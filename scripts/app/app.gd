class_name UniverseDeliverApp
extends Control

const DEBUG_UI_ARGUMENT: String = "--show-debug-ui"
const DEBUG_FLIGHT_LAB_ARGUMENT: String = "--flight-lab"
const DEBUG_DELIVERY_LAB_ARGUMENT: String = "--delivery-lab"
const DEBUG_RED_SAND_ROUTE_ARGUMENT: String = "--red-sand-route"
const DEBUG_RED_SAND_ARRIVAL_ARGUMENT: String = "--red-sand-arrival"
const DEBUG_RED_SAND_RESULTS_ARGUMENT: String = "--red-sand-results"
const M1_DEBUG_RESET_ACTION: StringName = &"m1_debug_reset"
const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"
const DELIVERY_LAB_SCENE_PATH: String = "res://scenes/flight/delivery_lab.tscn"
const M1_DATA_REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const RED_SAND_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const ASTEROID_LASER_PATH: String = "res://data/modules/asteroid_laser.tres"
const FULLSCREEN_ACTION: StringName = &"toggle_fullscreen"

@onready var scene_container: Control = %SceneContainer
@onready var debug_layer: CanvasLayer = %DebugLayer
@onready var current_stage_label: Label = %CurrentStageLabel
@onready var stage_buttons: HBoxContainer = %StageButtons
@onready var express_order_hud: ExpressOrderHUD = %ExpressOrderHUD
@onready var m1_debug_status: M1DebugStatus = %M1DebugStatus
@onready var scene_router: SceneRouterService = get_node("/root/SceneRouter") as SceneRouterService

var _windowed_mode_before_fullscreen: int = DisplayServer.WINDOW_MODE_WINDOWED
var _m1_debug_controller: M1DebugScenarioController


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
	if should_start_in_m1_debug(OS.is_debug_build(), user_arguments):
		call_deferred("_open_m1_debug_from_arguments", user_arguments)
	elif should_start_in_flight_lab(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_flight_lab")
	elif should_start_in_delivery_lab(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_delivery_lab")
	elif should_start_in_red_sand_route(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_route")
	elif should_start_in_red_sand_arrival(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_arrival")
	elif should_start_in_red_sand_results(OS.is_debug_build(), user_arguments):
		call_deferred("_open_direct_red_sand_results")


func _unhandled_input(event: InputEvent) -> void:
	if (
		_m1_debug_controller != null
		and event.is_action_pressed(M1_DEBUG_RESET_ACTION)
	):
		if not _m1_debug_controller.reset_scenario():
			push_error(
				"App could not reset M1 debug scenario: %s"
				% _m1_debug_controller.last_error
			)
		get_viewport().set_input_as_handled()
		return
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


func _open_m1_debug_from_arguments(
	user_arguments: PackedStringArray
) -> void:
	var registry: GameDataRegistry = load(
		M1_DATA_REGISTRY_PATH
	) as GameDataRegistry
	var game_state: GameStateModel = get_node_or_null(
		"/root/GameState"
	) as GameStateModel
	var save_service: SaveServiceModel = get_node_or_null(
		"/root/SaveService"
	) as SaveServiceModel
	var settings_service: SettingsServiceModel = get_node_or_null(
		"/root/SettingsService"
	) as SettingsServiceModel
	if (
		registry == null
		or game_state == null
		or save_service == null
		or settings_service == null
	):
		push_error("App could not resolve M1 debug dependencies.")
		return
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.parse_arguments(
		user_arguments,
		registry
	)
	if definition == null:
		push_error("App rejected M1 debug arguments: %s" % catalog.last_error)
		return
	_m1_debug_controller = M1DebugScenarioController.new()
	_m1_debug_controller.configure(
		game_state,
		registry,
		scene_router,
		scene_container,
		save_service,
		settings_service,
		express_order_hud,
		m1_debug_status
	)
	if not _m1_debug_controller.start_scenario(definition.scenario_id):
		push_error(
			"App could not start M1 debug scenario: %s"
			% _m1_debug_controller.last_error
		)


func _open_direct_delivery_lab() -> void:
	if not scene_router.debug_switch_to_stage_scene(
		SceneRouterService.Stage.FLIGHT,
		DELIVERY_LAB_SCENE_PATH
	):
		push_error("App could not open Delivery Lab: %s" % scene_router.last_error)


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


static func should_start_in_m1_debug(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return (
		is_debug_build
		and M1DebugScenarioCatalog.has_m1_debug_argument(user_arguments)
	)


func get_active_m1_debug_scenario_id() -> StringName:
	if _m1_debug_controller == null:
		return &""
	var definition: M1DebugScenarioDefinition = (
		_m1_debug_controller.get_definition()
	)
	return &"" if definition == null else definition.scenario_id


func reset_active_m1_debug_scenario() -> bool:
	return (
		_m1_debug_controller != null
		and _m1_debug_controller.reset_scenario()
	)


static func should_start_in_delivery_lab(
	is_debug_build: bool,
	user_arguments: PackedStringArray
) -> bool:
	return is_debug_build and user_arguments.has(DEBUG_DELIVERY_LAB_ARGUMENT)


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
