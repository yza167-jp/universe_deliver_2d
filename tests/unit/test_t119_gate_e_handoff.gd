extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "Gate E requires the M1 registry.", failures)
	if registry == null:
		return failures
	_test_isolated_gate_start(registry, failures)
	_test_revisit_and_white_noise_boundaries(registry, failures)
	return failures


func _test_isolated_gate_start(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_GATE_E,
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
		"Gate E must start from one valid post-M0 station snapshot.",
		failures
	)
	if progress == null or not progress.is_valid():
		return
	var game_state: GameStateModel = GameStateModel.new()
	expect_true(
		progress.apply_to(game_state)
		and game_state.credits == 100
		and game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and game_state.has_completed_order(
			M1DebugScenarioCatalog.ORDER_M0
		)
		and game_state.has_completed_order(
			M1DebugScenarioCatalog.ORDER_M0_CANONICAL
		)
		and game_state.has_story_flag(
			StationTutorialController.COMPLETION_FLAG
		)
		and game_state.has_story_flag(
			M0ProgressIds.STORY_FIRST_DELIVERY_SETTLED
		)
		and game_state.has_story_flag(
			M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED
		)
		and game_state.has_codex_entry(
			M0ProgressIds.CODEX_PLANET_RED_SAND
		)
		and game_state.has_codex_entry(
			M0ProgressIds.CODEX_CHARACTER_IYA
		)
		and game_state.has_codex_entry(
			M0ProgressIds.CODEX_RELAY_PLAQUE
		)
		and game_state.has_souvenir(
			M0ProgressIds.SOUVENIR_RELAY_PLAQUE
		)
		and game_state.get_revisit_state(
			M1ProgressRules.PLANET_RED_SAND
		) == M1ProgressRules.REVISIT_RED_SAND_AVAILABLE,
		"Gate E did not preserve the completed M0 result and exact revisit start.",
		failures
	)
	expect_true(
		not SaveServiceModel.should_enable_automatic_saves(
			PackedStringArray(),
			PackedStringArray(["--m1-debug=gate_e"])
		)
		and SaveServiceModel.should_isolate_debug_storage(
			PackedStringArray(["--m1-debug=gate_e"])
		)
		and SettingsServiceModel.should_isolate_debug_settings(
			PackedStringArray(["--m1-debug=gate_e"])
		),
		"Gate E manual-play state must not read or write normal player storage.",
		failures
	)
	game_state.free()


func _test_revisit_and_white_noise_boundaries(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_GATE_E,
		registry
	)
	var progress: GameProgressData = catalog.build_initial_progress(
		definition,
		registry
	)
	if progress == null or not progress.is_valid():
		expect_true(false, "Gate E progress is unavailable.", failures)
		return
	var game_state: GameStateModel = GameStateModel.new()
	if not progress.apply_to(game_state):
		expect_true(false, "Gate E progress could not be applied.", failures)
		game_state.free()
		return
	var revisit_order: OrderDefinition = registry.find_order(
		M1DebugScenarioCatalog.ORDER_RED_SAND_REVISIT
	)
	var white_order: OrderDefinition = registry.find_order(
		M1CatalogModel.WHITE_NOISE_ORDER_ID
	)
	var preparation: M1DestinationPreparationStatus = (
		M1CatalogModel.build_destination_preparation_status(
			white_order,
			game_state
		)
	)
	expect_true(
		revisit_order != null
		and revisit_order.is_playable()
		and game_state.can_accept_order(revisit_order)
		and preparation != null
		and preparation.is_visible
		and preparation.state
		== M1DestinationPreparationStatus.State.PREVIOUS_MAIN_REQUIRED
		and not preparation.is_navigation_unlocked
		and not game_state.is_planet_unlocked(
			M1ProgressRules.PLANET_WHITE_NOISE
		)
		and not game_state.has_ship_module(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and white_order != null
		and white_order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY
		and not game_state.can_accept_order(white_order),
		"Gate E must expose only the revisit while preserving the White Noise route guard.",
		failures
	)
	expect_true(
		game_state.accept_order(revisit_order)
		and game_state.current_order_id == revisit_order.id
		and game_state.get_order_status(revisit_order.id)
		== GameStateModel.OrderStatus.ACCEPTED,
		"Gate E station start could not enter the normal revisit order flow.",
		failures
	)
	game_state.free()
