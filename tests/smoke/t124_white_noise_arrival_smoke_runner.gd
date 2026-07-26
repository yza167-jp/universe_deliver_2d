extends SceneTree

const ARRIVAL_SCENE_PATH: String = (
	"res://scenes/arrival/white_noise_arrival.tscn"
)
const ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)
const FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/white_noise_flight.tscn"
)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _arrival: WhiteNoiseArrival
var _fixture_order: OrderDefinition
var _return_request_count: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	if not _prepare_order_result():
		await _finish()
		return
	var packed_scene: PackedScene = load(ARRIVAL_SCENE_PATH) as PackedScene
	_arrival = packed_scene.instantiate() as WhiteNoiseArrival
	_check(_arrival != null, "T-124 arrival scene did not instantiate.")
	if _arrival == null:
		await _finish()
		return
	_arrival.game_state_override = _game_state
	_arrival.return_requested.connect(_on_return_requested)
	root.add_child(_arrival)
	await _settle_frames(3)
	await physics_frame
	var player: StationPlayer = _arrival.get_station_player()
	var dialogue_ui: DialogueUI = _arrival.get_dialogue_ui()
	var modal: SceneModalCoordinator = _arrival.get_modal_coordinator()
	_check(player != null, "T-124 did not reuse StationPlayer.")
	_check(dialogue_ui != null, "T-124 did not resolve DialogueUI.")
	_check(modal != null, "T-124 did not resolve SceneModalCoordinator.")
	_check(
		_arrival.is_main_dialogue_active()
		and modal != null
		and modal.has_modal(WhiteNoiseArrival.MODAL_DIALOGUE)
		and player != null
		and not player.is_input_enabled(),
		"T-124 main delivery dialogue did not own the modal lock."
	)
	_check(
		dialogue_ui != null
		and dialogue_ui.get_displayed_speaker()
		== tr("CHARACTER_WHITE_NOISE_ARCHIVIST_ROLE")
		and dialogue_ui.get_full_text().contains("三号交付座"),
		"T-124 must use the provisional duty title and concrete delivery handoff."
	)
	_check(
		_arrival.get_landing_feedback_text()
		== tr("UI_WHITE_NOISE_ARRIVAL_LANDING_SMOOTH") % 93,
		"T-124 did not preserve landing and cargo feedback."
	)
	if dialogue_ui != null:
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
			"T-124 main dialogue did not stop at its local choice."
		)
		var choice_container: VBoxContainer = dialogue_ui.get_node(
			"%ChoiceContainer"
		) as VBoxContainer
		_check(
			choice_container != null
			and choice_container.get_child_count() == 3,
			"T-124 must expose three real choice buttons."
		)
		var custody_button: Button = (
			choice_container.get_child(2) as Button
			if choice_container != null
			and choice_container.get_child_count() == 3
			else null
		)
		_check(
			custody_button != null,
			"T-124 local-custody button is missing."
		)
		if custody_button != null:
			custody_button.pressed.emit()
		await _settle_frames(2)
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"T-124 dialogue did not rejoin after local custody."
		)
	await _settle_frames(2)
	await physics_frame
	_check_main_choice_result(player)
	if player != null:
		await _check_bounded_area(player)
		await _check_delivery_and_index(player)
		await _check_memory_owner(player, dialogue_ui)
		await _check_return_handoff(player)
	await _finish()


