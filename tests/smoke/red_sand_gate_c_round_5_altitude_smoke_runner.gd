extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const ROUTE_RESOURCE_PATH: String = "res://data/tuning/flight_route_red_sand_m0.tres"
const STAGE_FIVE_INDEX: int = 4
const STAGE_SIX_INDEX: int = 5
const STAGE_EIGHT_INDEX: int = 7
const STAGE_SIX_START_DISTANCE: float = 23000.0
const STEP_SECONDS: float = 1.0 / 60.0
const REFERENCE_POINT_OFFSET_Y: float = 8.0

const TRAJECTORIES: Array[Dictionary] = [
	{"name": "high_level", "ship_y": 60.0, "vertical_speed": 0.0},
	{"name": "mid_level", "ship_y": 280.0, "vertical_speed": 0.0},
	{"name": "low_dive", "ship_y": 510.0, "vertical_speed": 90.0},
	{"name": "rising", "ship_y": 330.0, "vertical_speed": -80.0},
	{"name": "descending", "ship_y": 330.0, "vertical_speed": 80.0},
	{"name": "vertical_zero", "ship_y": 330.0, "vertical_speed": 0.0},
	{"name": "boost", "ship_y": 210.0, "vertical_speed": -45.0},
	{"name": "no_boost", "ship_y": 240.0, "vertical_speed": 30.0},
	{"name": "short_reverse", "ship_y": 360.0, "vertical_speed": 0.0},
	{"name": "checkpoint_restore", "ship_y": 300.0, "vertical_speed": -20.0},
	{"name": "route_restart", "ship_y": 180.0, "vertical_speed": 20.0},
]

var _failures: Array[String] = []
var _matrix_initial_altitudes: Dictionary[String, float] = {}
var _matrix_climb_altitudes: Dictionary[String, float] = {}
var _matrix_descent_altitudes: Dictionary[String, float] = {}
var _actual_input_results: Array[Dictionary] = []
var _repeat_pass_count: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var definition: FlightRouteDefinition = load(
		ROUTE_RESOURCE_PATH
	) as FlightRouteDefinition
	_check(definition != null, "Round 5 route definition could not load.")
	if definition == null:
		_finish()
		return
	_test_multi_trajectory_multi_rate_matrix(definition)
	_test_twenty_repeated_entries(definition)
	_test_invalid_reference_is_not_one_meter(definition)
	await _test_actual_input_entries()
	await _test_camera_and_stage_label_independence()
	await _test_invalid_source_does_not_trigger_radar()
	await _test_checkpoint_and_restart_restore()
	print(
		(
			"[gate-c-round-5-altitude] matrix=11x3 repeat=%d/20 "
			+ "high=%.1f→%.1f→%.1fm mid=%.1f→%.1f→%.1fm "
			+ "low=%.1f→%.1f→%.1fm actual=%s"
		)
		% [
			_repeat_pass_count,
			_matrix_initial_altitudes.get("high_level@60", 0.0),
			_matrix_climb_altitudes.get("high_level@60", 0.0),
			_matrix_descent_altitudes.get("high_level@60", 0.0),
			_matrix_initial_altitudes.get("mid_level@60", 0.0),
			_matrix_climb_altitudes.get("mid_level@60", 0.0),
			_matrix_descent_altitudes.get("mid_level@60", 0.0),
			_matrix_initial_altitudes.get("low_dive@60", 0.0),
			_matrix_climb_altitudes.get("low_dive@60", 0.0),
			_matrix_descent_altitudes.get("low_dive@60", 0.0),
			JSON.stringify(_actual_input_results),
		]
	)
	_finish()


