class_name WhiteNoiseRouteHUD
extends CanvasLayer

const STATUS_DURATION_SECONDS: float = 2.6

@onready var _stage_label: Label = %StageLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _branch_label: Label = %BranchLabel
@onready var _interference_label: Label = %InterferenceLabel
@onready var _shielding_label: Label = %ShieldingLabel
@onready var _hint_panel: PanelContainer = %HintPanel
@onready var _hint_label: Label = %HintLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _help_panel: PanelContainer = %HelpPanel
@onready var _help_label: Label = %HelpLabel

var _flight: WhiteNoiseFlight
var _ship: FlightLabShip
var _status_remaining: float = 0.0
var _storm_state_name: StringName = &"CLEAR"
var _storm_progress: float = 0.0
var _effective_interference: float = 0.0
var _shielding_enabled: bool = false
var _route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
var _noncritical_refresh_interval: float = 0.34
var _noncritical_refresh_remaining: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status_panel.visible = false
	_help_panel.visible = false
	_hint_label.text = tr("UI_WHITE_NOISE_ROUTE_HINTS")
	_help_label.text = tr("UI_WHITE_NOISE_ROUTE_HELP")
	_refresh_storm_labels()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var safe_delta: float = maxf(delta, 0.0)
	_noncritical_refresh_remaining = maxf(
		_noncritical_refresh_remaining - safe_delta,
		0.0
	)
	if _status_remaining > 0.0:
		_status_remaining = maxf(_status_remaining - safe_delta, 0.0)
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
	_hint_label.text = tr(
		"UI_WHITE_NOISE_SIDE_ROUTE_HINTS"
		if _flight.is_side_order_route()
		else "UI_WHITE_NOISE_ROUTE_HINTS"
	)
	_progress_label.text = tr("UI_WHITE_NOISE_ROUTE_PROGRESS") % [
		roundi(_flight.get_overall_progress() * 100.0),
		roundi(_flight.get_remaining_route_distance()),
	]
	if (
		_storm_state_name != &"ACTIVE"
		or _noncritical_refresh_remaining <= 0.0
	):
		_refresh_branch_label()
		_noncritical_refresh_remaining = (
			_noncritical_refresh_interval
			if _storm_state_name == &"ACTIVE"
			else 0.0
		)
	_refresh_storm_labels()


func set_storm_telemetry(
	state_name: StringName,
	state_progress: float,
	effective_interference: float,
	shielding_enabled: bool,
	route_hints_enabled: bool,
	noncritical_refresh_interval: float
) -> void:
	_storm_state_name = state_name
	_storm_progress = clampf(state_progress, 0.0, 1.0)
	_effective_interference = clampf(effective_interference, 0.0, 1.0)
	_shielding_enabled = shielding_enabled
	_route_hints_enabled = route_hints_enabled
	_noncritical_refresh_interval = maxf(noncritical_refresh_interval, 0.05)
	_hint_panel.visible = _route_hints_enabled
	_refresh_storm_labels()


func show_storm_warning() -> void:
	_show_status(tr("UI_WHITE_NOISE_STORM_WARNING"))


func show_storm_active() -> void:
	_show_status(tr("UI_WHITE_NOISE_STORM_ACTIVE"))


func show_storm_recovery() -> void:
	_show_status(tr("UI_WHITE_NOISE_STORM_RECOVERY"))


func show_signal_recovered() -> void:
	_show_status(tr("UI_WHITE_NOISE_SIGNAL_RECOVERED"))


func show_high_voltage_pulse(result: FlightDamageResult) -> void:
	if result == null:
		return
	_show_status(
		tr("UI_WHITE_NOISE_HIGH_VOLTAGE_PULSE") % [
			roundi(result.shield_damage),
			roundi(result.hull_damage),
			roundi(result.cargo_damage),
		],
		3.4
	)


func get_interference_text() -> String:
	return "" if _interference_label == null else _interference_label.text


func get_shielding_text() -> String:
	return "" if _shielding_label == null else _shielding_label.text


func get_hint_text() -> String:
	return "" if _hint_label == null else _hint_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_route_panel_rect() -> Rect2:
	var route_panel: Control = get_node_or_null("RoutePanel") as Control
	return Rect2() if route_panel == null else route_panel.get_global_rect()


func get_status_panel_rect() -> Rect2:
	return Rect2() if _status_panel == null else _status_panel.get_global_rect()


func is_hint_visible() -> bool:
	return _hint_panel != null and _hint_panel.visible


func _refresh_branch_label() -> void:
	if _flight == null:
		return
	if _flight.is_side_order_route():
		_branch_label.text = tr("UI_WHITE_NOISE_SIDE_ROUTE_LABEL")
		return
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


func _refresh_storm_labels() -> void:
	if _interference_label == null or _shielding_label == null:
		return
	match _storm_state_name:
		&"WARNING":
			_interference_label.text = tr(
				"UI_WHITE_NOISE_INTERFERENCE_WARNING"
			) % roundi(_effective_interference * 100.0)
		&"ACTIVE":
			_interference_label.text = tr(
				"UI_WHITE_NOISE_INTERFERENCE_ACTIVE"
			) % roundi(_effective_interference * 100.0)
		&"RECOVERY":
			_interference_label.text = tr(
				"UI_WHITE_NOISE_INTERFERENCE_RECOVERY"
			) % roundi((1.0 - _storm_progress) * 100.0)
		_:
			_interference_label.text = tr(
				"UI_WHITE_NOISE_INTERFERENCE_CLEAR"
			)
	_shielding_label.text = tr(
		"UI_WHITE_NOISE_SHIELDING_ENABLED"
		if _shielding_enabled
		else "UI_WHITE_NOISE_SHIELDING_DISABLED"
	)


func show_checkpoint(checkpoint_id: StringName) -> void:
	_show_status(tr("UI_WHITE_NOISE_CHECKPOINT") % String(checkpoint_id))


func show_retry() -> void:
	_show_status(tr("UI_WHITE_NOISE_RETRY"))


func show_failure(reason_key: StringName) -> void:
	if reason_key.is_empty():
		return
	_show_status(tr(String(reason_key)), 3.4)


func show_route_complete() -> void:
	_show_status(
		tr(
			"UI_WHITE_NOISE_SIDE_ROUTE_COMPLETE"
			if _flight != null and _flight.is_side_order_route()
			else "UI_WHITE_NOISE_ROUTE_COMPLETE"
		),
		3600.0
	)


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
