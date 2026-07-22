extends ProjectTestSuite

const TEST_SAVE_PATH: String = "user://t052_save_service.json"
const TEST_TEMP_PATH: String = "user://t052_save_service.tmp"
const TEST_BACKUP_PATH: String = "user://t052_save_service.backup.json"
const TEST_REJECTED_PATH: String = "user://t052_save_service.invalid.json"
const SETTINGS_SENTINEL_PATH: String = "user://t052_settings_sentinel.cfg"


func run() -> Array[String]:
	var failures: Array[String] = []
	_remove_test_files()
	_test_safe_write_and_backup_recovery(failures)
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
		game_state.credits == 45 and game_state.has_story_flag(&"legacy_loaded"),
		"Legacy progress must load through the migration path.",
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
