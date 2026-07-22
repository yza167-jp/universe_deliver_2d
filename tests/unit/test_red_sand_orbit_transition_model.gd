extends ProjectTestSuite

const START_POSITION: Vector2 = Vector2(479.5556, 146.4)
const START_SCALE: float = 1.0684444
const END_POSITION: Vector2 = Vector2(320.0, 612.0)
const END_SCALE: float = 7.0
const STAGE_FOUR_BOUNDARY: float = 13500.0
const NOMINAL_ROUTE_SPEED: float = 316.6666667


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_window_length(failures)
	_test_stage_boundary_continuity(failures)
	_test_monotonic_reverse_guard(failures)
	_test_alpha_waits_for_geometric_exit(failures)
	_test_checkpoint_and_full_restart_restore(failures)
	return failures


func _test_window_length(failures: Array[String]) -> void:
	expect_true(
		is_equal_approx(
			RedSandOrbitTransitionModel.TRANSITION_START_DISTANCE,
			11800.0
		)
		and is_equal_approx(
			RedSandOrbitTransitionModel.TRANSITION_END_DISTANCE,
			15800.0
		)
		and is_equal_approx(
			RedSandOrbitTransitionModel.TRANSITION_WINDOW_DISTANCE,
			4000.0
		)
		and is_equal_approx(
			RedSandOrbitTransitionModel.get_nominal_duration_seconds(
				NOMINAL_ROUTE_SPEED
			),
			12.6315789
		),
		"Orbit-to-atmosphere transition must span 11800-15800 (4000 m, about 12.63 s).",
		failures
	)


func _test_stage_boundary_continuity(failures: Array[String]) -> void:
	var transition: RedSandOrbitTransitionModel = _create_transition()
	transition.reset_to_distance(STAGE_FOUR_BOUNDARY - 0.001)
	var before_position: Vector2 = transition.get_planet_position()
	var before_scale: float = transition.get_planet_scale()
	var before_alpha: float = transition.get_planet_alpha()
	var before_glow: float = transition.get_glow_progress()
	transition.reset_to_distance(STAGE_FOUR_BOUNDARY)
	var boundary_position: Vector2 = transition.get_planet_position()
	var boundary_scale: float = transition.get_planet_scale()
	var boundary_alpha: float = transition.get_planet_alpha()
	var boundary_glow: float = transition.get_glow_progress()
	transition.reset_to_distance(STAGE_FOUR_BOUNDARY + 0.001)
	var after_position: Vector2 = transition.get_planet_position()

	expect_true(
		before_position.distance_to(boundary_position) < 0.001
		and boundary_position.distance_to(after_position) < 0.001
		and absf(before_scale - boundary_scale) < 0.001
		and is_equal_approx(before_alpha, boundary_alpha)
		and absf(before_glow - boundary_glow) < 0.001,
		"Stage 4 first-frame position, scale, alpha, and glow must inherit stage 3 continuously.",
		failures
	)
	expect_true(
		boundary_position.y > START_POSITION.y
		and boundary_scale > START_SCALE
		and is_equal_approx(boundary_alpha, 1.0)
		and is_equal_approx(
			transition.get_horizon_progress(),
			transition.get_high_cloud_progress()
		)
		and is_equal_approx(
			transition.get_horizon_progress(),
			transition.get_glow_progress()
		),
		"Disc motion must keep descending/growing while horizon, glow, and high cloud share progress.",
		failures
	)


func _test_monotonic_reverse_guard(failures: Array[String]) -> void:
	var transition: RedSandOrbitTransitionModel = _create_transition()
	transition.reset_to_distance(14200.0)
	var position_before_reverse: Vector2 = transition.get_planet_position()
	var scale_before_reverse: float = transition.get_planet_scale()
	var progress_before_reverse: float = transition.get_progress()
	transition.advance_to_distance(13900.0)
	expect_true(
		is_equal_approx(transition.get_route_distance(), 14200.0)
		and transition.get_planet_position().is_equal_approx(position_before_reverse)
		and is_equal_approx(transition.get_planet_scale(), scale_before_reverse)
		and is_equal_approx(transition.get_progress(), progress_before_reverse),
		"A short reverse correction must not rewind the background transition.",
		failures
	)


func _test_alpha_waits_for_geometric_exit(failures: Array[String]) -> void:
	var transition: RedSandOrbitTransitionModel = _create_transition()
	transition.reset_to_distance(14800.0)
	expect_true(
		is_equal_approx(transition.get_planet_alpha(), 1.0)
		and transition.get_planet_visible_height()
		> RedSandOrbitTransitionModel.PLANET_FADE_START_VISIBLE_HEIGHT,
		"Planet alpha must remain 1 while more than a thin cap is still on screen.",
		failures
	)
	transition.reset_to_distance(15400.0)
	expect_true(
		transition.get_planet_alpha() > 0.0
		and transition.get_planet_alpha() < 1.0
		and transition.get_planet_visible_height()
		<= RedSandOrbitTransitionModel.PLANET_FADE_START_VISIBLE_HEIGHT,
		"Planet fade must begin only after the disc has nearly cleared the viewport.",
		failures
	)
	transition.reset_to_distance(RedSandOrbitTransitionModel.TRANSITION_END_DISTANCE)
	expect_true(
		is_zero_approx(transition.get_planet_alpha())
		and transition.get_planet_visible_height()
		<= RedSandOrbitTransitionModel.PLANET_FADE_END_VISIBLE_HEIGHT,
		"Planet must finish its short fade at the end of the distance window.",
		failures
	)


func _test_checkpoint_and_full_restart_restore(failures: Array[String]) -> void:
	var transition: RedSandOrbitTransitionModel = _create_transition()
	transition.reset_to_distance(STAGE_FOUR_BOUNDARY)
	var checkpoint_position: Vector2 = transition.get_planet_position()
	var checkpoint_scale: float = transition.get_planet_scale()
	var checkpoint_alpha: float = transition.get_planet_alpha()
	var checkpoint_atmosphere: float = transition.get_atmosphere_progress()
	transition.advance_to_distance(14900.0)
	transition.reset_to_distance(STAGE_FOUR_BOUNDARY)
	expect_true(
		transition.get_planet_position().is_equal_approx(checkpoint_position)
		and is_equal_approx(transition.get_planet_scale(), checkpoint_scale)
		and is_equal_approx(transition.get_planet_alpha(), checkpoint_alpha)
		and is_equal_approx(
			transition.get_atmosphere_progress(),
			checkpoint_atmosphere
		),
		"Checkpoint reset must restore every transition value deterministically from distance.",
		failures
	)
	transition.reset_to_distance(0.0)
	expect_true(
		is_zero_approx(transition.get_route_distance())
		and is_zero_approx(transition.get_progress())
		and is_zero_approx(transition.get_atmosphere_progress()),
		"Full restart must restore the visual controller to route distance 0.",
		failures
	)


func _create_transition() -> RedSandOrbitTransitionModel:
	return RedSandOrbitTransitionModel.new(
		START_POSITION,
		START_SCALE,
		END_POSITION,
		END_SCALE
	)
