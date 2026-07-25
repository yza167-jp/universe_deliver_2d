extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var profile: LowAltitudeDropProfile = _make_profile()
	_test_profile_validation(profile, failures)
	_test_deterministic_prediction(profile, failures)
	_test_release_window_boundaries(profile, failures)
	_test_zone_boundaries(profile, failures)
	_test_invalid_release_reasons(profile, failures)
	_test_single_cargo_and_retry(profile, failures)
	return failures


func _test_profile_validation(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	expect_true(
		profile.validate().is_empty(),
		"The default low-altitude drop profile must be valid.",
		failures
	)
	var invalid_profile: LowAltitudeDropProfile = _make_profile()
	invalid_profile.outer_zone_half_width = invalid_profile.core_zone_half_width - 1.0
	invalid_profile.cargo_descent_speed = 0.0
	expect_true(
		invalid_profile.validate().size() == 2,
		"Profile validation must reject an inverted receive zone and zero descent speed.",
		failures
	)


func _test_deterministic_prediction(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	var model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var expected_duration: float = 1.25
	var expected_landing_x: float = 1100.0 + 160.0 * 0.5 * expected_duration
	expect_true(
		is_equal_approx(
			LowAltitudeDropModel.calculate_fall_duration(profile, 150.0),
			expected_duration
		),
		"Fall duration must be altitude divided by configured descent speed.",
		failures
	)
	expect_true(
		is_equal_approx(
			model.predict_landing_x(profile, 1100.0, 150.0, 160.0),
			expected_landing_x
		)
		and is_equal_approx(
			model.predict_landing_x(profile, 1100.0, 150.0, 160.0),
			expected_landing_x
		),
		"Landing prediction must be deterministic and use horizontal velocity inheritance.",
		failures
	)


func _test_release_window_boundaries(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	var minimum_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var minimum_result: LowAltitudeDropResult = minimum_model.try_release(
		profile,
		Vector2(1400.0, 0.0),
		1500.0,
		profile.minimum_release_altitude,
		profile.minimum_release_speed
	)
	expect_true(
		minimum_result.is_release_valid(),
		"Minimum altitude and speed boundaries must be inclusive.",
		failures
	)

	var maximum_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var maximum_release_x: float = (
		1500.0
		- profile.maximum_release_speed
		* profile.horizontal_velocity_inheritance
		* profile.maximum_release_altitude
		/ profile.cargo_descent_speed
	)
	var maximum_result: LowAltitudeDropResult = maximum_model.try_release(
		profile,
		Vector2(maximum_release_x, 0.0),
		1500.0,
		profile.maximum_release_altitude,
		profile.maximum_release_speed
	)
	expect_true(
		maximum_result.status == LowAltitudeDropModel.Status.CORE_SUCCESS,
		"Maximum altitude and speed boundaries must remain valid.",
		failures
	)


func _test_zone_boundaries(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	var altitude: float = 120.0
	var speed: float = 120.0
	var inherited_travel: float = (
		speed
		* profile.horizontal_velocity_inheritance
		* altitude
		/ profile.cargo_descent_speed
	)
	var target_x: float = 1500.0

	var core_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var core_result: LowAltitudeDropResult = core_model.try_release(
		profile,
		Vector2(target_x + profile.core_zone_half_width - inherited_travel, 0.0),
		target_x,
		altitude,
		speed
	)
	expect_true(
		core_result.status == LowAltitudeDropModel.Status.CORE_SUCCESS
		and is_equal_approx(core_result.quality_ratio, 1.0)
		and is_equal_approx(core_result.reward_ratio, 1.0),
		"The core receive-zone boundary must be a full success.",
		failures
	)

	var outer_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var outer_result: LowAltitudeDropResult = outer_model.try_release(
		profile,
		Vector2(target_x + profile.outer_zone_half_width - inherited_travel, 0.0),
		target_x,
		altitude,
		speed
	)
	expect_true(
		outer_result.status == LowAltitudeDropModel.Status.OUTER_PARTIAL
		and is_equal_approx(outer_result.quality_ratio, profile.partial_quality_ratio)
		and is_equal_approx(outer_result.reward_ratio, profile.partial_reward_ratio),
		"The outer receive-zone boundary must use configured partial ratios.",
		failures
	)

	var miss_model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var miss_result: LowAltitudeDropResult = miss_model.try_release(
		profile,
		Vector2(target_x + profile.outer_zone_half_width + 0.01 - inherited_travel, 0.0),
		target_x,
		altitude,
		speed
	)
	expect_true(
		miss_result.status == LowAltitudeDropModel.Status.MISSED
		and is_zero_approx(miss_result.quality_ratio)
		and is_zero_approx(miss_result.reward_ratio),
		"Landing outside the outer boundary must fail.",
		failures
	)


func _test_invalid_release_reasons(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	var cases: Array[Dictionary] = [
		{
			"altitude": profile.minimum_release_altitude - 0.01,
			"speed": profile.minimum_release_speed,
			"reason": LowAltitudeDropModel.REASON_ALTITUDE_TOO_LOW,
		},
		{
			"altitude": profile.maximum_release_altitude + 0.01,
			"speed": profile.minimum_release_speed,
			"reason": LowAltitudeDropModel.REASON_ALTITUDE_TOO_HIGH,
		},
		{
			"altitude": profile.minimum_release_altitude,
			"speed": profile.minimum_release_speed - 0.01,
			"reason": LowAltitudeDropModel.REASON_SPEED_TOO_LOW,
		},
		{
			"altitude": profile.minimum_release_altitude,
			"speed": profile.maximum_release_speed + 0.01,
			"reason": LowAltitudeDropModel.REASON_SPEED_TOO_HIGH,
		},
	]
	for case_data: Dictionary in cases:
		var model: LowAltitudeDropModel = LowAltitudeDropModel.new()
		var result: LowAltitudeDropResult = model.try_release(
			profile,
			Vector2(1400.0, 0.0),
			1500.0,
			float(case_data["altitude"]),
			float(case_data["speed"])
		)
		expect_true(
			result.status == LowAltitudeDropModel.Status.INVALID_RELEASE
			and result.reason_key == case_data["reason"]
			and not model.has_released_cargo()
			and model.get_release_count() == 0,
			"Invalid altitude/speed must report its reason without consuming cargo.",
			failures
		)


func _test_single_cargo_and_retry(
	profile: LowAltitudeDropProfile,
	failures: Array[String]
) -> void:
	var model: LowAltitudeDropModel = LowAltitudeDropModel.new()
	var first_result: LowAltitudeDropResult = model.try_release(
		profile,
		Vector2(1400.0, 0.0),
		1500.0,
		120.0,
		120.0
	)
	var repeated_result: LowAltitudeDropResult = model.try_release(
		profile,
		Vector2(1400.0, 0.0),
		1500.0,
		120.0,
		120.0
	)
	expect_true(
		first_result.is_release_valid()
		and repeated_result.status == LowAltitudeDropModel.Status.INVALID_RELEASE
		and repeated_result.reason_key == LowAltitudeDropModel.REASON_ALREADY_RELEASED
		and model.get_release_count() == 1
		and model.get_settled_result() == first_result,
		"Repeated input must not create or replace a second cargo result.",
		failures
	)
	model.reset()
	expect_true(
		not model.has_released_cargo()
		and model.get_release_count() == 0
		and model.get_settled_result().status == LowAltitudeDropModel.Status.PENDING,
		"Checkpoint retry must restore pending cargo and drop state.",
		failures
	)


func _make_profile() -> LowAltitudeDropProfile:
	var profile: LowAltitudeDropProfile = LowAltitudeDropProfile.new()
	profile.minimum_release_altitude = 80.0
	profile.maximum_release_altitude = 220.0
	profile.minimum_release_speed = 80.0
	profile.maximum_release_speed = 240.0
	profile.core_zone_half_width = 100.0
	profile.outer_zone_half_width = 200.0
	profile.cargo_descent_speed = 120.0
	profile.horizontal_velocity_inheritance = 0.5
	profile.partial_quality_ratio = 0.75
	profile.partial_reward_ratio = 0.65
	return profile
