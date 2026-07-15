class_name StationShipLoadoutController
extends Node

var _player: StationPlayer
var _workbench_interactable: Interactable2D
var _loadout_ui: ShipLoadoutUI


func _ready() -> void:
	call_deferred("_initialize_controller")


func get_loadout_ui() -> ShipLoadoutUI:
	return _loadout_ui


func _initialize_controller() -> void:
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_workbench_interactable = get_node_or_null(
		"../Interactables/ShipWorkbench"
	) as Interactable2D
	_loadout_ui = get_node_or_null(
		"../ShipLoadoutUILayer/ShipLoadoutUI"
	) as ShipLoadoutUI
	if _player == null or _workbench_interactable == null or _loadout_ui == null:
		push_error("Station ship loadout could not resolve its player, workbench, or UI.")
		return
	if not _workbench_interactable.interaction_triggered.is_connected(_on_workbench_interacted):
		_workbench_interactable.interaction_triggered.connect(_on_workbench_interacted)
	if not _loadout_ui.loadout_closed.is_connected(_on_loadout_closed):
		_loadout_ui.loadout_closed.connect(_on_loadout_closed)


func _on_workbench_interacted(_actor: Node) -> void:
	if _loadout_ui == null or _loadout_ui.visible:
		return
	_player.set_input_enabled(false)
	if not _loadout_ui.open_loadout():
		_player.set_input_enabled(true)
		push_error("Station ship loadout UI could not open.")


func _on_loadout_closed() -> void:
	_player.set_input_enabled(true)
