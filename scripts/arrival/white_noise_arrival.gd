class_name WhiteNoiseArrival
extends Node2D

signal exploration_unlocked
signal optional_interaction_completed(interaction_id: StringName)
signal return_requested

enum DialogueKind {
	NONE,
	MAIN,
	MEMORY_OWNER,
}

const BASE_VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)
const AREA_SIZE: Vector2 = Vector2(960.0, 360.0)
const WALKABLE_RECT: Rect2 = Rect2(40.0, 205.0, 880.0, 125.0)
const CAMERA_HALF_WIDTH: float = BASE_VIEWPORT_SIZE.x * 0.5
const CAMERA_CENTER_Y: float = BASE_VIEWPORT_SIZE.y * 0.5
const STATUS_DURATION_SECONDS: float = 6.0
const MODAL_DIALOGUE: StringName = &"white_noise_arrival_dialogue"
const MODAL_OBSERVATION: StringName = &"white_noise_arrival_observation"
const MODAL_RETURN_TRANSITION: StringName = (
	&"white_noise_arrival_return_transition"
)
const DELIVERY_INSPECTION_TRIGGER_ID: StringName = (
	&"white_noise_arrival_delivery_cradle_inspected"
)
const ARCHIVIST_TALK_TRIGGER_ID: StringName = (
	&"white_noise_arrival_archivist_talk"
)
const INDEX_INSPECTION_TRIGGER_ID: StringName = (
	&"white_noise_arrival_relay_index_inspected"
)
const MEMORY_OWNER_TALK_TRIGGER_ID: StringName = (
	&"white_noise_arrival_memory_owner_talk"
)
const DIALOGUE_UI_SCENE: PackedScene = preload(
	"res://scenes/narrative/dialogue_ui.tscn"
)

const BACKGROUND_DARK: Color = Color("071522")
const ICE_DEEP: Color = Color("102e45")
const ICE_MID: Color = Color("1f536b")
const ICE_LIGHT: Color = Color("7bc5d1")
const ARCHIVE_DARK: Color = Color("101c2b")
const ARCHIVE_MID: Color = Color("213b4b")
const FLOOR_DARK: Color = Color("14232f")
const FLOOR_EDGE: Color = Color("65b8c7")
const INDEX_CYAN: Color = Color("65e2dd")
const MEMORY_MAGENTA: Color = Color("d786bd")
const SIGNAL_AMBER: Color = Color("e7bd67")
const FROST_WHITE: Color = Color("d6edf0")

@export var arrival_contract: WhiteNoiseArrivalContract
@export var settlement_contract: WhiteNoiseSettlementContract
@export var data_registry: GameDataRegistry

@onready var _player: StationPlayer = %StationPlayer
@onready var _modal_coordinator: SceneModalCoordinator = %SceneModalCoordinator
@onready var _camera: Camera2D = %Camera2D
@onready var _delivery_cradle: Interactable2D = %DeliveryCradle
@onready var _archivist: Interactable2D = %Archivist
@onready var _index_terminal: Interactable2D = %IndexTerminal
@onready var _memory_owner: Interactable2D = %MemoryOwner
@onready var _return_lift: Interactable2D = %ReturnLift
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
var _status_dismissal_armed: bool = false
var _fallback_dialogue_layer: CanvasLayer
var _archive_phase: float = 0.0


func _ready() -> void:
	_connect_interactions()
	_objective_label.visible = false
	_status_panel.visible = false
	_modal_coordinator.begin_modal(MODAL_DIALOGUE)
	refresh_landing_feedback()
	_update_camera_for_player()
	call_deferred("_begin_arrival_flow")


func _process(delta: float) -> void:
	_archive_phase = fmod(
		_archive_phase + maxf(delta, 0.0) * 0.18,
		1.0
	)
	queue_redraw()
	if _status_time_remaining <= 0.0:
		return
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
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	refresh_landing_feedback()
	if _exploration_is_unlocked:
		_objective_label.text = tr("UI_WHITE_NOISE_ARRIVAL_OBJECTIVE")
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
			feedback_key = &"UI_WHITE_NOISE_ARRIVAL_LANDING_SMOOTH"
		OrderRunState.LANDING_RESULT_ROUGH:
			feedback_key = &"UI_WHITE_NOISE_ARRIVAL_LANDING_ROUGH"
		_:
			_landing_feedback_label.visible = false
			_landing_feedback_label.text = ""
			return
	_landing_feedback_label.text = tr(feedback_key) % roundi(
		run_state.cargo_integrity
	)
	_landing_feedback_label.visible = true


