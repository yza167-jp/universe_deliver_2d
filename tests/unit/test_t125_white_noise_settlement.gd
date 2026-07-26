extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var contract: WhiteNoiseSettlementContract = load(
		CONTRACT_PATH
	) as WhiteNoiseSettlementContract
	expect_true(registry != null, "T-125 registry must load.", failures)
	expect_true(contract != null, "T-125 settlement contract must load.", failures)
	if registry == null or contract == null:
		return failures
	_test_contract(registry, contract, failures)
	_test_choice_settlements(registry, contract, failures)
	_test_invalid_modifiers_are_atomic(contract, failures)
	return failures


func _test_contract(
	registry: GameDataRegistry,
	contract: WhiteNoiseSettlementContract,
	failures: Array[String]
) -> void:
	var errors: PackedStringArray = contract.validate(registry)
	expect_true(
		errors.is_empty(),
		"T-125 settlement contract errors: %s." % "; ".join(errors),
		failures
	)
	expect_true(
		contract.order != null
		and contract.order.is_playable()
		and contract.order.destination_planet != null
		and contract.order.destination_planet.is_playable()
		and contract.order.destination_planet.flight_scene_path
		== contract.flight_scene_path
		and contract.order.route_distance == 34000.0
		and contract.order.chapter_reward
		== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
		and contract.order.planet_unlock_rewards
		== [M1ProgressRules.PLANET_CANOPY_WORLD]
		and contract.order.revisit_state_rewards.get(
			M1ProgressRules.PLANET_WHITE_NOISE,
			&""
		)
		== M1ProgressRules.REVISIT_WHITE_NOISE_MEMORY_FOLLOWUP_AVAILABLE,
		"T-125 formal order must expose the exact route and progression handoff.",
		failures
	)
	var localization: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	for key: StringName in [
		contract.results_eyebrow_key,
		contract.minimum_index_narrative_key,
		contract.keep_sealed_narrative_key,
		contract.local_custody_narrative_key,
		contract.station_change_key,
		contract.next_step_key,
	]:
		expect_true(
			localization.has_translation(key, &"zh_CN")
			and localization.has_translation(key, &"en"),
			"T-125 settlement text must be bilingual: %s." % key,
			failures
		)


func _test_choice_settlements(
	registry: GameDataRegistry,
	contract: WhiteNoiseSettlementContract,
	failures: Array[String]
) -> void:
	var choices: Array[StringName] = (
		contract.arrival_contract.get_choice_flags()
	)
	var expected_codex_ids: Array[StringName] = [
		contract.minimum_index_codex.id,
		contract.keep_sealed_codex.id,
		contract.local_custody_codex.id,
	]
	var expected_ending_values: Array[StringName] = [
		contract.minimum_index_ending_value,
		contract.keep_sealed_ending_value,
		contract.local_custody_ending_value,
	]
	for index: int in choices.size():
		var state: GameStateModel = _create_qualified_state(
			registry,
			contract.order
		)
		expect_true(
			state != null,
			"T-125 choice fixture %d must accept the formal order." % index,
			failures
		)
		if state == null:
			continue
		var cargo_integrity: float = 0.0 if index == 0 else 88.0
		var run_state: OrderRunState = state.get_active_order_run_state()
		run_state.cargo_integrity = cargo_integrity
		run_state.record_landing_result(
			OrderRunState.LANDING_RESULT_ROUGH,
			6.0
		)
		_record_choice(state, contract, choices[index])
		var settlement: OrderSettlementResult = (
			OrderSettlementCalculator.calculate(contract.order, run_state)
		)
		var expected_reward: int = settlement.total_reward
		var relation_bonus: int = (
			0
			if index == 0
			else contract.privacy_relation_bonus
		)
		var committed: bool = state.settle_current_order(
			contract.order,
			settlement,
			&"",
			contract.get_settlement_flags(),
			contract.get_choice_relation_rewards(state),
			[],
			contract.get_choice_codex_rewards(state),
			contract.get_demo_ending_flags(state)
		)
		expect_true(
			committed
			and state.get_credits() == expected_reward
			and state.get_planet_relation(
				M1ProgressRules.PLANET_WHITE_NOISE
			) == 1 + relation_bonus
			and state.planet_permission_ids.has(
				M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
			)
			and state.has_souvenir(
				&"souvenir_white_noise_frost_index"
			)
			and state.has_completed_order(contract.order.id)
			and state.has_applied_order_reward(contract.order.id)
			and state.has_story_flag(contract.choice_settled_flag)
			and state.has_story_flag(
				contract.archive_terminal_updated_flag
			)
			and state.has_story_flag(contract.canopy_precursor_flag)
			and state.main_story_chapter
			== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
			and state.is_planet_unlocked(
				M1ProgressRules.PLANET_CANOPY_WORLD
			)
			and state.revisit_state.get(
				M1ProgressRules.PLANET_WHITE_NOISE,
				&""
			) == contract.revisit_state_id
			and state.demo_ending_flags.get(
				contract.ending_flag_id,
				&""
			) == expected_ending_values[index],
			"T-125 choice %d did not settle its complete atomic reward set."
			% index,
			failures
		)
		for choice_index: int in expected_codex_ids.size():
			expect_true(
				state.has_codex_entry(expected_codex_ids[choice_index])
				== (choice_index == index),
				"T-125 choice %d unlocked the wrong choice codex."
				% index,
				failures
			)
		expect_true(
			state.has_codex_entry(
				&"codex_character_white_noise_memory_owner"
			)
			and state.current_order_id.is_empty(),
			"T-125 must retain the memory-owner codex and clear the active order.",
			failures
		)
		var credits_after_first_commit: int = state.get_credits()
		expect_true(
			not state.settle_current_order(
				contract.order,
				settlement,
				&"",
				contract.get_settlement_flags(),
				contract.get_choice_relation_rewards(state),
				[],
				contract.get_choice_codex_rewards(state),
				contract.get_demo_ending_flags(state)
			)
			and state.last_order_error
			== GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
			and state.get_credits() == credits_after_first_commit,
			"T-125 repeated settlement must not duplicate rewards.",
			failures
		)
		_assert_round_trip(
			state,
			contract,
			expected_codex_ids[index],
			expected_ending_values[index],
			failures
		)
		state.free()


