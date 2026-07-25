class_name StationShipLoadoutController
extends Node

const MODAL_SHIP_LOADOUT: StringName = &"station_ship_loadout"

var _player: StationPlayer
var _modal_coordinator: StationModalCoordinator
var _workbench_interactable: Interactable2D
var _loadout_ui: ShipLoadoutUI
var _order_terminal_ui: OrderTerminalUI
var _game_state: GameStateModel
var _default_order_definition: OrderDefinition


func _ready() -> void:
	call_deferred("_initialize_controller")


func get_loadout_ui() -> ShipLoadoutUI:
	return _loadout_ui


func _initialize_controller() -> void:
	_player = get_node_or_null("../StationPlayer") as StationPlayer
	_modal_coordinator = get_node_or_null("../StationModalCoordinator") as StationModalCoordinator
	_workbench_interactable = get_node_or_null(
		"../Interactables/ShipWorkbench"
	) as Interactable2D
	_loadout_ui = get_node_or_null(
		"../ShipLoadoutUILayer/ShipLoadoutUI"
	) as ShipLoadoutUI
	_order_terminal_ui = get_node_or_null(
		"../OrderTerminalUILayer/OrderTerminalUI"
	) as OrderTerminalUI
	_game_state = get_node_or_null("/root/GameState") as GameStateModel
	if (
		_player == null
		or _modal_coordinator == null
		or _workbench_interactable == null
		or _loadout_ui == null
	):
		push_error("Station ship loadout could not resolve its player, workbench, or UI.")
		return
	_default_order_definition = _loadout_ui.order_definition
	if not _workbench_interactable.interaction_triggered.is_connected(_on_workbench_interacted):
		_workbench_interactable.interaction_triggered.connect(_on_workbench_interacted)
	if not _loadout_ui.loadout_closed.is_connected(_on_loadout_closed):
		_loadout_ui.loadout_closed.connect(_on_loadout_closed)


func _on_workbench_interacted(_actor: Node) -> void:
	if _loadout_ui == null or _loadout_ui.visible:
		return
	_refresh_active_order_definition()
	_modal_coordinator.begin_modal(MODAL_SHIP_LOADOUT)
	if not _loadout_ui.open_loadout():
		_modal_coordinator.end_modal(MODAL_SHIP_LOADOUT)
		push_error("Station ship loadout UI could not open.")


func _on_loadout_closed() -> void:
	_modal_coordinator.end_modal(MODAL_SHIP_LOADOUT)


func _refresh_active_order_definition() -> void:
	var active_order: OrderDefinition
	if (
		_game_state != null
		and not _game_state.current_order_id.is_empty()
		and _order_terminal_ui != null
		and _order_terminal_ui.data_registry != null
	):
		active_order = _order_terminal_ui.data_registry.find_order(
			_game_state.current_order_id
		)
	_loadout_ui.set_order_definition(
		active_order if active_order != null else _default_order_definition
	)
