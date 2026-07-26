extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const FORMAL_PLANET_PATH: String = "res://data/planets/white_noise.tres"
const FORMAL_ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const CORE_INPUT_ACTIONS: Array[StringName] = [
	&"flight_throttle",
	&"flight_brake",
	&"flight_pitch_up",
	&"flight_pitch_down",
	&"flight_boost",
	&"flight_restart",
	&"flight_controls_help",
]

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _original_time_scale: float = 1.0
var _original_slow_motion: bool = false
var _original_route_hints: bool = true
var _original_high_contrast: bool = false
var _settings_service: SettingsServiceModel
var _registry: GameDataRegistry
var _flight: WhiteNoiseFlight
var _fixture_state: GameStateModel


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_time_scale = Engine.time_scale
	TranslationServer.set_locale("zh_CN")
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_settings_service != null, "T-121 requires SettingsService.")
	_check(_registry != null, "T-121 requires the M1 registry.")
	if _settings_service == null or _registry == null:
		_finish()
		return
	_original_slow_motion = _settings_service.settings.slow_motion_assist
	_original_route_hints = _settings_service.settings.route_hints_enabled
	_original_high_contrast = _settings_service.settings.high_contrast_terrain
	var settings_write_count: int = _settings_service.get_storage_write_count()
	var input_signature: String = _input_signature()

	var shielded_result: Dictionary = await _exercise_shielded_route()
	await _cleanup_flight()
	var unshielded_result: Dictionary = await _exercise_unshielded_route()
	await _cleanup_flight()
	_validate_comparison(shielded_result, unshielded_result)
	_validate_debug_fixtures()
	_validate_formal_boundary()
	_check(
		input_signature == _input_signature(),
		"Electromagnetic interference changed player Input Map state."
	)
	_check(
		settings_write_count == _settings_service.get_storage_write_count(),
		"T-121 wrote player settings during the isolated route."
	)
	_finish()


func _exercise_shielded_route() -> Dictionary:
	if not await _instantiate_flight(true):
		return {}
	var ship: FlightLabShip = _flight.get_flight_ship()
	var storm: WhiteNoiseStormController = _flight.get_storm_controller()
	var hud: WhiteNoiseRouteHUD = _flight.get_route_hud()
	var visuals: WhiteNoiseRouteVisuals = _flight.get_route_visuals()
	var profile: WhiteNoiseStormProfile = storm.get_profile()
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	_check(
		profile != null
		and is_equal_approx(profile.trigger_distance, 17000.0)
		and is_equal_approx(profile.end_distance, 23000.0)
		and ship.is_high_voltage_shielding_enabled()
		and is_equal_approx(
			ship.get_electromagnetic_interference_multiplier(),
			0.45
		)
		and is_equal_approx(ship.get_high_voltage_damage_multiplier(), 0.60),
		"Shielded route did not consume the T-111 module Resource."
	)

	_settings_service.settings.route_hints_enabled = true
	_settings_service.settings.high_contrast_terrain = true
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.ROUTE_HINTS_ENABLED,
		true
	)
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		true
	)
	_check(
		visuals.are_route_hints_visible()
		and visuals.is_high_contrast_enabled()
		and hud.is_hint_visible()
		and VIEWPORT_RECT.encloses(hud.get_route_panel_rect()),
		"Route hints, high contrast, or compact 640x360 HUD did not apply."
	)

	_settings_service.settings.slow_motion_assist = true
	_check(_flight.debug_set_route_state(17000.0), "Could not stage warning.")
	_check(
		storm.get_state() == WhiteNoiseInterferenceModel.State.WARNING
		and storm.is_slow_motion_active()
		and is_equal_approx(
			Engine.time_scale,
			_original_time_scale * profile.slow_motion_time_scale
		)
		and hud.get_status_text().contains("预警"),
		"Slow-motion assist did not extend the deterministic warning."
	)
	var warning_elapsed: float = storm.get_state_progress()
	_check(_flight.open_controls_help(), "White Noise help did not open.")
	_flight._process(8.0)
	_check(
		paused
		and is_equal_approx(storm.get_state_progress(), warning_elapsed)
		and storm.get_total_pulse_count() == 0,
		"Help pause advanced the blizzard timer or damage."
	)
	_check(_flight.close_controls_help(), "White Noise help did not close.")

	ship.shield = 100.0
	ship.hull = 100.0
	ship.cargo_integrity = 100.0
	ship.integrate_motion(0.72, 0.18, -0.35, 0.0, 0.26)
	var controls_before := Vector4(
		ship.throttle_input,
		ship.brake_input,
		ship.pitch_input,
		ship.boost_input
	)
	_check(_flight.debug_set_route_state(19000.0), "Could not stage active route.")
	ship.integrate_motion(
		controls_before.x,
		controls_before.y,
		controls_before.z,
		0.0,
		controls_before.w
	)
	_check(
		_flight.debug_set_storm_state(
			WhiteNoiseInterferenceModel.State.ACTIVE,
			0.0
		),
		"Could not stage shielded active blizzard."
	)
	var pulse_count: int = storm.advance(
		profile.pulse_interval_seconds,
		19000.0
	)
	var pulse_result: FlightDamageResult = storm.get_last_pulse_result()
	_check(
		pulse_count == 1
		and pulse_result != null
		and is_equal_approx(pulse_result.requested_damage, 10.8)
		and is_equal_approx(ship.shield, 89.2)
		and is_equal_approx(ship.hull, 100.0)
		and is_equal_approx(ship.cargo_integrity, 100.0)
		and Vector4(
			ship.throttle_input,
			ship.brake_input,
			ship.pitch_input,
			ship.boost_input
		) == controls_before
		and hud.get_interference_text().contains("39%")
		and hud.get_shielding_text().contains("已安装")
		and hud.get_status_text().contains("护盾 -11"),
		"Shielded pulse did not use reduced shield-first damage with clear HUD feedback."
	)
	var pulse_count_before_system_pause: int = storm.get_total_pulse_count()
	var shield_before_system_pause: float = ship.shield
	paused = true
	_flight._process(8.0)
	paused = false
	_check(
		storm.get_total_pulse_count() == pulse_count_before_system_pause
		and is_equal_approx(ship.shield, shield_before_system_pause),
		"System pause advanced the blizzard timer or damage."
	)
	var shielded_interference: float = storm.get_effective_interference()
	var shielded_visibility: float = storm.get_visibility_intensity()
	var damaged_shield: float = ship.shield
	_check(
		_flight.restart_from_checkpoint(false)
		and storm.get_state() == WhiteNoiseInterferenceModel.State.WARNING
		and storm.get_total_pulse_count() == 0
		and is_equal_approx(ship.shield, 100.0),
		"Checkpoint retry did not restore deterministic warning and resources."
	)
	_check(
		_flight.debug_set_route_state(23100.0)
		and storm.get_state() == WhiteNoiseInterferenceModel.State.CLEAR
		and not storm.is_slow_motion_active()
		and is_equal_approx(Engine.time_scale, _original_time_scale)
		and is_equal_approx(visuals.get_blizzard_interference_strength(), 0.0),
		"Leaving the fixed window did not clear interference and time scale."
	)
	return {
		"interference": shielded_interference,
		"visibility": shielded_visibility,
		"shield_after_pulse": damaged_shield,
	}


