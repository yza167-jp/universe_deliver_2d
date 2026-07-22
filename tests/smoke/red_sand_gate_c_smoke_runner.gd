extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"
const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"

var _failures: Array[String] = []
var _original_locale: String = ""
var _app: UniverseDeliverApp
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _scene_container: Control


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var order: OrderDefinition = (
		registry.find_order(&"order_red_sand_m0")
		if registry != null
		else null
	)
	_check(_game_state != null, "Gate C smoke requires the GameState autoload.")
	_check(_scene_router != null, "Gate C smoke requires the SceneRouter autoload.")
	_check(order != null, "Gate C smoke could not load the Red Sand order.")
	if _game_state == null or _scene_router == null or order == null:
		_finish()
		return

	_game_state.reset_runtime_state()
	_check(_game_state.accept_order(order), "Gate C smoke could not accept the Red Sand order.")
	_check(
		_game_state.confirm_departure(order),
		"Gate C smoke could not confirm the default ship loadout."
	)
	_game_state.set_story_flag(Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)

	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(packed_app != null, "Gate C smoke could not load the App scene.")
	if packed_app == null:
		await _cleanup()
		_finish()
		return
	_app = packed_app.instantiate() as UniverseDeliverApp
	_check(_app != null, "Gate C smoke App root has the wrong type.")
	if _app == null:
		await _cleanup()
		_finish()
		return
	root.add_child(_app)
	await process_frame
	await process_frame
	_scene_container = _app.get_node_or_null("SceneContainer") as Control
	_check(_scene_container != null, "Gate C smoke could not find the App scene container.")
	if _scene_container == null:
		await _cleanup()
		_finish()
		return

	_check(
		_scene_router.debug_switch_to_stage(SceneRouterService.Stage.COCKPIT),
		"Gate C smoke could not open the configured cockpit."
	)
	await process_frame
	await process_frame
	var cockpit: Cockpit = _get_active_scene() as Cockpit
	_check(cockpit != null, "Gate C smoke did not enter Cockpit.")
	if cockpit == null:
		await _cleanup()
		_finish()
		return
	_check(
		cockpit.activate_hotspot(&"navigation_screen")
		and cockpit.start_configured_travel(),
		"Configured cockpit could not start Red Sand travel."
	)
	await process_frame
	await process_frame
	var travel: TravelSequenceController = cockpit.get_travel_controller()
	_check(travel != null, "Gate C smoke could not access the travel controller.")
	if travel == null:
		await _cleanup()
		_finish()
		return
	travel.set_process(false)
	travel.advance_travel(travel.departure_duration + 0.1)
	travel.advance_travel(travel.cruise_duration + 0.1)
	travel.advance_travel(travel.approach_duration + 0.1)
	await process_frame
	await process_frame

	var route: RedSandFlight = _get_active_scene() as RedSandFlight
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.FLIGHT
		and _game_state.travel_state == GameStateModel.TravelState.COMPLETED
		and route != null,
		"Cockpit travel did not hand the configured run to RedSandFlight."
	)
	if route == null:
		await _cleanup()
		_finish()
		return
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)
	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	var scenic_triggers: Array[FlightScenicTrigger] = _get_scenic_triggers(route)
	_check(ship != null, "Gate C route ship is missing.")
	_check(landing_zone != null, "Gate C landing zone is missing.")
	_check(
		definition != null
		and definition.validate().is_empty()
		and definition.segments.size() == 8
		and is_equal_approx(definition.expected_duration_seconds, 120.0),
		"Gate C route must keep its validated eight-stage, two-minute baseline."
	)
	_check(
		scenic_triggers.size() == 2
		and scenic_triggers[0].trigger_id != scenic_triggers[1].trigger_id,
		"Gate C route must expose two distinct shallow-flight scenic triggers."
	)
	if ship == null or definition == null or landing_zone == null:
		await _cleanup()
		_finish()
		return
	ship.set_physics_process(false)

	for index: int in range(1, definition.segments.size()):
		var segment: FlightRouteSegment = definition.segments[index]
		ship.position = Vector2(
			route.route_origin_x + segment.start_distance + 1.0,
			190.0
		)
		ship.velocity = Vector2(140.0, 8.0)
		_check(
			route.advance_route_state()
			and route.get_active_segment_index() == index,
			"Gate C route did not advance continuously to stage %d." % index
		)
		if index == 5:
			await physics_frame
		if index == 3 and scenic_triggers.size() == 2:
			ship.velocity = Vector2(140.0, 8.0)
			route._process(4.1)
			_check(
				scenic_triggers[0].try_trigger(ship),
				"Upper-atmosphere scenic trigger did not record the glide route."
			)
		elif index == 4:
			ship.impact_resolved.emit(FlightCollisionResult.Severity.GRAZE, 72.0)
		elif index == 5 and scenic_triggers.size() == 2:
			ship.velocity = Vector2(140.0, 8.0)
			route._process(4.1)
			_check(
				scenic_triggers[1].try_trigger(ship),
				"Lower-cloud scenic trigger did not record the glide route."
			)
	var run_state: OrderRunState = _game_state.order_run_state
	_check(
		run_state.active_checkpoint_id == definition.segments[-1].checkpoint_id
		and run_state.entry_style == FlightStyleTracker.STYLE_GLIDE
		and run_state.scenic_trigger_count == 2
		and run_state.collision_count == 1,
		"Gate C route did not retain checkpoints, scenic passes, collision, and GLIDE."
	)

	_touch_down(route, landing_zone)
	_check(
		route.is_route_completed()
		and route.get_landing_result() == OrderRunState.LANDING_RESULT_SMOOTH
		and route.is_arrival_transition_pending(),
		"Gate C route did not finish with a valid smooth touchdown."
	)
	var arrival_delay: float = ship.tuning.landing_arrival_transition_delay_seconds
	route._process(arrival_delay + 0.1)
	await process_frame
	await process_frame
	var arrival: RedSandArrival = _get_active_scene() as RedSandArrival
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.ARRIVAL
		and arrival != null
		and _game_state.current_order_id == order.id
		and _game_state.order_run_state.landing_result
		== OrderRunState.LANDING_RESULT_SMOOTH,
		"Gate C landing did not preserve the order result into ARRIVAL."
	)
	await _check_dive_profile(order)

	await _cleanup()
	_finish()


