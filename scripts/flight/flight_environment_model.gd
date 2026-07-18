class_name FlightEnvironmentModel
extends RefCounted

const MIN_DRAG_COEFFICIENT: float = 0.000001


## Moves a normalized environment value toward its configured target without a hard cut.
static func step_environment_value(
	current_value: float,
	target_value: float,
	transition_rate: float,
	delta: float
) -> float:
	var safe_current: float = clampf(current_value, 0.0, 1.0)
	if delta <= 0.0:
		return safe_current
	return move_toward(
		safe_current,
		clampf(target_value, 0.0, 1.0),
		maxf(transition_rate, 0.0) * delta
	)


static func calculate_effective_assist_strength(
	requested_assist_strength: float,
	fuel_available: float,
	tuning: FlightTuning
) -> float:
	var requested: float = clampf(requested_assist_strength, 0.0, 1.0)
	if tuning == null or fuel_available > 0.0:
		return requested
	return minf(requested, tuning.get_free_assist_strength())


static func calculate_assist_fuel_cost_rate(
	requested_assist_strength: float,
	gravity_blend: float,
	fuel_available: float,
	tuning: FlightTuning
) -> float:
	if tuning == null or fuel_available <= 0.0:
		return 0.0
	var free_strength: float = tuning.get_free_assist_strength()
	var paid_range: float = 1.0 - free_strength
	if paid_range <= 0.0:
		return 0.0
	var paid_fraction: float = clampf(
		(clampf(requested_assist_strength, 0.0, 1.0) - free_strength)
		/ paid_range,
		0.0,
		1.0
	)
	return (
		maxf(tuning.full_assist_fuel_cost_per_second, 0.0)
		* paid_fraction
		* clampf(gravity_blend, 0.0, 1.0)
	)


static func calculate_effective_gravity(
	profile: FlightEnvironmentProfile,
	gravity_blend: float,
	effective_assist_strength: float
) -> float:
	if profile == null:
		return 0.0
	return (
		maxf(profile.planet_gravity, 0.0)
		* clampf(gravity_blend, 0.0, 1.0)
		* (1.0 - clampf(effective_assist_strength, 0.0, 1.0))
	)


static func calculate_drag_coefficients(
	profile: FlightEnvironmentProfile,
	air_density: float,
	base_space_drag: float
) -> Vector2:
	var safe_space_drag: float = maxf(base_space_drag, 0.0)
	if profile == null:
		return Vector2(safe_space_drag, safe_space_drag)
	var safe_density: float = clampf(air_density, 0.0, 1.0)
	return Vector2(
		safe_space_drag + maxf(profile.horizontal_drag, 0.0) * safe_density,
		safe_space_drag + maxf(profile.vertical_drag, 0.0) * safe_density
	)


## Integrates linear drag analytically so gravity converges to a stable terminal speed.
static func step_velocity(
	current_velocity: Vector2,
	effective_gravity: float,
	profile: FlightEnvironmentProfile,
	air_density: float,
	base_space_drag: float,
	delta: float
) -> Vector2:
	if delta <= 0.0:
		return current_velocity
	var drag: Vector2 = calculate_drag_coefficients(
		profile,
		air_density,
		base_space_drag
	)
	var next_velocity: Vector2 = Vector2(
		_step_axis(current_velocity.x, 0.0, drag.x, delta),
		_step_axis(
			current_velocity.y,
			maxf(effective_gravity, 0.0),
			drag.y,
			delta
		)
	)
	return apply_terminal_fall_speed_safety(next_velocity, profile, air_density)


static func calculate_natural_terminal_fall_speed(
	effective_gravity: float,
	profile: FlightEnvironmentProfile,
	air_density: float,
	base_space_drag: float
) -> float:
	if effective_gravity <= 0.0:
		return 0.0
	var vertical_drag: float = calculate_drag_coefficients(
		profile,
		air_density,
		base_space_drag
	).y
	if vertical_drag <= MIN_DRAG_COEFFICIENT:
		return INF
	return effective_gravity / vertical_drag


static func apply_terminal_fall_speed_safety(
	current_velocity: Vector2,
	profile: FlightEnvironmentProfile,
	safety_blend: float = 1.0
) -> Vector2:
	var safe_blend: float = clampf(safety_blend, 0.0, 1.0)
	if (
		profile == null
		or profile.terminal_fall_speed_safety <= 0.0
		or safe_blend <= 0.0
	):
		return current_velocity
	var blended_safety_limit: float = (
		profile.terminal_fall_speed_safety / safe_blend
	)
	return Vector2(
		current_velocity.x,
		minf(current_velocity.y, blended_safety_limit)
	)


static func _step_axis(
	current_velocity: float,
	acceleration: float,
	drag_coefficient: float,
	delta: float
) -> float:
	var safe_drag: float = maxf(drag_coefficient, 0.0)
	if safe_drag <= MIN_DRAG_COEFFICIENT:
		return current_velocity + acceleration * delta
	var terminal_velocity: float = acceleration / safe_drag
	return terminal_velocity + (
		current_velocity - terminal_velocity
	) * exp(-safe_drag * delta)
