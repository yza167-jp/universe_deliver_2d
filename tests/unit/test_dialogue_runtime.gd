extends ProjectTestSuite

const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"

var _flow_events: Array[StringName] = []
var _dialogue_finished_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	var sequence: DialogueSequence = load(DIALOGUE_PATH) as DialogueSequence
	_test_normal_completion(sequence, failures)
	_test_read_line_skip(sequence, failures)
	_test_linear_sequence_skip(failures)
	_test_choice_safe_sequence_skip(sequence, failures)
	_test_cancel_is_idempotent(sequence, failures)
	return failures


func _test_normal_completion(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	_reset_signal_counters()
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_connect_runtime(runtime)

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
		_dialogue_finished_count == 1,
		"Normal completion must emit dialogue_finished exactly once.",
		failures
	)
	expect_true(
		_flow_events.count(&"dialogue_test_completed") == 1,
		"Normal completion must emit its final flow event exactly once.",
		failures
	)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, &"intro"),
		"Completed dialogue lines must be marked as read.",
		failures
	)
	expect_true(not runtime.advance(), "Finished dialogue must reject another advance.", failures)
	expect_true(not runtime.cancel(), "Finished dialogue must reject another finish request.", failures)
	expect_true(
		_dialogue_finished_count == 1,
		"Repeated finish requests must not emit dialogue_finished again.",
		failures
	)
	expect_true(
		_flow_events.count(&"dialogue_test_completed") == 1,
		"Repeated finish requests must not replay completion effects.",
		failures
	)
	game_state.free()


func _test_read_line_skip(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.mark_dialogue_line_read(sequence.id, &"intro")
	var runtime: DialogueRuntime = DialogueRuntime.new()
	expect_true(runtime.start(sequence, game_state), "Read dialogue must be replayable.", failures)
	expect_true(runtime.can_skip_current_line(), "A read effect-free line must be skippable.", failures)
	expect_true(
		runtime.skip_read_lines() == 1,
		"Skip-read must stop at a choice instead of silently choosing a branch.",
		failures
	)
	expect_true(runtime.current_line.id == &"prompt", "Skip-read must stop on the prompt.", failures)
	expect_true(runtime.cancel(), "Read-line skip test must close its active runtime.", failures)
	game_state.reset_runtime_state()
	expect_true(
		not game_state.has_read_dialogue_line(sequence.id, &"intro"),
		"Runtime reset must clear read dialogue state.",
		failures
	)
	game_state.free()


func _test_linear_sequence_skip(failures: Array[String]) -> void:
	_reset_signal_counters()
	var sequence: DialogueSequence = _create_linear_skip_sequence()
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_connect_runtime(runtime)

	expect_true(runtime.start(sequence, game_state), "Linear skip sequence must start.", failures)
	var result: DialogueRuntime.SequenceSkipResult = runtime.skip_sequence()
	expect_true(
		result == DialogueRuntime.SequenceSkipResult.FINISHED,
		"A linear sequence skip must finish the sequence.",
		failures
	)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, &"linear_start")
		and game_state.has_read_dialogue_line(sequence.id, &"linear_finish"),
		"Every skipped linear line must be marked as read.",
		failures
	)
	expect_true(
		game_state.has_story_flag(&"story_dialogue_linear_skipped"),
		"Sequence skip must apply story-flag effects from skipped lines.",
		failures
	)
	expect_true(
		_flow_events.count(&"dialogue_linear_completed") == 1,
		"Sequence skip must apply completion effects exactly once.",
		failures
	)
	expect_true(
		_dialogue_finished_count == 1,
		"Sequence skip must emit dialogue_finished exactly once.",
		failures
	)
	expect_true(
		runtime.skip_sequence() == DialogueRuntime.SequenceSkipResult.REJECTED,
		"A completed sequence must reject repeated skip requests.",
		failures
	)
	expect_true(not runtime.cancel(), "A skipped sequence must reject repeated finish requests.", failures)
	expect_true(
		_dialogue_finished_count == 1
		and _flow_events.count(&"dialogue_linear_completed") == 1,
		"Repeated requests must not duplicate completion or effects.",
		failures
	)
	game_state.free()


