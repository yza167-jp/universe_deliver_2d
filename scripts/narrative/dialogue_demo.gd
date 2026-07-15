extends Control

@export var sequence: DialogueSequence

@onready var dialogue_ui: DialogueUI = %DialogueUI


func _ready() -> void:
	var game_state: GameStateModel = get_node_or_null("/root/GameState") as GameStateModel
	if game_state == null:
		push_error("Dialogue demo requires the GameState autoload.")
		return
	if not dialogue_ui.start_dialogue(sequence, game_state):
		push_error("Dialogue demo could not start its sequence.")
