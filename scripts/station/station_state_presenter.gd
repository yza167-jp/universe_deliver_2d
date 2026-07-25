class_name StationStatePresenter
extends Node

@onready var _archive_terminal_root: Node2D = %ArchiveTerminalStateRoot
@onready var _ecology_corner_root: Node2D = %EcologyCornerStateRoot
@onready var _relay_observatory_root: Node2D = %RelayObservatoryStateRoot

var game_state_override: GameStateModel
var _game_state: GameStateModel


func _ready() -> void:
	_bind_game_state()
	refresh_state_roots()


func _exit_tree() -> void:
	_disconnect_game_state()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		refresh_state_roots()


func refresh_state_roots() -> void:
	if not is_node_ready():
		return
	_set_root_visible(
		_archive_terminal_root,
		StationStateRules.ARCHIVE_TERMINAL_ID
	)
	_set_root_visible(
		_ecology_corner_root,
		StationStateRules.ECOLOGY_CORNER_ID
	)
	_set_root_visible(
		_relay_observatory_root,
		StationStateRules.RELAY_OBSERVATORY_ID
	)


func is_state_root_visible(state_id: StringName) -> bool:
	var state_root: Node2D = get_state_root(state_id)
	return state_root != null and state_root.visible


func get_state_root(state_id: StringName) -> Node2D:
	match state_id:
		StationStateRules.ARCHIVE_TERMINAL_ID:
			return _archive_terminal_root
		StationStateRules.ECOLOGY_CORNER_ID:
			return _ecology_corner_root
		StationStateRules.RELAY_OBSERVATORY_ID:
			return _relay_observatory_root
	return null


func _bind_game_state() -> void:
	var next_game_state: GameStateModel = game_state_override
	if next_game_state == null:
		next_game_state = get_node_or_null("/root/GameState") as GameStateModel
	if next_game_state == _game_state:
		return
	_disconnect_game_state()
	_game_state = next_game_state
	if _game_state == null:
		return
	_game_state.persistent_state_changed.connect(_on_state_changed)
	_game_state.runtime_state_reset.connect(_on_state_changed)
	_game_state.runtime_state_restored.connect(_on_state_changed)


func _disconnect_game_state() -> void:
	if _game_state == null:
		return
	if _game_state.persistent_state_changed.is_connected(_on_state_changed):
		_game_state.persistent_state_changed.disconnect(_on_state_changed)
	if _game_state.runtime_state_reset.is_connected(_on_state_changed):
		_game_state.runtime_state_reset.disconnect(_on_state_changed)
	if _game_state.runtime_state_restored.is_connected(_on_state_changed):
		_game_state.runtime_state_restored.disconnect(_on_state_changed)
	_game_state = null


func _on_state_changed() -> void:
	refresh_state_roots()


func _set_root_visible(root: Node2D, state_id: StringName) -> void:
	if root == null:
		return
	root.visible = _game_state != null and _game_state.has_station_state(state_id)
