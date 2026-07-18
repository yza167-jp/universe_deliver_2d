class_name UniverseDeliverApp
extends Control

const DEBUG_UI_ARGUMENT: String = "--show-debug-ui"
const DEBUG_FLIGHT_LAB_ARGUMENT: String = "--flight-lab"
const FULLSCREEN_ACTION: StringName = &"toggle_fullscreen"

@onready var scene_container: Control = %SceneContainer
@onready var debug_layer: CanvasLayer = %DebugLayer
@onready var current_stage_label: Label = %CurrentStageLabel
@onready var stage_buttons: HBoxContainer = %StageButtons
@onready var scene_router: SceneRouterService = get_node("/root/SceneRouter") as SceneRouterService

var _windowed_mode_before_fullscreen: int = DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	if not scene_router.stage_changed.is_connected(_on_stage_changed):
		scene_router.stage_changed.connect(_on_stage_changed)

	var user_arguments: PackedStringArray = OS.get_cmdline_user_args()
	debug_layer.visible = should_show_debug_ui(
		OS.is_debug_build(),
		user_arguments
	)
	if debug_layer.visible:
		_build_debug_stage_switcher()

	if not scene_router.register_scene_container(scene_container):
		push_error("App could not register SceneContainer: %s" % scene_router.last_error)
		return
	if not scene_router.start():
		push_error("App could not start scene flow: %s" % scene_router.last_error)
		return
	if should_start_in_flight_lab(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_flight_lab")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(FULLSCREEN_ACTION):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if not is_instance_valid(scene_router):
		return
	if scene_router.stage_changed.is_connected(_on_stage_changed):
		scene_router.stage_changed.disconnect(_on_stage_changed)
	scene_router.unregister_scene_container(scene_container)


func _build_debug_stage_switcher() -> void:
	for stage: int in SceneRouterService.get_all_stages():
		var button: Button = Button.new()
		button.text = SceneRouterService.get_stage_name(stage)
		button.custom_minimum_size = Vector2(72.0, 24.0)
		button.pressed.connect(_on_debug_stage_requested.bind(stage))
		stage_buttons.add_child(button)


func _on_debug_stage_requested(stage: int) -> void:
	if not scene_router.debug_switch_to_stage(stage):
		push_warning("Debug stage switch rejected: %s" % scene_router.last_error)


func _on_stage_changed(_previous_stage: int, current_stage: int) -> void:
	current_stage_label.text = "STAGE: %s" % SceneRouterService.get_stage_name(current_stage)


func _open_direct_flight_lab() -> void:
	if not scene_router.debug_switch_to_stage(SceneRouterService.Stage.FLIGHT):
		push_error("App could not open Flight Lab: %s" % scene_router.last_error)


func toggle_fullscreen() -> bool:
	var current_mode: int = DisplayServer.window_get_mode()
	if is_fullscreen_mode(current_mode):
		DisplayServer.window_set_mode(_windowed_mode_before_fullscreen)
		return false
	if current_mode != DisplayServer.WINDOW_MODE_MINIMIZED:
		_windowed_mode_before_fullscreen = current_mode
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	return true


static func is_fullscreen_mode(window_mode: int) -> bool:
	return window_mode in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]


static func should_show_debug_ui(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_UI_ARGUMENT)


static func should_start_in_flight_lab(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_FLIGHT_LAB_ARGUMENT)
