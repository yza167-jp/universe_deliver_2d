extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const SURFACE_SEGMENT_INDEX: int = 6
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

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

	var settings_service: SettingsServiceModel = SettingsServiceModel.new()
	settings_service.settings.route_hints_enabled = true
	settings_service.settings.high_contrast_terrain = false
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Red Sand route controller is missing.")
	if route == null:
		settings_service.free()
		_finish()
		return
	route.settings_service_override = settings_service
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)

	var ship: FlightLabShip = route.get_flight_ship()
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var definition: FlightRouteDefinition = route.get_route_definition()
	_check(ship != null, "Red Sand route ship is missing.")
	_check(course != null, "Red Sand low-flight course is missing.")
	_check(feedback != null, "Red Sand environment feedback is missing.")
	_check(hud != null, "Red Sand route HUD is missing.")
	_check(definition != null, "Red Sand route definition is missing.")
	if ship == null or course == null or feedback == null or hud == null or definition == null:
		route.queue_free()
		await process_frame
		settings_service.free()
		_finish()
		return
	ship.set_physics_process(false)
	feedback.set_process(false)

	_test_fixed_course_structure(course)
	await _enter_surface_route(route, ship, definition)
	_test_accessibility_defaults(course, hud)
	await _test_high_route_lock(route, ship, course, feedback, hud)
	await _test_cover_breaks_lock(route, ship, course, feedback, hud)
	_test_accessibility_toggles(course, settings_service)
	_test_checkpoint_reset(route, course, hud)

	route.queue_free()
	await process_frame
	settings_service.free()
	_finish()


func _test_fixed_course_structure(course: RedSandLowFlightCourse) -> void:
	_check(course.validate().is_empty(), "Low-flight course validation failed.")
	_check(
		course.get_obstacle_count() == 6
		and course.get_radar_sectors().size() == 3
		and course.get_radar_covers().size() == 3,
		"T-042 needs six fixed obstacles, three radar sectors, and three covers."
	)
	var collision_geometry: Node = course.get_node_or_null("CollisionGeometry")
	_check(collision_geometry != null, "Canyon collision geometry is missing.")
	if collision_geometry == null:
		return
	for obstacle: Node in collision_geometry.get_children():
		if obstacle is StaticBody2D:
			_check(
				(obstacle as StaticBody2D).collision_layer
				== FlightWeaponRules.WORLD_COLLISION_LAYER,
				"Canyon obstacle '%s' is not on the world collision layer."
				% obstacle.name
			)
	var high_route_y: float = 70.0
	for obstacle: Node in collision_geometry.get_children():
		if not obstacle is StaticBody2D:
			continue
		var collision: CollisionPolygon2D = obstacle.get_node_or_null(
			"CollisionPolygon2D"
		) as CollisionPolygon2D
		if collision == null:
			continue
		for point: Vector2 in collision.polygon:
			_check(
				point.y > high_route_y,
				"Fixed obstacle '%s' closes the intended high-risk fast corridor."
				% obstacle.name
			)


func _enter_surface_route(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition
) -> void:
	var surface_segment: FlightRouteSegment = definition.segments[SURFACE_SEGMENT_INDEX]
	ship.position = Vector2(
		route.route_origin_x + surface_segment.start_distance + 1200.0,
		390.0
	)
	ship.velocity = Vector2.ZERO
	_check(route.advance_route_state(), "Surface-route boundary was not detected.")
	_check(
		route.get_active_segment_index() == SURFACE_SEGMENT_INDEX
		and ship.get_checkpoint_id() == surface_segment.checkpoint_id,
		"Low-flight course did not begin at the surface checkpoint."
	)
	var camera: Camera2D = route.get_flight_camera()
	if camera != null:
		camera.position = ship.position
	route._physics_process(1.0 / 60.0)
	await process_frame


func _test_accessibility_defaults(
	course: RedSandLowFlightCourse,
	hud: RedSandRouteHUD
) -> void:
	_check(
		course.are_route_hints_visible()
		and not course.is_high_contrast_enabled(),
		"Default route hints or high-contrast terrain state is incorrect."
	)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.LOW_PROFILE
		and is_zero_approx(course.get_lock_risk())
		and hud.get_radar_text().contains("贴地轮廓")
		and VIEWPORT_RECT.encloses(hud.get_radar_rect())
		and not hud.has_visible_mouse_interception(),
		"Low-profile radar HUD must be readable inside 640x360 without blocking input."
	)


