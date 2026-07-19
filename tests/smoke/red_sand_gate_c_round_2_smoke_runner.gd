extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const STEP_SECONDS: float = 1.0 / 60.0
const VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)

var _failures: Array[String] = []
var _original_locale: String = ""
var _original_tree_paused: bool = false


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_tree_paused = paused
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Gate C Round 3 route scene could not load.")
	if packed_scene == null:
		_finish()
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Gate C Round 3 route controller is missing.")
	if route == null:
		_finish()
		return
	route.force_direct_test_mode = true
	root.add_child(route)
	await process_frame
	await process_frame

	var ship: FlightLabShip = route.get_flight_ship()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var visuals: RedSandRouteVisuals = route.get_node_or_null(
		"World/RouteGeometry"
	) as RedSandRouteVisuals
	var hazards: RedSandHazardDirector = route.get_hazard_director()
	_check(ship != null, "Gate C Round 3 ship is missing.")
	_check(definition != null, "Gate C Round 3 route data is missing.")
	_check(hud != null, "Gate C Round 3 HUD is missing.")
	_check(visuals != null, "Gate C Round 3 background controller is missing.")
	_check(hazards != null, "Gate C Round 3 hazards are missing.")
	if ship == null or definition == null or hud == null or visuals == null or hazards == null:
		route.queue_free()
		await process_frame
		_finish()
		return

	_test_initial_help(route, ship, hud)
	route.close_controls_help()
	ship.set_physics_process(false)
	route.set_process(false)
	route.set_physics_process(false)
	_test_help_reopen_and_test_tools(route, ship, hud)
	_test_planet_stages_and_checkpoint(route, ship, definition, visuals)
	await physics_frame
	_test_propulsion_feedback(ship)
	await _test_continuous_beam(route, ship, hazards)
	_test_tracking_strike_visibility(route, ship, hazards)
	var profile_results: Dictionary[StringName, Vector2] = _measure_route_profiles(
		ship,
		definition
	)
	_test_profile_budgets(profile_results, definition)
	_test_boost_and_emergency_thrust(ship, definition)

	print(
		"[gate-c-round-3] measured "
		+ "fast=%.1fs/%.1f fuel, balanced=%.1fs/%.1f fuel, scenic=%.1fs/%.1f fuel"
		% [
			profile_results[&"fast"].x,
			profile_results[&"fast"].y,
			profile_results[&"balanced"].x,
			profile_results[&"balanced"].y,
			profile_results[&"scenic"].x,
			profile_results[&"scenic"].y,
		]
	)
	route.queue_free()
	await process_frame
	_finish()


func _test_initial_help(
	route: RedSandFlight,
	ship: FlightLabShip,
	hud: RedSandRouteHUD
) -> void:
	var help: FlightControlsHelp = hud.get_controls_help()
	var elapsed_before: float = route.get_route_elapsed_seconds()
	route._process(1.0)
	_check(
		route.is_controls_help_open()
		and paused
		and help != null
		and help.visible
		and is_equal_approx(route.get_route_elapsed_seconds(), elapsed_before),
		"Initial controls help did not pause flight, route timing, and hazards."
	)
	if help == null:
		return
	var core_text: String = help.get_core_controls_text()
	var test_text: String = help.get_test_controls_text()
	_check(
		core_text.contains("W")
		and core_text.contains("S")
		and core_text.contains("Shift")
		and core_text.contains("F")
		and core_text.contains("R")
		and core_text.contains("C")
		and core_text.contains("↑")
		and core_text.contains("↓")
		and test_text.contains("H")
		and test_text.contains("G")
		and test_text.contains("L")
		and test_text.contains("Tab")
		and help.get_laser_state_text().contains("未安装")
		and not ship.is_laser_enabled(),
		"Localized controls help omitted core keys, test keys, or laser state."
	)