func _test_multi_trajectory_multi_rate_matrix(
	definition: FlightRouteDefinition
) -> void:
	var frame_rate_results: Dictionary[String, Array] = {}
	for frames_per_second: int in [30, 60, 120]:
		var rate_results: Array[float] = []
		for trajectory: Dictionary in TRAJECTORIES:
			var result: Dictionary = _run_provider_trajectory(
				definition,
				trajectory,
				frames_per_second
			)
			var initial_altitude: float = float(result["initial"])
			var stage_five_altitude: float = float(result["stage_five"])
			var altitude_after_climb: float = float(result["after_climb"])
			var altitude_after_descent: float = float(result["after_descent"])
			var provider: FlightAltitudeReferenceProvider = result["provider"]
			var continuity_tolerance: float = maxf(
				25.0,
				absf(stage_five_altitude) * 0.05
			)
			_check(
				provider.has_numeric_altitude()
				and provider.is_current_source_valid()
				and absf(initial_altitude - stage_five_altitude)
				<= continuity_tolerance
				and not is_equal_approx(initial_altitude, 1.0)
				and altitude_after_climb > initial_altitude + 12.0
				and altitude_after_descent < altitude_after_climb - 20.0
				and is_equal_approx(
					provider.get_hud_altitude_meters(),
					provider.get_radar_altitude_meters()
				),
				(
					"%s at %d FPS broke Stage 5→6 validity/continuity or vertical response: "
					+ "stage5=%.2f initial=%.2f up=%.2f down=%.2f source=%s reason=%s"
				)
				% [
					String(trajectory["name"]),
					frames_per_second,
					stage_five_altitude,
					initial_altitude,
					altitude_after_climb,
					altitude_after_descent,
					provider.get_source_name(),
					provider.get_failure_reason(),
				]
			)
			_matrix_initial_altitudes[
				"%s@%d" % [String(trajectory["name"]), frames_per_second]
			] = initial_altitude
			_matrix_climb_altitudes[
				"%s@%d" % [String(trajectory["name"]), frames_per_second]
			] = altitude_after_climb
			_matrix_descent_altitudes[
				"%s@%d" % [String(trajectory["name"]), frames_per_second]
			] = altitude_after_descent
			rate_results.append(altitude_after_descent)
		frame_rate_results[str(frames_per_second)] = rate_results
	for trajectory_index: int in TRAJECTORIES.size():
		var value_30: float = float(frame_rate_results["30"][trajectory_index])
		var value_60: float = float(frame_rate_results["60"][trajectory_index])
		var value_120: float = float(frame_rate_results["120"][trajectory_index])
		_check(
			maxf(absf(value_30 - value_60), absf(value_60 - value_120)) < 0.75,
			"%s produced frame-rate-dependent AGL: %.2f / %.2f / %.2f."
			% [
				String(TRAJECTORIES[trajectory_index]["name"]),
				value_30,
				value_60,
				value_120,
			]
		)


