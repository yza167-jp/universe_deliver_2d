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
const REVISIT_OPTIONAL_TALK_TRIGGER_ID: StringName = (
	&"red_sand_revisit_optional_technician_talk"
)
const REVISIT_RECORD_INSPECTION_TRIGGER_ID: StringName = (
	&"red_sand_revisit_record_inspected"
)
const REVISIT_COOLING_INSPECTION_TRIGGER_ID: StringName = (
	&"red_sand_revisit_cooling_equipment_inspected"
)
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
@export var revisit_contract: RedSandRevisitContract

@onready var _player: StationPlayer = %StationPlayer
@onready var _modal_coordinator: SceneModalCoordinator = %SceneModalCoordinator
@onready var _camera: Camera2D = %Camera2D
@onready var _technician: Interactable2D = %Technician
@onready var _record_terminal: Interactable2D = %RecordTerminal
@onready var _return_beacon: Interactable2D = %ReturnBeacon
@onready var _cooling_equipment: Interactable2D = %CoolingEquipment
@onready var _landing_feedback_label: Label = %LandingFeedbackLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _location_label: Label = %LocationLabel
@onready var _scope_label: Label = %ScopeLabel
@onready var _record_label: Label = %RecordLabel
@onready var _cooling_equipment_label: Label = %CoolingEquipmentLabel

var game_state_override: GameStateModel
var dialogue_ui_override: DialogueUI
var scene_router_override: SceneRouterService

var _dialogue_ui: DialogueUI
var _active_dialogue_kind: DialogueKind = DialogueKind.NONE
var _exploration_is_unlocked: bool = false
var _status_time_remaining: float = 0.0
var _status_key: StringName = &""
var _status_dismissal_armed: bool = false
var _fallback_dialogue_layer: CanvasLayer
var _is_revisit: bool = false
var _steam_phase: float = 0.0


func _ready() -> void:
	_is_revisit = _resolve_is_revisit()
	_configure_variant_presentation()
	_connect_interactions()
	_objective_label.visible = false
	_status_panel.visible = false
	_modal_coordinator.begin_modal(MODAL_DIALOGUE)
	refresh_landing_feedback()
	_update_camera_for_player()
	call_deferred("_begin_arrival_flow")


func _process(delta: float) -> void:
	if _is_revisit:
		_steam_phase = fmod(
			_steam_phase + maxf(delta, 0.0) * 0.48,
			1.0
		)
		queue_redraw()
	if _status_time_remaining > 0.0:
		_status_time_remaining = maxf(_status_time_remaining - delta, 0.0)
		if is_zero_approx(_status_time_remaining):
			_hide_status()


func _physics_process(_delta: float) -> void:
	_update_camera_for_player()


func _unhandled_input(event: InputEvent) -> void:
	if (
		_status_dismissal_armed
		and _status_time_remaining > 0.0
		and event.is_action_pressed(&"ui_accept")
	):
		dismiss_status()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_landing_feedback()
		if _exploration_is_unlocked:
			_objective_label.text = tr(_get_exploration_objective_key())
		_refresh_variant_labels()
		if not _status_key.is_empty():
			_status_label.text = _format_status_text(_status_key)


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
			feedback_key = (
				revisit_contract.arrival_landing_smooth_key
				if _is_revisit and revisit_contract != null
				else &"UI_RED_SAND_ARRIVAL_LANDING_SMOOTH"
			)
		OrderRunState.LANDING_RESULT_ROUGH:
			feedback_key = (
				revisit_contract.arrival_landing_rough_key
				if _is_revisit and revisit_contract != null
				else &"UI_RED_SAND_ARRIVAL_LANDING_ROUGH"
			)
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


func get_cooling_equipment() -> Interactable2D:
	return _cooling_equipment


func get_interactables() -> Array[Interactable2D]:
	var interactables: Array[Interactable2D] = [
		_technician,
		_record_terminal,
		_return_beacon,
	]
	if _is_revisit:
		interactables.append(_cooling_equipment)
	return interactables


func is_exploration_unlocked() -> bool:
	return _exploration_is_unlocked


func is_main_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.MAIN


func is_optional_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.OPTIONAL


func is_revisit() -> bool:
	return _is_revisit


