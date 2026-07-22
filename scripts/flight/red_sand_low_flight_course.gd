class_name RedSandLowFlightCourse
extends Node2D

signal notice_requested(message_key: StringName)
signal lock_consequence_requested(
	damage: float,
	cargo_damage: float,
	reason_key: StringName
)

enum RadarState {
	INACTIVE,
	CLEAR,
	LOW_ALTITUDE_WARNING,
	LOCKED,
	PULSE,
	COOLDOWN,
}

const TRACKING_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_TRACKING"
const LOCKED_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_LOCKED"
const LOCK_LOST_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_LOST"
const LOCK_CONSEQUENCE_REASON_KEY: StringName = &"UI_RED_SAND_RADAR_LOCK_FAILURE"
const MAX_STATE_TRANSITIONS_PER_STEP: int = 64
const STATE_TRANSITION_EPSILON: float = 0.000001

@export var active_segment_id: StringName = &"red_sand_low_altitude_control"
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var surface_start_route_distance: float = 23000.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var radar_exit_route_distance: float = 30500.0
@export_range(0.05, 1.0, 0.01) var horizontal_distance_scale: float = 0.32
@export_range(1.0, 10000.0, 1.0, "or_greater")
var minimum_safe_altitude_meters: float = 300.0
@export_range(0.1, 5.0, 0.05, "or_greater") var warning_seconds: float = 1.0
@export_range(0.05, 3.0, 0.05, "or_greater") var locked_seconds: float = 0.45
@export_range(0.05, 1.0, 0.01, "or_greater") var pulse_seconds: float = 0.12
@export_range(0.1, 5.0, 0.05, "or_greater") var cooldown_seconds: float = 1.8
@export_range(0.0, 100.0, 1.0) var lock_damage: float = 12.0
@export_range(0.0, 100.0, 1.0) var lock_cargo_damage: float = 2.0

@onready var _collision_geometry: Node2D = %CollisionGeometry
@onready var _radar_sectors: Node2D = %RadarSectors
@onready var _route_hints: Node2D = %RouteHints

var _flight_ship: FlightLabShip
var _settings_service: SettingsServiceModel
var _altitude_provider: Object
var _route_origin_x: float = 0.0
var _radar_active: bool = false
var _radar_state: RadarState = RadarState.INACTIVE
var _state_elapsed_seconds: float = 0.0
var _active_sector_id: StringName = &""
var _scan_elapsed_seconds: float = 0.0
var _pulse_count: int = 0
var _route_hints_enabled: bool = false
var _high_contrast_enabled: bool = false
var _surface_frame_offset_y: float = 0.0


func _ready() -> void:
	_prepare_course_geometry()
	refresh_accessibility()
	_update_radar_visuals()


func bind(
	flight_ship: FlightLabShip,
	route_origin_x: float,
	settings_service: SettingsServiceModel = null,
	altitude_provider: Object = null
) -> bool:
	_flight_ship = flight_ship
	_settings_service = settings_service
	_altitude_provider = altitude_provider
	_route_origin_x = route_origin_x
	position.x = route_origin_x + surface_start_route_distance
	position.y = _surface_frame_offset_y
	scale.x = clampf(horizontal_distance_scale, 0.05, 1.0)
	var validation_errors: PackedStringArray = validate()
	if not validation_errors.is_empty():
		for validation_error: String in validation_errors:
			push_error("Red Sand low-altitude radar course: %s" % validation_error)
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
	if _collision_geometry == null:
		errors.append("Collision geometry container is missing.")
	if _radar_sectors == null:
		errors.append("Radar sector container is missing.")
	if _route_hints == null:
		errors.append("Route hint container is missing.")
	if active_segment_id.is_empty():
		errors.append("Active radar segment ID is empty.")
	if radar_exit_route_distance <= surface_start_route_distance:
		errors.append("Radar exit must follow the low-altitude course start.")
	if minimum_safe_altitude_meters <= 0.0:
		errors.append("Minimum safe altitude must be positive.")
	if warning_seconds <= 0.0 or locked_seconds <= 0.0:
		errors.append("Radar warning and lock durations must be positive.")
	if pulse_seconds <= 0.0 or cooldown_seconds <= 0.0:
		errors.append("Radar pulse and cooldown durations must be positive.")
	if lock_damage <= 0.0 and lock_cargo_damage <= 0.0:
		errors.append("Radar pulse must have a visible resource consequence.")
	if _collision_geometry != null and get_obstacle_count() < 5:
		errors.append("Low-altitude course needs at least five fixed obstacles.")

	var sector_ids: Dictionary[StringName, bool] = {}
	for sector: FlightRadarSector in get_radar_sectors():
		for sector_error: String in sector.validate():
			errors.append(sector_error)
		if sector_ids.has(sector.sector_id):
			errors.append("Radar sector ID '%s' is repeated." % sector.sector_id)
		sector_ids[sector.sector_id] = true
	if _radar_sectors != null and get_radar_sectors().size() < 2:
		errors.append("Low-altitude course needs at least two fixed radar sectors.")
	return errors


