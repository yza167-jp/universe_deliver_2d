extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const REVISIT_CODEX_ID: StringName = (
	&"codex_cargo_relay_pattern_shielding_materials"
)


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var contract: RedSandRevisitContract = load(
		CONTRACT_PATH
	) as RedSandRevisitContract
	expect_true(registry != null, "T-112 requires the M1 registry.", failures)
	expect_true(contract != null, "T-112 requires the revisit contract.", failures)
	if registry == null or contract == null:
		return failures
	_test_playable_contract(registry, contract, failures)
	_test_upload_settlement(registry, contract, failures)
	_test_local_settlement_and_save(registry, contract, failures)
	_test_invalid_auto_equip_is_atomic(registry, contract, failures)
	return failures


func _test_playable_contract(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = contract.order
	expect_true(
		contract.validate(registry).is_empty()
		and order != null
		and order.is_playable()
		and is_equal_approx(order.route_distance, contract.get_route_distance())
		and is_equal_approx(contract.route_entry_distance, 26000.0)
		and is_equal_approx(contract.route_end_distance, 38000.0)
		and is_equal_approx(contract.get_route_distance(), 12000.0)
		and is_equal_approx(contract.nominal_route_seconds, 48.0)
		and contract.get_route_segment_count() == 3
		and contract.arrival_dialogue != null
		and contract.arrival_dialogue.lines.size() >= 15
		and contract.optional_dialogue != null,
		"The formal revisit must expose the complete short-route and dialogue contract.",
		failures
	)
	for source_segment_index: int in [5, 6, 7]:
		expect_true(
			not contract.get_stage_display_name_key(
				source_segment_index
			).is_empty()
			and not contract.get_stage_instruction_key(
				source_segment_index
			).is_empty(),
			"Every reused route segment needs revisit-specific localized guidance.",
			failures
		)


func _test_upload_settlement(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = _create_accepted_state(contract)
	state.set_story_flag(contract.upload_full_record_flag)
	state.set_story_flag(contract.completion_dialogue_flag)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		state.get_active_order_run_state()
	)
	var module: ShipModuleDefinition = registry.find_module(
		contract.auto_equip_module_id
	)
	expect_true(
		contract.is_delivery_ready(state)
		and state.settle_current_order(
			contract.order,
			settlement,
			&"",
			[],
			contract.get_choice_relation_rewards(state),
			[module]
		),
		"The upload branch must commit through the unified settlement.",
		failures
	)
	var codex_entry: CodexCatalogEntry = _find_codex_entry(
		CodexCatalogModel.build_catalog(registry, state),
		REVISIT_CODEX_ID
	)
	expect_true(
		state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 1
		and state.has_completed_order(contract.order.id)
		and state.has_ship_module(module.id)
		and state.is_ship_module_equipped(module.id)
		and state.has_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
		and state.main_story_chapter == M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and state.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== contract.completed_state_id
		and codex_entry != null
		and codex_entry.description_key
		== CodexCatalogModel.RED_SAND_UPLOAD_DESCRIPTION_KEY,
		"The upload branch must apply all rewards and its specific codex record once.",
		failures
	)
	state.free()


func _test_local_settlement_and_save(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = _create_accepted_state(contract)
	state.set_story_flag(contract.keep_local_record_flag)
	state.set_story_flag(contract.completion_dialogue_flag)
	var module: ShipModuleDefinition = registry.find_module(
		contract.auto_equip_module_id
	)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		state.get_active_order_run_state()
	)
	expect_true(
		state.settle_current_order(
			contract.order,
			settlement,
			&"",
			[],
			contract.get_choice_relation_rewards(state),
			[module]
		),
		"The local-record branch must settle.",
		failures
	)
	var progress: GameProgressData = GameProgressData.capture(state)
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(
		progress.to_dictionary()
	)
	var restored: GameStateModel = GameStateModel.new()
	var codex_entry: CodexCatalogEntry = _find_codex_entry(
		CodexCatalogModel.build_catalog(registry, state),
		REVISIT_CODEX_ID
	)
	expect_true(
		state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 2
		and codex_entry != null
		and codex_entry.description_key
		== CodexCatalogModel.RED_SAND_LOCAL_DESCRIPTION_KEY
		and progress.is_valid()
		and restored_progress.is_valid()
		and restored_progress.apply_to(restored)
		and restored.has_story_flag(contract.keep_local_record_flag)
		and not restored.has_story_flag(contract.upload_full_record_flag)
		and restored.has_completed_order(contract.order.id)
		and restored.is_ship_module_equipped(module.id)
		and restored.has_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
		and restored.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== contract.completed_state_id,
		"The local choice, relation bonus, module install, and station change must survive save restore.",
		failures
	)
	state.free()
	restored.free()


func _test_invalid_auto_equip_is_atomic(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = _create_accepted_state(contract)
	state.set_story_flag(contract.upload_full_record_flag)
	state.set_story_flag(contract.completion_dialogue_flag)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		state.get_active_order_run_state()
	)
	var invalid_module: ShipModuleDefinition = registry.find_module(
		ShipLoadoutRules.DEFAULT_DEFENSE_MODULE_ID
	)
	var before: String = _progress_signature(state)
	expect_true(
		not state.settle_current_order(
			contract.order,
			settlement,
			&"",
			[],
			{},
			[invalid_module]
		)
		and state.last_order_error == GameStateModel.ORDER_ERROR_INVALID_REWARD
		and _progress_signature(state) == before,
		"An invalid auto-equipped reward must reject before any settlement mutation.",
		failures
	)
	state.free()


func _create_accepted_state(
	contract: RedSandRevisitContract
) -> GameStateModel:
	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	state.completed_order_ids[GameDataValidator.M1_ACTUAL_M0_ORDER_ID] = true
	state.order_states[GameDataValidator.M1_ACTUAL_M0_ORDER_ID] = (
		GameStateModel.OrderStatus.COMPLETED
	)
	state.set_story_flag(&"story_red_sand_order_completed")
	state.accept_order(contract.order)
	state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		contract.accepted_state_id
	)
	var run_state: OrderRunState = state.get_active_order_run_state()
	run_state.cargo_integrity = 100.0
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)
	return state


func _find_codex_entry(
	entries: Array[CodexCatalogEntry],
	entry_id: StringName
) -> CodexCatalogEntry:
	for entry: CodexCatalogEntry in entries:
		if entry.id == entry_id:
			return entry
	return null


func _progress_signature(state: GameStateModel) -> String:
	var progress: GameProgressData = GameProgressData.capture(state)
	if progress == null or not progress.is_valid():
		return "INVALID"
	progress.last_saved_at_unix = 0
	progress.build_version = "t112_fixture"
	return JSON.stringify(progress.to_dictionary())
