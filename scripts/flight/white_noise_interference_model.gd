class_name WhiteNoiseInterferenceModel
extends RefCounted

## Deterministic, frame-rate-independent phase and pulse model.
## It never reads or mutates player input.

enum State {
	CLEAR,
	WARNING,
	ACTIVE,
	RECOVERY,
}

var _profile: WhiteNoiseStormProfile
var _state: State = State.CLEAR
var _state_elapsed_seconds: float = 0.0
var _maximum_route_distance: float = 0.0
var _pulse_index: int = 0
var _total_pulse_count: int = 0


func configure(profile: WhiteNoiseStormProfile) -> bool:
	_profile = profile
	if _profile == null or not _profile.validate().is_empty():
		return false
	reset(0.0)
	return true


func reset(route_distance: float) -> void:
	_state = State.CLEAR
	_state_elapsed_seconds = 0.0
	_maximum_route_distance = maxf(route_distance, 0.0)
	_pulse_index = 0
	_total_pulse_count = 0
	if _is_inside_window(_maximum_route_distance):
		_enter_state(State.WARNING)


func step(delta: float, route_distance: float) -> int:
	if _profile == null:
		return 0
	_maximum_route_distance = maxf(
		_maximum_route_distance,
		maxf(route_distance, 0.0)
	)
	if _state == State.CLEAR:
		if _is_inside_window(_maximum_route_distance):
			_enter_state(State.WARNING)
		return 0

	var phase_duration: float = _get_phase_duration(_state)
	_state_elapsed_seconds += maxf(delta, 0.0)
	var emitted_pulses: int = 0
	if _state == State.ACTIVE:
		var next_pulse_index: int = floori(
			(_state_elapsed_seconds + 0.00001)
			/ _profile.pulse_interval_seconds
		)
		emitted_pulses = maxi(next_pulse_index - _pulse_index, 0)
		_pulse_index = next_pulse_index
		_total_pulse_count += emitted_pulses

	if (
		_state_elapsed_seconds >= phase_duration
		and _maximum_route_distance >= _get_phase_distance_gate(_state)
	):
		match _state:
			State.WARNING:
				_enter_state(State.ACTIVE)
			State.ACTIVE:
				_enter_state(State.RECOVERY)
			State.RECOVERY:
				_enter_state(State.CLEAR)
	return emitted_pulses


func debug_set_state(state: State, elapsed_seconds: float = 0.0) -> void:
	_enter_state(state)
	_state_elapsed_seconds = clampf(
		elapsed_seconds,
		0.0,
		_get_phase_duration(state)
	)
	if state == State.ACTIVE and _profile != null:
		_pulse_index = floori(
			(_state_elapsed_seconds + 0.00001)
			/ _profile.pulse_interval_seconds
		)
		_total_pulse_count = _pulse_index


func get_state() -> State:
	return _state


func get_state_name() -> StringName:
	match _state:
		State.WARNING:
			return &"WARNING"
		State.ACTIVE:
			return &"ACTIVE"
		State.RECOVERY:
			return &"RECOVERY"
	return &"CLEAR"


func get_state_elapsed_seconds() -> float:
	return _state_elapsed_seconds


func get_state_progress() -> float:
	var duration: float = _get_phase_duration(_state)
	if duration <= 0.0:
		return 0.0
	return clampf(_state_elapsed_seconds / duration, 0.0, 1.0)


func get_total_pulse_count() -> int:
	return _total_pulse_count


func get_maximum_route_distance() -> float:
	return _maximum_route_distance


func get_effective_interference(
	interference_multiplier: float
) -> float:
	if _profile == null or _state == State.CLEAR:
		return 0.0
	var phase_strength: float = 1.0
	match _state:
		State.WARNING:
			phase_strength = lerpf(0.22, 0.58, get_state_progress())
		State.RECOVERY:
			phase_strength = lerpf(0.55, 0.0, get_state_progress())
	return clampf(
		_profile.interference_intensity
		* clampf(interference_multiplier, 0.0, 1.0)
		* phase_strength,
		0.0,
		1.0
	)


func _is_inside_window(route_distance: float) -> bool:
	return (
		_profile != null
		and route_distance >= _profile.trigger_distance
		and route_distance < _profile.end_distance
	)


func _enter_state(state: State) -> void:
	_state = state
	_state_elapsed_seconds = 0.0
	_pulse_index = 0


func _get_phase_duration(state: State) -> float:
	if _profile == null:
		return 0.0
	match state:
		State.WARNING:
			return _profile.warning_duration_seconds
		State.ACTIVE:
			return _profile.active_duration_seconds
		State.RECOVERY:
			return _profile.recovery_duration_seconds
	return 0.0


func _get_phase_distance_gate(state: State) -> float:
	if _profile == null:
		return INF
	match state:
		State.WARNING:
			return _profile.warning_end_distance
		State.ACTIVE:
			return _profile.recovery_start_distance
		State.RECOVERY:
			return _profile.end_distance
	return INF
