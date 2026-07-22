extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const RED_SAND_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const ASTEROID_LASER_PATH: String = "res://data/modules/asteroid_laser.tres"
const TEST_SAVE_PATH: String = "user://t052_continue_smoke.json"
const TEST_TEMP_PATH: String = "user://t052_continue_smoke.tmp"
const TEST_BACKUP_PATH: String = "user://t052_continue_smoke.backup.json"
const TEST_REJECTED_PATH: String = "user://t052_continue_smoke.invalid.json"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

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
		_finish_smoke()
		return

	_save_service.set_automatic_saves_enabled(false)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	_remove_test_files()
	_game_state.reset_runtime_state()

	_write_text(TEST_SAVE_PATH, "{unreadable save")
	var main_menu: MainMenu = await _start_app_and_get_main_menu()
	if main_menu == null:
		await _cleanup()
		_finish_smoke()
		return
	_check(not main_menu.is_continue_button_enabled(), "Invalid save enabled Continue.")
	_check(main_menu.is_start_button_focused(), "Invalid save did not leave New Game usable.")
	_check(
		main_menu.get_status_text().contains("原文件已保留"),
		"Invalid-save guidance does not explain that the source file was preserved."
	)
	_check(
		_read_text(TEST_SAVE_PATH) == "{unreadable save",
		"Inspecting an invalid save modified its original bytes."
	)
	await _release_app()
	_remove_test_files()

	main_menu = await _start_app_and_get_main_menu()
	if main_menu == null:
		await _cleanup()
		_finish_smoke()
		return
	_check(
		VIEWPORT_RECT.encloses(main_menu.get_panel_rect()),
		"Main menu panel leaves the 640x360 viewport: %s" % main_menu.get_panel_rect()
	)
	_check(main_menu.get_continue_button_text() == "继续游戏", "Continue is not localized.")
	_check(not main_menu.is_continue_button_enabled(), "Continue was enabled without a save.")
	_check(main_menu.get_status_text().contains("尚无"), "No-save guidance is unclear.")
	_check(main_menu.is_start_button_focused(), "New Game lacks focus when no save exists.")
	_check(
		not main_menu.get_start_button_rect().intersects(main_menu.get_continue_button_rect()),
		"New Game and Continue overlap."
	)

	_check(_seed_completed_red_sand_order(), "Could not seed the completed Red Sand result.")
	_save_service.set_automatic_saves_enabled(true)
	_check(
		_scene_router.debug_switch_to_stage(SceneRouterService.Stage.RESULTS),
		"Could not enter Results for the automatic-save smoke."
	)
	await process_frame
	await process_frame
	await process_frame
	_check(
		_game_state.get_credits() == 97
		and _game_state.has_completed_order(&"order_red_sand_m0")
		and _game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		),
		"Results did not commit the expected post-delivery progress."
	)
	_check(
		FileAccess.file_exists(TEST_SAVE_PATH),
		"Entering the stable Results stage did not automatically save progress."
	)
	var autosaved: GameProgressData = _read_progress(TEST_SAVE_PATH)
	_check(
		autosaved != null
		and autosaved.credits == 97
		and autosaved.completed_order_ids.get(&"order_red_sand_m0", false)
		and autosaved.read_dialogue_ids.get(&"save_smoke/line_read", false),
		"Automatic Results save omitted required progress fields."
	)

	_save_service.set_automatic_saves_enabled(false)
	_check(
		_save_service.save_progress(),
		"Could not rotate the valid post-delivery save into backup: %s"
		% _save_service.last_error
	)
	_check(
		FileAccess.file_exists(TEST_BACKUP_PATH),
		"A second valid save did not create a backup."
	)
	_write_text(TEST_SAVE_PATH, "{corrupt primary")

	await _release_app()
	_game_state.reset_runtime_state()
	_save_service.set_automatic_saves_enabled(true)
	_check(
		_game_state.get_credits() == 0
		and not _game_state.has_completed_order(&"order_red_sand_m0"),
		"Restart fixture did not clear runtime progress before Continue."
	)

	main_menu = await _start_app_and_get_main_menu()
	if main_menu == null:
		await _cleanup()
		_finish_smoke()
		return
	_check(main_menu.is_continue_button_enabled(), "Valid backup did not enable Continue.")
	_check(main_menu.is_continue_button_focused(), "Continue lacks initial focus when available.")
	_check(
		main_menu.is_status_visible()
		and main_menu.get_status_text().contains("上一份有效备份"),
		"Backup recovery warning is not readable in Chinese."
	)
	_check(
		VIEWPORT_RECT.encloses(main_menu.get_panel_rect())
		and VIEWPORT_RECT.encloses(main_menu.get_status_rect()),
		"Backup warning leaves the 640x360 viewport."
	)
	_check(
		not main_menu.get_status_rect().intersects(main_menu.get_start_button_rect())
		and not main_menu.get_status_rect().intersects(
			main_menu.get_continue_button_rect()
		),
		"Backup warning overlaps a main-menu action."
	)
	_check(main_menu.continue_game(), "Continue failed: %s" % main_menu.last_error)
	_check(
		_save_service.last_load_source == SaveServiceModel.LoadSource.BACKUP,
		"Continue did not report backup as the recovery source."
	)
	await process_frame
	await process_frame
	await process_frame

	_check(
		_scene_router.current_stage == SceneRouterService.Stage.STATION,
		"Continue did not return the player to the stable station stage."
	)
	_check(
		_game_state.get_credits() == 97
		and _game_state.has_completed_order(&"order_red_sand_m0")
		and _game_state.has_story_flag(M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED)
		and _game_state.has_read_dialogue_line(&"save_smoke", &"line_read")
		and _game_state.ship_configuration.get(ShipLoadoutRules.SLOT_UTILITY, &"")
		== ShipLoadoutRules.LASER_MODULE_ID,
		"Continue did not restore credits, order, story, dialogue, and module progress."
	)
	var scene_container: Control = _app.get_node_or_null("SceneContainer") as Control
	var station: StationHub = (
		scene_container.get_child(0) as StationHub
		if scene_container != null and scene_container.get_child_count() == 1
		else null
	)
	_check(station != null, "Continue did not instantiate the station.")
	if station != null:
		var return_state: StationReturnStateController = station.get_return_state_controller()
		_check(return_state != null, "Station return-state controller is unavailable.")
		if return_state != null:
			_check(
				return_state.is_first_delivery_display_visible()
				and return_state.get_credit_text().contains("97"),
				"Restored station upgrade and credit feedback are not visible."
			)
	var repaired_primary: GameProgressData = _read_progress(TEST_SAVE_PATH)
	_check(
		repaired_primary != null and repaired_primary.credits == 97,
		"Entering the stable station did not repair the primary from recovered progress."
	)
	_check(
		_read_text(TEST_REJECTED_PATH) == "{corrupt primary",
		"Primary repair did not preserve the rejected bytes for diagnosis."
	)

	await _cleanup()
	_finish_smoke()


