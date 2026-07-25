class_name StationReturnStateController
extends Node
const MODAL_MEMORABILIA_OBSERVATION: StringName = (
	&"station_memorabilia_observation"
)

@onready var _memorabilia_wall: Interactable2D = (
	get_node("../Interactables/MemorabiliaWall") as Interactable2D
)
@onready var _modal_coordinator: StationModalCoordinator = (
	get_node("../StationModalCoordinator") as StationModalCoordinator
)
@onready var _souvenir_wall_ui: SouvenirWallUI = (
	get_node("../SouvenirWallUILayer/SouvenirWallUI") as SouvenirWallUI
)
@onready var _display_root: Node2D = %FirstDeliveryDisplay
@onready var _memorabilia_label: Label = %MemorabiliaLabel
@onready var _progress_panel: PanelContainer = %ReturnProgressPanel
@onready var _credit_label: Label = %ReturnCreditLabel
@onready var _upgrade_label: Label = %ReturnUpgradeLabel

var game_state_override: GameStateModel
var _game_state: GameStateModel


func _ready() -> void:
	if not _memorabilia_wall.interaction_triggered.is_connected(
		_on_memorabilia_interacted
	):
		_memorabilia_wall.interaction_triggered.connect(
			_on_memorabilia_interacted
		)
	if not _souvenir_wall_ui.wall_closed.is_connected(_on_wall_closed):
		_souvenir_wall_ui.wall_closed.connect(_on_wall_closed)
	_bind_game_state()
	refresh_return_state()


func _exit_tree() -> void:
	_disconnect_game_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_return_state()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		refresh_return_state()


func refresh_return_state() -> void:
	if not is_node_ready():
		return
	_bind_game_state()
	_souvenir_wall_ui.set_game_state_override(_game_state)
	var entries: Array[SouvenirWallEntry] = []
	if _game_state != null and _souvenir_wall_ui.data_registry != null:
		entries = SouvenirWallModel.build_entries(
			_souvenir_wall_ui.data_registry,
			_game_state
		)
	var acquired_count: int = SouvenirWallModel.get_acquired_count(entries)
	var relay_plaque_is_acquired: bool = _is_souvenir_acquired(
		entries,
		SouvenirWallModel.RELAY_PLAQUE_ID
	)
	_display_root.visible = relay_plaque_is_acquired
	_progress_panel.visible = relay_plaque_is_acquired
	if acquired_count <= 0:
		_memorabilia_label.text = tr("UI_STATION_MEMORABILIA_WALL")
	elif acquired_count == 1 and relay_plaque_is_acquired:
		_memorabilia_label.text = tr(
			"UI_STATION_MEMORABILIA_WALL_FILLED"
		)
	else:
		_memorabilia_label.text = tr(
			"UI_STATION_MEMORABILIA_WALL_COUNT_FORMAT"
		) % [acquired_count, entries.size()]

	var station: StationHub = get_parent() as StationHub
	if station != null:
		var acquired_states: Array[bool] = []
		for entry: SouvenirWallEntry in entries:
			acquired_states.append(entry.is_acquired)
		station.set_memorabilia_slot_states(acquired_states)

	if not relay_plaque_is_acquired or _game_state == null:
		_credit_label.text = ""
		_upgrade_label.text = ""
		return
	_credit_label.text = tr("UI_STATION_RETURN_CREDITS_FORMAT") % (
		_game_state.get_credits()
	)
	_upgrade_label.text = tr("UI_STATION_RETURN_UPGRADE")


func is_first_delivery_display_visible() -> bool:
	return _display_root != null and _display_root.visible


func get_credit_text() -> String:
	return "" if _credit_label == null else _credit_label.text


func get_status_text() -> String:
	return (
		""
		if _souvenir_wall_ui == null
		else _souvenir_wall_ui.get_detail_text()
	)


func get_memorabilia_wall() -> Interactable2D:
	return _memorabilia_wall


func get_souvenir_wall_ui() -> SouvenirWallUI:
	return _souvenir_wall_ui


func is_status_visible() -> bool:
	return _souvenir_wall_ui != null and _souvenir_wall_ui.visible


func dismiss_status() -> bool:
	if not is_status_visible():
		return false
	_souvenir_wall_ui.close_wall()
	return true


func _on_memorabilia_interacted(_actor: Node) -> void:
	if not _modal_coordinator.begin_modal(
		MODAL_MEMORABILIA_OBSERVATION,
		true
	):
		return
	_souvenir_wall_ui.set_game_state_override(_game_state)
	if _souvenir_wall_ui.open_wall():
		return
	_modal_coordinator.end_modal(MODAL_MEMORABILIA_OBSERVATION)


func _on_wall_closed() -> void:
	_modal_coordinator.end_modal(MODAL_MEMORABILIA_OBSERVATION)
	refresh_return_state()


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
	refresh_return_state()


func _is_souvenir_acquired(
	entries: Array[SouvenirWallEntry],
	souvenir_id: StringName
) -> bool:
	for entry: SouvenirWallEntry in entries:
		if entry.souvenir_id == souvenir_id:
			return entry.is_acquired
	return false
