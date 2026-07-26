extends SceneTree

const LOADOUT_SCENE_PATH: String = "res://scenes/ui/ship_loadout.tscn"
const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const ORDER_TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const RED_SAND_FLIGHT_SCENE_PATH: String = (
	"res://scenes/flight/red_sand_flight.tscn"
)
const REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const CONTRACT_PATH: String = (
	"res://data/revisits/red_sand_revisit_contract.tres"
)
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t119_gate_e_round2"
)
const M0_ORDER_ID: StringName = &"order_red_sand_m0"
const M0_ORDER_ALIAS: StringName = &"order_red_sand_cooling_core"

var _original_locale: String = ""
var _original_paused: bool = false
var _game_state: GameStateModel
var _registry: GameDataRegistry
var _contract: RedSandRevisitContract


func _initialize() -> void:
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_paused = paused
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_contract = load(CONTRACT_PATH) as RedSandRevisitContract
	if _game_state == null or _registry == null or _contract == null:
		printerr("[t119-round2-visual] Runtime data is unavailable.")
		await _cleanup()
		quit(1)
		return

	if not await _capture_loadout():
		await _cleanup()
		quit(1)
		return
	if not await _capture_archive_states():
		await _cleanup()
		quit(1)
		return
	if not await _capture_order_history():
		await _cleanup()
		quit(1)
		return
	if not await _capture_revisit_cockpit():
		await _cleanup()
		quit(1)
		return
	if not await _capture_revisit_route():
		await _cleanup()
		quit(1)
		return

	await _cleanup()
	print(
		"[t119-round2-visual] PASS: saved 11 verified 640x360 Gate E Round 2 frames."
	)
	quit(0)


func _capture_loadout() -> bool:
	if not _prepare_accepted_revisit():
		return false
	var laser: ShipModuleDefinition = _registry.find_module(
		ShipLoadoutRules.LASER_MODULE_ID
	)
	if laser == null or not _game_state.equip_ship_module(laser):
		printerr("[t119-round2-visual] Laser fixture could not be installed.")
		return false
	var scene: PackedScene = load(LOADOUT_SCENE_PATH) as PackedScene
	var loadout: ShipLoadoutUI = scene.instantiate() as ShipLoadoutUI
	loadout.order_definition = _contract.order
	loadout.data_registry = _registry
	root.add_child(loadout)
	await _settle_frames(3)
	if (
		not loadout.open_loadout()
		or loadout.get_slot_name_text(
			ShipModuleDefinition.SlotType.UTILITY
		) != "陨石激光炮"
		or not loadout.get_slot_status_text(
			ShipModuleDefinition.SlotType.UTILITY
		).contains("本次订单不要求")
	):
		printerr("[t119-round2-visual] Loadout did not reach the Round 2 state.")
		await _cleanup_node(loadout)
		return false
	await _settle_frames(3)
	var saved: bool = _save_frame("01_loadout_laser_not_required.png")
	await _cleanup_node(loadout)
	return saved


func _capture_archive_states() -> bool:
	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await _settle_frames(4)
	var terminal: Interactable2D = station.get_archive_terminal_interactable()
	var player: StationPlayer = station.get_station_player()
	var presenter: StationStatePresenter = station.get_station_state_presenter()
	if terminal == null or player == null or presenter == null:
		printerr("[t119-round2-visual] Offline archive fixture is incomplete.")
		await _cleanup_node(station)
		return false
	player.position = terminal.position + Vector2(0.0, 58.0)
	player.set_facing_direction(terminal.position - player.position)
	await _settle_frames(3)
	if (
		not presenter.is_state_root_visible(
			StationStateRules.ARCHIVE_TERMINAL_ID
		)
		or presenter.is_archive_terminal_powered()
		or not _save_frame("02_archive_shell_offline.png")
	):
		await _cleanup_node(station)
		return false
	await _cleanup_node(station)

	_game_state.reset_runtime_state()
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	_game_state.unlock_station_state(StationStateRules.ARCHIVE_TERMINAL_ID)
	_game_state.set_story_flag(
		StationTutorialController.ARCHIVE_BRIEFING_PENDING_FLAG
	)
	station = station_scene.instantiate() as StationHub
	root.add_child(station)
	await _settle_frames(5)
	var tutorial: StationTutorialController = station.get_tutorial_controller()
	var dialogue_ui: DialogueUI = tutorial.get_dialogue_ui()
	if (
		tutorial.get_active_dialogue_id()
		!= &"dialogue_lao_pi_archive_terminal_briefing"
		or dialogue_ui == null
	):
		printerr("[t119-round2-visual] Archive activation dialogue did not start.")
		await _cleanup_node(station)
		return false
	dialogue_ui.quick_show_current_line()
	await _settle_frames(2)
	if not _save_frame("03_archive_activation_dialogue.png"):
		await _cleanup_node(station)
		return false
	if (
		dialogue_ui.skip_dialogue_sequence()
		!= DialogueRuntime.SequenceSkipResult.FINISHED
	):
		printerr("[t119-round2-visual] Archive activation could not finish.")
		await _cleanup_node(station)
		return false
	await _settle_frames(3)
	terminal = station.get_archive_terminal_interactable()
	player = station.get_station_player()
	presenter = station.get_station_state_presenter()
	player.position = terminal.position + Vector2(0.0, 58.0)
	player.set_facing_direction(terminal.position - player.position)
	await _settle_frames(2)
	var online_saved: bool = (
		presenter.is_archive_terminal_powered()
		and _save_frame("04_archive_terminal_online.png")
	)
	await _cleanup_node(station)
	return online_saved


