class_name FlightLabCourse
extends RefCounted

enum Exercise {
	ASSIST_HOVER,
	DIVE,
	BRAKE_PULL_UP,
	COLLISION_RETRY,
	LASER,
	COUNT,
}

const HOVER_MIN_AIR_DENSITY: float = 0.9
const HOVER_MIN_GRAVITY_BLEND: float = 0.9
const HOVER_MAX_TOTAL_SPEED: float = 35.0
const HOVER_MAX_VERTICAL_SPEED: float = 8.0
const HOVER_HOLD_SECONDS: float = 0.6
const RECOVERY_BRAKE_THRESHOLD: float = 0.5
const RECOVERY_PITCH_UP_THRESHOLD: float = -0.5
const SMALL_ASTEROID_ID: StringName = &"asteroid_lab_small"
const LARGE_ASTEROID_ID: StringName = &"asteroid_lab_large"

var _completed: Array[bool] = []
var _observed_assist_presets: Dictionary[int, bool] = {}
var _hover_elapsed: float = 0.0
var _dive_observed: bool = false
var _recovery_controls_observed: bool = false
var _nonfatal_impact_observed: bool = false
var _fatal_impact_observed: bool = false
var _flight_failure_observed: bool = false
var _destroyed_asteroid_ids: Dictionary[StringName, bool] = {}


func _init() -> void:
	reset()


func reset() -> void:
	_completed.clear()
	_completed.resize(Exercise.COUNT)
	_completed.fill(false)
	_observed_assist_presets.clear()
	_hover_elapsed = 0.0
	_dive_observed = false
	_recovery_controls_observed = false
	_nonfatal_impact_observed = false
	_fatal_impact_observed = false
	_flight_failure_observed = false
	_destroyed_asteroid_ids.clear()


func record_assist_preset(assist_strength: float) -> bool:
	if not is_finite(assist_strength):
		return false
	var preset_percent: int = roundi(clampf(assist_strength, 0.0, 1.0) * 100.0)
	if preset_percent not in [0, 75, 100]:
		return false
	_observed_assist_presets[preset_percent] = true
	_refresh_assist_exercise()
	return true


## Records only whether the Gate B exercise was attempted; it does not judge feel.
func record_flight_sample(
	delta: float,
	air_density: float,
	gravity_blend: float,
	assist_strength: float,
	velocity: Vector2,
	brake_input: float,
	pitch_input: float,
	tuning: FlightTuning
) -> bool:
	if (
		tuning == null
		or not velocity.is_finite()
		or not is_finite(air_density)
		or not is_finite(gravity_blend)
		or not is_finite(assist_strength)
	):
		return false

	var previous_count: int = get_completed_count()
	var atmosphere_ready: bool = (
		air_density >= HOVER_MIN_AIR_DENSITY
		and gravity_blend >= HOVER_MIN_GRAVITY_BLEND
	)
	if atmosphere_ready and assist_strength >= 0.995:
		var is_low_speed_hover: bool = (
			velocity.length() <= HOVER_MAX_TOTAL_SPEED
			and absf(velocity.y) <= HOVER_MAX_VERTICAL_SPEED
		)
		if is_low_speed_hover:
			_hover_elapsed += maxf(delta, 0.0)
		else:
			_hover_elapsed = 0.0
	else:
		_hover_elapsed = 0.0
	_refresh_assist_exercise()

	if (
		atmosphere_ready
		and velocity.y >= maxf(tuning.dive_min_downward_speed, 0.0)
	):
		_dive_observed = true
		_set_completed(Exercise.DIVE)

	if (
		_dive_observed
		and brake_input >= RECOVERY_BRAKE_THRESHOLD
		and pitch_input <= RECOVERY_PITCH_UP_THRESHOLD
	):
		_recovery_controls_observed = true
	if (
		_recovery_controls_observed
		and velocity.y <= maxf(tuning.late_pull_up_recovery_downward_speed, 0.0)
	):
		_set_completed(Exercise.BRAKE_PULL_UP)
	return get_completed_count() > previous_count


func record_impact(severity: int) -> bool:
	var previous_count: int = get_completed_count()
	match severity:
		FlightCollisionResult.Severity.GRAZE, FlightCollisionResult.Severity.HARD:
			_nonfatal_impact_observed = true
		FlightCollisionResult.Severity.FATAL:
			_fatal_impact_observed = true
	_refresh_collision_exercise()
	return get_completed_count() > previous_count


func record_flight_failure() -> bool:
	var previous_count: int = get_completed_count()
	_flight_failure_observed = true
	_refresh_collision_exercise()
	return get_completed_count() > previous_count


func record_laser_target(target_id: StringName, target_destroyed: bool) -> bool:
	if not target_destroyed or target_id not in [SMALL_ASTEROID_ID, LARGE_ASTEROID_ID]:
		return false
	var previous_count: int = get_completed_count()
	_destroyed_asteroid_ids[target_id] = true
	if (
		_destroyed_asteroid_ids.has(SMALL_ASTEROID_ID)
		and _destroyed_asteroid_ids.has(LARGE_ASTEROID_ID)
	):
		_set_completed(Exercise.LASER)
	return get_completed_count() > previous_count


func get_exercise_count() -> int:
	return Exercise.COUNT


func get_completed_count() -> int:
	var count: int = 0
	for exercise_complete: bool in _completed:
		if exercise_complete:
			count += 1
	return count


func is_exercise_complete(exercise: int) -> bool:
	if exercise < 0 or exercise >= Exercise.COUNT:
		return false
	return _completed[exercise]


func get_current_exercise() -> int:
	for exercise: int in Exercise.COUNT:
		if not _completed[exercise]:
			return exercise
	return Exercise.COUNT


func is_complete() -> bool:
	return get_completed_count() == Exercise.COUNT


func _refresh_assist_exercise() -> void:
	if (
		_observed_assist_presets.has(0)
		and _observed_assist_presets.has(75)
		and _observed_assist_presets.has(100)
		and _hover_elapsed >= HOVER_HOLD_SECONDS
	):
		_set_completed(Exercise.ASSIST_HOVER)


func _refresh_collision_exercise() -> void:
	if (
		_nonfatal_impact_observed
		and _fatal_impact_observed
		and _flight_failure_observed
	):
		_set_completed(Exercise.COLLISION_RETRY)


func _set_completed(exercise: int) -> void:
	if exercise < 0 or exercise >= Exercise.COUNT:
		return
	_completed[exercise] = true