func _run_provider_trajectory(
	definition: FlightRouteDefinition,
	trajectory: Dictionary,
	frames_per_second: int
) -> Dictionary:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	var delta: float = 1.0 / float(frames_per_second)
	var stage_five: FlightRouteSegment = definition.segments[STAGE_FIVE_INDEX]
	var ground_y: float = definition.get_ground_route_y(
		STAGE_SIX_START_DISTANCE,
		STAGE_SIX_INDEX
	)
	var entry_vertical_speed: float = float(trajectory["vertical_speed"])
	var prepare_duration: float = 0.25
	var prepare_frames: int = roundi(prepare_duration * frames_per_second)
	var prepare_delta: float = prepare_duration / float(prepare_frames)
	var target_ship_y: float = float(trajectory["ship_y"])
	var ship_y: float = target_ship_y - entry_vertical_speed * prepare_duration
	var prepare_start_distance: float = STAGE_SIX_START_DISTANCE - 300.0
	var prepare_ground_y: float = definition.get_ground_route_y(
		prepare_start_distance,
		STAGE_FIVE_INDEX
	)
	provider.reset_to_canonical_samples(
		STAGE_FIVE_INDEX,
		stage_five.get_progress(prepare_start_distance),
		prepare_start_distance,
		ship_y,
		prepare_ground_y,
		true,
		prepare_ground_y - ship_y,
		true,
		definition.get_ground_profile_segment_id(STAGE_FIVE_INDEX)
	)
	for frame_index: int in prepare_frames:
		var interpolation: float = float(frame_index + 1) / float(prepare_frames)
		var route_distance: float = lerpf(
			prepare_start_distance,
			STAGE_SIX_START_DISTANCE - 0.01,
			interpolation
		)
		if String(trajectory["name"]) == "short_reverse":
			route_distance -= sin(interpolation * PI) * 100.0
		ship_y += entry_vertical_speed * prepare_delta
		prepare_ground_y = definition.get_ground_route_y(
			route_distance,
			STAGE_FIVE_INDEX
		)
		provider.update_from_canonical_samples(
			STAGE_FIVE_INDEX,
			stage_five.get_progress(route_distance),
			route_distance,
			ship_y,
			prepare_ground_y,
			true,
			prepare_ground_y - ship_y,
			true,
			prepare_delta,
			definition.get_ground_profile_segment_id(STAGE_FIVE_INDEX)
		)
	var stage_five_altitude: float = provider.get_altitude_meters()
	var raw_altitude: float = ground_y - ship_y
	provider.update_from_canonical_samples(
		STAGE_SIX_INDEX,
		0.0,
		STAGE_SIX_START_DISTANCE + 0.01,
		ship_y,
		ground_y,
		true,
		raw_altitude,
		true,
		delta,
		definition.get_ground_profile_segment_id(STAGE_SIX_INDEX)
	)
	var initial_altitude: float = provider.get_altitude_meters()
	var climb_duration: float = 0.60
	var climb_distance: float = 36.0
	var climb_frames: int = roundi(climb_duration * frames_per_second)
	for _frame_index: int in climb_frames:
		ship_y -= climb_distance / float(climb_frames)
		provider.update_from_canonical_samples(
			STAGE_SIX_INDEX,
			0.02,
			STAGE_SIX_START_DISTANCE + 100.0,
			ship_y,
			ground_y,
			true,
			ground_y - ship_y,
			true,
			delta
		)
	var altitude_after_climb: float = provider.get_altitude_meters()
	var descent_duration: float = 0.80
	var descent_distance: float = 72.0
	var descent_frames: int = roundi(descent_duration * frames_per_second)
	for _frame_index: int in descent_frames:
		ship_y += descent_distance / float(descent_frames)
		provider.update_from_canonical_samples(
			STAGE_SIX_INDEX,
			0.04,
			STAGE_SIX_START_DISTANCE + 200.0,
			ship_y,
			ground_y,
			true,
			ground_y - ship_y,
			true,
			delta
		)
	return {
		"stage_five": stage_five_altitude,
		"initial": initial_altitude,
		"after_climb": altitude_after_climb,
		"after_descent": provider.get_altitude_meters(),
		"provider": provider,
	}


func _test_twenty_repeated_entries(definition: FlightRouteDefinition) -> void:
	var ground_y: float = definition.get_ground_route_y(
		STAGE_SIX_START_DISTANCE,
		STAGE_SIX_INDEX
	)
	for run_index: int in 20:
		var intended_altitude: float = 120.0 + float((run_index * 73) % 481)
		var vertical_speed: float = -95.0 + float((run_index * 37) % 191)
		var prepare_duration: float = 0.20
		var prepare_frames: int = 12
		var prepare_delta: float = prepare_duration / float(prepare_frames)
		var ship_y: float = (
			ground_y - intended_altitude - vertical_speed * prepare_duration
		)
		var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
		provider.reset_to_canonical_samples(
			STAGE_FIVE_INDEX,
			0.8,
			STAGE_SIX_START_DISTANCE - 200.0,
			ship_y,
			ground_y,
			true,
			ground_y - ship_y,
			true
		)
		for prepare_frame: int in prepare_frames:
			var interpolation: float = (
				float(prepare_frame + 1) / float(prepare_frames)
			)
			ship_y += vertical_speed * prepare_delta
			provider.update_from_canonical_samples(
				STAGE_FIVE_INDEX,
				lerpf(0.8, 1.0, interpolation),
				lerpf(
					STAGE_SIX_START_DISTANCE - 200.0,
					STAGE_SIX_START_DISTANCE - 0.01,
					interpolation
				),
				ship_y,
				ground_y,
				true,
				ground_y - ship_y,
				true,
				prepare_delta
			)
		provider.update_from_canonical_samples(
			STAGE_SIX_INDEX,
			0.0,
			STAGE_SIX_START_DISTANCE + 0.01,
			ship_y,
			ground_y,
			true,
			intended_altitude,
			true,
			STEP_SECONDS
		)
		var entry_altitude: float = provider.get_altitude_meters()
		for _response_frame: int in 15:
			ship_y += vertical_speed * STEP_SECONDS
			provider.update_from_canonical_samples(
				STAGE_SIX_INDEX,
				0.01,
				STAGE_SIX_START_DISTANCE + 50.0,
				ship_y,
				ground_y,
				true,
				ground_y - ship_y,
				true,
				STEP_SECONDS
			)
		var response_delta: float = provider.get_altitude_meters() - entry_altitude
		var valid_run: bool = (
			provider.has_numeric_altitude()
			and provider.is_current_source_valid()
			and not is_equal_approx(entry_altitude, 1.0)
			and response_delta * -vertical_speed > 0.0
			and provider.get_source_name() == &"PROFILE"
		)
		if valid_run:
			_repeat_pass_count += 1
		_check(
			valid_run,
			"Repeated Stage 6 entry %d failed: altitude=%.2f source=%s reason=%s"
			% [
				run_index + 1,
				entry_altitude,
				provider.get_source_name(),
				provider.get_failure_reason(),
			]
		)


