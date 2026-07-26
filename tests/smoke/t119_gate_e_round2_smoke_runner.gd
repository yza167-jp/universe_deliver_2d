extends SceneTree

const LOADOUT_SCENE_PATH: String = "res://scenes/ui/ship_loadout.tscn"
const ORDER_TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const RED_SAND_FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/red_sand_flight.tscn"
)
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const M0_ORDER_ALIAS: StringName = &"order_red_sand_cooling_core"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const REQUIRED_FONT_NAMES: PackedStringArray = [
	"PingFang SC",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"sans-serif",
]
const FONT_SCENES: Array[Dictionary] = [
	{
		"name": "station",
		"path": "res://scenes/station/station_hub.tscn",
	},
	{
		"name": "order terminal",
		"path": "res://scenes/ui/order_terminal.tscn",
	},
	{
		"name": "ship loadout",
		"path": "res://scenes/ui/ship_loadout.tscn",
	},
	{
		"name": "cockpit",
		"path": "res://scenes/cockpit/cockpit.tscn",
	},
	{
		"name": "dialogue",
		"path": "res://scenes/narrative/dialogue_ui.tscn",
	},
	{
		"name": "archive browser",
		"path": "res://scenes/ui/codex_browser.tscn",
	},
	{
		"name": "arrival",
		"path": "res://scenes/arrival/red_sand_arrival.tscn",
	},
	{
		"name": "results",
		"path": "res://scenes/app/results.tscn",
	},
	{
		"name": "debug status",
		"path": "res://scenes/ui/m1_debug_status.tscn",
	},
	{
		"name": "route HUD",
		"path": "res://scenes/ui/red_sand_route_hud.tscn",
	},
	{
		"name": "flight controls help",
		"path": "res://scenes/ui/flight_controls_help.tscn",
	},
]

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _original_paused: bool = false
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _contract: RedSandRevisitContract


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_paused = paused
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as RedSandRevisitContract
	_check(_game_state != null, "Gate E Round 2 smoke requires GameState.")
	_check(_registry != null, "Gate E Round 2 smoke requires the M1 registry.")
	_check(_contract != null, "Gate E Round 2 smoke requires the revisit contract.")
	if _game_state == null or _registry == null or _contract == null:
		_finish()
		return

	await _check_loadout_semantics()
	await _check_history_browsing()
	await _check_revisit_cockpit()
	await _check_revisit_route()
	await _check_gate_e_font_contracts()
	_finish()


func _check_loadout_semantics() -> void:
	if not _prepare_accepted_revisit():
		return
	var laser: ShipModuleDefinition = _registry.find_module(
		ShipLoadoutRules.LASER_MODULE_ID
	)
	_check(
		laser != null and _game_state.equip_ship_module(laser),
		"Round 2 loadout fixture could not install the asteroid laser."
	)
	if laser == null:
		return
	var scene: PackedScene = load(LOADOUT_SCENE_PATH) as PackedScene
	var loadout: ShipLoadoutUI = scene.instantiate() as ShipLoadoutUI
	_check(loadout != null, "Round 2 ship loadout scene did not instantiate.")
	if loadout == null:
		return
	loadout.order_definition = _contract.order
	loadout.data_registry = _registry
	root.add_child(loadout)
	await _wait_frames(2)
	_check(loadout.open_loadout(), "Round 2 ship loadout did not open.")
	await process_frame
	var utility_name: String = loadout.get_slot_name_text(
		ShipModuleDefinition.SlotType.UTILITY
	)
	var utility_description: String = loadout.get_slot_description_text(
		ShipModuleDefinition.SlotType.UTILITY
	)
	var utility_status: String = loadout.get_slot_status_text(
		ShipModuleDefinition.SlotType.UTILITY
	)
	_check(
		utility_name == "陨石激光炮"
		and utility_description.contains("陨石")
		and utility_status.contains("本次订单不要求")
		and utility_status.contains("已安装")
		and not utility_name.contains("本次订单不使用")
		and not utility_description.contains("本次订单不使用")
		and _game_state.get_missing_required_modules(_contract.order).is_empty()
		and VIEWPORT_RECT.encloses(loadout.get_panel_rect()),
		"Utility A did not separate the real laser identity, order role, install state, and required-module gate."
	)
	_check(
		loadout.toggle_module_for_slot(
			ShipModuleDefinition.SlotType.UTILITY
		)
		and loadout.get_slot_name_text(
			ShipModuleDefinition.SlotType.UTILITY
		) == "陨石激光炮"
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.UTILITY
		).contains("本次订单不要求")
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.UTILITY
		).contains("已拥有")
		and loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.UTILITY
		).contains("未安装")
		and _game_state.get_missing_required_modules(_contract.order).is_empty(),
		"An order that does not require the laser could not keep it manageable without changing required modules."
	)
	_check(
		loadout.toggle_module_for_slot(
			ShipModuleDefinition.SlotType.UTILITY
		)
		and _game_state.is_ship_module_equipped(
			ShipLoadoutRules.LASER_MODULE_ID
		),
		"The owned asteroid laser could not be reinstalled."
	)
	_check_visible_text_glyphs(loadout, "ship loadout")
	await _cleanup_node(loadout)


