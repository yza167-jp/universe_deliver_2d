class_name UniverseDeliverApp
extends Control

const DEBUG_UI_ARGUMENT: String = "--show-debug-ui"
const DEBUG_FLIGHT_LAB_ARGUMENT: String = "--flight-lab"
const DEBUG_RED_SAND_ROUTE_ARGUMENT: String = "--red-sand-route"
const DEBUG_RED_SAND_ARRIVAL_ARGUMENT: String = "--red-sand-arrival"
const DEBUG_RED_SAND_RESULTS_ARGUMENT: String = "--red-sand-results"
const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"
const RED_SAND_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const ASTEROID_LASER_PATH: String = "res://data/modules/asteroid_laser.tres"
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
	elif should_start_in_red_sand_route(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_route")
	elif should_start_in_red_sand_arrival(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_arrival")
	elif should_start_in_red_sand_results(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_results")


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
	if not scene_router.debug_switch_to_stage_scene(
		SceneRouterService.Stage.FLIGHT,
		FLIGHT_LAB_SCENE_PATH
	):
		push_error("App could not open Flight Lab: %s" % scene_router.last_error)


func _open_direct_red_sand_route() -> void:
	if not scene_router.debug_switch_to_stage(SceneRouterService.Stage.FLIGHT):
		push_error("App could not open Red Sand route: %s" % scene_router.last_error)


func _open_direct_red_sand_arrival() -> void:
	if not _prepare_red_sand_debug_result():
		return
	if not scene_router.debug_switch_to_stage(SceneRouterService.Stage.ARRIVAL):
		push_error("App could not open Red Sand arrival: %s" % scene_router.last_error)


func _open_direct_red_sand_results() -> void:
	if not _prepare_red_sand_debug_result():
		return
	if not scene_router.debug_switch_to_stage(SceneRouterService.Stage.RESULTS):
		push_error("App could not open Red Sand results: %s" % scene_router.last_error)


func _prepare_red_sand_debug_result() -> bool:
	var game_state: GameStateModel = get_node_or_null("/root/GameState") as GameStateModel
	var order: OrderDefinition = load(RED_SAND_ORDER_PATH) as OrderDefinition
	var laser_module: ShipModuleDefinition = load(ASTEROID_LASER_PATH) as ShipModuleDefinition
	if game_state == null or order == null or laser_module == null:
		push_error("App could not prepare the Red Sand result debug state.")
		return false
	game_state.reset_runtime_state()
	if not game_state.accept_order(order) or not game_state.equip_ship_module(laser_module):
		push_error("App could not seed the Red Sand result order or loadout.")
		return false
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	if run_state == null:
		push_error("App could not seed the Red Sand order result.")
		return false
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)
	game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	return true


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


static func should_start_in_red_sand_route(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_RED_SAND_ROUTE_ARGUMENT)


static func should_start_in_red_sand_arrival(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_RED_SAND_ARRIVAL_ARGUMENT)


static func should_start_in_red_sand_results(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_RED_SAND_RESULTS_ARGUMENT)