func _test_invalid_reference_is_not_one_meter(
	definition: FlightRouteDefinition
) -> void:
	var ground_y: float = definition.get_ground_route_y(
		STAGE_SIX_START_DISTANCE,
		STAGE_SIX_INDEX
	)
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_canonical_samples(
		STAGE_SIX_INDEX,
		0.0,
		STAGE_SIX_START_DISTANCE,
		ground_y + 20.0,
		ground_y,
		true,
		0.0,
		false
	)
	_check(
		not provider.has_numeric_altitude()
		and not provider.is_current_source_valid()
		and not provider.profile_altitude_valid
		and not is_equal_approx(provider.get_altitude_meters(), 1.0)
		and provider.get_failure_reason() == &"REFERENCE_BELOW_TERRAIN_PROFILE",
		"A ship reference inside/below terrain was accepted or clamped to 1 m."
	)


func _test_actual_input_entries() -> void:
	for scenario: Dictionary in [
		{
			"name": "input_high_rising",
			"start_y": 150.0,
			"start_distance": 22600.0,
			"pitch_action": &"flight_pitch_up",
			"boost": false,
		},
		{
			"name": "input_low_diving",
			"start_y": 360.0,
			"start_distance": 22850.0,
			"pitch_action": &"flight_pitch_down",
			"boost": false,
		},
		{
			"name": "input_boost_rising",
			"start_y": 270.0,
			"start_distance": 22600.0,
			"pitch_action": &"flight_pitch_up",
			"boost": true,
		},
	]:
		await _run_actual_input_entry(scenario)


func _run_actual_input_entry(scenario: Dictionary) -> void:
	var route: RedSandFlight = await _create_route()
	if route == null:
		return
	var ship: FlightLabShip = route.get_flight_ship()
	var provider: FlightAltitudeReferenceProvider = route.get_altitude_reference_provider()
	ship.position = Vector2(route.route_origin_x + 20000.0, float(scenario["start_y"]))
	ship.velocity = Vector2(170.0, 0.0)
	ship.rotation = 0.0
	ship.angular_velocity = 0.0
	route.advance_route_state()
	route._physics_process(STEP_SECONDS)
	await physics_frame
	ship.position.x = route.route_origin_x + float(scenario["start_distance"])
	Input.action_press(&"flight_throttle")
	Input.action_press(scenario["pitch_action"] as StringName)
	if bool(scenario["boost"]):
		Input.action_press(&"flight_boost")
	var crossed: bool = false
	var first_altitude: float = 0.0
	for _frame_index: int in 300:
		ship._physics_process(STEP_SECONDS)
		route.advance_route_state()
		route._physics_process(STEP_SECONDS)
		if route.get_active_segment_index() == STAGE_SIX_INDEX:
			crossed = true
			first_altitude = provider.get_altitude_meters()
			break
		await physics_frame
	_release_flight_actions()
	var altitude_before_climb: float = provider.get_altitude_meters()
	Input.action_press(&"flight_pitch_up")
	for _frame_index: int in 45:
		ship._physics_process(STEP_SECONDS)
		route.advance_route_state()
		route._physics_process(STEP_SECONDS)
		await physics_frame
	Input.action_press(&"flight_throttle")
	for _frame_index: int in 210:
		ship._physics_process(STEP_SECONDS)
		route.advance_route_state()
		route._physics_process(STEP_SECONDS)
		await physics_frame
	_release_flight_actions()
	var altitude_after_climb: float = provider.get_altitude_meters()
	var result: Dictionary = {
		"name": String(scenario["name"]),
		"first": snappedf(first_altitude, 0.1),
		"before_climb": snappedf(altitude_before_climb, 0.1),
		"after_climb": snappedf(altitude_after_climb, 0.1),
		"source": String(provider.get_source_name()),
	}
	_actual_input_results.append(result)
	_check(
		crossed
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and not is_equal_approx(first_altitude, 1.0)
		and altitude_after_climb > altitude_before_climb + 8.0
		and not route.has_altitude_invariant_violation(),
		"Actual Input Map trajectory %s failed: %s / %s"
		% [String(scenario["name"]), JSON.stringify(result), route.get_altitude_diagnostic_snapshot()]
	)
	route.queue_free()
	await process_frame


