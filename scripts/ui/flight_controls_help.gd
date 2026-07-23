class_name FlightControlsHelp
extends Control

signal close_requested

@onready var _title_label: Label = %TitleLabel
@onready var _intro_label: Label = %IntroLabel
@onready var _core_controls_label: Label = %CoreControlsLabel
@onready var _laser_state_label: Label = %LaserStateLabel
@onready var _assist_heading_label: Label = %AssistHeadingLabel
@onready var _route_hints_button: CheckButton = %RouteHintsButton
@onready var _high_contrast_button: CheckButton = %HighContrastButton
@onready var _settings_feedback_label: Label = %SettingsFeedbackLabel
@onready var _test_section: VBoxContainer = %TestSection
@onready var _test_heading_label: Label = %TestHeadingLabel
@onready var _test_controls_label: Label = %TestControlsLabel
@onready var _start_button: Button = %StartButton

var _direct_test_mode: bool = false
var _laser_installed: bool = false
var _settings_service: SettingsServiceModel
var _syncing_settings_controls: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _start_button != null and not _start_button.pressed.is_connected(
		_on_start_button_pressed
	):
		_start_button.pressed.connect(_on_start_button_pressed)
	if not _route_hints_button.toggled.is_connected(_on_route_hints_toggled):
		_route_hints_button.toggled.connect(_on_route_hints_toggled)
	if not _high_contrast_button.toggled.is_connected(_on_high_contrast_toggled):
		_high_contrast_button.toggled.connect(_on_high_contrast_toggled)
	if _settings_service == null:
		bind_settings_service(
			get_node_or_null("/root/SettingsService") as SettingsServiceModel
		)
	refresh()


func _exit_tree() -> void:
	_disconnect_settings_service()


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


func bind_settings_service(settings_service: SettingsServiceModel) -> void:
	if settings_service == _settings_service:
		_sync_accessibility_controls()
		return
	_disconnect_settings_service()
	_settings_service = settings_service
	if (
		_settings_service != null
		and not _settings_service.settings_changed.is_connected(
			_sync_accessibility_controls
		)
	):
		_settings_service.settings_changed.connect(_sync_accessibility_controls)
	_sync_accessibility_controls()


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


func get_route_hints_button() -> CheckButton:
	return _route_hints_button


func get_high_contrast_button() -> CheckButton:
	return _high_contrast_button


func get_settings_feedback_text() -> String:
	return "" if _settings_feedback_label == null else _settings_feedback_label.text


func is_route_hints_enabled() -> bool:
	return _route_hints_button != null and _route_hints_button.button_pressed


func is_high_contrast_enabled() -> bool:
	return _high_contrast_button != null and _high_contrast_button.button_pressed


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
	_assist_heading_label.text = tr("UI_FLIGHT_CONTROLS_ASSIST_HEADING")
	_sync_accessibility_controls()
	_settings_feedback_label.text = tr(
		"UI_FLIGHT_CONTROLS_SETTINGS_READY"
		if _settings_service != null
		else "UI_FLIGHT_CONTROLS_SETTINGS_UNAVAILABLE"
	)
	_test_section.visible = _direct_test_mode
	_test_heading_label.text = tr("UI_FLIGHT_CONTROLS_TEST_HEADING")
	_test_controls_label.text = tr("UI_FLIGHT_CONTROLS_TEST").replace("\\n", "\n")
	_start_button.text = tr("UI_FLIGHT_CONTROLS_START")


func _on_start_button_pressed() -> void:
	close_requested.emit()


func _on_route_hints_toggled(enabled: bool) -> void:
	if _syncing_settings_controls or _settings_service == null:
		return
	_show_setting_result(
		_settings_service.set_route_hints_enabled(enabled),
		&"UI_FLIGHT_CONTROLS_ROUTE_HINTS",
		enabled
	)


func _on_high_contrast_toggled(enabled: bool) -> void:
	if _syncing_settings_controls or _settings_service == null:
		return
	_show_setting_result(
		_settings_service.set_high_contrast_terrain(enabled),
		&"UI_FLIGHT_CONTROLS_HIGH_CONTRAST",
		enabled
	)


func _sync_accessibility_controls() -> void:
	if not is_node_ready():
		return
	_syncing_settings_controls = true
	var route_hints_enabled: bool = LocalSettingsData.DEFAULT_ROUTE_HINTS_ENABLED
	var high_contrast_enabled: bool = LocalSettingsData.DEFAULT_HIGH_CONTRAST_TERRAIN
	if _settings_service != null:
		route_hints_enabled = _settings_service.settings.route_hints_enabled
		high_contrast_enabled = _settings_service.settings.high_contrast_terrain
	_route_hints_button.button_pressed = route_hints_enabled
	_high_contrast_button.button_pressed = high_contrast_enabled
	_route_hints_button.disabled = _settings_service == null
	_high_contrast_button.disabled = _settings_service == null
	_route_hints_button.text = _format_setting_label(
		&"UI_FLIGHT_CONTROLS_ROUTE_HINTS",
		route_hints_enabled
	)
	_high_contrast_button.text = _format_setting_label(
		&"UI_FLIGHT_CONTROLS_HIGH_CONTRAST",
		high_contrast_enabled
	)
	_syncing_settings_controls = false


func _format_setting_label(label_key: StringName, enabled: bool) -> String:
	return tr("UI_FLIGHT_CONTROLS_SETTING_FORMAT") % [
		tr(label_key),
		tr(
			"UI_FLIGHT_CONTROLS_SETTING_ON"
			if enabled
			else "UI_FLIGHT_CONTROLS_SETTING_OFF"
		),
	]


func _show_setting_result(
	saved: bool,
	label_key: StringName,
	enabled: bool
) -> void:
	if not saved:
		_settings_feedback_label.text = tr("UI_FLIGHT_CONTROLS_SETTING_SAVE_FAILED")
		return
	_settings_feedback_label.text = tr("UI_FLIGHT_CONTROLS_SETTING_SAVED") % [
		tr(label_key),
		tr(
			"UI_FLIGHT_CONTROLS_SETTING_ON"
			if enabled
			else "UI_FLIGHT_CONTROLS_SETTING_OFF"
		),
	]


func _disconnect_settings_service() -> void:
	if _settings_service == null:
		return
	if _settings_service.settings_changed.is_connected(_sync_accessibility_controls):
		_settings_service.settings_changed.disconnect(_sync_accessibility_controls)
	_settings_service = null
