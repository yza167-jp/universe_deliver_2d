class_name SettingsServiceModel
extends Node

signal settings_changed
signal assist_option_changed(option_id: StringName, enabled: bool)
signal input_binding_changed(action: StringName)

const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"
const INPUT_SECTION: String = "input"

const SLOW_MOTION_ASSIST: StringName = &"slow_motion_assist"
const ROUTE_HINTS_ENABLED: StringName = &"route_hints_enabled"
const HIGH_CONTRAST_TERRAIN: StringName = &"high_contrast_terrain"

const SUPPORTED_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"interact",
	&"toggle_fullscreen",
	&"flight_throttle",
	&"flight_brake",
	&"flight_pitch_up",
	&"flight_pitch_down",
	&"flight_boost",
	&"flight_fire",
	&"delivery_drop",
	&"flight_restart",
	&"flight_controls_help",
	&"flight_route_hint",
	&"flight_debug_toggle",
	&"flight_environment_cycle",
	&"flight_assist_cycle",
	&"flight_laser_toggle",
	&"pause",
]

var settings: LocalSettingsData = LocalSettingsData.new()
var storage_path: String = DEFAULT_SETTINGS_PATH
var last_error: String = ""


func _ready() -> void:
	if not load_settings():
		push_warning("Local settings could not be loaded: %s" % last_error)


func load_settings() -> bool:
	last_error = ""
	settings.reset_to_defaults()
	_apply_default_input_bindings()

	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(storage_path)
	if load_error == ERR_FILE_NOT_FOUND:
		_apply_runtime_settings()
		settings_changed.emit()
		return save_settings()
	if load_error != OK:
		last_error = "Could not load %s (error %d)." % [storage_path, load_error]
		return false

	settings.read_from_config(config, SETTINGS_SECTION)
	var migrated_legacy_flight_lab_bindings: bool = _load_input_bindings(config)
	_apply_runtime_settings()
	settings_changed.emit()
	if migrated_legacy_flight_lab_bindings:
		return save_settings()
	return true


func save_settings() -> bool:
	last_error = ""
	var config: ConfigFile = ConfigFile.new()
	settings.sanitize()
	settings.write_to_config(config, SETTINGS_SECTION)
	_write_input_bindings(config)
	var save_error: Error = config.save(storage_path)
	if save_error != OK:
		last_error = "Could not save %s (error %d)." % [storage_path, save_error]
		return false
	return true


func set_master_volume(value: float) -> bool:
	var sanitized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(settings.master_volume, sanitized_value):
		return true
	settings.master_volume = sanitized_value
	_apply_runtime_settings()
	settings_changed.emit()
	return save_settings()


func set_music_volume(value: float) -> bool:
	var sanitized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(settings.music_volume, sanitized_value):
		return true
	settings.music_volume = sanitized_value
	settings_changed.emit()
	return save_settings()


func set_sfx_volume(value: float) -> bool:
	var sanitized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(settings.sfx_volume, sanitized_value):
		return true
	settings.sfx_volume = sanitized_value
	settings_changed.emit()
	return save_settings()


func set_screen_shake_strength(value: float) -> bool:
	var sanitized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(settings.screen_shake_strength, sanitized_value):
		return true
	settings.screen_shake_strength = sanitized_value
	settings_changed.emit()
	return save_settings()


func set_text_speed(value: float) -> bool:
	var sanitized_value: float = clampf(
		value,
		LocalSettingsData.MIN_TEXT_SPEED,
		LocalSettingsData.MAX_TEXT_SPEED
	)
	if is_equal_approx(settings.text_speed, sanitized_value):
		return true
	settings.text_speed = sanitized_value
	settings_changed.emit()
	return save_settings()


func set_flight_assist_strength(value: float) -> bool:
	var sanitized_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(settings.flight_assist_strength, sanitized_value):
		return true
	settings.flight_assist_strength = sanitized_value
	settings_changed.emit()
	return save_settings()


func set_slow_motion_assist(enabled: bool) -> bool:
	return _set_assist_option(SLOW_MOTION_ASSIST, enabled)


func set_route_hints_enabled(enabled: bool) -> bool:
	return _set_assist_option(ROUTE_HINTS_ENABLED, enabled)


func set_high_contrast_terrain(enabled: bool) -> bool:
	return _set_assist_option(HIGH_CONTRAST_TERRAIN, enabled)


