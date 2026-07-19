class_name RedSandRouteHUD
extends CanvasLayer

const STATUS_DURATION_SECONDS: float = 2.4

@onready var _flight_panel: PanelContainer = %FlightPanel
@onready var _route_panel: PanelContainer = %RoutePanel
@onready var _motion_label: Label = %MotionLabel
@onready var _resources_label: Label = %ResourcesLabel
@onready var _stage_label: Label = %StageLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _radar_panel: PanelContainer = %RadarPanel
@onready var _radar_label: Label = %RadarLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel

var _flight_ship: FlightLabShip
var _route_definition: FlightRouteDefinition
var _segment_index: int = 0
var _route_distance: float = 0.0
var _elapsed_seconds: float = 0.0
var _checkpoint_id: StringName = &""
var _status_remaining: float = 0.0
var _radar_state_key: StringName = &""
var _radar_risk: float = 0.0


func _ready() -> void:
	_set_mouse_passthrough(self)
	_hide_status()
	refresh()


func _process(delta: float) -> void:
	if _status_remaining <= 0.0:
		return
	_status_remaining = maxf(_status_remaining - maxf(delta, 0.0), 0.0)
	if _status_remaining <= 0.0:
		_hide_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func bind(
	flight_ship: FlightLabShip,
	route_definition: FlightRouteDefinition
) -> void:
	_flight_ship = flight_ship
	_route_definition = route_definition
	refresh()


func set_route_state(
	segment_index: int,
	route_distance: float,
	elapsed_seconds: float,
	checkpoint_id: StringName
) -> void:
	_segment_index = maxi(segment_index, 0)
	_route_distance = maxf(route_distance, 0.0)
	_elapsed_seconds = maxf(elapsed_seconds, 0.0)
	_checkpoint_id = checkpoint_id
	refresh()


func refresh() -> void:
	if not is_node_ready() or _flight_ship == null or _route_definition == null:
		return
	var safe_segment_index: int = clampi(
		_segment_index,
		0,
		_route_definition.segments.size() - 1
	)
	var segment: FlightRouteSegment = _route_definition.segments[safe_segment_index]
	if segment == null:
		return
	var forward_speed: float = _flight_ship.get_forward_speed()
	var speed_key: StringName = (
		&"UI_FLIGHT_HUD_REVERSE_SPEED"
		if forward_speed < 0.0
		else &"UI_FLIGHT_HUD_FORWARD_SPEED"
	)
	_motion_label.text = (tr("UI_RED_SAND_ROUTE_HUD_MOTION") % [
		tr(speed_key) % _format_signed(forward_speed),
		_format_signed(_flight_ship.get_vertical_speed()),
		_format_signed(_flight_ship.get_pitch_degrees()),
		tr(FlightAssistMode.get_display_name_key(_flight_ship.assist_strength)),
	]).replace("\\n", "\n")
	_resources_label.text = tr("UI_RED_SAND_ROUTE_HUD_RESOURCES") % [
		roundi(_flight_ship.fuel),
		roundi(_flight_ship.boost_energy),
		roundi(_flight_ship.hull),
		roundi(_flight_ship.shield),
		roundi(_flight_ship.cargo_integrity),
	]
	_stage_label.text = tr("UI_RED_SAND_ROUTE_HUD_STAGE") % [
		_segment_index + 1,
		_route_definition.segments.size(),
		tr(segment.display_name_key),
	]
	_progress_label.text = tr("UI_RED_SAND_ROUTE_HUD_PROGRESS") % [
		roundi(_route_definition.get_overall_progress(_route_distance) * 100.0),
		_elapsed_seconds / 60.0,
		_route_definition.expected_duration_seconds / 60.0,
	]
	_instruction_label.text = tr(segment.instruction_key)
	_refresh_radar()


func show_stage_transition(segment: FlightRouteSegment) -> void:
	if segment == null:
		return
	_show_status(tr("UI_RED_SAND_ROUTE_STATUS_STAGE") % tr(segment.display_name_key))


func show_checkpoint_restored(checkpoint_id: StringName) -> void:
	_show_status(tr("UI_RED_SAND_ROUTE_STATUS_RESTORED") % String(checkpoint_id))


func show_auto_retry(checkpoint_id: StringName) -> void:
	_show_status(tr("UI_RED_SAND_ROUTE_STATUS_AUTO_RETRY") % String(checkpoint_id))


func show_failure(reason_key: StringName, retry_delay: float) -> void:
	_show_status(
		tr("UI_RED_SAND_ROUTE_STATUS_FAILURE") % [
			tr(reason_key),
			maxf(retry_delay, 0.0),
		],
		maxf(retry_delay + 0.5, 1.0)
	)


