extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"

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

	var station: StationHub = _instantiate_station()
	await process_frame
	await process_frame
	var controller: StationTutorialController = station.get_tutorial_controller()
	var player: StationPlayer = station.get_station_player()
	var lao_pi: LaoPiStation = station.get_lao_pi()
	_check(controller != null, "Station tutorial controller is missing.")
	_check(player != null, "Station player is missing.")
	_check(lao_pi != null, "Lao Pi is missing from the station.")
	if controller == null or player == null or lao_pi == null:
		station.queue_free()
		await process_frame
		game_state.reset_runtime_state()
		_finish_smoke(original_locale)
		return

	var dialogue_ui: DialogueUI = controller.get_dialogue_ui()
	_check(dialogue_ui != null, "Station tutorial dialogue UI is missing.")
	_check(
		controller.get_active_dialogue_id() == &"dialogue_lao_pi_tutorial_intro",
		"First station visit must open Lao Pi's introduction."
	)
	_check(not player.is_input_enabled(), "World input must pause during dialogue.")
	_check(lao_pi.is_talking(), "Lao Pi must animate while speaking.")
	if dialogue_ui != null:
		await _finish_dialogue(
			controller,
			dialogue_ui,
			&"dialogue_lao_pi_tutorial_intro"
		)
	_check(
		controller.get_stage() == StationTutorialController.Stage.WAIT_FOR_MOVE,
		"Introduction must advance to movement."
	)
	_check(
		controller.get_objective_text().contains("在大厅走动"),
		"Movement objective must be visible and localized."
	)

	var order_terminal: Interactable2D = station.get_node(
		"Interactables/OrderTerminal"
	) as Interactable2D
	_check(order_terminal.interact(player), "Order terminal must accept an early interaction.")
	_check(
		controller.get_stage() == StationTutorialController.Stage.WAIT_FOR_MOVE,
		"Early terminal interaction must not skip movement."
	)
	_check(
		controller.get_progress().has_inspected_order_terminal(),
		"Early terminal interaction must be retained."
	)

	player.position += Vector2(48.0, 0.0)
	await process_frame
	await process_frame
	_check(
		controller.get_active_dialogue_id() == &"dialogue_lao_pi_tutorial_move_ack",
		"Required movement must trigger Lao Pi's acknowledgement."
	)
	_check(
		lao_pi.is_moving_to_scripted_position(),
		"Lao Pi must begin his authored tutorial walk."
	)
	_check(
		String(lao_pi.get_current_animation_name()).begins_with("walk_"),
		"Lao Pi tutorial movement must use a walk animation."
	)
	if dialogue_ui != null:
		await _finish_dialogue(
			controller,
			dialogue_ui,
			&"dialogue_lao_pi_tutorial_move_ack"
		)
	_check(
		controller.get_stage() == StationTutorialController.Stage.WAIT_FOR_LAO_PI,
		"Movement acknowledgement must ask for Lao Pi interaction."
	)

	_check(lao_pi.interact(player), "Lao Pi must accept tutorial interaction.")
	_check(
		controller.get_active_dialogue_id() == &"dialogue_lao_pi_tutorial_interact_ack",
		"Lao Pi interaction must start its acknowledgement."
	)
	if dialogue_ui != null:
		await _finish_dialogue(
			controller,
			dialogue_ui,
			&"dialogue_lao_pi_tutorial_interact_ack"
		)
	await process_frame
	await process_frame
	_check(
		controller.get_active_dialogue_id() == &"dialogue_lao_pi_tutorial_complete",
		"Stored terminal interaction must safely chain to completion."
	)
	if dialogue_ui != null:
		await _finish_dialogue(
			controller,
			dialogue_ui,
			&"dialogue_lao_pi_tutorial_complete"
		)
	await process_frame
	_check(game_state.has_story_flag(StationTutorialController.COMPLETION_FLAG), "Tutorial completion flag was not saved.")
	_check(controller.is_tutorial_complete(), "Tutorial did not reach its complete stage.")
	_check(player.is_input_enabled(), "World input did not resume after tutorial completion.")
	var objective: Control = station.get_node(
		"TutorialUILayer/TutorialObjective"
	) as Control
	_check(not objective.visible, "Tutorial objective must hide after completion.")

	station.queue_free()
	await process_frame
	await process_frame

	var restored_station: StationHub = _instantiate_station()
	await process_frame
	await process_frame
	var restored_controller: StationTutorialController = restored_station.get_tutorial_controller()
	var restored_lao_pi: LaoPiStation = restored_station.get_lao_pi()
	var restored_player: StationPlayer = restored_station.get_station_player()
	_check(
		restored_controller.get_stage() == StationTutorialController.Stage.COMPLETE,
		"Completed tutorial must not replay on the next station load."
	)
	_check(
		restored_controller.get_active_dialogue_id().is_empty(),
		"Completed tutorial must load without forcing dialogue."
	)
	_check(restored_lao_pi.interact(restored_player), "Lao Pi daily interaction must remain available.")
	_check(
		restored_controller.get_active_dialogue_id() == &"dialogue_lao_pi_station_daily",
		"Post-tutorial Lao Pi interaction must start repeatable daily dialogue."
	)
	var restored_dialogue_ui: DialogueUI = restored_controller.get_dialogue_ui()
	if restored_dialogue_ui != null:
		await _finish_dialogue(
			restored_controller,
			restored_dialogue_ui,
			&"dialogue_lao_pi_station_daily"
		)
	_check(
		restored_controller.get_stage() == StationTutorialController.Stage.COMPLETE,
		"Daily dialogue must return to the completed station state."
	)

	restored_station.queue_free()
	game_state.reset_runtime_state()
	await process_frame
	_finish_smoke(original_locale)


func _instantiate_station() -> StationHub:
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	return station


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
		print("[station-tutorial] PASS: recovery, dialogue, completion restore, and daily interaction.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[station-tutorial] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
