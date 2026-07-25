class_name LowAltitudeDropProfile
extends Resource

@export_range(0.0, 10000.0, 1.0, "or_greater") var minimum_release_altitude: float = 90.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var maximum_release_altitude: float = 220.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var minimum_release_speed: float = 90.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var maximum_release_speed: float = 240.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var core_zone_half_width: float = 110.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var outer_zone_half_width: float = 220.0
@export_range(0.01, 10000.0, 1.0, "or_greater") var cargo_descent_speed: float = 120.0
@export_range(0.0, 1.0, 0.01) var horizontal_velocity_inheritance: float = 0.65
@export_range(0.0, 1.0, 0.01) var partial_quality_ratio: float = 0.75
@export_range(0.0, 1.0, 0.01) var partial_reward_ratio: float = 0.65


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if minimum_release_altitude < 0.0:
		errors.append("minimum_release_altitude must not be negative")
	if maximum_release_altitude < minimum_release_altitude:
		errors.append("maximum_release_altitude must be at least the minimum")
	if minimum_release_speed < 0.0:
		errors.append("minimum_release_speed must not be negative")
	if maximum_release_speed < minimum_release_speed:
		errors.append("maximum_release_speed must be at least the minimum")
	if core_zone_half_width <= 0.0:
		errors.append("core_zone_half_width must be positive")
	if outer_zone_half_width < core_zone_half_width:
		errors.append("outer_zone_half_width must contain the core zone")
	if cargo_descent_speed <= 0.0:
		errors.append("cargo_descent_speed must be positive")
	if horizontal_velocity_inheritance < 0.0 or horizontal_velocity_inheritance > 1.0:
		errors.append("horizontal_velocity_inheritance must be between zero and one")
	if partial_quality_ratio < 0.0 or partial_quality_ratio > 1.0:
		errors.append("partial_quality_ratio must be between zero and one")
	if partial_reward_ratio < 0.0 or partial_reward_ratio > 1.0:
		errors.append("partial_reward_ratio must be between zero and one")
	return errors
