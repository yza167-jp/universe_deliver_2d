extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const MAIN_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const SIDE_CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_side_order_contract.tres"
)


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var main_contract: WhiteNoiseSettlementContract = load(
		MAIN_CONTRACT_PATH
	) as WhiteNoiseSettlementContract
	var side_contract: WhiteNoiseSideOrderContract = load(
		SIDE_CONTRACT_PATH
	) as WhiteNoiseSideOrderContract
	expect_true(registry != null, "Gate F requires the M1 registry.", failures)
	expect_true(
		main_contract != null,
		"Gate F requires the White Noise main settlement contract.",
		failures
	)
	expect_true(
		side_contract != null,
		"Gate F requires the White Noise side-order contract.",
		failures
	)
	if registry == null or main_contract == null or side_contract == null:
		return failures
	_test_isolated_gate_start(registry, main_contract, side_contract, failures)
	_test_main_to_optional_handoff(
		registry,
		main_contract,
		side_contract,
		failures
	)
	return failures


func _test_isolated_gate_start(
	registry: GameDataRegistry,
	main_contract: WhiteNoiseSettlementContract,
	side_contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_GATE_F,
		registry
	)
	var progress: GameProgressData = catalog.build_initial_progress(
		definition,
		registry
	)
	expect_true(
		definition != null
		and definition.target_stage == SceneRouterService.Stage.STATION
		and definition.target_scene_path
		== M1DebugScenarioCatalog.STATION_SCENE_PATH
		and not definition.preview_only
		and definition.active_order_id.is_empty()
		and progress != null
		and progress.is_valid(),
		"Gate F must start from one valid post-revisit station snapshot.",
		failures
	)
	if progress == null or not progress.is_valid():
		return
	var state: GameStateModel = GameStateModel.new()
	expect_true(
		progress.apply_to(state)
		and state.credits == 240
		and state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and state.has_completed_order(
			M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
		)
		and state.get_revisit_state(
			M1ProgressRules.PLANET_RED_SAND
		) == M1ProgressRules.REVISIT_RED_SAND_COMPLETED
		and state.has_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		and state.station_state_level
		== StationStateRules.ARCHIVE_TERMINAL_LEVEL
		and state.has_ship_module(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and state.is_ship_module_equipped(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and state.has_codex_entry(
			M1DebugScenarioCatalog.CODEX_REVISIT_CARGO
		)
		and state.has_codex_entry(
			M1DebugScenarioCatalog.CODEX_RELAY_ECHO
		)
		and state.has_codex_entry(
			M1DebugScenarioCatalog.CODEX_WHITE_NOISE
		)
		and state.can_accept_order(main_contract.order)
		and not state.can_accept_order(side_contract.order)
		and not state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		),
		"Gate F did not preserve the accepted Gate E outcome and exact White Noise start.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray(["--m1-debug=gate_f"])
		)
		and SaveServiceModel.should_isolate_debug_storage(
			PackedStringArray(["--m1-debug=gate_f"])
		)
		and SettingsServiceModel.should_isolate_debug_settings(
			PackedStringArray(["--m1-debug=gate_f"])
		),
		"Gate F must not read or write normal player storage.",
		failures
	)
	state.free()


func _test_main_to_optional_handoff(
	registry: GameDataRegistry,
	main_contract: WhiteNoiseSettlementContract,
	side_contract: WhiteNoiseSideOrderContract,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_GATE_F,
		registry
	)
	var progress: GameProgressData = catalog.build_initial_progress(
		definition,
		registry
	)
	if progress == null or not progress.is_valid():
		expect_true(false, "Gate F transition snapshot is unavailable.", failures)
		return
	var state: GameStateModel = GameStateModel.new()
	if not progress.apply_to(state) or not state.accept_order(main_contract.order):
		expect_true(
			false,
			"Gate F could not accept its formal White Noise main order.",
			failures
		)
		state.free()
		return
	var choice_flag: StringName = (
		main_contract.arrival_contract.keep_sealed_flag
	)
	state.set_story_flag(
		main_contract.arrival_contract.main_dialogue_completion_flag
	)
	state.set_story_flag(
		main_contract.arrival_contract.choice_recorded_flag
	)
	state.set_story_flag(choice_flag)
	var run_state: OrderRunState = state.get_active_order_run_state()
	var settlement: OrderSettlementResult = (
		OrderSettlementCalculator.calculate(main_contract.order, run_state)
	)
	var committed: bool = (
		settlement != null
		and state.settle_current_order(
			main_contract.order,
			settlement,
			&"",
			main_contract.get_settlement_flags(),
			main_contract.get_choice_relation_rewards(state),
			[],
			main_contract.get_choice_codex_rewards(state),
			main_contract.get_demo_ending_flags(state)
		)
	)
	expect_true(
		committed
		and state.has_completed_order(main_contract.order.id)
		and state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		)
		and state.can_accept_order(side_contract.order)
		and state.accept_order(side_contract.order)
		and state.abandon_order(side_contract.order)
		and state.has_completed_order(main_contract.order.id)
		and state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
		and state.is_planet_unlocked(
			M1ProgressRules.PLANET_CANOPY_WORLD
		),
		"Gate F main completion must expose a voluntary side order whose abandonment cannot block Canopy.",
		failures
	)
	state.free()
