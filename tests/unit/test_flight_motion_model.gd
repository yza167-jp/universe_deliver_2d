extends ProjectTestSuite

const FLOAT_TOLERANCE: float = 0.001
const M0_TUNING_PATH: String = "res://data/tuning/flight_tuning_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_thrust_follows_ship_forward(failures)
	_test_boost_adds_configured_forward_acceleration(failures)
	_test_space_drag_preserves_inertia(failures)
	_test_brake_decelerates_without_reversing(failures)
	_test_speed_limit_is_enforced(failures)
	_test_pitch_response_and_damping(failures)
	_test_pitch_limit_is_enforced(failures)
	_test_tuning_changes_motion_without_formula_changes(failures)
	_test_default_tuning_reaches_high_speed_and_coasts(failures)
	return failures


func _test_boost_adds_configured_forward_acceleration(
	failures: Array[String]
) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.boost_multiplier = 2.0
	var boosted_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		0.0,
		0.0,
		0.0,
		tuning,
		0.5,
		1.0
	)
	_expect_vector_close(
		boosted_velocity,
		Vector2(100.0, 0.0),
		"Boost must add its configured forward acceleration without requiring throttle.",
		failures
	)


func _test_thrust_follows_ship_forward(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	var horizontal_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		0.0,
		1.0,
		0.0,
		tuning,
		0.5
	)
	_expect_vector_close(
		horizontal_velocity,
		Vector2(100.0, 0.0),
		"Throttle must accelerate along the ship's forward direction.",
		failures
	)

	var downward_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		PI * 0.5,
		1.0,
		0.0,
		tuning,
		0.5
	)
	_expect_vector_close(
		downward_velocity,
		Vector2(0.0, 100.0),
		"Rotated thrust must follow the rotated ship nose.",
		failures
	)


func _test_space_drag_preserves_inertia(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.space_drag = 0.05
	var coast_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2(200.0, 0.0),
		0.0,
		0.0,
		0.0,
		tuning,
		1.0
	)
	expect_true(
		coast_velocity.x < 200.0 and coast_velocity.x > 190.0,
		"Releasing throttle in space must preserve most speed instead of stopping.",
		failures
	)


func _test_brake_decelerates_without_reversing(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.brake_acceleration = 100.0
	var braked_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2(200.0, 0.0),
		0.0,
		0.0,
		1.0,
		tuning,
		0.5
	)
	_expect_vector_close(
		braked_velocity,
		Vector2(150.0, 0.0),
		"Brake must reduce speed gradually.",
		failures
	)
	var stopped_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2(40.0, 0.0),
		0.0,
		0.0,
		1.0,
		tuning,
		2.0
	)
	_expect_vector_close(
		stopped_velocity,
		Vector2.ZERO,
		"Brake must stop at zero without automatically reversing the ship.",
		failures
	)


func _test_speed_limit_is_enforced(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.thrust_acceleration = 1000.0
	tuning.max_forward_speed = 300.0
	tuning.max_total_speed = 500.0
	var capped_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		0.0,
		1.0,
		0.0,
		tuning,
		1.0
	)
	expect_true(
		is_equal_approx(capped_velocity.length(), 300.0),
		"Explicit integration must enforce the configured forward speed limit.",
		failures
	)
	tuning.max_forward_speed = 1000.0
	tuning.max_total_speed = 250.0
	var total_capped_velocity: Vector2 = FlightMotionModel.step_velocity(
		Vector2(0.0, 400.0),
		0.0,
		0.0,
		0.0,
		tuning,
		1.0
	)
	expect_true(
		is_equal_approx(total_capped_velocity.length(), 250.0),
		"Explicit integration must enforce the configured total speed safety limit.",
		failures
	)


