extends SceneTree

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const PANEL_HOTSPOT_IDS: Array[StringName] = [
	&"navigation_screen",
	&"company_terminal",
	&"cargo_indicator",
]

var _failures: PackedStringArray = []
var _activated_ids: Array[StringName] = []
var _original_locale: String = ""
var _cockpit: Cockpit
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _radio_player_instance_id: int = 0
var _radio_stream_instance_id: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_prepare_order_state()
	var packed_scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Cockpit scene could not be loaded.")
	if packed_scene == null:
		_finish_smoke()
		return
	_cockpit = packed_scene.instantiate() as Cockpit
	_check(_cockpit != null, "Cockpit scene root is not Cockpit.")
	if _cockpit == null:
		_finish_smoke()
		return
	_cockpit.data_registry = _registry
	root.add_child(_cockpit)
	_cockpit.hotspot_activated.connect(_on_hotspot_activated)
	await process_frame
	await process_frame

	_check_layout_and_focus_semantics()
	for hotspot_id: StringName in _cockpit.get_hotspot_ids():
		await _exercise_mouse_and_keyboard_activation(hotspot_id)
	_check_starfield_animation()

	await _cleanup()
	_finish_smoke()


func _prepare_order_state() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_check(_game_state != null, "Cockpit smoke requires the GameState autoload.")
	_check(_registry != null, "Cockpit smoke could not load the M0 data registry.")
	if _game_state == null or _registry == null:
		return
	_game_state.reset_runtime_state()
	var order: OrderDefinition = _registry.find_order(&"order_red_sand_m0")
	_check(order != null, "Red Sand order is missing from the M0 registry.")
	if order != null:
		_check(_game_state.accept_order(order), "Cockpit smoke could not prepare the active order.")


func _check_layout_and_focus_semantics() -> void:
	_check(_cockpit.size == Vector2(640.0, 360.0), "Cockpit does not fill the 640x360 viewport.")
	var radio_players: Array[Node] = _cockpit.find_children(
		"RadioAudioPlayer",
		"AudioStreamPlayer",
		true,
		false
	)
	_check(radio_players.size() == 1, "Cockpit must own exactly one radio audio player.")
	var hotspot_ids: Array[StringName] = _cockpit.get_hotspot_ids()
	_check(hotspot_ids.size() == 6, "Cockpit does not expose exactly six hotspots.")
	var unique_ids: Dictionary[StringName, bool] = {}
	var rects: Dictionary[StringName, Rect2] = _cockpit.get_hotspot_rects()
	_check(rects.size() == hotspot_ids.size(), "Cockpit hotspot rectangles are incomplete.")
	for hotspot_id: StringName in hotspot_ids:
		_check(not unique_ids.has(hotspot_id), "Cockpit hotspot ID is duplicated: %s" % hotspot_id)
		unique_ids[hotspot_id] = true
		var button: Button = _cockpit.get_hotspot_button(hotspot_id)
		_check(button != null, "Cockpit hotspot button is missing: %s" % hotspot_id)
		if button == null:
			continue
		_check(
			VIEWPORT_RECT.encloses(button.get_global_rect()),
			"Cockpit hotspot leaves the viewport: %s %s" % [hotspot_id, button.get_global_rect()]
		)
		_check(button.focus_mode == Control.FOCUS_ALL, "Hotspot cannot receive focus: %s" % hotspot_id)
		_check(not button.text.begins_with("UI_"), "Hotspot label was not localized: %s" % hotspot_id)
		_check(button.tooltip_text.is_empty(), "Hotspot still exposes a duplicate tooltip: %s" % hotspot_id)

		var activation_count: int = _activated_ids.size()
		var selected_before_hover: StringName = _cockpit.get_selected_hotspot_id()
		button.mouse_entered.emit()
		_check(
			_activated_ids.size() == activation_count,
			"Hover activated a cockpit hotspot: %s" % hotspot_id
		)
		_check(
			_cockpit.get_selected_hotspot_id() == selected_before_hover,
			"Hover changed the focused hotspot state: %s" % hotspot_id
		)
		_check(not _cockpit.is_input_locked(), "Hover incorrectly opened a modal: %s" % hotspot_id)

		_check(_cockpit.focus_hotspot(hotspot_id), "Keyboard focus failed: %s" % hotspot_id)
		_check(
			_cockpit.get_selected_hotspot_id() == hotspot_id,
			"Focused hotspot did not become selected: %s" % hotspot_id
		)
		_check(
			not _cockpit.get_prompt_text().is_empty()
			and not _cockpit.get_prompt_text().begins_with("UI_"),
			"Focused hotspot is missing a localized action prompt: %s" % hotspot_id
		)
		_check(
			_activated_ids.size() == activation_count,
			"Focus alone activated a cockpit hotspot: %s" % hotspot_id
		)

	for first_index: int in hotspot_ids.size():
		for second_index: int in range(first_index + 1, hotspot_ids.size()):
			var first_id: StringName = hotspot_ids[first_index]
			var second_id: StringName = hotspot_ids[second_index]
			_check(
				not rects[first_id].intersects(rects[second_id], false),
				"Cockpit hotspots overlap: %s and %s" % [first_id, second_id]
			)


