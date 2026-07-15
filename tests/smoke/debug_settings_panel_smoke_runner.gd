extends SceneTree

const PANEL_SCENE_PATH: String = "res://scenes/ui/debug_settings_panel.tscn"
const TEST_SETTINGS_PATH: String = "user://t006_debug_settings_runner_test.cfg"

var _failures: PackedStringArray = []
var _changed_options: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_remove_test_settings()
	var service: SettingsServiceModel = SettingsServiceModel.new()
	service.storage_path = TEST_SETTINGS_PATH
	_check(service.load_settings(), "Debug settings fixture could not load local storage.")
	service.assist_option_changed.connect(_on_assist_option_changed)

	var host: Control = Control.new()
	host.size = Vector2(640.0, 360.0)
	root.add_child(host)
	var panel_scene: PackedScene = load(PANEL_SCENE_PATH) as PackedScene
	var panel: DebugSettingsPanel = panel_scene.instantiate() as DebugSettingsPanel
	panel.settings_service_override = service
	host.add_child(panel)
	await process_frame

	var slow_motion_button: CheckButton = panel.get_node(
		"Margin/Content/SlowMotionButton"
	) as CheckButton
	var route_hints_button: CheckButton = panel.get_node(
		"Margin/Content/RouteHintsButton"
	) as CheckButton
	var high_contrast_button: CheckButton = panel.get_node(
		"Margin/Content/HighContrastButton"
	) as CheckButton
	var assist_slider: HSlider = panel.get_node(
		"Margin/Content/AssistStrengthSlider"
	) as HSlider

	slow_motion_button.button_pressed = true
	route_hints_button.button_pressed = false
	high_contrast_button.button_pressed = true
	assist_slider.value = 35.0
	await process_frame

	_check(service.settings.slow_motion_assist, "Slow-motion assist did not toggle from the UI.")
	_check(not service.settings.route_hints_enabled, "Route hints did not toggle from the UI.")
	_check(service.settings.high_contrast_terrain, "High contrast did not toggle from the UI.")
	_check(
		is_equal_approx(service.settings.flight_assist_strength, 0.35),
		"Flight assist slider did not map 0-100% UI values to 0-1 settings."
	)
	_check(
		_changed_options == [
			SettingsServiceModel.SLOW_MOTION_ASSIST,
			SettingsServiceModel.ROUTE_HINTS_ENABLED,
			SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		],
		"The three assistance toggles did not emit ordered state signals."
	)
	_check(FileAccess.file_exists(TEST_SETTINGS_PATH), "Debug changes did not persist locally.")
	_check(panel.position.x >= 0.0 and panel.position.y >= 0.0, "Debug panel left the viewport.")
	_check(
		panel.position.x + panel.size.x <= 640.0 and panel.position.y + panel.size.y <= 360.0,
		"Debug panel does not fit the 640x360 viewport."
	)

	host.queue_free()
	service.free()
	_remove_test_settings()
	_restore_global_settings()
	await process_frame
	if _failures.is_empty():
		print("[debug-settings] PASS: toggles, slider, signals, persistence, and layout.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[debug-settings] %s" % failure)
	quit(1)


func _on_assist_option_changed(option_id: StringName, _enabled: bool) -> void:
	_changed_options.append(option_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _restore_global_settings() -> void:
	var global_service: SettingsServiceModel = root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	if global_service != null:
		global_service.load_settings()


func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
