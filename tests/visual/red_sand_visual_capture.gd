extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t044"
const STORM_SEGMENT_INDEX: int = 4
const LANDING_SEGMENT_INDEX: int = 7


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_route_frames")


func _capture_route_frames() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	if packed_scene == null:
		printerr("[red-sand-visual] Route scene could not be loaded.")
		quit(1)
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	if route == null:
		printerr("[red-sand-visual] Route controller is missing.")
		quit(1)
		return
	root.add_child(route)
	await process_frame
	await process_frame
	var hud: RedSandRouteHUD = route.get_route_hud()
	if hud != null:
		hud.visible = false
	var ship: FlightLabShip = route.get_flight_ship()
	if ship == null:
		printerr("[red-sand-visual] Flight ship is missing.")
		quit(1)
		return
	ship.set_physics_process(false)

	_prepare_storm_frame(route, ship)
	await _settle_particles(90)
	if not _save_frame("red_sand_storm_no_hud.png"):
		quit(1)
		return

	_prepare_landing_frame(route, ship)
	await _settle_particles(90)
	if not _save_frame("red_sand_landing_no_hud.png"):
		quit(1)
		return

	print("[red-sand-visual] PASS: saved two 640x360 no-HUD route frames.")
	route.queue_free()
	await process_frame
	quit(0)


func _prepare_storm_frame(route: RedSandFlight, ship: FlightLabShip) -> void:
	var definition: FlightRouteDefinition = route.get_route_definition()
	var storm_segment: FlightRouteSegment = definition.segments[STORM_SEGMENT_INDEX]
	ship.position = Vector2(route.route_origin_x + 71180.0, 142.0)
	ship.velocity = Vector2(360.0, 12.0)
	ship.rotation = deg_to_rad(2.0)
	ship.effective_throttle_input = 0.82
	ship.effective_boost_input = 0.35
	ship._update_engine_feedback()
	route.advance_route_state()
	route._physics_process(1.0 / 60.0)
	route._process(0.0)
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	if feedback != null:
		feedback.set_segment(storm_segment)
		feedback.set_ship_feedback(360.0, 0.82, 0.35, 0.8, false)


func _prepare_landing_frame(route: RedSandFlight, ship: FlightLabShip) -> void:
	var landing_zone: RedSandLandingZone = route.get_landing_zone()
	ship.global_position = landing_zone.global_position + Vector2(-120.0, 252.0)
	ship.velocity = Vector2(112.0, 4.0)
	ship.rotation = deg_to_rad(1.0)
	ship.effective_throttle_input = 0.34
	ship.effective_boost_input = 0.0
	ship._update_engine_feedback()
	route.advance_route_state()
	route._physics_process(1.0 / 60.0)
	route._process(0.0)
	var definition: FlightRouteDefinition = route.get_route_definition()
	var landing_segment: FlightRouteSegment = definition.segments[
		LANDING_SEGMENT_INDEX
	]
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	if feedback != null:
		feedback.set_segment(landing_segment)
		feedback.set_ship_feedback(112.0, 0.34, 0.0, 1.0, false)


func _settle_particles(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _save_frame(file_name: String) -> bool:
	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)
	if directory_error != OK:
		printerr("[red-sand-visual] Could not create capture directory.")
		return false
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[red-sand-visual] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(file_name)
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr("[red-sand-visual] Could not save frame: %s" % output_path)
		return false
	print("[red-sand-visual] Saved %s" % output_path)
	return true
