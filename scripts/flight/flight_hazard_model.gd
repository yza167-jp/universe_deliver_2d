class_name FlightHazardModel
extends RefCounted


static func calculate_assist_mitigation(
	assist_strength: float,
	maximum_reduction: float
) -> float:
	return clampf(assist_strength, 0.0, 1.0) * clampf(
		maximum_reduction,
		0.0,
		1.0
	)


## Returns deterministic wind so every retry presents the same control problem.
static func calculate_storm_wind(
	base_acceleration: Vector2,
	gust_acceleration: Vector2,
	gust_frequency_hz: float,
	elapsed_seconds: float,
	assist_strength: float,
	maximum_assist_reduction: float
) -> Vector2:
	var safe_frequency: float = maxf(gust_frequency_hz, 0.0)
	var safe_elapsed: float = maxf(elapsed_seconds, 0.0)
	var primary_wave: float = sin(TAU * safe_frequency * safe_elapsed)
	var secondary_wave: float = sin(
		TAU * safe_frequency * 2.3 * safe_elapsed + 0.75
	) * 0.35
	var gust_phase: float = clampf(
		(primary_wave + secondary_wave) / 1.35,
		-1.0,
		1.0
	)
	var mitigation: float = calculate_assist_mitigation(
		assist_strength,
		maximum_assist_reduction
	)
	return (base_acceleration + gust_acceleration * gust_phase) * (
		1.0 - mitigation
	)


static func step_velocity(
	current_velocity: Vector2,
	acceleration: Vector2,
	delta: float,
	maximum_speed: float
) -> Vector2:
	if delta <= 0.0:
		return current_velocity
	var next_velocity: Vector2 = current_velocity + acceleration * delta
	var safe_maximum_speed: float = maxf(maximum_speed, 0.0)
	if safe_maximum_speed <= 0.0:
		return next_velocity
	return next_velocity.limit_length(safe_maximum_speed)
