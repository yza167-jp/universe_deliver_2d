extends ProjectTestSuite

const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"

var _flow_events: Array[StringName] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	var sequence: DialogueSequence = load(DIALOGUE_PATH) as DialogueSequence
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_flow_events.clear()
	runtime.flow_event_emitted.connect(_on_flow_event_emitted)

	expect_true(runtime.start(sequence, game_state), "Dialogue runtime must start.", failures)
	expect_true(runtime.current_line.id == &"intro", "Dialogue must start at intro.", failures)
	expect_true(runtime.advance(), "Intro must advance to the choice prompt.", failures)
	expect_true(runtime.current_line.id == &"prompt", "Choice prompt must become active.", failures)
	expect_true(
		runtime.get_available_choices().size() == 2,
		"Test dialogue must expose two simple choices.",
		failures
	)
	expect_true(
		not runtime.select_choice(&"choice_missing"),
		"Unavailable choices must be rejected.",
		failures
	)
	expect_true(
		runtime.select_choice(&"follow_process"),
		"Professional choice must be accepted.",
		failures
	)
	expect_true(
		game_state.has_story_flag(&"story_dialogue_test_professional"),
		"A simple choice must set its story flag.",
		failures
	)
	expect_true(
		runtime.current_line.id == &"process_response",
		"Choice must follow its explicit next_line_id.",
		failures
	)
	expect_true(runtime.advance(), "Choice response must advance.", failures)
	expect_true(runtime.current_line.id == &"finish", "Final line must become active.", failures)
	expect_true(runtime.advance(), "Final line must complete the dialogue.", failures)
	expect_true(not runtime.is_running(), "Dialogue must enter a finished state.", failures)
	expect_true(
		_flow_events.has(&"dialogue_test_completed"),
		"Approved flow event effects must be emitted.",
		failures
	)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, &"intro"),
		"Completed dialogue lines must be marked as read.",
		failures
	)

	expect_true(runtime.start(sequence, game_state), "Read dialogue must be replayable.", failures)
	expect_true(runtime.can_skip_current_line(), "A read effect-free line must be skippable.", failures)
	expect_true(
		runtime.skip_read_lines() == 1,
		"Skip-read must stop at a choice instead of silently choosing a branch.",
		failures
	)
	expect_true(runtime.current_line.id == &"prompt", "Skip-read must stop on the prompt.", failures)

	game_state.reset_runtime_state()
	expect_true(
		not game_state.has_read_dialogue_line(sequence.id, &"intro"),
		"Runtime reset must clear read dialogue state.",
		failures
	)
	game_state.free()
	return failures


func _on_flow_event_emitted(event_id: StringName) -> void:
	_flow_events.append(event_id)
