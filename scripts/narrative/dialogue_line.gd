class_name DialogueLine
extends Resource

@export var id: StringName = &""
@export var speaker: CharacterDefinition
@export var text_key: StringName = &""
@export var portrait_expression: StringName = &"neutral"
@export var conditions: Array[DialogueCondition] = []
@export var effects: Array[DialogueEffect] = []
@export var choices: Array[DialogueChoice] = []
@export var next_line_id: StringName = &""
