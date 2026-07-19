extends SceneTree

const ORDER_ID: StringName = &"order_red_sand_m0"

var _failures: Array[String] = []
var _original_locale: String = ""
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
	_check(_game_state != null, "Landing smoke requires the GameState autoload.")
	_check(_scene_router != null, "Landing smoke requires the SceneRouter autoload.")
	if _game_state == null or _scene_router == null:
		_finish()
		return

	_game_state.reset_runtime_state()
	_game_state.current_order_id = ORDER_ID
	_game_state.order_run_state.reset(ORDER_ID)
	_scene_container = Control.new()
	_scene_container.name = &"LandingSmokeSceneContainer"
	_scene_container.size = Vector2(640.0, 360.0)
	root.add_child(_scene_container)
	_check(
		_scene_router.register_scene_container(_scene_container),
		"Landing smoke could not register a stage container."
	)
	_check(
		_scene_router.debug_switch_to_stage(SceneRouterService.Stage.FLIGHT),
		"Landing smoke could not open the standard FLIGHT stage."
	)
	await process_frame
	await process_frame

	var route: RedSandFlight = _get_active_route()
	_check(route != null, "Standard FLIGHT stage did not instantiate RedSandFlight.")
	if route != null:
		route.close_controls_help()
	if route == null:
		await _cleanup()
		_finish()
		return
	route.set_process(false)
	route.set_physics_process(false)
	var flight_ship: FlightLabShip = route.get_flight_ship()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	var route_hud: RedSandRouteHUD = route.get_route_hud()
	var definition: FlightRouteDefinition = route.get_route_definition()
	_check(flight_ship != null, "Landing smoke route ship is missing.")
	_check(landing_zone != null, "Landing smoke zone is missing.")
	_check(route_hud != null, "Landing smoke HUD is missing.")
	_check(definition != null, "Landing smoke route definition is missing.")
	if (
		flight_ship == null
		or landing_zone == null
		or route_hud == null
		or definition == null
	):
		await _cleanup()
		_finish()
		return
	flight_ship.set_physics_process(false)

	var final_segment: FlightRouteSegment = definition.segments[-1]
	flight_ship.position = Vector2(
		route.route_origin_x + final_segment.start_distance + 1.0,
		230.0
	)
	flight_ship.velocity = Vector2(125.0, 4.0)
	_check(route.advance_route_state(), "Landing stage could not be reached.")
	route._physics_process(0.0)
	_check(
		route.get_active_segment_index() == definition.segments.size() - 1
		and flight_ship.get_checkpoint_id() == final_segment.checkpoint_id
		and landing_zone.get_pad_width() >= 960.0
		and not route_hud.get_landing_text().is_empty(),
		"Landing stage did not expose its readable pad, checkpoint, and guidance."
	)
	flight_ship.global_position = landing_zone.global_position + Vector2(0.0, 232.0)
	flight_ship.velocity = Vector2(110.0, 0.0)
	route._physics_process(0.0)
	route._process(0.0)
	await process_frame
	await process_frame
	var landing_label: Label = route_hud.get_node(
		"LandingPanel/Margin/LandingLabel"
	) as Label
	_check(
		landing_label != null
		and landing_label.visible
		and landing_label.get_global_rect().size.x >= 300.0
		and landing_label.get_global_rect().size.y >= 24.0,
		"Landing guidance label did not receive a readable 640x360 layout."
	)
	landing_zone.reset_for_checkpoint()

	_touch_down(
		route,
		landing_zone,
		Vector2(220.0, 92.0),
		deg_to_rad(4.0)
	)
	_check(
		flight_ship.is_failed
		and route.is_retry_pending()
		and not route.is_route_completed()
		and _game_state.order_run_state.landing_result.is_empty(),
		"Unsafe touchdown did not fail without recording a delivery result."
	)
	var retry_delay: float = flight_ship.tuning.failure_retry_delay_seconds
	route._process(retry_delay + 0.1)
	_check(
		not flight_ship.is_failed
		and not route.is_retry_pending()
		and route.get_active_segment_index() == definition.segments.size() - 1
		and flight_ship.position == landing_zone.get_safe_checkpoint_position()
		and flight_ship.velocity == landing_zone.get_safe_checkpoint_velocity()
		and is_zero_approx(flight_ship.rotation),
		"Automatic retry did not restore the safe landing approach checkpoint."
	)

	var cargo_before: float = flight_ship.cargo_integrity
	_touch_down(
		route,
		landing_zone,
		Vector2(130.0, 55.0),
		deg_to_rad(14.0)
	)
	var expected_damage: float = flight_ship.tuning.landing_rough_cargo_damage
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		route.is_route_completed()
		and flight_ship.is_landed
		and route.get_landing_result() == OrderRunState.LANDING_RESULT_ROUGH
		and route.is_arrival_transition_pending(),
		"Recoverable touchdown did not complete as a rough landing."
	)
	_check(
		run_state != null
		and run_state.landing_result == OrderRunState.LANDING_RESULT_ROUGH
		and is_equal_approx(run_state.landing_cargo_damage, expected_damage)
		and is_equal_approx(run_state.cargo_integrity, cargo_before - expected_damage)
		and run_state.result_tags.has(OrderRunState.LANDING_RESULT_ROUGH),
		"Rough landing outcome and cargo cost did not persist for ARRIVAL."
	)

	var arrival_delay: float = flight_ship.tuning.landing_arrival_transition_delay_seconds
	route._process(arrival_delay + 0.1)
	await process_frame
	var arrival: RedSandArrival = _get_active_arrival()
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.ARRIVAL
		and arrival != null,
		"Successful landing did not transition from FLIGHT to ARRIVAL."
	)
	if arrival != null:
		_check(
			arrival.get_landing_feedback_text()
			== tr("UI_RED_SAND_ARRIVAL_LANDING_ROUGH")
			% roundi(cargo_before - expected_damage),
			"ARRIVAL did not read the localized rough-landing result: %s"
			% arrival.get_landing_feedback_text()
		)

	await _cleanup()
	_finish()


func _touch_down(
	route: RedSandFlight,
	landing_zone: RedSandLandingZone,
	velocity: Vector2,
	pitch_radians: float
) -> void:
	var flight_ship: FlightLabShip = route.get_flight_ship()
	flight_ship.global_position = landing_zone.global_position + Vector2(
		0.0,
		landing_zone.get_touchdown_center_y() - 2.0
	)
	flight_ship.velocity = velocity
	flight_ship.rotation = pitch_radians
	route._physics_process(1.0 / 60.0)
	flight_ship.global_position.y = (
		landing_zone.global_position.y
		+ landing_zone.get_touchdown_center_y()
		+ 1.0
	)
	route._physics_process(1.0 / 60.0)


func _get_active_route() -> RedSandFlight:
	if _scene_container == null or _scene_container.get_child_count() != 1:
		return null
	return _scene_container.get_child(0) as RedSandFlight


func _get_active_arrival() -> RedSandArrival:
	if _scene_container == null or _scene_container.get_child_count() != 1:
		return null
	return _scene_container.get_child(0) as RedSandArrival


func _cleanup() -> void:
	if _scene_router != null and _scene_container != null:
		_scene_router.unregister_scene_container(_scene_container)
	if _scene_container != null:
		_scene_container.queue_free()
	if _game_state != null:
		_game_state.reset_runtime_state()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[red-sand-landing] PASS: readable pad, failed-touchdown retry, rough "
			+ "cargo result, and FLIGHT-to-ARRIVAL handoff."
		)
		quit(0)
		return
	printerr("[red-sand-landing] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
