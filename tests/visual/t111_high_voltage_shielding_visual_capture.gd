extends SceneTree

const LOADOUT_SCENE_PATH: String = "res://scenes/ui/ship_loadout.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const WHITE_ORDER_ID: StringName = &"order_m1_white_noise_archive_core"
const PLAYABLE_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t111_high_voltage_shielding"
)


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frame")


func _capture_frame() -> void:
	var game_state: GameStateModel = root.get_node_or_null(
		"GameState"
	) as GameStateModel
	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	if game_state == null or registry == null:
		printerr("[t111-visual] GameState or M1 registry is unavailable.")
		quit(1)
		return
	var shielding: ShipModuleDefinition = registry.find_module(
		ShipLoadoutRules.HIGH_VOLTAGE_SHIELDING_MODULE_ID
	)
	var order: OrderDefinition = registry.find_order(WHITE_ORDER_ID)
	if shielding == null or order == null:
		printerr("[t111-visual] Shielding or White Noise order is unavailable.")
		quit(1)
		return
	order = _make_playable_order(order)
	game_state.reset_runtime_state()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	game_state.ship_upgrade_ids.append(shielding.id)
	game_state.set_story_flag(
		&"story_m1_red_sand_shielding_retrofit_completed"
	)
	if (
		not game_state.accept_order(order)
		or not game_state.equip_ship_module(shielding)
	):
		printerr("[t111-visual] Could not prepare installed shielding state.")
		quit(1)
		return

	var scene: PackedScene = load(LOADOUT_SCENE_PATH) as PackedScene
	var loadout: ShipLoadoutUI = scene.instantiate() as ShipLoadoutUI
	loadout.set_game_state_override(game_state)
	loadout.set_order_definition(order)
	root.add_child(loadout)
	await _settle_frames(3)
	if not loadout.open_loadout():
		printerr("[t111-visual] Loadout could not open.")
		quit(1)
		return
	await _settle_frames(3)
	if not _save_frame("white_noise_shielding_installed.png"):
		quit(1)
		return
	loadout.queue_free()
	game_state.reset_runtime_state()
	await _settle_frames(2)
	print(
		"[t111-visual] PASS: saved installed story-module loadout frame."
	)
	quit(0)


func _make_playable_order(source: OrderDefinition) -> OrderDefinition:
	var fixture: OrderDefinition = source.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		source.destination_planet.duplicate(true) as PlanetDefinition
	)
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = PLAYABLE_ROUTE_PATH
	fixture.destination_planet = planet
	return fixture


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t111-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t111-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t111-visual] Could not save %s." % output_path)
		return false
	print("[t111-visual] Saved %s" % output_path)
	return true
