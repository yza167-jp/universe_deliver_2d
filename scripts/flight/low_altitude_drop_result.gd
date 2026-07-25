class_name LowAltitudeDropResult
extends RefCounted

var status: int = LowAltitudeDropModel.Status.PENDING
var reason_key: StringName = &""
var release_position: Vector2 = Vector2.ZERO
var predicted_landing_x: float = 0.0
var fall_duration: float = 0.0
var horizontal_offset: float = 0.0
var quality_ratio: float = 0.0
var reward_ratio: float = 0.0


func is_release_valid() -> bool:
	return status in [
		LowAltitudeDropModel.Status.CORE_SUCCESS,
		LowAltitudeDropModel.Status.OUTER_PARTIAL,
		LowAltitudeDropModel.Status.MISSED,
	]


func is_success() -> bool:
	return status in [
		LowAltitudeDropModel.Status.CORE_SUCCESS,
		LowAltitudeDropModel.Status.OUTER_PARTIAL,
	]
