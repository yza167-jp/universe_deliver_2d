extends ProjectTestSuite


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_v2_round_trip(failures)
	_test_v2_missing_fields_use_safe_defaults(failures)
	_test_completed_v1_migration(failures)
	_test_incomplete_v1_migration(failures)
	_test_schema_zero_chains_through_v1(failures)
	_test_collections_and_dictionaries_are_validated(failures)
	_test_invalid_data_is_rejected(failures)
	_test_invalid_progress_does_not_pollute_runtime(failures)
	return failures


func _test_v2_round_trip(failures: Array[String]) -> void:
	var source: GameStateModel = GameStateModel.new()
	source.current_order_id = &"order_red_sand_m0"
	source.destination_id = &"planet_red_sand"
	source.cargo_id = &"cargo_relay_core"
	source.ship_configuration[ShipLoadoutRules.SLOT_UTILITY] = (
		ShipLoadoutRules.LASER_MODULE_ID
	)
	source.ship_configuration[ShipLoadoutRules.SLOT_SHIELD_BACKUP_POWER] = (
		ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
	)
	source.story_flags[&"story_first_delivery"] = true
	source.read_dialogue_ids[&"dialogue_test/line_02"] = true
	source.completed_order_ids[&"order_orientation"] = true
	source.credits = 97
	source.station_upgrade_ids[&"station_upgrade_archive_terminal"] = true
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
	source.main_story_chapter = &"chapter_m1_white_noise"
	source.unlocked_planet_ids = [
		&"planet_white_noise",
		&"planet_red_sand",
		&"planet_red_sand",
	]
	source.planet_relation_values[&"planet_red_sand"] = 2
	source.planet_relation_values[&"planet_white_noise"] = -1
	source.planet_permission_ids = [
		&"permission_white_noise_archive_access",
		&"permission_canopy_core_route",
	]
	source.codex_entry_ids = [&"codex_planet_red_sand", &"codex_character_iya"]
	source.souvenir_ids = [&"souvenir_old_relay_plaque"]
	source.completed_side_order_ids = [&"side_white_noise_returned_memory"]
	source.failed_side_order_ids = [&"side_canopy_spore_rush"]
	source.station_state_level = 2
	source.ship_upgrade_ids = [
		&"module_high_voltage_shielding",
		&"module_biosignal_isolation",
	]
	source.revisit_state[&"planet_red_sand"] = &"revisit_available"
	source.demo_ending_flags[&"ending_relay_signal_detected"] = true
	source.demo_ending_flags[&"ending_side_orders_completed"] = 1
	source.demo_ending_flags[&"ending_weather_ratio"] = 0.75
	source.demo_ending_flags[&"ending_archive_choice"] = &"archive_private"
	source.last_stable_station_state = &"station_state_archive_terminal"

	var captured: GameProgressData = GameProgressData.capture(source)
	var serialized: Dictionary[String, Variant] = captured.to_dictionary()
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(serialized)
	var restored: GameStateModel = GameStateModel.new()

	expect_true(captured.is_valid(), "Captured game progress must be valid.", failures)
	expect_true(
		int(serialized.get("schema_version", -1)) == GameProgressData.CURRENT_SCHEMA_VERSION,
		"Serialized progress must carry schema v2.",
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
		"M0 story, dialogue, and completed-order IDs must round-trip.",
		failures
	)
	expect_true(
		restored.credits == 97
		and restored.station_upgrade_ids == source.station_upgrade_ids,
		"M0 credits and station upgrades must round-trip.",
		failures
	)
	expect_true(
		restored.main_story_chapter == &"chapter_m1_white_noise"
		and restored.unlocked_planet_ids == [
			&"planet_red_sand",
			&"planet_white_noise",
		]
		and restored.planet_relation_values == source.planet_relation_values,
		"M1 chapter, unique planet unlocks, and relations must round-trip.",
		failures
	)
	expect_true(
		restored.planet_permission_ids == [
			&"permission_canopy_core_route",
			&"permission_white_noise_archive_access",
		]
		and restored.codex_entry_ids == [
			&"codex_character_iya",
			&"codex_planet_red_sand",
		]
		and restored.souvenir_ids == [&"souvenir_old_relay_plaque"],
		"Permissions, codex entries, and souvenirs must round-trip.",
		failures
	)
	expect_true(
		restored.completed_side_order_ids == [&"side_white_noise_returned_memory"]
		and restored.failed_side_order_ids == [&"side_canopy_spore_rush"]
		and restored.station_state_level == 2
		and restored.ship_upgrade_ids == [
			&"module_biosignal_isolation",
			&"module_high_voltage_shielding",
		],
		"Side-order history, station level, and ship upgrades must round-trip.",
		failures
	)
	expect_true(
		restored.revisit_state == source.revisit_state
		and restored.demo_ending_flags == source.demo_ending_flags
		and restored.last_stable_station_state
		== &"station_state_archive_terminal",
		"Revisit, ending, and stable-station state must round-trip.",
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


func _test_v2_missing_fields_use_safe_defaults(failures: Array[String]) -> void:
	var minimal_v2: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"credits": 12,
		},
	})
	expect_true(minimal_v2.is_valid(), minimal_v2.validation_error, failures)
	expect_true(
		minimal_v2.credits == 12
		and minimal_v2.ship_configuration
		== ShipLoadoutRules.create_default_configuration()
		and minimal_v2.main_story_chapter.is_empty()
		and minimal_v2.unlocked_planet_ids.is_empty()
		and minimal_v2.planet_relation_values.is_empty()
		and minimal_v2.planet_permission_ids.is_empty()
		and minimal_v2.codex_entry_ids.is_empty()
		and minimal_v2.souvenir_ids.is_empty()
		and minimal_v2.completed_side_order_ids.is_empty()
		and minimal_v2.failed_side_order_ids.is_empty()
		and minimal_v2.station_state_level == 0
		and minimal_v2.ship_upgrade_ids.is_empty()
		and minimal_v2.revisit_state.is_empty()
		and minimal_v2.demo_ending_flags.is_empty()
		and minimal_v2.last_stable_station_state.is_empty(),
		"Missing v2 fields must use explicit safe defaults.",
		failures
	)


