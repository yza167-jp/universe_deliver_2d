extends SceneTree

const RESULTS_SCENE_PATH: String = "res://scenes/app/results.tscn"
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/settlements/white_noise_settlement_contract.tres"
)
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t125_white_noise_settlement"
)

var _original_locale: String = ""
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _contract: WhiteNoiseSettlementContract


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as WhiteNoiseSettlementContract
	if (
		_game_state == null
		or _registry == null
		or _contract == null
		or not _prepare_delivery_ready_order()
	):
		_fail("Could not prepare the White Noise settlement fixture.")
		return

	var results_scene: PackedScene = load(RESULTS_SCENE_PATH) as PackedScene
	var results: OrderResults = results_scene.instantiate() as OrderResults
	if results == null:
		_fail("White Noise results scene could not instantiate.")
		return
	root.add_child(results)
	await _settle_frames(4)
	if not results.is_settlement_committed():
		_fail("White Noise settlement did not commit.")
		return
	if not _save_frame("01_local_custody_results.png"):
		return
	results.queue_free()
	await _settle_frames(3)

	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	if station == null:
		_fail("Station scene could not instantiate after settlement.")
		return
	root.add_child(station)
	await _settle_frames(4)
	var terminal: Interactable2D = station.get_archive_terminal_interactable()
	var player: StationPlayer = station.get_station_player()
	var presenter: StationStatePresenter = station.get_station_state_presenter()
	if (
		terminal == null
		or player == null
		or presenter == null
		or not presenter.is_archive_terminal_white_noise_synced()
	):
		_fail("White Noise archive-terminal state is unavailable.")
		return
	player.position = terminal.position + Vector2(0.0, 58.0)
	player.set_facing_direction(terminal.position - player.position)
	await _settle_frames(3)
	if not _save_frame("02_archive_terminal_synced.png"):
		return
	if not terminal.interact(player):
		_fail("Updated archive terminal could not open.")
		return
	await _settle_frames(3)
	var browser: CodexBrowserUI = station.get_archive_terminal_ui()
	if (
		browser == null
		or not browser.select_category(CodexEntryDefinition.Category.ANOMALY)
		or not browser.select_entry(_contract.local_custody_codex.id)
	):
		_fail("Local-custody archive record could not be selected.")
		return
	await _settle_frames(3)
	if not _save_frame("03_local_custody_codex.png"):
		return

	station.queue_free()
	await _settle_frames(2)
	_restore_runtime()
	print(
		"[t125-visual] PASS: saved White Noise results, synced archive "
		+ "terminal, and local-custody codex frames."
	)
	quit(0)


func _prepare_delivery_ready_order() -> bool:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for completed_order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
	]:
		_game_state.completed_order_ids[completed_order_id] = true
		_game_state.order_states[
			completed_order_id
		] = GameStateModel.OrderStatus.COMPLETED
		_game_state.reward_applied_order_ids.append(completed_order_id)
	_game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	_game_state.story_flags[
		StationTutorialController.COMPLETION_FLAG
	] = true
	_game_state.story_flags[
		M0ProgressIds.STORY_RETURN_DIALOGUE_COMPLETED
	] = true
	_game_state.unlock_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
	var shielding: ShipModuleDefinition = _registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	if shielding == null:
		return false
	if not _game_state.ship_upgrade_ids.has(shielding.id):
		_game_state.ship_upgrade_ids.append(shielding.id)
	if (
		not _game_state.equip_ship_module(shielding)
		or not _game_state.accept_order(_contract.order)
		or not _game_state.confirm_departure(_contract.order)
	):
		return false
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	if run_state == null:
		return false
	run_state.cargo_integrity = 94.0
	run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_ROUGH,
		6.0
	)
	for story_flag: StringName in [
		_contract.arrival_contract.main_dialogue_completion_flag,
		_contract.arrival_contract.choice_recorded_flag,
		_contract.arrival_contract.local_custody_flag,
	]:
		_game_state.set_story_flag(story_flag)
	return _contract.is_delivery_ready(_game_state)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		_fail("Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		_fail("Could not save %s." % output_path)
		return false
	print("[t125-visual] Saved %s" % output_path)
	return true


func _restore_runtime() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t125-visual] FAIL: %s" % message)
	_restore_runtime()
	quit(1)
