extends ProjectTestSuite

const CONTRACT_PATH: String = (
	"res://data/arrivals/white_noise_arrival_contract.tres"
)
const ORDER_PATH: String = (
	"res://data/orders/m1_white_noise_archive_core.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var contract: WhiteNoiseArrivalContract = load(
		CONTRACT_PATH
	) as WhiteNoiseArrivalContract
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var localization: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	expect_true(contract != null, "T-124 arrival contract must load.", failures)
	expect_true(order != null, "T-124 White Noise order must load.", failures)
	expect_true(
		localization.errors.is_empty(),
		"T-124 localization must parse without CSV errors.",
		failures
	)
	if contract == null or order == null or not localization.errors.is_empty():
		return failures
	_test_contract_and_dialogues(contract, localization, failures)
	_test_three_rejoining_choices(contract, order, failures)
	_test_relay_claim_boundary(localization, failures)
	_test_playable_boundary(order, failures)
	return failures


func _test_contract_and_dialogues(
	contract: WhiteNoiseArrivalContract,
	localization: LocalizationCatalog,
	failures: Array[String]
) -> void:
	var contract_errors: PackedStringArray = contract.validate()
	expect_true(
		contract_errors.is_empty(),
		"T-124 arrival contract errors: %s." % "; ".join(contract_errors),
		failures
	)
	for sequence: DialogueSequence in [
		contract.main_dialogue,
		contract.memory_owner_dialogue,
	]:
		var dialogue_errors: PackedStringArray = DialogueValidator.validate(
			sequence,
			localization,
			REQUIRED_LOCALES
		)
		expect_true(
			sequence != null
			and String(sequence.id).begins_with(
				"dialogue_m1_white_noise_"
			)
			and dialogue_errors.is_empty(),
			"T-124 dialogue must be stable and localized: %s."
			% "; ".join(dialogue_errors),
			failures
		)
	expect_true(
		contract.get_choice_flags().size() == 3,
		"T-124 must expose exactly three local archive choices.",
		failures
	)


func _test_three_rejoining_choices(
	contract: WhiteNoiseArrivalContract,
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	var choice_expectations: Dictionary[StringName, StringName] = {
		&"minimum_public_index": contract.minimum_index_flag,
		&"keep_archive_sealed": contract.keep_sealed_flag,
		&"local_shared_custody": contract.local_custody_flag,
	}
	var optional_line_expectations: Dictionary[StringName, StringName] = {
		&"minimum_public_index": &"owner_minimum_index",
		&"keep_archive_sealed": &"owner_keep_sealed",
		&"local_shared_custody": &"owner_local_custody",
	}
	for choice_id: StringName in choice_expectations:
		var game_state: GameStateModel = GameStateModel.new()
		var runtime: DialogueRuntime = DialogueRuntime.new()
		var credits_before: int = game_state.credits
		var relation_before: int = game_state.get_planet_relation(
			order.planet_id
		)
		expect_true(
			runtime.start(contract.main_dialogue, game_state)
			and runtime.skip_sequence()
			== DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE
			and runtime.current_line.id == &"arrival_choice",
			"T-124 main dialogue must stop at its mandatory local choice.",
			failures
		)
		expect_true(
			runtime.get_available_choices().size() == 3
			and runtime.select_choice(choice_id)
			and runtime.skip_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"T-124 choice '%s' must rejoin and finish." % choice_id,
			failures
		)
		var expected_flag: StringName = choice_expectations[choice_id]
		expect_true(
			contract.is_delivery_ready(game_state)
			and contract.get_selected_choice_id(game_state)
			== expected_flag,
			"T-124 choice '%s' must set exactly one stable result."
			% choice_id,
			failures
		)
		var selected_count: int = 0
		for choice_flag: StringName in contract.get_choice_flags():
			if game_state.has_story_flag(choice_flag):
				selected_count += 1
		expect_true(
			selected_count == 1
			and game_state.get_order_status(order.id)
			== GameStateModel.OrderStatus.AVAILABLE
			and not game_state.has_completed_order(order.id)
			and not game_state.has_applied_order_reward(order.id)
			and game_state.credits == credits_before
			and game_state.get_planet_relation(order.planet_id)
			== relation_before
			and game_state.codex_entry_ids.is_empty()
			and game_state.planet_permission_ids.is_empty(),
			"T-124 local choice '%s' must not settle or grant T-125 rewards."
			% choice_id,
			failures
		)
		expect_true(
			runtime.start(contract.memory_owner_dialogue, game_state)
			and runtime.current_line.id
			== optional_line_expectations[choice_id]
			and runtime.skip_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED
			and game_state.has_story_flag(
				contract.memory_owner_dialogue_completion_flag
			),
			"T-124 optional follow-up must reflect '%s' without branching the route."
			% choice_id,
			failures
		)
		game_state.free()


func _test_relay_claim_boundary(
	localization: LocalizationCatalog,
	failures: Array[String]
) -> void:
	var relay_text: String = localization.get_message(
		&"DIALOGUE_M1_WHITE_NOISE_ARRIVAL_RELAY_FRAGMENT",
		&"zh_CN"
	)
	expect_true(
		relay_text.contains("早三十七年")
		and relay_text.contains("只能证明")
		and relay_text.contains("无法")
		and not relay_text.contains("老皮来自")
		and not relay_text.contains("创造者是")
		and not relay_text.contains("真实用途是"),
		"T-124 relay fragment must prove only that the protocol predates the company.",
		failures
	)


func _test_playable_boundary(
	order: OrderDefinition,
	failures: Array[String]
) -> void:
	expect_true(
		order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE
		and order.destination_planet != null
		and order.destination_planet.content_readiness
		== PlanetDefinition.ContentReadiness.PLAYABLE
		and order.destination_planet.flight_scene_path
		== "res://scenes/flight/white_noise_flight.tscn",
		"T-125 must open the already-validated T-124 destination through its dedicated route.",
		failures
	)
