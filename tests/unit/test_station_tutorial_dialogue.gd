extends ProjectTestSuite

const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]
const SEQUENCE_PATHS: PackedStringArray = [
	"res://data/dialogue/lao_pi_tutorial_intro.tres",
	"res://data/dialogue/lao_pi_tutorial_move_ack.tres",
	"res://data/dialogue/lao_pi_tutorial_interact_ack.tres",
	"res://data/dialogue/lao_pi_tutorial_complete.tres",
	"res://data/dialogue/lao_pi_station_daily.tres",
	"res://data/dialogue/lao_pi_order_accepted.tres",
	"res://data/dialogue/lao_pi_active_order_daily.tres",
]

var _flow_events: Array[StringName] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	for sequence_path: String in SEQUENCE_PATHS:
		var sequence: DialogueSequence = load(sequence_path) as DialogueSequence
		expect_true(sequence != null, "Tutorial dialogue must load: %s" % sequence_path, failures)
		if sequence == null:
			continue
		var errors: PackedStringArray = DialogueValidator.validate(
			sequence,
			catalog,
			REQUIRED_LOCALES
		)
		expect_true(
			errors.is_empty(),
			"Tutorial dialogue must validate: %s" % "; ".join(errors),
			failures
		)

	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TUTORIAL_INTRO_02", &"zh_CN").contains(
			"同声传译器"
		),
		"Opening tutorial must establish the simultaneous translator.",
		failures
	)
	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TUTORIAL_INTERACT_02", &"zh_CN").contains(
			"公司"
		),
		"Tutorial must include company black humor.",
		failures
	)
	expect_true(
		catalog.get_message(&"DIALOGUE_LAO_PI_TUTORIAL_COMPLETE_02", &"zh_CN").contains(
			"不只我一个人"
		),
		"Tutorial must include a warm companion line.",
		failures
	)
	_check_completion_effects(failures)
	return failures


func _check_completion_effects(failures: Array[String]) -> void:
	var sequence: DialogueSequence = load(SEQUENCE_PATHS[3]) as DialogueSequence
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_flow_events.clear()
	runtime.flow_event_emitted.connect(_on_flow_event_emitted)
	expect_true(runtime.start(sequence, game_state), "Completion dialogue must start.", failures)
	while runtime.is_running():
		expect_true(runtime.advance(), "Completion dialogue must advance.", failures)
	expect_true(
		game_state.has_story_flag(StationTutorialController.COMPLETION_FLAG),
		"Completion dialogue must persist the tutorial flag.",
		failures
	)
	expect_true(
		_flow_events.has(StationTutorialController.FLOW_COMPLETE),
		"Completion dialogue must emit its station flow event.",
		failures
	)
	game_state.free()


func _on_flow_event_emitted(event_id: StringName) -> void:
	_flow_events.append(event_id)
