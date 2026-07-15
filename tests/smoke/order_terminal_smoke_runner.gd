extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

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
		station.queue_free()
		game_state.reset_runtime_state()
		await process_frame
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
	_check(terminal_ui.get_status_text() == "未接取", "Initial order state is not clear.")
	_check(terminal_ui.is_accept_enabled(), "Valid Red Sand order cannot be accepted.")
	_check(
		terminal_ui.get_feedback_text().contains("不会被误操作放弃"),
		"Terminal does not explain the main-order safety rule."
	)
	_check(
		terminal_ui.get_environment_text().contains("陨石带")
		and terminal_ui.get_environment_text().contains("低空雷达"),
		"Planet environment and risks are missing from the terminal."
	)
	_check(
		terminal_ui.get_cargo_text().contains("深层冷却泵核心")
		and terminal_ui.get_cargo_text().contains("强烈碰撞"),
		"Cargo identity and handling information are missing."
	)
	_check(
		terminal_ui.get_required_modules_text().contains("标准动力模块")
		and terminal_ui.get_required_modules_text().contains("大气防护模块"),
		"Required loadout is incomplete."
	)
	_check(
		terminal_ui.get_customer_history_text().contains("工业配额异常")
		and terminal_ui.get_customer_history_text().contains("工人居住区"),
		"Customer history does not establish the order's story tension."
	)
	_check(
		terminal_ui.get_future_order_text().contains("等待公司许可"),
		"Future-order placeholder is missing."
	)
	_check(
		terminal_ui.find_child("CancelButton", true, false) == null,
		"Main order exposes an accidental cancellation control."
	)

	_check(terminal_ui.accept_current_order(), "Accepting the Red Sand order failed.")
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	_check(
		game_state.current_order_id == order.id
		and game_state.destination_id == order.destination_planet.id
		and game_state.cargo_id == order.cargo.id,
		"Accepted order did not write its IDs into GameState."
	)
	_check(terminal_ui.get_status_text() == "已接取", "Accepted state is not visible.")
	_check(not terminal_ui.is_accept_enabled(), "Accepted order can be accepted twice.")
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
	_check(terminal_ui.get_status_text() == "已接取", "Reopened terminal lost accepted state.")
	_check(game_state.complete_current_order(order), "Future completion transition failed.")
	_check(terminal_ui.get_status_text() == "已完成", "Completed state is not visible.")
	_check(not terminal_ui.is_accept_enabled(), "Completed order became acceptable again.")

	var invalid_order: OrderDefinition = OrderDefinition.new()
	invalid_order.id = &"order_invalid_fixture"
	invalid_order.display_name_key = &"ORDER_RED_SAND_M0_NAME"
	terminal_ui.set_order_definition(invalid_order)
	_check(not terminal_ui.is_accept_enabled(), "Incomplete order data did not disable acceptance.")
	_check(
		terminal_ui.get_status_text() == "不可接取"
		and terminal_ui.get_feedback_text().contains("数据不完整"),
		"Incomplete order data did not report a visible reason."
	)
	terminal_ui.close_terminal()
	await process_frame
	_check(player.is_input_enabled(), "Station movement did not resume after closing the terminal.")

	station.queue_free()
	game_state.reset_runtime_state()
	await process_frame
	_finish_smoke(original_locale)


func _finish_dialogue(
	controller: StationTutorialController,
	dialogue_ui: DialogueUI,
	expected_dialogue_id: StringName
) -> void:
	var remaining_lines: int = 16
	while controller.get_active_dialogue_id() == expected_dialogue_id and remaining_lines > 0:
		dialogue_ui.quick_show_current_line()
		_check(dialogue_ui.continue_dialogue(), "Dialogue could not advance: %s" % expected_dialogue_id)
		remaining_lines -= 1
		await process_frame
	_check(remaining_lines > 0, "Dialogue exceeded its smoke-test line limit: %s" % expected_dialogue_id)


func _finish_smoke(original_locale: String) -> void:
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print("[order-terminal] PASS: data display, one-way state, Lao Pi feedback, and invalid-data guard.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[order-terminal] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
