extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const REVISIT_ORDER_ID: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const WHITE_SIDE_ORDER_ID: StringName = &"side_white_noise_returned_memory"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var game_state: GameStateModel = root.get_node_or_null("GameState") as GameStateModel
	_check(game_state != null, "GameState autoload is unavailable.")
	if game_state == null:
		_finish_smoke(original_locale)
		return
	game_state.reset_runtime_state()
	game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame
	await process_frame
	var player: StationPlayer = station.get_station_player()
	var lao_pi: LaoPiStation = station.get_lao_pi()
	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var terminal_ui: OrderTerminalUI = station.get_order_terminal_ui()
	var terminal_interactable: Interactable2D = station.get_node_or_null(
		"Interactables/OrderTerminal"
	) as Interactable2D
	_check(player != null, "Station player is missing.")
	_check(lao_pi != null, "Lao Pi is missing.")
	_check(tutorial != null, "Lao Pi dialogue controller is missing.")
	_check(terminal_ui != null, "Order terminal UI is missing.")
	_check(terminal_interactable != null, "Order terminal interactable is missing.")
	if (
		player == null
		or lao_pi == null
		or tutorial == null
		or terminal_ui == null
		or terminal_interactable == null
	):
		await _cleanup(station, game_state)
		_finish_smoke(original_locale)
		return

	_check(terminal_interactable.interact(player), "Order terminal interaction was rejected.")
	await process_frame
	_check(terminal_ui.visible, "Order terminal interaction did not open its UI.")
	_check(not player.is_input_enabled(), "Station movement must pause while the terminal is open.")
	_check(
		VIEWPORT_RECT.encloses(terminal_ui.get_panel_rect()),
		"Order terminal panel leaves the 640x360 viewport."
	)
	var directory_rect: Rect2 = terminal_ui.get_directory_panel_rect()
	var detail_rect: Rect2 = terminal_ui.get_detail_scroll_rect()
	var accept_button: Button = terminal_ui.get_node_or_null("%AcceptButton") as Button
	var close_button: Button = terminal_ui.get_node_or_null("%CloseButton") as Button
	_check(
		directory_rect.size.x >= 170.0
		and directory_rect.size.x <= 210.0,
		"Order directory must stay within the compact 170-210 px target."
	)
	_check(
		not directory_rect.intersects(detail_rect, false),
		"Order directory overlaps the selected-order detail region."
	)
	_check(
		accept_button != null
		and close_button != null
		and VIEWPORT_RECT.encloses(accept_button.get_global_rect())
		and VIEWPORT_RECT.encloses(close_button.get_global_rect())
		and not detail_rect.intersects(accept_button.get_global_rect(), false),
		"Detail scrolling and persistent actions overlap at 640x360."
	)

	_check(
		terminal_ui.get_directory_entry_count() == 1
		and terminal_ui.get_selected_order_id() == M0_ORDER_ID
		and terminal_ui.get_directory_entry_texts()[0].contains("主线")
		and terminal_ui.get_directory_entry_texts()[0].contains("赤砂星"),
		"New Game must show exactly one clear M0 main-order card."
	)
	_check(terminal_ui.get_status_text() == "可接取", "Initial M0 order state is unclear.")
	_check(terminal_ui.is_accept_enabled(), "Valid Red Sand order cannot be accepted.")
	_check(
		terminal_ui.get_environment_text().contains("陨石带")
		and terminal_ui.get_environment_text().contains("低空雷达"),
		"Planet environment and risks are missing from the terminal."
	)
	_check(
		terminal_ui.get_cargo_text().contains("深层冷却泵核心")
		and terminal_ui.get_cargo_text().contains("强烈碰撞"),
		"Cargo identity and company handling guidance are missing."
	)
	_check(
		terminal_ui.get_required_modules_text().contains("标准动力模块")
		and terminal_ui.get_required_modules_text().contains("大气防护模块")
		and terminal_ui.get_required_modules_text().contains("已安装"),
		"Required modules do not distinguish their installed state."
	)
	_check(
		terminal_ui.get_recommended_modules_text().contains("激光炮")
		and terminal_ui.get_recommended_modules_text().contains("护盾备用电源")
		and terminal_ui.get_recommended_modules_text().contains("已拥有，未安装")
		and terminal_ui.is_accept_enabled(),
		"Recommended modules must show ownership without blocking acceptance."
	)
	_check(
		terminal_ui.get_customer_history_text().contains("工业配额异常")
		and terminal_ui.get_customer_history_text().contains("工人居住区"),
		"Customer history does not establish the order's story tension."
	)
	var m0_button: Button = terminal_ui.get_directory_button(M0_ORDER_ID)
	_check(m0_button != null, "M0 directory button is missing.")
	if m0_button != null:
		m0_button.pressed.emit()
	await process_frame
	_check(
		game_state.current_order_id.is_empty(),
		"Selecting an order card must never accept it implicitly."
	)

	_check(terminal_ui.accept_current_order(), "Accepting the Red Sand order failed.")
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	_check(
		game_state.current_order_id == order.id
		and game_state.destination_id == order.destination_planet.id
		and game_state.cargo_id == order.cargo.id,
		"Explicit acceptance did not write the selected order IDs into GameState."
	)
	_check(
		terminal_ui.get_selected_order_id() == M0_ORDER_ID
		and terminal_ui.get_status_text() == "已接取"
		and not terminal_ui.is_accept_enabled(),
		"Accepting did not synchronize the pinned directory entry and detail state."
	)
	_check(
		terminal_ui.get_directory_entry_count() == 2,
		"An active order should retain one neutral next lead rather than a task ocean."
	)
	var clue_button: Button = terminal_ui.get_directory_button(REVISIT_ORDER_ID)
	_check(clue_button != null, "Active-order catalog is missing its one neutral next lead.")
	if clue_button != null:
		clue_button.pressed.emit()
	await process_frame
	_check(
		terminal_ui.get_selected_order_id() == M0_ORDER_ID
		and game_state.current_order_id == M0_ORDER_ID
		and not terminal_ui.select_order(REVISIT_ORDER_ID)
		and terminal_ui.get_feedback_text().contains("订单已锁定"),
		"The neutral next lead must remain non-selectable while preserving the active order."
	)
	_check(
		not terminal_ui.get_order_name_text().contains("PROVISIONAL")
		and not terminal_ui.get_feedback_text().contains("active_order"),
		"Player-facing catalog text exposed an internal key or reason ID."
	)
	if m0_button != null:
		m0_button.pressed.emit()
	terminal_ui.close_terminal()
	await process_frame
	_check(
		tutorial.get_active_dialogue_id() == &"dialogue_lao_pi_order_accepted",
		"Accepting the order did not update Lao Pi's dialogue."
	)
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	if dialogue_ui != null:
		await _finish_dialogue(
			tutorial,
			dialogue_ui,
			&"dialogue_lao_pi_order_accepted"
		)

	_check(lao_pi.interact(player), "Lao Pi active-order interaction was rejected.")
	_check(
		tutorial.get_active_dialogue_id() == &"dialogue_lao_pi_active_order_daily",
		"Lao Pi did not retain order-aware daily dialogue."
	)
	if dialogue_ui != null:
		await _finish_dialogue(
			tutorial,
			dialogue_ui,
			&"dialogue_lao_pi_active_order_daily"
		)

	_check(terminal_interactable.interact(player), "Accepted order could not be reviewed.")
	await process_frame
	_check(
		terminal_ui.get_selected_order_id() == M0_ORDER_ID,
		"Reopened terminal did not pin the active order first."
	)
	_check(game_state.complete_current_order(order), "Completion transition failed.")
	await process_frame
	_check(
		terminal_ui.get_history_count() == 1
		and terminal_ui.get_directory_button(M0_ORDER_ID) != null,
		"Completed M0 must produce exactly one selectable history row."
	)
	_check(
		terminal_ui.select_order(M0_ORDER_ID),
		"Completed M0 history row could not be selected."
	)
	_check(
		terminal_ui.get_status_text() == "已完成"
		and terminal_ui.get_accept_button_text() == "只读历史"
		and terminal_ui.get_feedback_text().contains("历史订单只读")
		and not terminal_ui.is_accept_enabled(),
		"Completed M0 history row did not become read-only."
	)
	_check(
		terminal_ui.get_parties_text().contains("公司调度")
		and terminal_ui.get_route_text().contains("赤砂星"),
		"Completed M0 history detail lost its known parties or destination."
	)
	_check(
		terminal_ui.get_reward_text().contains("100"),
		"Completed M0 history detail lost its known base reward."
	)
	_check(
		terminal_ui.get_customer_history_text().contains(
			"详细飞行结算未保留"
		),
		"Completed M0 history detail did not disclose the settlement limitation."
	)

	var invalid_order: OrderDefinition = OrderDefinition.new()
	invalid_order.id = &"order_invalid_fixture"
	invalid_order.display_name_key = &"ORDER_RED_SAND_M0_NAME"
	terminal_ui.set_order_definition(invalid_order)
	_check(not terminal_ui.is_accept_enabled(), "Incomplete order data did not disable acceptance.")
	_check(
		terminal_ui.get_status_text() == "未开放"
		and terminal_ui.get_feedback_text().contains("资料不完整"),
		"Incomplete order data did not report a localized visible reason."
	)

	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_WHITE_NOISE)
	game_state.set_story_flag(&"story_red_sand_order_completed")
	terminal_ui.set_order_definition(null)
	terminal_ui.close_terminal()
	await process_frame
	_check(terminal_interactable.interact(player), "M1 prologue terminal could not reopen.")
	await process_frame
	_check(
		terminal_ui.get_directory_button(REVISIT_ORDER_ID) != null
		and terminal_ui.get_directory_button(WHITE_SIDE_ORDER_ID) != null,
		"M1 prologue hierarchy does not expose the current revisit and discovered optional order."
	)
	var side_button: Button = terminal_ui.get_directory_button(WHITE_SIDE_ORDER_ID)
	if side_button != null:
		side_button.pressed.emit()
	await process_frame
	_check(
		terminal_ui.get_selected_order_id() == WHITE_SIDE_ORDER_ID
		and game_state.current_order_id.is_empty()
		and not terminal_ui.is_accept_enabled()
		and terminal_ui.get_feedback_text().contains("航路资料尚未开放"),
		"Mouse selection must inspect registered-only optional content without accepting it."
	)
	_check(terminal_ui.select_order(REVISIT_ORDER_ID), "Revisit could not be selected for keyboard focus.")
	var revisit_button: Button = terminal_ui.get_directory_button(REVISIT_ORDER_ID)
	if revisit_button != null:
		revisit_button.grab_focus()
	_push_action(&"ui_down")
	await process_frame
	_check(
		terminal_ui.get_selected_order_id() == WHITE_SIDE_ORDER_ID
		and game_state.current_order_id.is_empty(),
		"Keyboard navigation must use the same selection-only path as mouse input."
	)
	_check(
		not terminal_ui.accept_current_order()
		and game_state.current_order_id.is_empty(),
		"Registered-only content was accepted through the explicit action."
	)
	for text: String in terminal_ui.get_directory_entry_texts():
		_check(
			not text.contains("order_")
			and not text.contains("side_")
			and not text.contains("PROVISIONAL"),
			"Directory exposed an internal stable ID or provisional key name."
		)

	terminal_ui.close_terminal()
	await process_frame
	_check(player.is_input_enabled(), "Station movement did not resume after closing the terminal.")
	await _exercise_selected_accept(game_state)
	await _cleanup(station, game_state)
	_finish_smoke(original_locale)


