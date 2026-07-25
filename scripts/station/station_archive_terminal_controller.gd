class_name StationArchiveTerminalController
extends Node

const MODAL_ARCHIVE_TERMINAL: StringName = &"station_archive_terminal"

@onready var _terminal_interactable: Interactable2D = (
	get_node("../Interactables/ArchiveTerminal") as Interactable2D
)
@onready var _modal_coordinator: StationModalCoordinator = (
	get_node("../StationModalCoordinator") as StationModalCoordinator
)
@onready var _browser_ui: CodexBrowserUI = (
	get_node("../ArchiveTerminalUILayer/CodexBrowserUI") as CodexBrowserUI
)

var game_state_override: GameStateModel
var _game_state: GameStateModel


func _ready() -> void:
	if not _terminal_interactable.interaction_triggered.is_connected(
		_on_terminal_interacted
	):
		_terminal_interactable.interaction_triggered.connect(
			_on_terminal_interacted
		)
	if not _browser_ui.browser_closed.is_connected(_on_browser_closed):
		_browser_ui.browser_closed.connect(_on_browser_closed)
	_bind_game_state()
	refresh_availability()


func _exit_tree() -> void:
	_disconnect_game_state()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		refresh_availability()


func refresh_availability() -> void:
	if not is_node_ready():
		return
	_bind_game_state()
	var is_available: bool = (
		_game_state != null
		and _game_state.has_station_state(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
	)
	_terminal_interactable.interaction_enabled = is_available
	_browser_ui.set_game_state_override(_game_state)
	if not is_available and _browser_ui.visible:
		_browser_ui.close_browser()


func is_terminal_available() -> bool:
	return (
		_terminal_interactable != null
		and _terminal_interactable.interaction_enabled
	)


func get_terminal_interactable() -> Interactable2D:
	return _terminal_interactable


func get_browser_ui() -> CodexBrowserUI:
	return _browser_ui


func _on_terminal_interacted(_actor: Node) -> void:
	if (
		not is_terminal_available()
		or _browser_ui.visible
		or not _modal_coordinator.begin_modal(MODAL_ARCHIVE_TERMINAL)
	):
		return
	_browser_ui.set_game_state_override(_game_state)
	if _browser_ui.open_browser():
		return
	_modal_coordinator.end_modal(MODAL_ARCHIVE_TERMINAL)
	push_error("Station archive terminal browser could not open.")


func _on_browser_closed() -> void:
	_modal_coordinator.end_modal(MODAL_ARCHIVE_TERMINAL)


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
	refresh_availability()
