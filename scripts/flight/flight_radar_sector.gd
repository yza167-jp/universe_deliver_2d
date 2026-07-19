class_name FlightRadarSector
extends Area2D

@export var sector_id: StringName = &"red_sand_radar_sector"
@export_range(320.0, 20000.0, 1.0, "or_greater") var sector_width: float = 3200.0
@export_range(-200.0, 800.0, 1.0) var safe_altitude_y: float = 350.0
@export_range(1.0, 500.0, 1.0, "or_greater") var full_exposure_height: float = 120.0
@export_range(0.1, 4.0, 0.05, "or_greater") var acquire_rate_multiplier: float = 1.0
@export_range(-200.0, 800.0, 1.0) var emitter_y: float = 480.0

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _scan_band: Polygon2D = %ScanBand
@onready var _safe_boundary: Line2D = %SafeBoundary
@onready var _sweep_line: Line2D = %SweepLine
@onready var _emitter_visual: Node2D = %EmitterVisual


func _ready() -> void:
	_configure_geometry()
	set_tracking_visual(false, 0.0, 0.0)


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if sector_id.is_empty():
		errors.append("Radar sector ID is empty.")
	if sector_width < 320.0:
		errors.append("Radar sector '%s' is too narrow." % sector_id)
	if full_exposure_height <= 0.0:
		errors.append("Radar sector '%s' has no altitude transition." % sector_id)
	if acquire_rate_multiplier <= 0.0:
		errors.append("Radar sector '%s' has no acquisition rate." % sector_id)
	return errors


func contains_global_point(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	return (
		absf(local_point.x) <= sector_width * 0.5
		and local_point.y >= -420.0
		and local_point.y <= 780.0
	)


func calculate_exposure(global_point: Vector2) -> float:
	if not contains_global_point(global_point):
		return 0.0
	return FlightRadarModel.calculate_altitude_exposure(
		global_point.y,
		safe_altitude_y,
		full_exposure_height
	)


func set_tracking_visual(active: bool, lock_risk: float, elapsed_seconds: float) -> void:
	var safe_risk: float = clampf(lock_risk, 0.0, 1.0)
	if _scan_band != null:
		_scan_band.visible = active
		_scan_band.modulate.a = 0.34 + safe_risk * 0.5
	if _safe_boundary != null:
		_safe_boundary.visible = active
		_safe_boundary.modulate.a = 0.46 + safe_risk * 0.5
	if _sweep_line != null:
		_sweep_line.visible = active
		_sweep_line.position.x = lerpf(
			-sector_width * 0.5,
			sector_width * 0.5,
			fposmod(maxf(elapsed_seconds, 0.0) * 0.32, 1.0)
		)
		_sweep_line.modulate.a = 0.42 + safe_risk * 0.58
	if _emitter_visual != null:
		_emitter_visual.modulate = (
			Color(1.0, 0.42, 0.32, 1.0)
			if safe_risk >= 1.0
			else Color(1.0, 0.78, 0.42, 0.88 if active else 0.58)
		)


func _configure_geometry() -> void:
	var rectangle: RectangleShape2D = null
	if _collision_shape != null:
		rectangle = _collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = Vector2(sector_width, 1200.0)
		_collision_shape.position.y = 180.0
	if _scan_band != null:
		_scan_band.polygon = PackedVector2Array([
			Vector2(-sector_width * 0.5, -420.0),
			Vector2(sector_width * 0.5, -420.0),
			Vector2(sector_width * 0.5, safe_altitude_y),
			Vector2(-sector_width * 0.5, safe_altitude_y),
		])
	if _safe_boundary != null:
		_safe_boundary.points = PackedVector2Array([
			Vector2(-sector_width * 0.5, safe_altitude_y),
			Vector2(sector_width * 0.5, safe_altitude_y),
		])
	if _sweep_line != null:
		_sweep_line.points = PackedVector2Array([
			Vector2(0.0, -420.0),
			Vector2(0.0, safe_altitude_y),
		])
	if _emitter_visual != null:
		_emitter_visual.position.y = emitter_y
