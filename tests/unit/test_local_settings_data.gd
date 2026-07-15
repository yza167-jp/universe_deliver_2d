extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var settings: LocalSettingsData = LocalSettingsData.new()

	expect_true(
		is_equal_approx(settings.flight_assist_strength, 0.75),
		"Flight assist must default to 75%.",
		failures
	)
	expect_true(settings.route_hints_enabled, "Route hints must default to enabled.", failures)
	expect_true(
		not settings.slow_motion_assist and not settings.high_contrast_terrain,
		"Visual and time-altering assists must be opt-in by default.",
		failures
	)

	settings.master_volume = 2.0
	settings.music_volume = -1.0
	settings.sfx_volume = 1.5
	settings.screen_shake_strength = -0.5
	settings.text_speed = 1000.0
	settings.flight_assist_strength = -2.0
	settings.sanitize()
	expect_true(is_equal_approx(settings.master_volume, 1.0), "Master volume must clamp.", failures)
	expect_true(is_equal_approx(settings.music_volume, 0.0), "Music volume must clamp.", failures)
	expect_true(is_equal_approx(settings.sfx_volume, 1.0), "SFX volume must clamp.", failures)
	expect_true(
		is_equal_approx(settings.screen_shake_strength, 0.0),
		"Screen shake strength must clamp.",
		failures
	)
	expect_true(
		is_equal_approx(settings.text_speed, LocalSettingsData.MAX_TEXT_SPEED),
		"Text speed must clamp to its readable range.",
		failures
	)
	expect_true(
		is_equal_approx(settings.flight_assist_strength, 0.0),
		"Flight assist strength must clamp to 0-100%.",
		failures
	)
	return failures