func _touch_down(route: RedSandFlight, landing_zone: RedSandLandingZone) -> void:
	var ship: FlightLabShip = route.get_flight_ship()
	ship.global_position = landing_zone.global_position + Vector2(
		0.0,
		landing_zone.get_touchdown_center_y() - 2.0
	)
	ship.velocity = Vector2(70.0, 24.0)
	ship.rotation = deg_to_rad(5.0)
	route._physics_process(1.0 / 60.0)
	ship.global_position.y = (
		landing_zone.global_position.y
		+ landing_zone.get_touchdown_center_y()
		+ 1.0
	)
	route._physics_process(1.0 / 60.0)


func _get_active_scene() -> Node:
	if _scene_container == null or _scene_container.get_child_count() != 1:
		return null
	return _scene_container.get_child(0)


func _get_scenic_triggers(route: RedSandFlight) -> Array[FlightScenicTrigger]:
	var result: Array[FlightScenicTrigger] = []
	var container: Node2D = route.get_node_or_null("World/ScenicTriggers") as Node2D
	if container == null:
		return result
	for child: Node in container.get_children():
		if child is FlightScenicTrigger:
			result.append(child as FlightScenicTrigger)
	return result


func _check_dive_profile(order: OrderDefinition) -> void:
	var dive_state: GameStateModel = GameStateModel.new()
	_check(dive_state.accept_order(order), "Dive profile could not accept the order.")
	_check(dive_state.confirm_departure(order), "Dive profile could not confirm departure.")
	var packed_route: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	var dive_route: RedSandFlight = (
		packed_route.instantiate() as RedSandFlight
		if packed_route != null
		else null
	)
	_check(dive_route != null, "Dive profile could not instantiate RedSandFlight.")
	if dive_route == null:
		dive_state.free()
		return
	dive_route.game_state_override = dive_state
	root.add_child(dive_route)
	await process_frame
	await process_frame
	dive_route.close_controls_help()
	dive_route.set_process(false)
	dive_route.set_physics_process(false)
	var ship: FlightLabShip = dive_route.get_flight_ship()
	var definition: FlightRouteDefinition = dive_route.get_route_definition()
	if ship == null or definition == null:
		_check(false, "Dive profile route dependencies are missing.")
		dive_route.queue_free()
		await process_frame
		dive_state.free()
		return
	ship.set_physics_process(false)
	for index: int in range(1, definition.segments.size()):
		var segment: FlightRouteSegment = definition.segments[index]
		ship.position = Vector2(
			dive_route.route_origin_x + segment.start_distance + 1.0,
			330.0
		)
		ship.velocity = Vector2(280.0, 200.0)
		dive_route.advance_route_state()
		if index >= 3 and index < 7:
			dive_route._process(0.9)
	_check(
		dive_state.order_run_state.entry_style == FlightStyleTracker.STYLE_DIVE
		and dive_state.order_run_state.scenic_trigger_count == 0,
		"Formal Red Sand route did not retain a fast, no-vista DIVE profile."
	)
	dive_route.queue_free()
	await process_frame
	dive_state.free()


func _cleanup() -> void:
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await process_frame
		await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[gate-c] PASS: cockpit handoff, eight-stage Red Sand route, smooth "
			+ "landing, and retained ARRIVAL result."
		)
		quit(0)
		return
	printerr("[gate-c] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
