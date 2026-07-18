class_name FlightEnvironmentProfile
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""

@export_group("Gravity and Atmosphere")
@export_range(0.0, 1200.0, 1.0, "or_greater")
var planet_gravity: float = 0.0
@export_range(0.0, 1.0, 0.01)
var target_gravity_blend: float = 0.0
@export_range(0.0, 1.0, 0.01)
var target_air_density: float = 0.0
@export_range(0.0, 5.0, 0.01, "or_greater")
var horizontal_drag: float = 0.0
@export_range(0.0, 5.0, 0.01, "or_greater")
var vertical_drag: float = 0.0
@export_range(0.0, 1200.0, 1.0, "or_greater")
var terminal_fall_speed_safety: float = 0.0

@export_group("Transition")
@export_range(0.01, 10.0, 0.01, "or_greater")
var transition_rate: float = 0.6
