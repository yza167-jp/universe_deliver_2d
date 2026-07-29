class_name CockpitStarfield
extends Control

const DEEP_SPACE: Color = Color("08111f")
const DISTANT_GLOW: Color = Color(0.18, 0.31, 0.48, 0.22)
const RED_SAND_DARK: Color = Color("5e2f28")
const RED_SAND_SURFACE: Color = Color("b86445")
const RED_SAND_LIGHT: Color = Color("d99468")
const RED_SAND_ATMOSPHERE: Color = Color(0.95, 0.57, 0.36, 0.34)
const WHITE_NOISE_DARK: Color = Color("173d57")
const WHITE_NOISE_SURFACE: Color = Color("5f9faf")
const WHITE_NOISE_LIGHT: Color = Color("d9f5f4")
const WHITE_NOISE_ATMOSPHERE: Color = Color(0.33, 0.89, 0.79, 0.3)
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
var _travel_progress: float = 0.0
var _speed_multiplier: float = 1.0
var _destination_planet_id: StringName = M1ProgressRules.PLANET_RED_SAND


func _process(delta: float) -> void:
	advance_animation(delta)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DEEP_SPACE, true)
	_draw_destination()
	_draw_layer(FAR_STARS, _layer_offsets[0], FAR_STAR_COLOR, 1.0)
	_draw_layer(MID_STARS, _layer_offsets[1], MID_STAR_COLOR, 1.0)
	_draw_layer(NEAR_STARS, _layer_offsets[2], NEAR_STAR_COLOR, 2.0)


func advance_animation(delta: float) -> void:
	if delta <= 0.0 or size.x <= 0.0:
		return
	for layer_index: int in LAYER_SPEEDS.size():
		_layer_offsets[layer_index] = fposmod(
			_layer_offsets[layer_index]
			+ LAYER_SPEEDS[layer_index] * _speed_multiplier * delta,
			size.x
		)
	queue_redraw()


func set_travel_visuals(travel_progress: float, speed_multiplier: float) -> void:
	_travel_progress = clampf(travel_progress, 0.0, 1.0)
	_speed_multiplier = maxf(speed_multiplier, 0.0)
	queue_redraw()


func get_layer_count() -> int:
	return LAYER_SPEEDS.size()


func get_layer_offsets() -> PackedFloat32Array:
	return _layer_offsets.duplicate()


func get_travel_progress() -> float:
	return _travel_progress


func get_speed_multiplier() -> float:
	return _speed_multiplier


func set_destination_planet_id(planet_id: StringName) -> void:
	_destination_planet_id = (
		planet_id
		if not planet_id.is_empty()
		else M1ProgressRules.PLANET_RED_SAND
	)
	queue_redraw()


func get_destination_planet_id() -> StringName:
	return _destination_planet_id


func get_destination_palette_signature() -> StringName:
	return (
		&"white_noise_ice"
		if _destination_planet_id == M1ProgressRules.PLANET_WHITE_NOISE
		else &"red_sand_warm"
	)


func _draw_destination() -> void:
	if _travel_progress <= 0.0:
		draw_circle(Vector2(size.x * 0.72, size.y * 0.42), 34.0, DISTANT_GLOW)
		return
	var eased_progress: float = ease(_travel_progress, 1.7)
	var planet_center: Vector2 = Vector2(
		lerpf(size.x * 0.78, size.x * 0.69, eased_progress),
		lerpf(size.y * 0.43, size.y * 0.52, eased_progress)
	)
	var planet_radius: float = lerpf(8.0, 66.0, eased_progress)
	var is_white_noise: bool = (
		_destination_planet_id == M1ProgressRules.PLANET_WHITE_NOISE
	)
	var atmosphere_color: Color = (
		WHITE_NOISE_ATMOSPHERE if is_white_noise else RED_SAND_ATMOSPHERE
	)
	var dark_color: Color = (
		WHITE_NOISE_DARK if is_white_noise else RED_SAND_DARK
	)
	var surface_color: Color = (
		WHITE_NOISE_SURFACE if is_white_noise else RED_SAND_SURFACE
	)
	var light_color: Color = (
		WHITE_NOISE_LIGHT if is_white_noise else RED_SAND_LIGHT
	)
	draw_circle(planet_center, planet_radius + 5.0, atmosphere_color)
	draw_circle(planet_center, planet_radius, dark_color)
	draw_circle(
		planet_center + Vector2(-planet_radius * 0.18, -planet_radius * 0.12),
		planet_radius * 0.82,
		surface_color
	)
	draw_arc(
		planet_center + Vector2(-planet_radius * 0.12, planet_radius * 0.14),
		planet_radius * 0.55,
		0.15,
		2.55,
		18,
		light_color,
		maxf(1.0, planet_radius * 0.05)
	)
	if is_white_noise:
		draw_arc(
			planet_center + Vector2(planet_radius * 0.06, -planet_radius * 0.08),
			planet_radius * 0.68,
			3.45,
			5.85,
			20,
			Color(WHITE_NOISE_LIGHT, 0.72),
			maxf(1.0, planet_radius * 0.035)
		)


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
