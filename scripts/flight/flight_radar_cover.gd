class_name FlightRadarCover
extends Area2D

@export var cover_id: StringName = &"red_sand_radar_cover"
@export var cover_size: Vector2 = Vector2(1200.0, 180.0)

@onready var _collision_shape: CollisionShape2D = %CollisionShape2D
@onready var _hint_outline: Line2D = %HintOutline


func _ready() -> void:
	_configure_geometry()


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if cover_id.is_empty():
		errors.append("Radar cover ID is empty.")
	if cover_size.x <= 0.0 or cover_size.y <= 0.0:
		errors.append("Radar cover '%s' has an invalid size." % cover_id)
	return errors


func contains_global_point(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	return (
		absf(local_point.x) <= cover_size.x * 0.5
		and absf(local_point.y) <= cover_size.y * 0.5
	)


func set_hint_visible(visible: bool) -> void:
	if _hint_outline != null:
		_hint_outline.visible = visible


func _configure_geometry() -> void:
	var rectangle: RectangleShape2D = null
	if _collision_shape != null:
		rectangle = _collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = cover_size
	if _hint_outline != null:
		var half_size: Vector2 = cover_size * 0.5
		_hint_outline.points = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y),
			Vector2(-half_size.x, -half_size.y),
		])