func _exercise_mouse_and_keyboard_activation(hotspot_id: StringName) -> void:
	var button: Button = _cockpit.get_hotspot_button(hotspot_id)
	if button == null:
		return

	var mouse_count_before: int = _activated_ids.size()
	button.pressed.emit()
	await process_frame
	_check(
		_activated_ids.size() == mouse_count_before + 1,
		"One mouse activation did not emit exactly once: %s" % hotspot_id
	)
	_check(
		_cockpit.get_last_activated_hotspot_id() == hotspot_id,
		"Mouse activation reached the wrong unified behavior: %s" % hotspot_id
	)
	var mouse_behavior: String = _get_behavior_signature(hotspot_id)
	_check(not mouse_behavior.is_empty(), "Mouse activation produced no concrete behavior: %s" % hotspot_id)
	_check_specific_behavior(hotspot_id)
	await _close_behavior_and_check_focus(hotspot_id, true)

	_check(_cockpit.focus_hotspot(hotspot_id), "Hotspot could not regain focus: %s" % hotspot_id)
	var keyboard_count_before: int = _activated_ids.size()
	_push_action(Cockpit.INTERACT_ACTION)
	await process_frame
	_check(
		_activated_ids.size() == keyboard_count_before + 1,
		"One keyboard activation did not emit exactly once: %s" % hotspot_id
	)
	_check(
		_cockpit.get_last_activated_hotspot_id() == hotspot_id,
		"Keyboard activation reached the wrong unified behavior: %s" % hotspot_id
	)
	var keyboard_behavior: String = _get_behavior_signature(hotspot_id)
	_check(
		keyboard_behavior == mouse_behavior,
		"Mouse and keyboard produced different behavior types for %s: %s / %s"
		% [hotspot_id, mouse_behavior, keyboard_behavior]
	)
	_check_specific_behavior(hotspot_id)
	await _close_behavior_and_check_focus(hotspot_id, false)


func _get_behavior_signature(hotspot_id: StringName) -> String:
	if hotspot_id in PANEL_HOTSPOT_IDS:
		return "panel:%s" % _cockpit.get_open_panel_id()
	match hotspot_id:
		&"lao_pi_seat":
			return "dialogue" if _cockpit.is_dialogue_active() else ""
		&"radio":
			return "radio_toggle"
		&"window_view":
			return "window_notification" if _cockpit.is_notification_visible() else ""
	return ""


