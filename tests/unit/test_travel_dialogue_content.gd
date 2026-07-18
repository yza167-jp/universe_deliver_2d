extends ProjectTestSuite

const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const MAIN_DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_travel_main.tres"
const RADIO_DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_travel_radio.tres"
const CARGO_DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_travel_cargo.tres"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	var main_dialogue: DialogueSequence = load(MAIN_DIALOGUE_PATH) as DialogueSequence
	var radio_dialogue: DialogueSequence = load(RADIO_DIALOGUE_PATH) as DialogueSequence
	var cargo_dialogue: DialogueSequence = load(CARGO_DIALOGUE_PATH) as DialogueSequence

	_validate_sequence(main_dialogue, catalog, "main", failures)
	_validate_sequence(radio_dialogue, catalog, "radio", failures)
	_validate_sequence(cargo_dialogue, catalog, "cargo", failures)
	_test_main_dialogue_branch(main_dialogue, false, &"laser_unequipped", failures)
	_test_main_dialogue_branch(main_dialogue, true, &"laser_equipped", failures)
	_test_localized_tone(catalog, failures)
	return failures


func _validate_sequence(
	sequence: DialogueSequence,
	catalog: LocalizationCatalog,
	label: String,
	failures: Array[String]
) -> void:
	expect_true(sequence != null, "Travel %s dialogue must load." % label, failures)
	if sequence == null:
		return
	var errors: PackedStringArray = DialogueValidator.validate(
		sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		errors.is_empty(),
		"Travel %s dialogue must validate: %s" % [label, "; ".join(errors)],
		failures
	)


func _test_main_dialogue_branch(
	sequence: DialogueSequence,
	laser_equipped: bool,
	expected_branch_id: StringName,
	failures: Array[String]
) -> void:
	if sequence == null:
		return
	var game_state: GameStateModel = GameStateModel.new()
	if laser_equipped:
		game_state.ship_configuration[&"utility"] = ShipLoadoutRules.LASER_MODULE_ID
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(runtime.start(sequence, game_state), "Travel main dialogue must start.", failures)
	expect_true(
		runtime.current_line != null and runtime.current_line.id == &"travel_quiet",
		"Travel main dialogue must begin with the shared quiet-route line.",
		failures
	)
	expect_true(runtime.advance(), "Travel main dialogue must reach its module branch.", failures)
	expect_true(
		runtime.current_line != null and runtime.current_line.id == expected_branch_id,
		"Travel main dialogue selected the wrong laser loadout branch.",
		failures
	)
	expect_true(
		runtime.skip_sequence() == DialogueRuntime.SequenceSkipResult.FINISHED,
		"Travel main dialogue must remain safely whole-sequence skippable.",
		failures
	)
	expect_true(
		game_state.has_story_flag(Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG),
		"Completing either loadout branch must persist the required-dialogue flag.",
		failures
	)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, expected_branch_id),
		"The selected loadout branch must be recorded as read.",
		failures
	)
	var unused_branch_id: StringName = (
		&"laser_unequipped" if laser_equipped else &"laser_equipped"
	)
	expect_true(
		not game_state.has_read_dialogue_line(sequence.id, unused_branch_id),
		"The unused loadout branch must not be recorded as read.",
		failures
	)
	game_state.free()


func _test_localized_tone(
	catalog: LocalizationCatalog,
	failures: Array[String]
) -> void:
	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TRAVEL_MAIN_LASER", &"zh_CN").contains("公司"),
		"Laser commentary must retain Lao Pi's restrained company humor.",
		failures
	)
	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TRAVEL_RADIO_01", &"zh_CN").contains("还住着人"),
		"Radio dialogue must reinforce the inhabited frontier atmosphere.",
		failures
	)
	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TRAVEL_CARGO_02", &"zh_CN").contains("不只是仓库编号"),
		"Cargo dialogue must connect the shipment to people without a lore dump.",
		failures
	)
