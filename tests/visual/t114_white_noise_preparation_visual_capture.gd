extends SceneTree

const TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const LOADOUT_SCENE_PATH: String = "res://scenes/ui/ship_loadout.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t114_white_noise_preparation"
)

var _game_state: GameStateModel
var _registry: GameDataRegistry
var _shielding: ShipModuleDefinition
var _order: OrderDefinition


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	if _game_state == null or _registry == null:
		printerr("[t114-visual] GameState or M1 registry is unavailable.")
		quit(1)
		return
	_shielding = _registry.find_module(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	_order = _registry.find_order(M1CatalogModel.WHITE_NOISE_ORDER_ID)
	if _shielding == null or _order == null:
		printerr("[t114-visual] White Noise preparation data is unavailable.")
		quit(1)
		return
	_prepare_owned_uninstalled_state()
	if not await _capture_terminal():
		quit(1)
		return
	if not _game_state.equip_ship_module(_shielding):
		printerr("[t114-visual] Could not install high-voltage shielding.")
		quit(1)
		return
	if not await _capture_loadout():
		quit(1)
		return
	if not await _capture_cockpit():
		quit(1)
		return
	_game_state.reset_runtime_state()
	print(
		"[t114-visual] PASS: saved order risk preview, qualified loadout, "
		+ "and cockpit route-pending frames."
	)
	quit(0)


func _capture_terminal() -> bool:
	var scene: PackedScene = load(TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	terminal.set_game_state_override(_game_state)
	terminal.set_data_registry(_registry)
	root.add_child(terminal)
	await _settle_frames(3)
	if (
		not terminal.open_terminal()
		or not terminal.select_order(M1CatalogModel.WHITE_NOISE_ORDER_ID)
	):
		printerr("[t114-visual] White Noise order preview could not open.")
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame("white_noise_order_preview.png")
	terminal.queue_free()
	await _settle_frames(2)
	return saved


func _capture_loadout() -> bool:
	var scene: PackedScene = load(LOADOUT_SCENE_PATH) as PackedScene
	var loadout: ShipLoadoutUI = scene.instantiate() as ShipLoadoutUI
	loadout.set_game_state_override(_game_state)
	loadout.set_order_definition(_order)
	root.add_child(loadout)
	await _settle_frames(3)
	if not loadout.open_loadout():
		printerr("[t114-visual] White Noise loadout preview could not open.")
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame("white_noise_qualified_loadout.png")
	loadout.queue_free()
	await _settle_frames(2)
	return saved


func _capture_cockpit() -> bool:
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(3)
	if not cockpit.activate_hotspot(&"navigation_screen"):
		printerr("[t114-visual] Cockpit navigation preview could not open.")
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame("white_noise_cockpit_preview.png")
	cockpit.queue_free()
	await _settle_frames(2)
	return saved


func _prepare_owned_uninstalled_state() -> void:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for order_id: StringName in [
		M1CatalogModel.M0_ORDER_ID,
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT,
	]:
		_game_state.completed_order_ids[order_id] = true
		_game_state.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
		_game_state.reward_applied_order_ids.append(order_id)
	_game_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	_game_state.ship_upgrade_ids.append(_shielding.id)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t114-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t114-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t114-visual] Could not save %s." % output_path)
		return false
	print("[t114-visual] Saved %s" % output_path)
	return true
