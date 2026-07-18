class_name Cockpit
extends Control

signal hotspot_focused(hotspot_id: StringName)
signal hotspot_activated(hotspot_id: StringName)
signal radio_state_changed(is_on: bool)
signal travel_phase_changed(phase: GameStateModel.TravelState)
signal travel_finished(destination_id: StringName)

enum DialogueContext {
	NONE,
	MANUAL_LAO_PI,
	TRAVEL_REQUIRED,
	TRAVEL_RADIO,
	TRAVEL_CARGO,
}

const INTERACT_ACTION: StringName = &"interact"
const CANCEL_ACTION: StringName = &"ui_cancel"
const INITIAL_HOTSPOT_ID: StringName = &"navigation_screen"
const TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG: StringName = (
	&"story_cockpit_travel_main_completed"
)
const DIALOGUE_UI_SCENE: PackedScene = preload("res://scenes/narrative/dialogue_ui.tscn")
const TRAVEL_PHASE_CUE_SECONDS: float = 0.16
const TRAVEL_PHASE_CUE_VOLUME: float = 0.045
const RADIO_SAMPLE_RATE: int = 22050
const RADIO_LOOP_SECONDS: float = 1.2
const RADIO_VOLUME_DB: float = -30.0
const TRAVEL_PHASE_SPEEDS: Dictionary[GameStateModel.TravelState, float] = {
	GameStateModel.TravelState.DEPARTURE: 2.0,
	GameStateModel.TravelState.CRUISE: 3.4,
	GameStateModel.TravelState.APPROACH: 1.4,
}

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
@export var travel_main_dialogue: DialogueSequence
@export var travel_radio_dialogue: DialogueSequence
@export var travel_cargo_dialogue: DialogueSequence

@onready var _title_label: Label = %TitleLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _status_panel: PanelContainer = %StatusPanel
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
@onready var _device_action_button: Button = %DeviceActionButton
@onready var _device_close_button: Button = %DeviceCloseButton
@onready var _travel_controller: TravelSequenceController = %TravelSequenceController
@onready var _travel_progress_bar: ProgressBar = %TravelProgressBar
@onready var _skip_travel_button: Button = %SkipTravelButton
@onready var _travel_audio_player: AudioStreamPlayer = %TravelAudioPlayer
@onready var _radio_audio_player: AudioStreamPlayer = %RadioAudioPlayer
@onready var _radio_feedback: CockpitRadioFeedback = %RadioFeedback

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
var _scene_router: SceneRouterService
var _active_order: OrderDefinition
var _dialogue_ui: DialogueUI
var _fallback_dialogue_layer: CanvasLayer
var _forward_window_passive: bool = false
var _active_dialogue_context: DialogueContext = DialogueContext.NONE
var _active_dialogue_id: StringName = &""
var _active_dialogue_holds_travel: bool = false
var _travel_main_dialogue_pending: bool = false


func _ready() -> void:
	_game_state = get_node_or_null("/root/GameState") as GameStateModel
	_scene_router = get_node_or_null("/root/SceneRouter") as SceneRouterService
	_dialogue_ui = _resolve_dialogue_ui()
	if not _initialize_hotspots() or not _resolve_required_ui():
		push_error("Cockpit could not initialize its hotspots, panels, or dialogue UI.")
		return
	_active_order = _resolve_active_order()
	_travel_controller.configure(_game_state, _active_order)
	_connect_runtime_signals()
	_configure_travel_audio()
	_configure_radio_audio()
	_modal_layer.visible = false
	_device_panel.visible = false
	_device_dimmer.visible = false
	_device_action_button.visible = false
	_notification_panel.visible = false
	_localize_content()
	_refresh_travel_display()
	_queue_travel_main_dialogue_if_needed(_travel_controller.get_phase())
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


func _exit_tree() -> void:
	if _travel_audio_player != null:
		_travel_audio_player.stop()
		_travel_audio_player.stream = null
	if _radio_audio_player != null:
		_radio_audio_player.stop()
		_radio_audio_player.stream = null


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