func _test_help_reopen_and_test_tools(
	route: RedSandFlight,
	ship: FlightLabShip,
	hud: RedSandRouteHUD
) -> void:
	_check(not paused and not route.is_controls_help_open(), "Closing help did not resume flight.")
	var controls_event: InputEventAction = InputEventAction.new()
	controls_event.action = RedSandFlight.CONTROLS_HELP_ACTION
	controls_event.pressed = true
	route._unhandled_input(controls_event)
	_check(
		route.is_controls_help_open() and paused,
		"C did not reopen and pause controls help."
	)
	route._unhandled_input(controls_event)
	_check(
		not route.is_controls_help_open() and not paused,
		"Second C input did not close help cleanly."
	)
	var diagnostics_event: InputEventAction = InputEventAction.new()
	diagnostics_event.action = RedSandFlight.HUD_TOGGLE_ACTION
	diagnostics_event.pressed = true
	route._unhandled_input(diagnostics_event)
	_check(
		hud.is_full_diagnostics_visible()
		and hud.get_diagnostics_text().contains("完整诊断")
		and hud.get_diagnostics_text().contains("路线")
		and hud.get_navigation_text().contains("距着陆点"),
		"H did not open full diagnostics while preserving Essential navigation."
	)
	route._unhandled_input(diagnostics_event)
	_check(
		not hud.is_full_diagnostics_visible()
		and hud.get_diagnostics_rect() == Rect2(),
		"Second H input did not close full diagnostics."
	)
	var fuel_before_test_tools: float = ship.fuel
	_check(
		route.toggle_test_laser_loadout()
		and ship.is_laser_enabled(),
		"Direct route L tool did not install the laser module."
	)
	route.open_controls_help()
	_check(
		hud.get_controls_help().get_laser_state_text().contains("已安装"),
		"Controls help did not refresh the installed laser state."
	)
	route.close_controls_help()
	_check(
		is_equal_approx(ship.fuel, fuel_before_test_tools),
		"Help and test loadout inputs unexpectedly consumed route fuel."
	)


func _test_planet_stages_and_checkpoint(
	route: RedSandFlight,
	ship: FlightLabShip,
	definition: FlightRouteDefinition,
	visuals: RedSandRouteVisuals
) -> void:
	var stage_one_scale: float = visuals.get_planet_scale()
	var stage_one_position: Vector2 = visuals.get_planet_position()
	_check(
		visuals.is_full_planet_visible()
		and is_equal_approx(stage_one_scale, 0.36),
		"Stage 1 did not show the small Red Sand disc."
	)
	var near_orbit: FlightRouteSegment = definition.segments[2]
	ship.position.x = route.route_origin_x + near_orbit.end_distance - 1.0
	route.advance_route_state()
	route._process(0.0)
	var stage_three_scale: float = visuals.get_planet_scale()
	_check(
		visuals.is_full_planet_visible()
		and stage_three_scale / stage_one_scale >= 2.5
		and stage_three_scale / stage_one_scale <= 4.0
		and visuals.get_planet_position() != stage_one_position,
		"Stage 3 planet did not grow 2.5-4x and move across the approach."
	)
	var atmosphere: FlightRouteSegment = definition.segments[3]
	ship.position.x = route.route_origin_x + atmosphere.start_distance + 1.0
	route.advance_route_state()
	route._process(0.45)
	_check(
		visuals.is_full_planet_visible()
		and visuals.get_planet_transition_progress() > 0.0
		and visuals.get_planet_transition_progress() < 1.0
		and visuals.get_planet_scale() > stage_three_scale
		and visuals.get_atmosphere_horizon_alpha() > 0.0
		and visuals.get_atmosphere_horizon_alpha() < 1.0,
		"Atmosphere entry did not continuously grow the disc into a curved horizon."
	)
	route._process(0.5)
	_check(
		not visuals.is_full_planet_visible()
		and is_equal_approx(visuals.get_planet_transition_progress(), 1.0)
		and is_equal_approx(visuals.get_atmosphere_horizon_alpha(), 1.0),
		"The 0.9-second disc-to-horizon handoff did not finish continuously."
	)
	_check(route.restart_from_checkpoint(false), "Atmosphere checkpoint did not restore.")
	_check(
		visuals.is_full_planet_visible()
		and is_zero_approx(visuals.get_planet_transition_progress())
		and is_zero_approx(visuals.get_atmosphere_horizon_alpha()),
		"Atmosphere retry did not restore the start of the visual transition."
	)
	var storm: FlightRouteSegment = definition.segments[4]
	ship.fuel = 1.0
	ship.position.x = route.route_origin_x + storm.start_distance + 1.0
	route.advance_route_state()
	route._process(0.0)
	_check(
		not visuals.is_full_planet_visible()
		and is_equal_approx(visuals.get_atmosphere_horizon_alpha(), 1.0),
		"Stage 5 must hide the full disc while retaining atmospheric curvature."
	)
	_check(route.restart_from_checkpoint(false), "Storm checkpoint did not restore.")
	_check(
		ship.fuel >= storm.checkpoint_fuel_floor
		and not visuals.is_full_planet_visible()
		and is_equal_approx(visuals.get_atmosphere_horizon_alpha(), 1.0),
		"Checkpoint retry did not restore safe fuel and background state."
	)