func _test_choice_safe_sequence_skip(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	_reset_signal_counters()
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_connect_runtime(runtime)

	expect_true(runtime.start(sequence, game_state), "Choice skip sequence must start.", failures)
	var result: DialogueRuntime.SequenceSkipResult = runtime.skip_sequence()
	expect_true(
		result == DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"Sequence skip must stop at the nearest choice.",
		failures
	)
	expect_true(runtime.current_line.id == &"prompt", "Sequence skip must reveal the choice prompt.", failures)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, &"intro")
		and not game_state.has_read_dialogue_line(sequence.id, &"prompt"),
		"Sequence skip must mark prior lines read without completing the choice prompt.",
		failures
	)
	expect_true(
		not game_state.has_story_flag(&"story_dialogue_test_professional")
		and not game_state.has_story_flag(&"story_dialogue_test_equipment_first"),
		"Stopping at a choice must not select any branch.",
		failures
	)
	expect_true(
		runtime.skip_sequence() == DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"Repeated skip at a choice must remain safely stopped.",
		failures
	)
	expect_true(
		_dialogue_finished_count == 0,
		"Stopping at a choice must not finish the sequence.",
		failures
	)
	expect_true(
		not runtime.advance() and runtime.current_line.id == &"prompt",
		"A choice prompt must reject non-choice advancement after sequence skip.",
		failures
	)
	expect_true(
		runtime.select_choice(&"follow_process"),
		"Player choice must remain available after sequence skip.",
		failures
	)
	expect_true(
		runtime.skip_sequence() == DialogueRuntime.SequenceSkipResult.FINISHED,
		"Sequence skip must finish linear content after an explicit choice.",
		failures
	)
	expect_true(
		game_state.has_story_flag(&"story_dialogue_test_professional")
		and not game_state.has_story_flag(&"story_dialogue_test_equipment_first"),
		"Only the explicit player choice may apply its branch effect.",
		failures
	)
	expect_true(
		game_state.has_read_dialogue_line(sequence.id, &"prompt")
		and game_state.has_read_dialogue_line(sequence.id, &"process_response")
		and game_state.has_read_dialogue_line(sequence.id, &"finish"),
		"Choice and post-choice linear content must be marked as read.",
		failures
	)
	expect_true(
		_dialogue_finished_count == 1
		and _flow_events.count(&"dialogue_test_completed") == 1,
		"Post-choice sequence skip must complete exactly once.",
		failures
	)
	game_state.free()


func _test_cancel_is_idempotent(
	sequence: DialogueSequence,
	failures: Array[String]
) -> void:
	_reset_signal_counters()
	var game_state: GameStateModel = GameStateModel.new()
	var runtime: DialogueRuntime = DialogueRuntime.new()
	_connect_runtime(runtime)
	expect_true(runtime.start(sequence, game_state), "Cancelable dialogue must start.", failures)
	expect_true(runtime.cancel(), "Active dialogue must support modal cancellation.", failures)
	expect_true(not runtime.is_running(), "Canceled dialogue must stop running.", failures)
	expect_true(
		not game_state.has_read_dialogue_line(sequence.id, &"intro"),
		"Canceling must not mark the visible line as completed.",
		failures
	)
	expect_true(not runtime.cancel(), "Repeated cancellation must be rejected.", failures)
	expect_true(
		_dialogue_finished_count == 1,
		"Repeated cancellation must not emit dialogue_finished again.",
		failures
	)
	game_state.free()


func _create_linear_skip_sequence() -> DialogueSequence:
	var story_effect: DialogueEffect = DialogueEffect.new()
	story_effect.effect_type = DialogueEffect.EffectType.SET_STORY_FLAG
	story_effect.effect_id = &"story_dialogue_linear_skipped"
	var story_effects: Array[DialogueEffect] = [story_effect]

	var completion_effect: DialogueEffect = DialogueEffect.new()
	completion_effect.effect_type = DialogueEffect.EffectType.EMIT_FLOW_EVENT
	completion_effect.effect_id = &"dialogue_linear_completed"
	var completion_effects: Array[DialogueEffect] = [completion_effect]

	var start_line: DialogueLine = DialogueLine.new()
	start_line.id = &"linear_start"
	start_line.text_key = &"DIALOGUE_TEST_INTRO"
	start_line.effects = story_effects
	start_line.next_line_id = &"linear_finish"

	var finish_line: DialogueLine = DialogueLine.new()
	finish_line.id = &"linear_finish"
	finish_line.text_key = &"DIALOGUE_TEST_FINISH"
	finish_line.effects = completion_effects

	var lines: Array[DialogueLine] = [start_line, finish_line]
	var sequence: DialogueSequence = DialogueSequence.new()
	sequence.id = &"dialogue_linear_skip_test"
	sequence.start_line_id = start_line.id
	sequence.lines = lines
	return sequence


func _connect_runtime(runtime: DialogueRuntime) -> void:
	runtime.flow_event_emitted.connect(_on_flow_event_emitted)
	runtime.dialogue_finished.connect(_on_dialogue_finished)


func _reset_signal_counters() -> void:
	_flow_events.clear()
	_dialogue_finished_count = 0


func _on_flow_event_emitted(event_id: StringName) -> void:
	_flow_events.append(event_id)


func _on_dialogue_finished() -> void:
	_dialogue_finished_count += 1
