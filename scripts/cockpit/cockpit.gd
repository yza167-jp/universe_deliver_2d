class_name Cockpit
extends Control

signal hotspot_focused(hotspot_id: StringName)
signal hotspot_activated(hotspot_id: StringName)
signal radio_state_changed(is_on: bool)

const INTERACT_ACTION: StringName = &"interact"
const CANCEL_ACTION: StringName = &"ui_cancel"
const INITIAL_HOTSPOT_ID: StringName = &"navigation_screen"
const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/narrative/dialogue_ui.tscn")

const HOTSPOT_IDS: Array[StringName] = [
	&"navigation_screen",
	&"window_view",
	&"lao_pi_seat",
	&"company_terminal",
	&"radio",
	&"cargo_indicator",
]
const HOTSPOT_TITLE_KEYS: Dictionary[StringName, StringName] = {
	&"navigation_screen": &"UI_COCKPIT_HOTSPOT_NAVIGATION",
	&"window_view": &"UI_COCKPIT_HOTSPOT_WINDOW",
	&"lao_pi_seat": &"UI_COCKPIT_HOTSPOT_LAO_PI",
	&"company_terminal": &"UI_COCKPIT_HOTSPOT_COMPANY_TERMINAL",
	&"radio": &"UI_COCKPIT_HOTSPOT_RADIO",
	&"cargo_indicator": &"UI_COCKPIT_HOTSPOT_CARGO",
}
const HOTSPOT_ACTION_KEYS: Dictionary[StringName, StringName] = {
	&"navigation_screen": &"UI_COCKPIT_ACTION_NAVIGATION",
	&"window_view": &"UI_COCKPIT_ACTION_WINDOW",
	&"lao_pi_seat": &"UI_COCKPIT_ACTION_LAO_PI",
	&"company_terminal": &"UI_COCKPIT_ACTION_COMPANY_TERMINAL",
	&"radio": &"UI_COCKPIT_ACTION_RADIO",
	&"cargo_indicator": &"UI_COCKPIT_ACTION_CARGO",
}

const DEEP_SPACE: Color = Color("08111f")
const SPACE_BLUE: Color = Color("142a45")
const WARM_DARK: Color = Color("2a2430")
const STATION_AMBER: Color = Color("e7a85b")
const FRIENDLY_CYAN: Color = Color("77c9c4")
const COMPANY_CREAM: Color = Color("e8dfc8")
const MUTED_TEXT: Color = Color("9aa7b5")

@export var data_registry: GameDataRegistry
@export var lao_pi_dialogue: DialogueSequence

@onready var _title_label: Label = %TitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _hotspots_root: Control = %Hotspots
@onready var _starfield: CockpitStarfield = %Starfield
@onready var _notification_panel: PanelContainer = %NotificationPanel
@onready var _notification_label: Label = %NotificationLabel
@onready var _notification_timer: Timer = %NotificationTimer
@onready var _modal_layer: Control = %ModalLayer
@onready var _device_dimmer: ColorRect = %DeviceDimmer
@onready var _device_panel: PanelContainer = %DevicePanel
@onready var _device_panel_title: Label = %DevicePanelTitle
@onready var _device_panel_body: Label = %DevicePanelBody
@onready var _device_close_button: Button = %DeviceCloseButton

