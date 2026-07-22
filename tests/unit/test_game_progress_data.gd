extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_round_trip(failures)
	_test_missing_fields_and_legacy_migration(failures)
	_test_invalid_data_is_rejected(failures)
	return failures


func _test_round_trip(failures: Array[String]) -> void:
	var source: GameStateModel = GameStateModel.new()
	source.current_order_id = &"order_red_sand_m0"
	source.destination_id = &"planet_red_sand"
	source.cargo_id = &"cargo_relay_core"
	source.ship_configuration[ShipLoadoutRules.SLOT_UTILITY] = (
		ShipLoadoutRules.LASER_MODULE_ID
	)
	source.story_flags[&"story_first_delivery"] = true
	source.read_dialogue_ids[&"dialogue_test/line_02"] = true
	source.completed_order_ids[&"order_orientation"] = true
	source.credits = 97
	source.station_upgrade_ids[&"station_upgrade_first_delivery_display"] = true
	source.departure_confirmed = true
	source.travel_state = GameStateModel.TravelState.CRUISE
	source.travel_destination_id = &"planet_red_sand"
	source.order_run_state.reset(source.current_order_id)
	source.order_run_state.cargo_integrity = 92.0
	source.order_run_state.hull = 84.0
	source.order_run_state.shield = 66.0
	source.order_run_state.fuel = 43.5
	source.order_run_state.boost_energy = 28.0
	source.order_run_state.active_checkpoint_id = &"checkpoint_atmosphere"
	source.order_run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	source.order_run_state.entry_duration = 37.5
	source.order_run_state.max_downward_speed = 215.0
	source.order_run_state.max_total_speed = 610.0
	source.order_run_state.max_risk_or_heat = 0.72
	source.order_run_state.scenic_trigger_count = 3
	source.order_run_state.late_pull_up_detected = true
	source.order_run_state.collision_count = 2
	source.order_run_state.elapsed_time = 101.25
	source.order_run_state.optional_trigger_ids = [&"storm_01", &"relay_ruin"]
	source.order_run_state.result_tags = [&"cargo_recovered"]

	var captured: GameProgressData = GameProgressData.capture(source)
	var serialized: Dictionary[String, Variant] = captured.to_dictionary()
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(serialized)
	var restored: GameStateModel = GameStateModel.new()

	expect_true(captured.is_valid(), "Captured game progress must be valid.", failures)
	expect_true(
		int(serialized.get("schema_version", -1)) == GameProgressData.CURRENT_SCHEMA_VERSION,
		"Serialized progress must carry the current schema version.",
		failures
	)
	expect_true(
		String(serialized.get("settings_reference", "")) == "local_settings",
		"Progress must reference, rather than embed, local settings.",
		failures
	)
	expect_true(restored_progress.is_valid(), restored_progress.validation_error, failures)
	expect_true(
		restored_progress.apply_to(restored),
		"Valid progress must apply to a fresh GameState.",
		failures
	)
	expect_true(
		restored.current_order_id == source.current_order_id
		and restored.destination_id == source.destination_id
		and restored.cargo_id == source.cargo_id,
		"Active order IDs must round-trip.",
		failures
	)
	expect_true(
		restored.ship_configuration == source.ship_configuration,
		"Stable ship module IDs must round-trip.",
		failures
	)
	expect_true(
		restored.story_flags == source.story_flags
		and restored.read_dialogue_ids == source.read_dialogue_ids
		and restored.completed_order_ids == source.completed_order_ids,
		"Story, read-dialogue, and completed-order IDs must round-trip.",
		failures
	)
	expect_true(
		restored.credits == 97
		and restored.station_upgrade_ids == source.station_upgrade_ids,
		"Credits and station upgrades must round-trip.",
		failures
	)
	expect_true(
		restored.departure_confirmed
		and restored.travel_state == GameStateModel.TravelState.CRUISE
		and restored.travel_destination_id == &"planet_red_sand",
		"Departure and travel state must round-trip.",
		failures
	)
	var run_state: OrderRunState = restored.order_run_state
	expect_true(
		run_state.order_id == source.current_order_id
		and is_equal_approx(run_state.cargo_integrity, 92.0)
		and is_equal_approx(run_state.fuel, 43.5)
		and run_state.active_checkpoint_id == &"checkpoint_atmosphere"
		and run_state.entry_style == FlightStyleTracker.STYLE_BALANCED
		and run_state.late_pull_up_detected
		and run_state.collision_count == 2
		and run_state.optional_trigger_ids == [&"relay_ruin", &"storm_01"]
		and run_state.result_tags == [&"cargo_recovered"],
		"Order-run resources, checkpoint, entry result, and tags must round-trip.",
		failures
	)
	source.free()
	restored.free()


