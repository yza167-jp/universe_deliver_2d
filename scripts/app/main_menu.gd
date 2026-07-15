class_name MainMenu
extends Control

signal new_game_started

@onready var _title_label: Label = %TitleLabel
@onready var _eyebrow_label: Label = %EyebrowLabel
@onready var _brief_label: Label = %BriefLabel
@onready var _controls_label: Label = %ControlsLabel
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel

var game_state_override: GameStateModel
var scene_router_override: SceneRouterService
var last_error: String = ""


func _ready() -> void:
	_localize_content()
	_status_label.visible = false
	if not _start_button.pressed.is_connected(_on_start_button_pressed):
		_start_button.pressed.connect(_on_start_button_pressed)
	_start_button.call_deferred("grab_focus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_localize_content()


func start_new_game() -> bool:
	last_error = ""
	var game_state: GameStateModel = _resolve_game_state()
	var scene_router: SceneRouterService = _resolve_scene_router()
	if game_state == null or scene_router == null:
		last_error = "Required runtime services are unavailable."
		_show_start_error()
		return false

	_start_button.disabled = true
	_status_label.visible = false
	game_state.reset_runtime_state()
	if not scene_router.request_stage(SceneRouterService.Stage.STATION):
		last_error = scene_router.last_error
		_start_button.disabled = false
		_show_start_error()
		_start_button.grab_focus()
		return false

	new_game_started.emit()
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


func is_start_button_focused() -> bool:
	return _start_button != null and _start_button.has_focus()


func _on_start_button_pressed() -> void:
	start_new_game()


func _resolve_game_state() -> GameStateModel:
	if game_state_override != null:
		return game_state_override
	return get_node_or_null("/root/GameState") as GameStateModel


func _resolve_scene_router() -> SceneRouterService:
	if scene_router_override != null:
		return scene_router_override
	return get_node_or_null("/root/SceneRouter") as SceneRouterService


func _show_start_error() -> void:
	_status_label.text = tr("UI_MAIN_MENU_START_UNAVAILABLE")
	_status_label.visible = true


func _localize_content() -> void:
	_title_label.text = tr("UI_BOOTSTRAP_TITLE")
	_eyebrow_label.text = tr("UI_MAIN_MENU_EYEBROW")
	_brief_label.text = tr("UI_MAIN_MENU_BRIEF")
	_controls_label.text = tr("UI_MAIN_MENU_CONTROLS")
	_start_button.text = tr("UI_MAIN_MENU_NEW_GAME")
	if _status_label.visible:
		_status_label.text = tr("UI_MAIN_MENU_START_UNAVAILABLE")