func _test_propulsion_feedback(ship: FlightLabShip) -> void:
	var engine_particles: CPUParticles2D = ship.get_engine_trail_particles()
	var boost_particles: CPUParticles2D = ship.get_boost_trail_particles()
	_check(
		engine_particles != null
		and boost_particles != null
		and engine_particles.local_coords
		and boost_particles.local_coords
		and engine_particles.gravity == Vector2.ZERO
		and boost_particles.gravity == Vector2.ZERO
		and engine_particles.direction.x < 0.0
		and boost_particles.direction.x < 0.0,
		"Propulsion trails are not local, rearward, and zero-gravity."
	)
	_check(
		boost_particles.amount >= engine_particles.amount * 2
		and boost_particles.initial_velocity_min > engine_particles.initial_velocity_max,
		"Boost trail is not clearly stronger than normal thrust."
	)
	ship.clear_propulsion_feedback()
	_check(
		not engine_particles.emitting and not boost_particles.emitting,
		"Retry feedback cleanup left propulsion particles emitting."
	)


func _test_continuous_beam(
	route: RedSandFlight,
	ship: FlightLabShip,
	hazards: RedSandHazardDirector
) -> void:
	var asteroids: Array[DestructibleAsteroid] = hazards.get_asteroids()
	if asteroids.is_empty():
		_check(false, "Continuous beam test has no asteroid target.")
		return
	var target: DestructibleAsteroid = null
	for asteroid: DestructibleAsteroid in asteroids:
		if asteroid.max_durability >= 3:
			target = asteroid
			break
	if target == null:
		_check(false, "Continuous beam test has no durable asteroid target.")
		return
	target.reset_asteroid()
	ship.position = target.position - Vector2(300.0, 0.0)
	ship.rotation = 0.0
	ship.velocity = Vector2.ZERO
	ship.set_laser_enabled(true)
	await physics_frame
	var weapon: FlightLaserWeapon = ship.get_laser_weapon()
	_check(
		ship.begin_laser_beam() == FlightLaserWeapon.FireResult.FIRED
		and weapon.is_beam_active()
		and weapon.is_beam_visible(),
		"Held laser did not start one continuous visible beam."
	)
	var first_tick_count: int = weapon.get_damage_tick_count()
	var first_end: Vector2 = weapon.get_last_beam_end_global()
	weapon._physics_process(ship.tuning.beam_damage_tick_seconds + 0.01)
	_check(
		weapon.is_beam_active()
		and weapon.is_beam_visible()
		and weapon.get_damage_tick_count() > first_tick_count
		and first_end.distance_to(weapon.global_position) < ship.tuning.beam_max_range,
		"Damage tick closed the beam or the asteroid hit did not clip its endpoint."
	)
	weapon.stop_beam()
	weapon._physics_process(
		ship.tuning.beam_min_visible_seconds
		+ ship.tuning.beam_release_fade_seconds
		+ 0.02
	)
	_check(
		not weapon.is_beam_active()
		and not weapon.is_beam_visible()
		and not weapon.get_shot_audio().playing,
		"Beam or loop audio remained after release."
	)
	ship.set_laser_enabled(false)
	_check(
		ship.begin_laser_beam() == FlightLaserWeapon.FireResult.UNAVAILABLE
		and not weapon.is_beam_active(),
		"Uninstalled laser incorrectly activated a beam."
	)
	ship.set_laser_enabled(true)
	ship.begin_laser_beam()
	route.restart_from_checkpoint(false)
	_check(
		not weapon.is_beam_active()
		and not weapon.is_beam_visible()
		and not weapon.get_shot_audio().playing,
		"Checkpoint retry left a beam or loop audio active."
	)


