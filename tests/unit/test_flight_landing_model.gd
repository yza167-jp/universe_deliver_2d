extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning: FlightTuning = FlightTuning.new()

	expect_true(
		FlightLandingModel.classify_touchdown(
			Vector2(70.0, 24.0),
			deg_to_rad(5.0),
			30.0,
			tuning
		) == FlightLandingModel.Quality.SMOOTH,
		"A slow, level touchdown should be classified as smooth.",
		failures
	)
	expect_true(
		FlightLandingModel.classify_touchdown(
			Vector2(130.0, 55.0),
			deg_to_rad(14.0),
			62.0,
			tuning
		) == FlightLandingModel.Quality.ROUGH,
		"A recoverable touchdown outside smooth limits should remain a rough success.",
		failures
	)
	expect_true(
		is_equal_approx(
			FlightLandingModel.get_cargo_damage(
				FlightLandingModel.Quality.ROUGH,
				tuning
			),
			tuning.landing_rough_cargo_damage
		),
		"Rough landing cargo damage must come from FlightTuning.",
		failures
	)

	var unsafe_samples: Array[Array] = [
		[Vector2(181.0, 20.0), deg_to_rad(4.0), 25.0],
		[Vector2(90.0, 86.0), deg_to_rad(4.0), 90.0],
		[Vector2(90.0, 40.0), deg_to_rad(25.0), 45.0],
		[Vector2(90.0, 40.0), deg_to_rad(4.0), 101.0],
	]
	for sample: Array in unsafe_samples:
		var sample_velocity: Vector2 = sample[0]
		expect_true(
			FlightLandingModel.classify_touchdown(
				sample_velocity,
				float(sample[1]),
				float(sample[2]),
				tuning
			) == FlightLandingModel.Quality.FAILED,
			"Every success limit must independently reject an unsafe touchdown.",
			failures
		)

	tuning.landing_success_max_horizontal_speed = 70.0
	expect_true(
		FlightLandingModel.classify_touchdown(
			Vector2(80.0, 20.0),
			0.0,
			20.0,
			tuning
		) == FlightLandingModel.Quality.FAILED,
		"Landing thresholds must be replaceable without changing classifier code.",
		failures
	)
	expect_true(
		FlightLandingModel.get_result_id(FlightLandingModel.Quality.SMOOTH)
		== OrderRunState.LANDING_RESULT_SMOOTH,
		"Smooth landing result IDs must remain stable for arrival dialogue.",
		failures
	)
	return failures
