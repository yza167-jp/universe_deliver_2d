extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const TEST_SAVE_PATH: String = "user://t113_archive_terminal.json"
const TEST_TEMP_PATH: String = "user://t113_archive_terminal.tmp"
const TEST_BACKUP_PATH: String = "user://t113_archive_terminal.backup.json"
const TEST_REJECTED_PATH: String = "user://t113_archive_terminal.invalid.json"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const RELAY_ECHO_CODEX_ID: StringName = &"codex_anomaly_relay_echo"
const WHITE_NOISE_CODEX_ID: StringName = &"codex_planet_white_noise"

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _original_save_isolation: bool = false
var _original_automatic_saves: bool = false
var _game_state: GameStateModel
var _save_service: SaveServiceModel
var _registry: GameDataRegistry
var _contract: RedSandRevisitContract
var _station: StationHub
var _focus_fixture: Button


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_save_service = root.get_node_or_null("SaveService") as SaveServiceModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as RedSandRevisitContract
	_check(_game_state != null, "T-113 smoke requires GameState.")
	_check(_save_service != null, "T-113 smoke requires SaveService.")
	_check(_registry != null, "T-113 smoke requires the M1 registry.")
	_check(_contract != null, "T-113 smoke requires the revisit contract.")
	if (
		_game_state == null
		or _save_service == null
		or _registry == null
		or _contract == null
	):
		await _cleanup()
		_finish()
		return

	_original_save_isolation = _save_service.isolated_debug_session
	_original_automatic_saves = _save_service.automatic_saves_enabled
	_save_service.set_isolated_debug_session(false)
	_save_service.set_automatic_saves_enabled(false)
	_save_service.configure_storage_paths(
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH
	)
	_remove_test_files()

	await _check_locked_station()
	if not _prepare_completed_revisit():
		await _cleanup()
		_finish()
		return
	await _instantiate_station()
	if _station == null:
		await _cleanup()
		_finish()
		return
	await _check_archive_activation_briefing()
	await _check_archive_terminal_flow()
	await _check_save_and_continue()
	await _cleanup()
	_finish()


func _check_locked_station() -> void:
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	await _instantiate_station()
	if _station == null:
		return
	var controller: StationArchiveTerminalController = (
		_station.get_archive_terminal_controller()
	)
	var presenter: StationStatePresenter = (
		_station.get_station_state_presenter()
	)
	var terminal: Interactable2D = (
		_station.get_archive_terminal_interactable()
	)
	_check(controller != null, "Locked station is missing the archive controller.")
	_check(presenter != null, "Locked station is missing the state presenter.")
	_check(terminal != null, "Locked station is missing the archive interactable.")
	_check(
		controller != null
		and not controller.is_terminal_available()
		and presenter != null
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and not presenter.is_archive_terminal_powered()
		and presenter.get_archive_terminal_label_text()
		== "旧档案接口 · 未接通"
		and terminal != null
		and not terminal.can_interact(_station.get_station_player()),
		"New Game did not keep the archive shell visible, offline, and non-interactive.",
	)
	await _free_station()


func _prepare_completed_revisit() -> bool:
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var m0_order: OrderDefinition = _registry.find_order(
		GameDataValidator.M1_ACTUAL_M0_ORDER_ID
	)
	_check(
		m0_order != null
		and _game_state.accept_order(m0_order)
		and _game_state.complete_order(
			m0_order,
			-1,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		),
		"T-113 could not prepare the completed M0 baseline.",
	)
	if m0_order == null or not _game_state.has_completed_order(m0_order.id):
		return false
	_game_state.main_story_chapter = (
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	)
	if not _game_state.unlocked_planet_ids.has(
		M1ProgressRules.PLANET_RED_SAND
	):
		_game_state.unlocked_planet_ids.append(
			M1ProgressRules.PLANET_RED_SAND
		)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	_check(
		_game_state.accept_order(_contract.order),
		"T-113 could not accept the formal revisit order.",
	)
	if _game_state.current_order_id != _contract.order.id:
		return false
	_game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		_contract.accepted_state_id
	)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	run_state.cargo_integrity = 100.0
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	_game_state.set_story_flag(_contract.keep_local_record_flag)
	_game_state.set_story_flag(_contract.completion_dialogue_flag)
	var module: ShipModuleDefinition = _registry.find_module(
		_contract.auto_equip_module_id
	)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		_contract.order,
		run_state
	)
	_check(
		module != null
		and _game_state.settle_current_order(
			_contract.order,
			settlement,
			&"",
			[
				StationTutorialController.ARCHIVE_BRIEFING_PENDING_FLAG,
			],
			_contract.get_choice_relation_rewards(_game_state),
			[module]
		),
		"T-113 could not settle the completed revisit fixture.",
	)
	return (
		_game_state.has_completed_order(_contract.order.id)
		and _game_state.has_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
	)


func _instantiate_station() -> void:
	await _free_station()
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	_station = station_scene.instantiate() as StationHub
	_check(_station != null, "T-113 station scene did not instantiate.")
	if _station == null:
		return
	root.add_child(_station)
	await _wait_frames(4)