func _test_tracking_strike_visibility(
	route: RedSandFlight,
	ship: FlightLabShip,
	hazards: RedSandHazardDirector
) -> void:
	var strikes: Array[FlightLightningStrike] = hazards.get_lightning_strikes()
	if strikes.size() < 2:
		_check(false, "Tracking strike test needs two fixed strikes.")
		return
	var camera: Camera2D = route.get_flight_camera()
	var test_y_values: PackedFloat32Array = PackedFloat32Array([36.0, 324.0])
	for index: int in 2:
		var strike: FlightLightningStrike = strikes[index]
		strike.reset_for_route(0.0)
		var ship_position: Vector2 = Vector2(
			route.route_origin_x + strike.trigger_route_distance,
			test_y_values[index]
		)
		ship.global_position = ship_position
		camera.global_position = ship_position
		strike.advance(
			0.0,
			strike.trigger_route_distance + 1.0,
			ship_position,
			Vector2(120.0, 40.0),
			camera.global_position,
			VIEWPORT_SIZE
		)
		var target_in_view: Vector2 = (
			strike.get_target_global_position() - camera.global_position
			+ VIEWPORT_SIZE * 0.5
		)
		_check(
			strike.get_state() == FlightLightningStrike.State.TRACKING
			and Rect2(Vector2.ZERO, VIEWPORT_SIZE).has_point(target_in_view)
			and not strike.is_position_in_hit_zone(ship_position),
			"High/low TRACKING warning escaped the viewport or enabled damage early."
		)


func _measure_route_profiles(
	ship: FlightLabShip,
	definition: FlightRouteDefinition
) -> Dictionary[StringName, Vector2]:
	var results: Dictionary[StringName, Vector2] = {}
	results[&"fast"] = _simulate_profile(ship, definition, &"fast")
	results[&"balanced"] = _simulate_profile(ship, definition, &"balanced")
	results[&"scenic"] = _simulate_profile(ship, definition, &"scenic")
	return results


func _simulate_profile(
	ship: FlightLabShip,
	definition: FlightRouteDefinition,
	profile_id: StringName
) -> Vector2:
	ship.reset_to_start(
		FlightAssistMode.LIMITED,
		definition.segments[0].environment_profile,
		true
	)
	ship.set_physics_process(false)
	var route_distance: float = 0.0
	var elapsed_seconds: float = 0.0
	var active_segment_id: StringName = definition.segments[0].id
	while route_distance < definition.get_total_distance() and elapsed_seconds < 240.0:
		var segment: FlightRouteSegment = definition.get_segment(route_distance)
		if segment.id != active_segment_id:
			active_segment_id = segment.id
			ship.set_environment_profile(segment.environment_profile, true)
		var throttle: float = 1.0
		var boost: float = 0.0
		match profile_id:
			&"fast":
				boost = 1.0 if fmod(elapsed_seconds, 2.0) < 0.9 else 0.0
			&"balanced":
				throttle = 0.45 if fmod(elapsed_seconds, 4.0) < 2.0 else 0.0
				boost = 1.0 if fmod(elapsed_seconds, 4.0) < 1.0 else 0.0
			&"scenic":
				throttle = 0.5 if fmod(elapsed_seconds, 2.0) < 1.15 else 0.0
		ship.integrate_motion(throttle, 0.0, 0.0, STEP_SECONDS, boost)
		ship.velocity.y = 0.0
		route_distance += maxf(ship.velocity.x, 0.0) * STEP_SECONDS
		elapsed_seconds += STEP_SECONDS
	return Vector2(elapsed_seconds, ship.fuel)


