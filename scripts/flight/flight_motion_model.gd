class_name FlightMotionModel
extends RefCounted


## Integrates thrust, braking, low space drag, and the safety speed limit.
static func step_velocity(
	current_velocity: Vector2,
	rotation: float,
	throttle_input: float,
	brake_input: float,
	tuning: FlightTuning,
	delta: float,
	boost_input: float = 0.0
) -> Vector2:
	if tuning == null or delta <= 0.0:
		return current_velocity

	var next_velocity: Vector2 = step_control_velocity(
		current_velocity,
		rotation,
		throttle_input,
		brake_input,
		tuning,
		delta,
		boost_input
	)
	next_velocity = _apply_space_drag(next_velocity, tuning, delta)
	return apply_speed_limits(next_velocity, rotation, tuning)


## Applies only player-controlled thrust and braking so environment forces can be composed once.
static func step_control_velocity(
	current_velocity: Vector2,
	rotation: float,
	throttle_input: float,
	brake_input: float,
	tuning: FlightTuning,
	delta: float,
	boost_input: float = 0.0
) -> Vector2:
	if tuning == null or delta <= 0.0:
		return current_velocity
	var safe_throttle: float = clampf(throttle_input, 0.0, 1.0)
	var safe_brake: float = clampf(brake_input, 0.0, 1.0)
	var safe_boost: float = clampf(boost_input, 0.0, 1.0)
	var next_velocity: Vector2 = current_velocity
	next_velocity += (
		Vector2.RIGHT.rotated(rotation)
		* maxf(tuning.thrust_acceleration, 0.0)
		* (
			safe_throttle
			+ safe_boost * maxf(tuning.boost_multiplier - 1.0, 0.0)
		)
		* delta
	)
	return _apply_brake(next_velocity, safe_brake, tuning, delta)


## Approaches the requested pitch rate, then damps angular inertia on release.
static func step_angular_velocity(
	current_angular_velocity: float,
	pitch_input: float,
	tuning: FlightTuning,
	delta: float
) -> float:
	if tuning == null or delta <= 0.0:
		return current_angular_velocity

	var safe_input: float = clampf(pitch_input, -1.0, 1.0)
	var max_rate: float = maxf(tuning.max_pitch_rate, 0.0)
	if not is_zero_approx(safe_input):
		return move_toward(
			current_angular_velocity,
			safe_input * max_rate,
			maxf(tuning.pitch_acceleration, 0.0) * delta
		)
	return move_toward(
		current_angular_velocity,
		0.0,
		maxf(tuning.angular_damping, 0.0) * delta
	)


static func integrate_rotation(
	current_rotation: float,
	angular_velocity: float,
	tuning: FlightTuning,
	delta: float
) -> float:
	if tuning == null or delta <= 0.0:
		return current_rotation
	var max_pitch: float = tuning.get_max_pitch_radians()
	return clampf(
		current_rotation + angular_velocity * delta,
		-max_pitch,
		max_pitch
	)


static func _apply_brake(
	current_velocity: Vector2,
	brake_input: float,
	tuning: FlightTuning,
	delta: float
) -> Vector2:
	if brake_input <= 0.0 or current_velocity.is_zero_approx():
		return current_velocity
	if current_velocity.length() <= maxf(tuning.brake_deadzone, 0.0):
		return Vector2.ZERO
	return current_velocity.move_toward(
		Vector2.ZERO,
		maxf(tuning.brake_acceleration, 0.0) * brake_input * delta
	)


static func _apply_space_drag(
	current_velocity: Vector2,
	tuning: FlightTuning,
	delta: float
) -> Vector2:
	var drag_factor: float = exp(-maxf(tuning.space_drag, 0.0) * delta)
	return current_velocity * drag_factor


static func apply_speed_limits(
	current_velocity: Vector2,
	rotation: float,
	tuning: FlightTuning
) -> Vector2:
	if tuning == null:
		return current_velocity
	var limited_velocity: Vector2 = current_velocity
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	var max_forward_speed: float = maxf(tuning.max_forward_speed, 0.0)
	var forward_speed: float = limited_velocity.dot(forward)
	if forward_speed > max_forward_speed:
		limited_velocity -= forward * (forward_speed - max_forward_speed)
	return limited_velocity.limit_length(maxf(tuning.max_total_speed, 0.0))