func _free_station() -> void:
	if _station == null or not is_instance_valid(_station):
		_station = null
		return
	_station.queue_free()
	await _wait_frames(2)
	_station = null


func _check_archive_terminal_flow() -> void:
	var controller: StationArchiveTerminalController = (
		_station.get_archive_terminal_controller()
	)
	var presenter: StationStatePresenter = (
		_station.get_station_state_presenter()
	)
	var terminal: Interactable2D = (
		_station.get_archive_terminal_interactable()
	)
	var browser: CodexBrowserUI = _station.get_archive_terminal_ui()
	var player: StationPlayer = _station.get_station_player()
	var coordinator: StationModalCoordinator = _station.get_modal_coordinator()
	var archive_root: Node2D = presenter.get_state_root(
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	var archive_label: Label = archive_root.get_node_or_null(
		"ArchiveTerminalLabel"
	) as Label
	_check(
		controller != null and controller.is_terminal_available(),
		"The exact archive state did not enable the archive interaction.",
	)
	_check(
		presenter != null
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and presenter.is_archive_terminal_powered(),
		"The exact archive state did not power the persistent terminal shell.",
	)
	_check(
		terminal != null
		and terminal.get_interaction_prompt() == "查看档案终端",
		"The archive terminal interaction prompt was not localized.",
	)
	_check(
		archive_label != null and archive_label.text == "档案终端",
		"The visible archive terminal label was not localized.",
	)
	_check(browser != null, "The station archive browser is missing.")
	_check(player != null, "The station player is missing.")
	_check(coordinator != null, "The station modal coordinator is missing.")
	if (
		terminal == null
		or browser == null
		or player == null
		or coordinator == null
	):
		return

	_focus_fixture = Button.new()
	_focus_fixture.text = "t113-focus"
	root.add_child(_focus_fixture)
	_focus_fixture.grab_focus()
	await process_frame
	_check(
		terminal.interact(player),
		"The unlocked archive terminal rejected interaction.",
	)
	await _wait_frames(2)
	_check(
		browser.visible
		and coordinator.has_modal(
			StationArchiveTerminalController.MODAL_ARCHIVE_TERMINAL
		)
		and coordinator.has_world_input_lock()
		and not player.is_input_enabled()
		and player.is_interaction_prompt_suppressed(),
		"Archive browsing did not acquire the shared world-input modal.",
	)
	_check(
		VIEWPORT_RECT.encloses(browser.get_panel_rect())
		and VIEWPORT_RECT.encloses(browser.get_entry_panel_rect())
		and VIEWPORT_RECT.encloses(browser.get_detail_panel_rect())
		and not browser.get_entry_panel_rect().intersects(
			browser.get_detail_panel_rect()
		),
		"Archive browser sections overlap or leave the 640x360 viewport.",
	)
	_check(
		browser.get_current_category()
		== CodexEntryDefinition.Category.PLANET
		and browser.get_entry_texts()
		== PackedStringArray(["赤砂星", "白噪星"])
		and _game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_WHITE_NOISE
		),
		"The completed revisit did not keep White Noise knowledge and navigation unlock aligned.",
	)

	var keyboard_event: InputEventAction = InputEventAction.new()
	keyboard_event.action = &"ui_right"
	keyboard_event.pressed = true
	browser._unhandled_input(keyboard_event)
	_check(
		browser.get_current_category()
		== CodexEntryDefinition.Category.CHARACTER
		and browser.get_entry_texts() == PackedStringArray(["伊娅"]),
		"Keyboard navigation exposed a future character or lost Iya.",
	)
	var anomaly_button: Button = browser.get_category_button(
		CodexEntryDefinition.Category.ANOMALY
	)
	_check(anomaly_button != null, "The anomaly category button is missing.")
	if anomaly_button != null:
		anomaly_button.pressed.emit()
	_check(
		browser.get_entry_texts()
		== PackedStringArray(["旧铭牌异常回波"])
		and browser.get_detail_description_text().contains("来源和含义均未确定"),
		"Mouse category activation did not show the bounded relay-echo clue.",
	)
	browser.select_category(CodexEntryDefinition.Category.CARGO)
	_check(
		browser.get_entry_texts()
		== PackedStringArray(["中继纹屏蔽材料"])
		and browser.get_detail_description_text().contains("完整纹路保留"),
		"The archive lost the completed revisit cargo branch record.",
	)
	browser.select_category(CodexEntryDefinition.Category.SOUVENIR)
	_check(
		browser.get_entry_texts()
		== PackedStringArray(["旧中继铭牌"])
		and browser.get_detail_description_text().contains("早于公司现行标准"),
		"The formal archive lost the known old relay plaque souvenir record.",
	)
	browser.close_browser()
	await process_frame
	_check(
		not coordinator.is_modal_active()
		and player.is_input_enabled()
		and not player.is_interaction_prompt_suppressed()
		and root.gui_get_focus_owner() == _focus_fixture,
		"Closing the archive did not restore world input, prompts, and prior focus.",
	)


