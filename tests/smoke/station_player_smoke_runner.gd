extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"

var _failures: PackedStringArray = []
var _interaction_signal_received: bool = false


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var game_state: GameStateModel = root.get_node_or_null("GameState") as GameStateModel
	if game_state != null:
		game_state.reset_runtime_state()
		game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame
	await physics_frame

	var player: StationPlayer = station.get_station_player()
	_check(player != null, "Station player is missing from the live scene tree.")
	if player != null:
		await _check_live_movement(player)
		await _check_live_interaction(station, player)
		await _check_single_press_dialogue_modal(station, player)
		await process_frame

	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	station.queue_free()
	if game_state != null:
		game_state.reset_runtime_state()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print("[station-player] PASS: movement, animation, prompt, priority target, and interaction signal.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[station-player] %s" % failure)
	quit(1)


func _check_live_movement(player: StationPlayer) -> void:
	var start_position: Vector2 = player.position
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	for _frame: int in 12:
		await physics_frame
	Input.action_release(&"move_up")
	Input.action_release(&"move_right")
	_check(player.position.x > start_position.x, "Diagonal input did not move the player right.")
	_check(player.position.y < start_position.y, "Diagonal input did not move the player up.")
	_check(
		player.velocity.length() <= player.move_speed + 0.1,
		"Live diagonal movement exceeded the configured speed."
	)
	_check(
		String(player.get_current_animation_name()).begins_with("walk_"),
		"Moving player did not enter a walk animation."
	)
	for _frame: int in 10:
		await physics_frame
	_check(player.velocity.length() < 0.1, "Player did not decelerate to rest after input release.")
	_check(
		String(player.get_current_animation_name()).begins_with("idle_"),
		"Stopped player did not return to an idle animation."
	)


func _check_live_interaction(station: StationHub, player: StationPlayer) -> void:
	var approach: Marker2D = station.get_feature_approach_anchor(&"order_terminal")
	var feature: Marker2D = station.get_feature_anchor(&"order_terminal")
	_check(approach != null and feature != null, "Order terminal interaction anchors are missing.")
	if approach == null or feature == null:
		return
	player.position = approach.position
	player.velocity = Vector2.ZERO
	player.set_facing_direction(feature.position - approach.position)
	await physics_frame
	await physics_frame
	var selected: Interactable2D = player.refresh_interaction_target()
	_check(selected != null, "Approaching the order terminal did not select an interaction target.")
	if selected == null:
		return
	_check(
		selected.interaction_id == &"order_terminal",
		"Approaching the order terminal selected the wrong target: %s" % selected.interaction_id
	)
	_check(player.is_interaction_prompt_visible(), "Interaction prompt is not visible near a target.")
	_check(
		player.get_interaction_prompt_text().contains("查看订单终端"),
		"Interaction prompt did not localize to the selected target."
	)
	selected.interaction_triggered.connect(_on_interaction_triggered)
	_check(player.try_interact(), "Selected interaction could not be triggered.")
	_check(_interaction_signal_received, "Interactable did not emit its interaction signal.")
	var coordinator: StationModalCoordinator = station.get_modal_coordinator()
	var terminal_ui: OrderTerminalUI = station.get_order_terminal_ui()
	var objective: Control = station.get_node(
		"TutorialUILayer/TutorialObjective"
	) as Control
	_check(
		coordinator != null and coordinator.is_modal_active(),
		"Opening the order terminal did not acquire the shared modal lock."
	)
	if coordinator != null:
		_check(
			not coordinator.begin_modal(StationOrderTerminalController.MODAL_ORDER_TERMINAL)
			and coordinator.get_active_modal_count() == 1,
			"Repeated modal open created a duplicate world lock."
		)
	_check(not player.is_input_enabled(), "World input remained active behind the order terminal.")
	_check(
		not player.is_interaction_prompt_visible(),
		"Interaction prompt remained visible over the order terminal."
	)
	_check(objective != null and not objective.visible, "Objective HUD remained visible over the order terminal.")
	if terminal_ui != null:
		terminal_ui.close_terminal()
	await process_frame
	await process_frame
	_check(player.is_input_enabled(), "Closing the order terminal did not restore world input.")
	_check(
		player.is_interaction_prompt_visible(),
		"Closing the order terminal did not restore the in-range interaction prompt."
	)
	_check(objective != null and objective.visible, "Closing the order terminal did not restore the objective HUD.")


func _check_single_press_dialogue_modal(station: StationHub, player: StationPlayer) -> void:
	var lao_pi: LaoPiStation = station.get_lao_pi()
	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var coordinator: StationModalCoordinator = station.get_modal_coordinator()
	var objective: Control = station.get_node(
		"TutorialUILayer/TutorialObjective"
	) as Control
	_check(lao_pi != null and tutorial != null and coordinator != null, "Dialogue modal fixture is incomplete.")
	if lao_pi == null or tutorial == null or coordinator == null:
		return
	player.position = lao_pi.position + Vector2(0.0, 44.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(lao_pi.position - player.position)
	await physics_frame
	await physics_frame
	var selected: Interactable2D = player.refresh_interaction_target()
	_check(selected == lao_pi, "Lao Pi was not selected for the single-press dialogue check.")
	if selected != lao_pi:
		return

	Input.action_press(&"interact")
	_check(player.try_interact(), "One E press did not open Lao Pi's daily dialogue.")
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	_check(
		tutorial.get_active_dialogue_id() == &"dialogue_lao_pi_station_daily",
		"The interaction press did not select Lao Pi's daily dialogue."
	)
	_check(dialogue_ui != null, "Daily dialogue UI is unavailable.")
	if dialogue_ui == null:
		Input.action_release(&"interact")
		return
	var expected_first_line: String = tr("DIALOGUE_LAO_PI_DAILY_01")
	_check(
		dialogue_ui.get_full_text() == expected_first_line,
		"The E press that opened dialogue also advanced past its first line."
	)
	await physics_frame
	Input.action_release(&"interact")
	_check(
		dialogue_ui.get_full_text() == expected_first_line,
		"Holding the opening E press advanced the dialogue."
	)
	_check(coordinator.is_modal_active(), "Dialogue did not keep the shared modal lock.")
	_check(not player.is_input_enabled(), "World input remained active during dialogue.")
	_check(not player.is_interaction_prompt_visible(), "Interaction prompt remained visible over dialogue.")
	_check(objective != null and not objective.visible, "Objective HUD remained visible over dialogue.")

	var remaining_lines: int = 4
	while not tutorial.get_active_dialogue_id().is_empty() and remaining_lines > 0:
		dialogue_ui.quick_show_current_line()
		dialogue_ui.continue_dialogue()
		remaining_lines -= 1
		await process_frame
	_check(remaining_lines > 0, "Daily dialogue did not finish within its authored line count.")
	_check(not coordinator.is_modal_active(), "Dialogue modal lock remained after closing.")
	_check(player.is_input_enabled(), "Dialogue close did not restore world input.")
	_check(
		player.is_interaction_prompt_visible(),
		"Dialogue close did not restore Lao Pi's in-range interaction prompt."
	)
	_check(objective != null and objective.visible, "Dialogue close did not restore the objective HUD.")


func _on_interaction_triggered(_actor: Node) -> void:
	_interaction_signal_received = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
