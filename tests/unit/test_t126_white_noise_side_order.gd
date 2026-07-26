extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const ROUTE_PATH: String = (
	"res://data/tuning/flight_route_white_noise_m1.tres"
)
const CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_side_order_contract.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const MAIN_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var route: WhiteNoiseRouteDefinition = load(
		ROUTE_PATH
	) as WhiteNoiseRouteDefinition
	var contract: WhiteNoiseSideOrderContract = load(
		CONTRACT_PATH
	) as WhiteNoiseSideOrderContract
	expect_true(registry != null, "T-126 registry must load.", failures)
	expect_true(route != null, "T-126 White Noise route must load.", failures)
	expect_true(contract != null, "T-126 side-order contract must load.", failures)
	if registry == null or route == null or contract == null:
		return failures
	_test_contract(registry, route, contract, failures)
	_test_choice_settlements(registry, contract, failures)
	_test_damaged_cargo_result(registry, contract, failures)
	_test_failure_and_abandonment(registry, contract, failures)
	return failures


func _test_contract(
	registry: GameDataRegistry,
	route: WhiteNoiseRouteDefinition,
	contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	var errors: PackedStringArray = contract.validate(registry, route)
	expect_true(
		errors.is_empty(),
		"T-126 side-order contract errors: %s." % "; ".join(errors),
		failures
	)
	var order: OrderDefinition = contract.order
	expect_true(
		order != null
		and order.is_playable()
		and order.order_type == OrderDefinition.OrderType.SIDE
		and order.cargo != null
		and order.cargo.id == &"cargo_returned_memory_case"
		and order.required_completed_order_ids == [MAIN_ORDER_ID]
		and order.route_distance == 17000.0
		and contract.route_start_segment_index == 3
		and contract.route_start_distance == 17000.0
		and route.get_total_distance() - contract.route_start_distance
		== order.route_distance
		and contract.flight_scene_path
		== "res://scenes/flight/white_noise_flight.tscn"
		and contract.arrival_scene_path
		== "res://scenes/arrival/white_noise_arrival.tscn"
		and order.chapter_reward.is_empty()
		and order.planet_unlock_rewards.is_empty(),
		"T-126 must reuse the final 17 km of the main route without "
		+ "advancing or gating the Canopy mainline.",
		failures
	)
	var dialogue_ids: Array[StringName] = [
		contract.arrival_dialogue.id,
		contract.cockpit_manual_dialogue.id,
		contract.cockpit_travel_main_dialogue.id,
		contract.cockpit_travel_radio_dialogue.id,
		contract.cockpit_travel_cargo_dialogue.id,
	]
	var unique_dialogue_ids: Dictionary[StringName, bool] = {}
	for dialogue_id: StringName in dialogue_ids:
		unique_dialogue_ids[dialogue_id] = true
	expect_true(
		unique_dialogue_ids.size() == 5,
		"T-126 arrival and cockpit content must use five independent dialogue IDs.",
		failures
	)
	var localization: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	var required_keys: Array[StringName] = [
		contract.cockpit_company_note_key,
		contract.cockpit_cargo_note_key,
		contract.results_eyebrow_key,
		contract.keep_private_narrative_key,
		contract.anonymous_index_narrative_key,
		contract.local_original_narrative_key,
		contract.cargo_intact_key,
		contract.cargo_damaged_key,
		contract.station_change_key,
		contract.next_step_key,
		&"UI_ORDER_SIDE_VOLUNTARY_READY",
		&"UI_WHITE_NOISE_SIDE_ROUTE_LABEL",
		&"UI_WHITE_NOISE_SIDE_ROUTE_HINTS",
		&"UI_WHITE_NOISE_SIDE_ARRIVAL_OBJECTIVE",
	]
	required_keys.append_array(
		contract.cockpit_travel_phase_name_keys
	)
	required_keys.append_array(
		contract.cockpit_travel_phase_detail_keys
	)
	for key: StringName in required_keys:
		expect_true(
			localization.has_translation(key, &"zh_CN")
			and localization.has_translation(key, &"en"),
			"T-126 player-facing text must be bilingual: %s." % key,
			failures
		)


func _test_choice_settlements(
	registry: GameDataRegistry,
	contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	var choices: Array[StringName] = contract.get_choice_flags()
	var expected_endings: Array[StringName] = [
		contract.keep_private_ending_value,
		contract.anonymous_index_ending_value,
		contract.local_original_ending_value,
	]
	var expected_owner_keys: Array[StringName] = [
		&"CODEX_CHARACTER_WHITE_NOISE_MEMORY_OWNER_DESCRIPTION_PRIVATE",
		&"CODEX_CHARACTER_WHITE_NOISE_MEMORY_OWNER_DESCRIPTION_ANONYMOUS",
		&"CODEX_CHARACTER_WHITE_NOISE_MEMORY_OWNER_DESCRIPTION_LOCAL_ORIGINAL",
	]
	var expected_cargo_keys: Array[StringName] = [
		&"CODEX_CARGO_RETURNED_MEMORY_CASE_DESCRIPTION_PRIVATE",
		&"CODEX_CARGO_RETURNED_MEMORY_CASE_DESCRIPTION_ANONYMOUS",
		&"CODEX_CARGO_RETURNED_MEMORY_CASE_DESCRIPTION_LOCAL_ORIGINAL",
	]
	for index: int in choices.size():
		var state: GameStateModel = _create_qualified_state(
			registry,
			contract.order
		)
		expect_true(
			state != null,
			"T-126 choice fixture %d must accept the optional order." % index,
			failures
		)
		if state == null:
			continue
		_record_choice(state, contract, choices[index])
		var run_state: OrderRunState = state.get_active_order_run_state()
		run_state.cargo_integrity = 100.0
		var settlement: OrderSettlementResult = (
			OrderSettlementCalculator.calculate(contract.order, run_state)
		)
		var committed: bool = state.settle_current_order(
			contract.order,
			settlement,
			&"",
			contract.get_settlement_flags(),
			contract.get_choice_relation_rewards(run_state),
			[],
			[],
			contract.get_demo_ending_flags(state)
		)
		expect_true(
			committed
			and state.get_credits() == 80
			and state.get_planet_relation(
				M1ProgressRules.PLANET_WHITE_NOISE
			) == 1
			and state.has_completed_order(contract.order.id)
			and state.completed_side_order_ids.has(contract.order.id)
			and state.has_story_flag(contract.choice_settled_flag)
			and state.has_codex_entry(
				&"codex_character_white_noise_memory_owner"
			)
			and state.has_codex_entry(
				&"codex_cargo_returned_memory_case"
			)
			and state.demo_ending_flags.get(
				contract.ending_flag_id,
				&""
			) == expected_endings[index]
			and state.main_story_chapter
			== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
			and state.is_planet_unlocked(
				M1ProgressRules.PLANET_CANOPY_WORLD
			),
			"T-126 choice %d did not atomically apply the bounded side reward."
			% index,
			failures
		)
		var descriptions: Dictionary[StringName, StringName] = (
			_get_unlocked_description_keys(registry, state)
		)
		expect_true(
			descriptions.get(
				&"codex_character_white_noise_memory_owner",
				&""
			) == expected_owner_keys[index]
			and descriptions.get(
				&"codex_cargo_returned_memory_case",
				&""
			) == expected_cargo_keys[index],
			"T-126 choice %d did not produce its person and cargo codex feedback."
			% index,
			failures
		)
		var credits_after_commit: int = state.get_credits()
		expect_true(
			not state.settle_current_order(
				contract.order,
				settlement,
				&"",
				contract.get_settlement_flags(),
				{},
				[],
				[],
				contract.get_demo_ending_flags(state)
			)
			and state.last_order_error
			== GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
			and state.get_credits() == credits_after_commit,
			"T-126 repeated settlement must not duplicate rewards.",
			failures
		)
		state.free()


func _test_damaged_cargo_result(
	registry: GameDataRegistry,
	contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = _create_qualified_state(
		registry,
		contract.order
	)
	if state == null:
		expect_true(false, "T-126 damaged-cargo fixture could not start.", failures)
		return
	_record_choice(state, contract, contract.keep_private_flag)
	var run_state: OrderRunState = state.get_active_order_run_state()
	run_state.cargo_integrity = 50.0
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		run_state
	)
	expect_true(
		settlement != null
		and settlement.total_reward == 64
		and contract.is_cargo_relation_penalized(
			settlement.cargo_integrity
		)
		and state.settle_current_order(
			contract.order,
			settlement,
			&"",
			contract.get_settlement_flags(),
			contract.get_choice_relation_rewards(run_state),
			[],
			[],
			contract.get_demo_ending_flags(state)
		)
		and state.get_credits() == 64
		and state.get_planet_relation(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == 0,
		"T-126 cargo below 70 percent must reduce credits and cancel only "
		+ "the side order's +1 relation reward.",
		failures
	)
	state.free()


func _test_failure_and_abandonment(
	registry: GameDataRegistry,
	contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	for should_fail: bool in [true, false]:
		var state: GameStateModel = _create_qualified_state(
			registry,
			contract.order
		)
		expect_true(
			state != null,
			"T-126 side failure fixture must accept.",
			failures
		)
		if state == null:
			continue
		var transitioned: bool = (
			state.fail_order(contract.order)
			if should_fail
			else state.abandon_order(contract.order)
		)
		var expected_status: GameStateModel.OrderStatus = (
			GameStateModel.OrderStatus.FAILED
			if should_fail
			else GameStateModel.OrderStatus.ABANDONED
		)
		expect_true(
			transitioned
			and state.current_order_id.is_empty()
			and state.get_order_status(contract.order.id)
			== expected_status
			and not state.has_completed_order(contract.order.id)
			and state.main_story_chapter
			== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
			and state.is_planet_unlocked(
				M1ProgressRules.PLANET_CANOPY_WORLD
			)
			and state.has_completed_order(MAIN_ORDER_ID)
			and state.ship_upgrade_ids.has(
				M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
			),
			"T-126 failure/abandonment must clear only the optional order "
			+ "without blocking the Canopy mainline.",
			failures
		)
		state.free()


func _create_qualified_state(
	registry: GameDataRegistry,
	order: OrderDefinition
) -> GameStateModel:
	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
	state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
		M1ProgressRules.PLANET_CANOPY_WORLD,
	]
	state.planet_permission_ids.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	for completed_order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
		MAIN_ORDER_ID,
	]:
		state.completed_order_ids[completed_order_id] = true
		state.order_states[
			completed_order_id
		] = GameStateModel.OrderStatus.COMPLETED
		state.reward_applied_order_ids.append(completed_order_id)
	state.set_story_flag(
		&"story_m1_white_noise_archive_core_completed"
	)
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
	contract: WhiteNoiseSideOrderContract,
	choice_flag: StringName
) -> void:
	state.set_story_flag(contract.arrival_dialogue_completion_flag)
	state.set_story_flag(contract.choice_recorded_flag)
	state.set_story_flag(choice_flag)


func _get_unlocked_description_keys(
	registry: GameDataRegistry,
	state: GameStateModel
) -> Dictionary[StringName, StringName]:
	var keys: Dictionary[StringName, StringName] = {}
	for entry: CodexCatalogEntry in CodexCatalogModel.build_catalog(
		registry,
		state
	):
		if entry.is_unlocked:
			keys[entry.id] = entry.description_key
	return keys
