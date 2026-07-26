extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const M0_ORDER_ALIAS: StringName = &"order_red_sand_cooling_core"


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var contract: RedSandRevisitContract = load(
		CONTRACT_PATH
	) as RedSandRevisitContract
	var localization: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	expect_true(registry != null, "Gate E Round 2 requires the M1 registry.", failures)
	expect_true(contract != null, "Gate E Round 2 requires the revisit contract.", failures)
	expect_true(
		localization.errors.is_empty(),
		"Gate E Round 2 localization must parse without CSV errors.",
		failures
	)
	if registry == null or contract == null or not localization.errors.is_empty():
		return failures
	_test_readable_history_projection(registry, contract, failures)
	_test_revisit_presentation_contract(contract, localization, failures)
	_test_revisit_dialogue_flag_isolation(contract, failures)
	return failures


func _test_readable_history_projection(
	registry: GameDataRegistry,
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = GameStateModel.new()
	state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for order_id: StringName in [
		M0_ORDER_ID,
		M0_ORDER_ALIAS,
		contract.order.id,
	]:
		state.completed_order_ids[order_id] = true
		state.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
	state.set_story_flag(contract.keep_local_record_flag)
	var entries: Array[M1OrderCatalogEntry] = M1CatalogModel.build_order_catalog(
		registry,
		state
	)
	var history_entries: Array[M1OrderCatalogEntry] = []
	for entry: M1OrderCatalogEntry in entries:
		if entry.is_history():
			history_entries.append(entry)
	expect_true(
		history_entries.size() == 2
		and _count_order(entries, M0_ORDER_ID) == 1
		and _count_order(entries, M0_ORDER_ALIAS) == 0,
		"M0 and revisit must produce two history rows while the M0 alias stays projected once.",
		failures
	)
	for entry: M1OrderCatalogEntry in history_entries:
		expect_true(
			entry.is_selectable and not entry.accept_enabled,
			"Completed and archived history rows must be selectable but read-only.",
			failures
		)
	state.free()


func _test_revisit_presentation_contract(
	contract: RedSandRevisitContract,
	localization: LocalizationCatalog,
	failures: Array[String]
) -> void:
	var dialogue_sequences: Array[DialogueSequence] = [
		contract.cockpit_manual_dialogue,
		contract.cockpit_travel_main_dialogue,
		contract.cockpit_travel_radio_dialogue,
		contract.cockpit_travel_cargo_dialogue,
	]
	var sequence_ids: Dictionary[StringName, bool] = {}
	for sequence: DialogueSequence in dialogue_sequences:
		expect_true(
			sequence != null
			and String(sequence.id).begins_with(
				"dialogue_m1_red_sand_revisit_"
			)
			and not sequence_ids.has(sequence.id),
			"Every revisit cockpit surface must use a unique revisit dialogue ID.",
			failures
		)
		if sequence == null:
			continue
		sequence_ids[sequence.id] = true
		for line: DialogueLine in sequence.lines:
			expect_true(
				line != null
				and String(line.text_key).begins_with(
					"DIALOGUE_M1_RED_SAND_REVISIT_"
				),
				"Revisit cockpit dialogue must not reuse an M0 text key.",
				failures
			)

	var expected_stage_name_keys: Array[StringName] = [
		&"UI_M1_RED_SAND_REVISIT_STAGE_SERVICE_LANE",
		&"UI_M1_RED_SAND_REVISIT_STAGE_PREPARATION",
		&"UI_M1_RED_SAND_REVISIT_STAGE_FINAL_APPROACH",
	]
	var expected_stage_instruction_keys: Array[StringName] = [
		&"UI_M1_RED_SAND_REVISIT_INSTRUCTION_SERVICE_LANE",
		&"UI_M1_RED_SAND_REVISIT_INSTRUCTION_PREPARATION",
		&"UI_M1_RED_SAND_REVISIT_INSTRUCTION_FINAL_APPROACH",
	]
	expect_true(
		contract.get_route_segment_count() == 3
		and contract.route_hud_stage_format_key
		== &"UI_M1_RED_SAND_REVISIT_ROUTE_HUD_STAGE"
		and contract.route_stage_display_name_keys
		== expected_stage_name_keys
		and contract.route_stage_instruction_keys
		== expected_stage_instruction_keys,
		"The short revisit route must keep three dedicated localized responsibilities.",
		failures
	)
	var manual_text: String = localization.get_message(
		&"DIALOGUE_M1_RED_SAND_REVISIT_COCKPIT_MANUAL_SERVICE_LANE",
		&"zh_CN"
	)
	var travel_text: String = localization.get_message(
		&"DIALOGUE_M1_RED_SAND_REVISIT_TRAVEL_MAIN_ROUTE",
		&"zh_CN"
	)
	var stage_one_text: String = localization.get_message(
		contract.route_stage_instruction_keys[0],
		&"zh_CN"
	)
	expect_true(
		manual_text.contains("完整进近")
		and manual_text.contains("维修服务航道")
		and manual_text.contains("后段安全走廊")
		and travel_text.contains("跳过外层系统")
		and travel_text.contains("陨石区")
		and travel_text.contains("完整大气进入")
		and stage_one_text.contains("完整进近")
		and stage_one_text.contains("后段安全走廊"),
		"The cockpit and stage-one HUD must explain the recorded full approach and short service lane.",
		failures
	)
	var stage_two_text: String = localization.get_message(
		contract.route_stage_instruction_keys[1],
		&"zh_CN"
	)
	var stage_three_text: String = localization.get_message(
		contract.route_stage_instruction_keys[2],
		&"zh_CN"
	)
	expect_true(
		stage_two_text.contains("屏蔽材料")
		and stage_two_text.contains("进场状态")
		and stage_three_text.contains("维修场")
		and stage_three_text.contains("着陆"),
		"Stages two and three must cover material checks and the changed-yard landing.",
		failures
	)


func _test_revisit_dialogue_flag_isolation(
	contract: RedSandRevisitContract,
	failures: Array[String]
) -> void:
	var state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		contract.cockpit_travel_completion_flag
		!= Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG
		and runtime.start(contract.cockpit_travel_main_dialogue, state),
		"Revisit mandatory cockpit dialogue must use a completion flag independent from M0.",
		failures
	)
	while runtime.is_running():
		expect_true(
			runtime.advance(),
			"Revisit mandatory cockpit dialogue must advance to completion.",
			failures
		)
	expect_true(
		state.has_story_flag(contract.cockpit_travel_completion_flag)
		and not state.has_story_flag(
			Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG
		),
		"Completing revisit travel dialogue must not mark the M0 travel dialogue complete.",
		failures
	)
	state.free()


func _count_order(
	entries: Array[M1OrderCatalogEntry],
	order_id: StringName
) -> int:
	var count: int = 0
	for entry: M1OrderCatalogEntry in entries:
		if entry.order_id == order_id:
			count += 1
	return count
