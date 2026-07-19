extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"

var _failures: Array[String] = []
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Red Sand route scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Red Sand route controller is missing.")
	if route == null:
		_finish()
		return
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)

	var flight_ship: FlightLabShip = route.get_flight_ship()
	var flight_camera: Camera2D = route.get_flight_camera()
	var route_hud: RedSandRouteHUD = route.get_route_hud()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	_check(flight_ship != null, "Red Sand route ship is missing.")
	_check(flight_camera != null and flight_camera.enabled, "Red Sand route camera is inactive.")
	_check(route_hud != null, "Red Sand route HUD is missing.")
	_check(landing_zone != null, "Red Sand landing zone is missing.")
	_check(
		definition != null
		and definition.validate().is_empty()
		and definition.segments.size() == 8,
		"Red Sand route data is not a validated eight-stage sequence."
	)
	if (
		flight_ship == null
		or route_hud == null
		or definition == null
		or landing_zone == null
	):
		route.queue_free()
		await process_frame
		_finish()
		return
	flight_ship.set_physics_process(false)

	_check(
		route.get_active_segment_index() == 0
		and flight_ship.get_checkpoint_id()
		== definition.segments[0].checkpoint_id
		and flight_ship.environment_profile
		== definition.segments[0].environment_profile,
		"Route did not begin at the system-edge checkpoint and environment."
	)
	_check(
		is_equal_approx(route.get_planet_visual_scale(), 0.36),
		"Initial Red Sand planet scale does not match the distant-system baseline."
	)
	_check(
		route.get_node("World/RouteGeometry").get_child_count() >= 41,
		"Runtime graybox did not build stage bands, floors, markers, and the finish beacon."
	)
	var route_geometry: Node = route.get_node("World/RouteGeometry")
	var landmark_names: PackedStringArray = [
		"AsteroidSilhouettes02",
		"ApproachGuides03",
		"ApproachGuides04",
		"CloudSilhouettes05",
		"CloudSilhouettes06",
		"FacilitySilhouettes07",
		"LandingGuides08",
	]
	for landmark_name: String in landmark_names:
		var landmark: Node = route_geometry.get_node_or_null(landmark_name)
		_check(
			landmark is Node2D
			and landmark.find_children("*", "CollisionObject2D", true, false).is_empty(),
			"Stage landmark '%s' must exist and remain visual-only." % landmark_name
		)
	var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	_check(
		route_hud.get_flight_panel_rect() == Rect2()
		and viewport_bounds.encloses(route_hud.get_route_panel_rect())
		and not route_hud.has_visible_mouse_interception(),
		"Red Sand Essential HUD is outside 640x360 or blocks mouse input."
	)
	route_hud.toggle_full_diagnostics()
	_check(
		viewport_bounds.encloses(route_hud.get_flight_panel_rect())
		and not route_hud.get_flight_panel_rect().intersects(
			route_hud.get_route_panel_rect()
		),
		"H diagnostics did not stay inside the viewport without overlapping route data."
	)
	route_hud.toggle_full_diagnostics()

	var previous_planet_scale: float = route.get_planet_visual_scale()
	var checkpoint_position: Vector2 = Vector2.ZERO
	var checkpoint_velocity: Vector2 = Vector2.ZERO
	var checkpoint_rotation: float = 0.0
	for index: int in range(1, definition.segments.size()):
		var segment: FlightRouteSegment = definition.segments[index]
		flight_ship.position = Vector2(
			route.route_origin_x + segment.start_distance + 1.0,
			190.0 + float(index)
		)
		flight_ship.velocity = Vector2(120.0 + float(index), 4.0 + float(index))
		flight_ship.rotation = 0.01 * float(index)
		var position_before: Vector2 = flight_ship.position
		var velocity_before: Vector2 = flight_ship.velocity
		var rotation_before: float = flight_ship.rotation
		_check(route.advance_route_state(), "Route stage boundary was not detected.")
		route._process(0.0)
		_check(
			route.get_active_segment_index() == index,
			"Route stage order skipped or regressed at index %d." % index
		)
		_check(
			flight_ship.position == position_before
			and flight_ship.velocity == velocity_before
			and is_equal_approx(flight_ship.rotation, rotation_before),
			"Stage transition changed ship position, velocity, or rotation at index %d."
			% index
		)
		_check(
			flight_ship.environment_profile == segment.environment_profile
			and flight_ship.get_checkpoint_id() == segment.checkpoint_id,
			"Stage transition did not apply its environment and checkpoint at index %d."
			% index
		)
		var current_planet_scale: float = route.get_planet_visual_scale()
		_check(
			current_planet_scale >= previous_planet_scale,
			"Planet visual scale decreased during the route."
		)
		previous_planet_scale = current_planet_scale
		if index == definition.segments.size() - 1:
			checkpoint_position = landing_zone.get_safe_checkpoint_position()
			checkpoint_velocity = landing_zone.get_safe_checkpoint_velocity()
			checkpoint_rotation = 0.0
	route._physics_process(0.0)

	_check(
		route_hud.get_stage_text().contains(
			tr(definition.segments[-1].display_name_key)
		)
		and route_hud.get_progress_text().contains("87%")
		and not route_hud.get_instruction_text().is_empty()
		and not route_hud.get_landing_text().is_empty()
		and viewport_bounds.encloses(route_hud.get_landing_rect())
		and not route_hud.get_landing_rect().intersects(
			route_hud.get_flight_panel_rect()
		)
		and not route_hud.get_landing_rect().intersects(
			route_hud.get_route_panel_rect()
		),
		"Localized route HUD did not follow the active landing-approach stage."
	)

	var active_segment: FlightRouteSegment = route.get_active_segment()
	var minimum_x: float = (
		route.route_origin_x
		+ active_segment.start_distance
		- definition.reverse_allowance_distance
	)
	flight_ship.position = Vector2(minimum_x - 120.0, 214.0)
	flight_ship.velocity = Vector2(-80.0, 17.0)
	_check(route.enforce_forward_route_limit(), "Long reverse route limit did not engage.")
	_check(
		is_equal_approx(flight_ship.position.x, minimum_x)
		and is_zero_approx(flight_ship.velocity.x)
		and is_equal_approx(flight_ship.velocity.y, 17.0)
		and route.get_active_segment_index() == definition.segments.size() - 1,
		"Reverse limit did not preserve vertical motion and the active route act."
	)

	_check(route.restart_from_checkpoint(false), "Route checkpoint could not be restored.")
	_check(
		flight_ship.position == checkpoint_position
		and flight_ship.velocity == checkpoint_velocity
		and is_equal_approx(flight_ship.rotation, checkpoint_rotation),
		"Landing retry did not restore the fixed safe approach checkpoint."
	)

	flight_ship.position.x = route.route_origin_x + definition.get_total_distance() + 1.0
	flight_ship.velocity = Vector2(160.0, 9.0)
	var completion_position: Vector2 = flight_ship.position
	var completion_velocity: Vector2 = flight_ship.velocity
	_check(not route.advance_route_state(), "Route endpoint must not create a ninth stage.")
	route._process(0.0)
	_check(
		not route.is_route_completed()
		and flight_ship.position == completion_position
		and flight_ship.velocity == completion_velocity
		and is_equal_approx(route.get_route_progress(), 1.0)
		and is_equal_approx(route.get_planet_visual_scale(), 1.55)
		and not (
			route.get_node("World/RouteGeometry") as RedSandRouteVisuals
		).is_full_planet_visible(),
		"Flying past the route distance must not replace a real touchdown."
	)

	var maximum_x: float = (
		route.route_origin_x
		+ definition.get_total_distance()
		+ definition.finish_hold_distance
	)
	flight_ship.position.x = maximum_x + 100.0
	flight_ship.velocity = Vector2(90.0, -6.0)
	_check(route.enforce_forward_route_limit(), "Route finish hold limit did not engage.")
	_check(
		is_equal_approx(flight_ship.position.x, maximum_x)
		and is_zero_approx(flight_ship.velocity.x)
		and is_equal_approx(flight_ship.velocity.y, -6.0),
		"Route finish hold must stop overshoot without changing vertical correction."
	)

	flight_ship.global_position = landing_zone.global_position + Vector2(
		0.0,
		landing_zone.get_touchdown_center_y() - 2.0
	)
	flight_ship.velocity = Vector2(70.0, 24.0)
	flight_ship.rotation = deg_to_rad(5.0)
	route._physics_process(1.0 / 60.0)
	flight_ship.global_position.y = (
		landing_zone.global_position.y
		+ landing_zone.get_touchdown_center_y()
		+ 1.0
	)
	route._physics_process(1.0 / 60.0)
	route._process(0.0)
	_check(
		route.is_route_completed()
		and flight_ship.is_landed
		and flight_ship.velocity == Vector2.ZERO
		and route.get_landing_result() == OrderRunState.LANDING_RESULT_SMOOTH
		and route.is_arrival_transition_pending(),
		"A safe, level touchdown did not complete landing and queue ARRIVAL."
	)
	_check(
		route_hud.get_status_text()
		== tr("UI_RED_SAND_LANDING_RESULT_SMOOTH") % 100
		and route_hud.get_landing_rect() == Rect2(),
		"Smooth landing did not replace guidance with localized Lao Pi feedback."
	)
	_check(
		definition.nominal_fast_duration_seconds >= 60.0
		and definition.nominal_fast_duration_seconds <= 100.0
		and definition.expected_duration_seconds >= 90.0
		and definition.expected_duration_seconds <= 150.0
		and definition.nominal_scenic_duration_seconds >= 120.0
		and definition.nominal_scenic_duration_seconds <= 180.0,
		"Route duration profiles are not tunable within the required 1-3 minutes."
	)
	_check(
		UniverseDeliverApp.should_start_in_red_sand_route(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_RED_SAND_ROUTE_ARGUMENT])
		)
		and UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"Red Sand route or preserved Flight Lab direct debug entry is unavailable."
	)

	route.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[red-sand-route] PASS: eight continuous stages, safe landing checkpoint, "
			+ "bounded route, localized guidance, and touchdown-only completion."
		)
		quit(0)
		return
	printerr("[red-sand-route] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