func get_station_player() -> StationPlayer:
	return _player


func get_dialogue_ui() -> DialogueUI:
	return _dialogue_ui


func get_modal_coordinator() -> SceneModalCoordinator:
	return _modal_coordinator


func get_delivery_cradle() -> Interactable2D:
	return _delivery_cradle


func get_archivist() -> Interactable2D:
	return _archivist


func get_index_terminal() -> Interactable2D:
	return _index_terminal


func get_memory_owner() -> Interactable2D:
	return _memory_owner


func get_return_lift() -> Interactable2D:
	return _return_lift


func get_interactables() -> Array[Interactable2D]:
	return [
		_delivery_cradle,
		_archivist,
		_index_terminal,
		_memory_owner,
		_return_lift,
	]


func get_landing_feedback_text() -> String:
	return (
		""
		if _landing_feedback_label == null
		else _landing_feedback_label.text
	)


func get_objective_text() -> String:
	return "" if _objective_label == null else _objective_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func is_exploration_unlocked() -> bool:
	return _exploration_is_unlocked


func is_main_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.MAIN


func is_memory_owner_dialogue_active() -> bool:
	return _active_dialogue_kind == DialogueKind.MEMORY_OWNER


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
	return Rect2(
		_camera.global_position - BASE_VIEWPORT_SIZE * 0.5,
		BASE_VIEWPORT_SIZE
	)


func _begin_arrival_flow() -> void:
	var game_state: GameStateModel = _resolve_game_state()
	_dialogue_ui = _resolve_dialogue_ui()
	if (
		game_state == null
		or _dialogue_ui == null
		or arrival_contract == null
		or not arrival_contract.validate().is_empty()
		or settlement_contract == null
		or not settlement_contract.validate(data_registry).is_empty()
	):
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		push_error("White Noise arrival could not resolve its contract or UI.")
		return
	if arrival_contract.is_delivery_ready(game_state):
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		_unlock_exploration()
		return
	if not _start_dialogue(
		arrival_contract.main_dialogue,
		DialogueKind.MAIN
	):
		_modal_coordinator.end_modal(MODAL_DIALOGUE)
		push_error("White Noise arrival could not start its delivery dialogue.")


func _connect_interactions() -> void:
	_delivery_cradle.interaction_triggered.connect(
		_on_delivery_cradle_interacted
	)
	_archivist.interaction_triggered.connect(_on_archivist_interacted)
	_index_terminal.interaction_triggered.connect(
		_on_index_terminal_interacted
	)
	_memory_owner.interaction_triggered.connect(_on_memory_owner_interacted)
	_return_lift.interaction_triggered.connect(_on_return_lift_interacted)


func _start_dialogue(
	sequence: DialogueSequence,
	kind: DialogueKind
) -> bool:
	if (
		sequence == null
		or kind == DialogueKind.NONE
		or _active_dialogue_kind != DialogueKind.NONE
	):
		return false
	var game_state: GameStateModel = _resolve_game_state()
	if game_state == null:
		return false
	if _dialogue_ui == null:
		_dialogue_ui = _resolve_dialogue_ui()
	if _dialogue_ui == null:
		return false
	if not _dialogue_ui.dialogue_finished.is_connected(
		_on_dialogue_finished
	):
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
		if (
			arrival_contract != null
			and arrival_contract.is_delivery_ready(game_state)
		):
			_unlock_exploration()
			return
		_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_ERROR")
		return
	if (
		finished_kind == DialogueKind.MEMORY_OWNER
		and arrival_contract != null
		and game_state != null
		and game_state.has_story_flag(
			arrival_contract.memory_owner_dialogue_completion_flag
		)
	):
		_record_optional_trigger(MEMORY_OWNER_TALK_TRIGGER_ID)
		_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_OWNER_TALK")
		_unlock_exploration()


