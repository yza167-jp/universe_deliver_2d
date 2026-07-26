extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t121_white_noise_blizzard"
)

var _settings_service: SettingsServiceModel
var _original_slow_motion: bool = false
var _original_route_hints: bool = true
var _original_high_contrast: bool = false
var _original_locale: String = ""
var _original_time_scale: float = 1.0
var _flight: WhiteNoiseFlight
var _fixture_state: GameStateModel


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_time_scale = Engine.time_scale
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	if _settings_service == null:
		_fail("SettingsService is unavailable.")
		return
	_original_slow_motion = _settings_service.settings.slow_motion_assist
	_original_route_hints = _settings_service.settings.route_hints_enabled
	_original_high_contrast = _settings_service.settings.high_contrast_terrain
	_settings_service.settings.slow_motion_assist = false
	_settings_service.settings.route_hints_enabled = true
	_settings_service.settings.high_contrast_terrain = false

	if not await _create_flight(true):
		return
	if not await _stage_and_capture(
		"01_blizzard_warning_shielded.png",
		17400.0,
		WhiteNoiseInterferenceModel.State.WARNING,
		1.2
	):
		return
	if not await _stage_and_capture(
		"02_blizzard_active_shielded.png",
		19000.0,
		WhiteNoiseInterferenceModel.State.ACTIVE,
		5.0
	):
		return
	await _destroy_flight()

	if not await _create_flight(false):
		return
	if not await _stage_and_capture(
		"03_blizzard_active_unshielded.png",
		19000.0,
		WhiteNoiseInterferenceModel.State.ACTIVE,
		5.0
	):
		return
	_settings_service.settings.high_contrast_terrain = true
	_settings_service.settings.route_hints_enabled = true
	_flight.get_storm_controller().refresh_accessibility()
	if not await _stage_and_capture(
		"04_blizzard_high_contrast_route_hints.png",
		20500.0,
		WhiteNoiseInterferenceModel.State.ACTIVE,
		7.0
	):
		return
	await _destroy_flight()

	if not await _create_flight(true):
		return
	_settings_service.settings.high_contrast_terrain = false
	_flight.get_storm_controller().refresh_accessibility()
	if not await _stage_and_capture(
		"05_archive_signal_recovery.png",
		26450.0,
		WhiteNoiseInterferenceModel.State.RECOVERY,
		1.4
	):
		return
	await _destroy_flight()
	_restore_runtime()
	print(
		"[t121-visual] PASS: saved warning, shielded/unshielded active, "
		+ "high-contrast route hints, and archive signal recovery frames."
	)
	quit(0)


func _create_flight(shielded: bool) -> bool:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	if _flight == null:
		_fail("White Noise route scene could not instantiate.")
		return false
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
	await _settle_frames(3)
	_flight.get_flight_ship().process_mode = Node.PROCESS_MODE_DISABLED
	return true


func _stage_and_capture(
	file_name: String,
	route_distance: float,
	state: WhiteNoiseInterferenceModel.State,
	elapsed_seconds: float
) -> bool:
	if (
		not _flight.debug_set_route_state(
			route_distance,
			&"white_noise_balanced"
		)
		or not _flight.debug_set_storm_state(state, elapsed_seconds)
	):
		_fail("Could not stage %s." % file_name)
		return false
	await _settle_frames(3)
	var storm: WhiteNoiseStormController = _flight.get_storm_controller()
	if (
		storm.get_state() != state
		or _flight.get_route_hud().get_interference_text().is_empty()
		or not Rect2(0.0, 0.0, 640.0, 360.0).encloses(
			_flight.get_route_hud().get_route_panel_rect()
		)
	):
		_fail("Capture state or compact HUD was invalid for %s." % file_name)
		return false
	return _save_frame(file_name)


func _destroy_flight() -> void:
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
		await _settle_frames(2)
	_flight = null
	if _fixture_state != null and is_instance_valid(_fixture_state):
		_fixture_state.free()
	_fixture_state = null
	Engine.time_scale = _original_time_scale


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		_fail("Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		_fail("Could not save %s." % output_path)
		return false
	print("[t121-visual] Saved %s" % output_path)
	return true


func _restore_runtime() -> void:
	Engine.time_scale = _original_time_scale
	if _settings_service != null:
		_settings_service.settings.slow_motion_assist = _original_slow_motion
		_settings_service.settings.route_hints_enabled = _original_route_hints
		_settings_service.settings.high_contrast_terrain = _original_high_contrast
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t121-visual] FAIL: %s" % message)
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
	_restore_runtime()
	quit(1)