func _check_history_browsing() -> void:
	_prepare_completed_history()
	var scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	_check(terminal != null, "Round 2 order terminal scene did not instantiate.")
	if terminal == null:
		return
	terminal.data_registry = _registry
	root.add_child(terminal)
	await _wait_frames(2)
	_check(terminal.open_terminal(), "Round 2 order terminal did not open.")
	await process_frame
	_check(
		terminal.get_history_count() == 2
		and terminal.get_directory_button(M0_ORDER_ID) != null
		and terminal.get_directory_button(_contract.order.id) != null
		and terminal.get_directory_button(M0_ORDER_ALIAS) == null
		and VIEWPORT_RECT.encloses(terminal.get_panel_rect()),
		"The order directory did not expose exactly the M0 and revisit history rows."
	)
	_check(
		terminal.select_order(M0_ORDER_ID)
		and terminal.get_order_name_text().contains("赤砂")
		and terminal.get_status_text() == "已完成"
		and terminal.get_parties_text().contains("公司调度")
		and terminal.get_parties_text().contains("伊娅")
		and terminal.get_route_text().contains("赤砂星")
		and terminal.get_reward_text().contains("信用点")
		and terminal.get_cargo_text().contains("深层冷却泵核心")
		and terminal.get_customer_history_text().contains("首次赤砂配送完成")
		and terminal.get_customer_history_text().contains(
			"详细飞行结算未保留"
		)
		and terminal.get_accept_button_text() == "只读历史"
		and not terminal.is_accept_enabled(),
		"The completed M0 row did not open a complete read-only history detail."
	)
	_check(
		terminal.select_order(_contract.order.id)
		and terminal.get_order_name_text() == "旧铭牌的新外壳"
		and terminal.get_status_text() == "已完成"
		and terminal.get_parties_text().contains("伊娅")
		and terminal.get_route_text().contains("赤砂星")
		and terminal.get_reward_text().contains("140")
		and terminal.get_cargo_text().contains("中继纹屏蔽材料")
		and terminal.get_customer_history_text().contains("完整记录保留在本地")
		and terminal.get_customer_history_text().contains(
			"详细飞行结算未保留"
		)
		and terminal.get_accept_button_text() == "只读历史"
		and not terminal.is_accept_enabled(),
		"The completed revisit row did not open its known choice and read-only detail."
	)
	_check_visible_text_glyphs(terminal, "order history")
	await _cleanup_node(terminal)


