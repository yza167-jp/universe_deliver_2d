class_name LowAltitudeDropModel
extends RefCounted

enum Status {
	PENDING,
	CORE_SUCCESS,
	OUTER_PARTIAL,
	MISSED,
	INVALID_RELEASE,
}

const REASON_ALTITUDE_TOO_LOW: StringName = &"UI_DELIVERY_DROP_REASON_ALTITUDE_TOO_LOW"
const REASON_ALTITUDE_TOO_HIGH: StringName = &"UI_DELIVERY_DROP_REASON_ALTITUDE_TOO_HIGH"
const REASON_SPEED_TOO_LOW: StringName = &"UI_DELIVERY_DROP_REASON_SPEED_TOO_LOW"
const REASON_SPEED_TOO_HIGH: StringName = &"UI_DELIVERY_DROP_REASON_SPEED_TOO_HIGH"
const REASON_ALREADY_RELEASED: StringName = &"UI_DELIVERY_DROP_REASON_ALREADY_RELEASED"
const REASON_INVALID_PROFILE: StringName = &"UI_DELIVERY_DROP_REASON_INVALID_PROFILE"
const REASON_CORE_SUCCESS: StringName = &"UI_DELIVERY_DROP_RESULT_CORE"
const REASON_OUTER_PARTIAL: StringName = &"UI_DELIVERY_DROP_RESULT_OUTER"
const REASON_MISSED: StringName = &"UI_DELIVERY_DROP_RESULT_MISSED"

var _cargo_released: bool = false
var _release_count: int = 0
var _settled_result: LowAltitudeDropResult = LowAltitudeDropResult.new()


func reset() -> void:
	_cargo_released = false
	_release_count = 0
	_settled_result = LowAltitudeDropResult.new()


func try_release(
	profile: LowAltitudeDropProfile,
	release_position: Vector2,
	target_center_x: float,
	release_altitude: float,
	horizontal_speed: float
) -> LowAltitudeDropResult:
	if _cargo_released:
		return _make_invalid_result(REASON_ALREADY_RELEASED, release_position)
	if profile == null or not profile.validate().is_empty():
		return _make_invalid_result(REASON_INVALID_PROFILE, release_position)
	if release_altitude < profile.minimum_release_altitude:
		return _make_invalid_result(REASON_ALTITUDE_TOO_LOW, release_position)
	if release_altitude > profile.maximum_release_altitude:
		return _make_invalid_result(REASON_ALTITUDE_TOO_HIGH, release_position)
	if horizontal_speed < profile.minimum_release_speed:
		return _make_invalid_result(REASON_SPEED_TOO_LOW, release_position)
	if horizontal_speed > profile.maximum_release_speed:
		return _make_invalid_result(REASON_SPEED_TOO_HIGH, release_position)

	var result: LowAltitudeDropResult = LowAltitudeDropResult.new()
	result.release_position = release_position
	result.fall_duration = calculate_fall_duration(profile, release_altitude)
	result.predicted_landing_x = calculate_landing_x(
		profile,
		release_position.x,
		release_altitude,
		horizontal_speed
	)
	result.horizontal_offset = absf(result.predicted_landing_x - target_center_x)
	if result.horizontal_offset <= profile.core_zone_half_width:
		result.status = Status.CORE_SUCCESS
		result.reason_key = REASON_CORE_SUCCESS
		result.quality_ratio = 1.0
		result.reward_ratio = 1.0
	elif result.horizontal_offset <= profile.outer_zone_half_width:
		result.status = Status.OUTER_PARTIAL
		result.reason_key = REASON_OUTER_PARTIAL
		result.quality_ratio = profile.partial_quality_ratio
		result.reward_ratio = profile.partial_reward_ratio
	else:
		result.status = Status.MISSED
		result.reason_key = REASON_MISSED
		result.quality_ratio = 0.0
		result.reward_ratio = 0.0

	_cargo_released = true
	_release_count = 1
	_settled_result = result
	return result


func predict_landing_x(
	profile: LowAltitudeDropProfile,
	release_x: float,
	release_altitude: float,
	horizontal_speed: float
) -> float:
	if profile == null or not profile.validate().is_empty():
		return release_x
	return calculate_landing_x(
		profile,
		release_x,
		maxf(release_altitude, 0.0),
		horizontal_speed
	)


func has_released_cargo() -> bool:
	return _cargo_released


func get_release_count() -> int:
	return _release_count


func get_settled_result() -> LowAltitudeDropResult:
	return _settled_result


static func calculate_fall_duration(
	profile: LowAltitudeDropProfile,
	release_altitude: float
) -> float:
	if profile == null or profile.cargo_descent_speed <= 0.0:
		return 0.0
	return maxf(release_altitude, 0.0) / profile.cargo_descent_speed


static func calculate_landing_x(
	profile: LowAltitudeDropProfile,
	release_x: float,
	release_altitude: float,
	horizontal_speed: float
) -> float:
	if profile == null:
		return release_x
	return (
		release_x
		+ horizontal_speed
		* clampf(profile.horizontal_velocity_inheritance, 0.0, 1.0)
		* calculate_fall_duration(profile, release_altitude)
	)


func _make_invalid_result(
	reason_key: StringName,
	release_position: Vector2
) -> LowAltitudeDropResult:
	var result: LowAltitudeDropResult = LowAltitudeDropResult.new()
	result.status = Status.INVALID_RELEASE
	result.reason_key = reason_key
	result.release_position = release_position
	result.predicted_landing_x = release_position.x
	return result
