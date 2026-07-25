class_name SouvenirWallUI
extends Control

signal wall_closed
signal souvenir_selected(souvenir_id: StringName)

@export var data_registry: GameDataRegistry

@onready var _title_label: Label = %WallTitleLabel
@onready var _summary_label: Label = %WallSummaryLabel
@onready var _slot_grid: GridContainer = %SlotGrid
@onready var _detail_title_label: Label = %DetailTitleLabel
@onready var _detail_status_label: Label = %DetailStatusLabel
@onready var _detail_description_label: Label = %DetailDescriptionLabel
@onready var _close_button: Button = %CloseButton

var game_state_override: GameStateModel

var _game_state: GameStateModel
var _entries: Array[SouvenirWallEntry] = []
var _slot_buttons: Dictionary[StringName, Button] = {}
var _selected_souvenir_id: StringName = &""
var _controls_initialized: bool = false
var _previous_focus: Control


func _ready() -> void:
	_initialize_controls()
	_bind_game_state()
	visible = false


func _exit_tree() -> void:
	_disconnect_game_state()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_wall()
		get_viewport().set_input_as_handled()
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if _slot_buttons.values().has(focus_owner):
		if event.is_action_pressed(&"ui_left"):
			_move_slot_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_right"):
			_move_slot_focus(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_up"):
			_move_slot_focus(-2)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_down"):
			_move_slot_focus(2)
			get_viewport().set_input_as_handled()
	elif focus_owner == _close_button and event.is_action_pressed(&"ui_up"):
		_focus_selected_slot()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_wall()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		_refresh_wall()


func set_data_registry(registry: GameDataRegistry) -> void:
	data_registry = registry
	if is_inside_tree():
		_refresh_wall()


func open_wall() -> bool:
	if not _initialize_controls() or data_registry == null:
		return false
	_bind_game_state()
	if _game_state == null:
		return false
	_previous_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_refresh_wall()
	if not _focus_selected_slot():
		_close_button.grab_focus()
	return true

func close_wall() -> void:
	if not visible:
		return
	visible = false
	if _previous_focus != null and is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()
	_previous_focus = null
	wall_closed.emit()


func select_souvenir(souvenir_id: StringName) -> bool:
	var entry: SouvenirWallEntry = _find_entry(souvenir_id)
	if entry == null:
		return false
	_selected_souvenir_id = souvenir_id
	_render_detail(entry)
	souvenir_selected.emit(souvenir_id)
	return true


func get_entries() -> Array[SouvenirWallEntry]:
	return _entries.duplicate()


func get_selected_souvenir_id() -> StringName:
	return _selected_souvenir_id


func get_slot_button(souvenir_id: StringName) -> Button:
	return _slot_buttons.get(souvenir_id)


func get_slot_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for entry: SouvenirWallEntry in _entries:
		var button: Button = _slot_buttons.get(entry.souvenir_id)
		if button != null:
			texts.append(button.text)
	return texts


func get_detail_text() -> String:
	if _detail_title_label == null or _detail_description_label == null:
		return ""
	return "%s\n%s" % [
		_detail_title_label.text,
		_detail_description_label.text,
	]


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("WallPanel") as PanelContainer
	return Rect2() if panel == null else panel.get_global_rect()


func get_slot_panel_rect() -> Rect2:
	var panel: PanelContainer = %SlotPanel
	return Rect2() if panel == null else panel.get_global_rect()


func get_detail_panel_rect() -> Rect2:
	var panel: PanelContainer = %DetailPanel
	return Rect2() if panel == null else panel.get_global_rect()


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	var required_controls: Array[Control] = [
		_title_label,
		_summary_label,
		_slot_grid,
		_detail_title_label,
		_detail_status_label,
		_detail_description_label,
		_close_button,
	]
	for control: Control in required_controls:
		if control == null:
			return false
	_close_button.pressed.connect(close_wall)
	_controls_initialized = true
	return true


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
	if visible:
		_refresh_wall()


func _refresh_wall() -> void:
	if not _controls_initialized:
		return
	_title_label.text = tr("UI_SOUVENIR_WALL_TITLE")
	_close_button.text = tr("UI_SOUVENIR_WALL_CLOSE")
	_entries.clear()
	if data_registry != null and _game_state != null:
		_entries = SouvenirWallModel.build_entries(data_registry, _game_state)
	_rebuild_slots()
	var selected_entry: SouvenirWallEntry = _find_entry(
		_selected_souvenir_id
	)
	if selected_entry == null and not _entries.is_empty():
		selected_entry = _entries[0]
		_selected_souvenir_id = selected_entry.souvenir_id
	_render_detail(selected_entry)


func _rebuild_slots() -> void:
	for child: Node in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	for entry: SouvenirWallEntry in _entries:
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(116.0, 72.0)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_button.focus_mode = Control.FOCUS_ALL
		slot_button.text = tr(String(entry.display_name_key))
		slot_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_button.pressed.connect(
			select_souvenir.bind(entry.souvenir_id)
		)
		slot_button.focus_entered.connect(
			select_souvenir.bind(entry.souvenir_id)
		)
		_slot_grid.add_child(slot_button)
		_slot_buttons[entry.souvenir_id] = slot_button
	var acquired_count: int = SouvenirWallModel.get_acquired_count(_entries)
	_summary_label.text = tr("UI_SOUVENIR_WALL_COUNT_FORMAT") % [
		acquired_count,
		_entries.size(),
	]


func _render_detail(entry: SouvenirWallEntry) -> void:
	if entry == null:
		_detail_title_label.text = tr("UI_SOUVENIR_NO_SELECTION_TITLE")
		_detail_status_label.text = tr("UI_SOUVENIR_NO_SELECTION_STATUS")
		_detail_description_label.text = tr(
			"UI_SOUVENIR_NO_SELECTION_DESCRIPTION"
		)
		return
	_detail_title_label.text = tr(String(entry.display_name_key))
	_detail_description_label.text = tr(String(entry.description_key))
	_detail_status_label.text = tr(
		"UI_SOUVENIR_STATUS_ACQUIRED"
		if entry.is_acquired
		else "UI_SOUVENIR_STATUS_LOCKED"
	)


func _find_entry(souvenir_id: StringName) -> SouvenirWallEntry:
	for entry: SouvenirWallEntry in _entries:
		if entry.souvenir_id == souvenir_id:
			return entry
	return null


func _move_slot_focus(offset: int) -> void:
	if _entries.is_empty():
		_close_button.grab_focus()
		return
	var current_index: int = 0
	for index: int in _entries.size():
		if _entries[index].souvenir_id == _selected_souvenir_id:
			current_index = index
			break
	var next_index: int = clampi(
		current_index + offset,
		0,
		_entries.size() - 1
	)
	var next_entry: SouvenirWallEntry = _entries[next_index]
	select_souvenir(next_entry.souvenir_id)
	_slot_buttons.get(next_entry.souvenir_id).grab_focus()


func _focus_selected_slot() -> bool:
	var selected_button: Button = _slot_buttons.get(_selected_souvenir_id)
	if selected_button == null:
		return false
	selected_button.grab_focus()
	return true
