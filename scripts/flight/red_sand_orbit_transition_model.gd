class_name RedSandOrbitTransitionModel
extends RefCounted

const TRANSITION_START_DISTANCE: float = 11800.0
const TRANSITION_END_DISTANCE: float = 15800.0
const TRANSITION_WINDOW_DISTANCE: float = (
	TRANSITION_END_DISTANCE - TRANSITION_START_DISTANCE
)
const VIEWPORT_HEIGHT: float = 360.0
const PLANET_LOCAL_RADIUS: float = 48.0
const PLANET_FADE_START_VISIBLE_HEIGHT: float = 112.0
const PLANET_FADE_END_VISIBLE_HEIGHT: float = 84.0

var _start_position: Vector2
var _start_scale: float
var _end_position: Vector2
var _end_scale: float
var _route_distance: float = 0.0


func _init(
	start_position: Vector2 = Vector2.ZERO,
	start_scale: float = 1.0,
	end_position: Vector2 = Vector2.ZERO,
	end_scale: float = 1.0
) -> void:
	_start_position = start_position
	_start_scale = maxf(start_scale, 0.0)
	_end_position = end_position
	_end_scale = maxf(end_scale, _start_scale)


## Advances the visual window monotonically so a short correction burn cannot rewind it.
func advance_to_distance(route_distance: float) -> void:
	_route_distance = maxf(_route_distance, maxf(route_distance, 0.0))


## Checkpoint and full-route restarts deliberately bypass monotonic advancement.
func reset_to_distance(route_distance: float) -> void:
	_route_distance = maxf(route_distance, 0.0)


func get_route_distance() -> float:
	return _route_distance


func get_progress() -> float:
	return clampf(
		(_route_distance - TRANSITION_START_DISTANCE) / TRANSITION_WINDOW_DISTANCE,
		0.0,
		1.0
	)


func get_motion_progress() -> float:
	return smoothstep(0.0, 1.0, get_progress())


func get_planet_position() -> Vector2:
	return _start_position.lerp(_end_position, get_motion_progress())


func get_planet_scale() -> float:
	return lerpf(_start_scale, _end_scale, get_motion_progress())


func get_planet_visible_height() -> float:
	var planet_top: float = (
		get_planet_position().y - PLANET_LOCAL_RADIUS * get_planet_scale()
	)
	return maxf(VIEWPORT_HEIGHT - planet_top, 0.0)


## The disc stays opaque until only a thin off-screen-edge cap remains.
func get_planet_alpha() -> float:
	return smoothstep(
		PLANET_FADE_END_VISIBLE_HEIGHT,
		PLANET_FADE_START_VISIBLE_HEIGHT,
		get_planet_visible_height()
	)


## One value drives the curved horizon, its glow, and the high-cloud veil together.
func get_atmosphere_progress() -> float:
	return get_motion_progress()


func get_horizon_progress() -> float:
	return get_atmosphere_progress()


func get_glow_progress() -> float:
	return get_atmosphere_progress()


func get_high_cloud_progress() -> float:
	return get_atmosphere_progress()


func get_star_fade_progress() -> float:
	return get_atmosphere_progress()


static func get_nominal_duration_seconds(route_speed: float) -> float:
	if route_speed <= 0.0:
		return 0.0
	return TRANSITION_WINDOW_DISTANCE / route_speed
