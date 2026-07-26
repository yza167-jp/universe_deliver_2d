extends SceneTree

const TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTENT_PATH: String = (
	"res://data/orders/white_noise_main_order_content.tres"
)
const WHITE_NOISE_FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/white_noise_flight.tscn"
)
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t122_white_noise_content"
)

var _original_locale: String = ""
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _content: WhiteNoiseMainOrderContent


func _initialize() -> void:
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_content = load(CONTENT_PATH) as WhiteNoiseMainOrderContent
	if _game_state == null or _registry == null or _content == null:
		_fail("Runtime data is unavailable.")
		return
	_prepare_white_noise_progress()
	if not await _capture_order_brief():
		_fail("Order brief captures failed.")
		return
	if not await _capture_cockpit_content():
		_fail("Cockpit content captures failed.")
		return
	_restore_runtime()
	print(
		"[t122-visual] PASS: saved 6 verified 640x360 White Noise content frames."
	)
	quit(0)


func _capture_order_brief() -> bool:
	var scene: PackedScene = load(TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	terminal.set_game_state_override(_game_state)
	terminal.set_order_definition(_content.order)
	root.add_child(terminal)
	await _settle_frames(3)
	if (
		not terminal.open_terminal()
		or terminal.get_selected_order_id() != _content.order.id
	):
		await _cleanup_node(terminal)
		return false
	await _settle_frames(3)
	if not _save_frame("01_order_brief.png"):
		await _cleanup_node(terminal)
		return false
	var body_scroll: ScrollContainer = terminal.get_node_or_null(
		"%BodyScroll"
	) as ScrollContainer
	if body_scroll == null:
		await _cleanup_node(terminal)
		return false
	body_scroll.scroll_vertical = 260
	await _settle_frames(3)
	if not _save_frame("02_cargo_context.png"):
		await _cleanup_node(terminal)
		return false
	body_scroll.scroll_vertical = 1000
	await _settle_frames(3)
	var saved: bool = _save_frame("03_customer_history.png")
	await _cleanup_node(terminal)
	return saved


func _capture_cockpit_content() -> bool:
	if not _prepare_travel_fixture():
		return false
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(5)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	if (
		dialogue_ui == null
		or cockpit.get_active_dialogue_id()
		!= _content.cockpit_travel_main_dialogue.id
	):
		await _cleanup_node(cockpit)
		return false
	dialogue_ui.quick_show_current_line()
	await _settle_frames(2)
	if not _save_frame("04_travel_dialogue.png"):
		await _cleanup_node(cockpit)
		return false
	if (
		dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.FINISHED
	):
		await _cleanup_node(cockpit)
		return false
	await _settle_frames(2)
	if not cockpit.activate_hotspot(&"company_terminal"):
		await _cleanup_node(cockpit)
		return false
	await _settle_frames(2)
	if not _save_frame("05_company_terminal.png"):
		await _cleanup_node(cockpit)
		return false
	cockpit.close_active_modal()
	await _settle_frames(1)
	if not cockpit.activate_hotspot(&"cargo_indicator"):
		await _cleanup_node(cockpit)
		return false
	dialogue_ui.quick_show_current_line()
	dialogue_ui.skip_dialogue_sequence()
	await _settle_frames(2)
	if not cockpit.activate_hotspot(&"cargo_indicator"):
		await _cleanup_node(cockpit)
		return false
	await _settle_frames(2)
	var saved: bool = _save_frame("06_cargo_local_seal.png")
	await _cleanup_node(cockpit)
	return saved


func _prepare_white_noise_progress() -> void:
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
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	_game_state.set_story_flag(
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	)
	for module: ShipModuleDefinition in _content.order.required_modules:
		if module == null:
			continue
		if not _game_state.ship_upgrade_ids.has(module.id):
			_game_state.ship_upgrade_ids.append(module.id)
		if not _game_state.equip_ship_module(module):
			printerr(
				"[t122-visual] Could not equip required module '%s'."
				% module.id
			)


func _prepare_travel_fixture() -> bool:
	_prepare_white_noise_progress()
	var fixture: OrderDefinition = _content.order.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		_content.order.destination_planet.duplicate(true) as PlanetDefinition
	)
	if fixture == null or planet == null:
		return false
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture.required_chapter = &""
	fixture.unlock_conditions.clear()
	fixture.story_requirements.clear()
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = WHITE_NOISE_FLIGHT_SCENE_PATH
	fixture.destination_planet = planet
	return (
		_game_state.accept_order(fixture)
		and _game_state.confirm_departure(fixture)
		and _game_state.begin_travel(fixture, planet.id)
		and _game_state.advance_travel_state(
			GameStateModel.TravelState.CRUISE
		)
	)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _settle_frames(2)


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		return false
	print("[t122-visual] Saved %s" % output_path)
	return true


func _restore_runtime() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)


func _fail(message: String) -> void:
	printerr("[t122-visual] FAIL: %s" % message)
	_restore_runtime()
	quit(1)
