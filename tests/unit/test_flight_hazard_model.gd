extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_wind_is_deterministic_and_time_varying(failures)
	_test_assist_reduces_control_pressure(failures)
	_test_external_velocity_step_is_bounded(failures)
	return failures


func _test_wind_is_deterministic_and_time_varying(
	failures: Array[String]
) -> void:
	var base_wind: Vector2 = Vector2(-18.0, 8.0)
	var gust_wind: Vector2 = Vector2(12.0, 92.0)
	var first: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		2.5,
		0.0,
		0.7
	)
	var repeated: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		2.5,
		0.0,
		0.7
	)
	var later: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		3.2,
		0.0,
		0.7
	)
	expect_true(
		first.is_equal_approx(repeated) and not first.is_equal_approx(later),
		"Storm wind must repeat exactly on retry while still varying over time.",
		failures
	)


func _test_assist_reduces_control_pressure(failures: Array[String]) -> void:
	var base_wind: Vector2 = Vector2(-18.0, 8.0)
	var gust_wind: Vector2 = Vector2(12.0, 92.0)
	var no_assist: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		1.75,
		0.0,
		0.7
	)
	var default_assist: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		1.75,
		0.75,
		0.7
	)
	var full_assist: Vector2 = FlightHazardModel.calculate_storm_wind(
		base_wind,
		gust_wind,
		0.38,
		1.75,
		1.0,
		0.7
	)
	expect_true(
		no_assist.length() > default_assist.length()
		and default_assist.length() > full_assist.length()
		and is_equal_approx(
			FlightHazardModel.calculate_assist_mitigation(0.75, 0.7),
			0.525
		),
		"0%, 75%, and 100% assist must progressively reduce storm wind pressure.",
		failures
	)


func _test_external_velocity_step_is_bounded(failures: Array[String]) -> void:
	var stepped: Vector2 = FlightHazardModel.step_velocity(
		Vector2(500.0, 0.0),
		Vector2(500.0, 500.0),
		1.0,
		520.0
	)
	expect_true(
		stepped.length() <= 520.001 and stepped.y > 0.0,
		"Storm acceleration must respect the configured total-speed safety bound.",
		failures
	)