func set_active_segment(segment_id: StringName) -> void:
	var should_be_active: bool = segment_id == active_segment_id
	_radar_active = should_be_active
	_clear_radar_runtime(
		RadarState.CLEAR if should_be_active else RadarState.INACTIVE,
		true
	)
	_update_radar_visuals()


func step_physics(delta: float) -> void:
	if not _radar_active:
		return
	if _get_route_distance() >= radar_exit_route_distance:
		_deactivate_radar()
		return
	if _flight_ship == null or _flight_ship.is_failed or delta <= 0.0:
		return

	_scan_elapsed_seconds += delta
	var sector: FlightRadarSector = _find_sector(_flight_ship.global_position)
	_active_sector_id = &"" if sector == null else sector.sector_id
	if sector == null or not _has_numeric_altitude():
		_enter_clear_state()
		_update_radar_visuals()
		return

	var altitude_meters: float = _get_numeric_altitude_meters()
	if not is_finite(altitude_meters):
		_enter_clear_state()
		_update_radar_visuals()
		return
	if not FlightRadarModel.is_low_altitude(
		altitude_meters,
		minimum_safe_altitude_meters
	):
		_enter_clear_state()
		_update_radar_visuals()
		return

	_advance_low_altitude_state(delta)
	_update_radar_visuals()


func reset_for_checkpoint() -> void:
	_pulse_count = 0
	_clear_radar_runtime(
		RadarState.CLEAR if _radar_active else RadarState.INACTIVE,
		true
	)
	_update_radar_visuals()


func refresh_accessibility() -> void:
	var route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
	var high_contrast_enabled: bool = LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
	var settings_service: SettingsServiceModel = _settings_service
	if settings_service == null:
		settings_service = get_node_or_null(
			"/root/SettingsService"
		) as SettingsServiceModel
	if settings_service != null:
		route_hints_enabled = settings_service.settings.route_hints_enabled
		high_contrast_enabled = settings_service.settings.high_contrast_terrain
	_route_hints_enabled = route_hints_enabled
	_high_contrast_enabled = high_contrast_enabled
	if _route_hints != null:
		_route_hints.visible = _radar_active and route_hints_enabled
	if _collision_geometry != null:
		for obstacle_node: Node in _collision_geometry.get_children():
			var outline: Line2D = obstacle_node.get_node_or_null(
				"ContrastOutline"
			) as Line2D
			if outline != null:
				outline.visible = high_contrast_enabled


func get_radar_state() -> RadarState:
	return _radar_state


func get_radar_state_key() -> StringName:
	match _radar_state:
		RadarState.CLEAR:
			return &"UI_RED_SAND_RADAR_STATE_CLEAR"
		RadarState.LOW_ALTITUDE_WARNING:
			return &"UI_RED_SAND_RADAR_STATE_LOW_ALTITUDE_WARNING"
		RadarState.LOCKED:
			return &"UI_RED_SAND_RADAR_STATE_LOCKED"
		RadarState.PULSE:
			return &"UI_RED_SAND_RADAR_STATE_PULSE"
		RadarState.COOLDOWN:
			return &"UI_RED_SAND_RADAR_STATE_COOLDOWN"
	return &""


func get_lock_risk() -> float:
	match _radar_state:
		RadarState.LOW_ALTITUDE_WARNING:
			return FlightRadarModel.calculate_phase_progress(
				_state_elapsed_seconds,
				warning_seconds
			)
		RadarState.LOCKED, RadarState.PULSE:
			return 1.0
		RadarState.COOLDOWN:
			return FlightRadarModel.calculate_cooldown_pressure(
				_state_elapsed_seconds,
				cooldown_seconds
			)
	return 0.0


func is_locked() -> bool:
	return _radar_state in [RadarState.LOCKED, RadarState.PULSE]


func is_radar_active() -> bool:
	return _radar_active


## Kept for the route/HUD bridge; the replacement radar has no landing-buffer state.
func is_landing_buffer_active() -> bool:
	return false


func get_radar_exit_route_distance() -> float:
	return radar_exit_route_distance


