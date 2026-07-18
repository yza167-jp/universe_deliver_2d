class_name FlightDebugHUD
extends CanvasLayer

const STATUS_DURATION_SECONDS: float = 2.4
const COMPACT_ROUTE_HEIGHT: float = 70.0
const EXPANDED_ROUTE_HEIGHT: float = 152.0
const COURSE_STEP_KEYS: Array[StringName] = [
	&"UI_FLIGHT_LAB_COURSE_STEP_ASSIST",
	&"UI_FLIGHT_LAB_COURSE_STEP_DIVE",
	&"UI_FLIGHT_LAB_COURSE_STEP_RECOVERY",
	&"UI_FLIGHT_LAB_COURSE_STEP_COLLISION",
	&"UI_FLIGHT_LAB_COURSE_STEP_LASER",
]
const COURSE_COMPACT_INSTRUCTION_KEYS: Array[StringName] = [
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_ASSIST_COMPACT",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_DIVE_COMPACT",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_RECOVERY_COMPACT",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_COLLISION_COMPACT",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_LASER_COMPACT",
]
const COURSE_INSTRUCTION_KEYS: Array[StringName] = [
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_ASSIST",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_DIVE",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_RECOVERY",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_COLLISION",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_LASER",
]

@onready var _essential_motion_panel: PanelContainer = %EssentialMotionPanel
@onready var _essential_resources_panel: PanelContainer = %EssentialResourcesPanel
@onready var _motion_label: Label = %MotionLabel
@onready var _environment_assist_label: Label = %EnvironmentAssistLabel
@onready var _shortcut_label: Label = %ShortcutLabel
@onready var _resource_label: Label = %ResourceLabel
@onready var _integrity_label: Label = %IntegrityLabel
@onready var _diagnostics_panel: PanelContainer = %DiagnosticsPanel
@onready var _diagnostics_hint_label: Label = %DiagnosticsHintLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _vertical_speed_label: Label = %VerticalSpeedLabel
@onready var _pitch_label: Label = %PitchLabel
@onready var _angular_velocity_label: Label = %AngularVelocityLabel
@onready var _zone_label: Label = %ZoneLabel
@onready var _environment_label: Label = %EnvironmentLabel
@onready var _gravity_label: Label = %GravityLabel
@onready var _terminal_label: Label = %TerminalLabel
@onready var _durability_label: Label = %DurabilityLabel
@onready var _fuel_label: Label = %FuelLabel
@onready var _boost_label: Label = %BoostLabel
@onready var _assist_label: Label = %AssistLabel
@onready var _entry_style_label: Label = %EntryStyleLabel
@onready var _laser_label: Label = %LaserLabel
@onready var _collision_label: Label = %CollisionLabel
@onready var _checkpoint_label: Label = %CheckpointLabel
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _route_panel: PanelContainer = %RoutePanel
@onready var _route_title_label: Label = %RouteTitleLabel
@onready var _route_progress_label: Label = %RouteProgressLabel
@onready var _route_checklist_label: Label = %RouteChecklistLabel
@onready var _route_instruction_label: Label = %RouteInstructionLabel

var _flight_ship: FlightLabShip
var _entry_style_tracker: FlightStyleTracker
var _flight_tuning: FlightTuning
var _course: FlightLabCourse
var _route_expanded: bool = false
var _status_remaining: float = 0.0


func _ready() -> void:
	_set_mouse_passthrough()
	set_full_diagnostics_visible(false)
	set_route_expanded(false)
	_hide_status()
	_localize_static_content()
	refresh()


func _process(delta: float) -> void:
	if _status_remaining <= 0.0:
		return
	_status_remaining = maxf(_status_remaining - maxf(delta, 0.0), 0.0)
	if _status_remaining <= 0.0:
		_hide_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_localize_static_content()
		refresh()


func bind_ship(flight_ship: FlightLabShip) -> void:
	_flight_ship = flight_ship
	refresh()


func bind_entry_style_tracker(
	tracker: FlightStyleTracker,
	tuning: FlightTuning
) -> void:
	_entry_style_tracker = tracker
	_flight_tuning = tuning
	refresh()


func bind_course(course: FlightLabCourse) -> void:
	_course = course
	_refresh_route_guide()


