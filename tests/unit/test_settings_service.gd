extends ProjectTestSuite

const TEST_SETTINGS_PATH: String = "user://t006_settings_service_test.cfg"

var _assist_events: Array[StringName] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	_remove_test_settings()
	_assist_events.clear()

	var service: SettingsServiceModel = SettingsServiceModel.new()
	service.storage_path = TEST_SETTINGS_PATH
	service.assist_option_changed.connect(_on_assist_option_changed)
	expect_true(service.load_settings(), "Default local settings must save on first load.", failures)
	expect_true(
		FileAccess.file_exists(TEST_SETTINGS_PATH),
		"Settings must use an independent local config file.",
		failures
	)
	_expect_default_input_map(failures)

	expect_true(service.set_master_volume(0.4), "Master volume must save.", failures)
	expect_true(service.set_music_volume(0.5), "Music volume must save.", failures)
	expect_true(service.set_sfx_volume(0.6), "SFX volume must save.", failures)
	expect_true(service.set_screen_shake_strength(0.25), "Screen shake must save.", failures)
	expect_true(service.set_text_speed(72.0), "Text speed must save.", failures)
	expect_true(service.set_flight_assist_strength(0.33), "Flight assist must save.", failures)
	expect_true(service.set_slow_motion_assist(true), "Slow motion assist must save.", failures)
	expect_true(service.set_route_hints_enabled(false), "Route hints must save.", failures)
	expect_true(service.set_high_contrast_terrain(true), "High contrast must save.", failures)
	expect_true(
		_assist_events == [
			SettingsServiceModel.SLOW_MOTION_ASSIST,
			SettingsServiceModel.ROUTE_HINTS_ENABLED,
			SettingsServiceModel.HIGH_CONTRAST_TERRAIN,
		],
		"Each debug assistance toggle must emit a state signal.",
		failures
	)

	var remapped_interact: Array[InputEvent] = []
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_K
	remapped_interact.append(key_event)
	expect_true(
		service.set_action_events(&"interact", remapped_interact),
		"Keyboard remapping must save.",
		failures
	)

	var restored: SettingsServiceModel = SettingsServiceModel.new()
	restored.storage_path = TEST_SETTINGS_PATH
	expect_true(restored.load_settings(), "Saved settings must restore after restart.", failures)
	expect_true(
		is_equal_approx(restored.settings.master_volume, 0.4)
		and is_equal_approx(restored.settings.music_volume, 0.5)
		and is_equal_approx(restored.settings.sfx_volume, 0.6),
		"Saved audio settings must round-trip.",
		failures
	)
	expect_true(
		is_equal_approx(restored.settings.screen_shake_strength, 0.25)
		and is_equal_approx(restored.settings.text_speed, 72.0),
		"Saved readability settings must round-trip.",
		failures
	)
	expect_true(
		is_equal_approx(restored.settings.flight_assist_strength, 0.33),
		"Flight assist strength must round-trip.",
		failures
	)
	expect_true(
		restored.settings.slow_motion_assist
		and not restored.settings.route_hints_enabled
		and restored.settings.high_contrast_terrain,
		"Assistance toggles must round-trip.",
		failures
	)
	expect_true(
		_has_physical_key(InputMap.action_get_events(&"interact"), KEY_K),
		"Keyboard remapping must restore after restart.",
		failures
	)

	_restore_global_settings(service)
	restored.free()
	service.free()
	_remove_test_settings()
	return failures


func _expect_default_input_map(failures: Array[String]) -> void:
	for action: StringName in SettingsServiceModel.get_supported_actions():
		expect_true(InputMap.has_action(action), "Missing Input Map action: %s" % action, failures)
		expect_true(
			not InputMap.action_get_events(action).is_empty(),
			"Input Map action has no keyboard/mouse default: %s" % action,
			failures
		)
	expect_true(
		_has_physical_key(InputMap.action_get_events(&"flight_throttle"), KEY_W),
		"Flight throttle must default to W.",
		failures
	)
	expect_true(
		_has_physical_key(InputMap.action_get_events(&"flight_brake"), KEY_S),
		"Flight brake must default to S.",
		failures
	)
	expect_true(
		_has_key(InputMap.action_get_events(&"flight_pitch_up"), KEY_UP)
		and _has_key(InputMap.action_get_events(&"flight_pitch_down"), KEY_DOWN),
		"Flight pitch must default to the up and down arrow keys.",
		failures
	)
	expect_true(
		_has_mouse_button(InputMap.action_get_events(&"flight_fire"), MOUSE_BUTTON_LEFT),
		"Flight fire must include the left mouse button.",
		failures
	)
	expect_true(
		_has_key(InputMap.action_get_events(&"toggle_fullscreen"), KEY_F11),
		"Actual fullscreen must default to F11.",
		failures
	)
	expect_true(
		_has_key(InputMap.action_get_events(&"flight_debug_toggle"), KEY_F3),
		"Flight Lab debug HUD toggle must default to F3.",
		failures
	)
	expect_true(
		_has_key(InputMap.action_get_events(&"flight_environment_cycle"), KEY_F4),
		"Flight Lab environment cycle must default to F4.",
		failures
	)
	expect_true(
		_has_key(InputMap.action_get_events(&"flight_assist_cycle"), KEY_F5),
		"Flight Lab assist preset cycle must default to F5.",
		failures
	)


func _has_physical_key(events: Array[InputEvent], expected_key: Key) -> bool:
	for input_event: InputEvent in events:
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event as InputEventKey
			if key_event.physical_keycode == expected_key:
				return true
	return false


func _has_key(events: Array[InputEvent], expected_key: Key) -> bool:
	for input_event: InputEvent in events:
		if input_event is InputEventKey:
			var key_event: InputEventKey = input_event as InputEventKey
			if key_event.keycode == expected_key or key_event.physical_keycode == expected_key:
				return true
	return false


func _has_mouse_button(events: Array[InputEvent], expected_button: MouseButton) -> bool:
	for input_event: InputEvent in events:
		if input_event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
			if mouse_event.button_index == expected_button:
				return true
	return false


func _on_assist_option_changed(option_id: StringName, _enabled: bool) -> void:
	_assist_events.append(option_id)


func _restore_global_settings(fallback_service: SettingsServiceModel) -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var global_service: SettingsServiceModel = scene_tree.root.get_node_or_null(
		"SettingsService"
	) as SettingsServiceModel
	if global_service != null:
		global_service.load_settings()
	else:
		fallback_service.reset_input_map_to_defaults(false)


func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
