class_name CockpitStarfield
extends Control

const DEEP_SPACE: Color = Color("08111f")
const DISTANT_GLOW: Color = Color(0.18, 0.31, 0.48, 0.22)
const FAR_STAR_COLOR: Color = Color("70849a")
const MID_STAR_COLOR: Color = Color("b7c8d7")
const NEAR_STAR_COLOR: Color = Color("e8dfc8")

const LAYER_SPEEDS: Array[float] = [4.0, 9.0, 18.0]
const FAR_STARS: Array[Vector2] = [
	Vector2(18.0, 24.0), Vector2(72.0, 86.0), Vector2(118.0, 42.0),
	Vector2(166.0, 116.0), Vector2(226.0, 20.0), Vector2(276.0, 74.0),
	Vector2(334.0, 126.0), Vector2(392.0, 48.0), Vector2(430.0, 104.0),
]
const MID_STARS: Array[Vector2] = [
	Vector2(42.0, 58.0), Vector2(96.0, 130.0), Vector2(154.0, 18.0),
	Vector2(204.0, 92.0), Vector2(258.0, 138.0), Vector2(312.0, 52.0),
	Vector2(364.0, 98.0), Vector2(418.0, 30.0),
]
const NEAR_STARS: Array[Vector2] = [
	Vector2(28.0, 118.0), Vector2(138.0, 72.0), Vector2(242.0, 38.0),
	Vector2(348.0, 142.0), Vector2(444.0, 82.0),
]

var _layer_offsets: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])


func _process(delta: float) -> void:
	advance_animation(delta)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DEEP_SPACE, true)
	draw_circle(Vector2(size.x * 0.72, size.y * 0.42), 34.0, DISTANT_GLOW)
	_draw_layer(FAR_STARS, _layer_offsets[0], FAR_STAR_COLOR, 1.0)
	_draw_layer(MID_STARS, _layer_offsets[1], MID_STAR_COLOR, 1.0)
	_draw_layer(NEAR_STARS, _layer_offsets[2], NEAR_STAR_COLOR, 2.0)


func advance_animation(delta: float) -> void:
	if delta <= 0.0 or size.x <= 0.0:
		return
	for layer_index: int in LAYER_SPEEDS.size():
		_layer_offsets[layer_index] = fposmod(
			_layer_offsets[layer_index] + LAYER_SPEEDS[layer_index] * delta,
			size.x
		)
	queue_redraw()


func get_layer_count() -> int:
	return LAYER_SPEEDS.size()


func get_layer_offsets() -> PackedFloat32Array:
	return _layer_offsets.duplicate()


func _draw_layer(
	stars: Array[Vector2],
	horizontal_offset: float,
	color: Color,
	pixel_size: float
) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for star: Vector2 in stars:
		var position: Vector2 = Vector2(
			fposmod(star.x - horizontal_offset, size.x),
			fposmod(star.y, size.y)
		)
		draw_rect(Rect2(position, Vector2.ONE * pixel_size), color, true)
