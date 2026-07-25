extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const RED_SAND_SCENE_PATH: String = (
	"res://scenes/flight/red_sand_flight.tscn"
)
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const REVISIT_ORDER_ID: StringName = (
	&"order_m1_red_sand_shielding_retrofit"
)
const UPLOAD_FLAG: StringName = (
	&"story_m1_red_sand_retrofit_records_uploaded_full"
)
const KEEP_LOCAL_FLAG: StringName = (
	&"story_m1_red_sand_retrofit_records_kept_local"
)


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var contract: RedSandRevisitContract = load(
		CONTRACT_PATH
	) as RedSandRevisitContract
	expect_true(registry != null, "T-110 requires the M1 registry.", failures)
	expect_true(contract != null, "T-110 requires the revisit contract.", failures)
	if registry == null or contract == null:
		return failures
	_test_contract_and_registered_data(registry, contract, failures)
	_test_m0_completion_gate_and_atomic_rewards(registry, contract, failures)
	_test_invalid_chapter_reward_is_atomic(contract, failures)
	_test_dialogue_choice_skeleton(contract, failures)
	_test_debug_snapshot(registry, failures)
	return failures


func _test_contract_and_registered_data(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var registry_errors: PackedStringArray = GameDataValidator.validate(registry)
	var contract_errors: PackedStringArray = contract.validate(registry)
	var order: OrderDefinition = contract.order
	var shield_reward_sources: int = 0
	for candidate: OrderDefinition in registry.orders:
		if (
			candidate != null
			and candidate.ship_upgrade_rewards.has(
				M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
			)
		):
			shield_reward_sources += 1
	var shield_module: ShipModuleDefinition = registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	expect_true(
		registry_errors.is_empty(),
		"T-110 registry contract errors: %s." % "; ".join(registry_errors),
		failures
	)
	expect_true(
		contract_errors.is_empty(),
		"T-110 revisit contract errors: %s." % "; ".join(contract_errors),
		failures
	)
	expect_true(
		order != null
		and order.id == REVISIT_ORDER_ID
		and order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE
		and order.order_type == OrderDefinition.OrderType.REVISIT
		and order.repeat_policy == OrderDefinition.RepeatPolicy.UNIQUE
		and order.required_completed_order_ids == [M0_ORDER_ID]
		and order.story_requirements.has(&"story_red_sand_order_completed")
		and order.cargo != null
		and order.cargo.id == &"cargo_relay_pattern_shielding_materials"
		and order.cargo.boost_policy == CargoDefinition.BoostPolicy.LIMITED
		and is_equal_approx(order.cargo.collision_tolerance, 0.65),
		"The implemented revisit must be playable with exact M0 and cargo gates.",
		failures
	)
	expect_true(
		shield_reward_sources == 1
		and shield_module != null
		and shield_module.cost == 0
		and order.ship_upgrade_rewards
		== [M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING]
		and order.station_state_rewards
		== [StationStateRules.ARCHIVE_TERMINAL_ID]
		and order.chapter_reward
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and order.revisit_state_rewards.get(
			M1ProgressRules.PLANET_RED_SAND,
			&""
		) == M1ProgressRules.REVISIT_RED_SAND_COMPLETED,
		"Shielding must have one free, deterministic revisit reward path.",
		failures
	)
	expect_true(
		contract.source_route != null
		and contract.source_route.id == &"route_red_sand_m0"
		and contract.route_variant_id
		== &"route_red_sand_revisit_service_lane"
		and is_equal_approx(contract.route_entry_distance, 26000.0)
		and is_equal_approx(contract.get_route_distance(), 12000.0)
		and is_equal_approx(contract.nominal_route_seconds, 48.0),
		"The revisit must define a short M0-derived service-lane window.",
		failures
	)


func _test_m0_completion_gate_and_atomic_rewards(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var fixture: OrderDefinition = contract.order.duplicate(true) as OrderDefinition
	var fixture_planet: PlanetDefinition = (
		contract.order.destination_planet.duplicate(true) as PlanetDefinition
	)
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture_planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	fixture_planet.flight_scene_path = RED_SAND_SCENE_PATH
	fixture.destination_planet = fixture_planet

	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	expect_true(
		state.get_order_acceptance_error(fixture)
		== M1ProgressRules.REASON_REQUIRED_COMPLETED_ORDER,
		"A chapter flag alone must not bypass the completed M0 order.",
		failures
	)
	state.completed_order_ids[M0_ORDER_ID] = true
	state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	expect_true(
		state.get_order_acceptance_error(fixture)
		== GameStateModel.ORDER_ERROR_STORY_REQUIREMENT,
		"The revisit must retain the M0 story-completion guard.",
		failures
	)
	state.set_story_flag(&"story_red_sand_order_completed")
	expect_true(
		state.accept_order(fixture)
		and state.set_revisit_state(
			M1ProgressRules.PLANET_RED_SAND,
			contract.accepted_state_id
		).success,
		"A completed M0 state must accept the playable test fixture.",
		failures
	)
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		runtime.start(contract.arrival_dialogue, state)
		and _advance_to_choice(runtime)
		and runtime.select_choice(&"upload_full_retrofit_record")
		and _finish_dialogue(runtime),
		"The upload branch must resolve through the dialogue runtime.",
		failures
	)
	expect_true(
		state.complete_order(fixture)
		and state.get_order_status(REVISIT_ORDER_ID)
		== GameStateModel.OrderStatus.COMPLETED
		and state.credits == 140
		and state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 1
		and state.ship_upgrade_ids.has(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and not state.is_ship_module_equipped(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		)
		and state.has_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
		and state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and state.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== M1ProgressRules.REVISIT_RED_SAND_COMPLETED
		and state.has_story_flag(
			&"story_m1_red_sand_shielding_retrofit_completed"
		)
		and state.has_story_flag(UPLOAD_FLAG)
		and not state.has_story_flag(KEEP_LOCAL_FLAG),
		"Revisit completion must atomically persist its full progression reward set.",
		failures
	)
	var reward_signature: String = _progress_signature(state)
	expect_true(
		not state.complete_order(fixture)
		and state.last_order_error
		== GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
		and _progress_signature(state) == reward_signature,
		"Revisit completion and its free module reward must be idempotent.",
		failures
	)
	expect_true(
		registry.find_order(REVISIT_ORDER_ID).content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE,
		"The fixture must not mutate formal T-112 readiness.",
		failures
	)
	state.free()


func _test_invalid_chapter_reward_is_atomic(
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var fixture: OrderDefinition = contract.order.duplicate(true) as OrderDefinition
	var fixture_planet: PlanetDefinition = (
		contract.order.destination_planet.duplicate(true) as PlanetDefinition
	)
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture.chapter_reward = M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
	fixture_planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	fixture_planet.flight_scene_path = RED_SAND_SCENE_PATH
	fixture.destination_planet = fixture_planet

	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	state.completed_order_ids[M0_ORDER_ID] = true
	state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	state.set_story_flag(&"story_red_sand_order_completed")
	expect_true(
		state.accept_order(fixture),
		"The illegal-reward fixture must reach the completion guard.",
		failures
	)
	var before_signature: String = _progress_signature(state)
	expect_true(
		not state.complete_order(fixture)
		and state.last_order_error == GameStateModel.ORDER_ERROR_INVALID_REWARD
		and _progress_signature(state) == before_signature,
		"An illegal chapter skip must reject the whole settlement atomically.",
		failures
	)
	state.free()


func _test_dialogue_choice_skeleton(
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	var dialogue_errors: PackedStringArray = DialogueValidator.validate(
		contract.arrival_dialogue,
		catalog,
		PackedStringArray(["zh_CN", "en"])
	)
	expect_true(
		dialogue_errors.is_empty(),
		"T-110 dialogue errors: %s." % "; ".join(dialogue_errors),
		failures
	)
	var state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		runtime.start(contract.arrival_dialogue, state)
		and _advance_to_choice(runtime)
		and runtime.get_available_choices().size() == 2
		and runtime.select_choice(&"keep_retrofit_record_local")
		and _finish_dialogue(runtime)
		and state.has_story_flag(KEEP_LOCAL_FLAG)
		and not state.has_story_flag(UPLOAD_FLAG)
		and state.has_story_flag(
			&"story_m1_red_sand_revisit_dialogue_completed"
		),
		"The local-record branch must record one bounded choice and finish.",
		failures
	)
	state.free()


func _test_debug_snapshot(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: M1DebugScenarioCatalog = M1DebugScenarioCatalog.new()
	var definition: M1DebugScenarioDefinition = catalog.get_definition(
		M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT,
		registry
	)
	var progress: GameProgressData = catalog.build_initial_progress(
		definition,
		registry
	)
	expect_true(
		definition != null
		and progress != null
		and progress.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and progress.completed_order_ids.get(M0_ORDER_ID, false)
		and progress.revisit_state.get(
			M1ProgressRules.PLANET_RED_SAND,
			&""
		) == M1ProgressRules.REVISIT_RED_SAND_AVAILABLE
		and not progress.ship_upgrade_ids.has(
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		),
		"The Red Sand debug snapshot must stop before retrofit rewards.",
		failures
	)


func _advance_to_choice(runtime: DialogueRuntime) -> bool:
	while (
		runtime.is_running()
		and runtime.current_line != null
		and runtime.current_line.choices.is_empty()
	):
		if not runtime.advance():
			return false
	return (
		runtime.is_running()
		and runtime.current_line != null
		and runtime.current_line.id == &"revisit_record_choice"
	)


func _finish_dialogue(runtime: DialogueRuntime) -> bool:
	while runtime.is_running():
		if runtime.current_line == null or not runtime.current_line.choices.is_empty():
			return false
		if not runtime.advance():
			return false
	return true


func _progress_signature(state: GameStateModel) -> String:
	var progress: GameProgressData = GameProgressData.capture(state)
	if progress == null or not progress.is_valid():
		return "INVALID"
	progress.last_saved_at_unix = 0
	progress.build_version = "t110_fixture"
	return JSON.stringify(progress.to_dictionary())