func get_active_dialogue_id() -> StringName:
	return _active_dialogue_id


func is_travel_main_dialogue_pending() -> bool:
	return _travel_main_dialogue_pending


func get_starfield() -> CockpitStarfield:
	return _starfield


func get_travel_controller() -> TravelSequenceController:
	return _travel_controller


func get_travel_phase_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_travel_detail_text() -> String:
	return "" if _prompt_label == null else _prompt_label.text


func is_travel_status_visible() -> bool:
	return _travel_progress_bar != null and _travel_progress_bar.visible


func get_travel_hud_rect() -> Rect2:
	return Rect2() if _status_panel == null else _status_panel.get_global_rect()


func get_forward_window_rect() -> Rect2:
	var window_button: Button = _hotspot_buttons.get(&"window_view")
	return Rect2() if window_button == null else window_button.get_global_rect()


func is_forward_window_passive() -> bool:
	return _forward_window_passive


func is_skip_travel_visible() -> bool:
	return _skip_travel_button != null and _skip_travel_button.visible


func is_navigation_action_enabled() -> bool:
	return (
		_device_action_button != null
		and _device_action_button.visible
		and not _device_action_button.disabled
	)


func get_navigation_action_text() -> String:
	return "" if _device_action_button == null else _device_action_button.text


func start_configured_travel() -> bool:
	_active_order = _resolve_active_order()
	if (
		_active_order == null
		or _active_order.destination_planet == null
		or _game_state == null
	):
		_show_notification(&"UI_COCKPIT_TRAVEL_ERROR_NO_ORDER")
		return false
	var destination: StringName = _active_order.destination_planet.id
	var travel_error: StringName = _game_state.get_travel_start_error(
		_active_order,
		destination
	)
	if not travel_error.is_empty():
		_game_state.last_travel_error = travel_error
		_show_notification(_get_travel_error_key(travel_error))
		return false
	_travel_controller.configure(_game_state, _active_order)
	if not _travel_controller.start_travel(destination):
		_show_notification(_get_travel_error_key(_game_state.last_travel_error))
		return false
	if not _open_panel_id.is_empty():
		_finish_modal()
	return true


func is_input_locked() -> bool:
	return not _modal_hotspot_id.is_empty()


func is_dialogue_active() -> bool:
	return _dialogue_active


func is_notification_visible() -> bool:
	return _notification_panel != null and _notification_panel.visible


func is_radio_on() -> bool:
	return _radio_on


func is_radio_audio_playing() -> bool:
	return _radio_audio_player != null and _radio_audio_player.playing


func get_radio_audio_player() -> AudioStreamPlayer:
	return _radio_audio_player


func get_radio_feedback() -> CockpitRadioFeedback:
	return _radio_feedback


func focus_hotspot(hotspot_id: StringName) -> bool:
	if is_input_locked() or _is_passive_window_hotspot(hotspot_id):
		return false
	var button: Button = _hotspot_buttons.get(hotspot_id)
	if button == null:
		return false
	button.grab_focus()
	return button.has_focus()


## Shared activation entry used by both Button.pressed and the mapped interaction action.
func activate_hotspot(hotspot_id: StringName) -> bool:
	if (
		is_input_locked()
		or not _hotspot_buttons.has(hotspot_id)
		or _is_passive_window_hotspot(hotspot_id)
	):
		return false
	_select_hotspot(hotspot_id)
	var behavior_started: bool = false
	match hotspot_id:
		&"navigation_screen", &"company_terminal":
			behavior_started = _open_device_panel(hotspot_id)
		&"cargo_indicator":
			behavior_started = _activate_cargo_hotspot()
		&"lao_pi_seat":
			behavior_started = _start_lao_pi_dialogue()
		&"radio":
			behavior_started = _activate_radio_hotspot()
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
		and _status_panel != null
		and _notification_panel != null
		and _notification_label != null
		and _notification_timer != null
		and _modal_layer != null
		and _device_dimmer != null
		and _device_panel != null
		and _device_panel_title != null
		and _device_panel_body != null
		and _device_action_button != null
		and _device_close_button != null
		and _travel_controller != null
		and _travel_progress_bar != null
		and _skip_travel_button != null
		and _travel_audio_player != null
		and _radio_audio_player != null
		and _radio_feedback != null
		and _dialogue_ui != null
	)