func set_action_events(action: StringName, events: Array[InputEvent]) -> bool:
	last_error = ""
	if not SUPPORTED_ACTIONS.has(action):
		last_error = "Unsupported input action: %s" % action
		return false
	for event: InputEvent in events:
		if not _is_supported_input_event(event):
			last_error = "Only keyboard and mouse-button bindings are supported in M0."
			return false
	_apply_action_events(action, events)
	input_binding_changed.emit(action)
	return save_settings()


func reset_action_to_default(action: StringName) -> bool:
	last_error = ""
	if not SUPPORTED_ACTIONS.has(action):
		last_error = "Unsupported input action: %s" % action
		return false
	_apply_action_events(action, _build_default_events(action))
	input_binding_changed.emit(action)
	return save_settings()


func reset_input_map_to_defaults(save_after_reset: bool = true) -> bool:
	_apply_default_input_bindings()
	for action: StringName in SUPPORTED_ACTIONS:
		input_binding_changed.emit(action)
	if save_after_reset:
		return save_settings()
	return true


static func get_supported_actions() -> Array[StringName]:
	return SUPPORTED_ACTIONS.duplicate()


func _set_assist_option(option_id: StringName, enabled: bool) -> bool:
	var previous_value: bool = false
	match option_id:
		SLOW_MOTION_ASSIST:
			previous_value = settings.slow_motion_assist
			settings.slow_motion_assist = enabled
		ROUTE_HINTS_ENABLED:
			previous_value = settings.route_hints_enabled
			settings.route_hints_enabled = enabled
		HIGH_CONTRAST_TERRAIN:
			previous_value = settings.high_contrast_terrain
			settings.high_contrast_terrain = enabled
		_:
			last_error = "Unsupported assist option: %s" % option_id
			return false
	if previous_value == enabled:
		return true
	settings_changed.emit()
	assist_option_changed.emit(option_id, enabled)
	return save_settings()


func _apply_runtime_settings() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	var master_db: float = -80.0
	if settings.master_volume > 0.0:
		master_db = linear_to_db(settings.master_volume)
	AudioServer.set_bus_volume_db(master_bus_index, master_db)


func _apply_default_input_bindings() -> void:
	for action: StringName in SUPPORTED_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_apply_action_events(action, _build_default_events(action))