func _test_invalid_modifiers_are_atomic(
	contract: WhiteNoiseSettlementContract,
	failures: Array[String]
) -> void:
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var state: GameStateModel = _create_qualified_state(
		registry,
		contract.order
	)
	if state == null:
		expect_true(false, "T-125 atomicity fixture could not start.", failures)
		return
	_record_choice(
		state,
		contract,
		contract.arrival_contract.minimum_index_flag
	)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		state.get_active_order_run_state()
	)
	var invalid_ending_flags: Dictionary[StringName, Variant] = {
		&"ending_archive_choice": NodePath("/invalid"),
	}
	expect_true(
		not state.settle_current_order(
			contract.order,
			settlement,
			&"",
			contract.get_settlement_flags(),
			{},
			[],
			[&"not_a_codex_id"],
			invalid_ending_flags
		)
		and state.last_order_error == GameStateModel.ORDER_ERROR_INVALID_REWARD
		and state.current_order_id == contract.order.id
		and not state.has_completed_order(contract.order.id)
		and state.get_credits() == 0
		and not state.has_story_flag(contract.choice_settled_flag)
		and state.demo_ending_flags.is_empty(),
		"T-125 invalid choice modifiers must reject without partial mutation.",
		failures
	)
	state.free()


func _create_qualified_state(
	registry: GameDataRegistry,
	order: OrderDefinition
) -> GameStateModel:
	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	state.completed_order_ids[M1CatalogModel.M0_ORDER_ID] = true
	state.order_states[
		M1CatalogModel.M0_ORDER_ID
	] = GameStateModel.OrderStatus.COMPLETED
	state.reward_applied_order_ids.append(M1CatalogModel.M0_ORDER_ID)
	state.completed_order_ids[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = true
	state.order_states[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = GameStateModel.OrderStatus.COMPLETED
	state.reward_applied_order_ids.append(
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	)
	state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	state.ship_upgrade_ids.append(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	var shielding: ShipModuleDefinition = registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	if shielding == null or not state.equip_ship_module(shielding):
		state.free()
		return null
	if not state.accept_order(order):
		state.free()
		return null
	return state


func _record_choice(
	state: GameStateModel,
	contract: WhiteNoiseSettlementContract,
	choice_flag: StringName
) -> void:
	state.set_story_flag(
		contract.arrival_contract.main_dialogue_completion_flag
	)
	state.set_story_flag(contract.arrival_contract.choice_recorded_flag)
	state.set_story_flag(choice_flag)


func _assert_round_trip(
	state: GameStateModel,
	contract: WhiteNoiseSettlementContract,
	expected_codex_id: StringName,
	expected_ending_value: StringName,
	failures: Array[String]
) -> void:
	var progress: GameProgressData = GameProgressData.capture(state)
	var restored_progress: GameProgressData = GameProgressData.from_dictionary(
		progress.to_dictionary()
	)
	var restored: GameStateModel = GameStateModel.new()
	expect_true(
		progress.is_valid()
		and restored_progress.is_valid()
		and restored_progress.apply_to(restored)
		and restored.has_completed_order(contract.order.id)
		and restored.has_codex_entry(expected_codex_id)
		and restored.has_story_flag(
			contract.archive_terminal_updated_flag
		)
		and restored.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		)
		and restored.revisit_state.get(
			M1ProgressRules.PLANET_WHITE_NOISE,
			&""
		) == contract.revisit_state_id
		and restored.demo_ending_flags.get(
			contract.ending_flag_id,
			&""
		) == expected_ending_value,
		"T-125 save round-trip lost choice or progression rewards.",
		failures
	)
	restored.free()
