extends Control

@onready var scene_container: Control = %SceneContainer
@onready var debug_layer: CanvasLayer = %DebugLayer
@onready var current_stage_label: Label = %CurrentStageLabel
@onready var stage_buttons: HBoxContainer = %StageButtons
@onready var scene_router: SceneRouterService = get_node("/root/SceneRouter") as SceneRouterService


func _ready() -> void:
	if not scene_router.stage_changed.is_connected(_on_stage_changed):
		scene_router.stage_changed.connect(_on_stage_changed)

	debug_layer.visible = OS.is_debug_build()
	if debug_layer.visible:
		_build_debug_stage_switcher()

	if not scene_router.register_scene_container(scene_container):
		push_error("App could not register SceneContainer: %s" % scene_router.last_error)
		return
	if not scene_router.start():
		push_error("App could not start scene flow: %s" % scene_router.last_error)


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
