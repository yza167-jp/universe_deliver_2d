class_name Cockpit
extends Control

signal hotspot_activated(hotspot_id: StringName)

const INTERACT_ACTION: StringName = &"interact"
const INITIAL_HOTSPOT_ID: StringName = &"navigation_screen"
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
const HOTSPOT_DESCRIPTION_KEYS: Dictionary[StringName, StringName] = {
	&"navigation_screen": &"UI_COCKPIT_DESC_NAVIGATION",
	&"window_view": &"UI_COCKPIT_DESC_WINDOW",
	&"lao_pi_seat": &"UI_COCKPIT_DESC_LAO_PI",
	&"company_terminal": &"UI_COCKPIT_DESC_COMPANY_TERMINAL",
	&"radio": &"UI_COCKPIT_DESC_RADIO",
	&"cargo_indicator": &"UI_COCKPIT_DESC_CARGO",
}

const DEEP_SPACE: Color = Color("08111f")
const SPACE_BLUE: Color = Color("142a45")
const WARM_DARK: Color = Color("2a2430")
const STATION_AMBER: Color = Color("e7a85b")
const FRIENDLY_CYAN: Color = Color("77c9c4")
const COMPANY_CREAM: Color = Color("e8dfc8")
const MUTED_TEXT: Color = Color("9aa7b5")

@onready var _title_label: Label = %TitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _hotspots_root: Control = %Hotspots
@onready var _starfield: CockpitStarfield = %Starfield

var _hotspot_buttons: Dictionary[StringName, Button] = {}
var _active_hotspot_id: StringName = &""
var _initialized: bool = false


func _ready() -> void:
	if not _initialize_hotspots():
		push_error("Cockpit graybox could not initialize all required hotspots.")
		return
	_localize_content()
	queue_redraw()
	call_deferred("focus_hotspot", INITIAL_HOTSPOT_ID)


func _unhandled_input(event: InputEvent) -> void:
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


func get_active_hotspot_id() -> StringName:
	return _active_hotspot_id


func get_feedback_text() -> String:
	return "" if _feedback_label == null else _feedback_label.text


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_starfield() -> CockpitStarfield:
	return _starfield


func focus_hotspot(hotspot_id: StringName) -> bool:
	var button: Button = _hotspot_buttons.get(hotspot_id)
	if button == null:
		return false
	button.grab_focus()
	return button.has_focus()


func activate_focused_hotspot() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or not focus_owner is Button:
		return false
	var button: Button = focus_owner as Button
	var hotspot_id: StringName = _get_button_hotspot_id(button)
	if hotspot_id.is_empty() or not _hotspot_buttons.has(hotspot_id):
		return false
	button.pressed.emit()
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
		button.mouse_entered.connect(_preview_hotspot.bind(hotspot_id))
		button.focus_entered.connect(_preview_hotspot.bind(hotspot_id))
		button.pressed.connect(_activate_hotspot.bind(hotspot_id))
	for hotspot_id: StringName in HOTSPOT_IDS:
		if not _hotspot_buttons.has(hotspot_id):
			return false
	_initialized = true
	return true


func _localize_content() -> void:
	_title_label.text = tr("UI_COCKPIT_TITLE")
	_instruction_label.text = tr("UI_COCKPIT_INSTRUCTIONS")
	for hotspot_id: StringName in HOTSPOT_IDS:
		var button: Button = _hotspot_buttons.get(hotspot_id)
		if button == null:
			continue
		button.text = tr(String(HOTSPOT_TITLE_KEYS[hotspot_id]))
		button.tooltip_text = tr(String(HOTSPOT_DESCRIPTION_KEYS[hotspot_id]))
	if _active_hotspot_id.is_empty():
		_status_label.text = tr("UI_COCKPIT_STATUS_READY")
		_feedback_label.text = tr("UI_COCKPIT_FEEDBACK_READY")
	else:
		_preview_hotspot(_active_hotspot_id)


func _preview_hotspot(hotspot_id: StringName) -> void:
	if not HOTSPOT_IDS.has(hotspot_id):
		return
	_active_hotspot_id = hotspot_id
	_status_label.text = tr(String(HOTSPOT_TITLE_KEYS[hotspot_id]))
	_feedback_label.text = tr(String(HOTSPOT_DESCRIPTION_KEYS[hotspot_id]))


func _activate_hotspot(hotspot_id: StringName) -> void:
	if not HOTSPOT_IDS.has(hotspot_id):
		return
	_active_hotspot_id = hotspot_id
	var title: String = tr(String(HOTSPOT_TITLE_KEYS[hotspot_id]))
	_status_label.text = tr("UI_COCKPIT_STATUS_ACTIVE_FORMAT") % title
	_feedback_label.text = tr(String(HOTSPOT_DESCRIPTION_KEYS[hotspot_id]))
	hotspot_activated.emit(hotspot_id)


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
