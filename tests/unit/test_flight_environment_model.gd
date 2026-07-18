extends ProjectTestSuite

const DEEP_SPACE_PROFILE_PATH: String = (
	"res://data/tuning/flight_environment_deep_space.tres"
)
const RED_SAND_PROFILE_PATH: String = (
	"res://data/tuning/flight_environment_red_sand_atmosphere.tres"
)
const M0_TUNING_PATH: String = "res://data/tuning/flight_tuning_m0.tres"
const FIXED_DELTA: float = 1.0 / 60.0


func run() -> Array[String]:
	var failures: Array[String] = []
	var deep_space: FlightEnvironmentProfile = load(
		DEEP_SPACE_PROFILE_PATH
	) as FlightEnvironmentProfile
	var red_sand: FlightEnvironmentProfile = load(
		RED_SAND_PROFILE_PATH
	) as FlightEnvironmentProfile
	var tuning: FlightTuning = load(M0_TUNING_PATH) as FlightTuning
	expect_true(deep_space != null, "Deep-space environment profile must load.", failures)
	expect_true(red_sand != null, "Red Sand environment profile must load.", failures)
	expect_true(tuning != null, "M0 flight tuning must load.", failures)
	if deep_space == null or red_sand == null or tuning == null:
		return failures

	_test_environment_transition_is_gradual(red_sand, failures)
	_test_assist_presets_and_paid_hover(red_sand, tuning, failures)
	_test_terminal_fall_and_axis_drag(red_sand, tuning, failures)
	_test_profile_replacement_changes_planet_gravity(red_sand, failures)
	_test_dive_and_pull_up_recovery(red_sand, tuning, failures)
	_test_deep_space_preserves_zero_gravity(deep_space, tuning, failures)
	return failures


func _test_environment_transition_is_gradual(
	profile: FlightEnvironmentProfile,
	failures: Array[String]
) -> void:
	var first_step: float = FlightEnvironmentModel.step_environment_value(
		0.0,
		profile.target_gravity_blend,
		profile.transition_rate,
		0.5
	)
	expect_true(
		first_step > 0.0 and first_step < profile.target_gravity_blend,
		"Atmosphere gravity must blend in over time instead of switching in one frame.",
		failures
	)
	var completed: float = first_step
	for _step_index: int in 10:
		completed = FlightEnvironmentModel.step_environment_value(
			completed,
			profile.target_gravity_blend,
			profile.transition_rate,
			0.5
		)
	expect_true(
		is_equal_approx(completed, profile.target_gravity_blend),
		"Environment transition must eventually reach its configured target.",
		failures
	)


func _test_assist_presets_and_paid_hover(
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var full_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		0.0
	)
	var default_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		0.75
	)
	var hover_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		1.0
	)
	expect_true(
		is_equal_approx(full_gravity, profile.planet_gravity)
		and is_equal_approx(default_gravity, profile.planet_gravity * 0.25)
		and is_zero_approx(hover_gravity),
		"Assist presets must expose full gravity, 75% compensation, and hover.",
		failures
	)
	expect_true(
		is_zero_approx(
			FlightEnvironmentModel.calculate_assist_fuel_cost_rate(
				0.75,
				1.0,
				100.0,
				tuning
			)
		),
		"Default 75% assist must not pay the full-hover surcharge.",
		failures
	)
	expect_true(
		is_equal_approx(
			FlightEnvironmentModel.calculate_assist_fuel_cost_rate(
				1.0,
				1.0,
				100.0,
				tuning
			),
			tuning.full_assist_fuel_cost_per_second
		),
		"100% assist must expose an explicit configurable fuel cost.",
		failures
	)
	expect_true(
		is_equal_approx(
			FlightEnvironmentModel.calculate_effective_assist_strength(
				1.0,
				0.0,
				tuning
			),
			tuning.get_free_assist_strength()
		),
		"Depleted fuel must limit paid hover instead of allowing free 100% assist.",
		failures
	)

	var zero_assist_speed: float = _simulate_uncontrolled_fall(
		profile,
		tuning,
		0.0,
		2.0
	)
	var default_assist_speed: float = _simulate_uncontrolled_fall(
		profile,
		tuning,
		0.75,
		2.0
	)
	var full_assist_speed: float = _simulate_uncontrolled_fall(
		profile,
		tuning,
		1.0,
		2.0
	)
	expect_true(
		zero_assist_speed > default_assist_speed
		and default_assist_speed > 0.0
		and is_zero_approx(full_assist_speed),
		"0%, 75%, and 100% assist must produce clearly different fall behavior.",
		failures
	)


