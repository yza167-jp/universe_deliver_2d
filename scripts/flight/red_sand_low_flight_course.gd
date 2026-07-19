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
	LOW_PROFILE,
	TRACKING,
	COVERED,
	LOCKED,
	LANDING_BUFFER,
}

const TRACKING_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_TRACKING"
const LOCKED_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_LOCKED"
const LOCK_LOST_NOTICE_KEY: StringName = &"UI_RED_SAND_RADAR_NOTICE_LOST"
const LOCK_CONSEQUENCE_REASON_KEY: StringName = &"UI_RED_SAND_RADAR_LOCK_FAILURE"

@export var surface_segment_id: StringName = &"red_sand_surface_route"
@export var landing_segment_id: StringName = &"red_sand_landing_approach"
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var surface_start_route_distance: float = 27500.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var radar_exit_route_distance: float = 32650.0
@export_range(0.05, 1.0, 0.01) var horizontal_distance_scale: float = 0.22
@export_range(0.01, 4.0, 0.01, "or_greater") var lock_acquire_rate: float = 0.55
@export_range(0.01, 4.0, 0.01, "or_greater") var lock_decay_rate: float = 0.8
@export_range(0.0, 1.0, 0.01) var lock_release_threshold: float = 0.5
@export_range(0.0, 1.0, 0.01) var tracking_notice_threshold: float = 0.18
@export_range(0.0, 100.0, 1.0) var lock_damage: float = 12.0
@export_range(0.0, 100.0, 1.0) var lock_cargo_damage: float = 2.0

@onready var _collision_geometry: Node2D = %CollisionGeometry
@onready var _radar_sectors: Node2D = %RadarSectors
@onready var _radar_covers: Node2D = %RadarCovers
@onready var _route_hints: Node2D = %RouteHints

var _flight_ship: FlightLabShip
var _settings_service: SettingsServiceModel
var _route_origin_x: float = 0.0
var _surface_active: bool = false
var _landing_buffer_active: bool = false
var _lock_risk: float = 0.0
var _locked: bool = false
var _radar_state: RadarState = RadarState.INACTIVE
var _active_sector_id: StringName = &""
var _active_cover_id: StringName = &""
var _scan_elapsed_seconds: float = 0.0
var _tracking_notice_emitted: bool = false
var _lock_notice_emitted: bool = false
var _lock_consequence_emitted: bool = false
var _route_hints_visible: bool = false
var _high_contrast_enabled: bool = false


func _ready() -> void:
	_prepare_course_geometry()
	refresh_accessibility()
	_update_radar_visuals()


func bind(
	flight_ship: FlightLabShip,
	route_origin_x: float,
	settings_service: SettingsServiceModel = null
) -> bool:
	_flight_ship = flight_ship
	_settings_service = settings_service
	_route_origin_x = route_origin_x
	position.x = route_origin_x + surface_start_route_distance
	scale.x = clampf(horizontal_distance_scale, 0.05, 1.0)
	var validation_errors: PackedStringArray = validate()
	if not validation_errors.is_empty():
		for validation_error: String in validation_errors:
			push_error("Red Sand low-flight course: %s" % validation_error)
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
	if _radar_covers == null:
		errors.append("Radar cover container is missing.")
	if _route_hints == null:
		errors.append("Route hint container is missing.")
	if surface_segment_id.is_empty():
		errors.append("Surface segment ID is empty.")
	if landing_segment_id.is_empty():
		errors.append("Landing segment ID is empty.")
	if radar_exit_route_distance <= surface_start_route_distance:
		errors.append("Radar exit must follow the low-flight course start.")
	if lock_damage <= 0.0 and lock_cargo_damage <= 0.0:
		errors.append("Radar lock must have a visible resource consequence.")
	if lock_acquire_rate <= 0.0 or lock_decay_rate <= 0.0:
		errors.append("Radar acquisition and decay rates must be positive.")
	if _collision_geometry != null and get_obstacle_count() < 5:
		errors.append("Low-flight course needs at least five fixed obstacles.")

	var sector_ids: Dictionary[StringName, bool] = {}
	for sector: FlightRadarSector in get_radar_sectors():
		for sector_error: String in sector.validate():
			errors.append(sector_error)
		if sector_ids.has(sector.sector_id):
			errors.append("Radar sector ID '%s' is repeated." % sector.sector_id)
		sector_ids[sector.sector_id] = true
	if _radar_sectors != null and get_radar_sectors().size() < 3:
		errors.append("Low-flight course needs at least three fixed radar sectors.")

	var cover_ids: Dictionary[StringName, bool] = {}
	for cover: FlightRadarCover in get_radar_covers():
		for cover_error: String in cover.validate():
			errors.append(cover_error)
		if cover_ids.has(cover.cover_id):
			errors.append("Radar cover ID '%s' is repeated." % cover.cover_id)
		cover_ids[cover.cover_id] = true
	if _radar_covers != null and get_radar_covers().size() < 3:
		errors.append("Low-flight course needs at least three terrain covers.")
	return errors


