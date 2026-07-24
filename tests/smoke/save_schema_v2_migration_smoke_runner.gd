extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const TEST_SAVE_PATH: String = "user://t101_migration_smoke.json"
const TEST_TEMP_PATH: String = "user://t101_migration_smoke.tmp"
const TEST_BACKUP_PATH: String = "user://t101_migration_smoke.backup.json"
const TEST_REJECTED_PATH: String = "user://t101_migration_smoke.invalid.json"

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _save_service: SaveServiceModel
var _app: UniverseDeliverApp


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_check(_game_state != null, "GameState autoload is unavailable.")
	_check(_scene_router != null, "SceneRouter autoload is unavailable.")
	_check(_save_service != null, "SaveService autoload is unavailable.")
	if _game_state == null or _scene_router == null or _save_service == null:
		await _cleanup()
		_finish()
		return

	_save_service.set_automatic_saves_enabled(false)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	await _run_completed_v1_continue()
	await _run_incomplete_v1_continue()
	await _cleanup()
	_finish()


func _run_completed_v1_continue() -> void:
	_remove_test_files()
	_game_state.reset_runtime_state()
	var v1_text: String = JSON.stringify(_make_completed_v1_save(), "\t", true)
	_write_text(TEST_SAVE_PATH, v1_text)
	var main_menu: MainMenu = await _start_app_and_get_main_menu()
	if main_menu == null:
		return
	_check(main_menu.is_continue_button_enabled(), "Completed v1 did not enable Continue.")
	_check(
		main_menu.get_status_text().contains("旧版存档"),
		"Completed v1 did not expose the localized migration notice."
	)
	_check(
		_read_text(TEST_SAVE_PATH) == v1_text,
		"Opening the menu rewrote v1 before a stable save."
	)

	_save_service.set_automatic_saves_enabled(true)
	_check(main_menu.continue_game(), "Completed v1 Continue failed.")
	await _wait_frames(5)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION,
		"Completed v1 did not continue to the stable station."
	)
	_check(
		_game_state.credits == 137
		and _game_state.has_completed_order(
			GameProgressData.LEGACY_RED_SAND_ORDER_ID
		)
		and _game_state.has_completed_order(
			GameProgressData.CANONICAL_RED_SAND_ORDER_ID
		)
		and _game_state.main_story_chapter
		== GameProgressData.RED_SAND_REVISIT_CHAPTER_ID
		and _game_state.souvenir_ids
		== [GameProgressData.RELAY_PLAQUE_SOUVENIR_ID],
		"Completed v1 did not restore its M0 result and M1 revisit bridge."
	)
	_check(
		not _game_state.unlocked_planet_ids.has(&"planet_white_noise")
		and not _game_state.ship_upgrade_ids.has(&"module_high_voltage_shielding")
		and _game_state.planet_relation_values.is_empty()
		and _game_state.planet_permission_ids.is_empty(),
		"Completed v1 incorrectly received White Noise access or M1 rewards."
	)
	var station: StationHub = _get_active_station()
	_check(station != null, "Completed v1 did not instantiate StationHub.")
	if station != null:
		var return_state: StationReturnStateController = station.get_return_state_controller()
		_check(
			return_state != null and return_state.is_first_delivery_display_visible(),
			"Completed v1 lost the old relay plaque station display."
		)
	var committed_root: Dictionary = _read_json_object(TEST_SAVE_PATH)
	_check(
		int(committed_root.get("schema_version", -1)) == 2,
		"Stable station entry did not commit schema v2."
	)
	_check(
		_read_text(TEST_BACKUP_PATH) == v1_text,
		"Stable v2 save did not retain the original valid v1 backup."
	)

	await _release_app()
	_game_state.reset_runtime_state()
	main_menu = await _start_app_and_get_main_menu()
	if main_menu == null:
		return
	_save_service.set_automatic_saves_enabled(true)
	_check(main_menu.continue_game(), "Repeated v2 Continue failed.")
	await _wait_frames(5)
	_check(
		_game_state.credits == 137
		and _game_state.unlocked_planet_ids.count(
			GameProgressData.RED_SAND_PLANET_ID
		) == 1
		and _game_state.souvenir_ids.count(
			GameProgressData.RELAY_PLAQUE_SOUVENIR_ID
		) == 1,
		"Repeated Continue duplicated migrated progress or rewards."
	)
	await _release_app()


