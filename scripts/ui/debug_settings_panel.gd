class_name DebugSettingsPanel
extends PanelContainer

var settings_service_override: SettingsServiceModel

var slow_motion_button: CheckButton
var route_hints_button: CheckButton
var high_contrast_button: CheckButton
var assist_strength_label: Label
var assist_strength_slider: HSlider
var feedback_label: Label

var _settings_service: SettingsServiceModel
var _syncing_controls: bool = false
var _controls_initialized: bool = false


func _ready() -> void:
	initialize()


## Initializes the debug-only control surface and allows isolated smoke tests to inject local storage.
func initialize() -> bool:
	if not _initialize_controls():
		return false
	var requested_service: SettingsServiceModel = settings_service_override
	if requested_service == null and is_inside_tree():
		requested_service = get_node_or_null("/root/SettingsService") as SettingsServiceModel
	if requested_service != _settings_service:
		_disconnect_settings_service()
		_settings_service = requested_service
	if _settings_service == null:
		_set_controls_enabled(false)
		feedback_label.text = tr("UI_DEBUG_SETTINGS_UNAVAILABLE")
		return false
	_set_controls_enabled(true)
	if not _settings_service.settings_changed.is_connected(_sync_controls):
		_settings_service.settings_changed.connect(_sync_controls)
	_sync_controls()
	return true


func _exit_tree() -> void:
	_disconnect_settings_service()


func _disconnect_settings_service() -> void:
	if _settings_service == null:
		return
	if _settings_service.settings_changed.is_connected(_sync_controls):
		_settings_service.settings_changed.disconnect(_sync_controls)
	_settings_service = null


func _initialize_controls() -> bool:
	if _controls_initialized:
		return true
	slow_motion_button = get_node_or_null("Margin/Content/SlowMotionButton") as CheckButton
	route_hints_button = get_node_or_null("Margin/Content/RouteHintsButton") as CheckButton
	high_contrast_button = get_node_or_null("Margin/Content/HighContrastButton") as CheckButton
	assist_strength_label = get_node_or_null("Margin/Content/AssistStrengthLabel") as Label
	assist_strength_slider = get_node_or_null(
		"Margin/Content/AssistStrengthSlider"
	) as HSlider
	feedback_label = get_node_or_null("Margin/Content/FeedbackLabel") as Label
	if (
		slow_motion_button == null
		or route_hints_button == null
		or high_contrast_button == null
		or assist_strength_label == null
		or assist_strength_slider == null
		or feedback_label == null
	):
		return false
	slow_motion_button.toggled.connect(_on_slow_motion_toggled)
	route_hints_button.toggled.connect(_on_route_hints_toggled)
	high_contrast_button.toggled.connect(_on_high_contrast_toggled)
	assist_strength_slider.value_changed.connect(_on_assist_strength_changed)
	_controls_initialized = true
	return true


func _sync_controls() -> void:
	if _settings_service == null:
		return
	_syncing_controls = true
	slow_motion_button.button_pressed = _settings_service.settings.slow_motion_assist
	route_hints_button.button_pressed = _settings_service.settings.route_hints_enabled
	high_contrast_button.button_pressed = _settings_service.settings.high_contrast_terrain
	assist_strength_slider.value = _settings_service.settings.flight_assist_strength * 100.0
	_update_assist_strength_label()
	_syncing_controls = false


func _on_slow_motion_toggled(enabled: bool) -> void:
	if _syncing_controls or _settings_service == null:
		return
	_show_toggle_result(
		_settings_service.set_slow_motion_assist(enabled),
		"UI_DEBUG_SLOW_MOTION",
		enabled
	)


func _on_route_hints_toggled(enabled: bool) -> void:
	if _syncing_controls or _settings_service == null:
		return
	_show_toggle_result(
		_settings_service.set_route_hints_enabled(enabled),
		"UI_DEBUG_ROUTE_HINTS",
		enabled
	)


func _on_high_contrast_toggled(enabled: bool) -> void:
	if _syncing_controls or _settings_service == null:
		return
	_show_toggle_result(
		_settings_service.set_high_contrast_terrain(enabled),
		"UI_DEBUG_HIGH_CONTRAST",
		enabled
	)


func _on_assist_strength_changed(value: float) -> void:
	if _syncing_controls or _settings_service == null:
		return
	var saved: bool = _settings_service.set_flight_assist_strength(value / 100.0)
	_update_assist_strength_label()
	if saved:
		feedback_label.text = tr("UI_DEBUG_SETTINGS_SAVED") % assist_strength_label.text
	else:
		feedback_label.text = tr("UI_DEBUG_SETTINGS_SAVE_FAILED")


func _show_toggle_result(saved: bool, label_key: String, enabled: bool) -> void:
	if not saved:
		feedback_label.text = tr("UI_DEBUG_SETTINGS_SAVE_FAILED")
		return
	var state_key: String = "UI_DEBUG_SETTING_OFF"
	if enabled:
		state_key = "UI_DEBUG_SETTING_ON"
	var changed_setting: String = "%s · %s" % [tr(label_key), tr(state_key)]
	feedback_label.text = tr("UI_DEBUG_SETTINGS_SAVED") % changed_setting


func _update_assist_strength_label() -> void:
	assist_strength_label.text = "%s: %d%%" % [
		tr("UI_DEBUG_FLIGHT_ASSIST"),
		roundi(assist_strength_slider.value),
	]


func _set_controls_enabled(enabled: bool) -> void:
	slow_motion_button.disabled = not enabled
	route_hints_button.disabled = not enabled
	high_contrast_button.disabled = not enabled
	assist_strength_slider.editable = enabled