func _start_app_and_get_main_menu() -> MainMenu:
	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(app_scene != null, "App scene could not be loaded.")
	if app_scene == null:
		return null
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene did not instantiate as UniverseDeliverApp.")
	if _app == null:
		return null
	root.add_child(_app)
	await process_frame
	await process_frame
	await process_frame
	var scene_container: Control = _app.get_node_or_null("SceneContainer") as Control
	_check(scene_container != null, "App SceneContainer is unavailable.")
	if scene_container == null or scene_container.get_child_count() != 1:
		_check(false, "App did not start with exactly one stage scene.")
		return null
	var main_menu: MainMenu = scene_container.get_child(0) as MainMenu
	_check(main_menu != null, "App did not start at MainMenu.")
	return main_menu


func _seed_completed_red_sand_order() -> bool:
	var order: OrderDefinition = load(RED_SAND_ORDER_PATH) as OrderDefinition
	var laser_module: ShipModuleDefinition = load(ASTEROID_LASER_PATH) as ShipModuleDefinition
	if order == null or laser_module == null:
		return false
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	_game_state.mark_dialogue_line_read(&"save_smoke", &"line_read")
	if not _game_state.accept_order(order) or not _game_state.equip_ship_module(laser_module):
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	if run_state == null:
		return false
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	return run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)


func _read_progress(path: String) -> GameProgressData:
	var raw_text: String = _read_text(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		return null
	var progress: GameProgressData = GameProgressData.from_dictionary(parsed as Dictionary)
	return progress if progress.is_valid() else null


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
	await process_frame
	await process_frame
	_app = null


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


func _finish_smoke() -> void:
	if _failures.is_empty():
		print(
			"[save-continue] PASS: Results autosave, validated backup, Chinese Continue, "
			+ "stable-station restoration, and independent settings reference."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[save-continue] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