func _unlock_exploration() -> void:
	var was_unlocked: bool = _exploration_is_unlocked
	_exploration_is_unlocked = true
	if not _modal_coordinator.is_modal_active():
		_player.set_input_enabled(true)
		_player.set_interaction_prompt_suppressed(false)
	_objective_label.text = tr("UI_WHITE_NOISE_ARRIVAL_OBJECTIVE")
	_objective_label.visible = true
	if not was_unlocked:
		exploration_unlocked.emit()


func _on_delivery_cradle_interacted(_actor: Node) -> void:
	if not _can_observe():
		return
	_record_optional_trigger(DELIVERY_INSPECTION_TRIGGER_ID)
	_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_DELIVERY")


func _on_archivist_interacted(_actor: Node) -> void:
	if not _can_observe():
		return
	_record_optional_trigger(ARCHIVIST_TALK_TRIGGER_ID)
	_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_ARCHIVIST")


func _on_index_terminal_interacted(_actor: Node) -> void:
	if not _can_observe() or arrival_contract == null:
		return
	var game_state: GameStateModel = _resolve_game_state()
	if not arrival_contract.has_valid_choice(game_state):
		_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_ERROR")
		return
	game_state.set_story_flag(arrival_contract.relay_record_inspected_flag)
	_record_optional_trigger(INDEX_INSPECTION_TRIGGER_ID)
	var status_key: StringName = (
		&"UI_WHITE_NOISE_ARRIVAL_STATUS_INDEX_MINIMUM"
	)
	if game_state.has_story_flag(arrival_contract.keep_sealed_flag):
		status_key = &"UI_WHITE_NOISE_ARRIVAL_STATUS_INDEX_SEALED"
	elif game_state.has_story_flag(arrival_contract.local_custody_flag):
		status_key = &"UI_WHITE_NOISE_ARRIVAL_STATUS_INDEX_CUSTODY"
	_show_status(status_key)


func _on_memory_owner_interacted(_actor: Node) -> void:
	if not _exploration_is_unlocked or arrival_contract == null:
		return
	_start_dialogue(
		arrival_contract.memory_owner_dialogue,
		DialogueKind.MEMORY_OWNER
	)


func _on_return_lift_interacted(_actor: Node) -> void:
	if not _can_observe() or arrival_contract == null:
		return
	if not arrival_contract.is_delivery_ready(_resolve_game_state()):
		_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_RETURN_BLOCKED")
		return
	return_requested.emit()
	var scene_router: SceneRouterService = _resolve_scene_router()
	if (
		scene_router == null
		or scene_router.current_stage != SceneRouterService.Stage.ARRIVAL
	):
		_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_RETURN_READY")
		return
	if not _modal_coordinator.begin_modal(MODAL_RETURN_TRANSITION):
		return
	_objective_label.text = tr(
		"UI_WHITE_NOISE_ARRIVAL_OBJECTIVE_RETURNING"
	)
	if scene_router.request_stage(SceneRouterService.Stage.RESULTS):
		return
	_modal_coordinator.end_modal(MODAL_RETURN_TRANSITION)
	_objective_label.text = tr("UI_WHITE_NOISE_ARRIVAL_OBJECTIVE")
	_show_status(&"UI_WHITE_NOISE_ARRIVAL_STATUS_RETURN_ERROR")


func _can_observe() -> bool:
	return (
		_exploration_is_unlocked
		and _active_dialogue_kind == DialogueKind.NONE
	)


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


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _get_active_run_state() -> OrderRunState:
	var game_state: GameStateModel = _resolve_game_state()
	return (
		game_state.get_active_order_run_state()
		if game_state != null
		else null
	)