func _test_terminal_fall_and_axis_drag(
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		0.0
	)
	var natural_terminal: float = (
		FlightEnvironmentModel.calculate_natural_terminal_fall_speed(
			gravity,
			profile,
			1.0,
			tuning.space_drag
		)
	)
	var velocity: Vector2 = Vector2.ZERO
	var one_second_speed: float = 0.0
	var five_second_speed: float = 0.0
	for frame_index: int in 1200:
		velocity = FlightEnvironmentModel.step_velocity(
			velocity,
			gravity,
			profile,
			1.0,
			tuning.space_drag,
			FIXED_DELTA
		)
		if frame_index == 59:
			one_second_speed = velocity.y
		elif frame_index == 299:
			five_second_speed = velocity.y
	expect_true(
		one_second_speed > 0.0 and five_second_speed > one_second_speed,
		"Released flight in atmosphere must accelerate downward before stabilizing.",
		failures
	)
	expect_true(
		absf(velocity.y - natural_terminal) < 0.5
		and natural_terminal < profile.terminal_fall_speed_safety,
		"Atmospheric fall must converge naturally below the configured safety cap.",
		failures
	)

	var horizontal_velocity: Vector2 = Vector2(300.0, 0.0)
	for _frame_index: int in 180:
		horizontal_velocity = FlightEnvironmentModel.step_velocity(
			horizontal_velocity,
			0.0,
			profile,
			1.0,
			tuning.space_drag,
			FIXED_DELTA
		)
	expect_true(
		horizontal_velocity.x < 130.0
		and is_zero_approx(horizontal_velocity.y),
		"Horizontal atmosphere drag must decay forward speed independently.",
		failures
	)

	var safety_profile: FlightEnvironmentProfile = profile.duplicate(true) as FlightEnvironmentProfile
	safety_profile.terminal_fall_speed_safety = 100.0
	var safety_limited: Vector2 = FlightEnvironmentModel.step_velocity(
		Vector2(0.0, 900.0),
		gravity,
		safety_profile,
		1.0,
		tuning.space_drag,
		FIXED_DELTA
	)
	expect_true(
		is_equal_approx(safety_limited.y, 100.0),
		"Terminal fall safety must cap pathological downward speed.",
		failures
	)
	var partially_blended_limit: Vector2 = (
		FlightEnvironmentModel.apply_terminal_fall_speed_safety(
			Vector2(0.0, 900.0),
			safety_profile,
			0.5
		)
	)
	expect_true(
		is_equal_approx(partially_blended_limit.y, 200.0),
		"Terminal safety must blend in with atmosphere density instead of hard cutting.",
		failures
	)


func _test_profile_replacement_changes_planet_gravity(
	profile: FlightEnvironmentProfile,
	failures: Array[String]
) -> void:
	var heavier_planet: FlightEnvironmentProfile = (
		profile.duplicate(true) as FlightEnvironmentProfile
	)
	heavier_planet.id = &"environment_heavier_planet_test"
	heavier_planet.planet_gravity = profile.planet_gravity * 1.3
	var red_sand_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		0.75
	)
	var heavier_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		heavier_planet,
		1.0,
		0.75
	)
	expect_true(
		heavier_gravity > red_sand_gravity,
		"Replacing a planet environment profile must change gravity without formula edits.",
		failures
	)


func _test_dive_and_pull_up_recovery(
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var effective_gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		0.75
	)
	var passive_velocity: Vector2 = Vector2.ZERO
	var dive_velocity: Vector2 = Vector2.ZERO
	for _frame_index: int in 60:
		passive_velocity = _step_combined_motion(
			passive_velocity,
			0.0,
			0.0,
			0.0,
			effective_gravity,
			profile,
			tuning
		)
		dive_velocity = _step_combined_motion(
			dive_velocity,
			0.75,
			1.0,
			0.0,
			effective_gravity,
			profile,
			tuning
		)
	expect_true(
		dive_velocity.y > passive_velocity.y * 2.0,
		"Nose-down thrust must accelerate a dive beyond passive falling.",
		failures
	)
	var dive_downward_speed: float = dive_velocity.y
	for _frame_index: int in 90:
		dive_velocity = _step_combined_motion(
			dive_velocity,
			-1.1,
			1.0,
			0.25,
			effective_gravity,
			profile,
			tuning
		)
	expect_true(
		dive_velocity.y < dive_downward_speed * 0.4,
		"Pull-up thrust and braking must recover from a dive.",
		failures
	)


func _test_deep_space_preserves_zero_gravity(
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		profile.target_gravity_blend,
		0.0
	)
	var velocity: Vector2 = FlightEnvironmentModel.step_velocity(
		Vector2(200.0, 400.0),
		gravity,
		profile,
		profile.target_air_density,
		tuning.space_drag,
		1.0
	)
	expect_true(
		is_zero_approx(gravity)
		and velocity.x > 190.0
		and velocity.y > 380.0,
		"Deep-space profile must retain zero gravity, uncapped inertia, and low drag.",
		failures
	)


func _simulate_uncontrolled_fall(
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning,
	assist_strength: float,
	duration: float
) -> float:
	var gravity: float = FlightEnvironmentModel.calculate_effective_gravity(
		profile,
		1.0,
		assist_strength
	)
	var velocity: Vector2 = Vector2.ZERO
	var frame_count: int = roundi(duration / FIXED_DELTA)
	for _frame_index: int in frame_count:
		velocity = FlightEnvironmentModel.step_velocity(
			velocity,
			gravity,
			profile,
			1.0,
			tuning.space_drag,
			FIXED_DELTA
		)
	return velocity.y


func _step_combined_motion(
	current_velocity: Vector2,
	rotation: float,
	throttle_input: float,
	brake_input: float,
	effective_gravity: float,
	profile: FlightEnvironmentProfile,
	tuning: FlightTuning
) -> Vector2:
	var controlled_velocity: Vector2 = FlightMotionModel.step_control_velocity(
		current_velocity,
		rotation,
		throttle_input,
		brake_input,
		tuning,
		FIXED_DELTA
	)
	var environment_velocity: Vector2 = FlightEnvironmentModel.step_velocity(
		controlled_velocity,
		effective_gravity,
		profile,
		1.0,
		tuning.space_drag,
		FIXED_DELTA
	)
	return FlightMotionModel.apply_speed_limits(
		environment_velocity,
		rotation,
		tuning
	)
