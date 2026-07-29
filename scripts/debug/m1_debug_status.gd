class_name M1DebugStatus
extends PanelContainer

const AUTO_HIDE_SECONDS: float = 5.0

@onready var _scenario_label: Label = %ScenarioLabel
@onready var _context_label: Label = %ContextLabel
@onready var _isolation_label: Label = %IsolationLabel
@onready var _auto_hide_timer: Timer = %AutoHideTimer

var _definition: M1DebugScenarioDefinition
var _automatic_saves_disabled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_auto_hide_timer.wait_time = AUTO_HIDE_SECONDS
	if not _auto_hide_timer.timeout.is_connected(_on_auto_hide_timeout):
		_auto_hide_timer.timeout.connect(_on_auto_hide_timeout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func show_scenario(
	definition: M1DebugScenarioDefinition,
	automatic_saves_disabled: bool
) -> void:
	_definition = definition
	_automatic_saves_disabled = automatic_saves_disabled
	_refresh_text()
	visible = definition != null
	if definition != null:
		_auto_hide_timer.start()
	else:
		_auto_hide_timer.stop()


func hide_scenario() -> void:
	_definition = null
	_automatic_saves_disabled = false
	_auto_hide_timer.stop()
	visible = false


func get_scenario_text() -> String:
	return "" if _scenario_label == null else _scenario_label.text


func get_context_text() -> String:
	return "" if _context_label == null else _context_label.text


func get_isolation_text() -> String:
	return "" if _isolation_label == null else _isolation_label.text


func get_auto_hide_seconds() -> float:
	return AUTO_HIDE_SECONDS


func is_auto_hide_pending() -> bool:
	return _auto_hide_timer != null and not _auto_hide_timer.is_stopped()


func _on_auto_hide_timeout() -> void:
	visible = false


func _refresh_text() -> void:
	if _definition == null or not is_node_ready():
		return
	var order_id: StringName = (
		_definition.active_order_id
		if not _definition.active_order_id.is_empty()
		else _definition.catalog_focus_order_id
	)
	_scenario_label.text = tr("UI_M1_DEBUG_STATUS_SCENARIO") % (
		_definition.scenario_id
	)
	_context_label.text = tr("UI_M1_DEBUG_STATUS_CONTEXT") % [
		_definition.chapter_id,
		order_id,
		_definition.focus_planet_id,
	]
	_isolation_label.text = tr(
		"UI_M1_DEBUG_STATUS_ISOLATED"
		if _automatic_saves_disabled
		else "UI_M1_DEBUG_STATUS_UNSAFE"
	)
