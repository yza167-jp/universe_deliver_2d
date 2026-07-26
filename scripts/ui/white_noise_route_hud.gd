class_name WhiteNoiseRouteHUD
extends CanvasLayer

const STATUS_DURATION_SECONDS: float = 2.6

@onready var _stage_label: Label = %StageLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _branch_label: Label = %BranchLabel
@onready var _hint_label: Label = %HintLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _help_panel: PanelContainer = %HelpPanel
@onready var _help_label: Label = %HelpLabel

var _flight: WhiteNoiseFlight
var _ship: FlightLabShip
var _status_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status_panel.visible = false
	_help_panel.visible = false
	_hint_label.text = tr("UI_WHITE_NOISE_ROUTE_HINTS")
	_help_label.text = tr("UI_WHITE_NOISE_ROUTE_HELP")


func _process(delta: float) -> void:
	if _status_remaining <= 0.0:
		return
	_status_remaining = maxf(_status_remaining - maxf(delta, 0.0), 0.0)
	if _status_remaining <= 0.0:
		_status_panel.visible = false


func bind(flight: WhiteNoiseFlight, ship: FlightLabShip) -> void:
	_flight = flight
	_ship = ship
	refresh()


func refresh() -> void:
	if _flight == null or _ship == null:
		return
	var segment: FlightRouteSegment = _flight.get_active_segment()
	if segment == null:
		return
	_stage_label.text = tr(segment.display_name_key)
	_progress_label.text = tr("UI_WHITE_NOISE_ROUTE_PROGRESS") % [
		roundi(_flight.get_overall_progress() * 100.0),
		roundi(maxf(
			_flight.get_route_definition().get_total_distance()
			- _flight.get_route_distance(),
			0.0
		)),
	]
	var branch_id: StringName = _flight.get_active_branch_id()
	if branch_id.is_empty():
		_branch_label.text = tr("UI_WHITE_NOISE_BRANCH_PENDING")
	else:
		var branch: WhiteNoiseRouteBranch = (
			_flight.get_route_definition().get_branch(branch_id)
		)
		var branch_name: String = (
			String(branch_id)
			if branch == null
			else tr(branch.display_name_key)
		)
		_branch_label.text = (
			tr("UI_WHITE_NOISE_BRANCH_REJOINED") % branch_name
			if _flight.has_branch_rejoined()
			else tr("UI_WHITE_NOISE_BRANCH_ACTIVE") % branch_name
		)


func show_checkpoint(checkpoint_id: StringName) -> void:
	_show_status(tr("UI_WHITE_NOISE_CHECKPOINT") % String(checkpoint_id))


func show_retry() -> void:
	_show_status(tr("UI_WHITE_NOISE_RETRY"))


func show_route_complete() -> void:
	_show_status(tr("UI_WHITE_NOISE_ROUTE_COMPLETE_DEBUG"), 3600.0)


func show_controls_help() -> void:
	_help_panel.visible = true


func hide_controls_help() -> void:
	_help_panel.visible = false


func is_controls_help_visible() -> bool:
	return _help_panel.visible


func _show_status(message: String, duration: float = STATUS_DURATION_SECONDS) -> void:
	_status_label.text = message
	_status_panel.visible = true
	_status_remaining = maxf(duration, 0.0)
