extends ProjectTestSuite

const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning: FlightTuning = load(
		"res://data/tuning/flight_tuning_m0.tres"
	) as FlightTuning
	var game_state: GameStateModel = GameStateModel.new()
	game_state.current_order_id = &"order_style_dialogue_test"
	var run_state: OrderRunState = game_state.get_active_order_run_state()
	var tracker: FlightStyleTracker = FlightStyleTracker.new()
	tracker.begin(run_state)
	tracker.record_sample(1.0, Vector2(100.0, 230.0), 0.85, tuning)
	tracker.finalize(tuning)

	var dive_condition: DialogueCondition = DialogueCondition.new()
	dive_condition.condition_type = DialogueCondition.ConditionType.ENTRY_STYLE_EQUALS
	dive_condition.entry_style = FlightStyleTracker.STYLE_DIVE
	var glide_condition: DialogueCondition = DialogueCondition.new()
	glide_condition.condition_type = DialogueCondition.ConditionType.ENTRY_STYLE_EQUALS
	glide_condition.entry_style = FlightStyleTracker.STYLE_GLIDE
	expect_true(
		dive_condition.is_met(game_state) and not glide_condition.is_met(game_state),
		"Dialogue conditions must read the finalized order-run entry style.",
		failures
	)

	var sequence: DialogueSequence = (
		load(DIALOGUE_PATH) as DialogueSequence
	).duplicate(true) as DialogueSequence
	var intro_conditions: Array[DialogueCondition] = [dive_condition]
	sequence.lines[0].conditions = intro_conditions
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		runtime.start(sequence, game_state)
		and runtime.current_line.id == &"intro",
		"Dialogue runtime must retain a line whose entry-style condition matches.",
		failures
	)
	run_state.entry_style = FlightStyleTracker.STYLE_GLIDE
	var alternate_runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(
		alternate_runtime.start(sequence, game_state)
		and alternate_runtime.current_line.id == &"prompt",
		"Dialogue runtime must skip a line whose entry-style condition does not match.",
		failures
	)

	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	var valid_errors: PackedStringArray = DialogueValidator.validate(
		sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		valid_errors.is_empty(),
		"DIVE must be accepted by dialogue data validation: %s"
		% "; ".join(valid_errors),
		failures
	)
	dive_condition.entry_style = &"ARCADE_SCORE"
	var invalid_errors: PackedStringArray = DialogueValidator.validate(
		sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		_contains_error(invalid_errors, "entry_style must be DIVE, GLIDE, or BALANCED"),
		"Dialogue validation must reject arbitrary entry-style IDs.",
		failures
	)
	game_state.free()
	return failures


func _contains_error(errors: PackedStringArray, expected_fragment: String) -> bool:
	for error: String in errors:
		if error.contains(expected_fragment):
			return true
	return false