func get_objective_text() -> String:
	return "" if _objective_label == null else _objective_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func dismiss_status() -> bool:
	if _status_time_remaining <= 0.0:
		return false
	_hide_status()
	return true


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
	if game_state.has_story_flag(_get_main_completion_flag()):
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
	if (
		_cooling_equipment != null
		and not _cooling_equipment.interaction_triggered.is_connected(
			_on_cooling_equipment_interacted
		)
	):
		_cooling_equipment.interaction_triggered.connect(
			_on_cooling_equipment_interacted
		)


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
		if game_state != null and not _is_revisit:
			# A canceled first presentation must not leave the destination permanently locked.
			game_state.set_story_flag(STORY_MAIN_DIALOGUE_COMPLETED)
		if _is_revisit and not _is_revisit_delivery_ready(game_state):
			_unlock_exploration()
			_show_status(&"UI_M1_RED_SAND_REVISIT_STATUS_DELIVERY_PENDING")
			return
		queue_redraw()
		_unlock_exploration()
		return
	if finished_kind == DialogueKind.OPTIONAL:
		if (
			game_state != null
			and (
				(
					_is_revisit
					and revisit_contract != null
					and game_state.has_story_flag(
						revisit_contract.optional_dialogue_completion_flag
					)
				)
				or game_state.has_story_flag(STORY_OPTIONAL_DIALOGUE_COMPLETED)
			)
		):
			_record_optional_trigger(
				REVISIT_OPTIONAL_TALK_TRIGGER_ID
				if _is_revisit
				else OPTIONAL_TALK_TRIGGER_ID
			)
			_show_status(
				&"UI_M1_RED_SAND_REVISIT_STATUS_OPTIONAL_TALK"
				if _is_revisit
				else &"UI_RED_SAND_ARRIVAL_STATUS_OPTIONAL_TALK"
			)
			_unlock_exploration()


func _unlock_exploration() -> void:
	var was_unlocked: bool = _exploration_is_unlocked
	_exploration_is_unlocked = true
	if not _modal_coordinator.is_modal_active():
		_player.set_input_enabled(true)
		_player.set_interaction_prompt_suppressed(false)
	_objective_label.text = tr(_get_exploration_objective_key())
	_objective_label.visible = true
	if not was_unlocked:
		exploration_unlocked.emit()


func _on_technician_interacted(_actor: Node) -> void:
	if not _exploration_is_unlocked:
		return
	if _is_revisit and not _is_revisit_delivery_ready(_resolve_game_state()):
		_start_dialogue(main_dialogue_sequence, DialogueKind.MAIN)
		return
	_start_dialogue(optional_dialogue_sequence, DialogueKind.OPTIONAL)


func _on_record_terminal_interacted(_actor: Node) -> void:
	if not _exploration_is_unlocked or _active_dialogue_kind != DialogueKind.NONE:
		return
	var game_state: GameStateModel = _resolve_game_state()
	if _is_revisit:
		_record_optional_trigger(REVISIT_RECORD_INSPECTION_TRIGGER_ID)
		if game_state == null or not revisit_contract.has_valid_record_choice(
			game_state
		):
			_show_status(&"UI_M1_RED_SAND_REVISIT_RECORD_PENDING")
		elif game_state.has_story_flag(revisit_contract.upload_full_record_flag):
			_show_status(&"UI_M1_RED_SAND_REVISIT_RECORD_UPLOADED")
		else:
			_show_status(&"UI_M1_RED_SAND_REVISIT_RECORD_LOCAL")
		return
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
	if _is_revisit and not _is_revisit_delivery_ready(_resolve_game_state()):
		_show_status(&"UI_M1_RED_SAND_REVISIT_STATUS_RETURN_BLOCKED")
		return
	var scene_router: SceneRouterService = _resolve_scene_router()
	if scene_router == null:
		_show_status(&"UI_RED_SAND_ARRIVAL_STATUS_RETURN_ERROR")
		return
	if not _modal_coordinator.begin_modal(MODAL_RETURN_TRANSITION):
		return
	_objective_label.text = tr(
		"UI_M1_RED_SAND_REVISIT_OBJECTIVE_RETURNING"
		if _is_revisit
		else "UI_RED_SAND_ARRIVAL_OBJECTIVE_RETURNING"
	)
	if scene_router.request_stage(SceneRouterService.Stage.RESULTS):
		return
	_modal_coordinator.end_modal(MODAL_RETURN_TRANSITION)
	_objective_label.text = tr(_get_exploration_objective_key())
	_show_status(&"UI_RED_SAND_ARRIVAL_STATUS_RETURN_ERROR")


func _on_cooling_equipment_interacted(_actor: Node) -> void:
	if not _is_revisit or not _exploration_is_unlocked:
		return
	_record_optional_trigger(REVISIT_COOLING_INSPECTION_TRIGGER_ID)
	_show_status(&"UI_M1_RED_SAND_REVISIT_COOLING_DETAIL")


func _record_optional_trigger(trigger_id: StringName) -> void:
	var run_state: OrderRunState = _get_active_run_state()
	if run_state != null and not run_state.optional_trigger_ids.has(trigger_id):
		run_state.optional_trigger_ids.append(trigger_id)
	optional_interaction_completed.emit(trigger_id)


func _show_status(message_key: StringName) -> void:
	_status_key = message_key
	_status_label.text = _format_status_text(message_key)
	_status_panel.visible = true
	_status_time_remaining = STATUS_DURATION_SECONDS
	_status_dismissal_armed = false
	_modal_coordinator.begin_modal(MODAL_OBSERVATION, false)
	call_deferred("_arm_status_dismissal")


func _hide_status() -> void:
	_status_panel.visible = false
	_status_label.text = ""
	_status_key = &""
	_status_time_remaining = 0.0
	_status_dismissal_armed = false
	_modal_coordinator.end_modal(MODAL_OBSERVATION)


func _arm_status_dismissal() -> void:
	_status_dismissal_armed = _status_time_remaining > 0.0


