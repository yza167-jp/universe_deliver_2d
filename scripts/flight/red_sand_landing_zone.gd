class_name RedSandLandingZone
extends Node2D

signal landing_resolved(
	quality: int,
	cargo_damage: float,
	landed_global_position: Vector2
)
signal landing_failed(reason_key: StringName)

const FAILURE_KEY: StringName = &"UI_RED_SAND_LANDING_FAILURE"
const GUIDANCE_APPROACH_KEY: StringName = &"UI_RED_SAND_LANDING_GUIDANCE_APPROACH"
const GUIDANCE_SLOW_KEY: StringName = &"UI_RED_SAND_LANDING_GUIDANCE_SLOW"
const GUIDANCE_LEVEL_KEY: StringName = &"UI_RED_SAND_LANDING_GUIDANCE_LEVEL"
const GUIDANCE_READY_KEY: StringName = &"UI_RED_SAND_LANDING_GUIDANCE_READY"

@export var landing_segment_id: StringName = &"red_sand_landing_approach"
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var landing_center_route_distance: float = 36800.0
@export_range(960.0, 10000.0, 1.0, "or_greater") var pad_width: float = 2400.0
@export_range(0.0, 720.0, 1.0) var pad_surface_y: float = 328.0
@export_range(0.0, 720.0, 1.0) var touchdown_center_y: float = 318.0
@export_range(0.0, 10000.0, 1.0, "or_greater")
var approach_half_width: float = 3600.0
@export var safe_checkpoint_offset: Vector2 = Vector2(-2600.0, 232.0)
@export var safe_checkpoint_velocity: Vector2 = Vector2(110.0, 0.0)

@onready var _approach_sensor: Area2D = %ApproachSensor
@onready var _approach_shape: CollisionShape2D = %ApproachShape
@onready var _pad_body: StaticBody2D = %PadBody
@onready var _pad_shape: CollisionShape2D = %PadShape
@onready var _pad_visual: Polygon2D = %PadVisual
@onready var _pad_surface: Line2D = %PadSurface
@onready var _contrast_outline: Line2D = %ContrastOutline
@onready var _route_hints: Node2D = %RouteHints
@onready var _pad_label: Label = %PadLabel

var _flight_ship: FlightLabShip
var _settings_service: SettingsServiceModel
var _active: bool = false
var _attempt_resolved: bool = false
var _has_approach_sample: bool = false
var _last_approach_velocity: Vector2 = Vector2.ZERO
var _last_approach_rotation: float = 0.0
var _guidance_state_key: StringName = &""
var _route_hints_visible: bool = false
var _high_contrast_enabled: bool = false


func _ready() -> void:
	_configure_geometry()
	_refresh_label()
	refresh_accessibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_label()


func bind(
	flight_ship: FlightLabShip,
	route_origin_x: float,
	settings_service: SettingsServiceModel = null
) -> bool:
	_flight_ship = flight_ship
	_settings_service = settings_service
	position.x = route_origin_x + landing_center_route_distance
	var errors: PackedStringArray = validate()
	if not errors.is_empty():
		for error: String in errors:
			push_error("Red Sand landing zone: %s" % error)
		return false
	if (
		_settings_service != null
		and not _settings_service.assist_option_changed.is_connected(
			_on_assist_option_changed
		)
	):
		_settings_service.assist_option_changed.connect(_on_assist_option_changed)
	refresh_accessibility()
	reset_for_checkpoint()
	return true


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if _flight_ship == null:
		errors.append("Flight ship is missing.")
	if landing_segment_id.is_empty():
		errors.append("Landing segment ID is empty.")
	if pad_width < 960.0:
		errors.append("Landing pad is not large enough for a readable M0 target.")
	if approach_half_width <= pad_width * 0.5:
		errors.append("Landing approach must begin before the pad edge.")
	if touchdown_center_y >= pad_surface_y:
		errors.append("Touchdown center must stay above the pad surface.")
	if _approach_sensor == null or _approach_shape == null:
		errors.append("Landing approach sensor is missing.")
	if _pad_body == null or _pad_shape == null:
		errors.append("Landing pad collision is missing.")
	return errors


func set_active_segment(segment_id: StringName) -> void:
	var should_be_active: bool = segment_id == landing_segment_id
	if should_be_active and not _active:
		reset_for_checkpoint()
	_active = should_be_active
	if not _active:
		_guidance_state_key = &""


func step_physics(_delta: float) -> void:
	if not _active or _attempt_resolved or _flight_ship == null:
		return
	if _flight_ship.is_failed or _flight_ship.is_landed:
		return
	var local_ship_position: Vector2 = to_local(_flight_ship.global_position)
	_guidance_state_key = _resolve_guidance_state(local_ship_position)
	if absf(local_ship_position.x) > approach_half_width:
		return
	if local_ship_position.y < touchdown_center_y:
		_last_approach_velocity = _flight_ship.velocity
		_last_approach_rotation = _flight_ship.rotation
		_has_approach_sample = true
		return
	if absf(local_ship_position.x) > pad_width * 0.5:
		return

	var touchdown_velocity: Vector2 = (
		_last_approach_velocity
		if _has_approach_sample
		else _flight_ship.velocity
	)
	var touchdown_rotation: float = (
		_last_approach_rotation
		if _has_approach_sample
		else _flight_ship.rotation
	)
	var quality: int = FlightLandingModel.classify_touchdown(
		touchdown_velocity,
		touchdown_rotation,
		maxf(touchdown_velocity.y, 0.0),
		_flight_ship.tuning
	)
	_attempt_resolved = true
	if quality == FlightLandingModel.Quality.FAILED:
		landing_failed.emit(FAILURE_KEY)
		return
	var landed_position: Vector2 = global_position + Vector2(
		clampf(local_ship_position.x, -pad_width * 0.46, pad_width * 0.46),
		touchdown_center_y
	)
	landing_resolved.emit(
		quality,
		FlightLandingModel.get_cargo_damage(quality, _flight_ship.tuning),
		landed_position
	)


