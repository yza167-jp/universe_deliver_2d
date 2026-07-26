extends SceneTree

const ORDER_TERMINAL_SCENE_PATH: String = (
	"res://scenes/ui/order_terminal.tscn"
)
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTENT_PATH: String = (
	"res://data/orders/white_noise_main_order_content.tres"
)
const WHITE_NOISE_FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/white_noise_flight.tscn"
)
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _content: WhiteNoiseMainOrderContent


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_content = load(CONTENT_PATH) as WhiteNoiseMainOrderContent
	_check(_game_state != null, "T-122 smoke requires GameState.")
	_check(_registry != null, "T-122 smoke requires the M1 registry.")
	_check(_content != null, "T-122 smoke requires White Noise content.")
	if _game_state == null or _registry == null or _content == null:
		_finish()
		return
	_prepare_white_noise_progress()
	await _check_order_terminal()
	await _check_cockpit_content()
	_finish()


func _check_order_terminal() -> void:
	var scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	terminal.set_game_state_override(_game_state)
	terminal.set_order_definition(_content.order)
	root.add_child(terminal)
	await _settle_frames(3)
	_check(
		terminal.open_terminal(),
		"T-122 White Noise order detail could not open."
	)
	await _settle_frames(2)
	_check(
		terminal.get_selected_order_id() == _content.order.id
		and terminal.get_order_name_text().contains("白噪")
		and terminal.get_parties_text().contains("公司档案服务")
		and terminal.get_route_text().contains("风险 4/5")
		and terminal.get_required_modules_text().contains("特高压电屏蔽罩")
		and terminal.get_recommended_modules_text().contains("护盾备用电源")
		and terminal.get_cargo_text().contains("公司记录")
		and terminal.get_cargo_text().contains("标准核心组件")
		and terminal.get_cargo_text().contains("实际用途")
		and terminal.get_cargo_text().contains("批量访问接口")
		and terminal.get_customer_history_text().contains("最小访问原则")
		and terminal.get_customer_history_text().contains("具体家庭与个人记忆")
		and terminal.get_feedback_text().contains("正式航路仍在校准")
		and not terminal.is_accept_enabled()
		and VIEWPORT_RECT.encloses(terminal.get_panel_rect()),
		"The departure brief did not expose risks, cargo framing, local use, and history in 640x360."
	)
	await _cleanup_node(terminal)


func _check_cockpit_content() -> void:
	if not _prepare_travel_fixture():
		return
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(5)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	_check(
		dialogue_ui != null
		and cockpit.get_active_dialogue_id()
		== _content.cockpit_travel_main_dialogue.id
		and dialogue_ui.get_full_text().contains("强重力进场")
		and dialogue_ui.get_full_text().contains("电磁暴雪")
		and cockpit.get_travel_phase_text().contains("深空巡航")
		and cockpit.get_travel_detail_text().contains("货舱冷核"),
		"White Noise travel did not start its dedicated mandatory content."
	)
	if dialogue_ui == null:
		await _cleanup_node(cockpit)
		return
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"White Noise mandatory dialogue could not finish."
	)
	await _settle_frames(2)
	_check(
		_game_state.has_story_flag(
			_content.cockpit_travel_completion_flag
		)
		and not _game_state.has_story_flag(
			Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG
		),
		"White Noise mandatory content did not keep an independent completion flag."
	)
	_check(
		cockpit.activate_hotspot(&"lao_pi_seat")
		and cockpit.get_active_dialogue_id()
		== _content.cockpit_manual_dialogue.id
		and dialogue_ui.get_full_text().contains("1.28g"),
		"Lao Pi's seat did not expose the White Noise gravity and shielding brief."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _settle_frames(2)
	_check(
		cockpit.activate_hotspot(&"radio")
		and cockpit.get_active_dialogue_id()
		== _content.cockpit_travel_radio_dialogue.id
		and dialogue_ui.get_full_text().contains("标准化档案服务"),
		"The radio did not expose the company archive-service framing."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _settle_frames(2)
	_check(
		cockpit.activate_hotspot(&"cargo_indicator")
		and cockpit.get_active_dialogue_id()
		== _content.cockpit_travel_cargo_dialogue.id
		and dialogue_ui.get_full_text().contains("批量访问接口"),
		"The cargo hotspot did not expose the cryocore access consequence."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _settle_frames(2)
	_check(
		cockpit.activate_hotspot(&"company_terminal")
		and cockpit.get_device_panel_body().contains("标准档案服务组件")
		and cockpit.get_device_panel_body().contains("批量访问接口"),
		"The company terminal did not retain its concrete service framing."
	)
	cockpit.close_active_modal()
	await _settle_frames(1)
	_check(
		cockpit.activate_hotspot(&"cargo_indicator")
		and cockpit.get_device_panel_body().contains("只恢复获准索引")
		and cockpit.get_device_panel_body().contains("不代表获得公开授权"),
		"The cargo panel did not retain the local minimum-access seal."
	)
	var combined_text: String = "\n".join(PackedStringArray([
		cockpit.get_travel_phase_text(),
		cockpit.get_travel_detail_text(),
		cockpit.get_device_panel_body(),
	]))
	_check(
		not combined_text.contains("赤砂")
		and not combined_text.contains("维修服务航道")
		and VIEWPORT_RECT.encloses(cockpit.get_global_rect()),
		"White Noise cockpit content leaked revisit copy or escaped 640x360."
	)
	await _cleanup_node(cockpit)


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
		_check(
			_game_state.equip_ship_module(module),
			"T-122 fixture could not equip required module '%s'." % module.id
		)


func _prepare_travel_fixture() -> bool:
	_prepare_white_noise_progress()
	var fixture: OrderDefinition = _content.order.duplicate(true) as OrderDefinition
	var fixture_planet: PlanetDefinition = (
		_content.order.destination_planet.duplicate(true) as PlanetDefinition
	)
	if fixture == null or fixture_planet == null:
		_check(false, "T-122 could not duplicate a playable travel fixture.")
		return false
	fixture.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	fixture.required_chapter = &""
	fixture.unlock_conditions.clear()
	fixture.story_requirements.clear()
	fixture_planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	fixture_planet.flight_scene_path = WHITE_NOISE_FLIGHT_SCENE_PATH
	fixture.destination_planet = fixture_planet
	var prepared: bool = (
		_game_state.accept_order(fixture)
		and _game_state.confirm_departure(fixture)
		and _game_state.begin_travel(fixture, fixture_planet.id)
		and _game_state.advance_travel_state(
			GameStateModel.TravelState.CRUISE
		)
	)
	_check(prepared, "T-122 could not prepare White Noise cockpit travel.")
	return prepared


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _settle_frames(2)


func _finish() -> void:
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t122-white-noise-content] PASS: departure brief, independent "
			+ "cockpit dialogues, company/local framing, and 640x360 containment."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t122-white-noise-content] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