func _exercise_unshielded_route() -> Dictionary:
	if not await _instantiate_flight(false):
		return {}
	var ship: FlightLabShip = _flight.get_flight_ship()
	var storm: WhiteNoiseStormController = _flight.get_storm_controller()
	var hud: WhiteNoiseRouteHUD = _flight.get_route_hud()
	var profile: WhiteNoiseStormProfile = storm.get_profile()
	ship.process_mode = Node.PROCESS_MODE_DISABLED
	ship.shield = 100.0
	ship.hull = 100.0
	ship.cargo_integrity = 100.0
	_check(
		not ship.is_high_voltage_shielding_enabled()
		and is_equal_approx(
			ship.get_electromagnetic_interference_multiplier(),
			1.0
		)
		and is_equal_approx(ship.get_high_voltage_damage_multiplier(), 1.0),
		"Unshielded fixture unexpectedly received module protection."
	)
	_check(_flight.debug_set_route_state(19000.0), "Could not stage comparison route.")
	_check(
		_flight.debug_set_storm_state(
			WhiteNoiseInterferenceModel.State.ACTIVE,
			0.0
		),
		"Could not stage unshielded active blizzard."
	)
	var pulse_count: int = storm.advance(
		profile.pulse_interval_seconds,
		19000.0
	)
	_check(
		pulse_count == 1
		and is_equal_approx(ship.shield, 82.0)
		and is_equal_approx(ship.hull, 100.0)
		and hud.get_interference_text().contains("86%")
		and hud.get_shielding_text().contains("未安装"),
		"Unshielded comparison did not expose its full interference and resource risk."
	)
	ship.shield = 5.0
	ship.hull = 100.0
	ship.cargo_integrity = 100.0
	_flight.debug_set_storm_state(
		WhiteNoiseInterferenceModel.State.ACTIVE,
		0.0
	)
	storm.advance(profile.pulse_interval_seconds, 19000.0)
	var penetrated_result: FlightDamageResult = storm.get_last_pulse_result()
	_check(
		is_equal_approx(ship.shield, 0.0)
		and is_equal_approx(ship.hull, 87.0)
		and is_equal_approx(
			ship.cargo_integrity,
			100.0 - 3.0 * (13.0 / 18.0)
		)
		and penetrated_result.shield_damage == 5.0
		and penetrated_result.hull_damage == 13.0,
		"High-voltage pulses did not preserve ordinary shield-first penetration."
	)
	return {
		"interference": storm.get_effective_interference(),
		"visibility": storm.get_visibility_intensity(),
		"shield_after_pulse": ship.shield,
	}