var _hotspot_buttons: Dictionary[StringName, Button] = {}
var _selected_hotspot_id: StringName = &""
var _last_activated_hotspot_id: StringName = &""
var _modal_hotspot_id: StringName = &""
var _open_panel_id: StringName = &""
var _notification_key: StringName = &""
var _radio_on: bool = false
var _dialogue_active: bool = false
var _initialized: bool = false
var _game_state: GameStateModel
var _dialogue_ui: DialogueUI
var _fallback_dialogue_layer: CanvasLayer


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState") as GameStateModel
	_dialogue_ui = _resolve_dialogue_ui()
	if not _initialize_hotspots() or not _resolve_required_ui():
		push_error("Cockpit could not initialize its hotspots, panels, or dialogue UI.")
		return
	_connect_runtime_signals()
	_modal_layer.visible = false
	_device_panel.visible = false
	_device_dimmer.visible = false
	_notification_panel.visible = false
	_localize_content()
	queue_redraw()
	call_deferred("focus_hotspot", INITIAL_HOTSPOT_ID)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(CANCEL_ACTION):
		if close_active_modal():
			get_viewport().set_input_as_handled()
			return
		if _notification_panel.visible:
			_hide_notification()
			get_viewport().set_input_as_handled()
		return
	if is_input_locked():
		if event.is_action_pressed(INTERACT_ACTION):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INTERACT_ACTION) and activate_focused_hotspot():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _initialized:
		_localize_content()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DEEP_SPACE, true)
	draw_rect(Rect2(0.0, 0.0, size.x, 30.0), WARM_DARK.darkened(0.18), true)
	draw_rect(Rect2(88.0, 24.0, 464.0, 168.0), SPACE_BLUE.darkened(0.25), true)
	draw_rect(Rect2(94.0, 30.0, 452.0, 156.0), FRIENDLY_CYAN.darkened(0.52), false, 2.0)
	draw_line(Vector2(96.0, 32.0), Vector2(142.0, 184.0), MUTED_TEXT.darkened(0.35), 5.0)
	draw_line(Vector2(544.0, 32.0), Vector2(498.0, 184.0), MUTED_TEXT.darkened(0.35), 5.0)
	draw_rect(Rect2(0.0, 184.0, size.x, 124.0), WARM_DARK, true)
	draw_line(Vector2(0.0, 190.0), Vector2(size.x, 190.0), STATION_AMBER.darkened(0.28), 3.0)
	draw_rect(Rect2(16.0, 196.0, 496.0, 104.0), SPACE_BLUE.darkened(0.22), true)
	draw_rect(Rect2(510.0, 188.0, 118.0, 112.0), WARM_DARK.lightened(0.09), true)
	_draw_lao_pi_silhouette()
	draw_rect(Rect2(0.0, 306.0, size.x, 54.0), SPACE_BLUE.darkened(0.2), true)
	draw_line(Vector2(0.0, 306.0), Vector2(size.x, 306.0), FRIENDLY_CYAN.darkened(0.18), 2.0)


func get_hotspot_ids() -> Array[StringName]:
	return HOTSPOT_IDS.duplicate()


func get_hotspot_button(hotspot_id: StringName) -> Button:
	return _hotspot_buttons.get(hotspot_id)


func get_hotspot_rects() -> Dictionary[StringName, Rect2]:
	var rects: Dictionary[StringName, Rect2] = {}
	for hotspot_id: StringName in HOTSPOT_IDS:
		var button: Button = _hotspot_buttons.get(hotspot_id)
		if button != null:
			rects[hotspot_id] = button.get_global_rect()
	return rects


func get_selected_hotspot_id() -> StringName:
	return _selected_hotspot_id


## Compatibility alias for callers from the first graybox pass.
func get_active_hotspot_id() -> StringName:
	return _selected_hotspot_id


func get_last_activated_hotspot_id() -> StringName:
	return _last_activated_hotspot_id


func get_prompt_text() -> String:
	return "" if _prompt_label == null else _prompt_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_open_panel_id() -> StringName:
	return _open_panel_id


func get_device_panel_title() -> String:
	return "" if _device_panel_title == null else _device_panel_title.text


func get_device_panel_body() -> String:
	return "" if _device_panel_body == null else _device_panel_body.text


func get_notification_text() -> String:
	return "" if _notification_label == null else _notification_label.text


func get_dialogue_ui() -> DialogueUI:
	return _dialogue_ui


func get_starfield() -> CockpitStarfield:
	return _starfield


func is_input_locked() -> bool:
	return not _modal_hotspot_id.is_empty()


func is_dialogue_active() -> bool:
	return _dialogue_active


func is_notification_visible() -> bool:
	return _notification_panel != null and _notification_panel.visible


func is_radio_on() -> bool:
	return _radio_on


func focus_hotspot(hotspot_id: StringName) -> bool:
	if is_input_locked():
		return false
	var button: Button = _hotspot_buttons.get(hotspot_id)
	if button == null:
		return false
	button.grab_focus()
	return button.has_focus()


## Shared activation entry used by both Button.pressed and the mapped interaction action.
func activate_hotspot(hotspot_id: StringName) -> bool:
	if is_input_locked() or not _hotspot_buttons.has(hotspot_id):
		return false
	_select_hotspot(hotspot_id)
	var behavior_started: bool = false
	match hotspot_id:
		&"navigation_screen", &"company_terminal", &"cargo_indicator":
			behavior_started = _open_device_panel(hotspot_id)
		&"lao_pi_seat":
			behavior_started = _start_lao_pi_dialogue()
		&"radio":
			behavior_started = _toggle_radio()
		&"window_view":
			behavior_started = _observe_window()
	if not behavior_started:
		return false
	_last_activated_hotspot_id = hotspot_id
	hotspot_activated.emit(hotspot_id)
	return true


