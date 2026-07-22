extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const STEP_SECONDS: float = 1.0 / 60.0
const NOMINAL_ROUTE_SPEED: float = 316.6666667
const RADAR_SEGMENT_INDEX: int = 5
const PREPARATION_SEGMENT_INDEX: int = 6

var _failures: Array[String] = []
var _real_input_minimum_altitude: float = INF


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Gate C Round 4 route scene could not load.")
	if packed_scene == null:
		_finish()
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Gate C Round 4 route controller is missing.")
	if route == null:
		_finish()
		return
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)
	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var visuals: RedSandRouteVisuals = route.get_node_or_null(
		"World/RouteGeometry"
	) as RedSandRouteVisuals
	var provider: FlightAltitudeReferenceProvider = (
		route.get_altitude_reference_provider()
	)
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	_check(ship != null, "Gate C Round 4 ship is missing.")
	_check(definition != null, "Gate C Round 4 route data is missing.")
	_check(visuals != null, "Gate C Round 4 visual controller is missing.")
	_check(provider != null, "Gate C Round 4 altitude provider is missing.")
	_check(course != null, "Gate C Round 4 radar course is missing.")
	_check(landing_zone != null, "Gate C Round 4 landing zone is missing.")
	_check(feedback != null, "Gate C Round 4 environment feedback is missing.")
	if (
		ship == null
		or definition == null
		or visuals == null
		or provider == null
		or course == null
		or landing_zone == null
		or feedback == null
	):
		route.queue_free()
		await process_frame
		_finish()
		return
	ship.set_physics_process(false)
	await _test_consecutive_orbit_entry_frames(visuals, feedback)
	await _test_real_input_descends_below_radar_threshold(
		route,
		ship,
		definition,
		provider
	)
	await _test_live_agl_and_radar(route, ship, definition, provider, course)
	await _test_stage_seven_three_height_traversal(
		route,
		ship,
		definition,
		visuals
	)
	_test_effect_lifecycle(route, ship, landing_zone, feedback)
	print(
		(
			"[gate-c-round-4] measured orbit-entry=%.0fm/%.2fs, radar-safe=%.0fm, "
			+ "input-min=%.0fm, stage7=%.0fm, stage8-entry=%.0fm/%.0fm"
		)
		% [
			RedSandOrbitTransitionModel.TRANSITION_WINDOW_DISTANCE,
			RedSandOrbitTransitionModel.get_nominal_duration_seconds(
				NOMINAL_ROUTE_SPEED
			),
			course.get_minimum_safe_altitude_meters(),
			_real_input_minimum_altitude,
			definition.segments[PREPARATION_SEGMENT_INDEX].get_length(),
			landing_zone.get_landing_center_route_distance()
			- definition.segments[-1].start_distance,
			landing_zone.get_recommended_entry_altitude_meters(),
		]
	)
	route.queue_free()
	await process_frame
	_finish()


func _test_real_input_descends_below_radar_threshold(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition,
	provider: FlightAltitudeReferenceProvider
) -> void:
	var segment: FlightRouteSegment = definition.segments[RADAR_SEGMENT_INDEX]
	var route_distance: float = 24000.0
	var profile_ground_y: float = definition.get_altitude_reference_y(route_distance)
	ship.position = Vector2(
		route.route_origin_x + route_distance,
		profile_ground_y - 600.0
	)
	ship.velocity = Vector2(140.0, 0.0)
	ship.rotation = 0.0
	ship.angular_velocity = 0.0
	ship.is_failed = false
	ship.is_landed = false
	route.advance_route_state()
	provider.reset_to_route_state_from_world(
		RADAR_SEGMENT_INDEX,
		segment.get_progress(route_distance),
		ship,
		profile_ground_y
	)
	_real_input_minimum_altitude = provider.get_altitude_meters()
	Input.action_press(&"flight_throttle")
	Input.action_press(&"flight_pitch_down")
	var crossed_threshold: bool = false
	for _frame_index: int in 480:
		ship._physics_process(STEP_SECONDS)
		route.advance_route_state()
		route._physics_process(STEP_SECONDS)
		await physics_frame
		if provider.has_numeric_altitude():
			_real_input_minimum_altitude = minf(
				_real_input_minimum_altitude,
				provider.get_altitude_meters()
			)
		if (
			provider.has_numeric_altitude()
			and provider.get_altitude_meters() < 280.0
		):
			crossed_threshold = true
			break
	Input.action_release(&"flight_pitch_down")
	Input.action_release(&"flight_throttle")
	_check(
		crossed_threshold
		and provider.get_mode_name() == &"AGL"
		and provider.altitude_source_valid,
		"Real Input Map pitch/throttle could not descend from 600 m below the 300 m radar threshold (minimum %.1f m)."
		% _real_input_minimum_altitude
	)
