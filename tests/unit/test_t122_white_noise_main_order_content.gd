extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTENT_PATH: String = (
	"res://data/orders/white_noise_main_order_content.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var content: WhiteNoiseMainOrderContent = load(
		CONTENT_PATH
	) as WhiteNoiseMainOrderContent
	var localization: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_PATH
	)
	expect_true(registry != null, "T-122 requires the M1 registry.", failures)
	expect_true(
		content != null,
		"T-122 requires White Noise order-scoped cockpit content.",
		failures
	)
	expect_true(
		localization.errors.is_empty(),
		"T-122 localization must parse without CSV errors.",
		failures
	)
	if registry == null or content == null or not localization.errors.is_empty():
		return failures
	_test_content_contract(registry, content, localization, failures)
	_test_order_and_cargo_brief(content, localization, failures)
	_test_dialogue_read_state_isolation(content, failures)
	return failures


func _test_content_contract(
	registry: GameDataRegistry,
	content: WhiteNoiseMainOrderContent,
	localization: LocalizationCatalog,
	failures: Array[String]
) -> void:
	var contract_errors: PackedStringArray = content.validate(registry)
	expect_true(
		contract_errors.is_empty(),
		"T-122 content contract errors: %s." % "; ".join(contract_errors),
		failures
	)
	var dialogues: Array[DialogueSequence] = [
		content.cockpit_manual_dialogue,
		content.cockpit_travel_main_dialogue,
		content.cockpit_travel_radio_dialogue,
		content.cockpit_travel_cargo_dialogue,
	]
	var ids: Dictionary[StringName, bool] = {}
	for sequence: DialogueSequence in dialogues:
		var dialogue_errors: PackedStringArray = DialogueValidator.validate(
			sequence,
			localization,
			REQUIRED_LOCALES
		)
		expect_true(
			sequence != null
			and String(sequence.id).begins_with("dialogue_m1_white_noise_")
			and not ids.has(sequence.id)
			and dialogue_errors.is_empty(),
			"T-122 dialogue must be unique and localized: %s."
			% "; ".join(dialogue_errors),
			failures
		)
		if sequence != null:
			ids[sequence.id] = true
	expect_true(
		content.order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE
		and content.order.destination_planet.content_readiness
		== PlanetDefinition.ContentReadiness.PLAYABLE
		and content.order.destination_planet.flight_scene_path
		== "res://scenes/flight/white_noise_flight.tscn",
		"T-125 must expose the formal route without changing T-122 content.",
		failures
	)


func _test_order_and_cargo_brief(
	content: WhiteNoiseMainOrderContent,
	localization: LocalizationCatalog,
	failures: Array[String]
) -> void:
	var order: OrderDefinition = content.order
	var cargo: CargoDefinition = order.cargo
	expect_true(
		order.id == GameDataValidator.M1_WHITE_NOISE_ORDER_ID
		and order.sender != null
		and order.recipient != null
		and order.customer_history_keys.size() == 5
		and cargo != null
		and cargo.id == &"cargo_white_noise_archive_core"
		and cargo.company_description_key
		!= cargo.story_description_key,
		"The White Noise brief must retain stable parties, history, and two cargo descriptions.",
		failures
	)
	var company_text: String = localization.get_message(
		cargo.company_description_key,
		&"zh_CN"
	)
	var actual_text: String = localization.get_message(
		cargo.story_description_key,
		&"zh_CN"
	)
	var manual_text: String = localization.get_message(
		&"DIALOGUE_M1_WHITE_NOISE_COCKPIT_MANUAL_ACCESS",
		&"zh_CN"
	)
	var radio_text: String = localization.get_message(
		&"DIALOGUE_M1_WHITE_NOISE_TRAVEL_RADIO_WARNING",
		&"zh_CN"
	)
	expect_true(
		company_text.contains("标准核心组件")
		and actual_text.contains("批量访问接口")
		and manual_text.contains("只恢复获准索引")
		and radio_text.contains("不等于取得公开授权"),
		"Company framing and local memory-access limits must remain concretely different.",
		failures
	)
	for key: StringName in (
		content.cockpit_travel_phase_name_keys
		+ content.cockpit_travel_phase_detail_keys
	):
		expect_true(
			localization.has_translation(key, &"zh_CN")
			and localization.has_translation(key, &"en"),
			"White Noise travel presentation key '%s' is incomplete." % key,
			failures
		)


func _test_dialogue_read_state_isolation(
	content: WhiteNoiseMainOrderContent,
	failures: Array[String]
) -> void:
	var state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		runtime.start(content.cockpit_travel_main_dialogue, state)
		and runtime.skip_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"The White Noise mandatory travel dialogue must complete linearly.",
		failures
	)
	expect_true(
		state.has_story_flag(content.cockpit_travel_completion_flag)
		and not state.has_story_flag(
			Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG
		)
		and not state.has_story_flag(
			&"story_m1_red_sand_revisit_cockpit_travel_completed"
		),
		"White Noise travel completion must not overwrite M0 or revisit state.",
		failures
	)
	for sequence: DialogueSequence in [
		content.cockpit_manual_dialogue,
		content.cockpit_travel_radio_dialogue,
		content.cockpit_travel_cargo_dialogue,
	]:
		expect_true(
			runtime.start(sequence, state)
			and runtime.skip_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"White Noise optional cockpit dialogue '%s' must complete."
			% sequence.id,
			failures
		)
		for line: DialogueLine in sequence.lines:
			expect_true(
				state.has_read_dialogue_line(sequence.id, line.id),
				"Dialogue read state must use the White Noise sequence and line IDs.",
				failures
			)
	state.free()
