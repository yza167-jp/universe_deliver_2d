extends SceneTree

const ARRIVAL_SCENE_PATH: String = "res://scenes/arrival/red_sand_arrival.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const LASER_MODULE_PATH: String = "res://data/modules/asteroid_laser.tres"

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _arrival: RedSandArrival


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	if not _prepare_order_result():
		await _finish(original_locale)
		return

	var packed_scene: PackedScene = load(ARRIVAL_SCENE_PATH) as PackedScene
	_arrival = packed_scene.instantiate() as RedSandArrival
	_check(_arrival != null, "Red Sand arrival scene did not instantiate.")
	if _arrival == null:
		await _finish(original_locale)
		return
	root.add_child(_arrival)
	await process_frame
	await process_frame
	await physics_frame

	var player: StationPlayer = _arrival.get_station_player()
	var dialogue_ui: DialogueUI = _arrival.get_dialogue_ui()
	_check(player != null, "Arrival did not reuse the station player scene.")
	_check(dialogue_ui != null, "Arrival did not resolve a dialogue UI.")
	_check(_arrival.is_main_dialogue_active(), "Arrival did not open its main dialogue first.")
	_check(
		player != null and not player.is_input_enabled(),
		"World input remained active during the main arrival dialogue."
	)
	_check(
		player != null and player.is_interaction_prompt_suppressed(),
		"Interaction prompt was not suppressed during the main arrival dialogue."
	)
	_check(
		dialogue_ui != null
		and dialogue_ui.get_full_text() == tr("DIALOGUE_RED_SAND_ARRIVAL_GREETING"),
		"Arrival dialogue did not start on its localized greeting."
	)
	_check(
		_arrival.get_landing_feedback_text()
		== tr("UI_RED_SAND_ARRIVAL_LANDING_SMOOTH") % 92,
		"Arrival did not preserve the landing and cargo feedback."
	)

	if dialogue_ui != null:
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"Main arrival dialogue could not be safely skipped to completion."
		)
	await process_frame
	await physics_frame
	_check(_arrival.is_exploration_unlocked(), "Main dialogue did not unlock exploration.")
	_check(player != null and player.is_input_enabled(), "Exploration did not restore world input.")
	_check(
		player != null and not player.is_interaction_prompt_suppressed(),
		"Exploration did not restore interaction prompts."
	)
	_check(
		_arrival.get_objective_text() == tr("UI_RED_SAND_ARRIVAL_OBJECTIVE_EXPLORE"),
		"Arrival exploration objective is missing or not localized."
	)
	_check(_arrival.get_return_beacon() != null, "Arrival return beacon is missing.")
	_check(
		_arrival.get_interactables().size() == 3,
		"Arrival must expose the NPC, record terminal, and return beacon only."
	)
	_check(
		is_equal_approx(_arrival.get_area_width_in_viewports(), 1.5),
		"Arrival yard must remain a clearly bounded 1.5-screen area."
	)
	_check(
		_arrival.get_walkable_rect().size.x < 900.0
		and _arrival.get_walkable_rect().size.y < 140.0,
		"Arrival walkable bounds expanded beyond the small destination contract."
	)

	if player != null:
		await _check_camera_and_boundaries(player)
		await _check_optional_dialogue(player, dialogue_ui)
		await _check_record_terminal(player)

	await _finish(original_locale)


func _prepare_order_result() -> bool:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	if _game_state == null:
		_failures.append("GameState autoload is unavailable.")
		return false
	_game_state.reset_runtime_state()
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var laser_module: ShipModuleDefinition = load(
		LASER_MODULE_PATH
	) as ShipModuleDefinition
	if order == null or laser_module == null:
		_failures.append("Arrival smoke fixture order or laser module is missing.")
		return false
	if not _game_state.accept_order(order) or not _game_state.equip_ship_module(laser_module):
		_failures.append("Arrival smoke fixture could not accept the order or equip the laser.")
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	if run_state == null:
		_failures.append("Arrival smoke fixture has no active order run state.")
		return false
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)
	return true


