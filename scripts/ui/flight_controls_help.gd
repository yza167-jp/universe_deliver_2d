class_name FlightControlsHelp
extends Control

signal close_requested

@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _core_controls_label: Label = %CoreControlsLabel
@onready var _laser_state_label: Label = %LaserStateLabel
@onready var _test_section: VBoxContainer = %TestSection
@onready var _test_heading_label: Label = %TestHeadingLabel
@onready var _test_controls_label: Label = %TestControlsLabel
@onready var _start_button: Button = %StartButton

var _direct_test_mode: bool = false
var _laser_installed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _start_button != null and not _start_button.pressed.is_connected(
		_on_start_button_pressed
	):
		_start_button.pressed.connect(_on_start_button_pressed)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func show_help(direct_test_mode: bool, laser_installed: bool) -> void:
	_direct_test_mode = direct_test_mode
	_laser_installed = laser_installed
	visible = true
	refresh()
	if _start_button != null:
		_start_button.grab_focus()


func hide_help() -> void:
	visible = false


func set_laser_installed(installed: bool) -> void:
	_laser_installed = installed
	refresh()


func is_direct_test_mode() -> bool:
	return _direct_test_mode


func is_laser_installed() -> bool:
	return _laser_installed


func get_core_controls_text() -> String:
	return "" if _core_controls_label == null else _core_controls_label.text


func get_test_controls_text() -> String:
	return "" if _test_controls_label == null else _test_controls_label.text


func get_laser_state_text() -> String:
	return "" if _laser_state_label == null else _laser_state_label.text


func refresh() -> void:
	if not is_node_ready():
		return
	_title_label.text = tr("UI_FLIGHT_CONTROLS_TITLE")
	_intro_label.text = tr("UI_FLIGHT_CONTROLS_INTRO")
	_core_controls_label.text = tr("UI_FLIGHT_CONTROLS_CORE").replace("\\n", "\n")
	var laser_state_key: StringName = (
		&"UI_FLIGHT_CONTROLS_LASER_INSTALLED"
		if _laser_installed
		else &"UI_FLIGHT_CONTROLS_LASER_UNINSTALLED"
	)
	_laser_state_label.text = tr(laser_state_key)
	_test_section.visible = _direct_test_mode
	_test_heading_label.text = tr("UI_FLIGHT_CONTROLS_TEST_HEADING")
	_test_controls_label.text = tr("UI_FLIGHT_CONTROLS_TEST").replace("\\n", "\n")
	_start_button.text = tr("UI_FLIGHT_CONTROLS_START")


func _on_start_button_pressed() -> void:
	close_requested.emit()