func _apply_action_events(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _load_input_bindings(config: ConfigFile) -> bool:
	var migrated_legacy_flight_lab_bindings: bool = false
	for action: StringName in SUPPORTED_ACTIONS:
		var action_key: String = String(action)
		if not config.has_section_key(INPUT_SECTION, action_key):
			continue
		var stored_value: Variant = config.get_value(INPUT_SECTION, action_key)
		if not stored_value is Array:
			continue
		var stored_events: Array = stored_value as Array
		var events: Array[InputEvent] = []
		var all_events_valid: bool = true
		for stored_event: Variant in stored_events:
			if not stored_event is Dictionary:
				all_events_valid = false
				break
			var input_event: InputEvent = _deserialize_event(stored_event as Dictionary)
			if input_event == null:
				all_events_valid = false
				break
			events.append(input_event)
		if not all_events_valid:
			continue
		if _is_legacy_flight_lab_default(action, events):
			_apply_action_events(action, _build_default_events(action))
			migrated_legacy_flight_lab_bindings = true
		else:
			_apply_action_events(action, events)
	return migrated_legacy_flight_lab_bindings


func _write_input_bindings(config: ConfigFile) -> void:
	for action: StringName in SUPPORTED_ACTIONS:
		var stored_events: Array[Dictionary] = []
		for input_event: InputEvent in InputMap.action_get_events(action):
			var stored_event: Dictionary[String, Variant] = _serialize_event(input_event)
			if not stored_event.is_empty():
				stored_events.append(stored_event)
		config.set_value(INPUT_SECTION, String(action), stored_events)


func _serialize_event(input_event: InputEvent) -> Dictionary[String, Variant]:
	var stored_event: Dictionary[String, Variant] = {}
	if input_event is InputEventKey:
		var key_event: InputEventKey = input_event as InputEventKey
		stored_event["type"] = "key"
		stored_event["keycode"] = int(key_event.keycode)
		stored_event["physical_keycode"] = int(key_event.physical_keycode)
		stored_event["shift_pressed"] = key_event.shift_pressed
		stored_event["alt_pressed"] = key_event.alt_pressed
		stored_event["ctrl_pressed"] = key_event.ctrl_pressed
		stored_event["meta_pressed"] = key_event.meta_pressed
	elif input_event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
		stored_event["type"] = "mouse_button"
		stored_event["button_index"] = int(mouse_event.button_index)
	return stored_event


func _deserialize_event(stored_event: Dictionary) -> InputEvent:
	var event_type: String = String(stored_event.get("type", ""))
	if event_type == "key":
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = int(stored_event.get("keycode", 0))
		key_event.physical_keycode = int(stored_event.get("physical_keycode", 0))
		key_event.shift_pressed = bool(stored_event.get("shift_pressed", false))
		key_event.alt_pressed = bool(stored_event.get("alt_pressed", false))
		key_event.ctrl_pressed = bool(stored_event.get("ctrl_pressed", false))
		key_event.meta_pressed = bool(stored_event.get("meta_pressed", false))
		return key_event
	if event_type == "mouse_button":
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = int(stored_event.get("button_index", MOUSE_BUTTON_NONE))
		if mouse_event.button_index == MOUSE_BUTTON_NONE:
			return null
		return mouse_event
	return null


func _is_supported_input_event(input_event: InputEvent) -> bool:
	return input_event is InputEventKey or input_event is InputEventMouseButton


static func _build_default_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match action:
		&"move_up", &"flight_throttle":
			events.append(_create_key_event(KEY_W, true))
		&"move_down", &"flight_brake":
			events.append(_create_key_event(KEY_S, true))
		&"move_left":
			events.append(_create_key_event(KEY_A, true))
		&"move_right":
			events.append(_create_key_event(KEY_D, true))
		&"interact":
			events.append(_create_key_event(KEY_E, true))
		&"toggle_fullscreen":
			events.append(_create_key_event(KEY_F11))
		&"flight_pitch_up":
			events.append(_create_key_event(KEY_UP))
		&"flight_pitch_down":
			events.append(_create_key_event(KEY_DOWN))
		&"flight_boost":
			events.append(_create_key_event(KEY_SHIFT))
		&"flight_fire":
			events.append(_create_key_event(KEY_F, true))
			events.append(_create_mouse_button_event(MOUSE_BUTTON_LEFT))
		&"delivery_drop":
			events.append(_create_key_event(KEY_E, true))
			events.append(_create_mouse_button_event(MOUSE_BUTTON_RIGHT))
		&"flight_restart":
			events.append(_create_key_event(KEY_R, true))
		&"flight_controls_help":
			events.append(_create_key_event(KEY_C, true))
		&"flight_route_hint":
			events.append(_create_key_event(KEY_TAB))
		&"flight_debug_toggle":
			events.append(_create_key_event(KEY_H, true))
		&"flight_environment_cycle":
			events.append(_create_key_event(KEY_V, true))
		&"flight_assist_cycle":
			events.append(_create_key_event(KEY_G, true))
		&"flight_laser_toggle":
			events.append(_create_key_event(KEY_L, true))
		&"pause":
			events.append(_create_key_event(KEY_ESCAPE))
	return events


static func _is_legacy_flight_lab_default(
	action: StringName,
	events: Array[InputEvent]
) -> bool:
	if events.size() != 1 or not events[0] is InputEventKey:
		return false
	var legacy_key: Key = KEY_NONE
	match action:
		&"flight_debug_toggle":
			legacy_key = KEY_F3
		&"flight_environment_cycle":
			legacy_key = KEY_F4
		&"flight_assist_cycle":
			legacy_key = KEY_F5
		&"flight_laser_toggle":
			legacy_key = KEY_F6
		_:
			return false
	var key_event: InputEventKey = events[0] as InputEventKey
	return (
		key_event.keycode == legacy_key
		or key_event.physical_keycode == legacy_key
	)


static func _create_key_event(keycode: Key, use_physical_key: bool = false) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new()
	if use_physical_key:
		key_event.physical_keycode = keycode
	else:
		key_event.keycode = keycode
	return key_event


static func _create_mouse_button_event(button_index: MouseButton) -> InputEventMouseButton:
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = button_index
	return mouse_event
