extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const BRIEFING_PATH: String = (
	"res://data/dialogue/lao_pi_archive_terminal_briefing.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]
const RELAY_ECHO_CODEX_ID: StringName = &"codex_anomaly_relay_echo"
const WHITE_NOISE_CODEX_ID: StringName = &"codex_planet_white_noise"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var contract: RedSandRevisitContract = load(
		CONTRACT_PATH
	) as RedSandRevisitContract
	var briefing: DialogueSequence = load(BRIEFING_PATH) as DialogueSequence
	expect_true(registry != null, "T-113 requires the M1 registry.", failures)
	expect_true(contract != null, "T-113 requires the revisit contract.", failures)
	expect_true(briefing != null, "T-113 requires Lao Pi's archive briefing.", failures)
	if registry == null or contract == null or briefing == null:
		return failures
	_test_archive_catalog_contract(registry, contract, failures)
	_test_existing_v2_revisit_save_backfill(registry, contract, failures)
	_test_archive_briefing_completion(briefing, failures)
	return failures


func _test_archive_catalog_contract(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var anomaly: CodexEntryDefinition = registry.find_codex_entry(
		RELAY_ECHO_CODEX_ID
	)
	expect_true(
		anomaly != null
		and anomaly.category == CodexEntryDefinition.Category.ANOMALY
		and anomaly.hidden_when_locked
		and contract.order.codex_rewards.has(RELAY_ECHO_CODEX_ID)
		and contract.order.codex_rewards.has(WHITE_NOISE_CODEX_ID),
		"The revisit reward must expose one redacted anomaly clue and known White Noise record.",
		failures
	)

	var state: GameStateModel = _create_accepted_state(contract)
	_complete_revisit(state, registry, contract)
	var catalog: Array[CodexCatalogEntry] = CodexCatalogModel.build_catalog(
		registry,
		state
	)
	expect_true(
		_find_entry(catalog, RELAY_ECHO_CODEX_ID) != null
		and _find_entry(catalog, WHITE_NOISE_CODEX_ID) != null
		and _count_category(
			catalog,
			CodexEntryDefinition.Category.ANOMALY
		) == 1,
		"Completed revisit progress must expose the anomaly and White Noise without future characters.",
		failures
	)
	expect_true(
		_find_entry(
			catalog,
			&"codex_character_white_noise_archivist"
		) == null,
		"The archive terminal must not reveal an unintroduced White Noise character.",
		failures
	)
	state.free()


func _test_existing_v2_revisit_save_backfill(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = _create_accepted_state(contract)
	_complete_revisit(state, registry, contract)
	var payload: Dictionary = GameProgressData.capture(state).to_dictionary()
	var game_progress: Dictionary = payload.get("game_progress", {}) as Dictionary
	var old_codex_ids: Array = game_progress.get("codex_entry_ids", []) as Array
	old_codex_ids.erase(String(RELAY_ECHO_CODEX_ID))
	old_codex_ids.erase(String(WHITE_NOISE_CODEX_ID))
	game_progress["codex_entry_ids"] = old_codex_ids
	payload["game_progress"] = game_progress

	var restored_progress: GameProgressData = GameProgressData.from_dictionary(
		payload
	)
	var restored: GameStateModel = GameStateModel.new()
	expect_true(
		restored_progress.is_valid()
		and restored_progress.apply_to(restored)
		and restored.has_codex_entry(RELAY_ECHO_CODEX_ID)
		and restored.has_codex_entry(WHITE_NOISE_CODEX_ID),
		"An existing schema-v2 revisit save must gain the new archive records on Continue.",
		failures
	)
	state.free()
	restored.free()


func _test_archive_briefing_completion(
	briefing: DialogueSequence,
	failures: Array[String]
) -> void:
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	var validation_errors: PackedStringArray = DialogueValidator.validate(
		briefing,
		catalog,
		REQUIRED_LOCALES
	)
	var state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		validation_errors.is_empty()
		and briefing.lines.size() == 3
		and runtime.start(briefing, state),
		"Lao Pi's archive briefing must be a valid three-line sequence.",
		failures
	)
	expect_true(
		not state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
		),
		"The archive briefing must not complete before its final line.",
		failures
	)
	while runtime.is_running():
		expect_true(
			runtime.advance(),
			"The archive briefing must advance to completion.",
			failures
		)
	expect_true(
		state.has_story_flag(
			StationTutorialController.ARCHIVE_BRIEFING_COMPLETION_FLAG
		),
		"The final archive briefing line must persist its one-time completion flag.",
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
	state.reward_applied_order_ids.append(
		GameDataValidator.M1_ACTUAL_M0_ORDER_ID
	)
	state.set_story_flag(&"story_red_sand_order_completed")
	state.unlock_codex_entry(&"codex_planet_red_sand")
	state.unlock_codex_entry(&"codex_character_iya")
	state.add_souvenir(&"souvenir_old_relay_plaque")
	state.accept_order(contract.order)
	state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		contract.accepted_state_id
	)
	var run_state: OrderRunState = state.get_active_order_run_state()
	run_state.cargo_integrity = 100.0
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	return state


func _complete_revisit(
	state: GameStateModel,
	registry: GameDataRegistry,
	contract: RedSandRevisitContract
) -> bool:
	state.set_story_flag(contract.keep_local_record_flag)
	state.set_story_flag(contract.completion_dialogue_flag)
	var module: ShipModuleDefinition = registry.find_module(
		contract.auto_equip_module_id
	)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		contract.order,
		state.get_active_order_run_state()
	)
	return state.settle_current_order(
		contract.order,
		settlement,
		&"",
		[],
		contract.get_choice_relation_rewards(state),
		[module]
	)


func _find_entry(
	entries: Array[CodexCatalogEntry],
	entry_id: StringName
) -> CodexCatalogEntry:
	for entry: CodexCatalogEntry in entries:
		if entry.id == entry_id:
			return entry
	return null


func _count_category(
	entries: Array[CodexCatalogEntry],
	category: CodexEntryDefinition.Category
) -> int:
	var count: int = 0
	for entry: CodexCatalogEntry in entries:
		if entry.category == category:
			count += 1
	return count
