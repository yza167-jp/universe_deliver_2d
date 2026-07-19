class_name RedSandRouteHUD
extends CanvasLayer

signal controls_help_close_requested

const STATUS_DURATION_SECONDS: float = 2.4

@onready var _flight_panel: PanelContainer = %FlightPanel
@onready var _diagnostics_panel: PanelContainer = %DiagnosticsPanel
@onready var _route_panel: PanelContainer = %RoutePanel
@onready var _motion_label: Label = %MotionLabel
@onready var _safety_label: Label = %SafetyLabel
@onready var _resources_label: Label = %ResourcesLabel
@onready var _diagnostics_label: Label = %DiagnosticsLabel
@onready var _stage_label: Label = %StageLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _controls_hint_label: Label = %ControlsHintLabel
@onready var _radar_panel: PanelContainer = %RadarPanel
@onready var _radar_label: Label = %RadarLabel
@onready var _landing_panel: PanelContainer = %LandingPanel
@onready var _landing_label: Label = %LandingLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _controls_help: FlightControlsHelp = %FlightControlsHelp

var _flight_ship: FlightLabShip
var _route_definition: FlightRouteDefinition
var _segment_index: int = 0
var _route_distance: float = 0.0
var _elapsed_seconds: float = 0.0
var _checkpoint_id: StringName = &""
var _status_remaining: float = 0.0
var _radar_state_key: StringName = &""
var _radar_risk: float = 0.0
var _radar_altitude: float = 0.0
var _radar_safe_height: float = 0.0
var _landing_buffer_active: bool = false
var _landing_state_key: StringName = &""
var _landing_metrics: Vector3 = Vector3.ZERO
var _landing_tuning: FlightTuning
var _full_diagnostics_visible: bool = false
var _route_details_visible: bool = true


func _ready() -> void:
	_set_mouse_passthrough(self)
	if (
		_controls_help != null
		and not _controls_help.close_requested.is_connected(
			_on_controls_help_close_requested
		)
	):
		_controls_help.close_requested.connect(_on_controls_help_close_requested)
	if _flight_panel != null:
		_flight_panel.visible = true
	if _diagnostics_panel != null:
		_diagnostics_panel.visible = _full_diagnostics_visible
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
	var distance_remaining: float = maxf(
		_route_definition.get_total_distance() - _route_distance,
		0.0
	)
	var altitude: float = maxf(
		_route_definition.get_altitude_reference_y(_route_distance)
		- _flight_ship.position.y,
		0.0
	)
	_motion_label.text = tr("UI_RED_SAND_ROUTE_HUD_NAVIGATION") % [
		_format_distance(distance_remaining),
		roundi(_flight_ship.get_speed()),
		roundi(altitude),
	]
	_refresh_safety_label(altitude)
	var boost_state_key: StringName = (
		&"UI_RED_SAND_ROUTE_BOOST_ACTIVE"
		if _flight_ship.get_boost_feedback_strength() > 0.04
		else &"UI_RED_SAND_ROUTE_BOOST_READY"
	)
	_resources_label.text = tr("UI_RED_SAND_ROUTE_HUD_RESOURCES") % [
		roundi(_flight_ship.fuel),
		roundi(_flight_ship.boost_energy),
		tr(boost_state_key),
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
		_route_definition.expected_duration_seconds,
	]
	_instruction_label.text = tr(segment.instruction_key)
	_controls_hint_label.text = tr("UI_FLIGHT_CONTROLS_HINT")
	_progress_label.visible = _route_details_visible
	_instruction_label.visible = _route_details_visible
	_refresh_radar()
	_refresh_landing()
	_refresh_diagnostics(segment, distance_remaining, altitude)


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


func show_assist_changed(assist_strength: float) -> void:
	_show_status(
		tr("UI_RED_SAND_ROUTE_STATUS_ASSIST")
		% tr(FlightAssistMode.get_display_name_key(assist_strength))
	)


func show_laser_loadout_changed(enabled: bool) -> void:
	_show_status(tr(
		"UI_FLIGHT_CONTROLS_LASER_INSTALLED"
		if enabled
		else "UI_FLIGHT_CONTROLS_LASER_UNINSTALLED"
	))


func show_landing_result(result_id: StringName, cargo_integrity: float) -> void:
	var result_key: StringName = (
		&"UI_RED_SAND_LANDING_RESULT_SMOOTH"
		if result_id == OrderRunState.LANDING_RESULT_SMOOTH
		else &"UI_RED_SAND_LANDING_RESULT_ROUGH"
	)
	_show_status(tr(result_key) % roundi(cargo_integrity), 6.0)


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


func set_radar_state(
	state_key: StringName,
	lock_risk: float,
	altitude: float = 0.0,
	safe_height: float = 0.0,
	landing_buffer_active: bool = false
) -> void:
	_radar_state_key = state_key
	_radar_risk = clampf(lock_risk, 0.0, 1.0)
	_radar_altitude = maxf(altitude, 0.0)
	_radar_safe_height = maxf(safe_height, 0.0)
	_landing_buffer_active = landing_buffer_active
	_refresh_radar()
	refresh()