func set_route_guide_visible(is_visible: bool) -> void:
	if _route_panel != null:
		_route_panel.visible = is_visible


func toggle_route_expanded() -> bool:
	set_route_expanded(not _route_expanded)
	return _route_expanded


func toggle_route_guide() -> bool:
	return toggle_route_expanded()


func set_route_expanded(is_expanded: bool) -> void:
	_route_expanded = is_expanded
	if _route_panel == null:
		return
	_route_panel.offset_bottom = _route_panel.offset_top + (
		EXPANDED_ROUTE_HEIGHT if _route_expanded else COMPACT_ROUTE_HEIGHT
	)
	if _route_checklist_label != null:
		_route_checklist_label.visible = _route_expanded
	if _route_instruction_label != null:
		_route_instruction_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
			if _route_expanded
			else TextServer.AUTOWRAP_OFF
		)
	_refresh_route_guide()


func is_route_guide_visible() -> bool:
	return _route_panel != null and _route_panel.visible


func is_route_expanded() -> bool:
	return _route_expanded


func toggle_full_diagnostics() -> bool:
	set_full_diagnostics_visible(not is_full_diagnostics_visible())
	return is_full_diagnostics_visible()


func set_full_diagnostics_visible(is_visible: bool) -> void:
	if _diagnostics_panel != null:
		_diagnostics_panel.visible = is_visible


func is_full_diagnostics_visible() -> bool:
	return _diagnostics_panel != null and _diagnostics_panel.visible


func refresh() -> void:
	if not is_node_ready() or _flight_ship == null:
		return
	_refresh_essential_hud()
	_refresh_diagnostics()
	_refresh_route_guide()


func show_reset_feedback(_checkpoint_id: StringName = &"") -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_RESET"))


func show_auto_retry_feedback(_checkpoint_id: StringName) -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_AUTO_RETRY"))


func show_environment_feedback(environment_key: StringName) -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_ENVIRONMENT") % tr(environment_key))


func show_assist_feedback(assist_strength: float) -> void:
	var assist_name: String = tr(
		FlightAssistMode.get_display_name_key(assist_strength)
	)
	var description_key: StringName = FlightAssistMode.get_description_key(
		assist_strength
	)
	if description_key.is_empty():
		_show_status(tr("UI_FLIGHT_LAB_STATUS_ASSIST") % assist_name)
	else:
		_show_status(tr("UI_FLIGHT_LAB_STATUS_ASSIST_WITH_DETAIL") % [
			assist_name,
			tr(description_key),
		])


func show_entry_style_tracking_started() -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_ENTRY_TRACKING"))


func show_entry_style_finalized(style: StringName) -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_ENTRY_FINALIZED") % tr(
		_get_entry_style_key(style)
	))
	refresh()


func show_laser_loadout_feedback(enabled: bool) -> void:
	var status_key: StringName = (
		&"UI_FLIGHT_LAB_STATUS_LASER_EQUIPPED"
		if enabled
		else &"UI_FLIGHT_LAB_STATUS_LASER_UNEQUIPPED"
	)
	_show_status(tr(status_key))
	refresh()


func show_laser_miss_feedback() -> void:
	_show_status(tr("UI_FLIGHT_LAB_STATUS_LASER_MISS"))


func show_laser_rejected_feedback(reason_key: StringName) -> void:
	if reason_key == FlightLaserWeapon.FIRE_COOLDOWN_KEY and _flight_ship != null:
		_show_status(tr(reason_key) % _flight_ship.get_laser_cooldown_remaining())
		return
	_show_status(tr(reason_key))


func show_laser_hit_feedback(remaining_durability: int, target_destroyed: bool) -> void:
	if target_destroyed:
		_show_status(tr("UI_FLIGHT_LAB_STATUS_LASER_DESTROYED"))
		return
	_show_status(tr("UI_FLIGHT_LAB_STATUS_LASER_HIT") % maxi(
		remaining_durability,
		0
	))


func show_boost_blocked_feedback(reason_key: StringName) -> void:
	_show_status(tr(reason_key))


