extends SceneTree

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _router: SceneRouterService
var _scene_container: Control


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	if not _prepare_fixture():
		await _finish(original_locale)
		return

	_router = SceneRouterService.new()
	_scene_container = Control.new()
	root.add_child(_scene_container)
	_check(_router.register_scene_container(_scene_container), "Settlement router did not register.")
	_check(_router.start(), "Settlement router did not start.")
	# Let the main menu finish its deferred focus setup before the debug handoff.
	await process_frame
	_check(
		_router.debug_switch_to_stage(SceneRouterService.Stage.ARRIVAL),
		"Settlement smoke could not enter ARRIVAL."
	)
	var arrival: RedSandArrival = _scene_container.get_child(0) as RedSandArrival
	_check(arrival != null, "Settlement smoke did not instantiate Red Sand arrival.")
	if arrival == null:
		await _finish(original_locale)
		return
	arrival.scene_router_override = _router
	await process_frame
	await process_frame
	var dialogue_ui: DialogueUI = arrival.get_dialogue_ui()
	_check(dialogue_ui != null, "Arrival dialogue UI is unavailable in settlement flow.")
	if dialogue_ui != null:
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"Arrival main dialogue could not complete before settlement."
		)
	await process_frame
	var beacon: Interactable2D = arrival.get_return_beacon()
	_check(beacon != null, "Arrival return beacon is unavailable.")
	if beacon != null:
		_check(
			beacon.interact(arrival.get_station_player()),
			"Return beacon did not request order settlement."
		)
	await process_frame

	var results: OrderResults = _scene_container.get_child(0) as OrderResults
	_check(results != null, "Return beacon did not enter the Results scene.")
	if results == null:
		await _finish(original_locale)
		return
	results.scene_router_override = _router
	var settlement: OrderSettlementResult = results.get_settlement_result()
	_check(results.is_settlement_committed(), "Results did not commit the active order.")
	_check(
		settlement != null
		and settlement.base_reward == 100
		and settlement.cargo_adjustment == -3
		and settlement.total_reward == 97,
		"Results did not show the expected 100 - 3 = 97 credit settlement."
	)
	_check(
		_game_state.get_credits() == 97
		and _game_state.has_completed_order(&"order_red_sand_m0"),
		"Settlement did not award credits and complete the main order."
	)
	_check(
		_game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
		and _game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING),
		"Settlement did not unlock the station display and return dialogue."
	)
	_check(
		results.get_credit_balance_text().contains("97")
		and results.get_station_change_text().contains("中继铭牌")
		and results.get_next_step_text().contains("返回快递站")
		and results.get_next_step_text().contains("老皮"),
		"Results UI did not expose credits, station change, and the next player step."
	)
	_check(results.return_to_station(), "Results could not return to the station.")
	await process_frame
	await process_frame
	await process_frame

	var station: StationHub = _scene_container.get_child(0) as StationHub
	_check(station != null, "Results did not return to the Station scene.")
	if station != null:
		var return_state: StationReturnStateController = station.get_return_state_controller()
		var tutorial: StationTutorialController = station.get_tutorial_controller()
		_check(return_state != null, "Station return-state controller is missing.")
		_check(
			return_state != null
			and return_state.is_first_delivery_display_visible()
			and return_state.get_credit_text().contains("97"),
			"Returned station did not show its first-delivery display and credits."
		)
		var memorabilia_label: Label = station.get_node_or_null(
			"FeatureLabels/MemorabiliaLabel"
		) as Label
		var departure: StationDepartureController = station.get_departure_controller()
		_check(
			memorabilia_label != null and memorabilia_label.text.contains("旧中继铭牌"),
			"Returned station still described the populated memorabilia wall as empty."
		)
		_check(
			tutorial != null
			and tutorial.get_active_dialogue_id()
			== &"dialogue_lao_pi_first_delivery_return",
			"Lao Pi did not acknowledge the first delivery on return."
		)
		if tutorial != null and tutorial.get_dialogue_ui() != null:
			_check(
				tutorial.get_dialogue_ui().skip_dialogue_sequence()
				== DialogueRuntime.SequenceSkipResult.FINISHED,
				"Lao Pi return dialogue could not complete safely."
			)
		await process_frame
		_check(
			not _game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_PENDING)
			and _game_state.has_story_flag(M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED),
			"Lao Pi return dialogue did not retain its completion state."
		)
		_check(
			departure != null
			and departure.get_flow_state()
			== StationDepartureController.FlowState.FIRST_DELIVERY_COMPLETE
			and departure.get_objective_text().contains("首单已归档"),
			"Returned station incorrectly asked the player to accept the completed order again."
		)
		if return_state != null:
			var player: StationPlayer = station.get_station_player()
			var coordinator: StationModalCoordinator = station.get_modal_coordinator()
			_check(
				return_state.get_memorabilia_wall().interact(player),
				"The upgraded memorabilia wall did not respond to interaction."
			)
			_check(
				return_state.get_status_text().contains("旧中继铭牌"),
				"The upgraded wall did not expose its localized relay-plaque detail."
			)
			_check(
				coordinator != null
				and coordinator.has_modal(
					StationReturnStateController.MODAL_MEMORABILIA_OBSERVATION
				)
				and not player.is_input_enabled()
				and player.is_interaction_prompt_suppressed()
				and not player.is_interaction_prompt_visible(),
				"Memorabilia browser did not lock world input and hide interaction."
			)
			_check(
				return_state.get_souvenir_wall_ui().visible
				and return_state.get_souvenir_wall_ui().get_slot_texts().size()
				== 4,
				"Memorabilia browser did not expose its data-driven slots."
			)
			return_state.get_souvenir_wall_ui().close_wall()
			await process_frame
			_check(
				not return_state.is_status_visible()
				and player.is_input_enabled()
				and not player.is_interaction_prompt_suppressed(),
				"Closing the memorabilia browser did not restore station input."
			)

	await _finish(original_locale)


func _prepare_fixture() -> bool:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	if _game_state == null or order == null:
		_failures.append("Settlement smoke fixture is missing GameState or order data.")
		return false
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	if not _game_state.accept_order(order):
		_failures.append("Settlement smoke fixture could not accept the Red Sand order.")
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	if run_state == null:
		_failures.append("Settlement smoke fixture has no active run result.")
		return false
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)
	return true


func _finish(original_locale: String) -> void:
	if _router != null and _scene_container != null:
		_router.unregister_scene_container(_scene_container)
	if is_instance_valid(_scene_container):
		_scene_container.queue_free()
	if is_instance_valid(_router):
		_router.free()
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print(
			"[red-sand-settlement] PASS: arrival return, reward, credits, station "
			+ "display, Lao Pi response, and memorabilia interaction."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[red-sand-settlement] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