func activate_focused_hotspot() -> bool:
	if is_input_locked():
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or not focus_owner is Button:
		return false
	var button: Button = focus_owner as Button
	var hotspot_id: StringName = _get_button_hotspot_id(button)
	if hotspot_id.is_empty():
		return false
	return activate_hotspot(hotspot_id)


func close_active_modal() -> bool:
	if _dialogue_active:
		return _dialogue_ui != null and _dialogue_ui.cancel_dialogue()
	if _open_panel_id.is_empty():
		return false
	_finish_modal()
	return true


func _initialize_hotspots() -> bool:
	if _initialized:
		return true
	if _hotspots_root == null or _starfield == null:
		return false
	for child: Node in _hotspots_root.get_children():
		if not child is Button:
			continue
		var button: Button = child as Button
		var hotspot_id: StringName = _get_button_hotspot_id(button)
		if (
			hotspot_id.is_empty()
			or not HOTSPOT_IDS.has(hotspot_id)
			or _hotspot_buttons.has(hotspot_id)
		):
			return false
		_hotspot_buttons[hotspot_id] = button
		button.tooltip_text = ""
		button.focus_entered.connect(_select_hotspot.bind(hotspot_id))
		button.pressed.connect(_on_hotspot_pressed.bind(hotspot_id))
	for hotspot_id: StringName in HOTSPOT_IDS:
		if not _hotspot_buttons.has(hotspot_id):
			return false
	_initialized = true
	return true


func _resolve_required_ui() -> bool:
	return (
		_title_label != null
		and _instruction_label != null
		and _status_label != null
		and _prompt_label != null
		and _notification_panel != null
		and _notification_label != null
		and _notification_timer != null
		and _modal_layer != null
		and _device_dimmer != null
		and _device_panel != null
		and _device_panel_title != null
		and _device_panel_body != null
		and _device_close_button != null
		and _dialogue_ui != null
	)


func _connect_runtime_signals() -> void:
	if not _device_close_button.pressed.is_connected(close_active_modal):
		_device_close_button.pressed.connect(close_active_modal)
	if not _notification_timer.timeout.is_connected(_hide_notification):
		_notification_timer.timeout.connect(_hide_notification)
	if not _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)


func _localize_content() -> void:
	_title_label.text = tr("UI_COCKPIT_TITLE")
	_instruction_label.text = tr("UI_COCKPIT_INSTRUCTIONS")
	_device_close_button.text = tr("UI_COCKPIT_PANEL_CLOSE")
	for hotspot_id: StringName in HOTSPOT_IDS:
		var button: Button = _hotspot_buttons.get(hotspot_id)
		if button != null:
			button.text = _get_hotspot_button_text(hotspot_id)
			button.tooltip_text = ""
	_refresh_focus_prompt()
	if not _open_panel_id.is_empty():
		_populate_device_panel(_open_panel_id)
	if not _notification_key.is_empty():
		_notification_label.text = tr(String(_notification_key))


func _select_hotspot(hotspot_id: StringName) -> void:
	if is_input_locked() or not HOTSPOT_IDS.has(hotspot_id):
		return
	var changed: bool = _selected_hotspot_id != hotspot_id
	_selected_hotspot_id = hotspot_id
	_refresh_focus_prompt()
	if changed:
		hotspot_focused.emit(hotspot_id)


func _refresh_focus_prompt() -> void:
	if _selected_hotspot_id.is_empty():
		_status_label.text = tr("UI_COCKPIT_STATUS_READY")
		_prompt_label.text = tr("UI_COCKPIT_SELECT_PROMPT")
		return
	_status_label.text = _get_hotspot_status_text(_selected_hotspot_id)
	var action_text: String = tr(String(HOTSPOT_ACTION_KEYS[_selected_hotspot_id]))
	_prompt_label.text = tr("UI_COCKPIT_FOCUS_PROMPT_FORMAT") % [
		_get_action_binding_label(INTERACT_ACTION),
		action_text,
	]


func _get_hotspot_status_text(hotspot_id: StringName) -> String:
	var title: String = tr(String(HOTSPOT_TITLE_KEYS[hotspot_id]))
	if hotspot_id != &"radio":
		return title
	return tr("UI_COCKPIT_RADIO_STATUS_FORMAT") % [
		title,
		tr("UI_COCKPIT_RADIO_ON" if _radio_on else "UI_COCKPIT_RADIO_OFF"),
	]


