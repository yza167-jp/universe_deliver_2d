class_name GameStateModel
extends Node

## Session data that must outlive stage scenes; persistence is intentionally handled later.
signal runtime_state_reset

var current_order_id: StringName = &""
var destination_id: StringName = &""
var cargo_id: StringName = &""
var ship_configuration: Dictionary[StringName, StringName] = {}
var story_flags: Dictionary[StringName, bool] = {}
var read_dialogue_ids: Dictionary[StringName, bool] = {}


func reset_runtime_state() -> void:
	current_order_id = &""
	destination_id = &""
	cargo_id = &""
	ship_configuration.clear()
	story_flags.clear()
	read_dialogue_ids.clear()
	runtime_state_reset.emit()


func set_story_flag(flag_id: StringName, enabled: bool = true) -> void:
	story_flags[flag_id] = enabled


func has_story_flag(flag_id: StringName) -> bool:
	return story_flags.get(flag_id, false)


func mark_dialogue_line_read(sequence_id: StringName, line_id: StringName) -> void:
	read_dialogue_ids[_get_dialogue_read_id(sequence_id, line_id)] = true


func has_read_dialogue_line(sequence_id: StringName, line_id: StringName) -> bool:
	return read_dialogue_ids.get(_get_dialogue_read_id(sequence_id, line_id), false)


func _get_dialogue_read_id(sequence_id: StringName, line_id: StringName) -> StringName:
	return StringName("%s/%s" % [sequence_id, line_id])
