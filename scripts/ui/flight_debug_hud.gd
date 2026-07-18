class_name FlightDebugHUD
extends CanvasLayer

const COURSE_STEP_KEYS: Array[StringName] = [
	&"UI_FLIGHT_LAB_COURSE_STEP_ASSIST",
	&"UI_FLIGHT_LAB_COURSE_STEP_DIVE",
	&"UI_FLIGHT_LAB_COURSE_STEP_RECOVERY",
	&"UI_FLIGHT_LAB_COURSE_STEP_COLLISION",
	&"UI_FLIGHT_LAB_COURSE_STEP_LASER",
]
const COURSE_INSTRUCTION_KEYS: Array[StringName] = [
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_ASSIST",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_DIVE",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_RECOVERY",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_COLLISION",
	&"UI_FLIGHT_LAB_COURSE_INSTRUCTION_LASER",
]

@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
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


func _ready() -> void:
	_localize_static_content()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_localize_static_content()
		refresh()


func bind_ship(flight_ship: FlightLabShip) -> void:
	_flight_ship = flight_ship
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_READY")
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


func toggle_route_guide() -> bool:
	if _route_panel == null:
		return false
	_route_panel.visible = not _route_panel.visible
	return _route_panel.visible


func is_route_guide_visible() -> bool:
	return _route_panel != null and _route_panel.visible


func refresh() -> void:
	if not is_node_ready() or _flight_ship == null:
		return
	_speed_label.text = tr("UI_FLIGHT_DEBUG_SPEED") % _flight_ship.get_speed()
	_vertical_speed_label.text = (
		tr("UI_FLIGHT_DEBUG_VERTICAL_SPEED") % _flight_ship.get_vertical_speed()
	)
	_pitch_label.text = tr("UI_FLIGHT_DEBUG_PITCH") % _flight_ship.get_pitch_degrees()
	_angular_velocity_label.text = (
		tr("UI_FLIGHT_DEBUG_ANGULAR_VELOCITY")
		% _flight_ship.get_angular_velocity()
	)
	_zone_label.text = tr("UI_FLIGHT_DEBUG_ZONE") % tr(_flight_ship.environment_zone_key)
	_environment_label.text = tr("UI_FLIGHT_DEBUG_ENVIRONMENT") % [
		roundi(_flight_ship.air_density * 100.0),
		roundi(_flight_ship.gravity_blend * 100.0),
	]
	_gravity_label.text = (
		tr("UI_FLIGHT_DEBUG_GRAVITY") % _flight_ship.gravity_acceleration
	)
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
	_collision_label.text = (
		tr("UI_FLIGHT_DEBUG_COLLISION") % [
			tr(_flight_ship.collision_state_key),
			_flight_ship.last_impact_speed,
		]
	)
	_checkpoint_label.text = tr("UI_FLIGHT_DEBUG_CHECKPOINT") % String(
		_flight_ship.get_checkpoint_id()
	)
	_refresh_route_guide()


func show_reset_feedback(_checkpoint_id: StringName = &"") -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_RESET")


func show_auto_retry_feedback(_checkpoint_id: StringName) -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_AUTO_RETRY")


func show_environment_feedback(environment_key: StringName) -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_ENVIRONMENT") % tr(environment_key)


func show_assist_feedback(assist_strength: float) -> void:
	if not is_node_ready():
		return
	_status_label.text = (
		tr("UI_FLIGHT_LAB_STATUS_ASSIST")
		% roundi(clampf(assist_strength, 0.0, 1.0) * 100.0)
	)


func show_entry_style_tracking_started() -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_ENTRY_TRACKING")


func show_entry_style_finalized(style: StringName) -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_ENTRY_FINALIZED") % tr(
		_get_entry_style_key(style)
	)
	refresh()


func show_laser_loadout_feedback(enabled: bool) -> void:
	if not is_node_ready():
		return
	var status_key: StringName = (
		&"UI_FLIGHT_LAB_STATUS_LASER_EQUIPPED"
		if enabled
		else &"UI_FLIGHT_LAB_STATUS_LASER_UNEQUIPPED"
	)
	_status_label.text = tr(status_key)
	refresh()


func show_laser_miss_feedback() -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_LASER_MISS")


