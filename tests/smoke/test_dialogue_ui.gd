extends ProjectTestSuite

const UI_SCENE_PATH: String = "res://scenes/narrative/dialogue_ui.tscn"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"


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

	host.free()
	game_state.free()
	TranslationServer.set_locale(original_locale)
	return failures
