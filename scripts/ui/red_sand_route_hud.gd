class_name RedSandRouteHUD
extends CanvasLayer

signal controls_help_close_requested

const STATUS_DURATION_SECONDS: float = 2.4
const COMPANY_ALERT_DURATION_SECONDS: float = 5.2

@onready var _flight_panel: PanelContainer = %FlightPanel
@onready var _diagnostics_panel: PanelContainer = %DiagnosticsPanel
@onready var _route_panel: PanelContainer = %RoutePanel
@onready var _company_alert_panel: PanelContainer = %CompanyAlertPanel
@onready var _company_alert_heading_label: Label = %CompanyAlertHeadingLabel
@onready var _company_alert_body_label: Label = %CompanyAlertBodyLabel
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
var _altitude_reference_provider: FlightAltitudeReferenceProvider
var _landing_target_route_distance: float = -1.0
var _segment_index: int = 0
var _route_distance: float = 0.0
var _elapsed_seconds: float = 0.0
var _checkpoint_id: StringName = &""
var _status_remaining: float = 0.0
var _company_alert_remaining: float = 0.0
var _company_warning_key: StringName = &""
var _company_warning_cargo_integrity: float = 0.0
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
	_hide_company_alert()
	refresh()


func _process(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if _status_remaining > 0.0:
		_status_remaining = maxf(_status_remaining - safe_delta, 0.0)
		if _status_remaining <= 0.0:
			_hide_status()
	if _company_alert_remaining > 0.0:
		_company_alert_remaining = maxf(
			_company_alert_remaining - safe_delta,
			0.0
		)
		if _company_alert_remaining <= 0.0:
			_hide_company_alert()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func bind(
	flight_ship: FlightLabShip,
	route_definition: FlightRouteDefinition,
	altitude_reference_provider: FlightAltitudeReferenceProvider = null,
	landing_target_route_distance: float = -1.0
) -> void:
	_flight_ship = flight_ship
	_route_definition = route_definition
	_altitude_reference_provider = altitude_reference_provider
	_landing_target_route_distance = landing_target_route_distance
	refresh()


func bind_settings_service(settings_service: SettingsServiceModel) -> void:
	if _controls_help != null:
		_controls_help.bind_settings_service(settings_service)


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
	var landing_target_distance: float = (
		_landing_target_route_distance
		if _landing_target_route_distance >= 0.0
		else _route_definition.get_total_distance()
	)
	var distance_remaining: float = maxf(
		landing_target_distance - _route_distance,
		0.0
	)
	var altitude_text: String = _format_player_altitude()
	_motion_label.text = tr("UI_RED_SAND_ROUTE_HUD_NAVIGATION") % [
		_format_distance(distance_remaining),
		roundi(_flight_ship.get_speed()),
		altitude_text,
	]
	_refresh_safety_label()
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
	_refresh_company_alert()
	_refresh_diagnostics(segment, distance_remaining, altitude_text)


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
	if warning_key.is_empty():
		return
	_company_warning_key = warning_key
	_company_warning_cargo_integrity = clampf(cargo_integrity, 0.0, 100.0)
	_company_alert_remaining = COMPANY_ALERT_DURATION_SECONDS
	_refresh_company_alert()


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


func show_lightning_hit(
	shield_damage: float,
	hull_damage: float,
	cargo_damage: float
) -> void:
	_show_status(
		tr("UI_RED_SAND_HAZARD_LIGHTNING_HIT") % [
			roundi(maxf(shield_damage, 0.0)),
			roundi(maxf(hull_damage, 0.0)),
			roundi(maxf(cargo_damage, 0.0)),
		],
		2.8
	)


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


func show_radar_consequence(
	shield_damage: float,
	hull_damage: float,
	cargo_damage: float
) -> void:
	_show_status(
		tr("UI_RED_SAND_RADAR_LOCK_CONSEQUENCE") % [
			roundi(maxf(shield_damage, 0.0)),
			roundi(maxf(hull_damage, 0.0)),
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


func get_company_alert_heading_text() -> String:
	return (
		""
		if _company_alert_heading_label == null
		else _company_alert_heading_label.text
	)


func get_company_alert_body_text() -> String:
	return "" if _company_alert_body_label == null else _company_alert_body_label.text


func is_company_alert_visible() -> bool:
	return _company_alert_panel != null and _company_alert_panel.visible


func get_radar_text() -> String:
	return "" if _radar_label == null else _radar_label.text


func get_landing_text() -> String:
	return "" if _landing_label == null else _landing_label.text


func get_navigation_text() -> String:
	return "" if _motion_label == null else _motion_label.text


func get_current_altitude_text() -> String:
	return _format_player_altitude()


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


func get_company_alert_rect() -> Rect2:
	return _get_visible_rect(_company_alert_panel)


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


func _refresh_company_alert() -> void:
	if (
		_company_alert_panel == null
		or _company_alert_heading_label == null
		or _company_alert_body_label == null
	):
		return
	if _company_warning_key.is_empty() or _company_alert_remaining <= 0.0:
		_hide_company_alert()
		return
	var heading_key: StringName = &"UI_FLIGHT_COMPANY_ALERT_ATTENTION"
	if _company_warning_key == &"UI_FLIGHT_COMPANY_WARNING_CARGO_MEDIUM":
		heading_key = &"UI_FLIGHT_COMPANY_ALERT_WARNING"
	elif _company_warning_key == &"UI_FLIGHT_COMPANY_WARNING_CARGO_LOW":
		heading_key = &"UI_FLIGHT_COMPANY_ALERT_CRITICAL"
	_company_alert_heading_label.text = tr(heading_key)
	_company_alert_body_label.text = tr(_company_warning_key) % roundi(
		_company_warning_cargo_integrity
	)
	_company_alert_panel.visible = true
	if _route_panel != null:
		_route_panel.visible = false


func _hide_company_alert() -> void:
	_company_alert_remaining = 0.0
	_company_warning_key = &""
	if _company_alert_panel != null:
		_company_alert_panel.visible = false
	if _route_panel != null:
		_route_panel.visible = true


func _refresh_radar() -> void:
	if _radar_panel == null or _radar_label == null:
		return
	if _radar_state_key.is_empty():
		_radar_panel.visible = false
		_radar_label.text = ""
		return
	_radar_label.text = tr(_radar_state_key)
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


func _refresh_safety_label() -> void:
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
			_format_distance(_radar_altitude),
		]
		_safety_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.494118, 0.219608, 1.0)
			if _radar_altitude + 0.5 < _radar_safe_height
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
	altitude_text: String
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
		radar_state_text = tr(_radar_state_key)
	var altitude_mode_text: String = "—"
	var virtual_altitude: float = 0.0
	var terrain_altitude: float = 0.0
	var raycast_altitude: float = 0.0
	var profile_altitude: float = 0.0
	var final_agl_altitude: float = 0.0
	var altitude_source_text: String = "—"
	var altitude_source_valid_text: String = tr("UI_RED_SAND_ROUTE_TERRAIN_MISS")
	var ground_node_text: String = "—"
	var ground_path_text: String = "—"
	var altitude_failure_text: String = "—"
	var terrain_hit_text: String = tr("UI_RED_SAND_ROUTE_TERRAIN_MISS")
	var ship_route_y: float = 0.0
	var ground_route_y: float = 0.0
	var altitude_blend: float = 0.0
	var altitude_invalid_duration: float = 0.0
	var ray_profile_difference: float = 0.0
	var profile_segment_text: String = "—"
	if _altitude_reference_provider != null:
		altitude_mode_text = tr(_get_altitude_mode_key())
		virtual_altitude = _altitude_reference_provider.raw_virtual_altitude_meters
		terrain_altitude = _altitude_reference_provider.raw_terrain_altitude_meters
		raycast_altitude = _altitude_reference_provider.raw_raycast_altitude_meters
		profile_altitude = _altitude_reference_provider.raw_profile_altitude_meters
		final_agl_altitude = _altitude_reference_provider.final_agl_altitude_meters
		altitude_source_text = String(_altitude_reference_provider.get_source_name())
		altitude_source_valid_text = tr(
			"UI_RED_SAND_ROUTE_TERRAIN_HIT"
			if _altitude_reference_provider.altitude_source_valid
			else "UI_RED_SAND_ROUTE_TERRAIN_MISS"
		)
		ground_node_text = String(_altitude_reference_provider.get_ground_node_name())
		ground_path_text = String(_altitude_reference_provider.get_ground_node_path())
		altitude_failure_text = String(_altitude_reference_provider.get_failure_reason())
		ship_route_y = _altitude_reference_provider.ship_reference_route_y
		ground_route_y = _altitude_reference_provider.ground_route_y
		altitude_blend = _altitude_reference_provider.atmosphere_to_agl_blend
		altitude_invalid_duration = _altitude_reference_provider.invalid_duration_seconds
		ray_profile_difference = (
			_altitude_reference_provider.ray_profile_difference_meters
		)
		profile_segment_text = String(
			_altitude_reference_provider.terrain_profile_segment_id
		)
		if ground_node_text.is_empty():
			ground_node_text = "—"
		if ground_path_text.is_empty():
			ground_path_text = "—"
		if altitude_failure_text.is_empty():
			altitude_failure_text = "—"
		if profile_segment_text.is_empty():
			profile_segment_text = "—"
		terrain_hit_text = tr(
			"UI_RED_SAND_ROUTE_TERRAIN_HIT"
			if _altitude_reference_provider.terrain_hit_valid
			else "UI_RED_SAND_ROUTE_TERRAIN_MISS"
		)
	var lines: PackedStringArray = PackedStringArray([
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_HINT"),
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_MOTION") % [
			_flight_ship.get_speed(),
			_flight_ship.get_vertical_speed(),
			_flight_ship.get_pitch_degrees(),
			_flight_ship.get_angular_velocity(),
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_ENVIRONMENT") % [
			tr(_flight_ship.environment_zone_key),
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
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_PROPULSION") % [
			roundi(_flight_ship.fuel),
			_flight_ship.propulsion_fuel_cost_rate,
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
			altitude_text,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_ALTITUDE") % [
			altitude_mode_text,
			virtual_altitude,
			terrain_altitude,
			terrain_hit_text,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_ALTITUDE_SOURCE") % [
			altitude_source_text,
			altitude_source_valid_text,
			raycast_altitude,
			profile_altitude,
			final_agl_altitude,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_VERTICAL_FRAME") % [
			ship_route_y,
			ground_route_y,
			final_agl_altitude,
			profile_segment_text,
			altitude_blend,
			altitude_invalid_duration,
			ray_profile_difference,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_GROUND") % [
			ground_node_text,
			ground_path_text,
			altitude_failure_text,
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_COLLIDER") % [
			_segment_index + 1,
			String(_flight_ship.last_collision_object_name),
			_flight_ship.last_collision_layer,
			_flight_ship.last_collision_mask,
			_flight_ship.last_collision_normal,
			String(_flight_ship.last_collision_object_path),
		],
		tr("UI_RED_SAND_ROUTE_DIAGNOSTICS_RADAR") % [
			radar_state_text,
			roundi(_radar_risk * 100.0),
		],
		tr("UI_FLIGHT_DEBUG_CHECKPOINT") % String(_checkpoint_id),
	])
	_diagnostics_label.text = "\n".join(lines)