func show_radar_notice(message_key: StringName) -> void:
	if message_key.is_empty():
		return
	_show_status(tr(message_key), 3.6)


func show_radar_consequence(damage: float, cargo_damage: float) -> void:
	_show_status(
		tr("UI_RED_SAND_RADAR_LOCK_CONSEQUENCE") % [
			roundi(maxf(damage, 0.0)),
			roundi(maxf(cargo_damage, 0.0)),
		],
		4.2
	)


func set_landing_guidance(
	state_key: StringName,
	metrics: Vector3,
	tuning: FlightTuning
) -> void:
	_landing_state_key = state_key
	_landing_metrics = metrics
	_landing_tuning = tuning
	_refresh_landing()


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


func get_landing_text() -> String:
	return "" if _landing_label == null else _landing_label.text


func get_navigation_text() -> String:
	return "" if _motion_label == null else _motion_label.text


func get_safety_text() -> String:
	return "" if _safety_label == null else _safety_label.text


func get_diagnostics_text() -> String:
	return "" if _diagnostics_label == null else _diagnostics_label.text


func get_controls_help() -> FlightControlsHelp:
	return _controls_help


func show_controls_help(direct_test_mode: bool, laser_installed: bool) -> void:
	if _controls_help != null:
		_controls_help.show_help(direct_test_mode, laser_installed)


func hide_controls_help() -> void:
	if _controls_help != null:
		_controls_help.hide_help()


func update_controls_help_laser_state(installed: bool) -> void:
	if _controls_help != null:
		_controls_help.set_laser_installed(installed)


func toggle_full_diagnostics() -> bool:
	_full_diagnostics_visible = not _full_diagnostics_visible
	if _diagnostics_panel != null:
		_diagnostics_panel.visible = _full_diagnostics_visible
	return _full_diagnostics_visible


func is_full_diagnostics_visible() -> bool:
	return _full_diagnostics_visible


func toggle_route_details() -> bool:
	_route_details_visible = not _route_details_visible
	refresh()
	return _route_details_visible


func get_flight_panel_rect() -> Rect2:
	return _get_visible_rect(_flight_panel)


func get_diagnostics_rect() -> Rect2:
	return _get_visible_rect(_diagnostics_panel)


func get_route_panel_rect() -> Rect2:
	return _get_visible_rect(_route_panel)


func get_status_rect() -> Rect2:
	return _get_visible_rect(_status_panel)


func get_radar_rect() -> Rect2:
	return _get_visible_rect(_radar_panel)


func get_landing_rect() -> Rect2:
	return _get_visible_rect(_landing_panel)


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
	_radar_label.text = (
		tr(_radar_state_key)
		if _landing_buffer_active
		else tr(_radar_state_key) % roundi(_radar_risk * 100.0)
	)
	_radar_panel.visible = true


func _refresh_landing() -> void:
	if _landing_panel == null or _landing_label == null:
		return
	if _landing_state_key.is_empty() or _landing_tuning == null:
		_landing_panel.visible = false
		_landing_label.text = ""
		return
	_landing_label.text = (tr("UI_RED_SAND_LANDING_HUD") % [
		tr(_landing_state_key),
		roundi(_landing_metrics.x),
		roundi(_landing_tuning.landing_success_max_horizontal_speed),
		roundi(_landing_metrics.y),
		roundi(_landing_tuning.landing_success_max_descent_speed),
		roundi(_landing_metrics.z),
		roundi(_landing_tuning.landing_success_max_pitch_degrees),
	]).replace("\\n", "\n")
	_landing_panel.visible = true
	_landing_panel.queue_sort()


func _refresh_safety_label(altitude: float) -> void:
	if _safety_label == null:
		return
	if _landing_buffer_active:
		_safety_label.text = tr("UI_RED_SAND_ROUTE_HUD_LANDING_BUFFER")
		_safety_label.add_theme_color_override(
			"font_color",
			Color(0.670588, 1.0, 0.941176, 1.0)
		)
		return
	if not _radar_state_key.is_empty():
		_safety_label.text = tr("UI_RED_SAND_ROUTE_HUD_RADAR_SAFETY") % [
			roundi(_radar_safe_height),
			roundi(maxf(_radar_altitude, altitude)),
		]
		_safety_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.494118, 0.219608, 1.0)
			if _radar_altitude > _radar_safe_height + 0.5
			else Color(0.670588, 1.0, 0.941176, 1.0)
		)
		return
	_safety_label.text = tr("UI_RED_SAND_ROUTE_HUD_SAFETY") % tr(
		FlightAssistMode.get_display_name_key(_flight_ship.assist_strength)
	)
	_safety_label.add_theme_color_override(
		"font_color",
		Color(0.639216, 0.843137, 0.815686, 1.0)
	)


