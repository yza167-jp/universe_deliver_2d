class_name FlightCollisionResolver
extends RefCounted


## Classifies a collision from the incoming velocity component along its normal.
static func resolve(
	incoming_velocity: Vector2,
	collision_normal: Vector2,
	cargo_tolerance: float,
	tuning: FlightTuning
) -> FlightCollisionResult:
	var result: FlightCollisionResult = FlightCollisionResult.new()
	if tuning == null or collision_normal.is_zero_approx():
		return result

	result.impact_normal = collision_normal.normalized()
	result.impact_speed = absf(incoming_velocity.dot(result.impact_normal))
	if result.impact_speed < maxf(tuning.minimum_impact_speed, 0.0):
		return result

	if result.impact_speed >= maxf(
		tuning.fatal_impact_speed,
		tuning.safe_graze_speed
	):
		result.severity = FlightCollisionResult.Severity.FATAL
		result.total_damage = maxf(tuning.fatal_impact_damage, 0.0)
		result.cargo_damage = maxf(tuning.fatal_cargo_damage, 0.0)
		result.should_fail = true
		result.state_key = &"UI_FLIGHT_LAB_COLLISION_FATAL"
		return result

	if result.impact_speed <= maxf(tuning.safe_graze_speed, 0.0):
		result.severity = FlightCollisionResult.Severity.GRAZE
		result.total_damage = maxf(tuning.graze_shield_damage, 0.0)
		result.state_key = &"UI_FLIGHT_LAB_COLLISION_GRAZE"
		return result

	var hard_range: float = maxf(
		tuning.fatal_impact_speed - tuning.safe_graze_speed,
		0.001
	)
	var hard_fraction: float = clampf(
		(result.impact_speed - tuning.safe_graze_speed) / hard_range,
		0.0,
		1.0
	)
	result.severity = FlightCollisionResult.Severity.HARD
	result.total_damage = lerpf(
		maxf(tuning.hard_impact_min_damage, 0.0),
		maxf(tuning.hard_impact_max_damage, 0.0),
		hard_fraction
	)
	result.cargo_damage = lerpf(
		maxf(tuning.hard_cargo_min_damage, 0.0),
		maxf(tuning.hard_cargo_max_damage, 0.0),
		hard_fraction
	) * (1.0 - clampf(cargo_tolerance, 0.0, 1.0))
	result.state_key = &"UI_FLIGHT_LAB_COLLISION_HARD"
	return result