func _test_completed_v1_migration(failures: Array[String]) -> void:
	var v1_source: Dictionary = _make_completed_v1_save()
	var migrated: GameProgressData = GameProgressData.from_dictionary(v1_source)
	expect_true(migrated.is_valid(), migrated.validation_error, failures)
	expect_true(
		migrated.was_migrated() and migrated.migrated_from_version == 1,
		"A v1 save must report a single in-memory migration to v2.",
		failures
	)
	expect_true(
		migrated.main_story_chapter
		== GameProgressData.RED_SAND_REVISIT_CHAPTER_ID
		and migrated.unlocked_planet_ids == [GameProgressData.RED_SAND_PLANET_ID],
		"A completed v1 first delivery must enter the Red Sand revisit chapter only.",
		failures
	)
	expect_true(
		migrated.completed_order_ids.get(
			GameProgressData.LEGACY_RED_SAND_ORDER_ID,
			false
		)
		and migrated.completed_order_ids.get(
			GameProgressData.CANONICAL_RED_SAND_ORDER_ID,
			false
		)
		and migrated.credits == 137,
		"Migration must retain the M0 completion and add its canonical alias without changing credits.",
		failures
	)
	expect_true(
		migrated.ship_configuration.get(ShipLoadoutRules.SLOT_UTILITY, &"")
		== ShipLoadoutRules.LASER_MODULE_ID
		and migrated.ship_configuration.get(
			ShipLoadoutRules.SLOT_SHIELD_BACKUP_POWER,
			&""
		) == ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		and migrated.story_flags.get(
			M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED,
			false
		)
		and migrated.read_dialogue_ids.get(&"legacy_return/line_01", false),
		"Migration must preserve M0 modules, story flags, and dialogue history.",
		failures
	)
	expect_true(
		migrated.souvenir_ids == [GameProgressData.RELAY_PLAQUE_SOUVENIR_ID]
		and migrated.codex_entry_ids.has(GameProgressData.RED_SAND_CODEX_ENTRY_ID)
		and migrated.codex_entry_ids.has(GameProgressData.IYA_CODEX_ENTRY_ID)
		and migrated.codex_entry_ids.has(
			GameProgressData.RELAY_PLAQUE_CODEX_ENTRY_ID
		)
		and migrated.station_state_level == 1
		and migrated.last_stable_station_state
		== GameProgressData.FIRST_DELIVERY_STATION_STATE_ID,
		"Completed M0 state must backfill its existing planet, Iya, plaque, and station records.",
		failures
	)
	expect_true(
		not migrated.unlocked_planet_ids.has(&"planet_white_noise")
		and not migrated.ship_upgrade_ids.has(&"module_high_voltage_shielding")
		and migrated.planet_relation_values.is_empty()
		and migrated.planet_permission_ids.is_empty()
		and migrated.demo_ending_flags.is_empty(),
		"Migration must not unlock White Noise or grant M1 rewards.",
		failures
	)

	var loaded_again: GameProgressData = GameProgressData.from_dictionary(
		migrated.to_dictionary()
	)
	expect_true(loaded_again.is_valid(), loaded_again.validation_error, failures)
	expect_true(
		not loaded_again.was_migrated()
		and loaded_again.credits == 137
		and loaded_again.unlocked_planet_ids.count(
			GameProgressData.RED_SAND_PLANET_ID
		) == 1
		and loaded_again.souvenir_ids.count(
			GameProgressData.RELAY_PLAQUE_SOUVENIR_ID
		) == 1,
		"Reloading v2 must not migrate or award completion records again.",
		failures
	)


