extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t113_archive_terminal"
)

var _game_state: GameStateModel
var _registry: GameDataRegistry
var _contract: RedSandRevisitContract


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as RedSandRevisitContract
	if (
		_game_state == null
		or _registry == null
		or _contract == null
		or not _prepare_completed_revisit()
	):
		printerr("[t113-visual] Completed revisit fixture is unavailable.")
		quit(1)
		return

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await _settle_frames(4)
	var terminal: Interactable2D = station.get_archive_terminal_interactable()
	var player: StationPlayer = station.get_station_player()
	player.position = terminal.position + Vector2(0.0, 58.0)
	player.set_facing_direction(terminal.position - player.position)
	await _settle_frames(3)
	if not _save_frame("archive_terminal_station.png"):
		quit(1)
		return

	if not terminal.interact(player):
		printerr("[t113-visual] Archive terminal could not open.")
		quit(1)
		return
	await _settle_frames(3)
	var browser: CodexBrowserUI = station.get_archive_terminal_ui()
	browser.select_category(CodexEntryDefinition.Category.ANOMALY)
	browser.get_category_button(
		CodexEntryDefinition.Category.ANOMALY
	).grab_focus()
	await _settle_frames(2)
	if not _save_frame("archive_terminal_anomaly.png"):
		quit(1)
		return
	browser.close_browser()
	await _settle_frames(2)

	if not station.get_lao_pi().interact(player):
		printerr("[t113-visual] Lao Pi archive briefing could not open.")
		quit(1)
		return
	await _settle_frames(2)
	var dialogue_ui: DialogueUI = (
		station.get_tutorial_controller().get_dialogue_ui()
	)
	dialogue_ui.quick_show_current_line()
	dialogue_ui.continue_dialogue()
	dialogue_ui.quick_show_current_line()
	await _settle_frames(2)
	if not _save_frame("lao_pi_white_noise_briefing.png"):
		quit(1)
		return

	station.queue_free()
	_game_state.reset_runtime_state()
	await _settle_frames(2)
	print(
		"[t113-visual] PASS: saved station terminal, anomaly archive, "
		+ "and Lao Pi White Noise briefing frames."
	)
	quit(0)


func _prepare_completed_revisit() -> bool:
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var m0_order: OrderDefinition = _registry.find_order(
		GameDataValidator.M1_ACTUAL_M0_ORDER_ID
	)
	if (
		m0_order == null
		or not _game_state.accept_order(m0_order)
		or not _game_state.complete_order(
			m0_order,
			-1,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
	):
		return false
	_game_state.main_story_chapter = (
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	)
	if not _game_state.unlocked_planet_ids.has(
		M1ProgressRules.PLANET_RED_SAND
	):
		_game_state.unlocked_planet_ids.append(
			M1ProgressRules.PLANET_RED_SAND
		)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	if not _game_state.accept_order(_contract.order):
		return false
	_game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		_contract.accepted_state_id
	)
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	run_state.cargo_integrity = 100.0
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	_game_state.set_story_flag(_contract.keep_local_record_flag)
	_game_state.set_story_flag(_contract.completion_dialogue_flag)
	var module: ShipModuleDefinition = _registry.find_module(
		_contract.auto_equip_module_id
	)
	var settlement: OrderSettlementResult = OrderSettlementCalculator.calculate(
		_contract.order,
		run_state
	)
	return (
		module != null
		and _game_state.settle_current_order(
			_contract.order,
			settlement,
			&"",
			[],
			_contract.get_choice_relation_rewards(_game_state),
			[module]
		)
	)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t113-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t113-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t113-visual] Could not save %s." % output_path)
		return false
	print("[t113-visual] Saved %s" % output_path)
	return true
