extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const STAGE_SIX_INDEX: int = 5
const STAGE_SEVEN_INDEX: int = 6
const STAGE_EIGHT_INDEX: int = 7
const REFERENCE_POINT_OFFSET_Y: float = 8.0
const STEP_SECONDS: float = 1.0 / 60.0
const MAX_FULL_ROUTE_FRAMES: int = 9000

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var route: RedSandFlight = await _create_route()
	if route == null:
		_finish()
		return
	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var provider: FlightAltitudeReferenceProvider = route.get_altitude_reference_provider()
	var route_geometry: RedSandRouteVisuals = route.get_node(
		"World/RouteGeometry"
	) as RedSandRouteVisuals
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	_check(
		ship != null
		and definition != null
		and provider != null
		and route_geometry != null
		and course != null
		and landing_zone != null,
		"Round 6 surface-frame smoke is missing route dependencies."
	)
	if (
		ship == null
		or definition == null
		or provider == null
		or route_geometry == null
		or course == null
		or landing_zone == null
	):
		route.queue_free()
		await process_frame
		_finish()
		return

	Input.action_press(&"flight_throttle")
	# Early fixed hazards and CharacterBody collision are covered elsewhere. This
	# regression uses the real Input Map and explicit velocity/position integration
	# so the entire pre-surface gravity path is deterministic and isolated.
	var crossed_stage_six: bool = false
	var transition_preserved_ship_state: bool = false
	var stage_six_ship_y: float = 0.0
	var stage_six_vertical_speed: float = 0.0
	for _frame_index: int in MAX_FULL_ROUTE_FRAMES:
		ship.integrate_motion(
			Input.get_action_strength(FlightLabShip.THROTTLE_ACTION),
			Input.get_action_strength(FlightLabShip.BRAKE_ACTION),
			Input.get_axis(
				FlightLabShip.PITCH_UP_ACTION,
				FlightLabShip.PITCH_DOWN_ACTION
			),
			STEP_SECONDS,
			Input.get_action_strength(FlightLabShip.BOOST_ACTION)
		)
		ship.position += ship.velocity * STEP_SECONDS
		var position_before_transition: Vector2 = ship.position
		var velocity_before_transition: Vector2 = ship.velocity
		var rotation_before_transition: float = ship.rotation
		var changed: bool = route.advance_route_state()
		if changed and route.get_active_segment_index() == STAGE_SIX_INDEX:
			crossed_stage_six = true
			stage_six_ship_y = ship.position.y
			stage_six_vertical_speed = ship.velocity.y
			transition_preserved_ship_state = (
				ship.position == position_before_transition
				and ship.velocity == velocity_before_transition
				and is_equal_approx(ship.rotation, rotation_before_transition)
			)
		route._physics_process(STEP_SECONDS)
		if crossed_stage_six:
			break
	Input.action_release(&"flight_throttle")

	var surface_offset: float = route.get_surface_frame_offset_y()
	var stage_six_base_ground: float = definition.get_ground_route_y(
		definition.segments[STAGE_SIX_INDEX].start_distance,
		STAGE_SIX_INDEX
	)
	var stage_six_altitude: float = provider.get_altitude_meters()
	var stage_five_label: Label = route_geometry.get_node_or_null(
		"StageLabel05"
	) as Label
	var stage_six_label: Label = route_geometry.get_node_or_null(
		"StageLabel06"
	) as Label
	_check(
		crossed_stage_six
		and transition_preserved_ship_state
		and route.is_surface_frame_acquired()
		and route.is_surface_frame_locked()
		and surface_offset > 0.0
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and provider.get_source_name() == &"PROFILE"
		and stage_six_altitude
		>= definition.surface_frame_minimum_entry_altitude_meters
		and ship.get_checkpoint_id()
		== definition.segments[STAGE_SIX_INDEX].checkpoint_id,
		"Full-route limited-assist descent did not enter Stage 6 with a valid checkpoint: %s"
		% route.get_altitude_diagnostic_snapshot()
	)
	_check(
		is_equal_approx(route_geometry.get_surface_frame_offset_y(), surface_offset)
		and is_equal_approx(course.get_surface_frame_offset_y(), surface_offset)
		and is_equal_approx(landing_zone.get_surface_frame_offset_y(), surface_offset)
		and stage_five_label != null
		and stage_six_label != null
		and absf(
			stage_six_label.position.y
			- stage_five_label.position.y
			- surface_offset
		) < 0.01
		and absf(
			provider.ground_route_y - (stage_six_base_ground + surface_offset)
		) < 1.0,
		"Terrain visuals, collision, radar, landing, and profile did not share one offset."
	)

	for _sync_frame: int in 5:
		await physics_frame
		route._physics_process(STEP_SECONDS)
	_check(
		provider.terrain_hit_valid
		and provider.cross_source_consistency_valid
		and provider.ray_profile_difference_meters
		<= provider.ray_profile_tolerance_meters,
		"Physics terrain did not converge to the locked profile in the bounded sync window: %s"
		% route.get_altitude_diagnostic_snapshot()
	)

	ship.position += Vector2(180.0, 60.0)
	var restored_stage_six: bool = route.restart_from_checkpoint(false)
	_check(
		restored_stage_six
		and is_equal_approx(route.get_surface_frame_offset_y(), surface_offset)
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid(),
		"Stage 6 retry did not preserve the locked surface frame."
	)

	for target_index: int in [STAGE_SEVEN_INDEX, STAGE_EIGHT_INDEX]:
		var target_segment: FlightRouteSegment = definition.segments[target_index]
		var base_ground_y: float = definition.get_ground_route_y(
			target_segment.start_distance + 1.0,
			target_index
		)
		ship.position = Vector2(
			route.route_origin_x + target_segment.start_distance + 1.0,
			base_ground_y + surface_offset - 500.0 - REFERENCE_POINT_OFFSET_Y
		)
		ship.velocity = Vector2(140.0, 0.0)
		_check(
			route.advance_route_state(),
			"Route did not advance to Stage %d." % (target_index + 1)
		)
		await physics_frame
		route._physics_process(STEP_SECONDS)
		_check(
			provider.has_numeric_altitude()
			and provider.is_current_source_valid()
			and provider.cross_source_consistency_valid
			and route.get_active_segment_index() == target_index
			and ship.get_checkpoint_id() == target_segment.checkpoint_id,
			"Stage %d inherited an invalid surface frame/checkpoint: %s"
			% [target_index + 1, route.get_altitude_diagnostic_snapshot()]
		)

	var restored_stage_eight: bool = route.restart_from_checkpoint(false)
	_check(
		restored_stage_eight
		and route.get_active_segment_index() == STAGE_EIGHT_INDEX
		and is_equal_approx(route.get_surface_frame_offset_y(), surface_offset)
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and absf(provider.get_altitude_meters() - 600.0) < 1.0,
		"Stage 8 safe retry did not restore 4 km / 600 m in the locked frame: %s"
		% route.get_altitude_diagnostic_snapshot()
	)

	print(
		(
			"[gate-c-round-6-surface-frame] stage6_ship_y=%.2f vertical_speed=%.2f "
			+ "offset=%.2f entry_agl=%.2f predicted=%.2f source=%s"
		)
		% [
			stage_six_ship_y,
			stage_six_vertical_speed,
			surface_offset,
			stage_six_altitude,
			route.get_surface_frame_predicted_entry_altitude_meters(),
			provider.get_source_name(),
		]
	)
	route.queue_free()
	await process_frame
	_finish()


func _create_route() -> RedSandFlight:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Round 6 route scene could not load.")
	if packed_scene == null:
		return null
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Round 6 route root has the wrong type.")
	if route == null:
		return null
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)
	route.get_flight_ship().set_physics_process(false)
	_check(
		route.restart_from_checkpoint(false),
		"Round 6 full-route smoke could not restore its deterministic Stage 1 start."
	)
	return route


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	Input.action_release(&"flight_throttle")
	if _failures.is_empty():
		print(
			"[gate-c-round-6-surface-frame] PASS: full-route acquisition, "
			+ "shared offset, Stage 6-8 checkpoints, and retry."
		)
		quit(0)
		return
	printerr(
		"[gate-c-round-6-surface-frame] FAILED with %d error(s):"
		% _failures.size()
	)
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