func show_impact(severity: int, impact_speed: float) -> void:
	var state_key: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"
	match severity:
		FlightCollisionResult.Severity.GRAZE:
			state_key = &"UI_FLIGHT_LAB_COLLISION_GRAZE"
		FlightCollisionResult.Severity.HARD:
			state_key = &"UI_FLIGHT_LAB_COLLISION_HARD"
		FlightCollisionResult.Severity.FATAL:
			state_key = &"UI_FLIGHT_LAB_COLLISION_FATAL"
	_show_status(tr("UI_FLIGHT_LAB_STATUS_IMPACT") % [tr(state_key), impact_speed])


func show_boost_blocked(reason_key: StringName) -> void:
	_show_status(tr(reason_key))


func show_company_warning(warning_key: StringName, cargo_integrity: float) -> void:
	_show_status(tr(warning_key) % roundi(cargo_integrity))


func show_laser_rejected(reason_key: StringName, cooldown_remaining: float) -> void:
	if reason_key == FlightLaserWeapon.FIRE_COOLDOWN_KEY:
		_show_status(tr(reason_key) % maxf(cooldown_remaining, 0.0))
		return
	_show_status(tr(reason_key))


func show_laser_miss() -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_LASER_MISS"))


func show_route_complete() -> void:
	_show_status(tr("UI_RED_SAND_ROUTE_STATUS_COMPLETE"), 6.0)


func show_lightning_warning(
	warning_seconds: float,
	slow_motion_active: bool
) -> void:
	var warning_key: StringName = (
		&"UI_RED_SAND_HAZARD_LIGHTNING_WARNING_SLOW"
		if slow_motion_active
		else &"UI_RED_SAND_HAZARD_LIGHTNING_WARNING"
	)
	_show_status(
		tr(warning_key) % maxf(warning_seconds, 0.0),
		maxf(warning_seconds + 0.1, 1.0)
	)


func show_lightning_hit(damage: float) -> void:
	_show_status(tr("UI_RED_SAND_HAZARD_LIGHTNING_HIT") % roundi(damage), 2.8)


func show_lightning_avoided() -> void:
	_show_status(tr("UI_RED_SAND_HAZARD_LIGHTNING_AVOIDED"))


func set_radar_state(state_key: StringName, lock_risk: float) -> void:
	_radar_state_key = state_key
	_radar_risk = clampf(lock_risk, 0.0, 1.0)
	_refresh_radar()


func show_radar_notice(message_key: StringName) -> void:
	if message_key.is_empty():
		return
	_show_status(tr(message_key), 3.6)


func get_stage_text() -> String:
	return "" if _stage_label == null else _stage_label.text


func get_progress_text() -> String:
	return "" if _progress_label == null else _progress_label.text


func get_instruction_text() -> String:
	return "" if _instruction_label == null else _instruction_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_radar_text() -> String:
	return "" if _radar_label == null else _radar_label.text


func get_flight_panel_rect() -> Rect2:
	return _get_visible_rect(_flight_panel)


func get_route_panel_rect() -> Rect2:
	return _get_visible_rect(_route_panel)


func get_status_rect() -> Rect2:
	return _get_visible_rect(_status_panel)


func get_radar_rect() -> Rect2:
	return _get_visible_rect(_radar_panel)


func has_visible_mouse_interception() -> bool:
	return _control_tree_intercepts_mouse(self)


func _show_status(message: String, duration: float = STATUS_DURATION_SECONDS) -> void:
	if not is_node_ready() or _status_panel == null or _status_label == null:
		return
	_status_label.text = message.replace("\n", " ")
	_status_panel.visible = true
	_status_remaining = maxf(duration, 0.1)


func _hide_status() -> void:
	_status_remaining = 0.0
	if _status_panel != null:
		_status_panel.visible = false


func _refresh_radar() -> void:
	if _radar_panel == null or _radar_label == null:
		return
	if _radar_state_key.is_empty():
		_radar_panel.visible = false
		_radar_label.text = ""
		return
	_radar_label.text = tr(_radar_state_key) % roundi(_radar_risk * 100.0)
	_radar_panel.visible = true


func _format_signed(value: float) -> String:
	if absf(value) < 0.5:
		return "0"
	return "%s%d" % ["+" if value > 0.0 else "-", absi(roundi(value))]


func _get_visible_rect(control: Control) -> Rect2:
	if control == null or not control.visible:
		return Rect2()
	return control.get_global_rect()


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_passthrough(child)


func _control_tree_intercepts_mouse(node: Node) -> bool:
	if node is Control:
		var control: Control = node as Control
		if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	for child: Node in node.get_children():
		if _control_tree_intercepts_mouse(child):
			return true
	return false
