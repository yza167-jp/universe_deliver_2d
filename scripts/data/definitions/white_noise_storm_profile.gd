class_name WhiteNoiseStormProfile
extends Resource

## Data authority for the deterministic White Noise electromagnetic blizzard.

@export var id: StringName = &"white_noise_electromagnetic_blizzard_m1"
@export_range(0.0, 100000.0, 1.0, "or_greater") var trigger_distance: float = 17000.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var warning_end_distance: float = 17700.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var recovery_start_distance: float = 22000.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var end_distance: float = 23000.0
@export_range(0.1, 30.0, 0.1, "or_greater") var warning_duration_seconds: float = 2.4
@export_range(0.1, 60.0, 0.1, "or_greater") var active_duration_seconds: float = 12.0
@export_range(0.1, 30.0, 0.1, "or_greater") var recovery_duration_seconds: float = 2.8
@export_range(0.0, 1.0, 0.01) var interference_intensity: float = 0.86
@export_range(0.0, 100.0, 0.1, "or_greater") var high_voltage_damage: float = 18.0
@export_range(0.0, 100.0, 0.1, "or_greater") var cargo_damage: float = 3.0
@export_range(0.1, 30.0, 0.1, "or_greater") var pulse_interval_seconds: float = 4.0
@export_range(0.0, 1.0, 0.01) var visibility_intensity: float = 0.78
@export_range(0.05, 2.0, 0.01, "or_greater") var noncritical_hud_update_seconds: float = 0.34
@export_range(0.1, 1.0, 0.05) var slow_motion_time_scale: float = 0.55


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("White Noise storm profile ID is empty.")
	if (
		trigger_distance < 0.0
		or warning_end_distance <= trigger_distance
		or recovery_start_distance <= warning_end_distance
		or end_distance <= recovery_start_distance
	):
		errors.append("White Noise storm distance gates must be strictly increasing.")
	if (
		warning_duration_seconds <= 0.0
		or active_duration_seconds <= 0.0
		or recovery_duration_seconds <= 0.0
	):
		errors.append("White Noise storm phase durations must be positive.")
	if interference_intensity <= 0.0 or interference_intensity > 1.0:
		errors.append("White Noise storm interference intensity must stay in (0, 1].")
	if high_voltage_damage <= 0.0:
		errors.append("White Noise storm high-voltage damage must be positive.")
	if cargo_damage < 0.0:
		errors.append("White Noise storm cargo damage cannot be negative.")
	if pulse_interval_seconds <= 0.0:
		errors.append("White Noise storm pulse interval must be positive.")
	if visibility_intensity <= 0.0 or visibility_intensity > 1.0:
		errors.append("White Noise storm visibility intensity must stay in (0, 1].")
	if noncritical_hud_update_seconds <= 0.0:
		errors.append("White Noise noncritical HUD interval must be positive.")
	if slow_motion_time_scale <= 0.0 or slow_motion_time_scale > 1.0:
		errors.append("White Noise warning slow-motion scale must stay in (0, 1].")
	return errors


func get_nominal_duration_seconds() -> float:
	return (
		warning_duration_seconds
		+ active_duration_seconds
		+ recovery_duration_seconds
	)