func reset_for_checkpoint() -> void:
	_attempt_resolved = false
	_has_approach_sample = false
	_last_approach_velocity = Vector2.ZERO
	_last_approach_rotation = 0.0
	_guidance_state_key = GUIDANCE_APPROACH_KEY if _active else &""


func refresh_accessibility() -> void:
	var route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
	var high_contrast_enabled: bool = LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
	var settings_service: SettingsServiceModel = _settings_service
	if settings_service == null:
		settings_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if settings_service != null:
		route_hints_enabled = settings_service.settings.route_hints_enabled
		high_contrast_enabled = settings_service.settings.high_contrast_terrain
	_route_hints_visible = route_hints_enabled
	_high_contrast_enabled = high_contrast_enabled
	if _route_hints != null:
		_route_hints.visible = route_hints_enabled
	if _contrast_outline != null:
		_contrast_outline.visible = high_contrast_enabled


func get_guidance_state_key() -> StringName:
	return _guidance_state_key if _active else &""


func get_safe_checkpoint_position() -> Vector2:
	return global_position + safe_checkpoint_offset


func get_safe_checkpoint_velocity() -> Vector2:
	return safe_checkpoint_velocity


func get_pad_width() -> float:
	return pad_width


func get_pad_surface_y() -> float:
	return pad_surface_y


func get_touchdown_center_y() -> float:
	return touchdown_center_y


func are_route_hints_visible() -> bool:
	return _route_hints_visible and _route_hints != null and _route_hints.visible


func is_high_contrast_enabled() -> bool:
	return _high_contrast_enabled


func is_attempt_resolved() -> bool:
	return _attempt_resolved


func get_landing_metrics() -> Vector3:
	if _flight_ship == null:
		return Vector3.ZERO
	return Vector3(
		absf(_flight_ship.velocity.x),
		maxf(_flight_ship.velocity.y, 0.0),
		absf(_flight_ship.get_pitch_degrees())
	)


func _resolve_guidance_state(local_ship_position: Vector2) -> StringName:
	if absf(local_ship_position.x) > pad_width * 0.5:
		return GUIDANCE_APPROACH_KEY
	if _flight_ship == null or _flight_ship.tuning == null:
		return GUIDANCE_APPROACH_KEY
	var tuning: FlightTuning = _flight_ship.tuning
	if absf(_flight_ship.get_pitch_degrees()) > tuning.landing_success_max_pitch_degrees:
		return GUIDANCE_LEVEL_KEY
	if (
		absf(_flight_ship.velocity.x) > tuning.landing_success_max_horizontal_speed
		or maxf(_flight_ship.velocity.y, 0.0) > tuning.landing_success_max_descent_speed
	):
		return GUIDANCE_SLOW_KEY
	return GUIDANCE_READY_KEY


func _configure_geometry() -> void:
	var approach_rectangle: RectangleShape2D = null
	if _approach_shape != null:
		approach_rectangle = _approach_shape.shape as RectangleShape2D
	if approach_rectangle != null:
		approach_rectangle.size = Vector2(approach_half_width * 2.0, 520.0)
		_approach_shape.position.y = 180.0

	var pad_rectangle: RectangleShape2D = null
	if _pad_shape != null:
		pad_rectangle = _pad_shape.shape as RectangleShape2D
	if pad_rectangle != null:
		pad_rectangle.size = Vector2(pad_width, 160.0)
		_pad_shape.position.y = pad_surface_y + 80.0
	var half_width: float = pad_width * 0.5
	if _pad_visual != null:
		_pad_visual.polygon = PackedVector2Array([
			Vector2(-half_width, pad_surface_y),
			Vector2(half_width, pad_surface_y),
			Vector2(half_width, pad_surface_y + 160.0),
			Vector2(-half_width, pad_surface_y + 160.0),
		])
	if _pad_surface != null:
		_pad_surface.points = PackedVector2Array([
			Vector2(-half_width, pad_surface_y),
			Vector2(half_width, pad_surface_y),
		])
	if _contrast_outline != null:
		_contrast_outline.points = PackedVector2Array([
			Vector2(-half_width, pad_surface_y),
			Vector2(half_width, pad_surface_y),
			Vector2(half_width, pad_surface_y + 160.0),
			Vector2(-half_width, pad_surface_y + 160.0),
			Vector2(-half_width, pad_surface_y),
		])


func _refresh_label() -> void:
	if _pad_label != null:
		_pad_label.text = tr("UI_RED_SAND_LANDING_PAD_LABEL")


func _on_assist_option_changed(option_id: StringName, _enabled: bool) -> void:
	if option_id in [
		SettingsServiceModel.ROUTE_HINTS_ENABLED,
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
	]:
		refresh_accessibility()
