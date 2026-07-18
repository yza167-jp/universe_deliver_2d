class_name FlightDebugHUD
extends CanvasLayer

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
@onready var _collision_label: Label = %CollisionLabel
@onready var _checkpoint_label: Label = %CheckpointLabel
@onready var _status_label: Label = %StatusLabel

var _flight_ship: FlightLabShip


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
	_collision_label.text = (
		tr("UI_FLIGHT_DEBUG_COLLISION") % [
			tr(_flight_ship.collision_state_key),
			_flight_ship.last_impact_speed,
		]
	)
	_checkpoint_label.text = tr("UI_FLIGHT_DEBUG_CHECKPOINT") % String(
		_flight_ship.get_checkpoint_id()
	)


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


func get_checkpoint_text() -> String:
	return "" if _checkpoint_label == null else _checkpoint_label.text


func _localize_static_content() -> void:
	_title_label.text = tr("UI_FLIGHT_LAB_TITLE")
	_hint_label.text = tr("UI_FLIGHT_LAB_HINTS")
