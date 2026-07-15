class_name DialogueRuntime
extends RefCounted

signal line_changed(line: DialogueLine)
signal dialogue_finished
signal flow_event_emitted(event_id: StringName)

const MAX_CONDITION_SKIPS: int = 128

var sequence: DialogueSequence
var current_line: DialogueLine
var last_error: String = ""

var _game_state: GameStateModel
var _is_running: bool = false


func start(dialogue_sequence: DialogueSequence, game_state: GameStateModel) -> bool:
	last_error = ""
	sequence = dialogue_sequence
	_game_state = game_state
	current_line = null
	_is_running = false
	if sequence == null:
		return _fail("DialogueSequence is missing.")
	if _game_state == null:
		return _fail("GameStateModel is missing.")
	if sequence.start_line_id.is_empty():
		return _fail("DialogueSequence '%s' has no start line." % sequence.id)

	_is_running = true
	return _move_to_line(sequence.start_line_id)


func is_running() -> bool:
	return _is_running


func get_available_choices() -> Array[DialogueChoice]:
	var available_choices: Array[DialogueChoice] = []
	if current_line == null:
		return available_choices
	for choice: DialogueChoice in current_line.choices:
		if choice != null and _conditions_are_met(choice.conditions):
			available_choices.append(choice)
	return available_choices


func advance() -> bool:
	last_error = ""
	if not _is_running or current_line == null:
		return _fail("No dialogue line is active.")
	if not get_available_choices().is_empty():
		return _fail("Dialogue line '%s' requires a choice." % current_line.id)

	var next_line_id: StringName = current_line.next_line_id
	_complete_current_line()
	return _move_to_line(next_line_id)


func select_choice(choice_id: StringName) -> bool:
	last_error = ""
	if not _is_running or current_line == null:
		return _fail("No dialogue line is active.")
	for choice: DialogueChoice in get_available_choices():
		if choice.id != choice_id:
			continue
		_complete_current_line()
		_apply_effects(choice.effects)
		return _move_to_line(choice.next_line_id)
	return _fail("Dialogue choice '%s' is unavailable." % choice_id)


func can_skip_current_line() -> bool:
	return (
		_is_running
		and current_line != null
		and current_line.choices.is_empty()
		and current_line.effects.is_empty()
		and _game_state.has_read_dialogue_line(sequence.id, current_line.id)
	)


## Skips only previously read, effect-free lines and stops before choices or new content.
func skip_read_lines(maximum_lines: int = MAX_CONDITION_SKIPS) -> int:
	var skipped_lines: int = 0
	while skipped_lines < maximum_lines and can_skip_current_line():
		if not advance():
			break
		skipped_lines += 1
	return skipped_lines


func _move_to_line(line_id: StringName) -> bool:
	var candidate_id: StringName = line_id
	var visited_ids: Dictionary[StringName, bool] = {}
	while not candidate_id.is_empty():
		if visited_ids.has(candidate_id):
			return _fail("DialogueSequence '%s' contains a condition-skip cycle." % sequence.id)
		visited_ids[candidate_id] = true
		if visited_ids.size() > MAX_CONDITION_SKIPS:
			return _fail("DialogueSequence '%s' exceeded the condition-skip limit." % sequence.id)

		var candidate: DialogueLine = sequence.find_line(candidate_id)
		if candidate == null:
			return _fail(
				"DialogueSequence '%s' references missing line '%s'." % [sequence.id, candidate_id]
			)
		if _conditions_are_met(candidate.conditions):
			current_line = candidate
			line_changed.emit(current_line)
			return true
		candidate_id = candidate.next_line_id

	_finish_dialogue()
	return true


func _complete_current_line() -> void:
	_game_state.mark_dialogue_line_read(sequence.id, current_line.id)
	_apply_effects(current_line.effects)


func _conditions_are_met(conditions: Array[DialogueCondition]) -> bool:
	for condition: DialogueCondition in conditions:
		if condition == null or not condition.is_met(_game_state):
			return false
	return true


func _apply_effects(effects: Array[DialogueEffect]) -> void:
	for effect: DialogueEffect in effects:
		if effect == null:
			continue
		match effect.effect_type:
			DialogueEffect.EffectType.SET_STORY_FLAG:
				_game_state.set_story_flag(effect.effect_id, effect.bool_value)
			DialogueEffect.EffectType.EMIT_FLOW_EVENT:
				flow_event_emitted.emit(effect.effect_id)


func _finish_dialogue() -> void:
	current_line = null
	_is_running = false
	dialogue_finished.emit()


func _fail(message: String) -> bool:
	last_error = message
	return false
