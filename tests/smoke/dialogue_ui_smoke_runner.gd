extends SceneTree

const UI_SCENE_PATH: String = "res://scenes/narrative/dialogue_ui.tscn"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var host: Control = Control.new()
	host.size = Vector2(640.0, 360.0)
	root.add_child(host)
	var ui_scene: PackedScene = load(UI_SCENE_PATH) as PackedScene
	var dialogue_ui: DialogueUI = ui_scene.instantiate() as DialogueUI
	host.add_child(dialogue_ui)
	await process_frame

	var sequence: DialogueSequence = load(DIALOGUE_PATH) as DialogueSequence
	var game_state: GameStateModel = GameStateModel.new()
	_check(
		dialogue_ui.start_dialogue(sequence, game_state),
		"Dialogue UI could not start its test sequence."
	)
	await process_frame
	dialogue_ui.quick_show_current_line()
	await process_frame

	_check(dialogue_ui.get_displayed_speaker() == "老皮", "Chinese speaker text did not render.")
	_check(
		dialogue_ui.get_full_text().begins_with("同声传译器接通了"),
		"Chinese dialogue text did not render."
	)
	_check(dialogue_ui.get_body_view_height() >= 62.0, "Dialogue reading region is too short.")
	_check(
		dialogue_ui.get_body_content_height() <= dialogue_ui.get_body_view_height(),
		"Opening dialogue text overflows its reading region."
	)
	_check(
		dialogue_ui.body_font_has_glyph("老".unicode_at(0)),
		"Dialogue SystemFont fallback chain does not expose Chinese glyphs."
	)

	var dialogue_panel: PanelContainer = dialogue_ui.get_node("DialoguePanel") as PanelContainer
	_check(dialogue_panel.position.x >= 0.0, "Dialogue panel extends past the left viewport edge.")
	_check(dialogue_panel.position.y >= 0.0, "Dialogue panel extends past the top viewport edge.")
	_check(
		dialogue_panel.position.x + dialogue_panel.size.x <= 640.0,
		"Dialogue panel extends past the right viewport edge."
	)
	_check(
		dialogue_panel.position.y + dialogue_panel.size.y <= 360.0,
		"Dialogue panel extends past the bottom viewport edge."
	)
	_check(dialogue_ui.continue_dialogue(), "Dialogue UI could not advance to its choice prompt.")
	await process_frame
	dialogue_ui.quick_show_current_line()
	await process_frame
	var choice_container: VBoxContainer = dialogue_ui.get_node(
		"DialoguePanel/Margin/Content/ChoiceContainer"
	) as VBoxContainer
	_check(choice_container.get_child_count() == 2, "Choice prompt did not create two buttons.")
	_check(
		dialogue_ui.get_body_content_height() <= dialogue_ui.get_body_view_height(),
		"Chinese choice prompt overflows its reading region."
	)
	_check(dialogue_panel.position.y >= 0.0, "Choice layout pushes the panel above the viewport.")
	_check(
		dialogue_panel.position.y + dialogue_panel.size.y <= 360.0,
		"Choice layout pushes the panel below the viewport."
	)

	dialogue_ui.show_history()
	await process_frame
	var history_panel: PanelContainer = dialogue_ui.get_node("HistoryPanel") as PanelContainer
	_check(history_panel.visible, "Dialogue history did not open.")
	dialogue_ui.hide_history()
	_check(not history_panel.visible, "Dialogue history did not close.")

	host.queue_free()
	game_state.free()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print("[dialogue-ui] PASS: Chinese glyphs, layout, history, and localization.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[dialogue-ui] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