func show_impact_feedback(severity: int, impact_speed: float) -> void:
	var state_key: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"
	match severity:
		FlightCollisionResult.Severity.GRAZE:
			state_key = &"UI_FLIGHT_LAB_COLLISION_GRAZE"
		FlightCollisionResult.Severity.HARD:
			state_key = &"UI_FLIGHT_LAB_COLLISION_HARD"
		FlightCollisionResult.Severity.FATAL:
			state_key = &"UI_FLIGHT_LAB_COLLISION_FATAL"
	_show_status(tr("UI_FLIGHT_LAB_STATUS_IMPACT") % [
		tr(state_key),
		impact_speed,
	])


func show_failure_feedback(reason_key: StringName, retry_delay: float) -> void:
	_show_status(
		tr("UI_FLIGHT_LAB_STATUS_FAILURE") % [
			tr(reason_key),
			maxf(retry_delay, 0.0),
		],
		maxf(retry_delay + 0.5, 1.0)
	)


func show_company_warning(warning_key: StringName, cargo_integrity: float) -> void:
	_show_status(tr(warning_key) % roundi(cargo_integrity))


func get_header_rect() -> Rect2:
	return get_essential_motion_rect()


func get_stats_rect() -> Rect2:
	return get_diagnostics_rect()


func get_essential_motion_rect() -> Rect2:
	return _get_visible_rect(_essential_motion_panel)


func get_essential_resources_rect() -> Rect2:
	return _get_visible_rect(_essential_resources_panel)


func get_diagnostics_rect() -> Rect2:
	return _get_visible_rect(_diagnostics_panel)


func get_status_rect() -> Rect2:
	return _get_visible_rect(_status_panel)


func get_route_rect() -> Rect2:
	return _get_visible_rect(_route_panel)


func get_speed_text() -> String:
	return "" if _speed_label == null else _speed_label.text


func get_forward_speed_text() -> String:
	return "" if _motion_label == null else _motion_label.text


func get_environment_assist_text() -> String:
	return "" if _environment_assist_label == null else _environment_assist_label.text


func get_shortcut_text() -> String:
	return "" if _shortcut_label == null else _shortcut_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func is_status_visible() -> bool:
	return _status_panel != null and _status_panel.visible


func get_angular_velocity_text() -> String:
	return "" if _angular_velocity_label == null else _angular_velocity_label.text


func get_environment_text() -> String:
	return "" if _environment_label == null else _environment_label.text


func get_terminal_text() -> String:
	return "" if _terminal_label == null else _terminal_label.text


func get_durability_text() -> String:
	return "" if _durability_label == null else _durability_label.text


func get_laser_text() -> String:
	return "" if _laser_label == null else _laser_label.text


func get_entry_style_text() -> String:
	return "" if _entry_style_label == null else _entry_style_label.text


func get_checkpoint_text() -> String:
	return "" if _checkpoint_label == null else _checkpoint_label.text


func get_route_progress_text() -> String:
	return "" if _route_progress_label == null else _route_progress_label.text


func get_route_title_text() -> String:
	return "" if _route_title_label == null else _route_title_label.text


func get_route_checklist_text() -> String:
	return "" if _route_checklist_label == null else _route_checklist_label.text


func get_route_instruction_text() -> String:
	return "" if _route_instruction_label == null else _route_instruction_label.text


func is_route_checklist_visible() -> bool:
	return _route_checklist_label != null and _route_checklist_label.visible


func has_visible_mouse_interception() -> bool:
	for child: Node in get_children():
		if _control_tree_intercepts_mouse(child):
			return true
	return false


