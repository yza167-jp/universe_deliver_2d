class_name StationOrderTerminalController
extends Node

var _player: StationPlayer
var _terminal_interactable: Interactable2D
var _tutorial_controller: StationTutorialController
var _terminal_ui: OrderTerminalUI
var _open_after_tutorial: bool = false
var _accepted_feedback_pending: bool = false


func _ready() -> void:
	call_deferred("_initialize_controller")


func get_terminal_ui() -> OrderTerminalUI:
	return _terminal_ui


func _initialize_controller() -> void:
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_terminal_interactable = get_node_or_null(
		"../Interactables/OrderTerminal"
	) as Interactable2D
	_tutorial_controller = get_node_or_null(
		"../StationTutorialController"
	) as StationTutorialController
	_terminal_ui = get_node_or_null(
		"../OrderTerminalUILayer/OrderTerminalUI"
	) as OrderTerminalUI
	if (
		_player == null
		or _terminal_interactable == null
		or _tutorial_controller == null
		or _terminal_ui == null
	):
		push_error("Station order terminal could not resolve its player, tutorial, UI, or interactable.")
		return
	if not _terminal_interactable.interaction_triggered.is_connected(_on_terminal_interacted):
		_terminal_interactable.interaction_triggered.connect(_on_terminal_interacted)
	if not _tutorial_controller.tutorial_completed.is_connected(_on_tutorial_completed):
		_tutorial_controller.tutorial_completed.connect(_on_tutorial_completed)
	if not _terminal_ui.terminal_closed.is_connected(_on_terminal_closed):
		_terminal_ui.terminal_closed.connect(_on_terminal_closed)
	if not _terminal_ui.order_accepted.is_connected(_on_order_accepted):
		_terminal_ui.order_accepted.connect(_on_order_accepted)


func _on_terminal_interacted(_actor: Node) -> void:
	if _tutorial_controller.is_tutorial_complete():
		_open_terminal()
		return
	var progress: StationTutorialProgress = _tutorial_controller.get_progress()
	if progress != null and progress.is_complete():
		_open_after_tutorial = true


func _on_tutorial_completed() -> void:
	if not _open_after_tutorial:
		return
	_open_after_tutorial = false
	call_deferred("_open_terminal")


func _open_terminal() -> void:
	if _terminal_ui == null or _terminal_ui.visible:
		return
	_player.set_input_enabled(false)
	if not _terminal_ui.open_terminal():
		_player.set_input_enabled(true)
		push_error("Station order terminal UI could not open.")


func _on_order_accepted(_order_id: StringName) -> void:
	_accepted_feedback_pending = true


func _on_terminal_closed() -> void:
	_player.set_input_enabled(true)
	if not _accepted_feedback_pending:
		return
	_accepted_feedback_pending = false
	_tutorial_controller.play_order_accepted_dialogue()