func _test_incomplete_v1_migration(failures: Array[String]) -> void:
	var v1_source: Dictionary = {
		"schema_version": 1,
		"settings_reference": "local_settings",
		"game_progress": {
			"current_order_id": "order_red_sand_m0",
			"destination_id": "planet_red_sand",
			"cargo_id": "cargo_red_sand_m0",
			"credits": 31,
			"story_flags": ["story_tutorial_completed"],
			"read_dialogue_ids": ["tutorial/line_01"],
			"ship_configuration": {
				"utility": "module_asteroid_laser",
			},
			"order_run_state": {
				"order_id": "order_red_sand_m0",
				"fuel": 73.0,
			},
		},
	}
	var migrated: GameProgressData = GameProgressData.from_dictionary(v1_source)
	expect_true(migrated.is_valid(), migrated.validation_error, failures)
	expect_true(
		migrated.was_migrated()
		and migrated.current_order_id == &"order_red_sand_m0"
		and migrated.credits == 31
		and migrated.story_flags.get(&"story_tutorial_completed", false)
		and migrated.read_dialogue_ids.get(&"tutorial/line_01", false)
		and is_equal_approx(migrated.order_run_state.fuel, 73.0),
		"An unfinished v1 save must retain its reliable M0 state.",
		failures
	)
	expect_true(
		migrated.main_story_chapter.is_empty()
		and migrated.unlocked_planet_ids.is_empty()
		and migrated.codex_entry_ids.is_empty()
		and migrated.souvenir_ids.is_empty()
		and migrated.ship_upgrade_ids.is_empty()
		and migrated.station_state_level == 0
		and migrated.last_stable_station_state.is_empty(),
		"An unfinished v1 save must not invent a chapter or grant M1 progress.",
		failures
	)


func _test_schema_zero_chains_through_v1(failures: Array[String]) -> void:
	var schema_zero: Dictionary = (
		_make_completed_v1_save().get("game_progress") as Dictionary
	).duplicate(true)
	schema_zero["settings_reference"] = "local_settings"
	var migrated: GameProgressData = GameProgressData.from_dictionary(schema_zero)
	expect_true(migrated.is_valid(), migrated.validation_error, failures)
	expect_true(
		migrated.migrated_from_version == 0
		and migrated.schema_version == 2
		and migrated.main_story_chapter
		== GameProgressData.RED_SAND_REVISIT_CHAPTER_ID
		and migrated.completed_order_ids.get(
			GameProgressData.CANONICAL_RED_SAND_ORDER_ID,
			false
		),
		"Schema 0 must pass through v1 validation before receiving v2 migration state.",
		failures
	)