func set_active_segment(segment_id: StringName) -> void:
	_surface_active = segment_id == surface_segment_id
	_landing_buffer_active = segment_id == landing_segment_id
	if not _surface_active and not _landing_buffer_active:
		_clear_radar_runtime()
	elif _landing_buffer_active:
		_clear_radar_runtime()
		_radar_state = RadarState.LANDING_BUFFER
	else:
		_radar_state = RadarState.LOW_PROFILE
	_update_radar_visuals()


func step_physics(delta: float) -> void:
	if (
		not _surface_active
		or _flight_ship == null
		or _flight_ship.is_failed
		or delta <= 0.0
	):
		return
	if _landing_buffer_active or _get_route_distance() >= radar_exit_route_distance:
		_enter_landing_buffer()
		return
	_scan_elapsed_seconds += delta
	var ship_position: Vector2 = _flight_ship.global_position
	var sector: FlightRadarSector = _find_sector(ship_position)
	var cover: FlightRadarCover = _find_cover(ship_position)
	var exposure: float = 0.0
	var acquire_multiplier: float = 1.0
	if sector != null:
		exposure = sector.calculate_exposure(ship_position)
		acquire_multiplier = sector.acquire_rate_multiplier
	var was_locked: bool = _locked
	_lock_risk = FlightRadarModel.step_lock_risk(
		_lock_risk,
		exposure,
		sector != null,
		cover != null,
		delta,
		lock_acquire_rate * acquire_multiplier,
		lock_decay_rate
	)
	_locked = FlightRadarModel.resolve_lock_state(
		_lock_risk,
		_locked,
		cover != null,
		lock_release_threshold
	)
	_active_sector_id = &"" if sector == null else sector.sector_id
	_active_cover_id = &"" if cover == null else cover.cover_id
	_radar_state = _resolve_radar_state(sector, cover, exposure)
	_emit_radar_notices(was_locked, exposure)
	_update_radar_visuals()


func reset_for_checkpoint() -> void:
	_lock_risk = 0.0
	_locked = false
	_active_sector_id = &""
	_active_cover_id = &""
	_scan_elapsed_seconds = 0.0
	_tracking_notice_emitted = false
	_lock_notice_emitted = false
	_lock_consequence_emitted = false
	_landing_buffer_active = false
	_radar_state = RadarState.LOW_PROFILE if _surface_active else RadarState.INACTIVE
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
	_route_hints_visible = route_hints_enabled
	_high_contrast_enabled = high_contrast_enabled
	if _route_hints != null:
		_route_hints.visible = route_hints_enabled
	for cover: FlightRadarCover in get_radar_covers():
		cover.set_hint_visible(route_hints_enabled)
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
		RadarState.LOW_PROFILE:
			return &"UI_RED_SAND_RADAR_STATE_LOW_PROFILE"
		RadarState.TRACKING:
			return &"UI_RED_SAND_RADAR_STATE_TRACKING"
		RadarState.COVERED:
			return &"UI_RED_SAND_RADAR_STATE_COVERED"
		RadarState.LOCKED:
			return &"UI_RED_SAND_RADAR_STATE_LOCKED"
		RadarState.LANDING_BUFFER:
			return &"UI_RED_SAND_RADAR_STATE_LANDING_BUFFER"
	return &""


func get_lock_risk() -> float:
	return _lock_risk


func is_locked() -> bool:
	return _locked


func is_landing_buffer_active() -> bool:
	return _landing_buffer_active