func _check_specific_behavior(hotspot_id: StringName) -> void:
	if hotspot_id in PANEL_HOTSPOT_IDS or hotspot_id == &"lao_pi_seat":
		_check(_cockpit.is_input_locked(), "Modal behavior did not lock cockpit input: %s" % hotspot_id)
		var activation_count: int = _activated_ids.size()
		_check(
			not _cockpit.activate_hotspot(&"window_view"),
			"A background hotspot activated through an open modal: %s" % hotspot_id
		)
		_check(
			_activated_ids.size() == activation_count,
			"Input lock still emitted an activation event: %s" % hotspot_id
		)
		_check(
			not _cockpit.is_notification_visible(),
			"Modal behavior also displayed a duplicate transient notification: %s" % hotspot_id
		)

	match hotspot_id:
		&"navigation_screen":
			_check(
				_cockpit.get_open_panel_id() == hotspot_id,
				"Navigation did not open its panel state."
			)
			_check(
				_cockpit.get_device_panel_body().contains(tr("PLANET_RED_SAND_NAME"))
				and _cockpit.get_device_panel_body().contains(tr("UI_COCKPIT_NAV_ROUTE_PENDING")),
				"Navigation panel is missing order destination or read-only route state."
			)
		&"company_terminal":
			_check(
				_cockpit.get_open_panel_id() == hotspot_id
				and _cockpit.get_device_panel_body().contains(tr("UI_COCKPIT_COMPANY_LINK_STATUS"))
				and _cockpit.get_device_panel_body().contains("2/5")
				and _cockpit.get_device_panel_body().contains("优先保护护盾与货物")
				and _cockpit.get_device_panel_body().contains("自愿职业成长"),
				"Company terminal did not expose actionable route risk and management tone."
			)
		&"cargo_indicator":
			_check(
				_cockpit.get_open_panel_id() == hotspot_id
				and _cockpit.get_device_panel_body().contains(tr("CARGO_RED_SAND_M0_NAME")),
				"Cargo indicator did not show the loaded cargo state."
			)
		&"lao_pi_seat":
			var dialogue_ui: DialogueUI = _cockpit.get_dialogue_ui()
			_check(dialogue_ui != null and dialogue_ui.visible, "Lao Pi activation did not open dialogue UI.")
			if dialogue_ui != null:
				_check(dialogue_ui.get_displayed_speaker() == "老皮", "Cockpit dialogue has no Lao Pi speaker label.")
				_check(
					dialogue_ui.get_full_text() == tr("DIALOGUE_LAO_PI_COCKPIT_01"),
					"The activation input skipped or replaced Lao Pi's first line."
				)
				_check(
					dialogue_ui.get_full_text() != tr("UI_COCKPIT_DESC_LAO_PI")
					and _cockpit.get_prompt_text() != dialogue_ui.get_full_text(),
					"Lao Pi dialogue repeats the old third-person detail text."
				)
		&"radio":
			var radio_button: Button = _cockpit.get_hotspot_button(&"radio")
			var radio_player: AudioStreamPlayer = _cockpit.get_radio_audio_player()
			var radio_feedback: CockpitRadioFeedback = _cockpit.get_radio_feedback()
			var state_text: String = tr(
				"UI_COCKPIT_RADIO_ON" if _cockpit.is_radio_on() else "UI_COCKPIT_RADIO_OFF"
			)
			_check(
				radio_button != null
				and radio_button.text.contains(state_text)
				and _cockpit.get_status_text().contains(state_text),
				"Radio activation did not expose a clear On/Off visual state."
			)
			_check(
				radio_player != null and radio_player.stream is AudioStreamWAV,
				"Radio must use one configured local loop stream."
			)
			_check(
				radio_feedback != null
				and radio_feedback.is_active() == _cockpit.is_radio_on(),
				"Radio visual activity does not match its On/Off state."
			)
			_check(
				radio_player != null
				and radio_player.playing == _cockpit.is_radio_on(),
				"Radio audio playback does not match its On/Off state."
			)
			if radio_player != null:
				if _radio_player_instance_id == 0:
					_radio_player_instance_id = radio_player.get_instance_id()
				else:
					_check(
						radio_player.get_instance_id() == _radio_player_instance_id,
						"Radio toggles created a second audio player."
					)
				if radio_player.stream != null:
					if _radio_stream_instance_id == 0:
						_radio_stream_instance_id = radio_player.stream.get_instance_id()
					else:
						_check(
							radio_player.stream.get_instance_id() == _radio_stream_instance_id,
							"Radio toggles stacked or replaced the loop stream."
						)
			if radio_feedback != null:
				var phase_before: float = radio_feedback.get_pulse_phase()
				radio_feedback.advance_animation(0.2)
				if _cockpit.is_radio_on():
					_check(
						not is_equal_approx(radio_feedback.get_pulse_phase(), phase_before),
						"Radio On state did not animate its visual waveform."
					)
				else:
					_check(
						is_zero_approx(radio_feedback.get_pulse_phase()),
						"Radio Off state did not stop and reset its visual waveform."
					)
			_check(not _cockpit.is_input_locked(), "Radio incorrectly opened a modal.")
		&"window_view":
			_check(_cockpit.is_notification_visible(), "Window activation did not show an observation.")
			_check(
				_cockpit.get_notification_text() == tr("UI_COCKPIT_WINDOW_OBSERVATION")
				and _cockpit.get_notification_text() != _cockpit.get_prompt_text(),
				"Window observation is missing or duplicates the bottom prompt."
			)


