class_name StationReturnStateController
extends Node

const STATUS_DURATION_SECONDS: float = 5.0
const MODAL_MEMORABILIA_OBSERVATION: StringName = &"station_memorabilia_observation"

@onready var _memorabilia_wall: Interactable2D = (
	get_node("../Interactables/MemorabiliaWall") as Interactable2D
)
@onready var _modal_coordinator: StationModalCoordinator = (
	get_node("../StationModalCoordinator") as StationModalCoordinator
)
@onready var _display_root: Node2D = %FirstDeliveryDisplay
@onready var _memorabilia_label: Label = %MemorabiliaLabel
@onready var _progress_panel: PanelContainer = %ReturnProgressPanel
@onready var _credit_label: Label = %ReturnCreditLabel
@onready var _upgrade_label: Label = %ReturnUpgradeLabel
@onready var _status_panel: PanelContainer = %ReturnStatusPanel
@onready var _status_label: Label = %ReturnStatusLabel

var game_state_override: GameStateModel

var _status_time_remaining: float = 0.0
var _status_key: StringName = &""


func _ready() -> void:
	set_process(false)
	if not _memorabilia_wall.interaction_triggered.is_connected(_on_memorabilia_interacted):
		_memorabilia_wall.interaction_triggered.connect(_on_memorabilia_interacted)
	refresh_return_state()


func _process(delta: float) -> void:
	_status_time_remaining = maxf(_status_time_remaining - delta, 0.0)
	if is_zero_approx(_status_time_remaining):
		_hide_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_return_state()
		if not _status_key.is_empty():
			_status_label.text = tr(String(_status_key))


func refresh_return_state() -> void:
	if not is_node_ready():
		return
	var game_state: GameStateModel = _resolve_game_state()
	var display_is_unlocked: bool = (
		game_state != null
		and game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
	)
	_display_root.visible = display_is_unlocked
	_progress_panel.visible = display_is_unlocked
	_memorabilia_label.text = tr(
		"UI_STATION_MEMORABILIA_WALL_FILLED"
		if display_is_unlocked
		else "UI_STATION_MEMORABILIA_WALL"
	)
	if not display_is_unlocked:
		_credit_label.text = ""
		_upgrade_label.text = ""
		return
	_credit_label.text = tr("UI_STATION_RETURN_CREDITS_FORMAT") % game_state.get_credits()
	_upgrade_label.text = tr("UI_STATION_RETURN_UPGRADE")


func is_first_delivery_display_visible() -> bool:
	return _display_root != null and _display_root.visible


func get_credit_text() -> String:
	return "" if _credit_label == null else _credit_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_memorabilia_wall() -> Interactable2D:
	return _memorabilia_wall


func is_status_visible() -> bool:
	return _status_panel != null and _status_panel.visible


func _on_memorabilia_interacted(_actor: Node) -> void:
	var game_state: GameStateModel = _resolve_game_state()
	var display_is_unlocked: bool = (
		game_state != null
		and game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
	)
	_show_status(
		&"UI_STATION_MEMORABILIA_RELAY_DETAIL"
		if display_is_unlocked
		else &"UI_STATION_MEMORABILIA_EMPTY_DETAIL"
	)


func _show_status(message_key: StringName) -> void:
	_status_key = message_key
	_status_label.text = tr(String(message_key))
	_status_panel.visible = true
	_status_time_remaining = STATUS_DURATION_SECONDS
	_modal_coordinator.begin_modal(MODAL_MEMORABILIA_OBSERVATION)
	set_process(true)


func _hide_status() -> void:
	_status_panel.visible = false
	_status_label.text = ""
	_status_key = &""
	_status_time_remaining = 0.0
	_modal_coordinator.end_modal(MODAL_MEMORABILIA_OBSERVATION)
	set_process(false)


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel
