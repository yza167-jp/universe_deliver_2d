extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_low_altitude_exposure(failures)
	_test_phase_progress(failures)
	return failures


func _test_low_altitude_exposure(failures: Array[String]) -> void:
	var deep_low_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		150.0,
		300.0,
		150.0
	)
	var shallow_low_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		250.0,
		300.0,
		100.0
	)
	var high_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		450.0,
		300.0,
		100.0
	)
	expect_true(
		is_equal_approx(deep_low_exposure, 1.0)
		and is_equal_approx(shallow_low_exposure, 0.5)
		and is_zero_approx(high_exposure)
		and FlightRadarModel.is_low_altitude(299.9, 300.0)
		and not FlightRadarModel.is_low_altitude(300.0, 300.0),
		"Radar exposure must treat altitude below 300 m as dangerous and 300 m or higher as safe.",
		failures
	)


func _test_phase_progress(failures: Array[String]) -> void:
	expect_true(
		is_equal_approx(FlightRadarModel.calculate_phase_progress(0.5, 1.0), 0.5)
		and is_equal_approx(
			FlightRadarModel.calculate_cooldown_pressure(0.45, 1.8),
			0.75
		)
		and is_zero_approx(
			FlightRadarModel.calculate_cooldown_pressure(1.8, 1.8)
		),
		"Warning and cooldown progress must be deterministic and frame-rate independent.",
		failures
	)