func _test_camera_and_stage_label_independence() -> void:
	var route: RedSandFlight = await _create_route()
	if route == null:
		return
	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var provider: FlightAltitudeReferenceProvider = route.get_altitude_reference_provider()
	var camera: Camera2D = route.get_flight_camera()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var ground_y: float = definition.get_ground_route_y(
		STAGE_SIX_START_DISTANCE,
		STAGE_SIX_INDEX
	)
	ship.position = Vector2(
		route.route_origin_x + STAGE_SIX_START_DISTANCE + 1.0,
		ground_y - 420.0 - REFERENCE_POINT_OFFSET_Y
	)
	ship.rotation = 0.0
	route.advance_route_state()
	await physics_frame
	route._reset_altitude_reference()
	var baseline_altitude: float = provider.get_altitude_meters()
	var baseline_route_distance: float = provider.canonical_route_distance
	camera.position += Vector2(480.0, -220.0)
	hud.show_stage_transition(definition.segments[STAGE_EIGHT_INDEX])
	route._update_altitude_reference(STEP_SECONDS)
	_check(
		is_equal_approx(provider.canonical_route_distance, baseline_route_distance)
		and absf(provider.get_altitude_meters() - baseline_altitude) < 0.01
		and provider.is_current_source_valid(),
		"Camera or stage-label movement changed canonical AGL: %s"
		% route.get_altitude_diagnostic_snapshot()
	)
	route.queue_free()
	await process_frame


func _test_checkpoint_and_restart_restore() -> void:
	var route: RedSandFlight = await _create_route()
	if route == null:
		return
	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var provider: FlightAltitudeReferenceProvider = route.get_altitude_reference_provider()
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	var stage_six_ground: float = definition.get_ground_route_y(
		STAGE_SIX_START_DISTANCE,
		STAGE_SIX_INDEX
	)
	ship.position = Vector2(
		route.route_origin_x + STAGE_SIX_START_DISTANCE + 1.0,
		stage_six_ground - 420.0 - REFERENCE_POINT_OFFSET_Y
	)
	ship.velocity = Vector2(180.0, -15.0)
	route.advance_route_state()
	await physics_frame
	route._update_altitude_reference(STEP_SECONDS)
	var checkpoint_altitude: float = provider.get_altitude_meters()
	ship.position += Vector2(240.0, 80.0)
	route._update_altitude_reference(0.5)
	var restored: bool = route.restart_from_checkpoint(false)
	var restored_altitude: float = provider.get_altitude_meters()
	_check(
		restored
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and absf(restored_altitude - checkpoint_altitude) < 1.0
		and not is_equal_approx(restored_altitude, 1.0),
		"Stage 6 checkpoint restored a discontinuous/invalid altitude: %.2f -> %.2f."
		% [checkpoint_altitude, restored_altitude]
	)

	var stage_eight: FlightRouteSegment = definition.segments[STAGE_EIGHT_INDEX]
	ship.position = Vector2(
		route.route_origin_x + stage_eight.start_distance + 1.0,
		definition.get_ground_route_y(stage_eight.start_distance, STAGE_EIGHT_INDEX)
		- 600.0
		- REFERENCE_POINT_OFFSET_Y
	)
	ship.velocity = Vector2(110.0, 0.0)
	route.advance_route_state()
	route._update_altitude_reference(STEP_SECONDS)
	var stage_eight_valid: bool = provider.has_numeric_altitude()
	var stage_eight_restored: bool = route.restart_from_checkpoint(false)
	_check(
		stage_eight_valid
		and stage_eight_restored
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and provider.get_source_name() == &"PROFILE"
		and not route.has_altitude_invariant_violation(),
		"Stage 8 checkpoint/restart did not restore the canonical AGL frame."
	)

	ship.position = Vector2(
		route.route_origin_x + landing_zone.get_landing_center_route_distance(),
		landing_zone.global_position.y
		+ landing_zone.get_pad_surface_y()
		- 120.0
		- REFERENCE_POINT_OFFSET_Y
	)
	ship.velocity = Vector2(80.0, 0.0)
	landing_zone.step_physics(0.0)
	await physics_frame
	route._update_altitude_reference(STEP_SECONDS)
	_check(
		landing_zone.is_pad_collision_active()
		and landing_zone.has_altitude_surface_override(
			landing_zone.get_landing_center_route_distance()
		)
		and provider.is_current_source_valid()
		and provider.cross_source_consistency_valid
		and absf(provider.raw_profile_altitude_meters - 120.0) < 0.5
		and provider.ray_profile_difference_meters
		<= provider.ray_profile_tolerance_meters,
		"Landing pad override did not match the canonical profile and physics ray: %s"
		% route.get_altitude_diagnostic_snapshot()
	)
	route.queue_free()
	await process_frame