func _resolve_dialogue_ui() -> DialogueUI:
	if dialogue_ui_override != null:
		return dialogue_ui_override
	for node: Node in get_tree().get_nodes_in_group("dialogue_ui"):
		if node is DialogueUI:
			return node as DialogueUI
	_fallback_dialogue_layer = CanvasLayer.new()
	_fallback_dialogue_layer.name = "WhiteNoiseDialogueFallbackLayer"
	_fallback_dialogue_layer.layer = 30
	add_child(_fallback_dialogue_layer)
	var fallback_ui: DialogueUI = (
		DIALOGUE_UI_SCENE.instantiate() as DialogueUI
	)
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
	draw_rect(get_area_rect(), BACKGROUND_DARK, true)
	_draw_ice_ceiling()
	_draw_archive_shell()
	_draw_delivery_cradle(Vector2(244.0, 256.0))
	_draw_archivist(Vector2(430.0, 270.0))
	_draw_index_terminal(Vector2(628.0, 250.0))
	_draw_memory_owner(Vector2(792.0, 270.0))
	_draw_return_lift(Vector2(904.0, 250.0))


func _draw_ice_ceiling() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(AREA_SIZE.x, 0.0),
			Vector2(AREA_SIZE.x, 82.0),
			Vector2(874.0, 70.0),
			Vector2(760.0, 92.0),
			Vector2(632.0, 67.0),
			Vector2(508.0, 86.0),
			Vector2(372.0, 65.0),
			Vector2(244.0, 90.0),
			Vector2(118.0, 69.0),
			Vector2(0.0, 84.0),
		]),
		ICE_DEEP
	)
	for stripe_index: int in range(9):
		var x_start: float = float(stripe_index) * 118.0 - 40.0
		draw_line(
			Vector2(x_start, 12.0 + float(stripe_index % 3) * 13.0),
			Vector2(x_start + 146.0, 73.0),
			ICE_MID,
			3.0
		)
		draw_line(
			Vector2(x_start + 24.0, 10.0),
			Vector2(x_start + 86.0, 55.0),
			ICE_LIGHT,
			1.0
		)
	draw_polyline(
		PackedVector2Array([
			Vector2(0.0, 84.0),
			Vector2(118.0, 69.0),
			Vector2(244.0, 90.0),
			Vector2(372.0, 65.0),
			Vector2(508.0, 86.0),
			Vector2(632.0, 67.0),
			Vector2(760.0, 92.0),
			Vector2(874.0, 70.0),
			Vector2(960.0, 82.0),
		]),
		ICE_LIGHT,
		3.0
	)


func _draw_archive_shell() -> void:
	draw_rect(Rect2(0.0, 92.0, AREA_SIZE.x, 148.0), ARCHIVE_DARK, true)
	for bay_index: int in range(8):
		var bay_x: float = 28.0 + float(bay_index) * 122.0
		draw_rect(
			Rect2(bay_x, 110.0, 82.0, 94.0),
			ARCHIVE_MID,
			true
		)
		draw_rect(
			Rect2(bay_x + 9.0, 121.0, 64.0, 68.0),
			ICE_DEEP,
			true
		)
		for shelf_index: int in range(4):
			var shelf_y: float = 128.0 + float(shelf_index) * 14.0
			var glow: float = (
				0.45
				+ 0.25
				* sin(
					(_archive_phase + float(bay_index) * 0.11) * TAU
					+ float(shelf_index)
				)
			)
			draw_line(
				Vector2(bay_x + 15.0, shelf_y),
				Vector2(bay_x + 65.0, shelf_y),
				Color(INDEX_CYAN, glow),
				2.0
			)
	draw_rect(Rect2(0.0, 230.0, AREA_SIZE.x, 130.0), FLOOR_DARK, true)
	draw_line(
		Vector2(0.0, 230.0),
		Vector2(AREA_SIZE.x, 230.0),
		FLOOR_EDGE,
		3.0
	)
	for grid_x: int in range(0, 961, 48):
		draw_line(
			Vector2(float(grid_x), 272.0),
			Vector2(float(grid_x) + 24.0, 360.0),
			Color(ICE_MID, 0.35),
			1.0
		)
	for grid_y: int in range(278, 361, 28):
		draw_line(
			Vector2(0.0, float(grid_y)),
			Vector2(AREA_SIZE.x, float(grid_y)),
			Color(ICE_MID, 0.28),
			1.0
		)
	draw_line(
		Vector2(320.0, 96.0),
		Vector2(320.0, 230.0),
		SIGNAL_AMBER,
		2.0
	)
	draw_line(
		Vector2(704.0, 96.0),
		Vector2(704.0, 230.0),
		SIGNAL_AMBER,
		2.0
	)


