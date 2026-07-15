class_name StationTutorialController
extends Node

signal tutorial_stage_changed(stage: Stage)
signal tutorial_completed

enum Stage {
	BOOTSTRAP,
	DIALOGUE,
	WAIT_FOR_MOVE,
	WAIT_FOR_LAO_PI,
	WAIT_FOR_ORDER_TERMINAL,
	COMPLETE,
}

const COMPLETION_FLAG: StringName = &"story_station_tutorial_completed"
const FLOW_WAIT_FOR_MOVE: StringName = &"station_tutorial_wait_for_move"
const FLOW_WAIT_FOR_LAO_PI: StringName = &"station_tutorial_wait_for_lao_pi"
const FLOW_WAIT_FOR_ORDER_TERMINAL: StringName = &"station_tutorial_wait_for_order_terminal"
const FLOW_COMPLETE: StringName = &"station_tutorial_completed"
const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/narrative/dialogue_ui.tscn")

@export_range(8.0, 160.0, 1.0) var required_movement_distance: float = 32.0
@export var intro_sequence: DialogueSequence
@export var movement_ack_sequence: DialogueSequence
@export var interaction_ack_sequence: DialogueSequence
@export var completion_sequence: DialogueSequence
@export var daily_sequence: DialogueSequence

var _stage: Stage = Stage.BOOTSTRAP
var _progress: StationTutorialProgress
var _game_state: GameStateModel
var _player: StationPlayer
var _lao_pi: LaoPiStation
var _order_terminal: Interactable2D
var _guide_anchor: Marker2D
var _dialogue_ui: DialogueUI
var _objective_root: Control
var _objective_label: Label
var _movement_origin: Vector2 = Vector2.ZERO
var _active_dialogue_id: StringName
var _pending_flow_event: StringName
var _fallback_dialogue_layer: CanvasLayer


func _ready() -> void:
	set_process(false)
	call_deferred("_initialize_tutorial")


func _process(_delta: float) -> void:
	if (
		_stage != Stage.WAIT_FOR_MOVE
		or _player == null
		or _progress == null
		or not _player.is_input_enabled()
	):
		return
	var distance_moved: float = _player.global_position.distance_to(_movement_origin)
	if _progress.record_movement(distance_moved, required_movement_distance):
		_resume_progression()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_objective()


func get_stage() -> Stage:
	return _stage


func get_progress() -> StationTutorialProgress:
	return _progress


func get_dialogue_ui() -> DialogueUI:
	return _dialogue_ui


func get_active_dialogue_id() -> StringName:
	return _active_dialogue_id


func get_objective_text() -> String:
	if _objective_label == null:
		return ""
	return _objective_label.text


func is_tutorial_complete() -> bool:
	return _stage == Stage.COMPLETE and _game_state != null and _game_state.has_story_flag(
		COMPLETION_FLAG
	)


func _initialize_tutorial() -> void:
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_lao_pi = get_node_or_null("../Characters/LaoPi") as LaoPiStation
	_order_terminal = get_node_or_null("../Interactables/OrderTerminal") as Interactable2D
	_guide_anchor = get_node_or_null("../TutorialAnchors/LaoPiGuideSpot") as Marker2D
	_objective_root = get_node_or_null(
		"../TutorialUILayer/TutorialObjective"
	) as Control
	_objective_label = get_node_or_null(
		"../TutorialUILayer/TutorialObjective/Panel/TutorialObjectiveLabel"
	) as Label
	_game_state = get_node_or_null("/root/GameState") as GameStateModel
	_dialogue_ui = _resolve_dialogue_ui()
	if (
		_player == null
		or _lao_pi == null
		or _order_terminal == null
		or _game_state == null
		or _dialogue_ui == null
	):
		push_error("Station tutorial could not resolve its required player, character, UI, or state.")
		return
	_connect_runtime_signals()
	var already_completed: bool = _game_state.has_story_flag(COMPLETION_FLAG)
	_progress = StationTutorialProgress.new(already_completed)
	_movement_origin = _player.global_position
	if already_completed:
		_player.set_input_enabled(true)
		_set_stage(Stage.COMPLETE)
		return
	_start_dialogue(intro_sequence)


func _resolve_dialogue_ui() -> DialogueUI:
	for node: Node in get_tree().get_nodes_in_group("dialogue_ui"):
		if node is DialogueUI:
			return node as DialogueUI
	var station_root: Node = get_parent()
	if station_root == null:
		return null
	_fallback_dialogue_layer = CanvasLayer.new()
	_fallback_dialogue_layer.name = "StationDialogueFallbackLayer"
	_fallback_dialogue_layer.layer = 30
	station_root.add_child(_fallback_dialogue_layer)
	var fallback_ui: DialogueUI = DIALOGUE_UI_SCENE.instantiate() as DialogueUI
	if fallback_ui == null:
		return null
	_fallback_dialogue_layer.add_child(fallback_ui)
	return fallback_ui


func _connect_runtime_signals() -> void:
	if not _lao_pi.interaction_triggered.is_connected(_on_lao_pi_interacted):
		_lao_pi.interaction_triggered.connect(_on_lao_pi_interacted)
	if not _order_terminal.interaction_triggered.is_connected(_on_order_terminal_interacted):
		_order_terminal.interaction_triggered.connect(_on_order_terminal_interacted)
	if not _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	if not _dialogue_ui.flow_event_emitted.is_connected(_on_flow_event_emitted):
		_dialogue_ui.flow_event_emitted.connect(_on_flow_event_emitted)


