extends SceneTree

const EXPRESS_HUD_SCENE_PATH: String = "res://scenes/ui/express_order_hud.tscn"
const RED_SAND_HUD_SCENE_PATH: String = "res://scenes/ui/red_sand_route_hud.tscn"
const DIALOGUE_UI_SCENE_PATH: String = "res://scenes/narrative/dialogue_ui.tscn"
const DIALOGUE_SEQUENCE_PATH: String = (
	"res://data/dialogue/lao_pi_system_test.tres"
)
const ORDER_TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const RESULTS_SCENE_PATH: String = "res://scenes/app/results.tscn"
const TIDAL_EXPRESS_ORDER_PATH: String = (
	"res://data/orders/side_tidal_beacon_before_eye.tres"
)
const TEST_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t108_express"


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	var registered_order: OrderDefinition = load(
		TIDAL_EXPRESS_ORDER_PATH
	) as OrderDefinition
	var fixture: OrderDefinition = _make_playable_fixture(registered_order)
	if fixture == null:
		printerr("[t108-visual] Express fixture is unavailable.")
		quit(1)
		return
	if not await _capture_hud(fixture):
		quit(1)
		return
	if not await _capture_modal_pauses(fixture):
		quit(1)
		return
	if not await _capture_terminal(fixture):
		quit(1)
		return
	if not await _capture_results(fixture):
		quit(1)
		return
	print(
		"[t108-visual] PASS: saved HUD, modal pauses, terminal, "
		+ "and settlement frames."
	)
	quit(0)


func _capture_hud(order: OrderDefinition) -> bool:
	var frame: Control = _make_frame(Color("171a2b"))
	var route_scene: PackedScene = load(RED_SAND_HUD_SCENE_PATH) as PackedScene
	var route_hud: RedSandRouteHUD = route_scene.instantiate() as RedSandRouteHUD
	frame.add_child(route_hud)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 10
	frame.add_child(canvas)
	var hud_scene: PackedScene = load(EXPRESS_HUD_SCENE_PATH) as PackedScene
	var hud: ExpressOrderHUD = hud_scene.instantiate() as ExpressOrderHUD
	canvas.add_child(hud)
	var game_state: GameStateModel = GameStateModel.new()
	if not game_state.accept_order(order):
		printerr("[t108-visual] Express HUD fixture could not accept its order.")
		return false
	game_state.order_run_state.elapsed_time = 150.0
	root.add_child(frame)
	await _settle_frames(3)
	hud.set_process(false)
	hud.set_game_state_override(game_state)
	hud.set_order_override(order)
	hud.set_pause_state_override(false, false, false)
	await _settle_frames(2)
	if (
		not hud.is_timing_visible()
		or not hud.get_primary_text().contains("02:30")
		or not hud.get_secondary_text().contains("75%")
	):
		printerr(
			"[t108-visual] Express HUD did not render its grace state: %s / %s."
			% [hud.get_primary_text(), hud.get_secondary_text()]
		)
		return false
	if not _save_frame("express_hud_grace.png"):
		return false
	hud.set_pause_state_override(false, false, true)
	await _settle_frames(2)
	if not _save_frame("express_hud_paused.png"):
		return false
	frame.queue_free()
	await _settle_frames(2)
	game_state.free()
	return true