func _draw_delivery_cradle(center: Vector2) -> void:
	draw_rect(
		Rect2(center + Vector2(-44.0, -16.0), Vector2(88.0, 32.0)),
		ARCHIVE_MID,
		true
	)
	draw_rect(
		Rect2(center + Vector2(-31.0, -11.0), Vector2(62.0, 18.0)),
		ICE_DEEP,
		true
	)
	draw_rect(
		Rect2(center + Vector2(-24.0, -7.0), Vector2(48.0, 10.0)),
		Color(INDEX_CYAN, 0.85),
		true
	)
	draw_line(
		center + Vector2(-38.0, 17.0),
		center + Vector2(-30.0, 31.0),
		SIGNAL_AMBER,
		3.0
	)
	draw_line(
		center + Vector2(38.0, 17.0),
		center + Vector2(30.0, 31.0),
		SIGNAL_AMBER,
		3.0
	)


func _draw_archivist(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 19.0), 17.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-13.0, -20.0),
			center + Vector2(12.0, -20.0),
			center + Vector2(16.0, 10.0),
			center + Vector2(-15.0, 10.0),
		]),
		ICE_MID
	)
	draw_circle(center + Vector2(0.0, -28.0), 13.0, FROST_WHITE)
	draw_rect(
		Rect2(center + Vector2(-11.0, -30.0), Vector2(22.0, 6.0)),
		INDEX_CYAN,
		true
	)
	draw_line(
		center + Vector2(-11.0, -4.0),
		center + Vector2(12.0, -4.0),
		SIGNAL_AMBER,
		3.0
	)


func _draw_index_terminal(center: Vector2) -> void:
	draw_rect(
		Rect2(center + Vector2(-38.0, -28.0), Vector2(76.0, 50.0)),
		ARCHIVE_MID,
		true
	)
	draw_rect(
		Rect2(center + Vector2(-30.0, -20.0), Vector2(60.0, 31.0)),
		BACKGROUND_DARK,
		true
	)
	for line_index: int in range(4):
		var width: float = 47.0 - float(line_index) * 7.0
		draw_line(
			center + Vector2(-23.0, -13.0 + float(line_index) * 7.0),
			center + Vector2(-23.0 + width, -13.0 + float(line_index) * 7.0),
			INDEX_CYAN if line_index != 2 else MEMORY_MAGENTA,
			2.0
		)
	draw_rect(
		Rect2(center + Vector2(-7.0, 22.0), Vector2(14.0, 20.0)),
		ARCHIVE_MID,
		true
	)


func _draw_memory_owner(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 19.0), 17.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-14.0, -19.0),
			center + Vector2(10.0, -19.0),
			center + Vector2(17.0, 11.0),
			center + Vector2(-13.0, 11.0),
		]),
		Color("54405d")
	)
	draw_circle(center + Vector2(-1.0, -28.0), 13.0, Color("d8c5d5"))
	draw_rect(
		Rect2(center + Vector2(-12.0, -29.0), Vector2(24.0, 5.0)),
		MEMORY_MAGENTA,
		true
	)
	draw_line(
		center + Vector2(-10.0, 0.0),
		center + Vector2(12.0, 0.0),
		INDEX_CYAN,
		3.0
	)


func _draw_return_lift(center: Vector2) -> void:
	draw_rect(
		Rect2(center + Vector2(-43.0, -56.0), Vector2(86.0, 92.0)),
		ARCHIVE_MID,
		true
	)
	draw_rect(
		Rect2(center + Vector2(-32.0, -45.0), Vector2(64.0, 77.0)),
		BACKGROUND_DARK,
		true
	)
	draw_line(
		center + Vector2(0.0, -44.0),
		center + Vector2(0.0, 31.0),
		ICE_MID,
		2.0
	)
	draw_circle(center + Vector2(25.0, -23.0), 4.0, SIGNAL_AMBER)
	draw_line(
		center + Vector2(-25.0, 22.0),
		center + Vector2(25.0, 22.0),
		INDEX_CYAN,
		3.0
	)
