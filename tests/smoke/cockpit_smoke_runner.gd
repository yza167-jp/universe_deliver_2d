extends SceneTree

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _activated_ids: Array[StringName] = []
var _original_locale: String = ""
var _cockpit: Cockpit


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
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
	root.add_child(_cockpit)
	_cockpit.hotspot_activated.connect(_on_hotspot_activated)
	await process_frame
	await process_frame

	_check(_cockpit.size == Vector2(640.0, 360.0), "Cockpit does not fill the 640x360 viewport.")
	var hotspot_ids: Array[StringName] = _cockpit.get_hotspot_ids()
	_check(hotspot_ids.size() == 6, "Cockpit does not expose exactly six hotspots.")
	var rects: Dictionary[StringName, Rect2] = _cockpit.get_hotspot_rects()
	_check(rects.size() == hotspot_ids.size(), "Cockpit hotspot rectangles are incomplete.")
	for hotspot_id: StringName in hotspot_ids:
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
		_check(not button.tooltip_text.is_empty(), "Hotspot is missing hover help: %s" % hotspot_id)
		button.mouse_entered.emit()
		_check(
			_cockpit.get_active_hotspot_id() == hotspot_id,
			"Mouse hover did not preview hotspot: %s" % hotspot_id
		)
		_check(
			not _cockpit.get_feedback_text().is_empty()
			and not _cockpit.get_feedback_text().begins_with("UI_"),
			"Hotspot feedback was not localized: %s" % hotspot_id
		)
		_check(_cockpit.focus_hotspot(hotspot_id), "Keyboard focus failed: %s" % hotspot_id)
		var activation_count: int = _activated_ids.size()
		_check(_cockpit.activate_focused_hotspot(), "Focused hotspot could not activate: %s" % hotspot_id)
		_check(
			_activated_ids.size() == activation_count + 1 and _activated_ids.back() == hotspot_id,
			"Focused activation emitted the wrong hotspot: %s" % hotspot_id
		)

	for first_index: int in hotspot_ids.size():
		for second_index: int in range(first_index + 1, hotspot_ids.size()):
			var first_id: StringName = hotspot_ids[first_index]
			var second_id: StringName = hotspot_ids[second_index]
			_check(
				not rects[first_id].intersects(rects[second_id], false),
				"Cockpit hotspots overlap: %s and %s" % [first_id, second_id]
			)

	_check(
		_cockpit.focus_hotspot(Cockpit.INITIAL_HOTSPOT_ID),
		"Initial navigation hotspot could not receive focus."
	)
	var keyboard_activation_count: int = _activated_ids.size()
	var interact_event: InputEventAction = InputEventAction.new()
	interact_event.action = Cockpit.INTERACT_ACTION
	interact_event.pressed = true
	root.push_input(interact_event)
	await process_frame
	_check(
		_activated_ids.size() == keyboard_activation_count + 1
		and _activated_ids.back() == Cockpit.INITIAL_HOTSPOT_ID,
		"The mapped keyboard interaction action did not activate the focused hotspot."
	)

	var starfield: CockpitStarfield = _cockpit.get_starfield()
	_check(starfield != null, "Cockpit starfield is missing.")
	if starfield != null:
		starfield.set_process(false)
		_check(starfield.get_layer_count() >= 3, "Cockpit starfield has fewer than three layers.")
		var offsets_before: PackedFloat32Array = starfield.get_layer_offsets()
		starfield.advance_animation(1.0)
		var offsets_after: PackedFloat32Array = starfield.get_layer_offsets()
		_check(
			offsets_before.size() == offsets_after.size(),
			"Starfield layer offset count changed during animation."
		)
		for index: int in mini(offsets_before.size(), offsets_after.size()):
			_check(
				offsets_after[index] > offsets_before[index],
				"Starfield layer did not advance: %d" % index
			)

	await _cleanup()
	_finish_smoke()


func _on_hotspot_activated(hotspot_id: StringName) -> void:
	_activated_ids.append(hotspot_id)


func _cleanup() -> void:
	if _cockpit != null and is_instance_valid(_cockpit):
		_cockpit.queue_free()
		await process_frame


func _finish_smoke() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print("[cockpit] PASS: layout, six hotspots, mouse preview, keyboard focus, and layered starfield.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[cockpit] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
