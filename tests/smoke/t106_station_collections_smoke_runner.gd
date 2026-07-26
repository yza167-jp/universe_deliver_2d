extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const CODEX_SCENE_PATH: String = "res://scenes/ui/codex_browser.tscn"
const M0_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _station: StationHub
var _focus_fixture: Button


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_check(_game_state != null, "GameState autoload is unavailable.")
	if _game_state == null:
		_finish(original_locale)
		return
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	_check(
		order != null
		and _game_state.accept_order(order)
		and _game_state.complete_order(
			order,
			-1,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		),
		"T-106 M0 completion fixture could not settle.",
	)

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	_station = station_scene.instantiate() as StationHub
	_check(_station != null, "Station scene did not instantiate.")
	if _station == null:
		_finish(original_locale)
		return
	root.add_child(_station)
	await process_frame
	await process_frame

	var return_state: StationReturnStateController = (
		_station.get_return_state_controller()
	)
	var wall_ui: SouvenirWallUI = _station.get_souvenir_wall_ui()
	var coordinator: StationModalCoordinator = _station.get_modal_coordinator()
	var presenter: StationStatePresenter = (
		_station.get_station_state_presenter()
	)
	var player: StationPlayer = _station.get_station_player()
	_check(return_state != null, "Station return-state controller is missing.")
	_check(wall_ui != null, "Souvenir wall UI is missing.")
	_check(coordinator != null, "Station modal coordinator is missing.")
	_check(presenter != null, "Station-state presenter is missing.")
	_check(player != null, "Station player is missing.")
	if (
		return_state == null
		or wall_ui == null
		or coordinator == null
		or presenter == null
		or player == null
	):
		await _cleanup()
		_finish(original_locale)
		return

	_check(
		return_state.is_first_delivery_display_visible()
		and _station.get_memorabilia_slot_states()
		== [true, false, false, false],
		"The completed M0 state must fill exactly the first wall slot.",
	)
	var station_label: Label = _station.get_node_or_null(
		"FeatureLabels/MemorabiliaLabel"
	) as Label
	_check(
		station_label != null and station_label.text.contains("旧中继铭牌"),
		"The M0 wall label lost the old relay plaque.",
	)
	_check(
		presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and not presenter.is_archive_terminal_powered()
		and not presenter.is_state_root_visible(
			StationStateRules.ECOLOGY_CORNER_ID
		)
		and not presenter.is_state_root_visible(
			StationStateRules.RELAY_OBSERVATORY_ID
		),
		"M0-only progress did not preserve exactly the dormant archive shell.",
	)
	for interactable: Interactable2D in _station.get_interactables():
		_check(
			not StationStateRules.is_known_state_id(interactable.interaction_id),
			"A placeholder M1 facility leaked into normal station interactions.",
		)

	_focus_fixture = Button.new()
	_focus_fixture.text = "focus-fixture"
	root.add_child(_focus_fixture)
	_focus_fixture.grab_focus()
	await process_frame
	_check(
		return_state.get_memorabilia_wall().interact(player),
		"The station wall did not open its collection browser.",
	)
	await process_frame
	_check(
		wall_ui.visible
		and coordinator.has_modal(
			StationReturnStateController.MODAL_MEMORABILIA_OBSERVATION
		)
		and coordinator.has_world_input_lock()
		and not player.is_input_enabled()
		and player.is_interaction_prompt_suppressed()
		and not player.is_interaction_prompt_visible(),
		"Wall details must suppress prompts and lock the world behind the modal.",
	)
	var slot_texts: PackedStringArray = wall_ui.get_slot_texts()
	_check(
		slot_texts.size() == 4
		and slot_texts[0].contains("旧中继铭牌")
		and slot_texts[1] == "未解锁陈列位"
		and slot_texts[2] == "未解锁陈列位"
		and slot_texts[3] == "未解锁陈列位"
		and not " ".join(slot_texts).contains("霜纹")
		and not " ".join(slot_texts).contains("风铃")
		and not " ".join(slot_texts).contains("风向标"),
		"Locked slots revealed future souvenir names or lost stable order.",
	)
	_check(
		VIEWPORT_RECT.encloses(wall_ui.get_panel_rect())
		and VIEWPORT_RECT.encloses(wall_ui.get_slot_panel_rect())
		and VIEWPORT_RECT.encloses(wall_ui.get_detail_panel_rect())
		and not wall_ui.get_slot_panel_rect().intersects(
			wall_ui.get_detail_panel_rect()
		),
		"Souvenir wall sections overlap or leave the 640x360 viewport.",
	)
	var keyboard_event: InputEventAction = InputEventAction.new()
	keyboard_event.action = &"ui_right"
	keyboard_event.pressed = true
	wall_ui._unhandled_input(keyboard_event)
	_check(
		wall_ui.get_selected_souvenir_id()
		== &"souvenir_white_noise_frost_index"
		and wall_ui.get_detail_text().contains("尚未获得")
		and not wall_ui.get_detail_text().contains("霜纹"),
		"Keyboard selection did not use the same redacted slot detail path.",
	)
	var plaque_button: Button = wall_ui.get_slot_button(
		&"souvenir_old_relay_plaque"
	)
	_check(plaque_button != null, "The first souvenir slot button is missing.")
	if plaque_button != null:
		plaque_button.pressed.emit()
		_check(
			wall_ui.get_selected_souvenir_id()
			== &"souvenir_old_relay_plaque"
			and wall_ui.get_detail_text().contains("旧中继铭牌"),
			"Mouse activation did not select the same souvenir detail path.",
		)
	wall_ui.close_wall()
	await process_frame
	_check(
		not coordinator.is_modal_active()
		and player.is_input_enabled()
		and not player.is_interaction_prompt_suppressed()
		and root.gui_get_focus_owner() == _focus_fixture,
		"Closing the wall did not restore input, prompts, and prior focus.",
	)

	await _check_codex_browser()

	_check(
		_game_state.unlock_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		).changed,
		"Archive terminal state did not unlock.",
	)
	await process_frame
	_check(
		presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and presenter.is_archive_terminal_powered()
		and not presenter.is_state_root_visible(
			StationStateRules.ECOLOGY_CORNER_ID
		)
		and not presenter.is_state_root_visible(
			StationStateRules.RELAY_OBSERVATORY_ID
		),
		"Exact archive ID did not control only its own placeholder root.",
	)
	_game_state.unlock_station_state(StationStateRules.ECOLOGY_CORNER_ID)
	_game_state.unlock_station_state(StationStateRules.RELAY_OBSERVATORY_ID)
	await process_frame
	for state_id: StringName in StationStateRules.STATE_IDS:
		_check(
			presenter.is_state_root_visible(state_id),
			"Unlocked station root did not become active: %s." % state_id,
		)
	_game_state.reset_runtime_state()
	await process_frame
	_check(
		presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and not presenter.is_archive_terminal_powered()
		and not presenter.is_state_root_visible(
			StationStateRules.ECOLOGY_CORNER_ID
		)
		and not presenter.is_state_root_visible(
			StationStateRules.RELAY_OBSERVATORY_ID
		),
		"New Game reset did not restore exactly the dormant archive shell.",
	)

	await _cleanup()
	_finish(original_locale)