func _check_archive_activation_briefing() -> void:
	var lao_pi: LaoPiStation = _station.get_lao_pi()
	var tutorial: StationTutorialController = (
		_station.get_tutorial_controller()
	)
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	_check(
		lao_pi != null and tutorial != null and dialogue_ui != null,
		"T-113 Lao Pi briefing fixture is incomplete.",
	)
	if lao_pi == null or tutorial == null or dialogue_ui == null:
		return
	_check(
		_game_state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_PENDING_FLAG
		)
		and not _game_state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
		)
		and tutorial.get_active_dialogue_id()
		== &"dialogue_lao_pi_archive_terminal_briefing",
		"Returning from the revisit did not automatically start the one-time archive activation.",
	)
	await _finish_active_dialogue(tutorial, dialogue_ui, 6)
	_check(
		_game_state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
		),
		"Completing the archive activation did not persist its one-time flag.",
	)
	_check(
		lao_pi.interact(_station.get_station_player())
		and tutorial.get_active_dialogue_id()
		== &"dialogue_lao_pi_station_daily",
		"The completed activation replayed instead of returning Lao Pi to daily dialogue.",
	)
	await _finish_active_dialogue(tutorial, dialogue_ui, 5)


func _check_save_and_continue() -> void:
	_check(
		_save_service.save_progress(),
		"T-113 completed archive state could not save: %s."
		% _save_service.last_error,
	)
	_game_state.reset_runtime_state()
	await _wait_frames(2)
	var controller: StationArchiveTerminalController = (
		_station.get_archive_terminal_controller()
	)
	var presenter: StationStatePresenter = (
		_station.get_station_state_presenter()
	)
	_check(
		not controller.is_terminal_available()
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and not presenter.is_archive_terminal_powered(),
		"Runtime reset did not return the persistent archive shell to its offline state.",
	)
	_check(
		_save_service.load_progress(),
		"T-113 archive save could not Continue: %s."
		% _save_service.last_error,
	)
	await _wait_frames(3)
	_check(
		controller.is_terminal_available()
		and presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and _game_state.has_codex_entry(RELAY_ECHO_CODEX_ID)
		and _game_state.has_codex_entry(WHITE_NOISE_CODEX_ID)
		and _game_state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
		),
		"Continue did not restore the terminal, known records, and Lao Pi briefing state.",
	)
	await _free_station()
	await _instantiate_station()
	if _station == null:
		return
	controller = _station.get_archive_terminal_controller()
	presenter = _station.get_station_state_presenter()
	var tutorial: StationTutorialController = _station.get_tutorial_controller()
	_check(
		controller != null
		and controller.is_terminal_available()
		and presenter != null
		and presenter.is_archive_terminal_powered()
		and tutorial != null
		and tutorial.get_active_dialogue_id().is_empty(),
		"Loading an already activated archive replayed its activation dialogue.",
	)
	var browser: CodexBrowserUI = _station.get_archive_terminal_ui()
	_check(
		_station.get_archive_terminal_interactable().interact(
			_station.get_station_player()
		),
		"The restored archive terminal could not reopen.",
	)
	await _wait_frames(2)
	browser.select_category(CodexEntryDefinition.Category.ANOMALY)
	_check(
		browser.get_entry_texts()
		== PackedStringArray(["旧铭牌异常回波"]),
		"The restored archive lost its anomaly record.",
	)
	browser.close_browser()
	await process_frame


func _finish_active_dialogue(
	tutorial: StationTutorialController,
	dialogue_ui: DialogueUI,
	maximum_steps: int
) -> void:
	var remaining_steps: int = maximum_steps
	while not tutorial.get_active_dialogue_id().is_empty() and remaining_steps > 0:
		dialogue_ui.quick_show_current_line()
		dialogue_ui.continue_dialogue()
		remaining_steps -= 1
		await process_frame
	_check(
		remaining_steps > 0,
		"Station dialogue exceeded its expected authored line count.",
	)


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _remove_test_files() -> void:
	for path: String in [
		TEST_SAVE_PATH,
		TEST_TEMP_PATH,
		TEST_BACKUP_PATH,
		TEST_REJECTED_PATH,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	await _free_station()
	if _focus_fixture != null and is_instance_valid(_focus_fixture):
		_focus_fixture.queue_free()
		await process_frame
	_focus_fixture = null
	if _game_state != null:
		_game_state.reset_runtime_state()
	_remove_test_files()
	if _save_service != null:
		_save_service.reset_storage_paths()
		_save_service.set_isolated_debug_session(_original_save_isolation)
		_save_service.set_automatic_saves_enabled(
			_original_automatic_saves
		)
	TranslationServer.set_locale(_original_locale)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[t113-archive-terminal] PASS: exact unlock, v2 catalog, "
			+ "640x360 modal, focus restore, Lao Pi briefing, save, and Continue."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t113-archive-terminal] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
