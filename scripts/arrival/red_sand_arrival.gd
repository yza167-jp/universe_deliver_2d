class_name RedSandArrival
extends Node2D

signal exploration_unlocked
signal optional_interaction_completed(interaction_id: StringName)

enum DialogueKind {
	NONE,
	MAIN,
	OPTIONAL,
}

const BASE_VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)
const AREA_SIZE: Vector2 = Vector2(960.0, 360.0)
const WALKABLE_RECT: Rect2 = Rect2(40.0, 205.0, 880.0, 125.0)
const CAMERA_HALF_WIDTH: float = BASE_VIEWPORT_SIZE.x * 0.5
const CAMERA_CENTER_Y: float = BASE_VIEWPORT_SIZE.y * 0.5
const STATUS_DURATION_SECONDS: float = 5.0
const MODAL_DIALOGUE: StringName = &"arrival_dialogue"
const MODAL_OBSERVATION: StringName = &"arrival_observation"
const MODAL_RETURN_TRANSITION: StringName = &"arrival_return_transition"
const STORY_MAIN_DIALOGUE_COMPLETED: StringName = (
	&"story_red_sand_arrival_main_dialogue_completed"
)
const STORY_OPTIONAL_DIALOGUE_COMPLETED: StringName = (
	&"story_red_sand_arrival_optional_dialogue_completed"
)
const STORY_RECORD_INSPECTED: StringName = &"story_red_sand_order_record_inspected"
const OPTIONAL_TALK_TRIGGER_ID: StringName = &"red_sand_optional_technician_talk"
const RECORD_INSPECTION_TRIGGER_ID: StringName = &"red_sand_order_record_inspected"
const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/narrative/dialogue_ui.tscn")

const SKY_DARK: Color = Color("24151d")
const SKY_RUST: Color = Color("5d2e2a")
const DUNE_FAR: Color = Color("7b4230")
const DUNE_NEAR: Color = Color("a35b38")
const GROUND_DARK: Color = Color("34232a")
const GROUND_EDGE: Color = Color("d1844e")
const FACILITY_DARK: Color = Color("24313a")
const FACILITY_MID: Color = Color("38505a")
const FACILITY_LIGHT: Color = Color("6f8f8e")
const SIGNAL_CYAN: Color = Color("77c9c4")
const WARM_AMBER: Color = Color("e7a85b")
const PIPE_RUST: Color = Color("8b4e38")

@export var main_dialogue_sequence: DialogueSequence
@export var optional_dialogue_sequence: DialogueSequence

@onready var _player: StationPlayer = %StationPlayer
@onready var _modal_coordinator: SceneModalCoordinator = %SceneModalCoordinator
@onready var _camera: Camera2D = %Camera2D
@onready var _technician: Interactable2D = %Technician
@onready var _record_terminal: Interactable2D = %RecordTerminal
@onready var _return_beacon: Interactable2D = %ReturnBeacon
@onready var _landing_feedback_label: Label = %LandingFeedbackLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel

var game_state_override: GameStateModel
var dialogue_ui_override: DialogueUI
var scene_router_override: SceneRouterService

var _dialogue_ui: DialogueUI
var _active_dialogue_kind: DialogueKind = DialogueKind.NONE
var _exploration_is_unlocked: bool = false
var _status_time_remaining: float = 0.0
var _status_key: StringName = &""
var _fallback_dialogue_layer: CanvasLayer


func _ready() -> void:
	_connect_interactions()
	_objective_label.visible = false
	_status_panel.visible = false
	_modal_coordinator.begin_modal(MODAL_DIALOGUE)
	refresh_landing_feedback()
	_update_camera_for_player()
	call_deferred("_begin_arrival_flow")


func _process(delta: float) -> void:
	if _status_time_remaining <= 0.0:
		return
	_status_time_remaining = maxf(_status_time_remaining - delta, 0.0)
	if is_zero_approx(_status_time_remaining):
		_hide_status()


func _physics_process(_delta: float) -> void:
	_update_camera_for_player()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_landing_feedback()
		if _exploration_is_unlocked:
			_objective_label.text = tr("UI_RED_SAND_ARRIVAL_OBJECTIVE_EXPLORE")
		if not _status_key.is_empty():
			_status_label.text = tr(String(_status_key))