func _run_incomplete_v1_continue() -> void:
	_save_service.set_automatic_saves_enabled(false)
	_remove_test_files()
	_game_state.reset_runtime_state()
	var v1_text: String = JSON.stringify(_make_incomplete_v1_save(), "\t", true)
	_write_text(TEST_SAVE_PATH, v1_text)
	var main_menu: MainMenu = await _start_app_and_get_main_menu()
	if main_menu == null:
		return
	_check(main_menu.is_continue_button_enabled(), "Incomplete v1 did not enable Continue.")
	_save_service.set_automatic_saves_enabled(true)
	_check(main_menu.continue_game(), "Incomplete v1 Continue failed.")
	await _wait_frames(5)
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION
		and _game_state.credits == 33
		and _game_state.has_story_flag(&"unfinished_v1")
		and _game_state.main_story_chapter.is_empty()
		and _game_state.unlocked_planet_ids.is_empty()
		and _game_state.codex_entry_ids.is_empty()
		and _game_state.souvenir_ids.is_empty()
		and _game_state.ship_upgrade_ids.is_empty()
		and _game_state.station_state_level == 0,
		"Incomplete v1 did not preserve M0 progress with empty M1 defaults."
	)
	_check(
		int(_read_json_object(TEST_SAVE_PATH).get("schema_version", -1)) == 2
		and _read_text(TEST_BACKUP_PATH) == v1_text,
		"Incomplete v1 did not use the same safe v2 commit and backup path."
	)
	await _release_app()


func _start_app_and_get_main_menu() -> MainMenu:
	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(app_scene != null, "App scene could not be loaded.")
	if app_scene == null:
		return null
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene did not instantiate.")
	if _app == null:
		return null
	root.add_child(_app)
	await _wait_frames(3)
	var scene_container: Control = _app.get_node_or_null("SceneContainer") as Control
	if scene_container == null or scene_container.get_child_count() != 1:
		_check(false, "App did not start with exactly one stage scene.")
		return null
	var main_menu: MainMenu = scene_container.get_child(0) as MainMenu
	_check(main_menu != null, "App did not start at MainMenu.")
	return main_menu


func _get_active_station() -> StationHub:
	if _app == null:
		return null
	var scene_container: Control = _app.get_node_or_null("SceneContainer") as Control
	if scene_container == null or scene_container.get_child_count() != 1:
		return null
	return scene_container.get_child(0) as StationHub


func _make_completed_v1_save() -> Dictionary:
	return {
		"schema_version": 1,
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
		},
	}


func _make_incomplete_v1_save() -> Dictionary:
	return {
		"schema_version": 1,
		"settings_reference": "local_settings",
		"game_progress": {
			"credits": 33,
			"story_flags": ["unfinished_v1"],
			"read_dialogue_ids": ["tutorial/line_01"],
			"ship_configuration": {
				"utility": "module_asteroid_laser",
			},
		},
	}


func _read_json_object(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not write smoke fixture: %s" % path)
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
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _release_app() -> void:
	if _app == null or not is_instance_valid(_app):
		_app = null
		return
	_app.queue_free()
	await _wait_frames(2)
	_app = null


func _wait_frames(frame_count: int) -> void:
	for _index: int in range(frame_count):
		await process_frame


func _cleanup() -> void:
	if _save_service != null:
		_save_service.set_automatic_saves_enabled(false)
	await _release_app()
	if _game_state != null:
		_game_state.reset_runtime_state()
	_remove_test_files()
	if _save_service != null:
		_save_service.reset_storage_paths()
	TranslationServer.set_locale(_original_locale)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[save-v2-migration] PASS: completed and unfinished v1 Continue, "
			+ "stable v2 commit, original backup, and idempotent reload."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[save-v2-migration] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
