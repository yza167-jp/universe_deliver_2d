extends ProjectTestSuite

const PANEL_SCENE_PATH: String = "res://scenes/ui/debug_settings_panel.tscn"
const TEST_SETTINGS_PATH: String = "user://t006_debug_settings_panel_test.cfg"

var _changed_options: Array[StringName] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	_remove_test_settings()
	_changed_options.clear()

	var service: SettingsServiceModel = SettingsServiceModel.new()
	service.storage_path = TEST_SETTINGS_PATH
	service.load_settings()
	service.assist_option_changed.connect(_on_assist_option_changed)

	var panel_scene: PackedScene = load(PANEL_SCENE_PATH) as PackedScene
	var panel: DebugSettingsPanel = panel_scene.instantiate() as DebugSettingsPanel
	panel.settings_service_override = service
	expect_true(panel.initialize(), "Debug settings panel must initialize.", failures)
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(panel)

	var slow_motion_button: CheckButton = panel.get_node(
		"Margin/Content/SlowMotionButton"
	) as CheckButton
	var route_hints_button: CheckButton = panel.get_node(
		"Margin/Content/RouteHintsButton"
	) as CheckButton
	var high_contrast_button: CheckButton = panel.get_node(
		"Margin/Content/HighContrastButton"
	) as CheckButton
	slow_motion_button.button_pressed = true
	route_hints_button.button_pressed = false
	high_contrast_button.button_pressed = true

	expect_true(service.settings.slow_motion_assist, "Debug UI must enable slow motion.", failures)
	expect_true(not service.settings.route_hints_enabled, "Debug UI must disable hints.", failures)
	expect_true(service.settings.high_contrast_terrain, "Debug UI must enable contrast.", failures)
	expect_true(
		_changed_options == [
			SettingsServiceModel.SLOW_MOTION_ASSIST,
			SettingsServiceModel.ROUTE_HINTS_ENABLED,
			SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		],
		"Debug UI toggles must emit all assistance state signals.",
		failures
	)

	panel.free()
	service.free()
	_remove_test_settings()
	_restore_global_settings()
	return failures


func _on_assist_option_changed(option_id: StringName, _enabled: bool) -> void:
	_changed_options.append(option_id)


func _restore_global_settings() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var global_service: SettingsServiceModel = scene_tree.root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	if global_service != null:
		global_service.load_settings()


func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
