class_name DialogueSequence
extends Resource

@export var id: StringName = &""
@export var start_line_id: StringName = &""
@export var lines: Array[DialogueLine] = []


func find_line(line_id: StringName) -> DialogueLine:
	for line: DialogueLine in lines:
		if line != null and line.id == line_id:
			return line
	return null