func get_radar_exit_route_distance() -> float:
	return radar_exit_route_distance


func get_safe_altitude_y() -> float:
	var sector: FlightRadarSector = null
	if _flight_ship != null:
		sector = _find_sector(_flight_ship.global_position)
	if sector == null:
		var nearest_distance: float = INF
		for candidate: FlightRadarSector in get_radar_sectors():
			var distance: float = (
				absf(candidate.global_position.x - _flight_ship.global_position.x)
				if _flight_ship != null
				else absf(candidate.global_position.x)
			)
			if distance < nearest_distance:
				nearest_distance = distance
				sector = candidate
	return 0.0 if sector == null else sector.safe_altitude_y


func get_safe_height_ceiling(altitude_reference_y: float) -> float:
	return maxf(altitude_reference_y - get_safe_altitude_y(), 0.0)


func get_active_sector_id() -> StringName:
	return _active_sector_id


func get_active_cover_id() -> StringName:
	return _active_cover_id


func are_route_hints_visible() -> bool:
	return _route_hints_visible and _route_hints != null and _route_hints.visible


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


func get_radar_covers() -> Array[FlightRadarCover]:
	var covers: Array[FlightRadarCover] = []
	if _radar_covers == null:
		return covers
	for child: Node in _radar_covers.get_children():
		if child is FlightRadarCover:
			covers.append(child as FlightRadarCover)
	return covers


func _clear_radar_runtime() -> void:
	_lock_risk = 0.0
	_locked = false
	_active_sector_id = &""
	_active_cover_id = &""
	_radar_state = RadarState.INACTIVE


func _resolve_radar_state(
	sector: FlightRadarSector,
	cover: FlightRadarCover,
	exposure: float
) -> RadarState:
	if _landing_buffer_active:
		return RadarState.LANDING_BUFFER
	if not _surface_active:
		return RadarState.INACTIVE
	if cover != null:
		return RadarState.COVERED
	if _locked:
		return RadarState.LOCKED
	if sector != null and (exposure > 0.01 or _lock_risk > 0.01):
		return RadarState.TRACKING
	return RadarState.LOW_PROFILE


func _emit_radar_notices(was_locked: bool, exposure: float) -> void:
	if (
		not _tracking_notice_emitted
		and exposure > 0.0
		and _lock_risk >= tracking_notice_threshold
	):
		_tracking_notice_emitted = true
		notice_requested.emit(TRACKING_NOTICE_KEY)
	if _locked and not _lock_notice_emitted:
		_lock_notice_emitted = true
		notice_requested.emit(LOCKED_NOTICE_KEY)
	if _locked and not _lock_consequence_emitted:
		_lock_consequence_emitted = true
		lock_consequence_requested.emit(
			lock_damage,
			lock_cargo_damage,
			LOCK_CONSEQUENCE_REASON_KEY
		)
	if was_locked and not _locked:
		notice_requested.emit(LOCK_LOST_NOTICE_KEY)


func _update_radar_visuals() -> void:
	for sector: FlightRadarSector in get_radar_sectors():
		sector.set_tracking_visual(
			_surface_active and sector.sector_id == _active_sector_id,
			_lock_risk,
			_scan_elapsed_seconds
		)


func _enter_landing_buffer() -> void:
	if _landing_buffer_active and _radar_state == RadarState.LANDING_BUFFER:
		return
	_landing_buffer_active = true
	var had_lock_pressure: bool = _locked or _lock_risk > 0.0
	_clear_radar_runtime()
	_radar_state = RadarState.LANDING_BUFFER
	if had_lock_pressure:
		notice_requested.emit(LOCK_LOST_NOTICE_KEY)
	_update_radar_visuals()


func _get_route_distance() -> float:
	if _flight_ship == null:
		return 0.0
	return maxf(_flight_ship.global_position.x - _route_origin_x, 0.0)


func _find_sector(global_point: Vector2) -> FlightRadarSector:
	for sector: FlightRadarSector in get_radar_sectors():
		if sector.contains_global_point(global_point):
			return sector
	return null


func _find_cover(global_point: Vector2) -> FlightRadarCover:
	for cover: FlightRadarCover in get_radar_covers():
		if cover.contains_global_point(global_point):
			return cover
	return null


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
