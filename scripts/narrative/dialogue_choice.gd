class_name DialogueChoice
extends Resource

@export var id: StringName = &""
@export var text_key: StringName = &""
@export var conditions: Array[DialogueCondition] = []
@export var effects: Array[DialogueEffect] = []
@export var next_line_id: StringName = &""
