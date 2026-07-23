extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const RADAR_SEGMENT_INDEX: int = 5
const PREPARATION_SEGMENT_INDEX: int = 6
const LANDING_SEGMENT_INDEX: int = 7

var _failures: Array[String] = []


class AltitudeProviderStub:
	extends Node

	var numeric_altitude_available: bool = true
	var altitude_meters: float = 450.0

	func has_numeric_altitude() -> bool:
		return numeric_altitude_available

	func get_display_altitude_meters() -> float:
		return altitude_meters

	func get_radar_altitude_meters() -> float:
		return altitude_meters


func _initialize() -> void:
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
	var altitude_provider: AltitudeProviderStub = AltitudeProviderStub.new()
	route.add_child(altitude_provider)
	route.settings_service_override = settings_service
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)

	var ship: FlightLabShip = route.get_flight_ship()
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var environment_feedback: RedSandEnvironmentFeedback = (
		route.get_environment_feedback()
	)
	var definition: FlightRouteDefinition = route.get_route_definition()
	_check(ship != null, "Red Sand route ship is missing.")
	_check(course != null, "Red Sand low-altitude radar course is missing.")
	_check(environment_feedback != null, "Red Sand environment feedback is missing.")
	_check(definition != null, "Red Sand route definition is missing.")
	if (
		ship == null
		or course == null
		or environment_feedback == null
		or definition == null
	):
		route.queue_free()
		await process_frame
		settings_service.free()
		_finish()
		return
	ship.set_physics_process(false)
	_test_fixed_course_structure(course)
	await _enter_radar_segment(route, ship, definition)
	_test_world_altitude_ignores_facility_roofs(route, ship, course)
	_check(
		course.bind(
			ship,
			route.route_origin_x,
			settings_service,
			altitude_provider
		),
		"Low-altitude radar course rejected the numeric altitude provider."
	)
	_test_accessibility(course, settings_service)
	_test_missing_altitude_is_clear(ship, course, altitude_provider)
	_test_high_altitude_is_safe(ship, course, altitude_provider)
	_test_low_altitude_state_timing(
		ship,
		course,
		environment_feedback,
		altitude_provider
	)
	_test_high_altitude_clears_warning(ship, course, altitude_provider)
	_test_stage_end_clears_radar(
		route,
		ship,
		course,
		environment_feedback,
		altitude_provider,
		definition
	)

	route.queue_free()
	await process_frame
	settings_service.free()
	_finish()


func _test_fixed_course_structure(course: RedSandLowFlightCourse) -> void:
	_check(course.validate().is_empty(), "Low-altitude radar course validation failed.")
	_check(
		course.active_segment_id == &"red_sand_low_altitude_control"
		and is_equal_approx(course.surface_start_route_distance, 23000.0)
		and is_equal_approx(course.get_radar_exit_route_distance(), 30500.0)
		and is_equal_approx(course.minimum_safe_altitude_meters, 300.0),
		"Course boundaries or the centralized 300 m threshold are incorrect."
	)
	_check(
		course.get_obstacle_count() == 6
		and course.get_radar_sectors().size() >= 2
		and course.get_radar_covers().is_empty()
		and course.find_children("*", "FlightRadarCover", true, false).is_empty(),
		"Replacement course must retain obstacles and fixed sectors without terrain-cover rules."
	)
	var high_route_line: Line2D = course.get_node_or_null(
		"RouteHints/HighAltitudeSafeRouteLine"
	) as Line2D
	_check(high_route_line != null, "High-altitude safe-route hint is missing.")
	for sector: FlightRadarSector in course.get_radar_sectors():
		var scan_band: Polygon2D = sector.get_node_or_null("ScanBand") as Polygon2D
		var sweep_line: Line2D = sector.get_node_or_null("SweepLine") as Line2D
		var scan_starts_at_boundary: bool = scan_band != null
		var scan_reaches_ground: bool = scan_band != null
		if scan_band != null:
			for point: Vector2 in scan_band.polygon:
				scan_starts_at_boundary = (
					scan_starts_at_boundary and point.y >= sector.safe_boundary_y
				)
				scan_reaches_ground = (
					scan_reaches_ground
					and point.y <= sector.emitter_y
				)
		_check(
			sector.safe_boundary_y < sector.emitter_y
			and scan_starts_at_boundary
			and scan_reaches_ground
			and sweep_line != null
			and sweep_line.points.size() == 2
			and is_equal_approx(sweep_line.points[0].y, sector.emitter_y)
			and is_equal_approx(sweep_line.points[1].y, sector.safe_boundary_y),
			"Radar sector '%s' does not scan upward from ground to the low-altitude boundary."
			% sector.sector_id
		)
	if high_route_line != null:
		for point: Vector2 in high_route_line.points:
			_check(
				point.y < course.get_radar_sectors()[0].safe_boundary_y,
				"Safe-route hint descends into the low-altitude scan band."
			)


