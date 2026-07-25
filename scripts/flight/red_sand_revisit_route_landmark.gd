class_name RedSandRevisitRouteLandmark
extends Node2D

const FACILITY_DARK: Color = Color("142331")
const FACILITY_MID: Color = Color("294854")
const FACILITY_LIGHT: Color = Color("77c9c4")
const PIPE_RUST: Color = Color("8b4e38")
const WATER_BLUE: Color = Color("58a9bb")
const WARM_LIGHT: Color = Color("e7a85b")
const STEAM: Color = Color(0.82, 0.88, 0.84, 0.55)

@export var base_route_y: float = 250.0

var _route_origin_x: float = 0.0
var _route_distance: float = 0.0
var _surface_frame_offset_y: float = 0.0
var _steam_phase: float = 0.0


func _ready() -> void:
	set_process(visible)


func _process(delta: float) -> void:
	if not visible:
		return
	_steam_phase = fmod(_steam_phase + maxf(delta, 0.0) * 0.55, 1.0)
	queue_redraw()


func configure(route_origin_x: float, route_distance: float) -> bool:
	if not is_finite(route_origin_x) or not is_finite(route_distance):
		return false
	_route_origin_x = route_origin_x
	_route_distance = maxf(route_distance, 0.0)
	_sync_position()
	return true


func set_landmark_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)


func is_landmark_enabled() -> bool:
	return visible


func get_route_distance() -> float:
	return _route_distance


func set_surface_frame_offset_y(offset_y: float) -> void:
	if not is_finite(offset_y):
		return
	_surface_frame_offset_y = offset_y
	_sync_position()


func _sync_position() -> void:
	position = Vector2(
		_route_origin_x + _route_distance,
		base_route_y + _surface_frame_offset_y
	)


func _draw() -> void:
	if not visible:
		return
	# Cooling and water equipment is deliberately non-colliding: it is a changed
	# service-lane landmark, not a new hazard.
	draw_rect(Rect2(-210.0, -54.0, 420.0, 58.0), FACILITY_DARK, true)
	draw_rect(Rect2(-210.0, -54.0, 420.0, 58.0), FACILITY_LIGHT, false, 2.0)
	draw_rect(Rect2(-178.0, -112.0, 92.0, 58.0), FACILITY_MID, true)
	draw_rect(Rect2(-170.0, -102.0, 76.0, 34.0), WATER_BLUE.darkened(0.55), true)
	for x_offset: float in [-154.0, -132.0, -110.0]:
		draw_line(
			Vector2(x_offset, -54.0),
			Vector2(x_offset, -18.0),
			PIPE_RUST,
			6.0
		)
		draw_circle(Vector2(x_offset, -64.0), 5.0, FACILITY_LIGHT)
	draw_rect(Rect2(-40.0, -96.0, 118.0, 42.0), FACILITY_MID, true)
	draw_line(Vector2(-30.0, -73.0), Vector2(68.0, -73.0), WATER_BLUE, 5.0)
	for light_x: float in [-188.0, -72.0, 8.0, 94.0, 176.0]:
		draw_circle(Vector2(light_x, -48.0), 3.0, WARM_LIGHT)
	draw_line(Vector2(-216.0, -18.0), Vector2(218.0, -18.0), PIPE_RUST, 8.0)
	draw_line(Vector2(-216.0, -18.0), Vector2(218.0, -18.0), WARM_LIGHT.darkened(0.45), 2.0)
	for resident_x: float in [106.0, 132.0, 160.0]:
		draw_circle(Vector2(resident_x, -30.0), 4.0, WARM_LIGHT)
		draw_line(
			Vector2(resident_x, -26.0),
			Vector2(resident_x, -14.0),
			FACILITY_LIGHT,
			3.0
		)
	for steam_index: int in 4:
		var steam_progress: float = fmod(
			_steam_phase + float(steam_index) * 0.23,
			1.0
		)
		var steam_x: float = -62.0 + float(steam_index % 2) * 18.0
		var steam_y: float = -98.0 - steam_progress * 42.0
		draw_circle(
			Vector2(steam_x + sin(steam_progress * TAU) * 4.0, steam_y),
			3.0 + steam_progress * 2.0,
			Color(STEAM, STEAM.a * (1.0 - steam_progress))
		)