func _refresh_diagnostics(
	segment: FlightRouteSegment,
	distance_remaining: float,
	altitude: float
) -> void:
	if _diagnostics_label == null or segment == null:
		return
	var laser_loadout_key: StringName = &"UI_FLIGHT_LASER_LOADOUT_UNINSTALLED"
	var laser_state_text: String = tr("UI_FLIGHT_LASER_STATE_UNAVAILABLE")
	if _flight_ship.is_laser_enabled():
		laser_loadout_key = &"UI_FLIGHT_LASER_LOADOUT_INSTALLED"
		if _flight_ship.is_laser_ready():
			laser_state_text = tr("UI_FLIGHT_LASER_STATE_READY")
		else:
			laser_state_text = tr("UI_FLIGHT_LASER_STATE_COOLDOWN") % (
				_flight_ship.get_laser_cooldown_remaining()
			)
	var radar_state_text: String = "—"
	if not _radar_state_key.is_empty():
		radar_state_text = (
			tr(_radar_state_key)
			if _landing_buffer_active
			else tr(_radar_state_key) % roundi(_radar_risk * 100.0)
		)
	var lines: PackedStringArray = PackedStringArray([
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_HINT"),
		tr("UI_FLIGHT_DEBUG_SPEED") % _flight_ship.get_speed(),
		tr("UI_FLIGHT_DEBUG_VERTICAL_SPEED") % _flight_ship.get_vertical_speed(),
		tr("UI_FLIGHT_DEBUG_PITCH") % _flight_ship.get_pitch_degrees(),
		tr("UI_FLIGHT_DEBUG_ANGULAR_VELOCITY") % _flight_ship.get_angular_velocity(),
		tr("UI_FLIGHT_DEBUG_ZONE") % tr(_flight_ship.environment_zone_key),
		tr("UI_FLIGHT_DEBUG_ENVIRONMENT") % [
			roundi(_flight_ship.air_density * 100.0),
			roundi(_flight_ship.gravity_blend * 100.0),
		],
		tr("UI_FLIGHT_DEBUG_GRAVITY") % _flight_ship.gravity_acceleration,
		tr("UI_FLIGHT_DEBUG_TERMINAL") % [
			_flight_ship.natural_terminal_fall_speed,
			_flight_ship.get_terminal_fall_speed_safety(),
		],
		tr("UI_FLIGHT_DEBUG_DURABILITY") % [
			roundi(_flight_ship.hull),
			roundi(_flight_ship.shield),
			roundi(_flight_ship.cargo_integrity),
		],
		tr("UI_FLIGHT_DEBUG_FUEL") % [
			roundi(_flight_ship.fuel),
			_flight_ship.propulsion_fuel_cost_rate,
		],
		tr("UI_FLIGHT_DEBUG_BOOST") % [
			roundi(_flight_ship.boost_energy),
			_flight_ship.resources.boost_energy_cost_rate,
			_flight_ship.resources.boost_recovery_rate,
		],
		tr("UI_FLIGHT_DEBUG_ASSIST") % [
			tr(FlightAssistMode.get_display_name_key(_flight_ship.assist_strength)),
			roundi(_flight_ship.assist_strength * 100.0),
			roundi(_flight_ship.effective_assist_strength * 100.0),
		],
		tr("UI_FLIGHT_DEBUG_LASER") % [
			tr(laser_loadout_key),
			laser_state_text,
		],
		tr("UI_FLIGHT_DEBUG_COLLISION") % [
			tr(_flight_ship.collision_state_key),
			_flight_ship.last_impact_speed,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_ROUTE") % [
			_segment_index + 1,
			_route_definition.segments.size(),
			_route_distance,
			_format_distance(distance_remaining),
			roundi(altitude),
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_RADAR") % [
			radar_state_text,
			roundi(_radar_risk * 100.0),
		],
		tr("UI_FLIGHT_DEBUG_CHECKPOINT") % String(_checkpoint_id),
	])
	_diagnostics_label.text = "\n".join(lines)


func _format_distance(distance_meters: float) -> String:
	var safe_distance: float = maxf(distance_meters, 0.0)
	if safe_distance >= 1000.0:
		return "%.1f km" % (safe_distance / 1000.0)
	return "%d m" % roundi(safe_distance)


func _format_signed(value: float) -> String:
	if absf(value) < 0.5:
		return "0"
	return "%s%d" % ["+" if value > 0.0 else "-", absi(roundi(value))]


func _get_visible_rect(control: Control) -> Rect2:
	if control == null or not control.visible:
		return Rect2()
	return control.get_global_rect()


func _set_mouse_passthrough(node: Node) -> void:
	if node is FlightControlsHelp:
		return
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


func _on_controls_help_close_requested() -> void:
	controls_help_close_requested.emit()