func _format_player_altitude() -> String:
	if _altitude_reference_provider == null:
		return tr("UI_RED_SAND_ROUTE_ALTITUDE_HIGH")
	if not _altitude_reference_provider.has_numeric_altitude():
		if _altitude_reference_provider.get_mode_name() == &"AGL":
			return tr("UI_RED_SAND_ROUTE_ALTITUDE_UNAVAILABLE")
		return tr("UI_RED_SAND_ROUTE_ALTITUDE_HIGH")
	return tr("UI_RED_SAND_ROUTE_ALTITUDE_VALUE") % _format_distance(
		_altitude_reference_provider.get_display_altitude_meters()
	)


func _get_altitude_mode_key() -> StringName:
	if _altitude_reference_provider == null:
		return &"UI_RED_SAND_ROUTE_ALTITUDE_MODE_ORBITAL"
	match _altitude_reference_provider.get_mode_name():
		&"ATMOSPHERE_ENTRY":
			return &"UI_RED_SAND_ROUTE_ALTITUDE_MODE_ATMOSPHERE_ENTRY"
		&"AGL":
			return &"UI_RED_SAND_ROUTE_ALTITUDE_MODE_AGL"
		_:
			return &"UI_RED_SAND_ROUTE_ALTITUDE_MODE_ORBITAL"


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