func _close_behavior_and_check_focus(hotspot_id: StringName, use_escape: bool) -> void:
	if _cockpit.is_dialogue_active() or not _cockpit.get_open_panel_id().is_empty():
		if use_escape:
			_push_action(Cockpit.CANCEL_ACTION)
		else:
			var close_button: Button = _cockpit.get_node_or_null(
				"ModalLayer/DevicePanel/Margin/Content/Actions/DeviceCloseButton"
			) as Button
			if _cockpit.is_dialogue_active():
				var dialogue_ui: DialogueUI = _cockpit.get_dialogue_ui()
				_check(
					dialogue_ui != null
					and dialogue_ui.skip_dialogue_sequence()
					== DialogueRuntime.SequenceSkipResult.FINISHED,
					"Dialogue sequence skip could not finish the cockpit modal."
				)
			elif close_button != null:
				close_button.pressed.emit()
		await process_frame
		await process_frame
		_check(not _cockpit.is_input_locked(), "Closing the modal did not restore cockpit input: %s" % hotspot_id)
		_check(
			_cockpit.get_selected_hotspot_id() == hotspot_id,
			"Closing the modal did not restore the previous hotspot selection: %s" % hotspot_id
		)
		var restored_button: Button = _cockpit.get_hotspot_button(hotspot_id)
		_check(
			restored_button != null and restored_button.has_focus(),
			"Closing the modal did not return keyboard focus: %s" % hotspot_id
		)
	elif _cockpit.is_notification_visible():
		_push_action(Cockpit.CANCEL_ACTION)
		await process_frame
		_check(not _cockpit.is_notification_visible(), "Window observation could not be dismissed.")


func _check_starfield_animation() -> void:
	var starfield: CockpitStarfield = _cockpit.get_starfield()
	_check(starfield != null, "Cockpit starfield is missing.")
	if starfield == null:
		return
	starfield.set_process(false)
	_check(starfield.get_layer_count() >= 3, "Cockpit starfield has fewer than three layers.")
	var offsets_before: PackedFloat32Array = starfield.get_layer_offsets()
	starfield.advance_animation(1.0)
	var offsets_after: PackedFloat32Array = starfield.get_layer_offsets()
	_check(offsets_before.size() == offsets_after.size(), "Starfield layer count changed during animation.")
	for index: int in mini(offsets_before.size(), offsets_after.size()):
		_check(offsets_after[index] > offsets_before[index], "Starfield layer did not advance: %d" % index)


func _push_action(action: StringName) -> void:
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = action
	input_event.pressed = true
	root.push_input(input_event)


func _on_hotspot_activated(hotspot_id: StringName) -> void:
	_activated_ids.append(hotspot_id)


func _cleanup() -> void:
	if _cockpit != null and is_instance_valid(_cockpit):
		_cockpit.queue_free()
		await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()


func _finish_smoke() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[cockpit] PASS: hover/focus/activation semantics, six behaviors, modal lock, "
			+ "sequence-skip focus recovery, and layered starfield."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[cockpit] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