func _check_camera_and_boundaries(player: StationPlayer) -> void:
	var initial_camera_rect: Rect2 = _arrival.get_camera_world_rect()
	_check(
		is_equal_approx(initial_camera_rect.position.x, 0.0),
		"Arrival camera did not begin on the landing-pad half of the yard."
	)
	player.global_position = Vector2(900.0, 292.0)
	await physics_frame
	await physics_frame
	var far_camera_rect: Rect2 = _arrival.get_camera_world_rect()
	_check(
		is_equal_approx(far_camera_rect.position.x, 320.0),
		"Arrival camera did not reveal the second half without exceeding world bounds."
	)
	player.global_position = Vector2(48.0, 292.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_left")
	for _frame: int in 24:
		await physics_frame
	Input.action_release(&"move_left")
	_check(
		player.global_position.x >= 46.0,
		"Arrival player crossed the visible left boundary: %.2f" % player.global_position.x
	)


func _check_optional_dialogue(player: StationPlayer, dialogue_ui: DialogueUI) -> void:
	var technician: Interactable2D = _arrival.get_technician()
	_check(technician != null, "Arrival technician interactable is missing.")
	if technician == null or dialogue_ui == null:
		return
	player.global_position = technician.global_position + Vector2(0.0, 48.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(Vector2.UP)
	await physics_frame
	await physics_frame
	_check(
		player.refresh_interaction_target() == technician,
		"Approaching the technician selected the wrong interaction target."
	)
	_check(player.try_interact(), "Technician optional dialogue did not start.")
	_check(_arrival.is_optional_dialogue_active(), "Technician interaction opened no dialogue.")
	_check(not player.is_input_enabled(), "World input remained active behind optional dialogue.")
	_check(
		dialogue_ui.skip_dialogue_sequence() == DialogueRuntime.SequenceSkipResult.FINISHED,
		"Optional technician dialogue could not finish safely."
	)
	await process_frame
	await physics_frame
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		_game_state.has_story_flag(RedSandArrival.STORY_OPTIONAL_DIALOGUE_COMPLETED)
		and run_state.optional_trigger_ids.has(RedSandArrival.OPTIONAL_TALK_TRIGGER_ID),
		"Optional technician dialogue did not record its stable result."
	)
	_check(player.is_input_enabled(), "Optional dialogue did not restore exploration input.")


func _check_record_terminal(player: StationPlayer) -> void:
	var terminal: Interactable2D = _arrival.get_record_terminal()
	_check(terminal != null, "Arrival record terminal interactable is missing.")
	if terminal == null:
		return
	player.global_position = terminal.global_position + Vector2(0.0, 52.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(Vector2.UP)
	await physics_frame
	await physics_frame
	_check(
		player.refresh_interaction_target() == terminal,
		"Approaching the record terminal selected the wrong interaction target."
	)
	_check(player.try_interact(), "Order record terminal did not respond to interaction.")
	_check(
		_arrival.get_status_text() == tr("UI_RED_SAND_ARRIVAL_RECORD_DETAIL")
		and _game_state.has_story_flag(RedSandArrival.STORY_RECORD_INSPECTED),
		"Record terminal did not expose the company-versus-settlement discrepancy."
	)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		run_state.optional_trigger_ids.count(RedSandArrival.RECORD_INSPECTION_TRIGGER_ID) == 1,
		"Record inspection must be retained exactly once in the order run result."
	)
	player.try_interact()
	_check(
		run_state.optional_trigger_ids.count(RedSandArrival.RECORD_INSPECTION_TRIGGER_ID) == 1,
		"Repeated record inspection duplicated its order-run trigger."
	)


func _finish(original_locale: String) -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	if is_instance_valid(_arrival):
		_arrival.queue_free()
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print(
			"[red-sand-arrival] PASS: main dialogue, result branches, bounded yard, "
			+ "movement, NPC, record inspection, and modal recovery."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[red-sand-arrival] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