func _test_invalid_source_does_not_trigger_radar() -> void:
	var route: RedSandFlight = await _create_route()
	if route == null:
		return
	var ship: FlightLabShip = route.get_flight_ship()
	var provider: FlightAltitudeReferenceProvider = route.get_altitude_reference_provider()
	var course: RedSandLowFlightCourse = route.get_low_flight_course()
	var sector: FlightRadarSector = course.get_radar_sectors()[0]
	ship.global_position = sector.global_position
	course.set_active_segment(&"red_sand_low_altitude_control")
	provider.reset_to_canonical_samples(
		STAGE_SIX_INDEX,
		0.2,
		24500.0,
		510.0,
		660.0,
		true,
		150.0,
		true
	)
	course.reset_for_checkpoint()
	course.step_physics(course.warning_seconds + course.locked_seconds + 0.01)
	var pulse_count: int = course.get_pulse_count()
	provider.update_from_canonical_samples(
		STAGE_SIX_INDEX,
		0.2,
		24500.0,
		510.0,
		0.0,
		false,
		0.0,
		false,
		0.10
	)
	var held_but_current_invalid: bool = (
		provider.has_numeric_altitude()
		and provider.get_source_name() == &"HOLD_LAST_VALID"
		and not provider.is_current_source_valid()
	)
	course.reset_for_checkpoint()
	course.step_physics(2.0)
	_check(
		pulse_count == 1
		and held_but_current_invalid
		and course.get_radar_state() == RedSandLowFlightCourse.RadarState.CLEAR
		and course.get_pulse_count() == 0,
		"Radar punished a short invalid/HOLD_LAST_VALID altitude sample."
	)
	route.queue_free()
	await process_frame


func _create_route() -> RedSandFlight:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Round 5 route scene could not load.")
	if packed_scene == null:
		return null
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Round 5 route controller is missing.")
	if route == null:
		return null
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	route.set_process(false)
	route.set_physics_process(false)
	route.get_flight_ship().set_physics_process(false)
	return route


func _release_flight_actions() -> void:
	for action: StringName in [
		&"flight_throttle",
		&"flight_brake",
		&"flight_pitch_up",
		&"flight_pitch_down",
		&"flight_boost",
	]:
		Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_release_flight_actions()
	if _failures.is_empty():
		print(
			"[gate-c-round-5-altitude] PASS: canonical frame, 30/60/120 FPS, "
			+ "20 repeats, actual input, radar/HUD, checkpoint, and restart."
		)
		quit(0)
		return
	printerr("[gate-c-round-5-altitude] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
