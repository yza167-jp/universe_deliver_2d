class_name FlightLandingModel
extends RefCounted

enum Quality {
	FAILED,
	ROUGH,
	SMOOTH,
}

const RESULT_FAILED: StringName = &"landing_failed"
const RESULT_ROUGH: StringName = &"landing_rough"
const RESULT_SMOOTH: StringName = &"landing_smooth"


static func classify_touchdown(
	velocity: Vector2,
	pitch_radians: float,
	contact_speed: float,
	tuning: FlightTuning
) -> int:
	if tuning == null:
		return Quality.FAILED
	var horizontal_speed: float = absf(velocity.x)
	var descent_speed: float = maxf(velocity.y, 0.0)
	var safe_contact_speed: float = maxf(contact_speed, descent_speed)
	var pitch_degrees: float = absf(rad_to_deg(pitch_radians))
	var within_success_limits: bool = (
		horizontal_speed <= tuning.landing_success_max_horizontal_speed
		and descent_speed <= tuning.landing_success_max_descent_speed
		and safe_contact_speed <= tuning.landing_success_max_contact_speed
		and pitch_degrees <= tuning.landing_success_max_pitch_degrees
	)
	if not within_success_limits:
		return Quality.FAILED
	if (
		horizontal_speed <= tuning.landing_smooth_max_horizontal_speed
		and descent_speed <= tuning.landing_smooth_max_descent_speed
		and safe_contact_speed <= tuning.landing_smooth_max_contact_speed
		and pitch_degrees <= tuning.landing_smooth_max_pitch_degrees
	):
		return Quality.SMOOTH
	return Quality.ROUGH


static func get_result_id(quality: int) -> StringName:
	match quality:
		Quality.SMOOTH:
			return RESULT_SMOOTH
		Quality.ROUGH:
			return RESULT_ROUGH
	return RESULT_FAILED


static func get_cargo_damage(quality: int, tuning: FlightTuning) -> float:
	if quality != Quality.ROUGH or tuning == null:
		return 0.0
	return maxf(tuning.landing_rough_cargo_damage, 0.0)
