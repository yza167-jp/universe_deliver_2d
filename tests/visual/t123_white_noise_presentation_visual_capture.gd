extends SceneTree

const SCENE_PATH: String = "res://scenes/flight/white_noise_flight.tscn"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t123_white_noise_presentation"
)

var _flight: WhiteNoiseFlight
var _settings_service: SettingsServiceModel
var _original_high_contrast: bool = false
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_settings_service = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	if _settings_service == null:
		_fail("SettingsService is unavailable.")
		return
	_original_high_contrast = (
		_settings_service.settings.high_contrast_terrain
	)
	_settings_service.settings.high_contrast_terrain = false

	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_flight = packed.instantiate() as WhiteNoiseFlight
	if _flight == null:
		_fail("White Noise presentation scene could not instantiate.")
		return
	_flight.settings_service_override = _settings_service
	root.add_child(_flight)
	await _settle_frames(3)
	_flight.get_flight_ship().process_mode = Node.PROCESS_MODE_DISABLED
	if not await _capture_route_frame(
		"01_frozen_orbital_horizon.png",
		4050.0,
		180.0
	):
		return
	if not await _capture_route_frame(
		"02_layered_open_icefield.png",
		6500.0,
		470.0
	):
		return
	if not await _capture_route_frame(
		"03_translucent_ice_rift.png",
		12500.0,
		325.0
	):
		return
	if not await _capture_storm_frame(
		"04_aurora_blizzard.png",
		false
	):
		return
	if not await _capture_storm_frame(
		"05_aurora_blizzard_high_contrast.png",
		true
	):
		return
	_settings_service.settings.high_contrast_terrain = false
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		false
	)
	if not await _capture_route_frame(
		"06_under_ice_archive_descent.png",
		26000.0,
		370.0
	):
		return
	if not await _capture_route_frame(
		"07_archive_landing_beacons.png",
		32600.0,
		500.0
	):
		return
	_restore_runtime()
	_flight.queue_free()
	await _settle_frames(2)
	print(
		"[t123-visual] PASS: saved orbital ice, layered icefield/rift, "
		+ "aurora blizzard, reduced-noise contrast, archive, and landing frames."
	)
	quit(0)


func _capture_route_frame(
	file_name: String,
	route_distance: float,
	ship_y: float
) -> bool:
	if not _flight.debug_set_route_state(
		route_distance,
		&"white_noise_balanced"
	):
		_fail("Could not stage %s." % file_name)
		return false
	_flight.get_flight_ship().position.y = ship_y
	_flight._process(0.0)
	await _settle_frames(4)
	return _save_frame(file_name)


func _capture_storm_frame(
	file_name: String,
	high_contrast: bool
) -> bool:
	_settings_service.settings.high_contrast_terrain = high_contrast
	_settings_service.assist_option_changed.emit(
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		high_contrast
	)
	if (
		not _flight.debug_set_route_state(
			19500.0,
			&"white_noise_balanced"
		)
		or not _flight.debug_set_storm_state(
			WhiteNoiseInterferenceModel.State.ACTIVE,
			5.0
		)
	):
		_fail("Could not stage %s." % file_name)
		return false
	_flight.get_flight_ship().position.y = 300.0
	_flight._process(0.0)
	await _settle_frames(12)
	return _save_frame(file_name)


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
	print("[t123-visual] Saved %s" % output_path)
	return true


func _restore_runtime() -> void:
	if _settings_service != null:
		_settings_service.settings.high_contrast_terrain = (
			_original_high_contrast
		)
		_settings_service.assist_option_changed.emit(
			SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
			_original_high_contrast
		)
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t123-visual] FAIL: %s" % message)
	_restore_runtime()
	if _flight != null and is_instance_valid(_flight):
		_flight.queue_free()
	quit(1)