func _test_collections_and_dictionaries_are_validated(
	failures: Array[String]
) -> void:
	var deduplicated: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"unlocked_planet_ids": [
				"planet_red_sand",
				"planet_red_sand",
			],
			"codex_entry_ids": [
				"codex_planet_red_sand",
				"codex_planet_red_sand",
			],
		},
	})
	expect_true(
		deduplicated.is_valid()
		and deduplicated.unlocked_planet_ids == [&"planet_red_sand"]
		and deduplicated.codex_entry_ids == [&"codex_planet_red_sand"],
		"Repeated loads must normalize collection IDs without duplicates.",
		failures
	)

	var invalid_relation: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"planet_relation_values": {"planet_red_sand": "2"},
		},
	})
	expect_true(
		not invalid_relation.is_valid()
		and invalid_relation.validation_error.contains("planet_relation_values"),
		"Relation dictionary values must be integers.",
		failures
	)

	var out_of_range_relation: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"planet_relation_values": {"planet_red_sand": 4},
		},
	})
	expect_true(
		not out_of_range_relation.is_valid()
		and out_of_range_relation.validation_error.contains(
			"planet_relation_values"
		),
		"Persisted relations must stay inside the M1 bounded range.",
		failures
	)

	var invalid_chapter: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"main_story_chapter": "chapter_unknown",
		},
	})
	var invalid_planet: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"unlocked_planet_ids": ["planet_unknown"],
		},
	})
	var invalid_permission: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"planet_permission_ids": ["permission_unknown"],
		},
	})
	expect_true(
		not invalid_chapter.is_valid()
		and invalid_chapter.validation_error.contains("main_story_chapter")
		and not invalid_planet.is_valid()
		and invalid_planet.validation_error.contains("planet")
		and not invalid_permission.is_valid()
		and invalid_permission.validation_error.contains("permission"),
		"Schema v2 must reject unknown chapter, planet, and permission IDs.",
		failures
	)

	var invalid_revisit: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"revisit_state": {"planet_red_sand": 1},
		},
	})
	expect_true(
		not invalid_revisit.is_valid()
		and invalid_revisit.validation_error.contains("revisit_state"),
		"Revisit dictionary values must be stable IDs.",
		failures
	)

	var invalid_ending: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"demo_ending_flags": {"ending_archive_choice": ["not", "scalar"]},
		},
	})
	expect_true(
		not invalid_ending.is_valid()
		and invalid_ending.validation_error.contains("demo_ending_flags"),
		"Demo ending values must be supported JSON scalar data.",
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
		"schema_version": 2,
		"game_progress": {"credits": -1},
	})
	expect_true(
		not negative_credits.is_valid()
		and negative_credits.validation_error.contains("credits"),
		"Negative credits must be rejected.",
		failures
	)

	var incomplete_order: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
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
		"schema_version": 2,
		"game_progress": {
			"order_run_state": {"fuel": -1.0},
		},
	})
	expect_true(
		not impossible_resource.is_valid()
		and impossible_resource.validation_error.contains("fuel"),
		"Negative order resources must be rejected.",
		failures
	)

	var inconsistent_side_order: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"completed_side_order_ids": ["side_test"],
			"failed_side_order_ids": ["side_test"],
		},
	})
	expect_true(
		not inconsistent_side_order.is_valid()
		and inconsistent_side_order.validation_error.contains("both completed and failed"),
		"Inconsistent side-order terminal states must be rejected.",
		failures
	)

	var negative_station_level: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {"station_state_level": -1},
	})
	expect_true(
		not negative_station_level.is_valid()
		and negative_station_level.validation_error.contains("station_state_level"),
		"Negative station state levels must be rejected.",
		failures
	)

	var node_path_runtime: GameStateModel = GameStateModel.new()
	node_path_runtime.demo_ending_flags[&"invalid_runtime_reference"] = NodePath(
		"/root/Scene"
	)
	var invalid_node_path_capture: GameProgressData = GameProgressData.capture(
		node_path_runtime
	)
	expect_true(
		not invalid_node_path_capture.is_valid()
		and invalid_node_path_capture.validation_error.contains("demo_ending_flags"),
		"NodePath values must never enter the story save.",
		failures
	)
	node_path_runtime.free()

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


func _test_invalid_progress_does_not_pollute_runtime(
	failures: Array[String]
) -> void:
	var runtime: GameStateModel = GameStateModel.new()
	runtime.credits = 88
	runtime.story_flags[&"runtime_sentinel"] = true
	runtime.main_story_chapter = &"chapter_runtime_sentinel"
	var invalid: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"credits": -5,
		},
	})
	expect_true(not invalid.apply_to(runtime), "Invalid progress must not apply.", failures)
	expect_true(
		runtime.credits == 88
		and runtime.story_flags.get(&"runtime_sentinel", false)
		and runtime.main_story_chapter == &"chapter_runtime_sentinel",
		"Failed validation must not partially reset or mutate GameState.",
		failures
	)
	runtime.free()


func _make_completed_v1_save() -> Dictionary:
	return {
		"schema_version": 1,
		"last_saved_at_unix": 123,
		"build_version": "m0",
		"settings_reference": "local_settings",
		"game_progress": {
			"ship_configuration": {
				"utility": "module_asteroid_laser",
				"shield_backup_power": "module_shield_backup_power",
			},
			"story_flags": [
				"story_red_sand_arrival_main_dialogue_completed",
				String(M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED),
				String(M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED),
			],
			"read_dialogue_ids": ["legacy_return/line_01"],
			"completed_order_ids": ["order_red_sand_m0"],
			"credits": 137,
			"station_upgrade_ids": [
				String(M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY),
			],
			"order_run_state": {
				"order_id": "order_red_sand_m0",
				"cargo_integrity": 91.0,
				"hull": 82.0,
				"shield": 64.0,
				"fuel": 42.0,
			},
		},
	}