func get_safe_altitude_y() -> float:
	var sector: FlightRadarSector = _find_nearest_sector()
	return 0.0 if sector == null else sector.safe_boundary_y


func get_minimum_safe_altitude_meters() -> float:
	return minimum_safe_altitude_meters


func set_surface_frame_offset_y(offset_y: float) -> void:
	if not is_finite(offset_y):
		return
	_surface_frame_offset_y = offset_y
	position.y = offset_y


func get_surface_frame_offset_y() -> float:
	return _surface_frame_offset_y


func get_active_sector_id() -> StringName:
	return _active_sector_id


## Terrain cover no longer changes radar safety; this compatibility query is always empty.
func get_active_cover_id() -> StringName:
	return &""


func get_pulse_count() -> int:
	return _pulse_count


func get_state_elapsed_seconds() -> float:
	return _state_elapsed_seconds


func are_route_hints_visible() -> bool:
	return (
		_radar_active
		and _route_hints_enabled
		and _route_hints != null
		and _route_hints.visible
	)


func is_high_contrast_enabled() -> bool:
	return _high_contrast_enabled


func get_obstacle_count() -> int:
	if _collision_geometry == null:
		return 0
	var obstacle_count: int = 0
	for child: Node in _collision_geometry.get_children():
		if child is StaticBody2D:
			obstacle_count += 1
	return obstacle_count


func get_radar_sectors() -> Array[FlightRadarSector]:
	var sectors: Array[FlightRadarSector] = []
	if _radar_sectors == null:
		return sectors
	for child: Node in _radar_sectors.get_children():
		if child is FlightRadarSector:
			sectors.append(child as FlightRadarSector)
	return sectors


## Kept as a read-only compatibility surface while the obsolete cover nodes are absent.
func get_radar_covers() -> Array[FlightRadarCover]:
	return []


func _advance_low_altitude_state(delta: float) -> void:
	if _radar_state not in [
		RadarState.LOW_ALTITUDE_WARNING,
		RadarState.LOCKED,
		RadarState.PULSE,
		RadarState.COOLDOWN,
	]:
		_set_radar_state(RadarState.LOW_ALTITUDE_WARNING)

	var remaining_seconds: float = maxf(delta, 0.0)
	var transition_count: int = 0
	while (
		remaining_seconds > STATE_TRANSITION_EPSILON
		and transition_count < MAX_STATE_TRANSITIONS_PER_STEP
	):
		var state_duration: float = _get_state_duration(_radar_state)
		var seconds_until_transition: float = maxf(
			state_duration - _state_elapsed_seconds,
			0.0
		)
		if remaining_seconds + STATE_TRANSITION_EPSILON < seconds_until_transition:
			_state_elapsed_seconds += remaining_seconds
			remaining_seconds = 0.0
			break
		remaining_seconds = maxf(
			remaining_seconds - seconds_until_transition,
			0.0
		)
		_state_elapsed_seconds = state_duration
		_advance_radar_state()
		transition_count += 1


func _advance_radar_state() -> void:
	match _radar_state:
		RadarState.LOW_ALTITUDE_WARNING:
			_set_radar_state(RadarState.LOCKED)
		RadarState.LOCKED:
			_set_radar_state(RadarState.PULSE)
		RadarState.PULSE:
			_set_radar_state(RadarState.COOLDOWN)
		RadarState.COOLDOWN:
			_set_radar_state(RadarState.LOW_ALTITUDE_WARNING)
		_:
			_set_radar_state(RadarState.LOW_ALTITUDE_WARNING)


func _set_radar_state(next_state: RadarState) -> void:
	if _radar_state == next_state:
		return
	_radar_state = next_state
	_state_elapsed_seconds = 0.0
	match next_state:
		RadarState.LOW_ALTITUDE_WARNING:
			notice_requested.emit(TRACKING_NOTICE_KEY)
		RadarState.LOCKED:
			notice_requested.emit(LOCKED_NOTICE_KEY)
		RadarState.PULSE:
			_pulse_count += 1
			lock_consequence_requested.emit(
				lock_damage,
				lock_cargo_damage,
				LOCK_CONSEQUENCE_REASON_KEY
			)


func _get_state_duration(state: RadarState) -> float:
	match state:
		RadarState.LOW_ALTITUDE_WARNING:
			return maxf(warning_seconds, 0.1)
		RadarState.LOCKED:
			return maxf(locked_seconds, 0.05)
		RadarState.PULSE:
			return maxf(pulse_seconds, 0.05)
		RadarState.COOLDOWN:
			return maxf(cooldown_seconds, 0.1)
	return 0.0