func _refresh_essential_hud() -> void:
	var forward_speed: float = _flight_ship.get_forward_speed()
	var forward_key: StringName = (
		&"UI_FLIGHT_HUD_REVERSE_SPEED"
		if forward_speed < 0.0
		else &"UI_FLIGHT_HUD_FORWARD_SPEED"
	)
	var forward_text: String = tr(forward_key) % _format_signed(forward_speed)
	_motion_label.text = tr("UI_FLIGHT_HUD_MOTION") % [
		forward_text,
		_format_signed(_flight_ship.get_vertical_speed()),
		_format_signed(_flight_ship.get_pitch_degrees()),
	]
	_environment_assist_label.text = tr("UI_FLIGHT_HUD_ENVIRONMENT_ASSIST") % [
		tr(_flight_ship.environment_zone_key),
		tr(FlightAssistMode.get_display_name_key(_flight_ship.assist_strength)),
	]
	_resource_label.text = (tr("UI_FLIGHT_HUD_RESOURCES") % [
		roundi(_flight_ship.fuel),
		roundi(_flight_ship.boost_energy),
	]).replace("\\n", "\n")
	_integrity_label.text = (tr("UI_FLIGHT_HUD_INTEGRITY") % [
		roundi(_flight_ship.hull),
		roundi(_flight_ship.shield),
		roundi(_flight_ship.cargo_integrity),
	]).replace("\\n", "\n")


func _refresh_diagnostics() -> void:
	_speed_label.text = tr("UI_FLIGHT_DEBUG_SPEED") % _flight_ship.get_speed()
	_vertical_speed_label.text = (
		tr("UI_FLIGHT_DEBUG_VERTICAL_SPEED") % _flight_ship.get_vertical_speed()
	)
	_pitch_label.text = tr("UI_FLIGHT_DEBUG_PITCH") % _flight_ship.get_pitch_degrees()
	_angular_velocity_label.text = tr("UI_FLIGHT_DEBUG_ANGULAR_VELOCITY") % (
		_flight_ship.get_angular_velocity()
	)
	_zone_label.text = tr("UI_FLIGHT_DEBUG_ZONE") % tr(_flight_ship.environment_zone_key)
	_environment_label.text = tr("UI_FLIGHT_DEBUG_ENVIRONMENT") % [
		roundi(_flight_ship.air_density * 100.0),
		roundi(_flight_ship.gravity_blend * 100.0),
	]
	_gravity_label.text = tr("UI_FLIGHT_DEBUG_GRAVITY") % _flight_ship.gravity_acceleration
	_terminal_label.text = tr("UI_FLIGHT_DEBUG_TERMINAL") % [
		_flight_ship.natural_terminal_fall_speed,
		_flight_ship.get_terminal_fall_speed_safety(),
	]
	_durability_label.text = tr("UI_FLIGHT_DEBUG_DURABILITY") % [
		roundi(_flight_ship.hull),
		roundi(_flight_ship.shield),
		roundi(_flight_ship.cargo_integrity),
	]
	_fuel_label.text = tr("UI_FLIGHT_DEBUG_FUEL") % [
		roundi(_flight_ship.fuel),
		_flight_ship.propulsion_fuel_cost_rate,
	]
	_boost_label.text = tr("UI_FLIGHT_DEBUG_BOOST") % [
		roundi(_flight_ship.boost_energy),
		_flight_ship.resources.boost_energy_cost_rate,
		_flight_ship.resources.boost_recovery_rate,
	]
	_assist_label.text = tr("UI_FLIGHT_DEBUG_ASSIST") % [
		tr(FlightAssistMode.get_display_name_key(_flight_ship.assist_strength)),
		roundi(_flight_ship.assist_strength * 100.0),
		roundi(_flight_ship.effective_assist_strength * 100.0),
	]
	_refresh_entry_style()
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
	_laser_label.text = tr("UI_FLIGHT_DEBUG_LASER") % [
		tr(laser_loadout_key),
		laser_state_text,
	]
	_collision_label.text = tr("UI_FLIGHT_DEBUG_COLLISION") % [
		tr(_flight_ship.collision_state_key),
		_flight_ship.last_impact_speed,
	]
	_checkpoint_label.text = tr("UI_FLIGHT_DEBUG_CHECKPOINT") % String(
		_flight_ship.get_checkpoint_id()
	)


func _localize_static_content() -> void:
	_shortcut_label.text = tr("UI_FLIGHT_LAB_HINTS_COMPACT")
	_diagnostics_hint_label.text = tr("UI_FLIGHT_LAB_HINTS_FULL").replace(
		"\\n",
		"\n"
	)


