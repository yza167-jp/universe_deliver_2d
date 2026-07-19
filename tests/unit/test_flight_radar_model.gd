extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_altitude_exposure(failures)
	_test_high_route_acquires_lock(failures)
	_test_low_route_and_cover_decay_lock(failures)
	_test_lock_hysteresis(failures)
	return failures


func _test_altitude_exposure(failures: Array[String]) -> void:
	var high_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		190.0,
		350.0,
		120.0
	)
	var transition_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		290.0,
		350.0,
		120.0
	)
	var low_exposure: float = FlightRadarModel.calculate_altitude_exposure(
		390.0,
		350.0,
		120.0
	)
	expect_true(
		is_equal_approx(high_exposure, 1.0)
		and is_equal_approx(transition_exposure, 0.5)
		and is_zero_approx(low_exposure),
		"Radar altitude exposure must distinguish high, transition, and low routes.",
		failures
	)


func _test_high_route_acquires_lock(failures: Array[String]) -> void:
	var risk: float = FlightRadarModel.step_lock_risk(
		0.0,
		1.0,
		true,
		false,
		2.0,
		0.55,
		0.8
	)
	expect_true(
		is_equal_approx(risk, 1.0)
		and FlightRadarModel.resolve_lock_state(risk, false, false, 0.5),
		"A sustained high route must acquire radar lock before crossing a fixed sector.",
		failures
	)


func _test_low_route_and_cover_decay_lock(failures: Array[String]) -> void:
	var low_route_risk: float = FlightRadarModel.step_lock_risk(
		0.0,
		0.0,
		true,
		false,
		5.0,
		0.55,
		0.8
	)
	var covered_risk: float = FlightRadarModel.step_lock_risk(
		1.0,
		1.0,
		true,
		true,
		0.75,
		0.55,
		0.8
	)
	expect_true(
		is_zero_approx(low_route_risk)
		and covered_risk < 0.5
		and not FlightRadarModel.resolve_lock_state(
			covered_risk,
			true,
			true,
			0.5
		),
		"Low flight and terrain cover must prevent or break radar lock.",
		failures
	)


func _test_lock_hysteresis(failures: Array[String]) -> void:
	expect_true(
		FlightRadarModel.resolve_lock_state(0.72, true, false, 0.5)
		and not FlightRadarModel.resolve_lock_state(0.49, true, false, 0.5)
		and not FlightRadarModel.resolve_lock_state(0.99, false, false, 0.5),
		"Radar lock must release below its threshold without flickering during decay.",
		failures
	)