func _enter_radar_segment(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition
) -> void:
	var radar_segment: FlightRouteSegment = definition.segments[RADAR_SEGMENT_INDEX]
	_check(
		radar_segment.id == &"red_sand_low_altitude_control",
		"Stage 6 does not use the low-altitude-control segment ID."
	)
	ship.position = Vector2(
		route.route_origin_x + radar_segment.start_distance + 900.0,
		120.0
	)
	ship.velocity = Vector2.ZERO
	_check(route.advance_route_state(), "Stage 6 boundary was not detected.")
	_check(
		route.get_active_segment_index() == RADAR_SEGMENT_INDEX
		and course_is_active(route.get_low_flight_course()),
		"Low-altitude radar did not become active only in stage 6."
	)
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	for sector: FlightRadarSector in course.get_radar_sectors():
		_check(
			sector.is_scan_visual_visible(),
			"Fixed radar sector '%s' is not visible during stage 6." % sector.sector_id
		)
	for _sync_frame: int in 5:
		await physics_frame
		route._physics_process(0.0)


func course_is_active(course: RedSandLowFlightCourse) -> bool:
	return (
		course != null
		and course.is_radar_active()
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR
	)


func _test_world_altitude_ignores_facility_roofs(
	route: RedSandFlight,
	ship: FlightLabShip,
	course: RedSandLowFlightCourse
) -> void:
	var provider: FlightAltitudeReferenceProvider = (
		route.get_altitude_reference_provider()
	)
	var pipeline_test_x: float = course.to_global(Vector2(7000.0, 0.0)).x
	var pipeline_route_distance: float = pipeline_test_x - route.route_origin_x
	var ground_y: float = (
		route.get_route_definition().get_ground_route_y(
			pipeline_route_distance,
			RADAR_SEGMENT_INDEX
		)
		+ route.get_surface_frame_offset_y()
	)
	ship.global_position = Vector2(
		pipeline_test_x,
		ground_y - 700.0 - 8.0
	)
	route.advance_route_state()
	route._physics_process(0.25)
	var altitude_meters: float = provider.get_radar_altitude_meters()
	_check(
		provider.terrain_hit_valid
		and altitude_meters > 500.0
		and altitude_meters < 1000.0
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR,
		(
			"Facility roofs polluted the shared ground AGL or falsely triggered radar "
			+ "(altitude=%.1f, hit=%s, state=%d)."
		)
		% [
			altitude_meters,
			provider.terrain_hit_valid,
			course.get_radar_state(),
		]
	)


func _test_accessibility(
	course: RedSandLowFlightCourse,
	settings_service: SettingsServiceModel
) -> void:
	_check(
		course.are_route_hints_visible()
		and not course.is_high_contrast_enabled(),
		"Default route hints or high-contrast terrain state is incorrect."
	)
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
		"Accessibility toggles did not affect course hints and terrain outlines."
	)
	settings_service.settings.route_hints_enabled = true
	settings_service.settings.high_contrast_terrain = false
	course.refresh_accessibility()


