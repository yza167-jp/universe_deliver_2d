extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_stage_modes_and_prepared_handoff(failures)
	_test_frame_rate_independent_agl_smoothing(failures)
	_test_invalid_height_has_no_numeric_sentinel(failures)
	_test_short_hold_last_valid_grace(failures)
	_test_ray_profile_mismatch_is_explicit(failures)
	_test_hud_and_radar_share_final_agl(failures)
	_test_reset_is_deterministic(failures)
	_test_motion_invariant_detection(failures)
	return failures


func _test_stage_modes_and_prepared_handoff(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.update_from_canonical_samples(
		0, 0.5, 2000.0, 198.0, 1000.0, false, 0.0, false, 0.1
	)
	expect_true(
		provider.get_mode_name() == &"ORBITAL"
		and not provider.has_numeric_altitude()
		and provider.is_using_high_altitude_fallback()
		and provider.get_altitude_meters()
		> FlightAltitudeReferenceProvider.HIGH_ALTITUDE_THRESHOLD_METERS,
		"Stages 1-3 must expose only the nonnumeric >1 km state.",
		failures
	)

	provider.update_from_canonical_samples(
		3, 0.0, 13500.0, 198.0, 760.0, false, 0.0, false, 0.1
	)
	var atmosphere_start: float = provider.get_altitude_meters()
	provider.update_from_canonical_samples(
		3, 1.0, 18000.0, 198.0, 760.0, false, 0.0, false, 0.1
	)
	var atmosphere_boundary: float = provider.get_altitude_meters()
	provider.update_from_canonical_samples(
		4, 0.0, 18000.0, 198.0, 760.0, true, 562.0, true, 0.1
	)
	var stage_five_start: float = provider.get_altitude_meters()
	provider.update_from_canonical_samples(
		4, 1.0, 23000.0, 60.0, 660.0, true, 600.0, true, 0.1
	)
	var stage_five_last: float = provider.get_altitude_meters()
	provider.update_from_canonical_samples(
		5, 0.0, 23000.0, 60.0, 660.0, true, 600.0, true, 0.0
	)
	var stage_six_first: float = provider.get_altitude_meters()
	expect_true(
		provider.get_mode_name() == &"AGL"
		and provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and is_equal_approx(atmosphere_start, 1800.0)
		and is_equal_approx(atmosphere_boundary, 1200.0)
		and is_equal_approx(stage_five_start, 1200.0)
		and is_equal_approx(stage_five_last, 600.0)
		and is_equal_approx(stage_six_first, stage_five_last)
		and provider.get_source_name() == &"PROFILE",
		"Stage 5 must prepare the route-space AGL so Stage 6 inherits it without a semantic jump.",
		failures
	)


func _test_frame_rate_independent_agl_smoothing(failures: Array[String]) -> void:
	var one_step: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	one_step.reset_to_canonical_samples(
		4, 1.0, 22999.0, 60.0, 660.0, true, 600.0, true
	)
	one_step.update_from_canonical_samples(
		5, 0.1, 23750.0, 360.0, 660.0, true, 300.0, true, 1.0
	)

	var sixty_steps: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	sixty_steps.reset_to_canonical_samples(
		4, 1.0, 22999.0, 60.0, 660.0, true, 600.0, true
	)
	for _frame: int in 60:
		sixty_steps.update_from_canonical_samples(
			5, 0.1, 23750.0, 360.0, 660.0, true, 300.0, true, 1.0 / 60.0
		)

	expect_true(
		absf(one_step.get_altitude_meters() - sixty_steps.get_altitude_meters()) < 0.001
		and one_step.get_altitude_meters() > 300.0
		and one_step.get_altitude_meters() < 310.0,
		"AGL smoothing must depend on elapsed time rather than frame count.",
		failures
	)


func _test_invalid_height_has_no_numeric_sentinel(failures: Array[String]) -> void:
	var contact_provider: FlightAltitudeReferenceProvider = (
		FlightAltitudeReferenceProvider.new()
	)
	contact_provider.reset_to_canonical_samples(
		5, 0.0, 23000.0, 659.0, 660.0, true, 1.0, true
	)
	expect_true(
		contact_provider.has_numeric_altitude()
		and is_equal_approx(contact_provider.get_altitude_meters(), 1.0),
		"A genuine route-space 1 m AGL sample must remain valid.",
		failures
	)

	var below_provider: FlightAltitudeReferenceProvider = (
		FlightAltitudeReferenceProvider.new()
	)
	below_provider.reset_to_canonical_samples(
		5, 0.0, 23000.0, 661.0, 660.0, true, 0.0, false
	)
	expect_true(
		not below_provider.has_numeric_altitude()
		and not below_provider.is_current_source_valid()
		and below_provider.get_source_name() == &"INVALID"
		and below_provider.get_failure_reason() == &"REFERENCE_BELOW_TERRAIN_PROFILE"
		and is_zero_approx(below_provider.raw_profile_altitude_meters)
		and not below_provider.is_using_high_altitude_fallback(),
		"A below-profile reference must be explicitly invalid, never a valid 1 m or >1 km sentinel.",
		failures
	)


func _test_short_hold_last_valid_grace(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_canonical_samples(
		5, 0.2, 24500.0, 380.0, 660.0, true, 280.0, true
	)
	provider.update_from_canonical_samples(
		5, 0.2, 24500.0, 380.0, 0.0, false, 0.0, false, 0.10
	)
	var held_altitude: float = provider.get_altitude_meters()
	var held_valid: bool = provider.has_numeric_altitude()
	var held_source: StringName = provider.get_source_name()
	provider.update_from_canonical_samples(
		5, 0.2, 24500.0, 380.0, 0.0, false, 0.0, false, 0.11
	)
	expect_true(
		held_valid
		and held_source == &"HOLD_LAST_VALID"
		and is_equal_approx(held_altitude, 280.0)
		and not provider.has_numeric_altitude()
		and provider.get_source_name() == &"INVALID"
		and provider.invalid_duration_seconds > provider.invalid_source_grace_seconds,
		"A dual-source miss may hold the last AGL only for the configured short grace period.",
		failures
	)


func _test_ray_profile_mismatch_is_explicit(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_canonical_samples(
		5, 0.2, 24500.0, 360.0, 660.0, true, 320.0, true
	)
	expect_true(
		provider.has_cross_source_mismatch()
		and not provider.has_numeric_altitude()
		and provider.get_failure_reason() == &"RAY_PROFILE_MISMATCH"
		and is_equal_approx(provider.ray_profile_difference_meters, 20.0),
		"Ray/profile disagreement above tolerance must fail explicitly instead of selecting a random source.",
		failures
	)


func _test_hud_and_radar_share_final_agl(failures: Array[String]) -> void:
	for altitude: float in [600.0, 300.0, 280.0, 150.0, 1.0, 0.0, 1000.0]:
		var provider: FlightAltitudeReferenceProvider = (
			FlightAltitudeReferenceProvider.new()
		)
		provider.reset_to_canonical_samples(
			5,
			0.25,
			24875.0,
			660.0 - altitude,
			660.0,
			true,
			altitude,
			true
		)
		expect_true(
			provider.has_numeric_altitude()
			and is_equal_approx(provider.get_hud_altitude_meters(), altitude)
			and is_equal_approx(provider.get_radar_altitude_meters(), altitude),
			"HUD and radar must share the exact final %.0f m AGL value." % altitude,
			failures
		)


func _test_reset_is_deterministic(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_canonical_samples(
		5, 0.3, 25000.0, 327.0, 660.0, true, 333.0, true
	)
	provider.update_from_canonical_samples(
		5, 0.4, 26000.0, 510.0, 640.0, true, 130.0, true, 0.05
	)
	provider.reset_to_canonical_samples(
		5, 0.3, 25000.0, 327.0, 660.0, true, 333.0, true
	)
	expect_true(
		provider.has_numeric_altitude()
		and provider.is_current_source_valid()
		and is_equal_approx(provider.get_altitude_meters(), 333.0)
		and is_equal_approx(provider.last_valid_agl_meters, 333.0)
		and is_zero_approx(provider.invalid_duration_seconds),
		"Checkpoint reset must reproduce the canonical frame without old smoothing or invalid history.",
		failures
	)


func _test_motion_invariant_detection(failures: Array[String]) -> void:
	expect_true(
		FlightAltitudeReferenceProvider.is_motion_invariant_violated(
			300.0, 280.0, 660.0, 660.0, 360.0, 360.2, 1.0, 12.0, 0.75
		)
		and not FlightAltitudeReferenceProvider.is_motion_invariant_violated(
			300.0, 280.0, 660.0, 660.0, 360.0, 380.0, 1.0, 12.0, 0.75
		)
		and not FlightAltitudeReferenceProvider.is_motion_invariant_violated(
			300.0, 280.0, 660.0, 640.0, 360.0, 360.0, 1.0, 12.0, 0.75
		),
		"The runtime invariant must detect a frozen Final AGL without flagging correct or terrain-following motion.",
		failures
	)
