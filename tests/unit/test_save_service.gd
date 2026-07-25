extends ProjectTestSuite

const TEST_SAVE_PATH: String = "user://t052_save_service.json"
const TEST_TEMP_PATH: String = "user://t052_save_service.tmp"
const TEST_BACKUP_PATH: String = "user://t052_save_service.backup.json"
const TEST_REJECTED_PATH: String = "user://t052_save_service.invalid.json"
const SETTINGS_SENTINEL_PATH: String = "user://t052_settings_sentinel.cfg"

var _persistent_change_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	_remove_test_files()
	_test_safe_write_and_backup_recovery(failures)
	_remove_test_files()
	_test_m1_runtime_round_trip_without_reward_replay(failures)
	_remove_test_files()
	_test_v1_migration_waits_for_safe_save(failures)
	_remove_test_files()
	_test_invalid_v1_uses_valid_backup_without_pollution(failures)
	_remove_test_files()
	_test_invalid_files_are_preserved(failures)
	_remove_test_files()
	_test_legacy_availability_and_new_game_settings_boundary(failures)
	_test_automatic_save_gating(failures)
	_remove_test_files()
	return failures


func _test_safe_write_and_backup_recovery(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	game_state.credits = 12
	game_state.story_flags[&"save_one"] = true
	expect_true(service.save_progress(), service.last_error, failures)
	expect_true(FileAccess.file_exists(TEST_SAVE_PATH), "Primary save must be written.", failures)
	expect_true(
		not FileAccess.file_exists(TEST_TEMP_PATH),
		"Validated temporary save must be moved out of the temporary path.",
		failures
	)

	game_state.credits = 24
	game_state.story_flags[&"save_two"] = true
	expect_true(service.save_progress(), service.last_error, failures)
	expect_true(
		FileAccess.file_exists(TEST_BACKUP_PATH),
		"Replacing a valid primary must create a validated backup.",
		failures
	)
	var backup_progress: GameProgressData = _read_progress(TEST_BACKUP_PATH)
	expect_true(
		backup_progress != null
		and backup_progress.credits == 12
		and backup_progress.story_flags.get(&"save_one", false)
		and not backup_progress.story_flags.get(&"save_two", false),
		"Backup must retain the previous valid progress, not the new primary.",
		failures
	)

	_write_text(TEST_SAVE_PATH, "{not valid json")
	game_state.reset_runtime_state()
	game_state.credits = 999
	expect_true(
		service.refresh_save_availability() == SaveServiceModel.SaveAvailability.BACKUP,
		"A corrupt primary with a valid backup must expose Continue via backup.",
		failures
	)
	expect_true(
		service.last_warning_code == SaveServiceModel.WARNING_BACKUP_RECOVERY,
		"Backup availability must expose a recovery warning.",
		failures
	)
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		service.last_load_source == SaveServiceModel.LoadSource.BACKUP
		and game_state.credits == 12
		and game_state.has_story_flag(&"save_one"),
		"Loading must restore the last valid backup without applying corrupt primary data.",
		failures
	)
	expect_true(
		_read_text(TEST_SAVE_PATH) == "{not valid json",
		"Backup recovery must not silently overwrite the rejected primary.",
		failures
	)
	service.free()
	game_state.free()


