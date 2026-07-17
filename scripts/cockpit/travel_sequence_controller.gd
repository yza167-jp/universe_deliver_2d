class_name TravelSequenceController
extends Node

signal travel_started(destination_id: StringName)
signal phase_changed(phase: GameStateModel.TravelState)
signal progress_changed(phase: GameStateModel.TravelState, phase_progress: float, total_progress: float)
signal travel_completed(destination_id: StringName, was_skipped: bool)
signal travel_rejected(reason: StringName)

@export_range(0.1, 60.0, 0.1) var departure_duration: float = 3.0
@export_range(0.1, 60.0, 0.1) var cruise_duration: float = 5.0
@export_range(0.1, 60.0, 0.1) var approach_duration: float = 4.0

var _game_state: GameStateModel
var _order: OrderDefinition
var _phase_elapsed: float = 0.0
var _running: bool = false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_travel(delta)


func configure(game_state: GameStateModel, order: OrderDefinition) -> bool:
	_game_state = game_state
	_order = order
	_phase_elapsed = 0.0
	_running = _is_active_phase(get_phase())
	set_process(_running)
	return _game_state != null and _order != null


func get_phase() -> GameStateModel.TravelState:
	if _game_state == null:
		return GameStateModel.TravelState.IDLE
	return _game_state.travel_state


func get_phase_progress() -> float:
	if not _running:
		return 1.0 if get_phase() == GameStateModel.TravelState.COMPLETED else 0.0
	return clampf(_phase_elapsed / _get_phase_duration(get_phase()), 0.0, 1.0)


func get_total_progress() -> float:
	var phase_progress: float = get_phase_progress()
	match get_phase():
		GameStateModel.TravelState.DEPARTURE:
			return phase_progress / 3.0
		GameStateModel.TravelState.CRUISE:
			return (1.0 + phase_progress) / 3.0
		GameStateModel.TravelState.APPROACH:
			return (2.0 + phase_progress) / 3.0
		GameStateModel.TravelState.COMPLETED:
			return 1.0
	return 0.0


func is_running() -> bool:
	return _running


func can_skip() -> bool:
	return (
		_running
		and _game_state != null
		and _game_state.has_seen_travel(_game_state.travel_destination_id)
	)


func start_travel(destination_id: StringName) -> bool:
	if _game_state == null or _order == null:
		return _reject(GameStateModel.TRAVEL_ERROR_MISSING_DATA)
	if not _game_state.begin_travel(_order, destination_id):
		return _reject(_game_state.last_travel_error)
	_phase_elapsed = 0.0
	_running = true
	set_process(true)
	travel_started.emit(destination_id)
	phase_changed.emit(get_phase())
	_emit_progress()
	return true


func advance_travel(delta: float) -> void:
	if not _running or delta <= 0.0:
		return
	var remaining_delta: float = delta
	while _running and remaining_delta > 0.0:
		var phase_duration: float = _get_phase_duration(get_phase())
		var remaining_in_phase: float = maxf(phase_duration - _phase_elapsed, 0.0)
		var consumed_delta: float = minf(remaining_delta, remaining_in_phase)
		_phase_elapsed += consumed_delta
		remaining_delta -= consumed_delta
		_emit_progress()
		if _phase_elapsed + 0.0001 < phase_duration:
			break
		if not _advance_phase():
			break


func skip_travel() -> bool:
	if not can_skip():
		return _reject(GameStateModel.TRAVEL_ERROR_INVALID_TRANSITION)
	if not _game_state.complete_travel():
		return _reject(_game_state.last_travel_error)
	_finish_travel(true)
	return true


func _advance_phase() -> bool:
	var next_phase: GameStateModel.TravelState = GameStateModel.TravelState.IDLE
	match get_phase():
		GameStateModel.TravelState.DEPARTURE:
			next_phase = GameStateModel.TravelState.CRUISE
		GameStateModel.TravelState.CRUISE:
			next_phase = GameStateModel.TravelState.APPROACH
		GameStateModel.TravelState.APPROACH:
			next_phase = GameStateModel.TravelState.COMPLETED
		_:
			return _reject(GameStateModel.TRAVEL_ERROR_INVALID_TRANSITION)
	if not _game_state.advance_travel_state(next_phase):
		return _reject(_game_state.last_travel_error)
	_phase_elapsed = 0.0
	phase_changed.emit(get_phase())
	if get_phase() == GameStateModel.TravelState.COMPLETED:
		_finish_travel(false)
	else:
		_emit_progress()
	return true


func _finish_travel(was_skipped: bool) -> void:
	_running = false
	_phase_elapsed = 0.0
	set_process(false)
	_emit_progress()
	travel_completed.emit(_game_state.travel_destination_id, was_skipped)


func _emit_progress() -> void:
	progress_changed.emit(get_phase(), get_phase_progress(), get_total_progress())


func _get_phase_duration(phase: GameStateModel.TravelState) -> float:
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			return departure_duration
		GameStateModel.TravelState.CRUISE:
			return cruise_duration
		GameStateModel.TravelState.APPROACH:
			return approach_duration
	return 1.0


func _is_active_phase(phase: GameStateModel.TravelState) -> bool:
	return phase in [
		GameStateModel.TravelState.DEPARTURE,
		GameStateModel.TravelState.CRUISE,
		GameStateModel.TravelState.APPROACH,
	]


func _reject(reason: StringName) -> bool:
	travel_rejected.emit(reason)
	return false