func _test_consecutive_orbit_entry_frames(
	visuals: RedSandRouteVisuals,
	feedback: RedSandEnvironmentFeedback
) -> void:
	var frame_distance: float = NOMINAL_ROUTE_SPEED * STEP_SECONDS
	var previous_position: Vector2 = Vector2.ZERO
	var previous_scale: float = 0.0
	var previous_alpha: float = 1.0
	var previous_progress: float = -1.0
	var previous_stars_alpha: float = 1.0
	var maximum_position_step: float = 0.0
	var maximum_scale_step: float = 0.0
	var maximum_alpha_step: float = 0.0
	var frame_index: int = 0
	var distance: float = RedSandOrbitTransitionModel.TRANSITION_START_DISTANCE
	visuals.reset_to_distance(distance)
	while distance <= RedSandOrbitTransitionModel.TRANSITION_END_DISTANCE + 0.001:
		visuals.update_visuals(distance, STEP_SECONDS)
		var progress: float = visuals.get_orbit_to_atmosphere_visual_progress()
		feedback.set_orbit_to_atmosphere_visual_progress(progress)
		var planet_position: Vector2 = visuals.get_planet_position()
		var planet_scale: float = visuals.get_planet_scale()
		var planet_alpha: float = visuals.get_planet_alpha()
		var stars_alpha: float = visuals.get_far_stars_alpha()
		_check(
			visuals.get_atmosphere_horizon_position().distance_to(
				planet_position
			) < 0.001
			and absf(
				visuals.get_atmosphere_horizon_scale() - planet_scale
			) < 0.001,
			"Disc and curved horizon stopped sharing one geometric transform."
		)
		if frame_index > 0:
			maximum_position_step = maxf(
				maximum_position_step,
				previous_position.distance_to(planet_position)
			)
			maximum_scale_step = maxf(
				maximum_scale_step,
				absf(previous_scale - planet_scale)
			)
			maximum_alpha_step = maxf(
				maximum_alpha_step,
				absf(previous_alpha - planet_alpha)
			)
			_check(
				progress + 0.000001 >= previous_progress
				and stars_alpha <= previous_stars_alpha + 0.000001,
				"Shared visual progress or star fade rewound between consecutive frames."
			)
		previous_position = planet_position
		previous_scale = planet_scale
		previous_alpha = planet_alpha
		previous_progress = progress
		previous_stars_alpha = stars_alpha
		frame_index += 1
		distance += frame_distance
	visuals.update_visuals(RedSandOrbitTransitionModel.TRANSITION_END_DISTANCE)
	_check(
		maximum_position_step < 1.2
		and maximum_scale_step < 0.03
		and maximum_alpha_step < 0.08,
		"Consecutive entry frames exceeded normal transform/alpha deltas: %.3f / %.4f / %.4f"
		% [maximum_position_step, maximum_scale_step, maximum_alpha_step]
	)
	_check(
		RedSandOrbitTransitionModel.TRANSITION_WINDOW_DISTANCE >= 3000.0
		and RedSandOrbitTransitionModel.TRANSITION_WINDOW_DISTANCE <= 4500.0
		and RedSandOrbitTransitionModel.get_nominal_duration_seconds(
			NOMINAL_ROUTE_SPEED
		) >= 9.0
		and RedSandOrbitTransitionModel.get_nominal_duration_seconds(
			NOMINAL_ROUTE_SPEED
		) <= 14.0
		and not visuals.is_full_planet_visible()
		and visuals.get_atmosphere_horizon_alpha() > 0.99
		and feedback.get_orbit_to_atmosphere_visual_progress() > 0.99,
		"The 3-4.5 km shared entry curve did not naturally hand the disc to the horizon."
	)
	await process_frame


