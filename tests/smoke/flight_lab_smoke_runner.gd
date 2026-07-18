extends SceneTree

const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"

var _failures: Array[String] = []
var _failure_count: int = 0
var _company_warning_count: int = 0
var _last_company_warning_key: StringName = &""
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(FLIGHT_LAB_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Flight Lab scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return
	var flight_lab: FlightLab = packed_scene.instantiate() as FlightLab
	_check(flight_lab != null, "Flight Lab root controller is missing.")
	if flight_lab == null:
		_finish()
		return
	root.add_child(flight_lab)
	await process_frame
	await process_frame

	var flight_ship: FlightLabShip = flight_lab.get_flight_ship()
	var flight_camera: Camera2D = flight_lab.get_flight_camera()
	var debug_hud: FlightDebugHUD = flight_lab.get_debug_hud()
	var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	_check(flight_ship != null, "Flight Lab ship is missing.")
	_check(flight_camera != null and flight_camera.enabled, "Flight Lab camera is not active.")
	_check(debug_hud != null and debug_hud.visible, "Flight debug HUD is not visible.")
	if flight_ship != null:
		flight_ship.flight_failed.connect(_on_flight_failed)
		flight_ship.company_warning_requested.connect(_on_company_warning_requested)
	if debug_hud != null:
		var stats_rect: Rect2 = debug_hud.get_stats_rect()
		var status_rect: Rect2 = debug_hud.get_status_rect()
		_check(
			viewport_bounds.encloses(debug_hud.get_header_rect())
			and viewport_bounds.encloses(stats_rect)
			and viewport_bounds.encloses(status_rect),
			"Flight debug HUD leaves the 640x360 viewport."
		)
		_check(
			not stats_rect.intersects(status_rect),
			"Flight debug status and telemetry panels overlap at 640x360."
		)
		_check(
			debug_hud.get_speed_text() == tr("UI_FLIGHT_DEBUG_SPEED") % 0.0,
			"Flight debug HUD did not render the reset telemetry."
		)
		_check(
			debug_hud.get_environment_text().contains("0%")
			and not debug_hud.get_terminal_text().is_empty(),
			"Flight debug HUD did not render environment and terminal telemetry."
		)
		_check(
			debug_hud.get_durability_text().contains("100%")
			and debug_hud.get_checkpoint_text().contains(
				String(FlightLab.LAB_CHECKPOINT_ID)
			),
			"Flight debug HUD did not render five-resource and checkpoint telemetry."
		)
	_check(
		flight_lab.environment_profiles.size() == 2
		and flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id == &"environment_deep_space",
		"Flight Lab did not start in the deterministic deep-space preset."
	)
	_check(
		UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"The direct Flight Lab debug route is unavailable."
	)

	var toggle_event: InputEventAction = InputEventAction.new()
	toggle_event.action = FlightLab.HUD_TOGGLE_ACTION
	toggle_event.pressed = true
	flight_lab._unhandled_input(toggle_event)
	_check(debug_hud != null and not debug_hud.visible, "F3 action did not hide the debug HUD.")
	flight_lab._unhandled_input(toggle_event)
	_check(debug_hud != null and debug_hud.visible, "F3 action did not restore the debug HUD.")

	if flight_ship != null:
		var start_position: Vector2 = flight_ship.position
		await _hold_action_for_physics_frames(FlightLabShip.THROTTLE_ACTION, 12)
		var accelerated_speed: float = flight_ship.get_speed()
		_check(
			accelerated_speed > 20.0 and flight_ship.position.x > start_position.x,
			"Throttle action did not accelerate the ship forward."
		)
		for _frame_index: int in 6:
			await physics_frame
		_check(
			flight_ship.get_speed() > accelerated_speed * 0.9,
			"Released throttle removed space inertia too quickly."
		)
		var speed_before_brake: float = flight_ship.get_speed()
		await _hold_action_for_physics_frames(FlightLabShip.BRAKE_ACTION, 3)
		_check(
			flight_ship.get_speed() < speed_before_brake
			and flight_ship.get_speed() > 0.0,
			"Brake action must decelerate without instantly reversing or stopping."
		)
		await _hold_action_for_physics_frames(FlightLabShip.PITCH_DOWN_ACTION, 6)
		_check(
			flight_ship.rotation > 0.0 and flight_ship.angular_velocity > 0.0,
			"Pitch-down action did not build positive angular motion."
		)
		if debug_hud != null:
			await process_frame
			_check(
				not debug_hud.get_angular_velocity_text().is_empty()
				and debug_hud.get_angular_velocity_text()
				!= "UI_FLIGHT_DEBUG_ANGULAR_VELOCITY",
				"Flight debug HUD did not display angular velocity."
			)

		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not restore its stable checkpoint before Boost smoke."
		)
		var fuel_before_boost: float = flight_ship.fuel
		var energy_before_boost: float = flight_ship.boost_energy
		await _hold_action_for_physics_frames(FlightLabShip.BOOST_ACTION, 12)
		var energy_after_boost: float = flight_ship.boost_energy
		_check(
			flight_ship.get_speed() > 30.0
			and flight_ship.fuel < fuel_before_boost
			and energy_after_boost < energy_before_boost
			and flight_ship.effective_boost_input > 0.0,
			"Shift Boost did not accelerate or consume both fuel and Boost energy."
		)
		var boost_glow: Polygon2D = flight_ship.get_node_or_null("BoostGlow") as Polygon2D
		_check(
			boost_glow != null and boost_glow.visible,
			"Active Boost did not expose its minimum visual feedback."
		)
		for _frame_index: int in 48:
			await physics_frame
		_check(
			flight_ship.boost_energy > energy_after_boost,
			"Idle Boost energy did not recover after its configured delay."
		)

	var environment_event: InputEventAction = InputEventAction.new()
	environment_event.action = FlightLab.ENVIRONMENT_CYCLE_ACTION
	environment_event.pressed = true
	flight_lab._unhandled_input(environment_event)
	_check(
		flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id
		== &"environment_red_sand_atmosphere",
		"F4 action did not select the Red Sand atmosphere preset."
	)
	if flight_ship != null:
		for _frame_index: int in 10:
			await physics_frame
		_check(
			flight_ship.gravity_blend > 0.0
			and flight_ship.gravity_blend < 1.0
			and flight_ship.air_density > 0.0
			and flight_ship.air_density < 1.0,
			"Atmosphere gravity and density did not blend in gradually."
		)
		await process_frame
		_check(
			flight_lab.atmosphere_tint.color.a > 0.0
			and debug_hud != null
			and debug_hud.get_environment_text().contains("%")
			and debug_hud.get_environment_text() != "UI_FLIGHT_DEBUG_ENVIRONMENT",
			"Atmosphere transition did not provide visible tint and localized HUD feedback."
		)
		flight_ship.reset_to_start(
			0.75,
			flight_lab.get_active_environment_profile(),
			true
		)
		for _frame_index: int in 120:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			flight_ship.velocity.y > 0.0
			and flight_ship.velocity.y
			< flight_ship.get_terminal_fall_speed_safety(),
			"Default atmosphere assist did not produce a controlled downward fall."
		)
		flight_ship.velocity = Vector2(240.0, 0.0)
		for _frame_index: int in 60:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			flight_ship.velocity.x < 190.0,
			"Atmosphere did not decay horizontal speed with its independent drag."
		)

		flight_ship.reset_to_start(
			1.0,
			flight_lab.get_active_environment_profile(),
			true
		)
		for _frame_index: int in 60:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			absf(flight_ship.velocity.y) < 0.01
			and flight_ship.fuel < FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.assist_fuel_cost_rate > 0.0,
			"100% assist did not hover with an explicit fuel cost."
		)

	var assist_event: InputEventAction = InputEventAction.new()
	assist_event.action = FlightLab.ASSIST_CYCLE_ACTION
	assist_event.pressed = true
	var observed_assist_presets: Array[int] = []
	for _preset_index: int in 3:
		flight_lab._unhandled_input(assist_event)
		observed_assist_presets.append(
			roundi(flight_lab.get_active_assist_strength() * 100.0)
		)
	observed_assist_presets.sort()
	_check(
		observed_assist_presets == [0, 75, 100],
		"F5 action did not cycle all 0%, 75%, and 100% assist presets."
	)

	flight_lab._unhandled_input(environment_event)
	_check(
		flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id == &"environment_deep_space",
		"Second F4 action did not return to deep space."
	)

	if flight_ship != null:
		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not restore its deep-space checkpoint before impacts."
		)
		flight_ship.cargo_integrity = 91.0
		var hard_impact: FlightCollisionResult = flight_ship.resolve_impact(
			Vector2(250.0, 0.0),
			Vector2.LEFT
		)
		_check(
			hard_impact.severity == FlightCollisionResult.Severity.HARD
			and flight_ship.shield < FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.hull == FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.cargo_integrity < 90.0,
			"Hard impact did not damage shield and cargo without failing the run."
		)
		_check(
			_company_warning_count == 1
			and _last_company_warning_key
			== &"UI_FLIGHT_COMPANY_WARNING_CARGO_HIGH",
			"Crossing 90% cargo integrity did not trigger the company warning interface."
		)
		for _frame_index: int in 12:
			await physics_frame
		flight_ship.resolve_impact(Vector2(250.0, 0.0), Vector2.LEFT)
		_check(
			_company_warning_count == 1,
			"The same cargo warning threshold repeated during one checkpoint attempt."
		)

		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not reset before fatal terrain collision smoke."
		)
		_failure_count = 0
		flight_ship.position = Vector2(520.0, 241.0)
		flight_ship.velocity = Vector2(320.0, 0.0)
		for _frame_index: int in 20:
			await physics_frame
			if _failure_count > 0:
				break
		_check(
			_failure_count == 1
			and flight_ship.is_failed
			and flight_lab.is_retry_pending(),
			"High-speed collision with real terrain did not enter rapid failure retry."
		)
		await process_frame
		if debug_hud != null:
			var failure_status_rect: Rect2 = debug_hud.get_status_rect()
			_check(
				viewport_bounds.encloses(failure_status_rect)
				and not debug_hud.get_stats_rect().intersects(failure_status_rect),
				"Localized failure status expanded outside or over telemetry."
			)
		var retry_frames: int = 0
		while flight_lab.is_retry_pending() and retry_frames < 60:
			await physics_frame
			retry_frames += 1
		_check(
			retry_frames < 60
			and not flight_ship.is_failed
			and flight_ship.position == flight_ship.stable_start_position
			and flight_ship.velocity == Vector2.ZERO
			and is_equal_approx(
				flight_ship.hull,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(
				flight_ship.cargo_integrity,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			),
			"Fatal impact did not return control with checkpoint-defined resources."
		)

	if flight_ship != null:
		flight_ship.position = Vector2(812.0, 54.0)
		flight_ship.velocity = Vector2(220.0, 96.0)
		flight_ship.rotation = -0.55
		flight_ship.angular_velocity = -1.25
		flight_ship.throttle_input = 1.0
		flight_ship.brake_input = 1.0
		flight_ship.pitch_input = -1.0
		flight_ship.boost_input = 1.0
		flight_ship.hull = 9.0
		flight_ship.shield = 7.0
		flight_ship.fuel = 4.0
		flight_ship.boost_energy = 8.0
		flight_ship.cargo_integrity = 6.0
	var restart_event: InputEventAction = InputEventAction.new()
	restart_event.action = FlightLab.RESTART_ACTION
	restart_event.pressed = true
	flight_lab._unhandled_input(restart_event)
	if flight_ship != null:
		_check(
			flight_ship.position == flight_ship.stable_start_position
			and flight_ship.velocity == Vector2.ZERO
			and is_zero_approx(flight_ship.rotation)
			and is_zero_approx(flight_ship.angular_velocity)
			and is_zero_approx(flight_ship.throttle_input)
			and is_zero_approx(flight_ship.brake_input)
			and is_zero_approx(flight_ship.pitch_input)
			and is_zero_approx(flight_ship.boost_input),
			"R action left linear, angular, or input drift after reset."
		)
		_check(
			is_equal_approx(flight_ship.hull, FlightLabShip.DEFAULT_RESOURCE_VALUE)
			and is_equal_approx(
				flight_ship.shield,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(flight_ship.fuel, FlightLabShip.DEFAULT_RESOURCE_VALUE)
			and is_equal_approx(
				flight_ship.boost_energy,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(
				flight_ship.cargo_integrity,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			),
			"R action did not restore all five checkpoint resources."
		)
		_check(
			is_zero_approx(flight_ship.gravity_acceleration)
			and is_zero_approx(flight_ship.gravity_blend)
			and is_zero_approx(flight_ship.air_density),
			"R action did not snap the selected deep-space environment baseline."
		)
	if flight_camera != null and flight_ship != null:
		_check(
			flight_camera.position == flight_ship.stable_start_position,
			"Camera did not snap back to the stable start."
		)

	flight_lab.queue_free()
	await process_frame
	_finish()


func _hold_action_for_physics_frames(action: StringName, frame_count: int) -> void:
	Input.action_press(action)
	for _frame_index: int in frame_count:
		await physics_frame
	Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[flight-lab] PASS: controls, Boost resources, environment, collision "
			+ "bands, cargo warning, rapid retry, HUD, and checkpoint reset."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[flight-lab] %s" % failure)
	quit(1)


func _on_flight_failed(_reason_key: StringName) -> void:
	_failure_count += 1


func _on_company_warning_requested(
	warning_key: StringName,
	_cargo_integrity: float
) -> void:
	_company_warning_count += 1
	_last_company_warning_key = warning_key
