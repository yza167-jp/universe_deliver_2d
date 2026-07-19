class_name FlightRadarModel
extends RefCounted


static func calculate_altitude_exposure(
	ship_y: float,
	safe_altitude_y: float,
	full_exposure_height: float
) -> float:
	var safe_height: float = maxf(full_exposure_height, 1.0)
	return clampf((safe_altitude_y - ship_y) / safe_height, 0.0, 1.0)


static func step_lock_risk(
	current_risk: float,
	exposure: float,
	in_scan_sector: bool,
	terrain_covered: bool,
	delta: float,
	acquire_rate: float,
	decay_rate: float
) -> float:
	var safe_delta: float = maxf(delta, 0.0)
	var safe_risk: float = clampf(current_risk, 0.0, 1.0)
	var safe_exposure: float = clampf(exposure, 0.0, 1.0)
	if not in_scan_sector or terrain_covered or safe_exposure <= 0.0:
		return move_toward(
			safe_risk,
			0.0,
			maxf(decay_rate, 0.0) * safe_delta
		)
	return clampf(
		safe_risk + safe_exposure * maxf(acquire_rate, 0.0) * safe_delta,
		0.0,
		1.0
	)


static func resolve_lock_state(
	lock_risk: float,
	was_locked: bool,
	terrain_covered: bool,
	release_threshold: float
) -> bool:
	if terrain_covered:
		return false
	var safe_risk: float = clampf(lock_risk, 0.0, 1.0)
	if was_locked:
		return safe_risk > clampf(release_threshold, 0.0, 1.0)
	return safe_risk >= 1.0