func _exercise_selected_accept(game_state: GameStateModel) -> void:
	game_state.reset_runtime_state()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	var source_registry: GameDataRegistry = load(
		"res://data/m1_data_registry.tres"
	) as GameDataRegistry
	var m0_order: OrderDefinition = source_registry.find_order(M0_ORDER_ID)
	var selected_order: OrderDefinition = m0_order.duplicate(true) as OrderDefinition
	selected_order.id = &"side_catalog_selected_fixture"
	selected_order.order_type = OrderDefinition.OrderType.SIDE
	selected_order.required_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	selected_order.completion_flags.clear()
	selected_order.story_requirements.clear()
	var fixture_registry: GameDataRegistry = GameDataRegistry.new()
	fixture_registry.registry_id = &"test_selected_accept_catalog"
	fixture_registry.planets = source_registry.planets.duplicate()
	fixture_registry.orders = [m0_order, selected_order]
	fixture_registry.cargo_items = source_registry.cargo_items.duplicate()
	fixture_registry.modules = source_registry.modules.duplicate()
	fixture_registry.characters = source_registry.characters.duplicate()
	var terminal_scene: PackedScene = load(TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = terminal_scene.instantiate() as OrderTerminalUI
	terminal.data_registry = fixture_registry
	root.add_child(terminal)
	await process_frame
	_check(terminal.open_terminal(), "Selected-order fixture terminal could not open.")
	await process_frame
	var side_button: Button = terminal.get_directory_button(selected_order.id)
	_check(
		side_button != null and terminal.get_directory_entry_count() == 2,
		"Selected-order fixture did not expose two inspectable entries."
	)
	if side_button != null:
		side_button.pressed.emit()
	await process_frame
	_check(
		game_state.current_order_id.is_empty()
		and terminal.get_selected_order_id() == selected_order.id,
		"Selecting the second fixture order changed runtime state."
	)
	_check(
		terminal.accept_current_order()
		and game_state.current_order_id == selected_order.id
		and game_state.get_order_status(M0_ORDER_ID)
		== GameStateModel.OrderStatus.AVAILABLE,
		"Explicit acceptance did not apply only to the currently selected order."
	)
	terminal.queue_free()
	await process_frame


func _push_action(action: StringName) -> void:
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = action
	input_event.pressed = true
	root.push_input(input_event)
	var release_event: InputEventAction = input_event.duplicate() as InputEventAction
	release_event.pressed = false
	root.push_input(release_event)


func _finish_dialogue(
	controller: StationTutorialController,
	dialogue_ui: DialogueUI,
	expected_dialogue_id: StringName
) -> void:
	var remaining_lines: int = 16
	while controller.get_active_dialogue_id() == expected_dialogue_id and remaining_lines > 0:
		dialogue_ui.quick_show_current_line()
		_check(
			dialogue_ui.continue_dialogue(),
			"Dialogue could not advance: %s" % expected_dialogue_id
		)
		remaining_lines -= 1
		await process_frame
	_check(
		remaining_lines > 0,
		"Dialogue exceeded its smoke-test line limit: %s" % expected_dialogue_id
	)


func _cleanup(station: StationHub, game_state: GameStateModel) -> void:
	if station != null and is_instance_valid(station):
		station.queue_free()
		await process_frame
	game_state.reset_runtime_state()


func _finish_smoke(original_locale: String) -> void:
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print(
			"[order-terminal] PASS: compact catalog, selection-only input, explicit acceptance, "
			+ "registered-only guard, hierarchy, layout, and M0 tutorial feedback."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[order-terminal] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