func _prepare_order_result() -> bool:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	if _game_state == null:
		_failures.append("T-124 smoke requires GameState.")
		return false
	_game_state.reset_runtime_state()
	var formal_order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	if formal_order == null or formal_order.destination_planet == null:
		_failures.append("T-124 smoke fixture order is missing.")
		return false
	_fixture_order = formal_order.duplicate(true) as OrderDefinition
	var fixture_planet: PlanetDefinition = (
		formal_order.destination_planet.duplicate(true) as PlanetDefinition
	)
	if _fixture_order == null or fixture_planet == null:
		_failures.append("T-124 smoke could not duplicate a playable fixture.")
		return false
	_fixture_order.content_readiness = (
		OrderDefinition.ContentReadiness.PLAYABLE
	)
	_fixture_order.required_chapter = &""
	_fixture_order.unlock_conditions.clear()
	_fixture_order.story_requirements.clear()
	fixture_planet.content_readiness = (
		PlanetDefinition.ContentReadiness.PLAYABLE
	)
	fixture_planet.flight_scene_path = FLIGHT_SCENE_PATH
	_fixture_order.destination_planet = fixture_planet
	if not _game_state.accept_order(_fixture_order):
		_failures.append(
			"T-124 smoke could not accept its isolated playable fixture."
		)
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	run_state.cargo_integrity = 93.0
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	return true


func _check_main_choice_result(player: StationPlayer) -> void:
	var contract: WhiteNoiseArrivalContract = _arrival.arrival_contract
	_check(
		_arrival.is_exploration_unlocked()
		and player != null
		and player.is_input_enabled()
		and not player.is_interaction_prompt_suppressed()
		and contract != null
		and contract.is_delivery_ready(_game_state)
		and _game_state.has_story_flag(contract.local_custody_flag)
		and contract.get_selected_choice_id(_game_state)
		== contract.local_custody_flag,
		"T-124 choice did not unlock one shared exploration path."
	)
	_check(
		_arrival.get_objective_text()
		== tr("UI_WHITE_NOISE_ARRIVAL_OBJECTIVE")
		and _arrival.get_interactables().size() == 5,
		"T-124 exploration did not expose its localized objective and five bounded interactions."
	)


func _check_bounded_area(player: StationPlayer) -> void:
	_check(
		is_equal_approx(_arrival.get_area_width_in_viewports(), 1.5)
		and _arrival.get_walkable_rect().size.x == 880.0
		and _arrival.get_walkable_rect().size.y == 125.0,
		"T-124 destination must remain a 1.5-screen local area."
	)
	var initial_camera: Rect2 = _arrival.get_camera_world_rect()
	_check(
		is_equal_approx(initial_camera.position.x, 0.0),
		"T-124 camera did not begin on the delivery side."
	)
	player.global_position = Vector2(900.0, 292.0)
	await physics_frame
	await physics_frame
	var far_camera: Rect2 = _arrival.get_camera_world_rect()
	_check(
		is_equal_approx(far_camera.position.x, 320.0),
		"T-124 camera did not reveal the second screen within bounds."
	)
	player.global_position = Vector2(48.0, 292.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_left")
	for _frame: int in 24:
		await physics_frame
	Input.action_release(&"move_left")
	_check(
		player.global_position.x >= 46.0,
		"T-124 player crossed the local area's left boundary."
	)


func _check_delivery_and_index(player: StationPlayer) -> void:
	var cradle: Interactable2D = _arrival.get_delivery_cradle()
	_check(cradle != null, "T-124 delivery cradle is missing.")
	if cradle != null:
		await _approach_and_interact(player, cradle)
		_check(
			_arrival.get_status_text().contains("只开放本次获准索引")
			and player.is_input_enabled()
			and player.is_interaction_prompt_suppressed(),
			"T-124 delivery observation must preserve movement while suppressing re-trigger."
		)
		_arrival.dismiss_status()
		await process_frame
	var terminal: Interactable2D = _arrival.get_index_terminal()
	_check(terminal != null, "T-124 index terminal is missing.")
	if terminal == null:
		return
	await _approach_and_interact(player, terminal)
	var contract: WhiteNoiseArrivalContract = _arrival.arrival_contract
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		_arrival.get_status_text().contains("共同保管")
		and _arrival.get_status_text().contains("早于公司")
		and _arrival.get_status_text().contains("创造者与用途仍未知")
		and _game_state.has_story_flag(
			contract.relay_record_inspected_flag
		)
		and run_state.optional_trigger_ids.count(
			WhiteNoiseArrival.INDEX_INSPECTION_TRIGGER_ID
		) == 1,
		"T-124 index must reflect the choice and bounded relay-history claim exactly once."
	)
	Input.action_press(&"move_left")
	for _frame: int in 3:
		await physics_frame
	Input.action_release(&"move_left")
	_check(
		player.velocity.x < 0.0,
		"T-124 index observation unexpectedly locked movement."
	)
	_arrival.dismiss_status()
	await process_frame