func _check_revisit_cockpit() -> void:
	if not _prepare_accepted_revisit():
		return
	_check(
		_game_state.confirm_departure(_contract.order)
		and _game_state.begin_travel(
			_contract.order,
			_contract.order.destination_planet.id
		)
		and _game_state.advance_travel_state(
			GameStateModel.TravelState.CRUISE
		),
		"Round 2 cockpit fixture could not begin revisit travel."
	)
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	_check(cockpit != null, "Round 2 cockpit scene did not instantiate.")
	if cockpit == null:
		return
	root.add_child(cockpit)
	await _wait_frames(5)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	_check(
		dialogue_ui != null
		and cockpit.get_active_dialogue_id()
		== _contract.cockpit_travel_main_dialogue.id
		and dialogue_ui.get_full_text().contains("维修服务航道")
		and cockpit.get_travel_phase_text().contains("运行设施巡检")
		and cockpit.get_travel_detail_text().contains("安全走廊"),
		"Revisit departure did not use its mandatory dialogue and travel-phase text."
	)
	if dialogue_ui == null:
		await _cleanup_node(cockpit)
		return
	_check(
		dialogue_ui.skip_dialogue_sequence()
		== DialogueRuntime.SequenceSkipResult.FINISHED,
		"Revisit mandatory cockpit dialogue could not finish."
	)
	await _wait_frames(2)
	_check(
		_game_state.has_story_flag(
			_contract.cockpit_travel_completion_flag
		)
		and not _game_state.has_story_flag(
			Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG
		),
		"Revisit mandatory dialogue overwrote the M0 travel completion flag."
	)
	_check(
		cockpit.activate_hotspot(&"lao_pi_seat")
		and cockpit.get_active_dialogue_id()
		== _contract.cockpit_manual_dialogue.id
		and dialogue_ui.get_full_text().contains("完整进近"),
		"Lao Pi's revisit seat dialogue reused or lost the short-route explanation."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _wait_frames(2)
	_check(
		cockpit.activate_hotspot(&"radio")
		and cockpit.get_active_dialogue_id()
		== _contract.cockpit_travel_radio_dialogue.id
		and dialogue_ui.get_full_text().contains("设备兼容性复核"),
		"Revisit radio did not use its company-review dialogue."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _wait_frames(2)
	_check(
		cockpit.activate_hotspot(&"cargo_indicator")
		and cockpit.get_active_dialogue_id()
		== _contract.cockpit_travel_cargo_dialogue.id
		and dialogue_ui.get_full_text().contains("屏蔽材料"),
		"Revisit cargo hotspot did not use its shielding-material dialogue."
	)
	dialogue_ui.skip_dialogue_sequence()
	await _wait_frames(2)
	_check(
		cockpit.activate_hotspot(&"company_terminal")
		and cockpit.get_device_panel_body().contains("设备兼容性复核")
		and cockpit.get_device_panel_body().contains("完整进近已备案"),
		"Revisit company terminal did not expose the bounded compatibility review."
	)
	cockpit.close_active_modal()
	await process_frame
	_check(
		cockpit.activate_hotspot(&"cargo_indicator")
		and cockpit.get_device_panel_body().contains("中继纹屏蔽材料")
		and cockpit.get_device_panel_body().contains("伊娅"),
		"Revisit cargo panel did not retain its specific material and Iya request."
	)
	var combined_text: String = "\n".join(PackedStringArray([
		cockpit.get_travel_phase_text(),
		cockpit.get_travel_detail_text(),
		cockpit.get_device_panel_body(),
	]))
	_check(
		not combined_text.contains("第一次前往边境")
		and not combined_text.contains("失联维修机器人"),
		"Revisit cockpit still exposed first-delivery or missing-robot copy."
	)
	_check_visible_text_glyphs(cockpit, "revisit cockpit")
	await _cleanup_node(cockpit)


func _check_revisit_route() -> void:
	if not _prepare_accepted_revisit():
		return
	var scene: PackedScene = load(RED_SAND_FLIGHT_SCENE_PATH) as PackedScene
	var route: RedSandFlight = scene.instantiate() as RedSandFlight
	_check(route != null, "Round 2 Red Sand route scene did not instantiate.")
	if route == null:
		return
	root.add_child(route)
	await _wait_frames(5)
	route.close_controls_help()
	paused = false
	route.set_process(false)
	route.set_physics_process(false)
	var ship: FlightLabShip = route.get_flight_ship()
	var hud: RedSandRouteHUD = route.get_route_hud()
	_check(ship != null and hud != null, "Round 2 revisit route dependencies are missing.")
	if ship == null or hud == null:
		await _cleanup_node(route)
		return
	ship.set_physics_process(false)
	_check_revisit_stage(
		route,
		hud,
		1,
		"维修服务航道",
		["完整进近", "后段安全走廊", "净水", "冷却"]
	)
	ship.position.x = route.route_origin_x + 30510.0
	route.advance_route_state()
	route._process(0.0)
	_check_revisit_stage(
		route,
		hud,
		2,
		"屏蔽材料与维修场观察",
		["屏蔽材料", "进场状态"]
	)
	ship.position.x = route.route_origin_x + 33010.0
	route.advance_route_state()
	route._process(0.0)
	_check_revisit_stage(
		route,
		hud,
		3,
		"变化后的维修场着陆",
		["维修场", "着陆"]
	)
	hud.show_company_warning(
		&"UI_FLIGHT_COMPANY_WARNING_CARGO_MEDIUM",
		88.0
	)
	hud.show_controls_help(false, true)
	await process_frame
	_check_visible_text_glyphs(hud, "revisit route HUD and controls help")
	hud.hide_controls_help()
	await _cleanup_node(route)


func _check_revisit_stage(
	route: RedSandFlight,
	hud: RedSandRouteHUD,
	local_stage: int,
	expected_name: String,
	required_phrases: Array[String]
) -> void:
	var stage_text: String = hud.get_stage_text()
	var instruction_text: String = hud.get_instruction_text()
	var valid: bool = route.is_revisit_route()
	valid = valid and stage_text.contains(
		"赤砂回访短航线 %d/3" % local_stage
	)
	valid = valid and stage_text.contains(expected_name)
	for phrase: String in required_phrases:
		valid = valid and instruction_text.contains(phrase)
	valid = (
		valid
		and not stage_text.contains("星系外缘")
		and not stage_text.contains("陨石带")
		and not stage_text.contains("大气边缘")
	)
	_check(
		valid,
		"Revisit route stage %d did not use its dedicated name and objective: %s | %s."
		% [local_stage, stage_text, instruction_text]
	)


func _check_gate_e_font_contracts() -> void:
	var codepoints: PackedInt32Array = _load_chinese_codepoints()
	_check(
		not codepoints.is_empty(),
		"Gate E font coverage could not collect Chinese localization characters."
	)
	if codepoints.is_empty():
		return
	for scene_contract: Dictionary in FONT_SCENES:
		var scene_path: String = String(scene_contract.get("path", ""))
		var scene_name: String = String(scene_contract.get("name", scene_path))
		var packed_scene: PackedScene = load(scene_path) as PackedScene
		_check(
			packed_scene != null,
			"Gate E font scene could not load: %s." % scene_path
		)
		if packed_scene == null:
			continue
		var scene_root: Node = packed_scene.instantiate()
		_check(
			scene_root != null,
			"Gate E font scene could not instantiate: %s." % scene_path
		)
		if scene_root == null:
			continue
		var themes: Array[Theme] = []
		_collect_themes(scene_root, themes)
		_check(
			not themes.is_empty(),
			"Gate E scene '%s' has no explicit SystemFont theme." % scene_name
		)
		for theme: Theme in themes:
			var font: SystemFont = theme.default_font as SystemFont
			_check(
				font != null
				and
				font.font_names == REQUIRED_FONT_NAMES
				and font.allow_system_fallback,
				"Gate E scene '%s' does not use the required Chinese fallback chain."
				% scene_name
			)
			if font == null:
				continue
			var probe: Label = Label.new()
			probe.theme = theme
			probe.text = _build_codepoint_probe(codepoints)
			root.add_child(probe)
			await process_frame
			var resolved_font: Font = probe.get_theme_font(&"font")
			var missing_characters: PackedStringArray = []
			for codepoint: int in codepoints:
				if resolved_font == null or not resolved_font.has_char(codepoint):
					missing_characters.append(String.chr(codepoint))
					if missing_characters.size() >= 8:
						break
			_check(
				missing_characters.is_empty(),
				"Gate E scene '%s' font lacks Chinese glyphs: %s."
				% [scene_name, "".join(missing_characters)]
			)
			probe.queue_free()
			await process_frame
		scene_root.free()


func _collect_themes(node: Node, themes: Array[Theme]) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.theme != null and control.theme.default_font is SystemFont:
			if not themes.has(control.theme):
				themes.append(control.theme)
	for child: Node in node.get_children():
		_collect_themes(child, themes)


func _build_codepoint_probe(codepoints: PackedInt32Array) -> String:
	var characters: PackedStringArray = []
	for codepoint: int in codepoints:
		characters.append(String.chr(codepoint))
	return "".join(characters)


func _load_chinese_codepoints() -> PackedInt32Array:
	var file: FileAccess = FileAccess.open(LOCALIZATION_PATH, FileAccess.READ)
	if file == null:
		return PackedInt32Array()
	var headers: PackedStringArray = file.get_csv_line()
	var chinese_column: int = headers.find("zh_CN")
	if chinese_column < 0:
		return PackedInt32Array()
	var unique: Dictionary[int, bool] = {}
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() != headers.size():
			continue
		var message: String = row[chinese_column]
		for index: int in message.length():
			var codepoint: int = message.unicode_at(index)
			if _is_chinese_codepoint(codepoint):
				unique[codepoint] = true
	var codepoints: PackedInt32Array = PackedInt32Array()
	for codepoint: int in unique:
		codepoints.append(codepoint)
	codepoints.sort()
	return codepoints


func _is_chinese_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 0x3400 and codepoint <= 0x4dbf)
		or (codepoint >= 0x4e00 and codepoint <= 0x9fff)
		or (codepoint >= 0xf900 and codepoint <= 0xfaff)
	)