func refresh_landing_feedback() -> void:
	if _landing_feedback_label == null:
		return
	var run_state: OrderRunState = _get_active_run_state()
	if run_state == null or run_state.landing_result.is_empty():
		_landing_feedback_label.visible = false
		_landing_feedback_label.text = ""
		return
	var feedback_key: StringName = &""
	match run_state.landing_result:
		OrderRunState.LANDING_RESULT_SMOOTH:
			feedback_key = &"UI_RED_SAND_ARRIVAL_LANDING_SMOOTH"
		OrderRunState.LANDING_RESULT_ROUGH:
			feedback_key = &"UI_RED_SAND_ARRIVAL_LANDING_ROUGH"
		_:
			_landing_feedback_label.visible = false
			_landing_feedback_label.text = ""
			return
	_landing_feedback_label.text = tr(feedback_key) % roundi(run_state.cargo_integrity)
	_landing_feedback_label.visible = true


func get_landing_feedback_text() -> String:
	return "" if _landing_feedback_label == null else _landing_feedback_label.text


func get_station_player() -> StationPlayer:
	return _player


func get_dialogue_ui() -> DialogueUI:
	return _dialogue_ui


func get_modal_coordinator() -> SceneModalCoordinator:
	return _modal_coordinator


func get_technician() -> Interactable2D:
	return _technician


func get_record_terminal() -> Interactable2D:
	return _record_terminal


func get_return_beacon() -> Interactable2D:
	return _return_beacon


func get_interactables() -> Array[Interactable2D]:
	return [_technician, _record_terminal, _return_beacon]


func is_exploration_unlocked() -> bool:
	return _exploration_is_unlocked


func is_main_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.MAIN


func is_optional_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.OPTIONAL


func get_objective_text() -> String:
	return "" if _objective_label == null else _objective_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_area_rect() -> Rect2:
	return Rect2(Vector2.ZERO, AREA_SIZE)


func get_walkable_rect() -> Rect2:
	return WALKABLE_RECT


func get_area_width_in_viewports() -> float:
	return AREA_SIZE.x / BASE_VIEWPORT_SIZE.x


func get_camera_world_rect() -> Rect2:
	if _camera == null:
		return Rect2()
	return Rect2(_camera.global_position - BASE_VIEWPORT_SIZE * 0.5, BASE_VIEWPORT_SIZE)


func _begin_arrival_flow() -> void:
	var game_state: GameStateModel = _resolve_game_state()
	_dialogue_ui = _resolve_dialogue_ui()
	if game_state == null or _dialogue_ui == null:
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		push_error("Red Sand arrival could not resolve GameState or DialogueUI.")
		return
	if game_state.has_story_flag(STORY_MAIN_DIALOGUE_COMPLETED):
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		_unlock_exploration()
		return
	if not _start_dialogue(main_dialogue_sequence, DialogueKind.MAIN):
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		push_error("Red Sand arrival could not start its main delivery dialogue.")


func _connect_interactions() -> void:
	if not _technician.interaction_triggered.is_connected(_on_technician_interacted):
		_technician.interaction_triggered.connect(_on_technician_interacted)
	if not _record_terminal.interaction_triggered.is_connected(_on_record_terminal_interacted):
		_record_terminal.interaction_triggered.connect(_on_record_terminal_interacted)
	if not _return_beacon.interaction_triggered.is_connected(_on_return_beacon_interacted):
		_return_beacon.interaction_triggered.connect(_on_return_beacon_interacted)


func _start_dialogue(sequence: DialogueSequence, kind: DialogueKind) -> bool:
	if sequence == null or kind == DialogueKind.NONE or _active_dialogue_kind != DialogueKind.NONE:
		return false
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return false
	if _dialogue_ui == null:
		_dialogue_ui = _resolve_dialogue_ui()
	if _dialogue_ui == null:
		return false
	if not _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	if (
		not _modal_coordinator.has_modal(MODAL_DIALOGUE)
		and not _modal_coordinator.begin_modal(MODAL_DIALOGUE)
	):
		return false
	_active_dialogue_kind = kind
	_objective_label.visible = false
	if _dialogue_ui.start_dialogue(sequence, game_state):
		return true
	_active_dialogue_kind = DialogueKind.NONE
	_modal_coordinator.end_modal(MODAL_DIALOGUE)
	return false