func _enter_clear_state() -> void:
	if _radar_state == RadarState.CLEAR:
		_state_elapsed_seconds = 0.0
		return
	var had_pressure: bool = get_lock_risk() > 0.0
	_radar_state = RadarState.CLEAR
	_state_elapsed_seconds = 0.0
	if had_pressure:
		notice_requested.emit(LOCK_LOST_NOTICE_KEY)


func _deactivate_radar() -> void:
	_radar_active = false
	_clear_radar_runtime(RadarState.INACTIVE, false)
	_update_radar_visuals()


func _clear_radar_runtime(next_state: RadarState, reset_scan_elapsed: bool) -> void:
	_radar_state = next_state
	_state_elapsed_seconds = 0.0
	_active_sector_id = &""
	if reset_scan_elapsed:
		_scan_elapsed_seconds = 0.0


func _update_radar_visuals() -> void:
	var pressure: float = get_lock_risk()
	for sector: FlightRadarSector in get_radar_sectors():
		sector.set_tracking_visual(
			_radar_active,
			pressure if sector.sector_id == _active_sector_id else 0.0,
			_scan_elapsed_seconds,
			_radar_state == RadarState.PULSE
			and sector.sector_id == _active_sector_id
		)
	if _route_hints != null:
		_route_hints.visible = _radar_active and _route_hints_enabled


func _get_route_distance() -> float:
	if _flight_ship == null:
		return 0.0
	return maxf(_flight_ship.global_position.x - _route_origin_x, 0.0)


func _find_sector(global_point: Vector2) -> FlightRadarSector:
	for sector: FlightRadarSector in get_radar_sectors():
		if sector.contains_global_point(global_point):
			return sector
	return null


func _find_nearest_sector() -> FlightRadarSector:
	var nearest_sector: FlightRadarSector = null
	var nearest_distance: float = INF
	for candidate: FlightRadarSector in get_radar_sectors():
		var distance: float = (
			absf(candidate.global_position.x - _flight_ship.global_position.x)
			if _flight_ship != null
			else absf(candidate.global_position.x)
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_sector = candidate
	return nearest_sector


func _has_numeric_altitude() -> bool:
	if (
		_altitude_provider == null
		or not is_instance_valid(_altitude_provider)
		or not _altitude_provider.has_method(&"has_numeric_altitude")
		or not _altitude_provider.has_method(&"get_radar_altitude_meters")
	):
		return false
	var availability: Variant = _altitude_provider.call(&"has_numeric_altitude")
	if typeof(availability) != TYPE_BOOL or not bool(availability):
		return false
	if _altitude_provider.has_method(&"is_current_source_valid"):
		var current_source_valid: Variant = _altitude_provider.call(
			&"is_current_source_valid"
		)
		if typeof(current_source_valid) != TYPE_BOOL or not bool(current_source_valid):
			return false
	var altitude_value: Variant = _altitude_provider.call(
		&"get_radar_altitude_meters"
	)
	if typeof(altitude_value) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	return is_finite(float(altitude_value))


func _get_numeric_altitude_meters() -> float:
	if _altitude_provider == null or not is_instance_valid(_altitude_provider):
		return INF
	return float(_altitude_provider.call(&"get_radar_altitude_meters"))


func _prepare_course_geometry() -> void:
	if _collision_geometry == null:
		return
	for obstacle_node: Node in _collision_geometry.get_children():
		if not obstacle_node is StaticBody2D:
			continue
		var obstacle: StaticBody2D = obstacle_node as StaticBody2D
		obstacle.collision_layer = FlightWeaponRules.WORLD_COLLISION_LAYER
		obstacle.collision_mask = 0
		var collision: CollisionPolygon2D = obstacle.get_node_or_null(
			"CollisionPolygon2D"
		) as CollisionPolygon2D
		if collision == null:
			continue
		var visual: Polygon2D = obstacle.get_node_or_null("Visual") as Polygon2D
		if visual != null:
			visual.polygon = collision.polygon
		var outline: Line2D = obstacle.get_node_or_null(
			"ContrastOutline"
		) as Line2D
		if outline != null and not collision.polygon.is_empty():
			var outline_points: PackedVector2Array = collision.polygon.duplicate()
			outline_points.append(collision.polygon[0])
			outline.points = outline_points


func _on_assist_option_changed(option_id: StringName, _enabled: bool) -> void:
	if option_id in [
		SettingsServiceModel.ROUTE_HINTS_ENABLED,
		SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
	]:
		refresh_accessibility()