func _test_pitch_response_and_damping(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.max_pitch_rate = 2.0
	tuning.pitch_acceleration = 4.0
	tuning.angular_damping = 2.0
	var angular_velocity: float = FlightMotionModel.step_angular_velocity(
		0.0,
		1.0,
		tuning,
		0.25
	)
	_expect_float_close(
		angular_velocity,
		1.0,
		"Pitch input must build angular velocity instead of snapping rotation.",
		failures
	)
	angular_velocity = FlightMotionModel.step_angular_velocity(
		angular_velocity,
		1.0,
		tuning,
		0.25
	)
	_expect_float_close(
		angular_velocity,
		2.0,
		"Held pitch input must approach the configured maximum pitch rate.",
		failures
	)
	angular_velocity = FlightMotionModel.step_angular_velocity(
		angular_velocity,
		0.0,
		tuning,
		0.25
	)
	_expect_float_close(
		angular_velocity,
		1.5,
		"Released pitch input must damp angular velocity gradually.",
		failures
	)


func _test_pitch_limit_is_enforced(failures: Array[String]) -> void:
	var tuning: FlightTuning = _make_linear_tuning()
	tuning.max_pitch_degrees = 45.0
	var limited_rotation: float = FlightMotionModel.integrate_rotation(
		0.0,
		2.0,
		tuning,
		1.0
	)
	_expect_float_close(
		limited_rotation,
		PI * 0.25,
		"Pitch integration must prevent a 180-degree turn.",
		failures
	)


func _test_tuning_changes_motion_without_formula_changes(
	failures: Array[String]
) -> void:
	var low_thrust: FlightTuning = _make_linear_tuning()
	low_thrust.thrust_acceleration = 100.0
	var high_thrust: FlightTuning = _make_linear_tuning()
	high_thrust.thrust_acceleration = 250.0
	var low_result: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		0.0,
		1.0,
		0.0,
		low_thrust,
		1.0
	)
	var high_result: Vector2 = FlightMotionModel.step_velocity(
		Vector2.ZERO,
		0.0,
		1.0,
		0.0,
		high_thrust,
		1.0
	)
	expect_true(
		high_result.x > low_result.x * 2.0,
		"Replacing FlightTuning must change acceleration without editing formulas.",
		failures
	)


func _test_default_tuning_reaches_high_speed_and_coasts(
	failures: Array[String]
) -> void:
	var tuning: FlightTuning = load(M0_TUNING_PATH) as FlightTuning
	expect_true(
		tuning != null,
		"The M0 FlightTuning resource must load for default motion verification.",
		failures
	)
	if tuning == null:
		return
	var velocity: Vector2 = Vector2.ZERO
	for _frame_index: int in 180:
		velocity = FlightMotionModel.step_velocity(
			velocity,
			0.0,
			1.0,
			0.0,
			tuning,
			1.0 / 60.0
		)
	expect_true(
		velocity.length() > 350.0
		and velocity.length() <= tuning.max_forward_speed + FLOAT_TOLERANCE,
		"Default tuning must accelerate from rest into the high-speed range.",
		failures
	)
	var high_speed: float = velocity.length()
	for _frame_index: int in 60:
		velocity = FlightMotionModel.step_velocity(
			velocity,
			0.0,
			0.0,
			0.0,
			tuning,
			1.0 / 60.0
		)
	expect_true(
		velocity.length() > high_speed * 0.94,
		"Default space drag must preserve clear coasting inertia for one second.",
		failures
	)
	var speed_before_brake: float = velocity.length()
	for _frame_index: int in 15:
		velocity = FlightMotionModel.step_velocity(
			velocity,
			0.0,
			0.0,
			1.0,
			tuning,
			1.0 / 60.0
		)
	expect_true(
		velocity.length() < speed_before_brake and velocity.length() > 0.0,
		"Default brake must clearly slow high speed without stopping instantly.",
		failures
	)


func _make_linear_tuning() -> FlightTuning:
	var tuning: FlightTuning = FlightTuning.new()
	tuning.thrust_acceleration = 200.0
	tuning.brake_acceleration = 300.0
	tuning.space_drag = 0.0
	tuning.max_forward_speed = 1000.0
	tuning.max_total_speed = 1200.0
	tuning.brake_deadzone = 4.0
	return tuning


func _expect_vector_close(
	actual: Vector2,
	expected: Vector2,
	message: String,
	failures: Array[String]
) -> void:
	expect_true(
		actual.distance_to(expected) <= FLOAT_TOLERANCE,
		"%s Expected %s, got %s." % [message, expected, actual],
		failures
	)


func _expect_float_close(
	actual: float,
	expected: float,
	message: String,
	failures: Array[String]
) -> void:
	expect_true(
		absf(actual - expected) <= FLOAT_TOLERANCE,
		"%s Expected %.3f, got %.3f." % [message, expected, actual],
		failures
	)