func _capture_order_history() -> bool:
	_prepare_completed_history()
	var scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = scene.instantiate() as OrderTerminalUI
	terminal.data_registry = _registry
	root.add_child(terminal)
	await _settle_frames(3)
	if not terminal.open_terminal() or terminal.get_history_count() != 2:
		printerr("[t119-round2-visual] Two-row history did not open.")
		await _cleanup_node(terminal)
		return false
	if not terminal.select_order(M0_ORDER_ID):
		printerr("[t119-round2-visual] M0 history row could not open.")
		await _cleanup_node(terminal)
		return false
	await _settle_frames(2)
	if not _save_frame("05_history_m0.png"):
		await _cleanup_node(terminal)
		return false
	if not terminal.select_order(_contract.order.id):
		printerr("[t119-round2-visual] Revisit history row could not open.")
		await _cleanup_node(terminal)
		return false
	await _settle_frames(2)
	var saved: bool = _save_frame("06_history_revisit.png")
	await _cleanup_node(terminal)
	return saved


func _capture_revisit_cockpit() -> bool:
	if not _prepare_accepted_revisit():
		return false
	if (
		not _game_state.confirm_departure(_contract.order)
		or not _game_state.begin_travel(
			_contract.order,
			_contract.order.destination_planet.id
		)
		or not _game_state.advance_travel_state(
			GameStateModel.TravelState.CRUISE
		)
	):
		printerr("[t119-round2-visual] Revisit cockpit fixture could not travel.")
		return false
	var scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(5)
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	if (
		dialogue_ui == null
		or cockpit.get_active_dialogue_id()
		!= _contract.cockpit_travel_main_dialogue.id
	):
		printerr("[t119-round2-visual] Revisit cockpit dialogue did not start.")
		await _cleanup_node(cockpit)
		return false
	dialogue_ui.quick_show_current_line()
	await _settle_frames(2)
	var saved: bool = _save_frame("07_revisit_cockpit_dialogue.png")
	var fallback_layer: Node = dialogue_ui.get_parent()
	await _cleanup_node(cockpit)
	if (
		fallback_layer != null
		and is_instance_valid(fallback_layer)
		and fallback_layer.name == "CockpitDialogueFallbackLayer"
	):
		await _cleanup_node(fallback_layer)
	return saved


func _capture_revisit_route() -> bool:
	if not _prepare_accepted_revisit():
		return false
	var scene: PackedScene = load(RED_SAND_FLIGHT_SCENE_PATH) as PackedScene
	var route: RedSandFlight = scene.instantiate() as RedSandFlight
	root.add_child(route)
	await _settle_frames(5)
	route.close_controls_help()
	paused = false
	await _settle_frames(2)
	route.set_process(false)
	route.set_physics_process(false)
	var ship: FlightLabShip = route.get_flight_ship()
	var hud: RedSandRouteHUD = route.get_route_hud()
	if ship == null or hud == null:
		printerr("[t119-round2-visual] Revisit route fixture is incomplete.")
		await _cleanup_node(route)
		return false
	ship.set_physics_process(false)
	if (
		not hud.get_stage_text().contains("赤砂回访短航线 1/3")
		or not _save_frame("08_route_stage_1.png")
	):
		await _cleanup_node(route)
		return false
	ship.position.x = route.route_origin_x + 30510.0
	route.advance_route_state()
	route._process(0.0)
	await _settle_frames(2)
	if (
		not hud.get_stage_text().contains("赤砂回访短航线 2/3")
		or not _save_frame("09_route_stage_2.png")
	):
		await _cleanup_node(route)
		return false
	ship.position.x = route.route_origin_x + 33010.0
	route.advance_route_state()
	route._process(0.0)
	await _settle_frames(2)
	if (
		not hud.get_stage_text().contains("赤砂回访短航线 3/3")
		or not _save_frame("10_route_stage_3.png")
	):
		await _cleanup_node(route)
		return false
	hud.show_controls_help(false, true)
	await _settle_frames(2)
	var saved: bool = _save_frame("11_route_controls_help.png")
	hud.hide_controls_help()
	await _cleanup_node(route)
	return saved


func _prepare_accepted_revisit() -> bool:
	_game_state.reset_runtime_state()
	_game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	_game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	_game_state.completed_order_ids[M0_ORDER_ID] = true
	_game_state.order_states[M0_ORDER_ID] = GameStateModel.OrderStatus.COMPLETED
	_game_state.reward_applied_order_ids.append(M0_ORDER_ID)
	_game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)
	_game_state.set_story_flag(&"story_red_sand_order_completed")
	if not _game_state.accept_order(_contract.order):
		return false
	_game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		_contract.accepted_state_id
	)
	return true


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


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t119-round2-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t119-round2-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t119-round2-visual] Could not save %s." % output_path)
		return false
	print("[t119-round2-visual] Saved %s" % output_path)
	return true


func _cleanup_node(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _settle_frames(2)


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _cleanup() -> void:
	paused = _original_paused
	if _game_state != null:
		_game_state.reset_runtime_state()
	TranslationServer.set_locale(_original_locale)
