class_name FlightRadarModel
extends RefCounted

const ALTITUDE_COMPARISON_TOLERANCE_METERS: float = 0.01


static func calculate_altitude_exposure(
	altitude_meters: float,
	minimum_safe_altitude_meters: float,
	full_exposure_depth_meters: float
) -> float:
	var safe_depth: float = maxf(full_exposure_depth_meters, 1.0)
	return clampf(
		(minimum_safe_altitude_meters - altitude_meters) / safe_depth,
		0.0,
		1.0
	)


static func is_low_altitude(
	altitude_meters: float,
	minimum_safe_altitude_meters: float
) -> bool:
	return (
		altitude_meters + ALTITUDE_COMPARISON_TOLERANCE_METERS
		< maxf(minimum_safe_altitude_meters, 0.0)
	)


static func calculate_phase_progress(elapsed_seconds: float, duration_seconds: float) -> float:
	return clampf(
		maxf(elapsed_seconds, 0.0) / maxf(duration_seconds, 0.001),
		0.0,
		1.0
	)


static func calculate_cooldown_pressure(
	elapsed_seconds: float,
	duration_seconds: float
) -> float:
	return 1.0 - calculate_phase_progress(elapsed_seconds, duration_seconds)