func _format_status_text(message_key: StringName) -> String:
	return "%s\n%s" % [
		tr(String(message_key)),
		tr("UI_OBSERVATION_DISMISS_HINT"),
	]


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_is_revisit() -> bool:
	var game_state: GameStateModel = _resolve_game_state()
	return (
		revisit_contract != null
		and game_state != null
		and revisit_contract.is_revisit_order(game_state.current_order_id)
	)


func _configure_variant_presentation() -> void:
	if _is_revisit and revisit_contract != null:
		main_dialogue_sequence = revisit_contract.arrival_dialogue
		optional_dialogue_sequence = revisit_contract.optional_dialogue
		_technician.prompt_key = revisit_contract.arrival_technician_prompt_key
		_record_terminal.prompt_key = revisit_contract.arrival_record_prompt_key
		_return_beacon.prompt_key = revisit_contract.arrival_return_prompt_key
		_cooling_equipment.prompt_key = revisit_contract.arrival_cooling_prompt_key
	if _cooling_equipment != null:
		_cooling_equipment.visible = _is_revisit
		_cooling_equipment.interaction_enabled = _is_revisit
	if _cooling_equipment_label != null:
		_cooling_equipment_label.visible = _is_revisit
	_refresh_variant_labels()
	queue_redraw()


func _refresh_variant_labels() -> void:
	if _location_label != null:
		_location_label.text = tr(
			"UI_M1_RED_SAND_REVISIT_LOCATION"
			if _is_revisit
			else "UI_RED_SAND_ARRIVAL_LOCATION"
		)
	if _scope_label != null:
		_scope_label.text = tr(
			"UI_M1_RED_SAND_REVISIT_SCOPE"
			if _is_revisit
			else "UI_RED_SAND_ARRIVAL_SCOPE"
		)
	if _record_label != null:
		_record_label.text = tr(
			"UI_M1_RED_SAND_REVISIT_RECORD_LABEL"
			if _is_revisit
			else "UI_RED_SAND_ARRIVAL_RECORD_LABEL"
		)
	if _cooling_equipment_label != null:
		_cooling_equipment_label.text = tr(
			"UI_M1_RED_SAND_REVISIT_COOLING_LABEL"
		)


func _get_main_completion_flag() -> StringName:
	if _is_revisit and revisit_contract != null:
		return revisit_contract.completion_dialogue_flag
	return STORY_MAIN_DIALOGUE_COMPLETED


func _get_exploration_objective_key() -> StringName:
	return (
		&"UI_M1_RED_SAND_REVISIT_OBJECTIVE_EXPLORE"
		if _is_revisit
		else &"UI_RED_SAND_ARRIVAL_OBJECTIVE_EXPLORE"
	)


func _is_revisit_delivery_ready(game_state: GameStateModel) -> bool:
	return (
		_is_revisit
		and revisit_contract != null
		and revisit_contract.is_delivery_ready(game_state)
	)


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
	if _is_revisit:
		_draw_revisit_changes()


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


func _draw_revisit_changes() -> void:
	draw_rect(Rect2(650.0, 188.0, 104.0, 66.0), FACILITY_DARK, true)
	draw_rect(Rect2(650.0, 188.0, 104.0, 66.0), SIGNAL_CYAN, false, 2.0)
	draw_circle(Vector2(678.0, 214.0), 18.0, FACILITY_MID)
	draw_circle(Vector2(678.0, 214.0), 11.0, SIGNAL_CYAN.darkened(0.4))
	draw_rect(Rect2(706.0, 198.0, 34.0, 34.0), FACILITY_MID, true)
	draw_line(Vector2(620.0, 202.0), Vector2(650.0, 202.0), PIPE_RUST, 7.0)
	draw_line(Vector2(754.0, 226.0), Vector2(864.0, 226.0), PIPE_RUST, 7.0)
	for resident_x: float in [744.0, 772.0, 826.0]:
		draw_circle(Vector2(resident_x, 278.0), 4.0, WARM_AMBER)
		draw_line(
			Vector2(resident_x, 282.0),
			Vector2(resident_x, 296.0),
			FACILITY_LIGHT,
			3.0
		)
	for steam_index: int in 5:
		var steam_progress: float = fmod(
			_steam_phase + float(steam_index) * 0.19,
			1.0
		)
		var steam_x: float = 690.0 + float(steam_index % 2) * 14.0
		draw_circle(
			Vector2(
				steam_x + sin(steam_progress * TAU) * 4.0,
				188.0 - steam_progress * 52.0
			),
			3.0 + steam_progress * 2.0,
			Color(0.82, 0.88, 0.84, 0.5 * (1.0 - steam_progress))
		)
	var game_state: GameStateModel = _resolve_game_state()
	if not _is_revisit_delivery_ready(game_state):
		return
	draw_arc(
		Vector2(174.0, 275.0),
		72.0,
		PI + 0.18,
		TAU - 0.18,
		18,
		SIGNAL_CYAN,
		2.0
	)
	draw_circle(Vector2(112.0, 260.0), 3.0, WARM_AMBER)
	draw_circle(Vector2(236.0, 260.0), 3.0, WARM_AMBER)
