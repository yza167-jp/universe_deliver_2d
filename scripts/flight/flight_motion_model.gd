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
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	next_velocity += (
		forward
		* maxf(tuning.thrust_acceleration, 0.0)
		* (
			safe_throttle
			+ safe_boost * maxf(tuning.boost_multiplier - 1.0, 0.0)
		)
		* delta
	)
	return _apply_brake_or_reverse(
		next_velocity,
		forward,
		safe_brake,
		is_zero_approx(safe_throttle),
		tuning,
		delta
	)


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


static func _apply_brake_or_reverse(
	current_velocity: Vector2,
	forward: Vector2,
	brake_input: float,
	allow_reverse: bool,
	tuning: FlightTuning,
	delta: float
) -> Vector2:
	if brake_input <= 0.0:
		return current_velocity
	if not allow_reverse:
		return current_velocity.move_toward(
			Vector2.ZERO,
			maxf(tuning.brake_acceleration, 0.0)
			* maxf(tuning.reverse_brake_strength, 0.0)
			* brake_input
			* delta
		)
	var forward_speed: float = current_velocity.dot(forward)
	var reverse_entry_threshold: float = maxf(
		tuning.reverse_entry_speed_threshold,
		maxf(tuning.brake_deadzone, 0.0)
	)
	if forward_speed > reverse_entry_threshold:
		return current_velocity.move_toward(
			Vector2.ZERO,
			maxf(tuning.brake_acceleration, 0.0)
			* maxf(tuning.reverse_brake_strength, 0.0)
			* brake_input
			* delta
		)

	var reverse_velocity: Vector2 = current_velocity
	if forward_speed > 0.0:
		reverse_velocity -= forward * forward_speed
	reverse_velocity -= (
		forward
		* maxf(tuning.thrust_acceleration, 0.0)
		* clampf(tuning.reverse_thrust_multiplier, 0.0, 1.0)
		* brake_input
		* delta
	)
	return reverse_velocity


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
	var max_reverse_speed: float = tuning.get_max_reverse_speed()
	forward_speed = limited_velocity.dot(forward)
	if forward_speed < -max_reverse_speed:
		limited_velocity -= forward * (forward_speed + max_reverse_speed)
	return limited_velocity.limit_length(maxf(tuning.max_total_speed, 0.0))


static func get_forward_speed(current_velocity: Vector2, rotation: float) -> float:
	return current_velocity.dot(Vector2.RIGHT.rotated(rotation))


static func is_reverse_thrust_active(
	current_velocity: Vector2,
	rotation: float,
	brake_input: float,
	tuning: FlightTuning
) -> bool:
	if tuning == null or brake_input <= 0.0:
		return false
	return get_forward_speed(current_velocity, rotation) <= maxf(
		tuning.reverse_entry_speed_threshold,
		maxf(tuning.brake_deadzone, 0.0)
	)


static func is_reverse_boost_blocked(
	current_velocity: Vector2,
	rotation: float,
	brake_input: float
) -> bool:
	return (
		brake_input > 0.0
		or get_forward_speed(current_velocity, rotation) < 0.0
	)
