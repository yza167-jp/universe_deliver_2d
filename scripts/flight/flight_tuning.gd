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

@export_group("Boost and Resources")
@export_range(1.0, 5.0, 0.05, "or_greater")
var boost_multiplier: float = 2.2
@export_range(0.0, 20.0, 0.05, "or_greater")
var thrust_fuel_cost_per_second: float = 0.35
@export_range(0.0, 20.0, 0.05, "or_greater")
var boost_fuel_cost_per_second: float = 1.8
@export_range(0.0, 100.0, 0.5, "or_greater")
var boost_energy_cost_per_second: float = 24.0
@export_range(0.0, 100.0, 0.5, "or_greater")
var boost_energy_recovery_per_second: float = 12.0
@export_range(0.0, 5.0, 0.05, "or_greater")
var boost_recovery_delay_seconds: float = 0.6
@export_range(0.0, 1.0, 0.05)
var limited_cargo_boost_cap: float = 0.75
@export_range(0.0, 1.0, 0.05)
var emergency_thrust_multiplier: float = 0.3

@export_group("Asteroid Laser")
@export_range(0.0, 1600.0, 1.0, "or_greater")
var laser_range: float = 560.0
@export_range(0.0, 2.0, 0.01, "or_greater")
var laser_cooldown_seconds: float = 0.22
@export_range(0.0, 1.0, 0.01, "or_greater")
var laser_beam_duration_seconds: float = 0.07
@export_range(0, 20, 1, "or_greater")
var laser_damage: int = 1

@export_group("Entry Style")
@export_range(0.0, 30.0, 0.1, "or_greater")
var entry_style_min_sample_seconds: float = 1.0
@export_range(0.0, 1200.0, 1.0, "or_greater")
var dive_min_downward_speed: float = 190.0
@export_range(0.0, 1.0, 0.01)
var dive_min_risk_or_heat: float = 0.72
@export_range(0.0, 120.0, 0.5, "or_greater")
var dive_max_duration_seconds: float = 6.0
@export_range(0.0, 1600.0, 1.0, "or_greater")
var dive_short_entry_min_total_speed: float = 260.0
@export_range(0, 20, 1, "or_greater")
var dive_max_scenic_trigger_count: int = 0
@export_range(0.0, 120.0, 0.5, "or_greater")
var glide_min_duration_seconds: float = 8.0
@export_range(0.0, 1200.0, 1.0, "or_greater")
var glide_max_downward_speed: float = 110.0
@export_range(0.0, 1.0, 0.01)
var glide_max_risk_or_heat: float = 0.45
@export_range(0, 20, 1, "or_greater")
var glide_min_scenic_trigger_count: int = 2
@export_range(0.0, 120.0, 0.5, "or_greater")
var late_pull_up_min_elapsed_seconds: float = 3.0
@export_range(0.0, 1200.0, 1.0, "or_greater")
var late_pull_up_arm_downward_speed: float = 180.0
@export_range(0.0, 1200.0, 1.0, "or_greater")
var late_pull_up_recovery_downward_speed: float = 70.0

@export_group("Collision")
@export_range(0.0, 200.0, 1.0, "or_greater")
var minimum_impact_speed: float = 20.0
@export_range(0.0, 400.0, 1.0, "or_greater")
var safe_graze_speed: float = 90.0
@export_range(1.0, 800.0, 1.0, "or_greater")
var fatal_impact_speed: float = 280.0
@export_range(0.0, 100.0, 0.5, "or_greater")
var graze_shield_damage: float = 3.0
@export_range(0.0, 200.0, 0.5, "or_greater")
var hard_impact_min_damage: float = 24.0
@export_range(0.0, 200.0, 0.5, "or_greater")
var hard_impact_max_damage: float = 72.0
@export_range(0.0, 100.0, 0.5, "or_greater")
var hard_cargo_min_damage: float = 12.0
@export_range(0.0, 100.0, 0.5, "or_greater")
var hard_cargo_max_damage: float = 36.0
@export_range(0.0, 400.0, 1.0, "or_greater")
var fatal_impact_damage: float = 220.0
@export_range(0.0, 200.0, 1.0, "or_greater")
var fatal_cargo_damage: float = 100.0
@export_range(0.0, 2.0, 0.01, "or_greater")
var collision_feedback_cooldown_seconds: float = 0.18
@export_range(0.0, 1.0, 0.05)
var hard_impact_velocity_retention: float = 0.35
@export_range(0.0, 2.0, 0.05, "or_greater")
var failure_retry_delay_seconds: float = 0.35
@export_range(0.0, 20.0, 0.25, "or_greater")
var graze_camera_shake: float = 2.0
@export_range(0.0, 20.0, 0.25, "or_greater")
var hard_camera_shake: float = 5.0
@export_range(0.0, 20.0, 0.25, "or_greater")
var fatal_camera_shake: float = 8.0
@export_range(0.0, 2.0, 0.01, "or_greater")
var collision_camera_shake_duration: float = 0.2

@export_group("Cargo Warnings")
@export_range(0.0, 100.0, 1.0)
var cargo_warning_high_threshold: float = 90.0
@export_range(0.0, 100.0, 1.0)
var cargo_warning_medium_threshold: float = 60.0
@export_range(0.0, 100.0, 1.0)
var cargo_warning_low_threshold: float = 30.0


func get_max_pitch_radians() -> float:
	return deg_to_rad(maxf(max_pitch_degrees, 0.0))


func get_free_assist_strength() -> float:
	return clampf(free_assist_strength, 0.0, 1.0)
