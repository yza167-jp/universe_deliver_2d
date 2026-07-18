class_name FlightTuning
extends Resource

@export_group("Linear Motion")
@export_range(0.0, 1000.0, 1.0, "or_greater")
var thrust_acceleration: float = 240.0
@export_range(0.0, 1000.0, 1.0, "or_greater")
var brake_acceleration: float = 300.0
@export_range(0.0, 1.0, 0.001, "or_greater")
var space_drag: float = 0.045
@export_range(1.0, 1200.0, 1.0, "or_greater")
var max_forward_speed: float = 440.0
@export_range(1.0, 1600.0, 1.0, "or_greater")
var max_total_speed: float = 520.0
@export_range(0.0, 50.0, 0.5, "or_greater")
var brake_deadzone: float = 4.0

@export_group("Pitch")
@export_range(0.0, 8.0, 0.05, "or_greater")
var max_pitch_rate: float = 2.4
@export_range(0.0, 30.0, 0.1, "or_greater")
var pitch_acceleration: float = 7.0
@export_range(0.0, 30.0, 0.1, "or_greater")
var angular_damping: float = 5.0
@export_range(5.0, 85.0, 1.0)
var max_pitch_degrees: float = 70.0

@export_group("Flight Assist")
@export_range(0.0, 1.0, 0.01)
var free_assist_strength: float = 0.75
@export_range(0.0, 20.0, 0.1, "or_greater")
var full_assist_fuel_cost_per_second: float = 2.0


func get_max_pitch_radians() -> float:
	return deg_to_rad(maxf(max_pitch_degrees, 0.0))


func get_free_assist_strength() -> float:
	return clampf(free_assist_strength, 0.0, 1.0)