func _test_live_agl_and_radar(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition,
	provider: FlightAltitudeReferenceProvider,
	course: RedSandLowFlightCourse
) -> void:
	var segment: FlightRouteSegment = definition.segments[RADAR_SEGMENT_INDEX]
	var route_distance: float = 24000.0
	var profile_ground_y: float = definition.get_altitude_reference_y(route_distance)
	ship.position.x = route.route_origin_x + route_distance
	route.advance_route_state()
	course.set_active_segment(segment.id)
	for altitude: float in [600.0, 300.0, 280.0, 150.0, 400.0]:
		ship.position.y = profile_ground_y - altitude
		await physics_frame
		provider.reset_to_route_state_from_world(
			RADAR_SEGMENT_INDEX,
			segment.get_progress(route_distance),
			ship,
			profile_ground_y
		)
		_check(
			provider.has_numeric_altitude()
			and absf(provider.get_hud_altitude_meters() - altitude) < 0.5
			and absf(provider.get_radar_altitude_meters() - altitude) < 0.5
			and provider.get_hud_altitude_meters()
			== provider.get_radar_altitude_meters(),
			"Live ground sampling did not expose one final %.0f m AGL to HUD and radar."
			% altitude
		)
		course.reset_for_checkpoint()
		if altitude >= course.minimum_safe_altitude_meters:
			course.step_physics(2.0)
			_check(
				course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR,
				"A live %.0f m AGL sample did not remain radar-safe." % altitude
			)
		elif is_equal_approx(altitude, 280.0):
			course.step_physics(0.5)
			_check(
				course.get_radar_state()
				== RedSandLowFlightCourse.RadarState.LOW_ALTITUDE_WARNING,
				"The live 280 m AGL sample did not start a low-altitude warning."
			)
		else:
			var pulse_count_before: int = course.get_pulse_count()
			course.step_physics(course.warning_seconds + course.locked_seconds + 0.01)
			_check(
				course.get_radar_state() == RedSandLowFlightCourse.RadarState.PULSE
				and course.get_pulse_count() == pulse_count_before + 1,
				"The live 150 m AGL sample did not reach one radar pulse."
			)
	ship.position.y = profile_ground_y + 20.0
	await physics_frame
	provider.reset_to_route_state_from_world(
		RADAR_SEGMENT_INDEX,
		segment.get_progress(route_distance),
		ship,
		profile_ground_y
	)
	_check(
		not provider.terrain_hit_valid
		and provider.profile_altitude_valid
		and provider.has_numeric_altitude()
		and provider.get_source_name() == &"TERRAIN_PROFILE_FALLBACK"
		and provider.get_altitude_meters()
		>= FlightAltitudeReferenceProvider.MINIMUM_VALID_AGL_METERS
		and not provider.get_failure_reason().is_empty(),
		"A ray starting inside terrain did not use the diagnosed profile fallback."
	)