func _get_hotspot_button_text(hotspot_id: StringName) -> String:
	var title: String = tr(String(HOTSPOT_TITLE_KEYS[hotspot_id]))
	if hotspot_id != &"radio":
		return title
	return tr("UI_COCKPIT_RADIO_BUTTON_FORMAT") % [
		title,
		tr("UI_COCKPIT_RADIO_ON" if _radio_on else "UI_COCKPIT_RADIO_OFF"),
	]


func _on_hotspot_pressed(hotspot_id: StringName) -> void:
	if is_input_locked():
		return
	focus_hotspot(hotspot_id)
	activate_hotspot(hotspot_id)


func _open_device_panel(hotspot_id: StringName) -> bool:
	if not hotspot_id in [&"navigation_screen", &"company_terminal", &"cargo_indicator"]:
		return false
	if not _begin_modal(hotspot_id):
		return false
	_open_panel_id = hotspot_id
	_dialogue_active = false
	_device_dimmer.visible = true
	_device_panel.visible = true
	_populate_device_panel(hotspot_id)
	_device_close_button.grab_focus()
	return true


func _populate_device_panel(hotspot_id: StringName) -> void:
	match hotspot_id:
		&"navigation_screen":
			_device_panel_title.text = tr("UI_COCKPIT_NAV_PANEL_TITLE")
			_device_panel_body.text = _build_navigation_panel_text()
		&"company_terminal":
			_device_panel_title.text = tr("UI_COCKPIT_COMPANY_PANEL_TITLE")
			_device_panel_body.text = _build_company_panel_text()
		&"cargo_indicator":
			_device_panel_title.text = tr("UI_COCKPIT_CARGO_PANEL_TITLE")
			_device_panel_body.text = _build_cargo_panel_text()


func _build_navigation_panel_text() -> String:
	if _game_state == null or data_registry == null or _game_state.current_order_id.is_empty():
		return "\n".join([
			tr("UI_COCKPIT_NAV_NO_ORDER"),
			tr("UI_COCKPIT_NAV_DESTINATION_UNSET"),
			tr("UI_COCKPIT_NAV_ROUTE_PENDING"),
		])
	var order: OrderDefinition = data_registry.find_order(_game_state.current_order_id)
	var planet: PlanetDefinition = data_registry.find_planet(_game_state.destination_id)
	var order_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	var planet_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	if order != null:
		order_name = tr(String(order.display_name_key))
	if planet != null:
		planet_name = tr(String(planet.display_name_key))
	return "\n".join([
		tr("UI_COCKPIT_NAV_ORDER_FORMAT") % order_name,
		tr("UI_COCKPIT_NAV_DESTINATION_FORMAT") % planet_name,
		tr("UI_COCKPIT_NAV_ROUTE_PENDING"),
	])


func _build_company_panel_text() -> String:
	var order_status: String = tr("UI_COCKPIT_COMPANY_NO_ACTIVE_ORDER")
	if _game_state != null and data_registry != null and not _game_state.current_order_id.is_empty():
		var order: OrderDefinition = data_registry.find_order(_game_state.current_order_id)
		if order != null:
			order_status = tr("UI_COCKPIT_COMPANY_ACTIVE_ORDER_FORMAT") % tr(
				String(order.display_name_key)
			)
	return "\n".join([
		tr("UI_COCKPIT_COMPANY_LINK_STATUS"),
		order_status,
		tr("UI_COCKPIT_COMPANY_TRAVEL_NOTICE"),
	])


func _build_cargo_panel_text() -> String:
	if _game_state == null or data_registry == null or _game_state.cargo_id.is_empty():
		return "\n".join([
			tr("UI_COCKPIT_CARGO_EMPTY"),
			tr("UI_COCKPIT_CARGO_LOCK_STATUS"),
		])
	var cargo: CargoDefinition = data_registry.find_cargo(_game_state.cargo_id)
	var cargo_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	if cargo != null:
		cargo_name = tr(String(cargo.display_name_key))
	return "\n".join([
		tr("UI_COCKPIT_CARGO_LOADED_FORMAT") % cargo_name,
		tr("UI_COCKPIT_CARGO_INTEGRITY_PLACEHOLDER"),
		tr("UI_COCKPIT_CARGO_LOCK_STATUS"),
	])