func _test_missing_altitude_is_clear(
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	altitude_provider: AltitudeProviderStub
) -> void:
	var shield_before: float = ship.shield
	var cargo_before: float = ship.cargo_integrity
	altitude_provider.numeric_altitude_available = false
	altitude_provider.altitude_meters = 80.0
	course.step_physics(3.0)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR
		and is_zero_approx(course.get_lock_risk())
		and course.get_pulse_count() == 0
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Missing numeric AGL data must stay CLEAR and never punish the ship."
	)


func _test_high_altitude_is_safe(
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	altitude_provider: AltitudeProviderStub
) -> void:
	var shield_before: float = ship.shield
	var cargo_before: float = ship.cargo_integrity
	altitude_provider.numeric_altitude_available = true
	altitude_provider.altitude_meters = 450.0
	course.step_physics(4.0)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR
		and is_zero_approx(course.get_lock_risk())
		and course.get_pulse_count() == 0
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"High flight at or above 300 m did not remain completely safe."
	)


func _test_low_altitude_state_timing(
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	environment_feedback: RedSandEnvironmentFeedback,
	altitude_provider: AltitudeProviderStub
) -> void:
	course.reset_for_checkpoint()
	altitude_provider.altitude_meters = 180.0
	var shield_before: float = ship.shield
	var hull_before: float = ship.hull
	var cargo_before: float = ship.cargo_integrity
	var feedback_pulses_before: int = environment_feedback.get_radar_pulse_count()
	course.step_physics(course.warning_seconds - 0.01)
	_check(
		course.get_radar_state()
		== RedSandLowFlightCourse.RadarState.LOW_ALTITUDE_WARNING
		and course.get_lock_risk() > 0.9
		and course.get_pulse_count() == 0,
		"Low altitude did not remain in the approximately one-second warning phase."
	)
	course.step_physics(0.02)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.LOCKED
		and course.is_locked()
		and course.get_pulse_count() == 0,
		"Warning did not visibly escalate to LOCKED before the pulse."
	)
	course.step_physics(course.locked_seconds - 0.02)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.LOCKED
		and course.get_pulse_count() == 0,
		"LOCKED emitted its consequence before the configured lock delay."
	)
	course.step_physics(0.03)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.PULSE
		and course.get_pulse_count() == 1
		and environment_feedback.get_radar_pulse_count()
		== feedback_pulses_before + 1
		and environment_feedback.is_radar_pulse_visible()
		and environment_feedback.get_radar_pulse_audio() != null
		and environment_feedback.get_radar_pulse_audio().stream != null
		and is_equal_approx(ship.shield, shield_before - course.lock_damage)
		and is_equal_approx(ship.hull, hull_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Shielded PULSE did not apply exactly one shield-only consequence."
	)
	course.step_physics(course.pulse_seconds)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.COOLDOWN,
		"PULSE did not enter the configured cooldown phase."
	)
	var first_cooldown_elapsed: float = course.get_state_elapsed_seconds()
	course.step_physics(0.6)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.COOLDOWN
		and course.get_pulse_count() == 1,
		"Sustained low flight retriggered during cooldown."
	)
	var cooldown_remaining: float = maxf(
		course.cooldown_seconds - first_cooldown_elapsed - 0.6,
		0.0
	)
	course.step_physics(
		cooldown_remaining
		+ course.warning_seconds
		+ course.locked_seconds
		+ 0.01
	)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.PULSE
		and course.get_pulse_count() == 2
		and environment_feedback.get_radar_pulse_count()
		== feedback_pulses_before + 2
		and is_equal_approx(ship.shield, shield_before - course.lock_damage * 2.0)
		and is_equal_approx(ship.hull, hull_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Sustained low flight did not retrigger once after a full cooldown."
	)

	course.reset_for_checkpoint()
	ship.shield = 0.0
	var unshielded_hull: float = ship.hull
	var unshielded_cargo: float = ship.cargo_integrity
	course.step_physics(course.warning_seconds + course.locked_seconds + 0.01)
	_check(
		course.get_pulse_count() == 1
		and is_equal_approx(ship.hull, unshielded_hull - course.lock_damage)
		and is_equal_approx(
			ship.cargo_integrity,
			unshielded_cargo - course.lock_cargo_damage
		),
		"Unshielded radar pulse did not damage hull and cargo exactly once."
	)