func _check_codex_browser() -> void:
	var codex_scene: PackedScene = load(CODEX_SCENE_PATH) as PackedScene
	var browser: CodexBrowserUI = codex_scene.instantiate() as CodexBrowserUI
	_check(browser != null, "Codex browser scene did not instantiate.")
	if browser == null:
		return
	root.add_child(browser)
	browser.set_game_state_override(_game_state)
	_check(browser.open_browser(), "Codex browser did not open.")
	await process_frame
	_check(
		VIEWPORT_RECT.encloses(browser.get_panel_rect())
		and VIEWPORT_RECT.encloses(browser.get_entry_panel_rect())
		and VIEWPORT_RECT.encloses(browser.get_detail_panel_rect())
		and not browser.get_entry_panel_rect().intersects(
			browser.get_detail_panel_rect()
		),
		"Codex sections overlap or leave the 640x360 viewport.",
	)
	_check(
		browser.get_current_category()
		== CodexEntryDefinition.Category.PLANET
		and browser.get_current_entry_count() == 1
		and browser.get_entry_texts() == PackedStringArray(["赤砂星"])
		and browser.get_detail_description_text().contains("沙漠殖民地"),
		"Codex planet category did not show the unlocked Red Sand record.",
	)
	var keyboard_event: InputEventAction = InputEventAction.new()
	keyboard_event.action = &"ui_right"
	keyboard_event.pressed = true
	browser._unhandled_input(keyboard_event)
	_check(
		browser.get_current_category()
		== CodexEntryDefinition.Category.CHARACTER
		and browser.get_entry_texts() == PackedStringArray(["伊娅"]),
		"Keyboard category switching did not show Iya.",
	)
	var souvenir_button: Button = browser.get_category_button(
		CodexEntryDefinition.Category.SOUVENIR
	)
	_check(souvenir_button != null, "Codex souvenir category button is missing.")
	if souvenir_button != null:
		souvenir_button.pressed.emit()
	_check(
		browser.get_current_category()
		== CodexEntryDefinition.Category.SOUVENIR
		and browser.get_current_entry_count() == 1
		and browser.get_entry_texts() == PackedStringArray(["旧中继铭牌"]),
		"Mouse category activation duplicated or lost the relay plaque.",
	)
	browser.close_browser()
	browser.queue_free()
	await process_frame


func _cleanup() -> void:
	if _focus_fixture != null and is_instance_valid(_focus_fixture):
		_focus_fixture.queue_free()
	if _station != null and is_instance_valid(_station):
		_station.queue_free()
	await process_frame
	await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()


func _finish(original_locale: String) -> void:
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print(
			"[t106-collections] PASS: Codex, four-slot wall, modal restore, "
			+ "station-state roots, and 640x360 layout."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t106-collections] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