func _start_lao_pi_dialogue() -> bool:
	if lao_pi_dialogue == null or _dialogue_ui == null or _game_state == null:
		return false
	if _dialogue_ui.visible or not _begin_modal(&"lao_pi_seat"):
		return false
	_device_dimmer.visible = false
	_device_panel.visible = false
	if not _dialogue_ui.start_dialogue(lao_pi_dialogue, _game_state):
		_finish_modal()
		return false
	_dialogue_active = true
	return true


func _on_dialogue_finished() -> void:
	if not _dialogue_active:
		return
	_dialogue_active = false
	_finish_modal()


func _toggle_radio() -> bool:
	_radio_on = not _radio_on
	var radio_button: Button = _hotspot_buttons.get(&"radio")
	if radio_button != null:
		radio_button.text = _get_hotspot_button_text(&"radio")
	_refresh_focus_prompt()
	radio_state_changed.emit(_radio_on)
	return true


func _observe_window() -> bool:
	_show_notification(&"UI_COCKPIT_WINDOW_OBSERVATION")
	return true


func _show_notification(localization_key: StringName) -> void:
	_notification_key = localization_key
	_notification_label.text = tr(String(localization_key))
	_notification_panel.visible = true
	_notification_timer.start()


func _hide_notification() -> void:
	_notification_timer.stop()
	_notification_panel.visible = false
	_notification_label.text = ""
	_notification_key = &""


func _begin_modal(hotspot_id: StringName) -> bool:
	if is_input_locked() or hotspot_id.is_empty():
		return false
	_modal_hotspot_id = hotspot_id
	_hide_notification()
	_set_hotspot_input_enabled(false)
	_modal_layer.visible = true
	return true


func _finish_modal() -> void:
	var return_hotspot_id: StringName = _modal_hotspot_id
	_modal_hotspot_id = &""
	_open_panel_id = &""
	_dialogue_active = false
	_device_panel.visible = false
	_device_dimmer.visible = false
	_modal_layer.visible = false
	_set_hotspot_input_enabled(true)
	_refresh_focus_prompt()
	if not return_hotspot_id.is_empty():
		call_deferred("focus_hotspot", return_hotspot_id)


func _set_hotspot_input_enabled(enabled: bool) -> void:
	for hotspot_id: StringName in HOTSPOT_IDS:
		var button: Button = _hotspot_buttons.get(hotspot_id)
		if button == null:
			continue
		if not enabled and button.has_focus():
			button.release_focus()
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _resolve_dialogue_ui() -> DialogueUI:
	for node: Node in get_tree().get_nodes_in_group("dialogue_ui"):
		if node is DialogueUI:
			return node as DialogueUI
	_fallback_dialogue_layer = CanvasLayer.new()
	_fallback_dialogue_layer.name = "CockpitDialogueFallbackLayer"
	_fallback_dialogue_layer.layer = 30
	add_child(_fallback_dialogue_layer)
	var fallback_ui: DialogueUI = DIALOGUE_UI_SCENE.instantiate() as DialogueUI
	if fallback_ui == null:
		return null
	_fallback_dialogue_layer.add_child(fallback_ui)
	return fallback_ui


func _get_action_binding_label(action: StringName) -> String:
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event as InputEventKey
			var keycode: Key = key_event.physical_keycode
			if keycode == KEY_NONE:
				keycode = key_event.keycode
			var key_label: String = OS.get_keycode_string(keycode)
			if not key_label.is_empty():
				return key_label
		var event_label: String = input_event.as_text()
		if not event_label.is_empty():
			return event_label
	return String(action).to_upper()


func _get_button_hotspot_id(button: Button) -> StringName:
	if button == null:
		return &""
	return StringName(String(button.get_meta("hotspot_id", "")))


func _draw_lao_pi_silhouette() -> void:
	var head_center: Vector2 = Vector2(574.0, 220.0)
	draw_circle(head_center, 19.0, STATION_AMBER.darkened(0.18))
	draw_circle(head_center + Vector2(-13.0, -16.0), 5.0, STATION_AMBER.darkened(0.24))
	draw_circle(head_center + Vector2(13.0, -16.0), 5.0, STATION_AMBER.darkened(0.24))
	draw_circle(head_center + Vector2(7.0, -2.0), 2.0, DEEP_SPACE)
	draw_rect(Rect2(548.0, 238.0, 52.0, 54.0), STATION_AMBER.darkened(0.3), true)
	draw_line(Vector2(552.0, 246.0), Vector2(596.0, 282.0), FRIENDLY_CYAN, 3.0)
	draw_circle(Vector2(608.0, 276.0), 7.0, COMPANY_CREAM.darkened(0.18))
