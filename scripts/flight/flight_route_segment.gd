class_name FlightRouteSegment
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var instruction_key: StringName = &""
@export var checkpoint_id: StringName = &""
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var start_distance: float = 0.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var end_distance: float = 1.0
@export var environment_profile: FlightEnvironmentProfile
@export_range(0.05, 20.0, 0.01, "or_greater")
var planet_scale_start: float = 1.0
@export_range(0.05, 20.0, 0.01, "or_greater")
var planet_scale_end: float = 1.0
@export_range(-2000.0, 2000.0, 1.0)
var floor_y: float = 1000.0
@export var graybox_color: Color = Color(0.12, 0.16, 0.2, 1.0)


func get_length() -> float:
	return maxf(end_distance - start_distance, 0.0)


func get_progress(route_distance: float) -> float:
	var length: float = get_length()
	if length <= 0.0:
		return 0.0
	return clampf((route_distance - start_distance) / length, 0.0, 1.0)


func get_planet_scale(route_distance: float) -> float:
	return lerpf(
		planet_scale_start,
		planet_scale_end,
		get_progress(route_distance)
	)