func _test_stage_seven_three_height_traversal(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition,
	visuals: RedSandRouteVisuals
) -> void:
	var segment: FlightRouteSegment = definition.segments[PREPARATION_SEGMENT_INDEX]
	var start_x: float = route.route_origin_x + segment.start_distance + 1.0
	var motion_x: float = segment.get_length() - 2.0
	var ground_y: float = definition.get_altitude_reference_y(segment.start_distance)
	for altitude: float in [600.0, 280.0, 150.0]:
		ship.position = Vector2(start_x, ground_y - altitude)
		ship.velocity = Vector2.ZERO
		await physics_frame
		var collision: KinematicCollision2D = KinematicCollision2D.new()
		var blocked: bool = ship.test_move(
			ship.global_transform,
			Vector2(motion_x, 0.0),
			collision,
			0.001,
			true
		)
		_check(
			not blocked,
			"Stage 7 %.0f m route was blocked by %s (%s)."
			% [
				altitude,
				collision.get_collider().name
				if collision.get_collider() is Node
				else "<none>",
				collision.get_normal(),
			]
		)
	for stage_index: int in visuals.get_terrain_surface_stage_indices():
		var floor_body: StaticBody2D = visuals.get_node_or_null(
			"FloorBody%02d" % (stage_index + 1)
		) as StaticBody2D
		var surface_collision: CollisionShape2D = (
			floor_body.get_node_or_null("SurfaceCollision") as CollisionShape2D
			if floor_body != null
			else null
		)
		_check(
			floor_body != null
			and surface_collision != null
			and surface_collision.shape is SegmentShape2D
			and floor_body.has_meta(&"visible_geometry_path"),
			"Terrain stage %d retained a closed invisible side or lacks visible geometry."
			% (stage_index + 1)
		)
	ship.position = Vector2(start_x + 500.0, ground_y - 24.0)
	await physics_frame
	var surface_collision: KinematicCollision2D = KinematicCollision2D.new()
	var surface_blocked: bool = ship.test_move(
		ship.global_transform,
		Vector2(0.0, 40.0),
		surface_collision,
		0.001,
		true
	)
	if surface_blocked:
		ship._record_collision_diagnostics(surface_collision)
	_check(
		surface_blocked
		and ship.last_collision_object_name == &"FloorBody07"
		and String(ship.last_collision_object_path).contains("/World/RouteGeometry/FloorBody07")
		and ship.last_collision_layer
		== (
			FlightWeaponRules.WORLD_COLLISION_LAYER
			| FlightAltitudeReferenceProvider.ALTITUDE_REFERENCE_COLLISION_LAYER
		)
		and ship.last_collision_normal.y < -0.9,
		"Collision diagnostics did not name the visible Stage 7 surface and normal: %s / %s / %d / %s"
		% [
			ship.last_collision_object_name,
			ship.last_collision_object_path,
			ship.last_collision_layer,
			ship.last_collision_normal,
		]
	)


func _test_effect_lifecycle(
	route: RedSandFlight,
	ship: FlightLabShip,
	landing_zone: RedSandLandingZone,
	feedback: RedSandEnvironmentFeedback
) -> void:
	_check(
		feedback.get_node_or_null("LandingDustParticles") == null
		and feedback.get_node_or_null("LandingBurstParticles") == null,
		"Landing dust still exists in the fixed-screen EnvironmentFeedback CanvasLayer."
	)
	var dust: CPUParticles2D = landing_zone.get_node_or_null(
		"TouchdownDustParticles"
	) as CPUParticles2D
	var burst: CPUParticles2D = landing_zone.get_node_or_null(
		"TouchdownBurstParticles"
	) as CPUParticles2D
	_check(
		dust != null
		and burst != null
		and not dust.local_coords
		and not burst.local_coords
		and not landing_zone.are_touchdown_particles_emitting(),
		"World-space touchdown particles are missing or emit while the ship is static."
	)
	ship.integrate_motion(1.0, 0.0, 0.0, 0.2, 1.0)
	ship._update_engine_feedback()
	ship.set_laser_enabled(true)
	ship.begin_laser_beam()
	_check(
		not landing_zone.are_touchdown_particles_emitting(),
		"Throttle, Boost, or laser incorrectly activated pad-contact dust."
	)
	ship.cancel_held_fire(true)
	var contact: Vector2 = landing_zone.global_position + Vector2(
		180.0,
		landing_zone.get_touchdown_center_y()
	)
	landing_zone.burst_touchdown_dust(contact)
	_check(
		landing_zone.are_touchdown_particles_emitting()
		and absf(
			landing_zone.get_touchdown_effect_global_position().x - contact.x
		) < 0.1
		and is_equal_approx(
			landing_zone.get_touchdown_effect_global_position().y,
			landing_zone.global_position.y + landing_zone.get_pad_surface_y()
		),
		"Touchdown dust did not follow its real world-space contact point."
	)
	landing_zone.reset_for_checkpoint()
	_check(
		not landing_zone.are_touchdown_particles_emitting(),
		"Retry left a touchdown particle emitter or old particles alive."
	)
	landing_zone.set_active_segment(&"")
	feedback.stop_travel_feedback()
	_check(
		not landing_zone.are_touchdown_particles_emitting()
		and not feedback.are_speed_streaks_emitting()
		and not feedback.are_entry_particles_emitting()
		and not feedback.are_storm_particles_emitting(),
		"Stage exit left a world or screen-space travel effect emitting."
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[gate-c-round-4] PASS: consecutive entry geometry, live AGL/radar, "
			+ "three-height Stage 7 traversal, collision diagnostics, and effect lifecycle."
		)
		quit(0)
		return
	printerr("[gate-c-round-4] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
