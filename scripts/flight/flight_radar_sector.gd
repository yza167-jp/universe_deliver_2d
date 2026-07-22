class_name FlightRadarSector
extends Area2D

@export var sector_id: StringName = &"red_sand_radar_sector"
@export_range(320.0, 20000.0, 1.0, "or_greater") var sector_width: float = 3200.0
@export_range(-200.0, 800.0, 1.0) var safe_boundary_y: float = 220.0
@export_range(-200.0, 800.0, 1.0) var emitter_y: float = 480.0

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _scan_band: Polygon2D = %ScanBand
@onready var _safe_boundary: Line2D = %SafeBoundary
@onready var _sweep_line: Line2D = %SweepLine
@onready var _emitter_visual: Node2D = %EmitterVisual
@onready var _pulse_visual: Polygon2D = %Pulse


func _ready() -> void:
	_configure_geometry()
	set_tracking_visual(false, 0.0, 0.0)


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if sector_id.is_empty():
		errors.append("Radar sector ID is empty.")
	if sector_width < 320.0:
		errors.append("Radar sector '%s' is too narrow." % sector_id)
	if safe_boundary_y >= emitter_y:
		errors.append("Radar sector '%s' must scan upward from its emitter." % sector_id)
	return errors


func contains_global_point(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	return absf(local_point.x) <= sector_width * 0.5


func set_tracking_visual(
	active: bool,
	lock_risk: float,
	elapsed_seconds: float,
	pulse_active: bool = false
) -> void:
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
		_emitter_visual.visible = active
		_emitter_visual.modulate = (
			Color(1.0, 0.42, 0.32, 1.0)
			if safe_risk >= 1.0
			else Color(1.0, 0.78, 0.42, 0.88 if active else 0.58)
		)
	if _pulse_visual != null:
		_pulse_visual.scale = Vector2.ONE * (1.75 if pulse_active else 1.0)
		_pulse_visual.modulate.a = 1.0 if pulse_active else 0.72


func is_scan_visual_visible() -> bool:
	return (
		_scan_band != null
		and _scan_band.visible
		and _safe_boundary != null
		and _safe_boundary.visible
		and _emitter_visual != null
		and _emitter_visual.visible
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
			Vector2(-sector_width * 0.5, safe_boundary_y),
			Vector2(sector_width * 0.5, safe_boundary_y),
			Vector2(sector_width * 0.5, emitter_y),
			Vector2(-sector_width * 0.5, emitter_y),
		])
	if _safe_boundary != null:
		_safe_boundary.points = PackedVector2Array([
			Vector2(-sector_width * 0.5, safe_boundary_y),
			Vector2(sector_width * 0.5, safe_boundary_y),
		])
	if _sweep_line != null:
		_sweep_line.points = PackedVector2Array([
			Vector2(0.0, emitter_y),
			Vector2(0.0, safe_boundary_y),
		])
	if _emitter_visual != null:
		_emitter_visual.position.y = emitter_y
