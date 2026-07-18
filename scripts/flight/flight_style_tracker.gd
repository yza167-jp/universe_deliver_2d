class_name FlightStyleTracker
extends RefCounted

const STYLE_DIVE: StringName = &"DIVE"
const STYLE_GLIDE: StringName = &"GLIDE"
const STYLE_BALANCED: StringName = &"BALANCED"

var _run_state: OrderRunState
var _is_tracking: bool = false
var _late_pull_up_armed: bool = false


func bind_run_state(run_state: OrderRunState) -> bool:
	if run_state == null:
		return false
	_run_state = run_state
	_is_tracking = false
	_late_pull_up_armed = false
	return true


func begin(run_state: OrderRunState = null) -> bool:
	if run_state != null:
		_run_state = run_state
	if _run_state == null:
		return false
	_run_state.reset_entry_result()
	_is_tracking = true
	_late_pull_up_armed = false
	return true


## Records normalized risk/heat in the 0..1 range alongside deterministic motion metrics.
func record_sample(
	delta: float,
	velocity: Vector2,
	risk_or_heat: float,
	tuning: FlightTuning
) -> bool:
	if not _is_tracking or _run_state == null or tuning == null:
		return false
	if not velocity.is_finite() or not is_finite(risk_or_heat):
		return false

	_run_state.entry_duration += maxf(delta, 0.0)
	var downward_speed: float = maxf(velocity.y, 0.0)
	_run_state.max_downward_speed = maxf(
		_run_state.max_downward_speed,
		downward_speed
	)
	_run_state.max_total_speed = maxf(_run_state.max_total_speed, velocity.length())
	_run_state.max_risk_or_heat = maxf(
		_run_state.max_risk_or_heat,
		clampf(risk_or_heat, 0.0, 1.0)
	)

	if (
		_run_state.entry_duration >= tuning.late_pull_up_min_elapsed_seconds
		and downward_speed >= tuning.late_pull_up_arm_downward_speed
	):
		_late_pull_up_armed = true
	if (
		_late_pull_up_armed
		and downward_speed <= tuning.late_pull_up_recovery_downward_speed
	):
		mark_late_pull_up()
	return true


func record_scenic_trigger(trigger_id: StringName) -> bool:
	if not _is_tracking or _run_state == null or trigger_id.is_empty():
		return false
	if _run_state.optional_trigger_ids.has(trigger_id):
		return false
	_run_state.optional_trigger_ids.append(trigger_id)
	_run_state.scenic_trigger_count = _run_state.optional_trigger_ids.size()
	return true


func record_collision() -> bool:
	if not _is_tracking or _run_state == null:
		return false
	_run_state.collision_count += 1
	return true


func mark_late_pull_up() -> bool:
	if not _is_tracking or _run_state == null:
		return false
	_run_state.late_pull_up_detected = true
	_late_pull_up_armed = false
	return true


func get_candidate_style(tuning: FlightTuning) -> StringName:
	if _run_state == null:
		return &""
	if not _is_tracking and is_valid_style(_run_state.entry_style):
		return _run_state.entry_style
	if _run_state.entry_duration <= 0.0:
		return &""
	return classify(_run_state, tuning)


func finalize(tuning: FlightTuning) -> StringName:
	if _run_state == null or tuning == null:
		return &""
	_run_state.entry_style = classify(_run_state, tuning)
	_is_tracking = false
	_late_pull_up_armed = false
	return _run_state.entry_style


func get_run_state() -> OrderRunState:
	return _run_state


func is_tracking() -> bool:
	return _is_tracking


static func classify(run_state: OrderRunState, tuning: FlightTuning) -> StringName:
	if run_state == null or tuning == null:
		return STYLE_BALANCED
	if run_state.entry_duration < maxf(tuning.entry_style_min_sample_seconds, 0.0):
		return STYLE_BALANCED

	var has_few_scenic_triggers: bool = (
		run_state.scenic_trigger_count <= maxi(tuning.dive_max_scenic_trigger_count, 0)
	)
	var has_short_fast_entry: bool = (
		run_state.entry_duration <= maxf(tuning.dive_max_duration_seconds, 0.0)
		and run_state.max_total_speed >= maxf(tuning.dive_short_entry_min_total_speed, 0.0)
	)
	var has_dive_signal: bool = (
		run_state.max_downward_speed >= maxf(tuning.dive_min_downward_speed, 0.0)
		or run_state.max_risk_or_heat >= clampf(tuning.dive_min_risk_or_heat, 0.0, 1.0)
		or has_short_fast_entry
	)
	if has_few_scenic_triggers and has_dive_signal:
		return STYLE_DIVE

	var has_glide_profile: bool = (
		run_state.entry_duration >= maxf(tuning.glide_min_duration_seconds, 0.0)
		and run_state.max_downward_speed <= maxf(tuning.glide_max_downward_speed, 0.0)
		and run_state.max_risk_or_heat <= clampf(tuning.glide_max_risk_or_heat, 0.0, 1.0)
		and run_state.scenic_trigger_count >= maxi(tuning.glide_min_scenic_trigger_count, 0)
	)
	if has_glide_profile:
		return STYLE_GLIDE
	return STYLE_BALANCED


static func calculate_normalized_risk(
	downward_speed: float,
	safety_downward_speed: float
) -> float:
	if not is_finite(downward_speed) or not is_finite(safety_downward_speed):
		return 0.0
	if safety_downward_speed <= 0.0:
		return 0.0
	return clampf(maxf(downward_speed, 0.0) / safety_downward_speed, 0.0, 1.0)


static func is_valid_style(style: StringName) -> bool:
	return style in [STYLE_DIVE, STYLE_GLIDE, STYLE_BALANCED]