func _capture_modal_pauses(order: OrderDefinition) -> bool:
	var dialogue_state: GameStateModel = GameStateModel.new()
	dialogue_state.accept_order(order)
	dialogue_state.order_run_state.elapsed_time = 42.0
	var dialogue_frame: Control = _make_frame(Color("171a2b"))
	var dialogue_canvas: CanvasLayer = CanvasLayer.new()
	dialogue_canvas.layer = 10
	dialogue_frame.add_child(dialogue_canvas)
	var hud_scene: PackedScene = load(EXPRESS_HUD_SCENE_PATH) as PackedScene
	var dialogue_hud: ExpressOrderHUD = hud_scene.instantiate() as ExpressOrderHUD
	dialogue_canvas.add_child(dialogue_hud)
	var dialogue_scene: PackedScene = load(DIALOGUE_UI_SCENE_PATH) as PackedScene
	var dialogue_ui: DialogueUI = dialogue_scene.instantiate() as DialogueUI
	dialogue_canvas.add_child(dialogue_ui)
	root.add_child(dialogue_frame)
	await _settle_frames(2)
	dialogue_hud.set_process(false)
	dialogue_hud.set_game_state_override(dialogue_state)
	dialogue_hud.set_order_override(order)
	var sequence: DialogueSequence = load(
		DIALOGUE_SEQUENCE_PATH
	) as DialogueSequence
	if (
		sequence == null
		or not dialogue_ui.start_dialogue(sequence, dialogue_state)
		or not dialogue_ui.is_express_pause_notice_visible()
	):
		printerr("[t108-visual] Dialogue did not expose its express pause notice.")
		return false
	await _settle_frames(2)
	if not _save_frame("express_dialogue_pause.png"):
		return false
	dialogue_ui.cancel_dialogue()
	dialogue_frame.queue_free()
	await _settle_frames(2)
	dialogue_state.free()

	var help_state: GameStateModel = GameStateModel.new()
	help_state.accept_order(order)
	help_state.order_run_state.elapsed_time = 42.0
	var help_frame: Control = _make_frame(Color("171a2b"))
	var route_scene: PackedScene = load(RED_SAND_HUD_SCENE_PATH) as PackedScene
	var route_hud: RedSandRouteHUD = route_scene.instantiate() as RedSandRouteHUD
	help_frame.add_child(route_hud)
	var help_canvas: CanvasLayer = CanvasLayer.new()
	help_canvas.layer = 10
	help_frame.add_child(help_canvas)
	var help_hud: ExpressOrderHUD = hud_scene.instantiate() as ExpressOrderHUD
	help_canvas.add_child(help_hud)
	root.add_child(help_frame)
	await _settle_frames(2)
	help_hud.set_process(false)
	help_hud.set_game_state_override(help_state)
	help_hud.set_order_override(order)
	route_hud.show_controls_help(false, false)
	await _settle_frames(2)
	var controls_help: FlightControlsHelp = route_hud.get_controls_help()
	if (
		controls_help == null
		or not controls_help.is_express_pause_notice_visible()
	):
		printerr("[t108-visual] Flight help did not expose its express pause notice.")
		return false
	if not _save_frame("express_flight_help_pause.png"):
		return false
	help_frame.queue_free()
	await _settle_frames(2)
	help_state.free()
	return true


func _capture_terminal(order: OrderDefinition) -> bool:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.accept_order(order)
	var terminal_scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = terminal_scene.instantiate() as OrderTerminalUI
	terminal.game_state_override = game_state
	terminal.order_definition = order
	root.add_child(terminal)
	await _settle_frames(2)
	if not terminal.open_terminal():
		printerr("[t108-visual] Express terminal could not open.")
		return false
	await _settle_frames(3)
	if not _save_frame("express_order_terminal.png"):
		return false
	terminal.queue_free()
	await _settle_frames(2)
	game_state.free()
	return true


func _capture_results(order: OrderDefinition) -> bool:
	var game_state: GameStateModel = GameStateModel.new()
	game_state.accept_order(order)
	game_state.order_run_state.cargo_integrity = 50.0
	game_state.order_run_state.elapsed_time = 150.0
	var results_scene: PackedScene = load(RESULTS_SCENE_PATH) as PackedScene
	var results: OrderResults = results_scene.instantiate() as OrderResults
	results.order = order
	results.game_state_override = game_state
	root.add_child(results)
	await _settle_frames(3)
	if not results.is_settlement_committed():
		printerr("[t108-visual] Express results did not commit.")
		return false
	if not _save_frame("express_order_results.png"):
		return false
	results.queue_free()
	await _settle_frames(2)
	game_state.free()
	return true


func _make_frame(color: Color) -> Control:
	var frame: Control = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)
	return frame


func _make_playable_fixture(
	registered_order: OrderDefinition
) -> OrderDefinition:
	if registered_order == null or registered_order.destination_planet == null:
		return null
	var order: OrderDefinition = registered_order.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		registered_order.destination_planet.duplicate(true) as PlanetDefinition
	)
	order.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	order.required_chapter = &""
	order.unlock_conditions.clear()
	order.story_requirements.clear()
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = TEST_ROUTE_PATH
	planet.required_story_flags.clear()
	order.destination_planet = planet
	return order


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		printerr("[t108-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[t108-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	if image.save_png(output_path) != OK:
		printerr("[t108-visual] Could not save %s." % output_path)
		return false
	print("[t108-visual] Saved %s" % output_path)
	return true