func _on_lao_pi_interacted(_actor: Node) -> void:
	if _progress == null:
		return
	if _stage == Stage.COMPLETE:
		_start_dialogue(daily_sequence)
		return
	_progress.record_interaction(StationTutorialProgress.LAO_PI_INTERACTION_ID)
	_resume_progression()


func _on_order_terminal_interacted(_actor: Node) -> void:
	if _progress == null or _stage == Stage.COMPLETE:
		return
	_progress.record_interaction(StationTutorialProgress.ORDER_TERMINAL_INTERACTION_ID)
	_resume_progression()


func _resume_progression() -> void:
	if not _active_dialogue_id.is_empty() or _progress == null:
		return
	match _stage:
		Stage.WAIT_FOR_MOVE:
			if _progress.get_requirement() != StationTutorialProgress.Requirement.MOVE:
				if _guide_anchor != null:
					_lao_pi.move_to(_guide_anchor.global_position)
				_start_dialogue(movement_ack_sequence)
		Stage.WAIT_FOR_LAO_PI:
			if (
				_progress.get_requirement()
				!= StationTutorialProgress.Requirement.LAO_PI_INTERACTION
			):
				_start_dialogue(interaction_ack_sequence)
		Stage.WAIT_FOR_ORDER_TERMINAL:
			if _progress.get_requirement() == StationTutorialProgress.Requirement.COMPLETE:
				_start_dialogue(completion_sequence)


func _start_dialogue(sequence: DialogueSequence) -> bool:
	if sequence == null or _dialogue_ui == null or not _active_dialogue_id.is_empty():
		return false
	_active_dialogue_id = sequence.id
	_pending_flow_event = StringName()
	_set_stage(Stage.DIALOGUE)
	_player.set_input_enabled(false)
	_lao_pi.face_toward(_player.global_position)
	_lao_pi.set_talking(true)
	if _dialogue_ui.start_dialogue(sequence, _game_state):
		return true
	_lao_pi.set_talking(false)
	_player.set_input_enabled(true)
	_active_dialogue_id = StringName()
	push_error("Station tutorial could not start dialogue sequence '%s'." % sequence.id)
	return false


func _on_flow_event_emitted(event_id: StringName) -> void:
	if event_id in [
		FLOW_WAIT_FOR_MOVE,
		FLOW_WAIT_FOR_LAO_PI,
		FLOW_WAIT_FOR_ORDER_TERMINAL,
		FLOW_COMPLETE,
	]:
		_pending_flow_event = event_id


func _on_dialogue_finished() -> void:
	var finished_dialogue_id: StringName = _active_dialogue_id
	_active_dialogue_id = StringName()
	_lao_pi.set_talking(false)
	_player.set_input_enabled(true)
	match _pending_flow_event:
		FLOW_WAIT_FOR_MOVE:
			_movement_origin = _player.global_position
			_set_stage(Stage.WAIT_FOR_MOVE)
		FLOW_WAIT_FOR_LAO_PI:
			_set_stage(Stage.WAIT_FOR_LAO_PI)
		FLOW_WAIT_FOR_ORDER_TERMINAL:
			_set_stage(Stage.WAIT_FOR_ORDER_TERMINAL)
		FLOW_COMPLETE:
			_game_state.set_story_flag(COMPLETION_FLAG)
			_set_stage(Stage.COMPLETE)
			tutorial_completed.emit()
		_:
			if daily_sequence != null and finished_dialogue_id == daily_sequence.id:
				_set_stage(Stage.COMPLETE)
			else:
				_apply_safe_fallback_for_sequence(finished_dialogue_id)
	_pending_flow_event = StringName()
	call_deferred("_resume_progression")


func _apply_safe_fallback_for_sequence(sequence_id: StringName) -> void:
	if intro_sequence != null and sequence_id == intro_sequence.id:
		_movement_origin = _player.global_position
		_set_stage(Stage.WAIT_FOR_MOVE)
	elif movement_ack_sequence != null and sequence_id == movement_ack_sequence.id:
		_set_stage(Stage.WAIT_FOR_LAO_PI)
	elif interaction_ack_sequence != null and sequence_id == interaction_ack_sequence.id:
		_set_stage(Stage.WAIT_FOR_ORDER_TERMINAL)
	elif completion_sequence != null and sequence_id == completion_sequence.id:
		_game_state.set_story_flag(COMPLETION_FLAG)
		_set_stage(Stage.COMPLETE)
		tutorial_completed.emit()


func _set_stage(new_stage: Stage) -> void:
	if _stage == new_stage:
		_update_objective()
		return
	_stage = new_stage
	set_process(_stage == Stage.WAIT_FOR_MOVE)
	_update_objective()
	tutorial_stage_changed.emit(_stage)


func _update_objective() -> void:
	if _objective_root == null or _objective_label == null:
		return
	var objective_key: String = ""
	match _stage:
		Stage.WAIT_FOR_MOVE:
			objective_key = "UI_TUTORIAL_OBJECTIVE_MOVE"
		Stage.WAIT_FOR_LAO_PI:
			objective_key = "UI_TUTORIAL_OBJECTIVE_TALK_TO_LAO_PI"
		Stage.WAIT_FOR_ORDER_TERMINAL:
			objective_key = "UI_TUTORIAL_OBJECTIVE_ORDER_TERMINAL"
		_:
			_objective_root.visible = false
			_objective_label.text = ""
			return
	_objective_root.visible = true
	_objective_label.text = tr(objective_key)