func _connect_runtime_signals() -> void:
	if (
		_game_state != null
		and not _game_state.runtime_state_reset.is_connected(_on_runtime_state_reset)
	):
		_game_state.runtime_state_reset.connect(_on_runtime_state_reset)
	if not _device_action_button.pressed.is_connected(_on_device_action_pressed):
		_device_action_button.pressed.connect(_on_device_action_pressed)
	if not _device_close_button.pressed.is_connected(close_active_modal):
		_device_close_button.pressed.connect(close_active_modal)
	if not _skip_travel_button.pressed.is_connected(_on_skip_travel_pressed):
		_skip_travel_button.pressed.connect(_on_skip_travel_pressed)
	if not _notification_timer.timeout.is_connected(_hide_notification):
		_notification_timer.timeout.connect(_hide_notification)
	if not _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
		_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
	if not _travel_controller.travel_started.is_connected(_on_travel_started):
		_travel_controller.travel_started.connect(_on_travel_started)
	if not _travel_controller.phase_changed.is_connected(_on_travel_phase_changed):
		_travel_controller.phase_changed.connect(_on_travel_phase_changed)
	if not _travel_controller.progress_changed.is_connected(_on_travel_progress_changed):
		_travel_controller.progress_changed.connect(_on_travel_progress_changed)
	if not _travel_controller.travel_completed.is_connected(_on_travel_completed):
		_travel_controller.travel_completed.connect(_on_travel_completed)


func _localize_content() -> void:
	_title_label.text = tr("UI_COCKPIT_TITLE")
	_instruction_label.text = tr("UI_COCKPIT_INSTRUCTIONS")
	_device_action_button.text = tr("UI_COCKPIT_NAV_CONFIRM_AND_DEPART")
	_device_close_button.text = tr("UI_COCKPIT_PANEL_CLOSE")
	_skip_travel_button.text = tr("UI_COCKPIT_TRAVEL_SKIP")
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
	_refresh_travel_display()


func _select_hotspot(hotspot_id: StringName) -> void:
	if (
		is_input_locked()
		or not HOTSPOT_IDS.has(hotspot_id)
		or _is_passive_window_hotspot(hotspot_id)
	):
		return
	var changed: bool = _selected_hotspot_id != hotspot_id
	_selected_hotspot_id = hotspot_id
	_refresh_focus_prompt()
	if changed:
		hotspot_focused.emit(hotspot_id)


func _refresh_focus_prompt() -> void:
	if _is_travel_window_passive():
		_refresh_travel_status_text()
		return
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
	if hotspot_id == &"navigation_screen" and is_navigation_action_enabled():
		_device_action_button.grab_focus()
	else:
		_device_close_button.grab_focus()
	return true


func _populate_device_panel(hotspot_id: StringName) -> void:
	_device_action_button.visible = hotspot_id == &"navigation_screen"
	match hotspot_id:
		&"navigation_screen":
			_device_panel_title.text = tr("UI_COCKPIT_NAV_PANEL_TITLE")
			_device_panel_body.text = _build_navigation_panel_text()
			_refresh_navigation_action()
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
			tr("UI_COCKPIT_NAV_ROUTE_NO_ORDER"),
		])
	var order: OrderDefinition = _resolve_active_order()
	var planet: PlanetDefinition = data_registry.find_planet(_game_state.destination_id)
	var order_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	var planet_name: String = tr("UI_COCKPIT_VALUE_UNAVAILABLE")
	if order != null:
		order_name = tr(String(order.display_name_key))
	if planet != null:
		planet_name = tr(String(planet.display_name_key))
	var route_status: String = tr("UI_COCKPIT_NAV_ROUTE_PENDING")
	if order != null:
		var travel_error: StringName = _game_state.get_travel_start_error(
			order,
			order.destination_planet.id
		)
		route_status = tr(String(_get_travel_route_status_key(travel_error)))
	return "\n".join([
		tr("UI_COCKPIT_NAV_ORDER_FORMAT") % order_name,
		tr("UI_COCKPIT_NAV_DESTINATION_FORMAT") % planet_name,
		route_status,
	])