func _test_high_route_lock(
	route: RedSandFlight,
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	feedback: RedSandEnvironmentFeedback,
	hud: RedSandRouteHUD
) -> void:
	var hull_before: float = ship.hull
	var shield_before: float = ship.shield
	var cargo_before: float = ship.cargo_integrity
	var checkpoint_before: StringName = ship.get_checkpoint_id()
	ship.position = course.global_position + Vector2(1800.0, 190.0)
	var camera: Camera2D = route.get_flight_camera()
	if camera != null:
		camera.position = ship.position
	route._physics_process(2.0)
	_check(
		course.is_locked()
		and is_equal_approx(course.get_lock_risk(), 1.0)
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.LOCKED
		and hud.get_radar_text().contains("已锁定")
		and hud.get_status_text().contains("不含隐私")
		and feedback.is_radar_pressure_visible()
		and is_equal_approx(feedback.get_radar_pressure(), 1.0),
		"High route did not produce a readable fixed-sector radar lock."
	)
	_check(
		is_equal_approx(ship.hull, hull_before)
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before)
		and ship.get_checkpoint_id() == checkpoint_before
		and route.get_active_segment_index() == SURFACE_SEGMENT_INDEX
		and not route.is_route_completed(),
		"Radar pressure must not become combat damage or change route/story outcome."
	)
	await process_frame
	await process_frame


func _test_cover_breaks_lock(
	route: RedSandFlight,
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	feedback: RedSandEnvironmentFeedback,
	hud: RedSandRouteHUD
) -> void:
	var pipeline_cover: FlightRadarCover = null
	for cover: FlightRadarCover in course.get_radar_covers():
		if cover.cover_id == &"red_sand_cover_pipeline":
			pipeline_cover = cover
			break
	_check(pipeline_cover != null, "Pipeline terrain cover is missing.")
	if pipeline_cover == null:
		return
	ship.global_position = pipeline_cover.global_position
	var camera: Camera2D = route.get_flight_camera()
	if camera != null:
		camera.position = ship.position
	route._physics_process(0.1)
	_check(
		not course.is_locked()
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.COVERED
		and course.get_active_cover_id() == &"red_sand_cover_pipeline"
		and course.get_lock_risk() < 1.0
		and hud.get_radar_text().contains("地形遮挡")
		and hud.get_status_text().contains("切断雷达锁定")
		and feedback.is_radar_pressure_visible(),
		"Pipeline terrain cover did not visibly break and decay radar lock."
	)
	route._physics_process(2.0)
	_check(
		is_zero_approx(course.get_lock_risk())
		and not feedback.is_radar_pressure_visible(),
		"Terrain cover did not fully clear residual radar pressure."
	)
	await process_frame
	await process_frame


func _test_accessibility_toggles(
	course: RedSandLowFlightCourse,
	settings_service: SettingsServiceModel
) -> void:
	settings_service.settings.route_hints_enabled = false
	settings_service.settings.high_contrast_terrain = true
	course.refresh_accessibility()
	var outlines: Array[Node] = course.find_children(
		"ContrastOutline",
		"Line2D",
		true,
		false
	)
	var all_outlines_visible: bool = not outlines.is_empty()
	for outline: Node in outlines:
		all_outlines_visible = all_outlines_visible and (outline as Line2D).visible
	_check(
		not course.are_route_hints_visible()
		and course.is_high_contrast_enabled()
		and all_outlines_visible,
		"Route-hint and high-contrast terrain settings did not affect course visuals."
	)
	settings_service.settings.route_hints_enabled = true
	settings_service.settings.high_contrast_terrain = false
	course.refresh_accessibility()


func _test_checkpoint_reset(
	route: RedSandFlight,
	course: RedSandLowFlightCourse,
	hud: RedSandRouteHUD
) -> void:
	_check(route.restart_from_checkpoint(false), "Surface checkpoint could not be restored.")
	_check(
		is_zero_approx(course.get_lock_risk())
		and not course.is_locked()
		and course.get_active_sector_id().is_empty()
		and hud.get_radar_text().contains("贴地轮廓"),
		"Checkpoint reset did not clear radar state and restore low-flight feedback."
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[red-sand-low-flight] PASS: fixed canyon routes, high-route radar pressure, "
			+ "terrain-cover lock breaks, accessibility visuals, and non-combat outcomes."
		)
		quit(0)
		return
	printerr("[red-sand-low-flight] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
