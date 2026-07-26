extends ProjectTestSuite

const UI_SCENE_PATH: String = "res://scenes/narrative/dialogue_ui.tscn"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"

var _dialogue_finished_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")

	var ui_scene: PackedScene = load(UI_SCENE_PATH) as PackedScene
	var dialogue_ui: DialogueUI = ui_scene.instantiate() as DialogueUI
	var sequence: DialogueSequence = load(DIALOGUE_PATH) as DialogueSequence
	var game_state: GameStateModel = GameStateModel.new()
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Control = Control.new()
	host.size = Vector2(640.0, 360.0)
	scene_tree.root.add_child(host)
	host.add_child(dialogue_ui)
	_dialogue_finished_count = 0
	dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)

	expect_true(
		dialogue_ui.start_dialogue(sequence, game_state),
		"Dialogue UI must start a Resource-backed sequence.",
		failures
	)
	dialogue_ui.quick_show_current_line()
	expect_true(
		dialogue_ui.get_displayed_speaker() == "老皮",
		"Dialogue UI must display the localized Chinese speaker name.",
		failures
	)
	expect_true(
		dialogue_ui.get_full_text().begins_with("同声传译器接通了"),
		"Dialogue UI must display localized Chinese body text.",
		failures
	)
	expect_true(
		dialogue_ui.get_body_minimum_height() >= 62.0,
		"Dialogue body must reserve a stable reading region at 640×360.",
		failures
	)

	dialogue_ui.show_history()
	var history_panel: PanelContainer = dialogue_ui.get_node("HistoryPanel") as PanelContainer
	expect_true(history_panel.visible, "Dialogue history must be openable.", failures)
	dialogue_ui.hide_history()
	expect_true(not history_panel.visible, "Dialogue history must be closable.", failures)

	var skip_sequence_button: Button = dialogue_ui.get_node(
		"DialoguePanel/Margin/Content/Controls/SkipSequenceButton"
	) as Button
	expect_true(skip_sequence_button != null, "Dialogue UI must expose whole-sequence skip.", failures)
	if skip_sequence_button != null:
		expect_true(
			skip_sequence_button.text == "跳过整段",
			"Whole-sequence skip must use localized player-facing text.",
			failures
		)
		expect_true(not skip_sequence_button.disabled, "Whole-sequence skip must be available.", failures)

	var skip_result: DialogueRuntime.SequenceSkipResult = dialogue_ui.skip_dialogue_sequence()
	expect_true(
		skip_result == DialogueRuntime.SequenceSkipResult.STOPPED_AT_CHOICE,
		"Whole-sequence skip must stop at the nearest choice.",
		failures
	)
	var choice_container: VBoxContainer = dialogue_ui.get_node(
		"DialoguePanel/Margin/Content/ChoiceContainer"
	) as VBoxContainer
	expect_true(
		dialogue_ui.visible and choice_container.get_child_count() == 2,
		"Stopping at a choice must keep the dialogue open with explicit options.",
		failures
	)
	expect_true(
		not game_state.has_story_flag(&"story_dialogue_test_professional")
		and not game_state.has_story_flag(&"story_dialogue_test_equipment_first"),
		"Whole-sequence skip must never choose a branch.",
		failures
	)
	var first_choice_button: Button = choice_container.get_child(0) as Button
	expect_true(
		first_choice_button != null,
		"Choice UI must expose a real focusable Button.",
		failures
	)
	if first_choice_button != null:
		first_choice_button.pressed.emit()
	expect_true(
		game_state.has_story_flag(&"story_dialogue_test_professional")
		and choice_container.get_child_count() == 0
		and dialogue_ui.get_full_text() == tr("DIALOGUE_TEST_RESPONSE_PROCESS"),
		(
			"A real Button.pressed path must apply the choice, detach old "
			+ "buttons, and reveal the selected response."
		),
		failures
	)
	expect_true(
		dialogue_ui.skip_dialogue_sequence() == DialogueRuntime.SequenceSkipResult.FINISHED,
		"Whole-sequence skip must finish linear content after a player choice.",
		failures
	)
	expect_true(not dialogue_ui.visible, "Completed whole-sequence skip must close the dialogue.", failures)
	expect_true(
		_dialogue_finished_count == 1,
		"Completed whole-sequence skip must emit dialogue_finished exactly once.",
		failures
	)
	expect_true(
		dialogue_ui.skip_dialogue_sequence() == DialogueRuntime.SequenceSkipResult.REJECTED
		and _dialogue_finished_count == 1,
		"Repeated UI skip requests must not repeat completion.",
		failures
	)

	host.free()
	game_state.free()
	TranslationServer.set_locale(original_locale)
	return failures


func _on_dialogue_finished() -> void:
	_dialogue_finished_count += 1