func _check_visible_text_glyphs(node: Node, surface_name: String) -> void:
	var checked_controls: int = _check_node_text_glyphs(node, surface_name)
	_check(
		checked_controls > 0,
		"Gate E surface '%s' exposed no Chinese text for glyph verification."
		% surface_name
	)


func _check_node_text_glyphs(node: Node, surface_name: String) -> int:
	var checked_controls: int = 0
	var text: String = ""
	var font_key: StringName = &"font"
	if node is RichTextLabel:
		text = (node as RichTextLabel).text
		font_key = &"normal_font"
	elif node is Label:
		text = (node as Label).text
	elif node is Button:
		text = (node as Button).text
	if node is Control and _contains_chinese(text):
		checked_controls += 1
		var font: Font = (node as Control).get_theme_font(font_key)
		var missing: PackedStringArray = []
		for index: int in text.length():
			var codepoint: int = text.unicode_at(index)
			if _is_chinese_codepoint(codepoint) and (
				font == null or not font.has_char(codepoint)
			):
				var character: String = String.chr(codepoint)
				if not missing.has(character):
					missing.append(character)
		_check(
			missing.is_empty(),
			"Gate E surface '%s' rendered Chinese text with missing glyphs: %s."
			% [surface_name, "".join(missing)]
		)
	for child: Node in node.get_children():
		checked_controls += _check_node_text_glyphs(child, surface_name)
	return checked_controls


