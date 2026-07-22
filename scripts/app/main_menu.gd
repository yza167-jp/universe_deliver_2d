class_name MainMenu
extends Control

signal new_game_started
signal continued_game_started

@onready var _title_label: Label = %TitleLabel
@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _brief_label: Label = %BriefLabel
@onready var _controls_label: Label = %ControlsLabel
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _status_label: Label = %StatusLabel

var scene_router_override: SceneRouterService
var save_service_override: SaveServiceModel
var last_error: String = ""
var _status_message_key: StringName = &""


func _ready() -> void:
	_localize_content()
	if not _start_button.pressed.is_connected(_on_start_button_pressed):
		_start_button.pressed.connect(_on_start_button_pressed)
	if not _continue_button.pressed.is_connected(_on_continue_button_pressed):
		_continue_button.pressed.connect(_on_continue_button_pressed)
	_refresh_save_status()
	if _continue_button.disabled:
		_start_button.call_deferred("grab_focus")
	else:
		_continue_button.call_deferred("grab_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_localize_content()


func start_new_game() -> bool:
	last_error = ""
	var scene_router: SceneRouterService = _resolve_scene_router()
	var save_service: SaveServiceModel = _resolve_save_service()
	if scene_router == null or save_service == null:
		last_error = "Required runtime services are unavailable."
		_show_status(&"UI_MAIN_MENU_START_UNAVAILABLE")
		return false

	_set_actions_disabled(true)
	_hide_status()
	if not save_service.start_new_game():
		last_error = save_service.last_error
		_set_actions_disabled(false)
		_refresh_save_status(&"UI_MAIN_MENU_START_UNAVAILABLE")
		_start_button.grab_focus()
		return false
	if not scene_router.request_stage(SceneRouterService.Stage.STATION):
		last_error = scene_router.last_error
		_set_actions_disabled(false)
		_show_status(&"UI_MAIN_MENU_START_UNAVAILABLE")
		_start_button.grab_focus()
		return false

	new_game_started.emit()
	return true


func continue_game() -> bool:
	last_error = ""
	var scene_router: SceneRouterService = _resolve_scene_router()
	var save_service: SaveServiceModel = _resolve_save_service()
	if scene_router == null or save_service == null:
		last_error = "Required runtime services are unavailable."
		_show_status(&"UI_MAIN_MENU_CONTINUE_FAILED")
		return false
	_set_actions_disabled(true)
	_hide_status()
	if not save_service.load_progress():
		last_error = save_service.last_error
		_set_actions_disabled(false)
		_refresh_save_status(&"UI_MAIN_MENU_CONTINUE_FAILED")
		_continue_button.grab_focus()
		return false
	if not scene_router.request_stage(SceneRouterService.Stage.STATION):
		last_error = scene_router.last_error
		_set_actions_disabled(false)
		_show_status(&"UI_MAIN_MENU_CONTINUE_FAILED")
		_continue_button.grab_focus()
		return false
	continued_game_started.emit()
	return true


func get_panel_rect() -> Rect2:
	var panel: PanelContainer = get_node_or_null("MenuPanel") as PanelContainer
	return Rect2() if panel == null else panel.get_global_rect()


func get_title_text() -> String:
	return "" if _title_label == null else _title_label.text


func get_brief_text() -> String:
	return "" if _brief_label == null else _brief_label.text


func get_controls_text() -> String:
	return "" if _controls_label == null else _controls_label.text


func get_start_button_text() -> String:
	return "" if _start_button == null else _start_button.text


func get_start_button_rect() -> Rect2:
	return Rect2() if _start_button == null else _start_button.get_global_rect()


func get_continue_button_text() -> String:
	return "" if _continue_button == null else _continue_button.text


func get_continue_button_rect() -> Rect2:
	return Rect2() if _continue_button == null else _continue_button.get_global_rect()


func is_continue_button_enabled() -> bool:
	return _continue_button != null and not _continue_button.disabled


func get_status_text() -> String:
	return "" if _status_label == null else _status_label.text


func get_status_rect() -> Rect2:
	return Rect2() if _status_label == null else _status_label.get_global_rect()


func is_status_visible() -> bool:
	return _status_label != null and _status_label.visible


func is_start_button_focused() -> bool:
	return _start_button != null and _start_button.has_focus()


func is_continue_button_focused() -> bool:
	return _continue_button != null and _continue_button.has_focus()


func _on_start_button_pressed() -> void:
	start_new_game()


func _on_continue_button_pressed() -> void:
	continue_game()


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _resolve_save_service() -> SaveServiceModel:
	if save_service_override != null:
		return save_service_override
	return get_node_or_null("/root/SaveService") as SaveServiceModel


func _refresh_save_status(override_message_key: StringName = &"") -> void:
	var save_service: SaveServiceModel = _resolve_save_service()
	if save_service == null:
		_continue_button.disabled = true
		_show_status(
			override_message_key
			if not override_message_key.is_empty()
			else &"UI_MAIN_MENU_SAVE_UNREADABLE"
		)
		return
	var save_availability: SaveServiceModel.SaveAvailability = (
		save_service.refresh_save_availability()
	)
	_continue_button.disabled = save_availability not in [
		SaveServiceModel.SaveAvailability.PRIMARY,
		SaveServiceModel.SaveAvailability.BACKUP,
	]
	if not override_message_key.is_empty():
		_show_status(override_message_key)
		return
	match save_availability:
		SaveServiceModel.SaveAvailability.NONE:
			_show_status(&"UI_MAIN_MENU_NO_SAVE")
		SaveServiceModel.SaveAvailability.BACKUP:
			_show_status(&"UI_MAIN_MENU_BACKUP_RECOVERY")
		SaveServiceModel.SaveAvailability.INVALID:
			_show_status(&"UI_MAIN_MENU_SAVE_UNREADABLE")
		SaveServiceModel.SaveAvailability.PRIMARY:
			if save_service.last_warning_code == SaveServiceModel.WARNING_SCHEMA_MIGRATED:
				_show_status(&"UI_MAIN_MENU_SAVE_MIGRATED")
			else:
				_hide_status()


func _set_actions_disabled(disabled: bool) -> void:
	_start_button.disabled = disabled
	_continue_button.disabled = disabled


func _show_status(message_key: StringName) -> void:
	_status_message_key = message_key
	_status_label.text = tr(String(message_key))
	_status_label.visible = true


func _hide_status() -> void:
	_status_message_key = &""
	_status_label.text = ""
	_status_label.visible = false


func _localize_content() -> void:
	_title_label.text = tr("UI_BOOTSTRAP_TITLE")
	_eyebrow_label.text = tr("UI_MAIN_MENU_EYEBROW")
	_brief_label.text = tr("UI_MAIN_MENU_BRIEF")
	_controls_label.text = tr("UI_MAIN_MENU_CONTROLS")
	_start_button.text = tr("UI_MAIN_MENU_NEW_GAME")
	_continue_button.text = tr("UI_MAIN_MENU_CONTINUE_GAME")
	if not _status_message_key.is_empty():
		_status_label.text = tr(String(_status_message_key))