func _test_m1_runtime_round_trip_without_reward_replay(
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	game_state.ship_upgrade_ids = [
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING,
	]
	game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	game_state.completed_order_ids[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = true
	game_state.order_states[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = GameStateModel.OrderStatus.COMPLETED
	game_state.reward_applied_order_ids.append(
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	)
	expect_true(
		game_state.advance_main_story_chapter(
			M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		).changed
		and game_state.unlock_planet(
			M1ProgressRules.PLANET_WHITE_NOISE
		).changed
		and game_state.change_planet_relation(
			M1ProgressRules.PLANET_WHITE_NOISE,
			2,
			&"save_service_archive_choice"
		).changed
		and game_state.grant_permission(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		).changed
		and game_state.unlock_codex_entry(
			&"codex_planet_white_noise"
		).changed
		and game_state.add_souvenir(
			&"souvenir_white_noise_memory_fragment"
		).changed
		and game_state.set_revisit_state(
			M1ProgressRules.PLANET_RED_SAND,
			&"revisit_red_sand_completed"
		).changed,
		"M1 runtime APIs must establish a complete save fixture.",
		failures
	)
	expect_true(service.save_progress(), service.last_error, failures)

	game_state.reset_runtime_state()
	_persistent_change_count = 0
	game_state.persistent_state_changed.connect(_on_persistent_state_changed)
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		game_state.get_main_story_chapter()
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and game_state.is_planet_unlocked(M1ProgressRules.PLANET_WHITE_NOISE)
		and game_state.get_planet_relation(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == 2
		and game_state.has_permission(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		)
		and game_state.has_codex_entry(&"codex_planet_white_noise")
		and game_state.has_souvenir(
			&"souvenir_white_noise_memory_fragment"
		)
		and game_state.get_revisit_state(
			M1ProgressRules.PLANET_RED_SAND
		) == &"revisit_red_sand_completed"
		and _persistent_change_count == 0,
		"SaveService must restore all M1 fields without replaying progress events.",
		failures
	)

	var repeated_relation: ProgressChangeResult = game_state.change_planet_relation(
		M1ProgressRules.PLANET_WHITE_NOISE,
		2,
		&"save_service_archive_choice"
	)
	var repeated_permission: ProgressChangeResult = game_state.grant_permission(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	var repeated_codex: ProgressChangeResult = game_state.unlock_codex_entry(
		&"codex_planet_white_noise"
	)
	var repeated_souvenir: ProgressChangeResult = game_state.add_souvenir(
		&"souvenir_white_noise_memory_fragment"
	)
	var repeated_revisit: ProgressChangeResult = game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		&"revisit_red_sand_completed"
	)
	expect_true(
		not repeated_relation.changed
		and not repeated_permission.changed
		and not repeated_codex.changed
		and not repeated_souvenir.changed
		and not repeated_revisit.changed
		and _persistent_change_count == 0,
		"Reloaded rewards and collection events must remain idempotent.",
		failures
	)
	service.free()
	game_state.free()


func _test_v1_migration_waits_for_safe_save(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	var v1_text: String = JSON.stringify(_make_completed_v1_save(), "\t", true)
	_write_text(TEST_SAVE_PATH, v1_text)
	_write_text(SETTINGS_SENTINEL_PATH, "settings-remain-independent")

	expect_true(
		service.refresh_save_availability() == SaveServiceModel.SaveAvailability.PRIMARY
		and service.last_warning_code == SaveServiceModel.WARNING_SCHEMA_MIGRATED,
		"A valid v1 primary must offer Continue with a migration notice.",
		failures
	)
	expect_true(
		_read_text(TEST_SAVE_PATH) == v1_text,
		"Inspecting v1 availability must not rewrite the source file.",
		failures
	)
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		game_state.credits == 137
		and game_state.completed_order_ids.get(
			GameProgressData.LEGACY_RED_SAND_ORDER_ID,
			false
		)
		and game_state.completed_order_ids.get(
			GameProgressData.CANONICAL_RED_SAND_ORDER_ID,
			false
		)
		and game_state.story_flags.get(
			GameProgressData.RED_SAND_ORDER_COMPLETION_FLAG,
			false
		)
		and game_state.main_story_chapter
		== GameProgressData.RED_SAND_REVISIT_CHAPTER_ID
		and game_state.souvenir_ids
		== [GameProgressData.RELAY_PLAQUE_SOUVENIR_ID],
		"Loading v1 must apply a fully validated v2 state in memory.",
		failures
	)
	expect_true(
		_read_text(TEST_SAVE_PATH) == v1_text
		and _read_text(SETTINGS_SENTINEL_PATH) == "settings-remain-independent",
		"Loading v1 must preserve the original bytes and independent settings.",
		failures
	)

	expect_true(service.save_progress(), service.last_error, failures)
	var primary_progress: GameProgressData = _read_progress(TEST_SAVE_PATH)
	expect_true(
		primary_progress != null
		and not primary_progress.was_migrated()
		and primary_progress.schema_version == 2,
		"The next explicit stable save must commit a validated v2 primary.",
		failures
	)
	expect_true(
		_read_text(TEST_BACKUP_PATH) == v1_text,
		"Committing v2 must rotate the original valid v1 bytes into backup.",
		failures
	)
	expect_true(
		_read_text(SETTINGS_SENTINEL_PATH) == "settings-remain-independent",
		"Story migration and safe save must not overwrite local settings.",
		failures
	)

	game_state.reset_runtime_state()
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		game_state.credits == 137
		and game_state.unlocked_planet_ids.count(
			GameProgressData.RED_SAND_PLANET_ID
		) == 1
		and game_state.souvenir_ids.count(
			GameProgressData.RELAY_PLAQUE_SOUVENIR_ID
		) == 1
		and game_state.story_flags.get(
			GameProgressData.RED_SAND_ORDER_COMPLETION_FLAG,
			false
		)
		and not game_state.unlocked_planet_ids.has(&"planet_white_noise")
		and not game_state.ship_upgrade_ids.has(&"module_high_voltage_shielding"),
		"Reloading committed v2 must not duplicate rewards or unlock White Noise.",
		failures
	)
	service.free()
	game_state.free()


func _test_invalid_v1_uses_valid_backup_without_pollution(
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	var invalid_v1_text: String = JSON.stringify({
		"schema_version": 1,
		"game_progress": {"credits": -1},
	})
	var backup_v1: Dictionary = _make_incomplete_v1_save()
	_write_text(TEST_SAVE_PATH, invalid_v1_text)
	_write_text(TEST_BACKUP_PATH, JSON.stringify(backup_v1))
	game_state.credits = 77
	game_state.story_flags[&"runtime_sentinel"] = true

	expect_true(
		service.refresh_save_availability() == SaveServiceModel.SaveAvailability.BACKUP,
		"An invalid v1 primary with a valid v1 backup must recover from backup.",
		failures
	)
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		service.last_load_source == SaveServiceModel.LoadSource.BACKUP
		and game_state.credits == 33
		and game_state.story_flags.get(&"unfinished_v1", false)
		and not game_state.story_flags.get(&"runtime_sentinel", false)
		and game_state.main_story_chapter.is_empty()
		and game_state.unlocked_planet_ids.is_empty(),
		"Backup recovery must apply only the fully validated backup state.",
		failures
	)
	expect_true(
		_read_text(TEST_SAVE_PATH) == invalid_v1_text,
		"Migration failure must preserve the invalid primary for diagnosis.",
		failures
	)
	service.free()
	game_state.free()


func _test_invalid_files_are_preserved(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	_write_text(TEST_SAVE_PATH, "{broken primary")
	_write_text(TEST_BACKUP_PATH, "[]")
	game_state.credits = 77
	expect_true(
		service.refresh_save_availability() == SaveServiceModel.SaveAvailability.INVALID,
		"Two unreadable files must disable Continue rather than fabricate progress.",
		failures
	)
	expect_true(not service.load_progress(), "Unreadable saves must not load.", failures)
	expect_true(
		game_state.credits == 77,
		"A failed load must leave the current runtime state untouched.",
		failures
	)
	expect_true(
		_read_text(TEST_SAVE_PATH) == "{broken primary"
		and _read_text(TEST_BACKUP_PATH) == "[]",
		"Unreadable primary and backup files must remain available for diagnosis.",
		failures
	)
	service.free()
	game_state.free()


func _test_legacy_availability_and_new_game_settings_boundary(
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var service: SaveServiceModel = _create_service(game_state)
	_write_text(
		TEST_SAVE_PATH,
		JSON.stringify({
			"credits": 45,
			"story_flags": ["legacy_loaded"],
		})
	)
	expect_true(
		service.refresh_save_availability() == SaveServiceModel.SaveAvailability.PRIMARY
		and service.last_warning_code == SaveServiceModel.WARNING_SCHEMA_MIGRATED,
		"A readable schema-less save must offer Continue with a migration notice.",
		failures
	)
	expect_true(service.load_progress(), service.last_error, failures)
	expect_true(
		game_state.credits == 45
		and game_state.has_story_flag(&"legacy_loaded")
		and game_state.main_story_chapter.is_empty()
		and game_state.unlocked_planet_ids.is_empty(),
		"Schema-less unfinished progress must chain to v2 without M1 rewards.",
		failures
	)

	_write_text(SETTINGS_SENTINEL_PATH, "settings-remain-independent")
	game_state.credits = 999
	game_state.story_flags[&"new_game_must_clear"] = true
	expect_true(service.start_new_game(), service.last_error, failures)
	expect_true(
		game_state.credits == 0
		and not game_state.has_story_flag(&"new_game_must_clear")
		and _read_text(SETTINGS_SENTINEL_PATH) == "settings-remain-independent",
		"New Game must reset progress without touching the separate settings store.",
		failures
	)
	var new_game_progress: GameProgressData = _read_progress(TEST_SAVE_PATH)
	expect_true(
		new_game_progress != null
		and new_game_progress.settings_reference
		== GameProgressData.DEFAULT_SETTINGS_REFERENCE,
		"A new save must retain the stable local-settings reference.",
		failures
	)
	service.free()
	game_state.free()


func _test_automatic_save_gating(failures: Array[String]) -> void:
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(["--headless"]),
			PackedStringArray()
		),
		"Headless validation must not write the player's normal save.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(["--script", "res://tests/test_runner.gd"]),
			PackedStringArray()
		),
		"Script tests must not write the player's normal save.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray(["--red-sand-route"])
		),
		"Direct debug routes must not overwrite campaign progress.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray(["--delivery-lab"])
		),
		"Delivery Lab must not overwrite campaign progress.",
		failures
	)
	expect_true(
		SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray()
		),
		"Normal player startup must enable automatic saves.",
		failures
	)


func _create_service(game_state: GameStateModel) -> SaveServiceModel:
	var service: SaveServiceModel = SaveServiceModel.new()
	service.game_state_override = game_state
	service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	return service


func _read_progress(path: String) -> GameProgressData:
	var raw_text: String = _read_text(path)
	if raw_text.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		return null
	var progress: GameProgressData = GameProgressData.from_dictionary(parsed as Dictionary)
	return progress if progress.is_valid() else null


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
			},
		},
	}


func _make_incomplete_v1_save() -> Dictionary:
	return {
		"schema_version": 1,
		"settings_reference": "local_settings",
		"game_progress": {
			"credits": 33,
			"story_flags": ["unfinished_v1"],
			"ship_configuration": {
				"utility": "module_asteroid_laser",
			},
		},
	}


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _remove_test_files() -> void:
	for path: String in [
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH,
		SETTINGS_SENTINEL_PATH,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_persistent_state_changed() -> void:
	_persistent_change_count += 1