func _on_dialogue_finished() -> void:
	var finished_kind: DialogueKind = _active_dialogue_kind
	_active_dialogue_kind = DialogueKind.NONE
	_modal_coordinator.end_modal(MODAL_DIALOGUE)
	var game_state: GameStateModel = _resolve_game_state()
	if finished_kind == DialogueKind.MAIN:
		if game_state != null:
			# A canceled first presentation must not leave the destination permanently locked.
			game_state.set_story_flag(STORY_MAIN_DIALOGUE_COMPLETED)
		_unlock_exploration()
		return
	if finished_kind == DialogueKind.OPTIONAL:
		if (
			game_state != null
			and game_state.has_story_flag(STORY_OPTIONAL_DIALOGUE_COMPLETED)
		):
			_record_optional_trigger(OPTIONAL_TALK_TRIGGER_ID)
			_show_status(&"UI_RED_SAND_ARRIVAL_STATUS_OPTIONAL_TALK")
		_unlock_exploration()


func _unlock_exploration() -> void:
	var was_unlocked: bool = _exploration_is_unlocked
	_exploration_is_unlocked = true
	if not _modal_coordinator.is_modal_active():
		_player.set_input_enabled(true)
		_player.set_interaction_prompt_suppressed(false)
	_objective_label.text = tr("UI_RED_SAND_ARRIVAL_OBJECTIVE_EXPLORE")
	_objective_label.visible = true
	if not was_unlocked:
		exploration_unlocked.emit()


func _on_technician_interacted(_actor: Node) -> void:
	if not _exploration_is_unlocked:
		return
	_start_dialogue(optional_dialogue_sequence, DialogueKind.OPTIONAL)


func _on_record_terminal_interacted(_actor: Node) -> void:
	if not _exploration_is_unlocked or _active_dialogue_kind != DialogueKind.NONE:
		return
	var game_state: GameStateModel = _resolve_game_state()
	if game_state != null:
		game_state.set_story_flag(STORY_RECORD_INSPECTED)
	_record_optional_trigger(RECORD_INSPECTION_TRIGGER_ID)
	_show_status(&"UI_RED_SAND_ARRIVAL_RECORD_DETAIL")


func _on_return_beacon_interacted(_actor: Node) -> void:
	if (
		not _exploration_is_unlocked
		or _active_dialogue_kind != DialogueKind.NONE
		or _modal_coordinator.is_modal_active()
	):
		return
	var scene_router: SceneRouterService = _resolve_scene_router()
	if scene_router == null:
		_show_status(&"UI_RED_SAND_ARRIVAL_STATUS_RETURN_ERROR")
		return
	if not _modal_coordinator.begin_modal(MODAL_RETURN_TRANSITION):
		return
	_objective_label.text = tr("UI_RED_SAND_ARRIVAL_OBJECTIVE_RETURNING")
	if scene_router.request_stage(SceneRouterService.Stage.RESULTS):
		return
	_modal_coordinator.end_modal(MODAL_RETURN_TRANSITION)
	_objective_label.text = tr("UI_RED_SAND_ARRIVAL_OBJECTIVE_EXPLORE")
	_show_status(&"UI_RED_SAND_ARRIVAL_STATUS_RETURN_ERROR")


func _record_optional_trigger(trigger_id: StringName) -> void:
	var run_state: OrderRunState = _get_active_run_state()
	if run_state != null and not run_state.optional_trigger_ids.has(trigger_id):
		run_state.optional_trigger_ids.append(trigger_id)
	optional_interaction_completed.emit(trigger_id)


func _show_status(message_key: StringName) -> void:
	_status_key = message_key
	_status_label.text = tr(String(message_key))
	_status_panel.visible = true
	_status_time_remaining = STATUS_DURATION_SECONDS
	_modal_coordinator.begin_modal(MODAL_OBSERVATION)


func _hide_status() -> void:
	_status_panel.visible = false
	_status_label.text = ""
	_status_key = &""
	_status_time_remaining = 0.0
	_modal_coordinator.end_modal(MODAL_OBSERVATION)


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _get_active_run_state() -> OrderRunState:
	var game_state: GameStateModel = _resolve_game_state()
	return game_state.get_active_order_run_state() if game_state != null else null


