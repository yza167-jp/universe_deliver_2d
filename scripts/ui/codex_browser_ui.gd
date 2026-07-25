class_name CodexBrowserUI
extends Control

signal browser_closed
signal category_changed(category: CodexEntryDefinition.Category)
signal entry_selected(entry_id: StringName)

@export var data_registry: GameDataRegistry

@onready var _title_label: Label = %CodexTitleLabel
@onready var _category_row: HBoxContainer = %CategoryRow
@onready var _entry_scroll: ScrollContainer = %EntryScroll
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _empty_label: Label = %EmptyLabel
@onready var _detail_title_label: Label = %DetailTitleLabel
@onready var _detail_status_label: Label = %DetailStatusLabel
@onready var _detail_description_label: Label = %DetailDescriptionLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _close_button: Button = %CloseButton

var game_state_override: GameStateModel

var _game_state: GameStateModel
var _controls_initialized: bool = false
var _current_category: CodexEntryDefinition.Category = (
	CodexEntryDefinition.Category.PLANET
)
var _current_entries: Array[CodexCatalogEntry] = []
var _category_buttons: Dictionary[int, Button] = {}
var _entry_buttons: Dictionary[StringName, Button] = {}
var _selected_entry_id: StringName = &""
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
		close_browser()
		get_viewport().set_input_as_handled()
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if _category_buttons.values().has(focus_owner):
		if event.is_action_pressed(&"ui_left"):
			_move_category_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_right"):
			_move_category_focus(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_down"):
			_focus_selected_entry_or_close()
			get_viewport().set_input_as_handled()
	elif _entry_buttons.values().has(focus_owner):
		if event.is_action_pressed(&"ui_up"):
			_move_entry_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_down"):
			_move_entry_focus(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_left"):
			_category_buttons.get(int(_current_category)).grab_focus()
			get_viewport().set_input_as_handled()
	elif focus_owner == _close_button and event.is_action_pressed(&"ui_up"):
		_focus_selected_entry_or_category()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_catalog()


func set_game_state_override(game_state: GameStateModel) -> void:
	game_state_override = game_state
	if is_inside_tree():
		_bind_game_state()
		_refresh_catalog()


func set_data_registry(registry: GameDataRegistry) -> void:
	data_registry = registry
	if is_inside_tree():
		_refresh_catalog()


func open_browser() -> bool:
	if not _initialize_controls() or data_registry == null:
		return false
	_bind_game_state()
	if _game_state == null:
		return false
	_previous_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_refresh_catalog()
	var category_button: Button = _category_buttons.get(int(_current_category))
	if category_button != null:
		category_button.grab_focus()
	return true


func close_browser() -> void:
	if not visible:
		return
	visible = false
	if _previous_focus != null and is_instance_valid(_previous_focus):
		_previous_focus.grab_focus()
	_previous_focus = null
	browser_closed.emit()


func select_category(
	category: CodexEntryDefinition.Category
) -> bool:
	if not CodexCatalogModel.CATEGORY_ORDER.has(category):
		return false
	_current_category = category
	_selected_entry_id = &""
	_refresh_catalog()
	category_changed.emit(category)
	return true


func select_entry(entry_id: StringName) -> bool:
	var entry: CodexCatalogEntry = _find_entry(entry_id)
	if entry == null:
		return false
	_selected_entry_id = entry_id
	_render_detail(entry)
	entry_selected.emit(entry_id)
	return true


func get_current_category() -> CodexEntryDefinition.Category:
	return _current_category


func get_current_entry_count() -> int:
	return _current_entries.size()


func get_entry_button(entry_id: StringName) -> Button:
	return _entry_buttons.get(entry_id)


func get_category_button(
	category: CodexEntryDefinition.Category
) -> Button:
	return _category_buttons.get(int(category))


func get_entry_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for entry: CodexCatalogEntry in _current_entries:
		var button: Button = _entry_buttons.get(entry.id)
		if button != null:
			texts.append(button.text)
	return texts


func get_detail_title_text() -> String:
	return "" if _detail_title_label == null else _detail_title_label.text


func get_detail_description_text() -> String:
	return (
		""
		if _detail_description_label == null
		else _detail_description_label.text
	)


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("CodexPanel") as PanelContainer
	return Rect2() if panel == null else panel.get_global_rect()


func get_entry_panel_rect() -> Rect2:
	var panel: PanelContainer = %EntryPanel
	return Rect2() if panel == null else panel.get_global_rect()


func get_detail_panel_rect() -> Rect2:
	var panel: PanelContainer = %DetailPanel
	return Rect2() if panel == null else panel.get_global_rect()


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	var required_controls: Array[Control] = [
		_title_label,
		_category_row,
		_entry_scroll,
		_entry_list,
		_empty_label,
		_detail_title_label,
		_detail_status_label,
		_detail_description_label,
		_summary_label,
		_close_button,
	]
	for control: Control in required_controls:
		if control == null:
			return false
	for category: CodexEntryDefinition.Category in (
		CodexCatalogModel.get_category_order()
	):
		var category_button: Button = Button.new()
		category_button.custom_minimum_size = Vector2(0.0, 30.0)
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.focus_mode = Control.FOCUS_ALL
		category_button.toggle_mode = true
		category_button.pressed.connect(select_category.bind(category))
		_category_row.add_child(category_button)
		_category_buttons[int(category)] = category_button
	_close_button.pressed.connect(close_browser)
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
		_refresh_catalog()


func _refresh_catalog() -> void:
	if not _controls_initialized:
		return
	_localize_static_controls()
	_current_entries.clear()
	if data_registry != null and _game_state != null:
		_current_entries = CodexCatalogModel.get_entries_for_category(
			data_registry,
			_game_state,
			_current_category
		)
	_rebuild_entry_list()
	var selected_entry: CodexCatalogEntry = _find_entry(_selected_entry_id)
	if selected_entry == null and not _current_entries.is_empty():
		selected_entry = _current_entries[0]
		_selected_entry_id = selected_entry.id
	_render_detail(selected_entry)


func _localize_static_controls() -> void:
	_title_label.text = tr("UI_CODEX_TITLE")
	_close_button.text = tr("UI_CODEX_CLOSE")
	var category_keys: Dictionary[int, StringName] = {
		CodexEntryDefinition.Category.PLANET: &"UI_CODEX_CATEGORY_PLANET",
		CodexEntryDefinition.Category.CHARACTER: &"UI_CODEX_CATEGORY_CHARACTER",
		CodexEntryDefinition.Category.CARGO: &"UI_CODEX_CATEGORY_CARGO",
		CodexEntryDefinition.Category.ANOMALY: &"UI_CODEX_CATEGORY_ANOMALY",
		CodexEntryDefinition.Category.SOUVENIR: &"UI_CODEX_CATEGORY_SOUVENIR",
	}
	for category_value: int in _category_buttons:
		var category_button: Button = _category_buttons.get(category_value)
		category_button.text = tr(
			String(category_keys.get(category_value, &"UI_CODEX_UNKNOWN_TITLE"))
		)
		category_button.button_pressed = category_value == int(_current_category)


func _rebuild_entry_list() -> void:
	for child: Node in _entry_list.get_children():
		_entry_list.remove_child(child)
		child.queue_free()
	_entry_buttons.clear()
	_empty_label.visible = _current_entries.is_empty()
	_empty_label.text = tr("UI_CODEX_CATEGORY_EMPTY")
	for entry: CodexCatalogEntry in _current_entries:
		var entry_button: Button = Button.new()
		entry_button.custom_minimum_size = Vector2(0.0, 34.0)
		entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry_button.text = tr(String(entry.title_key))
		entry_button.focus_mode = Control.FOCUS_ALL
		entry_button.pressed.connect(select_entry.bind(entry.id))
		entry_button.focus_entered.connect(select_entry.bind(entry.id))
		_entry_list.add_child(entry_button)
		_entry_buttons[entry.id] = entry_button
	_summary_label.text = tr("UI_CODEX_ENTRY_COUNT_FORMAT") % _current_entries.size()


func _render_detail(entry: CodexCatalogEntry) -> void:
	if entry == null:
		_detail_title_label.text = tr("UI_CODEX_NO_SELECTION_TITLE")
		_detail_status_label.text = tr("UI_CODEX_NO_SELECTION_STATUS")
		_detail_description_label.text = tr("UI_CODEX_NO_SELECTION_DESCRIPTION")
		return
	_detail_title_label.text = tr(String(entry.title_key))
	_detail_description_label.text = tr(String(entry.description_key))
	_detail_status_label.text = tr(
		"UI_CODEX_STATUS_UNLOCKED"
		if entry.is_unlocked
		else "UI_CODEX_STATUS_UNKNOWN"
	)


func _find_entry(entry_id: StringName) -> CodexCatalogEntry:
	for entry: CodexCatalogEntry in _current_entries:
		if entry.id == entry_id:
			return entry
	return null


func _move_category_focus(direction: int) -> void:
	var categories: Array[CodexEntryDefinition.Category] = (
		CodexCatalogModel.get_category_order()
	)
	var current_index: int = categories.find(_current_category)
	var next_index: int = wrapi(current_index + direction, 0, categories.size())
	var next_category: CodexEntryDefinition.Category = categories[next_index]
	select_category(next_category)
	_category_buttons.get(int(next_category)).grab_focus()


func _move_entry_focus(direction: int) -> void:
	if _current_entries.is_empty():
		_close_button.grab_focus()
		return
	var current_index: int = 0
	for index: int in _current_entries.size():
		if _current_entries[index].id == _selected_entry_id:
			current_index = index
			break
	var next_index: int = clampi(
		current_index + direction,
		0,
		_current_entries.size() - 1
	)
	var next_entry: CodexCatalogEntry = _current_entries[next_index]
	select_entry(next_entry.id)
	_entry_buttons.get(next_entry.id).grab_focus()


func _focus_selected_entry_or_close() -> void:
	var selected_button: Button = _entry_buttons.get(_selected_entry_id)
	if selected_button != null:
		selected_button.grab_focus()
	else:
		_close_button.grab_focus()


func _focus_selected_entry_or_category() -> void:
	var selected_button: Button = _entry_buttons.get(_selected_entry_id)
	if selected_button != null:
		selected_button.grab_focus()
		return
	var category_button: Button = _category_buttons.get(int(_current_category))
	if category_button != null:
		category_button.grab_focus()