func _test_high_altitude_clears_warning(
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	altitude_provider: AltitudeProviderStub
) -> void:
	course.reset_for_checkpoint()
	altitude_provider.altitude_meters = 200.0
	course.step_physics(0.55)
	_check(
		course.get_radar_state()
		== RedSandLowFlightCourse.RadarState.LOW_ALTITUDE_WARNING,
		"Low-altitude warning setup failed."
	)
	var shield_before: float = ship.shield
	var cargo_before: float = ship.cargo_integrity
	altitude_provider.altitude_meters = 420.0
	course.step_physics(0.01)
	course.step_physics(3.0)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR
		and is_zero_approx(course.get_lock_risk())
		and course.get_pulse_count() == 0
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Climbing to safe altitude did not immediately clear warning without punishment."
	)


func _test_stage_end_clears_radar(
	route: RedSandFlight,
	ship: FlightLabShip,
	course: RedSandLowFlightCourse,
	environment_feedback: RedSandEnvironmentFeedback,
	altitude_provider: AltitudeProviderStub,
	definition: FlightRouteDefinition
) -> void:
	course.reset_for_checkpoint()
	altitude_provider.altitude_meters = 160.0
	course.step_physics(course.warning_seconds + 0.1)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.LOCKED,
		"Stage-end cleanup test could not establish a radar lock."
	)
	course.step_physics(course.locked_seconds)
	_check(
		course.get_radar_state() == RedSandLowFlightCourse.RadarState.PULSE
		and environment_feedback.is_radar_pulse_visible(),
		"Stage-end cleanup test could not establish pulse feedback."
	)
	var preparation_segment: FlightRouteSegment = definition.segments[
		PREPARATION_SEGMENT_INDEX
	]
	_check(
		preparation_segment.id == &"red_sand_landing_preparation",
		"Stage 7 does not use the landing-preparation segment ID."
	)
	ship.position.x = route.route_origin_x + preparation_segment.start_distance + 1.0
	_check(route.advance_route_state(), "Stage 7 boundary was not detected.")
	var shield_before: float = ship.shield
	var cargo_before: float = ship.cargo_integrity
	course.step_physics(5.0)
	_check(
		route.get_active_segment_index() == PREPARATION_SEGMENT_INDEX
		and not course.is_radar_active()
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.INACTIVE
		and is_zero_approx(course.get_lock_risk())
		and course.get_active_sector_id().is_empty()
		and not course.are_route_hints_visible()
		and not environment_feedback.is_radar_pulse_visible()
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Stage 7 did not fully clear and disable the radar."
	)
	for sector: FlightRadarSector in course.get_radar_sectors():
		_check(
			not sector.is_scan_visual_visible(),
			"Radar sector '%s' remained visible in stage 7." % sector.sector_id
		)

	var landing_segment: FlightRouteSegment = definition.segments[LANDING_SEGMENT_INDEX]
	_check(
		landing_segment.id == &"red_sand_landing_approach",
		"Stage 8 does not retain the landing-approach segment ID."
	)
	ship.position.x = route.route_origin_x + landing_segment.start_distance + 1.0
	_check(route.advance_route_state(), "Stage 8 boundary was not detected.")
	course.step_physics(5.0)
	_check(
		route.get_active_segment_index() == LANDING_SEGMENT_INDEX
		and not course.is_radar_active()
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.INACTIVE
		and is_zero_approx(course.get_lock_risk())
		and is_equal_approx(ship.shield, shield_before)
		and is_equal_approx(ship.cargo_integrity, cargo_before),
		"Stage 8 reactivated radar pressure or consequences."
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[red-sand-low-flight] PASS: low-altitude warning/lock/pulse/cooldown, "
			+ "high-altitude safety, provider fallback, no cover rule, and stage cleanup."
		)
		quit(0)
		return
	printerr("[red-sand-low-flight] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