func _contains_chinese(text: String) -> bool:
	for index: int in text.length():
		if _is_chinese_codepoint(text.unicode_at(index)):
			return true
	return false


func _prepare_accepted_revisit() -> bool:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	_game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	_game_state.completed_order_ids[M0_ORDER_ID] = true
	_game_state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	_game_state.reward_applied_order_ids.append(M0_ORDER_ID)
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	var accepted: bool = _game_state.accept_order(_contract.order)
	if accepted:
		_game_state.set_revisit_state(
			M1ProgressRules.PLANET_RED_SAND,
			_contract.accepted_state_id
		)
	_check(accepted, "Gate E Round 2 could not prepare the accepted revisit.")
	return accepted


func _prepare_completed_history() -> void:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	_game_state.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	for order_id: StringName in [
		M0_ORDER_ID,
		M0_ORDER_ALIAS,
		_contract.order.id,
	]:
		_game_state.completed_order_ids[order_id] = true
		_game_state.order_states[order_id] = GameStateModel.OrderStatus.COMPLETED
	_game_state.set_story_flag(_contract.keep_local_record_flag)
	_game_state.set_story_flag(
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	)


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _wait_frames(2)


func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _finish() -> void:
	paused = _original_paused
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[t119-gate-e-round2] PASS: loadout semantics, archive-ready history, "
			+ "revisit cockpit, three-stage service lane, and Chinese glyph coverage."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t119-gate-e-round2] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