func _test_missing_fields_and_legacy_migration(failures: Array[String]) -> void:
	var minimal_current: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": GameProgressData.CURRENT_SCHEMA_VERSION,
		"game_progress": {
			"credits": 12,
		},
	})
	expect_true(minimal_current.is_valid(), minimal_current.validation_error, failures)
	expect_true(
		minimal_current.credits == 12
		and minimal_current.ship_configuration
		== ShipLoadoutRules.create_default_configuration()
		and minimal_current.story_flags.is_empty()
		and minimal_current.travel_state == GameStateModel.TravelState.IDLE
		and is_equal_approx(
			minimal_current.order_run_state.fuel,
			OrderRunState.DEFAULT_RESOURCE_VALUE
		),
		"Missing current-schema fields must use explicit safe defaults.",
		failures
	)

	var legacy: GameProgressData = GameProgressData.from_dictionary({
		"credits": 31,
		"story_flags": ["legacy_story_flag"],
		"read_dialogue_ids": ["legacy_dialogue/line_01"],
		"station_upgrade_ids": ["legacy_station_upgrade"],
		"ship_configuration": {
			"utility": "module_asteroid_laser",
		},
	})
	expect_true(legacy.is_valid(), legacy.validation_error, failures)
	expect_true(legacy.was_migrated(), "Schema-less progress must be marked migrated.", failures)
	expect_true(
		legacy.credits == 31
		and legacy.story_flags.get(&"legacy_story_flag", false)
		and legacy.read_dialogue_ids.get(&"legacy_dialogue/line_01", false)
		and legacy.station_upgrade_ids.get(&"legacy_station_upgrade", false)
		and legacy.ship_configuration.get(ShipLoadoutRules.SLOT_UTILITY, &"")
		== ShipLoadoutRules.LASER_MODULE_ID
		and legacy.ship_configuration.get(ShipLoadoutRules.SLOT_POWER, &"")
		== ShipLoadoutRules.DEFAULT_POWER_MODULE_ID,
		"Legacy progress must migrate known fields while retaining safe slot defaults.",
		failures
	)


func _test_invalid_data_is_rejected(failures: Array[String]) -> void:
	var newer_schema: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": GameProgressData.CURRENT_SCHEMA_VERSION + 1,
		"game_progress": {},
	})
	expect_true(
		not newer_schema.is_valid() and newer_schema.validation_error.contains("newer"),
		"A newer unsupported schema must be rejected with a readable reason.",
		failures
	)

	var negative_credits: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": GameProgressData.CURRENT_SCHEMA_VERSION,
		"game_progress": {"credits": -1},
	})
	expect_true(
		not negative_credits.is_valid()
		and negative_credits.validation_error.contains("credits"),
		"Negative credits must be rejected.",
		failures
	)

	var incomplete_order: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": GameProgressData.CURRENT_SCHEMA_VERSION,
		"game_progress": {
			"current_order_id": "order_red_sand_m0",
			"destination_id": "",
			"cargo_id": "cargo_relay_core",
		},
	})
	expect_true(
		not incomplete_order.is_valid()
		and incomplete_order.validation_error.contains("destination"),
		"An incomplete active order must be rejected instead of partially applied.",
		failures
	)

	var impossible_resource: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": GameProgressData.CURRENT_SCHEMA_VERSION,
		"game_progress": {
			"order_run_state": {"fuel": 101.0},
		},
	})
	expect_true(
		not impossible_resource.is_valid()
		and impossible_resource.validation_error.contains("fuel"),
		"Out-of-range order resources must be rejected.",
		failures
	)

	var inconsistent_runtime: GameStateModel = GameStateModel.new()
	inconsistent_runtime.destination_id = &"planet_without_order"
	var invalid_capture: GameProgressData = GameProgressData.capture(inconsistent_runtime)
	expect_true(
		not invalid_capture.is_valid()
		and invalid_capture.validation_error.contains("active order"),
		"Save capture must reject inconsistent runtime state before writing.",
		failures
	)
	inconsistent_runtime.free()
