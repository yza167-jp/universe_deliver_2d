extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = (
	"res://.omx/artifacts/t045_gate_c_round_4_rework/orbit_entry_sequence"
)
const SOURCE_FPS: float = 60.0
const CAPTURE_FRAME_STRIDE: int = 4
const NOMINAL_ROUTE_SPEED: float = 316.6667
const SHIP_Y: float = 174.0


func _initialize() -> void:
	TranslationServer.set_locale("zh_CN")
	call_deferred("_capture_sequence")


func _capture_sequence() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Route scene could not be loaded.")
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	if route == null:
		_fail("Route controller is missing.")
		return
	root.add_child(route)
	await process_frame
	await process_frame
	route.close_controls_help()
	var hud: RedSandRouteHUD = route.get_route_hud()
	if hud != null:
		hud.visible = false
	var ship: FlightLabShip = route.get_flight_ship()
	if ship == null:
		_fail("Flight ship is missing.")
		return
	ship.set_physics_process(false)
	route.set_process(false)
	route.set_physics_process(false)

	var absolute_directory: String = ProjectSettings.globalize_path(
		CAPTURE_DIRECTORY
	)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)
	if directory_error != OK:
		_fail("Could not create capture directory.")
		return
	var distance_step: float = (
		NOMINAL_ROUTE_SPEED * float(CAPTURE_FRAME_STRIDE) / SOURCE_FPS
	)
	var transition_distance: float = (
		RedSandOrbitTransitionModel.TRANSITION_WINDOW_DISTANCE
	)
	var capture_count: int = ceili(transition_distance / distance_step) + 1
	for frame_index: int in capture_count:
		var route_distance: float = minf(
			RedSandOrbitTransitionModel.TRANSITION_START_DISTANCE
			+ distance_step * float(frame_index),
			RedSandOrbitTransitionModel.TRANSITION_END_DISTANCE
		)
		ship.position = Vector2(route.route_origin_x + route_distance, SHIP_Y)
		ship.velocity = Vector2(NOMINAL_ROUTE_SPEED, 0.0)
		route.advance_route_state()
		route._process(float(CAPTURE_FRAME_STRIDE) / SOURCE_FPS)
		await process_frame
		if not _save_frame(absolute_directory, frame_index):
			quit(1)
			return

	print(
		"[red-sand-orbit-entry-sequence] PASS: captured %d consecutive samples "
		% capture_count
		+ "across %.0f m / %.2f s at a 15 FPS evidence cadence."
		% [
			transition_distance,
			RedSandOrbitTransitionModel.get_nominal_duration_seconds(
				NOMINAL_ROUTE_SPEED
			),
		]
	)
	route.queue_free()
	await process_frame
	quit(0)


func _save_frame(absolute_directory: String, frame_index: int) -> bool:
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("[red-sand-orbit-entry-sequence] Viewport capture was empty.")
		return false
	if image.get_size() != Vector2i(640, 360):
		image.resize(640, 360, Image.INTERPOLATE_NEAREST)
	var output_path: String = absolute_directory.path_join(
		"frame_%04d.png" % frame_index
	)
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr(
			"[red-sand-orbit-entry-sequence] Could not save frame: %s"
			% output_path
		)
		return false
	return true


func _fail(message: String) -> void:
	printerr("[red-sand-orbit-entry-sequence] %s" % message)
	quit(1)