func _resolve_dialogue_ui() -> DialogueUI:
	if dialogue_ui_override != null:
		return dialogue_ui_override
	for node: Node in get_tree().get_nodes_in_group("dialogue_ui"):
		if node is DialogueUI:
			return node as DialogueUI
	_fallback_dialogue_layer = CanvasLayer.new()
	_fallback_dialogue_layer.name = "ArrivalDialogueFallbackLayer"
	_fallback_dialogue_layer.layer = 30
	add_child(_fallback_dialogue_layer)
	var fallback_ui: DialogueUI = DIALOGUE_UI_SCENE.instantiate() as DialogueUI
	if fallback_ui == null:
		return null
	_fallback_dialogue_layer.add_child(fallback_ui)
	return fallback_ui


func _update_camera_for_player() -> void:
	if _camera == null or _player == null:
		return
	_camera.global_position = Vector2(
		clampf(
			_player.global_position.x,
			CAMERA_HALF_WIDTH,
			AREA_SIZE.x - CAMERA_HALF_WIDTH
		),
		CAMERA_CENTER_Y
	)


func _draw() -> void:
	draw_rect(get_area_rect(), SKY_DARK, true)
	draw_rect(Rect2(0.0, 88.0, AREA_SIZE.x, 152.0), SKY_RUST, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 178.0), Vector2(92.0, 140.0), Vector2(210.0, 171.0),
			Vector2(346.0, 126.0), Vector2(494.0, 174.0), Vector2(650.0, 136.0),
			Vector2(806.0, 166.0), Vector2(960.0, 118.0), Vector2(960.0, 240.0),
			Vector2(0.0, 240.0),
		]),
		DUNE_FAR
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 218.0), Vector2(126.0, 176.0), Vector2(252.0, 213.0),
			Vector2(390.0, 182.0), Vector2(536.0, 220.0), Vector2(700.0, 171.0),
			Vector2(842.0, 207.0), Vector2(960.0, 184.0), Vector2(960.0, 254.0),
			Vector2(0.0, 254.0),
		]),
		DUNE_NEAR
	)
	draw_rect(Rect2(0.0, 230.0, AREA_SIZE.x, 130.0), GROUND_DARK, true)
	draw_line(Vector2(0.0, 230.0), Vector2(AREA_SIZE.x, 230.0), GROUND_EDGE, 3.0)
	_draw_landing_pad()
	_draw_repair_building()
	_draw_cooling_lines()


func _draw_landing_pad() -> void:
	draw_rect(Rect2(34.0, 256.0, 286.0, 50.0), FACILITY_DARK, true)
	draw_rect(Rect2(34.0, 256.0, 286.0, 50.0), SIGNAL_CYAN, false, 3.0)
	for x: float in [54.0, 104.0, 154.0, 204.0, 254.0, 304.0]:
		draw_circle(Vector2(x, 260.0), 3.0, WARM_AMBER)
	draw_line(Vector2(58.0, 282.0), Vector2(286.0, 282.0), FACILITY_LIGHT, 2.0)


func _draw_repair_building() -> void:
	draw_rect(Rect2(400.0, 116.0, 220.0, 104.0), FACILITY_DARK, true)
	draw_rect(Rect2(400.0, 116.0, 220.0, 104.0), FACILITY_LIGHT, false, 3.0)
	draw_rect(Rect2(418.0, 138.0, 72.0, 48.0), FACILITY_MID, true)
	draw_rect(Rect2(510.0, 136.0, 88.0, 26.0), SIGNAL_CYAN.darkened(0.48), true)
	for x: float in [426.0, 448.0, 470.0]:
		draw_rect(Rect2(x, 194.0, 10.0, 18.0), PIPE_RUST, true)
	draw_line(Vector2(410.0, 126.0), Vector2(610.0, 126.0), WARM_AMBER, 2.0)


func _draw_cooling_lines() -> void:
	draw_line(Vector2(320.0, 302.0), Vector2(902.0, 302.0), PIPE_RUST, 8.0)
	draw_line(Vector2(320.0, 302.0), Vector2(902.0, 302.0), WARM_AMBER.darkened(0.4), 2.0)
	for x: float in [352.0, 648.0, 878.0]:
		draw_line(Vector2(x, 302.0), Vector2(x, 250.0), PIPE_RUST, 8.0)
		draw_circle(Vector2(x, 250.0), 9.0, FACILITY_MID)
		draw_circle(Vector2(x, 250.0), 4.0, SIGNAL_CYAN)
