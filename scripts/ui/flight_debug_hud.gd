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
@onready var _fuel_label: Label = %FuelLabel
@onready var _boost_label: Label = %BoostLabel
@onready var _assist_label: Label = %AssistLabel
@onready var _collision_label: Label = %CollisionLabel
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
	_fuel_label.text = tr("UI_FLIGHT_DEBUG_FUEL") % [
		roundi(_flight_ship.fuel),
		_flight_ship.assist_fuel_cost_rate,
	]
	_boost_label.text = tr("UI_FLIGHT_DEBUG_BOOST") % roundi(_flight_ship.boost_energy)
	_assist_label.text = tr("UI_FLIGHT_DEBUG_ASSIST") % [
		roundi(_flight_ship.assist_strength * 100.0),
		roundi(_flight_ship.effective_assist_strength * 100.0),
	]
	_collision_label.text = (
		tr("UI_FLIGHT_DEBUG_COLLISION") % tr(_flight_ship.collision_state_key)
	)


func show_reset_feedback() -> void:
	if not is_node_ready():
		return
	_status_label.text = tr("UI_FLIGHT_LAB_STATUS_RESET")


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


func get_header_rect() -> Rect2:
	var header_panel: PanelContainer = get_node_or_null("HeaderPanel") as PanelContainer
	return Rect2() if header_panel == null else header_panel.get_global_rect()


func get_stats_rect() -> Rect2:
	var stats_panel: PanelContainer = get_node_or_null("StatsPanel") as PanelContainer
	return Rect2() if stats_panel == null else stats_panel.get_global_rect()


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


func _localize_static_content() -> void:
	_title_label.text = tr("UI_FLIGHT_LAB_TITLE")
	_hint_label.text = tr("UI_FLIGHT_LAB_HINTS")
