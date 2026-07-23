extends SceneTree

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const RESULTS_SCENE_PATH: String = "res://scenes/app/results.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t053_m0_ui"

var _game_state: GameStateModel
var _settings_service: SettingsServiceModel


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_frames")


func _capture_frames() -> void:
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_settings_service = SettingsServiceModel.new()
	if not _prepare_active_order():
		quit(1)
		return

	var route_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	var route: RedSandFlight = route_scene.instantiate() as RedSandFlight
	route.settings_service_override = _settings_service
	route.force_direct_test_mode = true
	root.add_child(route)
	await _settle_frames(4)
	if not _save_frame("flight_controls_help.png"):
		quit(1)
		return
	route.close_controls_help()
	route.get_route_hud().show_company_warning(
		&"UI_FLIGHT_COMPANY_WARNING_CARGO_MEDIUM",
		58.0
	)
	await _settle_frames(3)
	if not _save_frame("flight_company_alert.png"):
		quit(1)
		return
	route.queue_free()
	await _settle_frames(3)

	var cockpit_scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = cockpit_scene.instantiate() as Cockpit
	root.add_child(cockpit)
	await _settle_frames(3)
	cockpit.activate_hotspot(&"company_terminal")
	await _settle_frames(2)
	if not _save_frame("cockpit_company_briefing.png"):
		quit(1)
		return
	cockpit.queue_free()
	await _settle_frames(3)

	if not _prepare_active_order():
		quit(1)
		return
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)
	var results_scene: PackedScene = load(RESULTS_SCENE_PATH) as PackedScene
	var results: OrderResults = results_scene.instantiate() as OrderResults
	root.add_child(results)
	await _settle_frames(3)
	if not _save_frame("results_next_step.png"):
		quit(1)
		return

	results.queue_free()
	_game_state.reset_runtime_state()
	_settings_service.free()
	await process_frame
	print(
		"[m0-ui-visual] PASS: saved controls, company alert, cockpit briefing, "
		+ "and results next-step frames."
	)
	quit(0)


func _prepare_active_order() -> bool:
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	if _game_state == null or order == null:
		printerr("[m0-ui-visual] GameState or Red Sand order is unavailable.")
		return false
	_game_state.reset_runtime_state()
	if not _game_state.accept_order(order):
		printerr("[m0-ui-visual] Red Sand order could not be accepted.")
		return false
	return true


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(CAPTURE_DIRECTORY)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		printerr("[m0-ui-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[m0-ui-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr("[m0-ui-visual] Could not save frame: %s" % output_path)
		return false
	print("[m0-ui-visual] Saved %s" % output_path)
	return true