func show_laser_rejected_feedback(reason_key: StringName) -> void:
	if not is_node_ready():
		return
	if reason_key == FlightLaserWeapon.FIRE_COOLDOWN_KEY and _flight_ship != null:
		_status_label.text = tr(reason_key) % _flight_ship.get_laser_cooldown_remaining()
		return
	_status_label.text = tr(reason_key)


func show_laser_hit_feedback(remaining_durability: int, target_destroyed: bool) -> void:
	if not is_node_ready():
		return
	if target_destroyed:
		_status_label.text = tr("UI_FLIGHT_LAB_STATUS_LASER_DESTROYED")
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_LASER_HIT") % maxi(
		remaining_durability,
		0
	)


func show_impact_feedback(severity: int, impact_speed: float) -> void:
	if not is_node_ready():
		return
	var state_key: StringName = &"UI_FLIGHT_LAB_COLLISION_CLEAR"
	match severity:
		FlightCollisionResult.Severity.GRAZE:
			state_key = &"UI_FLIGHT_LAB_COLLISION_GRAZE"
		FlightCollisionResult.Severity.HARD:
			state_key = &"UI_FLIGHT_LAB_COLLISION_HARD"
		FlightCollisionResult.Severity.FATAL:
			state_key = &"UI_FLIGHT_LAB_COLLISION_FATAL"
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_IMPACT") % [
		tr(state_key),
		impact_speed,
	]


func show_failure_feedback(reason_key: StringName, retry_delay: float) -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_FAILURE") % [
		tr(reason_key),
		maxf(retry_delay, 0.0),
	]


func show_company_warning(warning_key: StringName, cargo_integrity: float) -> void:
	if not is_node_ready():
		return
	_status_label.text = tr(warning_key) % roundi(cargo_integrity)


func get_header_rect() -> Rect2:
	var header_panel: PanelContainer = get_node_or_null("HeaderPanel") as PanelContainer
	return Rect2() if header_panel == null else header_panel.get_global_rect()


func get_stats_rect() -> Rect2:
	var stats_panel: PanelContainer = get_node_or_null("StatsPanel") as PanelContainer
	return Rect2() if stats_panel == null else stats_panel.get_global_rect()


func get_status_rect() -> Rect2:
	var status_panel: PanelContainer = get_node_or_null("StatusPanel") as PanelContainer
	return Rect2() if status_panel == null else status_panel.get_global_rect()


func get_route_rect() -> Rect2:
	return Rect2() if _route_panel == null else _route_panel.get_global_rect()


func get_speed_text() -> String:
	return "" if _speed_label == null else _speed_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


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


func get_route_checklist_text() -> String:
	return "" if _route_checklist_label == null else _route_checklist_label.text


func get_route_instruction_text() -> String:
	return "" if _route_instruction_label == null else _route_instruction_label.text


func _localize_static_content() -> void:
	_title_label.text = tr("UI_FLIGHT_LAB_TITLE")
	_hint_label.text = tr("UI_FLIGHT_LAB_HINTS")
	_route_title_label.text = tr("UI_FLIGHT_LAB_COURSE_TITLE")


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
		or _route_checklist_label == null
		or _route_instruction_label == null
	):
		return
	var exercise_count: int = FlightLabCourse.Exercise.COUNT
	var completed_count: int = 0 if _course == null else _course.get_completed_count()
	_route_progress_label.text = tr("UI_FLIGHT_LAB_COURSE_PROGRESS") % [
		completed_count,
		exercise_count,
	]

	var checklist_lines: PackedStringArray = []
	for exercise: int in exercise_count:
		var marker: String = " "
		if _course != null and _course.is_exercise_complete(exercise):
			marker = "x"
		checklist_lines.append(
			tr("UI_FLIGHT_LAB_COURSE_CHECK_FORMAT") % [
				exercise + 1,
				marker,
			]
		)
	_route_checklist_label.text = "  ".join(checklist_lines)

	var current_exercise: int = (
		FlightLabCourse.Exercise.ASSIST_HOVER
		if _course == null
		else _course.get_current_exercise()
	)
	if current_exercise >= exercise_count:
		_route_instruction_label.text = tr("UI_FLIGHT_LAB_COURSE_COMPLETE")
		return
	_route_instruction_label.text = "%s\n%s" % [
		tr("UI_FLIGHT_LAB_COURSE_CURRENT") % [
			current_exercise + 1,
			exercise_count,
			tr(COURSE_STEP_KEYS[current_exercise]),
		],
		tr(COURSE_INSTRUCTION_KEYS[current_exercise]),
	]