func _refresh_entry_style() -> void:
	if _entry_style_label == null:
		return
	var style: StringName = &""
	var duration: float = 0.0
	var downward_speed: float = 0.0
	var risk_or_heat: float = 0.0
	var scenic_trigger_count: int = 0
	if _entry_style_tracker != null:
		style = _entry_style_tracker.get_candidate_style(_flight_tuning)
		var run_state: OrderRunState = _entry_style_tracker.get_run_state()
		if run_state != null:
			duration = run_state.entry_duration
			downward_speed = run_state.max_downward_speed
			risk_or_heat = run_state.max_risk_or_heat
			scenic_trigger_count = run_state.scenic_trigger_count
	_entry_style_label.text = tr("UI_FLIGHT_DEBUG_ENTRY_STYLE") % [
		tr(_get_entry_style_key(style)),
		duration,
		downward_speed,
		roundi(risk_or_heat * 100.0),
		scenic_trigger_count,
	]


func _get_entry_style_key(style: StringName) -> StringName:
	match style:
		FlightStyleTracker.STYLE_DIVE:
			return &"UI_FLIGHT_ENTRY_STYLE_DIVE"
		FlightStyleTracker.STYLE_GLIDE:
			return &"UI_FLIGHT_ENTRY_STYLE_GLIDE"
		FlightStyleTracker.STYLE_BALANCED:
			return &"UI_FLIGHT_ENTRY_STYLE_BALANCED"
	return &"UI_FLIGHT_ENTRY_STYLE_PENDING"


func _refresh_route_guide() -> void:
	if (
		_route_progress_label == null
		or _route_title_label == null
		or _route_checklist_label == null
		or _route_instruction_label == null
	):
		return
	var exercise_count: int = FlightLabCourse.Exercise.COUNT
	var current_exercise: int = (
		FlightLabCourse.Exercise.ASSIST_HOVER
		if _course == null
		else _course.get_current_exercise()
	)
	var display_step: int = mini(current_exercise + 1, exercise_count)
	_route_progress_label.text = tr("UI_FLIGHT_LAB_COURSE_PROGRESS_COMPACT") % [
		display_step,
		exercise_count,
	]

	var checklist_lines: PackedStringArray = []
	for exercise: int in exercise_count:
		var marker: String = "✓" if (
			_course != null and _course.is_exercise_complete(exercise)
		) else "·"
		checklist_lines.append(tr("UI_FLIGHT_LAB_COURSE_CHECK_ITEM") % [
			marker,
			exercise + 1,
			tr(COURSE_STEP_KEYS[exercise]),
		])
	_route_checklist_label.text = "\n".join(checklist_lines)

	if current_exercise >= exercise_count:
		_route_title_label.text = tr("UI_FLIGHT_LAB_COURSE_COMPLETE_TITLE")
		_route_instruction_label.text = tr("UI_FLIGHT_LAB_COURSE_COMPLETE")
		return
	_route_title_label.text = tr(COURSE_STEP_KEYS[current_exercise])
	_route_instruction_label.text = tr(
		COURSE_INSTRUCTION_KEYS[current_exercise]
		if _route_expanded
		else COURSE_COMPACT_INSTRUCTION_KEYS[current_exercise]
	)


func _show_status(
	message: String,
	duration: float = STATUS_DURATION_SECONDS
) -> void:
	if not is_node_ready() or _status_panel == null or _status_label == null:
		return
	_status_label.text = message.replace("\n", " ")
	_status_panel.visible = true
	_status_remaining = maxf(duration, 0.1)


func _hide_status() -> void:
	_status_remaining = 0.0
	if _status_panel != null:
		_status_panel.visible = false


func _format_signed(value: float) -> String:
	if absf(value) < 0.5:
		return "0"
	return "%s%d" % ["+" if value > 0.0 else "-", absi(roundi(value))]


func _get_visible_rect(control: Control) -> Rect2:
	if control == null or not control.visible:
		return Rect2()
	return control.get_global_rect()


func _set_mouse_passthrough() -> void:
	for child: Node in get_children():
		_set_control_tree_mouse_passthrough(child)


func _set_control_tree_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_control_tree_mouse_passthrough(child)


func _control_tree_intercepts_mouse(node: Node) -> bool:
	if node is Control:
		var control: Control = node as Control
		if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	for child: Node in node.get_children():
		if _control_tree_intercepts_mouse(child):
			return true
	return false