func _validate_comparison(
	shielded: Dictionary,
	unshielded: Dictionary
) -> void:
	_check(
		not shielded.is_empty()
		and not unshielded.is_empty()
		and float(shielded.get("interference", 1.0))
		< float(unshielded.get("interference", 0.0)) * 0.5
		and float(shielded.get("visibility", 1.0))
		< float(unshielded.get("visibility", 0.0)) * 0.5
		and float(shielded.get("shield_after_pulse", 0.0))
		> float(unshielded.get("shield_after_pulse", 100.0)),
		"Shielded and unshielded runs were not clearly different under one sequence."
	)


func _validate_debug_fixtures() -> void:
	var catalog := M1DebugScenarioCatalog.new()
	var shielded: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE,
		_registry
	)
	var unshielded: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_WHITE_NOISE_ROUTE_UNSHIELDED,
		_registry
	)
	var shielded_progress: GameProgressData = catalog.build_initial_progress(
		shielded,
		_registry
	)
	var unshielded_progress: GameProgressData = catalog.build_initial_progress(
		unshielded,
		_registry
	)
	_check(
		shielded != null
		and unshielded != null
		and shielded_progress != null
		and unshielded_progress != null
		and shielded_progress.ship_configuration.get(
			ShipLoadoutRules.SLOT_DEFENSE,
			&""
		) == ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
		and unshielded_progress.ship_configuration.get(
			ShipLoadoutRules.SLOT_DEFENSE,
			&""
		) != ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID,
		"Central debug catalog did not preserve its shielded/unshielded pair."
	)


func _validate_formal_boundary() -> void:
	var planet: PlanetDefinition = load(FORMAL_PLANET_PATH) as PlanetDefinition
	var order: OrderDefinition = load(FORMAL_ORDER_PATH) as OrderDefinition
	_check(
		planet != null
		and order != null
		and planet.content_readiness
		== PlanetDefinition.ContentReadiness.PLAYABLE
		and planet.flight_scene_path == SCENE_PATH
		and order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE,
		"T-125 did not preserve the validated T-121 storm route."
	)


func _instantiate_flight(shielded: bool) -> bool:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	_fixture_state = GameStateModel.new()
	_fixture_state.ship_configuration = (
		ShipLoadoutRules.create_default_configuration()
	)
	if shielded:
		_fixture_state.ship_configuration[
			ShipLoadoutRules.SLOT_DEFENSE
		] = ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
	_flight.game_state_override = _fixture_state
	_flight.settings_service_override = _settings_service
	root.add_child(_flight)
	await process_frame
	await physics_frame
	_check(_flight.is_node_ready(), "White Noise scene did not become ready.")
	return _flight.is_node_ready()


func _cleanup_flight() -> void:
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
		await process_frame
	_flight = null
	if _fixture_state != null and is_instance_valid(_fixture_state):
		_fixture_state.free()
	_fixture_state = null
	paused = false
	Engine.time_scale = _original_time_scale


func _input_signature() -> String:
	var rows: Array[String] = []
	for action: StringName in CORE_INPUT_ACTIONS:
		var event_rows: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action):
			event_rows.append(event.as_text())
		rows.append("%s=%s" % [action, ",".join(event_rows)])
	return "|".join(rows)


func _restore_settings() -> void:
	if _settings_service == null:
		return
	_settings_service.settings.slow_motion_assist = _original_slow_motion
	_settings_service.settings.route_hints_enabled = _original_route_hints
	_settings_service.settings.high_contrast_terrain = _original_high_contrast
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.SLOW_MOTION_ASSIST,
		_original_slow_motion
	)
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.ROUTE_HINTS_ENABLED,
		_original_route_hints
	)
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		_original_high_contrast
	)


func _finish() -> void:
	paused = false
	Engine.time_scale = _original_time_scale
	_restore_settings()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t121-white-noise-blizzard] PASS: deterministic phases, "
			+ "shield-first pulses, module contrast, accessible HUD, pause/retry "
			+ "cleanup, input/settings isolation, and formal readiness guard."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t121-white-noise-blizzard] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
