extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	var presets: Array[float] = FlightAssistMode.get_presets()
	expect_true(
		presets == [0.0, 0.75, 1.0],
		"Flight assist presets must retain the accepted 0/75/100 values.",
		failures
	)
	expect_true(
		FlightAssistMode.get_display_name_key(FlightAssistMode.OFF)
		== FlightAssistMode.OFF_NAME_KEY
		and FlightAssistMode.get_display_name_key(FlightAssistMode.LIMITED)
		== FlightAssistMode.LIMITED_NAME_KEY
		and FlightAssistMode.get_display_name_key(FlightAssistMode.UNLIMITED)
		== FlightAssistMode.UNLIMITED_NAME_KEY,
		"Each accepted assist value must map to one shared player-facing name key.",
		failures
	)
	expect_true(
		FlightAssistMode.get_description_key(FlightAssistMode.OFF).is_empty()
		and FlightAssistMode.get_description_key(FlightAssistMode.LIMITED).is_empty()
		and FlightAssistMode.get_description_key(FlightAssistMode.UNLIMITED)
		== FlightAssistMode.UNLIMITED_DESCRIPTION_KEY,
		"Only Unlimited gravity assist needs the continuous fuel-cost clarification.",
		failures
	)
	return failures
