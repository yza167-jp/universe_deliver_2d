extends SceneTree

const TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t105_catalog"
const M0_ORDER_ID: StringName = &"order_red_sand_m0"

var _game_state: GameStateModel
var _registry: GameDataRegistry


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	if _game_state == null or _registry == null:
		printerr("[m1-catalog-visual] GameState or M1 registry is unavailable.")
		quit(1)
		return

	_game_state.reset_runtime_state()
	if not await _capture_terminal("terminal_m0_new_game.png"):
		quit(1)
		return

	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.completed_order_ids[M0_ORDER_ID] = true
	_game_state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	_game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	_game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_WHITE_NOISE)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	if not await _capture_terminal("terminal_m1_prologue.png"):
		quit(1)
		return

	_game_state.reset_runtime_state()
	var m0_order: OrderDefinition = _registry.find_order(M0_ORDER_ID)
	if not _game_state.accept_order(m0_order):
		printerr("[m1-catalog-visual] M0 order could not be accepted.")
		quit(1)
		return
	if not await _capture_terminal("terminal_active_order.png"):
		quit(1)
		return

	_game_state.reset_runtime_state()
	if not await _capture_cockpit("cockpit_no_order.png"):
		quit(1)
		return

	_game_state.reset_runtime_state()
	if (
		not _game_state.accept_order(m0_order)
		or not _game_state.confirm_departure(m0_order)
	):
		printerr("[m1-catalog-visual] Confirmed M0 cockpit fixture failed.")
		quit(1)
		return
	if not await _capture_cockpit("cockpit_active_destination.png"):
		quit(1)
		return

	_game_state.reset_runtime_state()
	print(
		"[m1-catalog-visual] PASS: saved M0, M1 prologue, active-order, "
		+ "no-order navigation, and active-destination frames."
	)
	quit(0)


func _capture_terminal(file_name: String) -> bool:
	var scene: PackedScene = load(TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	root.add_child(terminal)
	await _settle_frames(3)
	if not terminal.open_terminal():
		printerr("[m1-catalog-visual] Terminal could not open.")
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame(file_name)
	terminal.queue_free()
	await _settle_frames(2)
	return saved


func _capture_cockpit(file_name: String) -> bool:
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(3)
	if not cockpit.activate_hotspot(&"navigation_screen"):
		printerr("[m1-catalog-visual] Cockpit navigation could not open.")
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame(file_name)
	cockpit.queue_free()
	await _settle_frames(2)
	return saved


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[m1-catalog-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[m1-catalog-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[m1-catalog-visual] Could not save %s." % output_path)
		return false
	print("[m1-catalog-visual] Saved %s" % output_path)
	return true
