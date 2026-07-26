extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const FORMAL_PLANET_PATH: String = "res://data/planets/white_noise.tres"
const FORMAL_ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)

var _failures: PackedStringArray = []
var _flight: WhiteNoiseFlight
var _settings_service: SettingsServiceModel
var _original_high_contrast: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	_check(_settings_service != null, "T-123 requires SettingsService.")
	if _settings_service == null:
		await _finish()
		return
	_original_high_contrast = (
		_settings_service.settings.high_contrast_terrain
	)
	_settings_service.settings.high_contrast_terrain = false

	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	_check(_flight != null, "White Noise presentation scene did not instantiate.")
	if _flight == null:
		await _finish()
		return
	_flight.settings_service_override = _settings_service
	root.add_child(_flight)
	await process_frame
	await physics_frame
	_flight.get_flight_ship().process_mode = Node.PROCESS_MODE_DISABLED
	_validate_scene_layers()
	await _validate_segment_mix()
	await _validate_accessibility()
	_validate_formal_boundary()
	await _finish()


func _validate_scene_layers() -> void:
	var feedback: WhiteNoiseEnvironmentFeedback = (
		_flight.get_environment_feedback()
	)
	var visuals: WhiteNoiseRouteVisuals = _flight.get_route_visuals()
	_check(
		feedback != null
		and visuals != null
		and feedback.get_presentation_signature()
		== &"white_noise_safe_storm_archive_motif"
		and visuals.get_presentation_signature()
		== &"white_noise_ice_aurora_archive"
		and visuals.get_background_layer_count() >= 7
		and visuals.get_collision_body_count() >= 5,
		"Layered presentation or collision silhouette contract is incomplete."
	)
	if feedback == null:
		return
	_check(
		_stream_has_signal(feedback.get_safe_audio().stream as AudioStreamWAV)
		and _stream_has_signal(
			feedback.get_storm_audio().stream as AudioStreamWAV
		)
		and _stream_has_signal(
			feedback.get_archive_audio().stream as AudioStreamWAV
		)
		and _stream_has_signal(
			feedback.get_motif_audio().stream as AudioStreamWAV
		),
		"Safe, storm, archive, or memory-motif generated audio is missing."
	)


func _validate_segment_mix() -> void:
	var feedback: WhiteNoiseEnvironmentFeedback = (
		_flight.get_environment_feedback()
	)
	_check(
		_flight.debug_set_route_state(6200.0),
		"Could not stage the open icefield."
	)
	await process_frame
	var safe_mix: Vector3 = feedback.get_layer_target_volumes()
	_check(
		feedback.get_active_segment_id() == &"white_noise_open_icefield"
		and feedback.is_snow_emitting()
		and feedback.get_snow_particle_amount() == 58
		and safe_mix.x > safe_mix.y
		and safe_mix.x > safe_mix.z
		and feedback.get_motif_play_count() >= 1,
		"Open icefield did not select safe wind, snow, and the short motif."
	)
	_check(
		_flight.debug_set_route_state(19000.0)
		and _flight.debug_set_storm_state(
			WhiteNoiseInterferenceModel.State.ACTIVE,
			5.0
		),
		"Could not stage the aurora blizzard."
	)
	await process_frame
	var storm_mix: Vector3 = feedback.get_layer_target_volumes()
	_check(
		feedback.get_active_segment_id() == &"white_noise_aurora_blizzard"
		and storm_mix.y > storm_mix.x
		and storm_mix.y > storm_mix.z
		and feedback.is_snow_emitting(),
		"Aurora blizzard did not prioritize its independent storm layer."
	)
	_check(
		_flight.debug_set_route_state(26000.0),
		"Could not stage the archive descent."
	)
	await process_frame
	var archive_mix: Vector3 = feedback.get_layer_target_volumes()
	_check(
		feedback.get_active_segment_id() == &"white_noise_archive_descent"
		and archive_mix.z > archive_mix.x
		and archive_mix.z > archive_mix.y
		and not feedback.is_snow_emitting()
		and feedback.get_motif_play_count() >= 2,
		"Archive descent did not replace snow pressure with archive machinery and motif."
	)


func _validate_accessibility() -> void:
	var feedback: WhiteNoiseEnvironmentFeedback = (
		_flight.get_environment_feedback()
	)
	var visuals: WhiteNoiseRouteVisuals = _flight.get_route_visuals()
	var storm: WhiteNoiseStormController = _flight.get_storm_controller()
	_settings_service.settings.high_contrast_terrain = false
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		false
	)
	_check(
		_flight.debug_set_route_state(20000.0)
		and _flight.debug_set_storm_state(
			WhiteNoiseInterferenceModel.State.ACTIVE,
			5.0
		),
		"Could not restage the default blizzard."
	)
	await process_frame
	var default_snow: int = feedback.get_snow_particle_amount()
	var default_streaks: int = visuals.get_blizzard_streak_count()
	var default_lines: int = storm.get_feedback_line_count()
	_settings_service.settings.high_contrast_terrain = true
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		true
	)
	await process_frame
	_check(
		feedback.is_reduced_visual_noise_enabled()
		and feedback.get_snow_particle_amount() < default_snow
		and feedback.get_snow_particle_alpha() < 0.5
		and visuals.get_blizzard_streak_count() < default_streaks
		and storm.get_feedback_line_count() < default_lines
		and storm.get_pulse_flash_alpha_scale() < 0.5
		and visuals.is_high_contrast_enabled(),
		"High contrast did not reduce snow, noise lines, and pulse flash together."
	)


func _validate_formal_boundary() -> void:
	var planet: PlanetDefinition = load(FORMAL_PLANET_PATH) as PlanetDefinition
	var order: OrderDefinition = load(FORMAL_ORDER_PATH) as OrderDefinition
	_check(
		planet != null
		and order != null
		and planet.content_readiness
		== PlanetDefinition.ContentReadiness.REGISTERED_ONLY
		and planet.flight_scene_path.is_empty()
		and order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY,
		"T-123 presentation changed the formal playable boundary."
	)


func _stream_has_signal(stream: AudioStreamWAV) -> bool:
	if stream == null or stream.data.is_empty():
		return false
	for byte: int in stream.data:
		if byte != 0:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _settings_service != null:
		_settings_service.settings.high_contrast_terrain = (
			_original_high_contrast
		)
		_settings_service.assist_option_changed.emit(
			SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
			_original_high_contrast
		)
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"[t123-presentation] PASS: layered ice/aurora/archive visuals, "
			+ "three ambience layers, motif, and reduced-noise accessibility."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t123-presentation] FAIL: %s" % failure)
	quit(1)