func _build_company_panel_text() -> String:
	var order_status: String = tr("UI_COCKPIT_COMPANY_NO_ACTIVE_ORDER")
	if _game_state != null and data_registry != null and not _game_state.current_order_id.is_empty():
		var order: OrderDefinition = data_registry.find_order(_game_state.current_order_id)
		if order != null:
			order_status = tr("UI_COCKPIT_COMPANY_ACTIVE_ORDER_FORMAT") % tr(
				String(order.display_name_key)
			)
	var travel_status: String = tr("UI_COCKPIT_COMPANY_TRAVEL_NOTICE")
	if _game_state != null:
		travel_status = tr(String(_get_company_travel_status_key(_game_state.travel_state)))
	return "\n".join([
		tr("UI_COCKPIT_COMPANY_LINK_STATUS"),
		order_status,
		travel_status,
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


func _refresh_navigation_action() -> void:
	_active_order = _resolve_active_order()
	_device_action_button.text = tr("UI_COCKPIT_NAV_CONFIRM_AND_DEPART")
	if _game_state == null or _active_order == null:
		_device_action_button.disabled = true
		return
	var destination: StringName = _active_order.destination_planet.id
	_device_action_button.disabled = not _game_state.get_travel_start_error(
		_active_order,
		destination
	).is_empty()


func _on_device_action_pressed() -> void:
	if _open_panel_id != &"navigation_screen":
		return
	start_configured_travel()


func _on_skip_travel_pressed() -> void:
	if not _travel_controller.skip_travel():
		_show_notification(&"UI_COCKPIT_TRAVEL_SKIP_LOCKED")


func _on_travel_started(_destination_id: StringName) -> void:
	_refresh_travel_display()


func _on_travel_phase_changed(phase: GameStateModel.TravelState) -> void:
	_refresh_travel_display()
	_play_travel_phase_cue(phase)
	travel_phase_changed.emit(phase)
	_queue_travel_main_dialogue_if_needed(phase)


func _on_travel_progress_changed(
	phase: GameStateModel.TravelState,
	_phase_progress: float,
	total_progress: float
) -> void:
	_update_travel_visuals(phase, total_progress)


func _on_travel_completed(destination_id: StringName, _was_skipped: bool) -> void:
	_refresh_travel_display()
	travel_finished.emit(destination_id)
	if _scene_router == null or _scene_router.current_stage != SceneRouterService.Stage.COCKPIT:
		_show_notification(&"UI_COCKPIT_TRAVEL_READY_FOR_FLIGHT")
		return
	if not _scene_router.request_stage(SceneRouterService.Stage.FLIGHT):
		push_error("Cockpit could not transition to FLIGHT: %s" % _scene_router.last_error)


func _on_runtime_state_reset() -> void:
	_active_order = _resolve_active_order()
	_travel_main_dialogue_pending = false
	_travel_controller.configure(_game_state, _active_order)
	_refresh_travel_display()


func _queue_travel_main_dialogue_if_needed(phase: GameStateModel.TravelState) -> void:
	if (
		phase != GameStateModel.TravelState.CRUISE
		or _game_state == null
		or _game_state.has_story_flag(TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)
		or _travel_main_dialogue_pending
		or _active_dialogue_context == DialogueContext.TRAVEL_REQUIRED
	):
		return
	if travel_main_dialogue == null:
		push_error("Cockpit travel main dialogue is missing.")
		return
	_travel_main_dialogue_pending = true
	_travel_controller.set_narrative_hold(true)
	call_deferred("_try_start_pending_travel_main_dialogue")


func _try_start_pending_travel_main_dialogue() -> void:
	if not _travel_main_dialogue_pending:
		return
	if (
		_game_state != null
		and _game_state.has_story_flag(TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)
	):
		_travel_main_dialogue_pending = false
		_travel_controller.set_narrative_hold(false)
		return
	if is_input_locked() or _dialogue_ui == null or _dialogue_ui.visible:
		return
	if _start_dialogue_sequence(
		travel_main_dialogue,
		&"lao_pi_seat",
		DialogueContext.TRAVEL_REQUIRED,
		true
	):
		_travel_main_dialogue_pending = false
		return
	_travel_main_dialogue_pending = false
	_travel_controller.set_narrative_hold(false)
	push_error("Cockpit could not start the required travel dialogue.")


func _refresh_travel_display() -> void:
	if _travel_progress_bar == null or _travel_controller == null:
		return
	var phase: GameStateModel.TravelState = _travel_controller.get_phase()
	var should_show: bool = _is_travel_window_passive_phase(phase)
	_set_forward_window_passive(should_show)
	_travel_progress_bar.visible = should_show
	_travel_progress_bar.value = _travel_controller.get_total_progress() * 100.0
	_skip_travel_button.visible = should_show and _travel_controller.can_skip()
	if should_show:
		_refresh_travel_status_text()
	else:
		_refresh_focus_prompt()
	_update_travel_visuals(phase, _travel_controller.get_total_progress())


func _refresh_travel_status_text() -> void:
	if _travel_controller == null:
		return
	var phase: GameStateModel.TravelState = _travel_controller.get_phase()
	_status_label.text = tr(String(_get_travel_phase_key(phase)))
	_prompt_label.text = tr(String(_get_travel_detail_key(phase)))


func _update_travel_visuals(
	phase: GameStateModel.TravelState,
	total_progress: float
) -> void:
	if _travel_progress_bar != null:
		_travel_progress_bar.value = total_progress * 100.0
	if _skip_travel_button != null:
		_skip_travel_button.visible = (
			_is_travel_window_passive_phase(phase)
			and _travel_controller.can_skip()
		)
	if _starfield != null:
		var speed_multiplier: float = TRAVEL_PHASE_SPEEDS.get(phase, 1.0)
		_starfield.set_travel_visuals(total_progress, speed_multiplier)


func _configure_travel_audio() -> void:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.25
	_travel_audio_player.stream = generator


func _configure_radio_audio() -> void:
	_radio_audio_player.stop()
	_radio_audio_player.volume_db = RADIO_VOLUME_DB
	_radio_audio_player.stream = _create_radio_loop()
	_radio_feedback.set_active(false)


func _create_radio_loop() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RADIO_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frame_count: int = maxi(int(RADIO_SAMPLE_RATE * RADIO_LOOP_SECONDS), 1)
	var audio_data: PackedByteArray = PackedByteArray()
	audio_data.resize(frame_count * 2)
	for frame_index: int in frame_count:
		var time_seconds: float = float(frame_index) / float(RADIO_SAMPLE_RATE)
		var hum: float = (
			sin(TAU * 55.0 * time_seconds) * 0.28
			+ sin(TAU * 91.0 * time_seconds) * 0.12
		)
		var texture: float = (
			sin(TAU * 173.0 * time_seconds)
			* sin(TAU * 29.0 * time_seconds)
			* 0.11
		)
		var sample: float = clampf(hum + texture, -0.72, 0.72)
		var encoded_sample: int = int(round(sample * 32767.0)) & 0xffff
		audio_data[frame_index * 2] = encoded_sample & 0xff
		audio_data[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	stream.data = audio_data
	stream.loop_begin = 0
	stream.loop_end = frame_count
	return stream


func _play_travel_phase_cue(phase: GameStateModel.TravelState) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var frequency: float = 0.0
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			frequency = 262.0
		GameStateModel.TravelState.CRUISE:
			frequency = 330.0
		GameStateModel.TravelState.APPROACH:
			frequency = 440.0
		_:
			return
	_travel_audio_player.play()
	var playback: AudioStreamGeneratorPlayback = (
		_travel_audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	)
	if playback == null:
		return
	var sample_rate: float = 22050.0
	var frame_count: int = mini(
		int(sample_rate * TRAVEL_PHASE_CUE_SECONDS),
		playback.get_frames_available()
	)
	for frame_index: int in frame_count:
		var progress: float = float(frame_index) / maxf(float(frame_count - 1), 1.0)
		var envelope: float = sin(progress * PI)
		var sample: float = (
			sin(TAU * frequency * float(frame_index) / sample_rate)
			* TRAVEL_PHASE_CUE_VOLUME
			* envelope
		)
		playback.push_frame(Vector2(sample, sample))


func _resolve_active_order() -> OrderDefinition:
	if _game_state == null or data_registry == null or _game_state.current_order_id.is_empty():
		return null
	return data_registry.find_order(_game_state.current_order_id)


func _get_travel_phase_key(phase: GameStateModel.TravelState) -> StringName:
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			return &"UI_COCKPIT_TRAVEL_PHASE_DEPARTURE"
		GameStateModel.TravelState.CRUISE:
			return &"UI_COCKPIT_TRAVEL_PHASE_CRUISE"
		GameStateModel.TravelState.APPROACH:
			return &"UI_COCKPIT_TRAVEL_PHASE_APPROACH"
		GameStateModel.TravelState.COMPLETED:
			return &"UI_COCKPIT_TRAVEL_PHASE_COMPLETED"
	return &"UI_COCKPIT_TRAVEL_PHASE_IDLE"


func _get_travel_detail_key(phase: GameStateModel.TravelState) -> StringName:
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			return &"UI_COCKPIT_TRAVEL_DETAIL_DEPARTURE"
		GameStateModel.TravelState.CRUISE:
			return &"UI_COCKPIT_TRAVEL_DETAIL_CRUISE"
		GameStateModel.TravelState.APPROACH:
			return &"UI_COCKPIT_TRAVEL_DETAIL_APPROACH"
		GameStateModel.TravelState.COMPLETED:
			return &"UI_COCKPIT_TRAVEL_DETAIL_COMPLETED"
	return &"UI_COCKPIT_TRAVEL_DETAIL_IDLE"


func _get_travel_route_status_key(error: StringName) -> StringName:
	if error.is_empty():
		return &"UI_COCKPIT_NAV_ROUTE_READY"
	match error:
		GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED:
			return &"UI_COCKPIT_NAV_ROUTE_PENDING"
		GameStateModel.TRAVEL_ERROR_ALREADY_STARTED:
			return &"UI_COCKPIT_NAV_ROUTE_ACTIVE"
		GameStateModel.TRAVEL_ERROR_ALREADY_COMPLETED:
			return &"UI_COCKPIT_NAV_ROUTE_COMPLETED"
		GameStateModel.TRAVEL_ERROR_ORDER_NOT_ACTIVE:
			return &"UI_COCKPIT_NAV_ROUTE_NO_ORDER"
	return &"UI_COCKPIT_NAV_ROUTE_UNAVAILABLE"


func _get_company_travel_status_key(phase: GameStateModel.TravelState) -> StringName:
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			return &"UI_COCKPIT_COMPANY_TRAVEL_DEPARTURE"
		GameStateModel.TravelState.CRUISE:
			return &"UI_COCKPIT_COMPANY_TRAVEL_CRUISE"
		GameStateModel.TravelState.APPROACH:
			return &"UI_COCKPIT_COMPANY_TRAVEL_APPROACH"
		GameStateModel.TravelState.COMPLETED:
			return &"UI_COCKPIT_COMPANY_TRAVEL_COMPLETED"
	return &"UI_COCKPIT_COMPANY_TRAVEL_NOTICE"


func _get_travel_error_key(error: StringName) -> StringName:
	match error:
		GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED:
			return &"UI_COCKPIT_TRAVEL_ERROR_PREFLIGHT"
		GameStateModel.TRAVEL_ERROR_DESTINATION_NOT_ALLOWED:
			return &"UI_COCKPIT_TRAVEL_ERROR_DESTINATION"
		GameStateModel.TRAVEL_ERROR_ALREADY_STARTED:
			return &"UI_COCKPIT_TRAVEL_ERROR_ACTIVE"
		GameStateModel.TRAVEL_ERROR_ALREADY_COMPLETED:
			return &"UI_COCKPIT_TRAVEL_ERROR_COMPLETED"
	return &"UI_COCKPIT_TRAVEL_ERROR_NO_ORDER"


func _start_lao_pi_dialogue() -> bool:
	return _start_dialogue_sequence(
		lao_pi_dialogue,
		&"lao_pi_seat",
		DialogueContext.MANUAL_LAO_PI,
		_is_active_travel_phase()
	)


func _start_dialogue_sequence(
	sequence: DialogueSequence,
	hotspot_id: StringName,
	context: DialogueContext,
	hold_travel: bool
) -> bool:
	if sequence == null or _dialogue_ui == null or _game_state == null:
		return false
	if _dialogue_ui.visible or not _begin_modal(hotspot_id):
		return false
	if hold_travel:
		_travel_controller.set_narrative_hold(true)
	_device_dimmer.visible = false
	_device_panel.visible = false
	if not _dialogue_ui.start_dialogue(sequence, _game_state):
		if hold_travel:
			_travel_controller.set_narrative_hold(false)
		_finish_modal()
		return false
	_dialogue_active = true
	_active_dialogue_context = context
	_active_dialogue_id = sequence.id
	_active_dialogue_holds_travel = hold_travel
	return true


func _on_dialogue_finished() -> void:
	if not _dialogue_active:
		return
	var completed_context: DialogueContext = _active_dialogue_context
	var held_travel: bool = _active_dialogue_holds_travel
	var required_dialogue_incomplete: bool = (
		completed_context == DialogueContext.TRAVEL_REQUIRED
		and _game_state != null
		and not _game_state.has_story_flag(TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)
	)
	_dialogue_active = false
	_active_dialogue_context = DialogueContext.NONE
	_active_dialogue_id = &""
	_active_dialogue_holds_travel = false
	if required_dialogue_incomplete:
		_travel_main_dialogue_pending = true
	elif held_travel:
		_travel_controller.set_narrative_hold(false)
	_finish_modal()


func _activate_radio_hotspot() -> bool:
	if not _toggle_radio():
		return false
	if (
		_radio_on
		and _is_active_travel_phase()
		and not _travel_main_dialogue_pending
		and not _is_dialogue_sequence_fully_read(travel_radio_dialogue)
	):
		_start_dialogue_sequence(
			travel_radio_dialogue,
			&"radio",
			DialogueContext.TRAVEL_RADIO,
			true
		)
	return true


func _activate_cargo_hotspot() -> bool:
	if (
		_is_active_travel_phase()
		and not _travel_main_dialogue_pending
		and not _is_dialogue_sequence_fully_read(travel_cargo_dialogue)
	):
		return _start_dialogue_sequence(
			travel_cargo_dialogue,
			&"cargo_indicator",
			DialogueContext.TRAVEL_CARGO,
			true
		)
	return _open_device_panel(&"cargo_indicator")


func _toggle_radio() -> bool:
	_radio_on = not _radio_on
	_radio_feedback.set_active(_radio_on)
	if _radio_on:
		if not _radio_audio_player.playing:
			_radio_audio_player.play()
	else:
		_radio_audio_player.stop()
	var radio_button: Button = _hotspot_buttons.get(&"radio")
	if radio_button != null:
		radio_button.text = _get_hotspot_button_text(&"radio")
	_refresh_focus_prompt()
	radio_state_changed.emit(_radio_on)
	return true


func _is_passive_window_hotspot(hotspot_id: StringName) -> bool:
	return hotspot_id == &"window_view" and _forward_window_passive


func _is_active_travel_phase() -> bool:
	if _travel_controller == null:
		return false
	return _travel_controller.get_phase() in [
		GameStateModel.TravelState.DEPARTURE,
		GameStateModel.TravelState.CRUISE,
		GameStateModel.TravelState.APPROACH,
	]


func _is_dialogue_sequence_fully_read(sequence: DialogueSequence) -> bool:
	if sequence == null or _game_state == null or sequence.lines.is_empty():
		return false
	for line: DialogueLine in sequence.lines:
		if (
			line == null
			or not _game_state.has_read_dialogue_line(sequence.id, line.id)
		):
			return false
	return true


func _is_travel_window_passive() -> bool:
	return (
		_travel_controller != null
		and _is_travel_window_passive_phase(_travel_controller.get_phase())
	)


func _is_travel_window_passive_phase(phase: GameStateModel.TravelState) -> bool:
	return phase in [
		GameStateModel.TravelState.DEPARTURE,
		GameStateModel.TravelState.CRUISE,
		GameStateModel.TravelState.APPROACH,
		GameStateModel.TravelState.COMPLETED,
	]


func _set_forward_window_passive(passive: bool) -> void:
	_forward_window_passive = passive
	var window_button: Button = _hotspot_buttons.get(&"window_view")
	if window_button == null:
		return
	if passive:
		if window_button.has_focus():
			window_button.release_focus()
		if _selected_hotspot_id == &"window_view":
			_selected_hotspot_id = &""
		window_button.focus_mode = Control.FOCUS_NONE
		window_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window_button.visible = false
		return
	window_button.visible = true
	var input_enabled: bool = not is_input_locked()
	window_button.focus_mode = Control.FOCUS_ALL if input_enabled else Control.FOCUS_NONE
	window_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if input_enabled else Control.MOUSE_FILTER_IGNORE
	)


func _observe_window() -> bool:
	var observation_key: StringName = &"UI_COCKPIT_WINDOW_OBSERVATION"
	if _game_state != null:
		match _game_state.travel_state:
			GameStateModel.TravelState.DEPARTURE:
				observation_key = &"UI_COCKPIT_WINDOW_DEPARTURE"
			GameStateModel.TravelState.CRUISE:
				observation_key = &"UI_COCKPIT_WINDOW_CRUISE"
			GameStateModel.TravelState.APPROACH:
				observation_key = &"UI_COCKPIT_WINDOW_APPROACH"
	_show_notification(observation_key)
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
	_device_action_button.visible = false
	_device_dimmer.visible = false
	_modal_layer.visible = false
	_set_hotspot_input_enabled(true)
	_refresh_focus_prompt()
	if not return_hotspot_id.is_empty():
		call_deferred("focus_hotspot", return_hotspot_id)
	if _travel_main_dialogue_pending:
		call_deferred("_try_start_pending_travel_main_dialogue")


func _set_hotspot_input_enabled(enabled: bool) -> void:
	for hotspot_id: StringName in HOTSPOT_IDS:
		var button: Button = _hotspot_buttons.get(hotspot_id)
		if button == null:
			continue
		var hotspot_enabled: bool = (
			enabled
			and not (hotspot_id == &"window_view" and _forward_window_passive)
		)
		if not hotspot_enabled and button.has_focus():
			button.release_focus()
		button.focus_mode = Control.FOCUS_ALL if hotspot_enabled else Control.FOCUS_NONE
		button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if hotspot_enabled
			else Control.MOUSE_FILTER_IGNORE
		)
		if hotspot_id == &"window_view":
			button.visible = not _forward_window_passive


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