func _test_profile_budgets(
	results: Dictionary[StringName, Vector2],
	definition: FlightRouteDefinition
) -> void:
	var fast: Vector2 = results[&"fast"]
	var balanced: Vector2 = results[&"balanced"]
	var scenic: Vector2 = results[&"scenic"]
	_check(
		fast.x >= FlightRouteDefinition.MIN_FAST_DURATION_SECONDS
		and fast.x <= FlightRouteDefinition.MAX_FAST_DURATION_SECONDS,
		"Scripted fast route did not finish within 60-100 seconds."
	)
	_check(
		balanced.x >= FlightRouteDefinition.MIN_BALANCED_DURATION_SECONDS
		and balanced.x <= FlightRouteDefinition.MAX_BALANCED_DURATION_SECONDS,
		"Scripted balanced route did not finish within 90-150 seconds."
	)
	_check(
		scenic.x >= FlightRouteDefinition.MIN_SCENIC_DURATION_SECONDS
		and scenic.x <= FlightRouteDefinition.MAX_SCENIC_DURATION_SECONDS,
		"Scripted scenic route did not finish within 120-180 seconds."
	)
	_check(
		balanced.y >= 30.0
		and fast.y >= 15.0
		and scenic.y >= 50.0
		and definition.segments.size() == 8,
		"Route profiles exhausted fuel or removed an M0 stage."
	)


func _test_boost_and_emergency_thrust(
	ship: FlightLabShip,
	definition: FlightRouteDefinition
) -> void:
	ship.reset_to_start(
		FlightAssistMode.LIMITED,
		definition.segments[0].environment_profile,
		true
	)
	for _frame: int in 60:
		ship.integrate_motion(1.0, 0.0, 0.0, STEP_SECONDS, 0.0)
	var normal_speed_delta: float = ship.get_forward_speed()
	ship.reset_to_start(
		FlightAssistMode.LIMITED,
		definition.segments[0].environment_profile,
		true
	)
	for _frame: int in 60:
		ship.integrate_motion(1.0, 0.0, 0.0, STEP_SECONDS, 1.0)
	var boost_speed_delta: float = ship.get_forward_speed()
	_check(
		boost_speed_delta >= normal_speed_delta * 1.5
		and ship.tuning.boost_multiplier >= 1.8
		and ship.tuning.boost_multiplier <= 2.2
		and ship.tuning.boost_max_speed_multiplier >= 1.25
		and ship.tuning.boost_max_speed_multiplier <= 1.4,
		"One-second Boost delta is not at least 1.5x normal thrust."
	)
	ship.reset_to_start(
		FlightAssistMode.LIMITED,
		definition.segments[0].environment_profile,
		true
	)
	ship.fuel = 0.0
	ship.integrate_motion(1.0, 0.0, 0.0, 0.5, 1.0)
	_check(
		ship.get_forward_speed() > 0.0
		and ship.effective_throttle_input > 0.0
		and is_zero_approx(ship.effective_boost_input),
		"Zero fuel did not preserve emergency thrust while disabling Boost."
	)
	print(
		"[gate-c-round-3] 1s speed delta normal=%.1f boost=%.1f"
		% [normal_speed_delta, boost_speed_delta]
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	paused = _original_tree_paused
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[gate-c-round-3] PASS: help pause, 1-3 minute profiles, fuel floors, "
			+ "planet horizon, local trails, continuous beam, tracking lightning, "
			+ "Boost feedback, emergency thrust, and retry cleanup."
		)
		quit(0)
		return
	printerr("[gate-c-round-3] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
