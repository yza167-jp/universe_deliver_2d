extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_stage_modes_and_virtual_altitude(failures)
	_test_frame_rate_independent_agl_smoothing(failures)
	_test_missing_raycast_uses_profile_and_last_valid_agl(failures)
	_test_required_radar_altitudes_share_one_final_value(failures)
	_test_reset_is_deterministic(failures)
	_test_meter_and_kilometer_boundaries(failures)
	return failures


func _test_stage_modes_and_virtual_altitude(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.update_from_terrain_sample(0, 0.5, 0.0, false, 0.1)
	expect_true(
		provider.mode == FlightAltitudeReferenceProvider.Mode.ORBITAL
		and provider.get_mode_name() == &"ORBITAL"
		and not provider.virtual_altitude_valid
		and provider.is_using_high_altitude_fallback()
		and not provider.has_numeric_altitude()
		and provider.get_display_altitude_meters() >
			FlightAltitudeReferenceProvider.HIGH_ALTITUDE_THRESHOLD_METERS
		and is_equal_approx(
			provider.get_altitude_meters(),
			FlightAltitudeReferenceProvider.HIGH_ALTITUDE_FALLBACK_METERS
		),
		"Stages 1-3 must expose only the high-altitude fallback.",
		failures
	)

	provider.update_from_terrain_sample(3, 0.0, 0.0, false, 0.1)
	var atmosphere_start: float = provider.get_altitude_meters()
	provider.update_from_terrain_sample(3, 1.0, 0.0, false, 0.1)
	var atmosphere_boundary: float = provider.get_altitude_meters()
	provider.update_from_terrain_sample(4, 1.0, 0.0, false, 0.1)
	var atmosphere_end: float = provider.get_altitude_meters()
	expect_true(
		provider.mode == FlightAltitudeReferenceProvider.Mode.ATMOSPHERE_ENTRY
		and provider.get_mode_name() == &"ATMOSPHERE_ENTRY"
		and provider.has_numeric_altitude()
		and is_equal_approx(atmosphere_start, 1800.0)
		and is_equal_approx(atmosphere_boundary, 1200.0)
		and is_equal_approx(atmosphere_end, 1050.0),
		"Stages 4-5 must provide the configured 1.8 km to 1.05 km virtual descent.",
		failures
	)

	provider.reset_to_route_state(5, 0.0, 320.0, true)
	expect_true(
		provider.mode == FlightAltitudeReferenceProvider.Mode.AGL
		and provider.get_mode_name() == &"AGL"
		and provider.terrain_hit_valid
		and is_equal_approx(provider.raw_virtual_altitude_meters, 1050.0)
		and is_equal_approx(provider.raw_terrain_altitude_meters, 320.0)
		and is_equal_approx(provider.get_altitude_meters(), 320.0),
		"Stages 6-8 must use valid terrain AGL while preserving the virtual handoff datum.",
		failures
	)


func _test_frame_rate_independent_agl_smoothing(failures: Array[String]) -> void:
	var one_step: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	one_step.reset_to_route_state(4, 1.0)
	one_step.update_from_terrain_sample(5, 0.0, 250.0, true, 1.0)

	var sixty_steps: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	sixty_steps.reset_to_route_state(4, 1.0)
	for _frame: int in 60:
		sixty_steps.update_from_terrain_sample(5, 0.0, 250.0, true, 1.0 / 60.0)

	expect_true(
		absf(one_step.get_altitude_meters() - sixty_steps.get_altitude_meters()) < 0.001
		and one_step.get_altitude_meters() > 250.0
		and one_step.get_altitude_meters() < 1050.0,
		"Virtual-to-AGL smoothing must depend on elapsed time, not frame count.",
		failures
	)
	expect_true(
		is_equal_approx(
			one_step.get_hud_altitude_meters(),
			one_step.get_radar_altitude_meters()
		),
		"HUD and radar accessors must share the same final smoothed altitude.",
		failures
	)


func _test_missing_raycast_uses_profile_and_last_valid_agl(
	failures: Array[String]
) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_route_state(5, 0.0, 280.0, true)
	provider.update_from_altitude_samples(6, 0.4, 0.0, false, 275.0, true, 1.0)
	expect_true(
		provider.mode == FlightAltitudeReferenceProvider.Mode.AGL
		and not provider.terrain_hit_valid
		and provider.profile_altitude_valid
		and provider.has_numeric_altitude()
		and provider.get_source_name() == &"TERRAIN_PROFILE_FALLBACK"
		and provider.get_altitude_meters() >= 275.0
		and provider.get_altitude_meters() < 280.0
		and provider.get_altitude_meters()
		== provider.get_radar_altitude_meters(),
		"An AGL ray miss must use the shared route profile instead of >1 km or zero.",
		failures
	)
	var last_valid_altitude: float = provider.get_altitude_meters()
	provider.update_from_altitude_samples(7, 0.4, 0.0, false, 0.0, false, 0.2)
	expect_true(
		provider.has_numeric_altitude()
		and provider.get_source_name() == &"LAST_VALID_AGL"
		and is_equal_approx(provider.get_altitude_meters(), last_valid_altitude),
		"A transient dual-source miss in stages 6-8 must retain the last valid AGL.",
		failures
	)

	var invalid_provider: FlightAltitudeReferenceProvider = (
		FlightAltitudeReferenceProvider.new()
	)
	invalid_provider.update_from_altitude_samples(
		5, 0.0, 0.0, false, 0.0, false, 0.2
	)
	expect_true(
		invalid_provider.get_mode_name() == &"AGL"
		and not invalid_provider.has_numeric_altitude()
		and not invalid_provider.altitude_source_valid
		and invalid_provider.get_failure_reason() == &"NO_VALID_AGL_SOURCE",
		"A continuous dual-source AGL failure must stay invalid and expose its reason.",
		failures
	)


func _test_required_radar_altitudes_share_one_final_value(
	failures: Array[String]
) -> void:
	for altitude: float in [600.0, 300.0, 280.0, 150.0, 400.0]:
		var provider: FlightAltitudeReferenceProvider = (
			FlightAltitudeReferenceProvider.new()
		)
		provider.reset_to_route_state(5, 0.25, altitude, true)
		expect_true(
			provider.has_numeric_altitude()
			and is_equal_approx(provider.get_hud_altitude_meters(), altitude)
			and is_equal_approx(provider.get_radar_altitude_meters(), altitude)
			and provider.get_altitude_meters()
			>= FlightAltitudeReferenceProvider.MINIMUM_VALID_AGL_METERS,
			"HUD and radar must share the final %.0f m AGL sample." % altitude,
			failures
		)


func _test_reset_is_deterministic(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_route_state(4, 1.0)
	provider.update_from_terrain_sample(5, 0.0, 180.0, true, 0.05)
	provider.reset_to_route_state(3, 0.5)
	var first_reset_altitude: float = provider.get_altitude_meters()
	provider.update_from_terrain_sample(5, 0.0, 640.0, true, 0.05)
	provider.reset_to_route_state(3, 0.5)
	expect_true(
		is_equal_approx(first_reset_altitude, 1500.0)
		and is_equal_approx(provider.get_altitude_meters(), first_reset_altitude)
		and is_equal_approx(provider.raw_virtual_altitude_meters, 1500.0),
		"Reset must reproduce virtual route altitude without retaining smoothing history.",
		failures
	)

	provider.reset_to_route_state(7, 0.75, 333.0, true)
	expect_true(
		provider.terrain_hit_valid
		and is_equal_approx(provider.get_altitude_meters(), 333.0),
		"Reset in an AGL stage must immediately restore the sampled terrain altitude.",
		failures
	)


func _test_meter_and_kilometer_boundaries(failures: Array[String]) -> void:
	var provider: FlightAltitudeReferenceProvider = FlightAltitudeReferenceProvider.new()
	provider.reset_to_route_state(5, 0.0, 999.0, true)
	var below_kilometer: float = provider.get_altitude_meters()
	provider.reset_to_route_state(5, 0.0, 1000.0, true)
	var at_kilometer: float = provider.get_altitude_meters()
	provider.reset_to_route_state(0, 0.0)
	expect_true(
		is_equal_approx(below_kilometer, 999.0)
		and is_equal_approx(at_kilometer, 1000.0)
		and is_equal_approx(
			provider.get_altitude_meters(),
			FlightAltitudeReferenceProvider.HIGH_ALTITUDE_FALLBACK_METERS
		)
		and provider.is_using_high_altitude_fallback(),
		"The formatter must be able to distinguish 999 m, numeric 1 km, and >1 km fallback.",
		failures
	)