func _check_memory_owner(
	player: StationPlayer,
	dialogue_ui: DialogueUI
) -> void:
	var owner: Interactable2D = _arrival.get_memory_owner()
	_check(owner != null, "T-124 memory-owner interactable is missing.")
	if owner == null or dialogue_ui == null:
		return
	await _approach_and_interact(player, owner)
	_check(
		_arrival.is_memory_owner_dialogue_active()
		and not player.is_input_enabled()
		and dialogue_ui.get_displayed_speaker()
		== tr("CHARACTER_WHITE_NOISE_MEMORY_OWNER_ROLE")
		and dialogue_ui.get_full_text().contains("共同保管"),
		"T-124 optional character did not reflect the selected local-custody result."
	)
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"T-124 optional memory-owner dialogue did not finish."
	)
	await _settle_frames(2)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(
		_game_state.has_story_flag(
			_arrival.arrival_contract.memory_owner_dialogue_completion_flag
		)
		and run_state.optional_trigger_ids.has(
			WhiteNoiseArrival.MEMORY_OWNER_TALK_TRIGGER_ID
		)
		and _arrival.get_status_text().contains("同一返航流程")
		and player.is_input_enabled(),
		"T-124 optional follow-up did not persist without branching the route."
	)
	_arrival.dismiss_status()
	await process_frame


func _check_return_handoff(player: StationPlayer) -> void:
	var return_lift: Interactable2D = _arrival.get_return_lift()
	_check(return_lift != null, "T-124 return lift is missing.")
	if return_lift == null:
		return
	var credits_before: int = _game_state.credits
	await _approach_and_interact(player, return_lift)
	_check(
		_return_request_count == 1
		and _arrival.get_status_text().contains("T-125")
		and _game_state.get_order_status(_fixture_order.id)
		== GameStateModel.OrderStatus.ACCEPTED
		and not _game_state.has_completed_order(_fixture_order.id)
		and not _game_state.has_applied_order_reward(_fixture_order.id)
		and _game_state.credits == credits_before,
		"T-124 return lift must emit a handoff without settling or granting rewards."
	)
	var formal_order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	_check(
		formal_order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY
		and formal_order.destination_planet.content_readiness
		== PlanetDefinition.ContentReadiness.REGISTERED_ONLY,
		"T-124 smoke must leave the formal order and planet registered-only."
	)


func _approach_and_interact(
	player: StationPlayer,
	target: Interactable2D
) -> void:
	player.global_position = target.global_position + Vector2(0.0, 48.0)
	player.velocity = Vector2.ZERO
	player.set_facing_direction(Vector2.UP)
	await physics_frame
	await physics_frame
	_check(
		player.refresh_interaction_target() == target,
		"T-124 approach selected the wrong target for '%s'."
		% target.interaction_id
	)
	_check(
		player.try_interact(),
		"T-124 interaction '%s' did not activate."
		% target.interaction_id
	)
	await process_frame


func _on_return_requested() -> void:
	_return_request_count += 1


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _finish() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	if is_instance_valid(_arrival):
		_arrival.queue_free()
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
	await process_frame
	if _failures.is_empty():
		print(
			"[t124-white-noise-arrival] PASS: bounded archive, real choice "
			+ "buttons, role-title NPCs, relay fragment, optional follow-up, "
			+ "modal recovery, and non-settling return handoff."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t124-white-noise-arrival] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
