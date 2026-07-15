extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var move_speed: float = 120.0
	var diagonal_velocity: Vector2 = StationPlayer.calculate_target_velocity(
		Vector2(1.0, 1.0),
		move_speed
	)
	expect_true(
		is_equal_approx(diagonal_velocity.length(), move_speed),
		"Diagonal movement must be normalized to the configured move speed.",
		failures
	)
	expect_true(
		is_equal_approx(absf(diagonal_velocity.x), absf(diagonal_velocity.y)),
		"Normalized diagonal movement must preserve equal axis intent.",
		failures
	)

	var accelerated: Vector2 = StationPlayer.step_velocity(
		Vector2.ZERO,
		Vector2(move_speed, 0.0),
		600.0,
		800.0,
		0.1
	)
	expect_true(
		accelerated.is_equal_approx(Vector2(60.0, 0.0)),
		"Movement must approach target velocity using the configured acceleration.",
		failures
	)

	var decelerated: Vector2 = StationPlayer.step_velocity(
		Vector2(move_speed, 0.0),
		Vector2.ZERO,
		600.0,
		800.0,
		0.05
	)
	expect_true(
		decelerated.is_equal_approx(Vector2(80.0, 0.0)),
		"Releasing movement must use the configured deceleration.",
		failures
	)
	expect_true(
		StationPlayer.calculate_target_velocity(Vector2.ZERO, move_speed).is_zero_approx(),
		"No input must produce a zero target velocity.",
		failures
	)
	return failures
