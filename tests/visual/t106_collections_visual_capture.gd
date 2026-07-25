extends SceneTree

const CODEX_SCENE_PATH: String = "res://scenes/ui/codex_browser.tscn"
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const M0_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t106_collections"

var _game_state: GameStateModel


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	if _game_state == null or not _prepare_completed_m0():
		printerr("[t106-visual] Completed M0 fixture is unavailable.")
		quit(1)
		return

	var codex_scene: PackedScene = load(CODEX_SCENE_PATH) as PackedScene
	var browser: CodexBrowserUI = codex_scene.instantiate() as CodexBrowserUI
	root.add_child(browser)
	await _settle_frames(3)
	if not browser.open_browser():
		printerr("[t106-visual] Codex browser could not open.")
		quit(1)
		return
	await _settle_frames(3)
	if not _save_frame("codex_red_sand.png"):
		quit(1)
		return
	browser.select_category(CodexEntryDefinition.Category.SOUVENIR)
	browser.get_category_button(
		CodexEntryDefinition.Category.SOUVENIR
	).grab_focus()
	await _settle_frames(2)
	if not _save_frame("codex_souvenir.png"):
		quit(1)
		return
	browser.queue_free()
	await _settle_frames(2)

	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await _settle_frames(4)
	var wall_ui: SouvenirWallUI = station.get_souvenir_wall_ui()
	var return_state: StationReturnStateController = (
		station.get_return_state_controller()
	)
	if (
		wall_ui == null
		or return_state == null
		or not return_state.get_memorabilia_wall().interact(
			station.get_station_player()
		)
	):
		printerr("[t106-visual] Souvenir wall could not open.")
		quit(1)
		return
	await _settle_frames(3)
	if not _save_frame("souvenir_wall_m0.png"):
		quit(1)
		return
	wall_ui.close_wall()
	station.queue_free()
	_game_state.reset_runtime_state()
	await _settle_frames(2)
	print(
		"[t106-visual] PASS: saved Red Sand codex, souvenir codex, "
		+ "and four-slot wall frames."
	)
	quit(0)


func _prepare_completed_m0() -> bool:
	var order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	_game_state.reset_runtime_state()
	return (
		order != null
		and _game_state.accept_order(order)
		and _game_state.complete_order(
			order,
			-1,
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
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
		printerr("[t106-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t106-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t106-visual] Could not save %s." % output_path)
		return false
	print("[t106-visual] Saved %s" % output_path)
	return true
