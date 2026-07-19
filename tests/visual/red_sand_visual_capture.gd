extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t045_gate_c_round_2"
const SYSTEM_EDGE_SEGMENT_INDEX: int = 0
const NEAR_ORBIT_SEGMENT_INDEX: int = 2
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
	route.close_controls_help()
	var hud: RedSandRouteHUD = route.get_route_hud()
	if hud != null:
		hud.visible = false
	var ship: FlightLabShip = route.get_flight_ship()
	if ship == null:
		printerr("[red-sand-visual] Flight ship is missing.")
		quit(1)
		return
	ship.set_physics_process(false)
	route.set_process(false)
	route.set_physics_process(false)

	_prepare_stage_frame(
		route, ship, SYSTEM_EDGE_SEGMENT_INDEX, 0.05, 184.0, 0.55, 0.0
	)
	await _settle_particles(45)
	if not _save_frame("stage_1_system_edge.png"):
		quit(1)
		return

	_prepare_stage_frame(
		route, ship, NEAR_ORBIT_SEGMENT_INDEX, 0.95, 170.0, 1.0, 1.0
	)
	await _settle_particles(45)
	if not _save_frame("stage_3_near_orbit.png"):
		quit(1)
		return

	_prepare_stage_frame(
		route, ship, STORM_SEGMENT_INDEX, 0.55, 142.0, 0.82, 0.0
	)
	await _settle_particles(90)
	if not _save_frame("stage_5_storm_layer.png"):
		quit(1)
		return

	_prepare_stage_frame(
		route, ship, LANDING_SEGMENT_INDEX, 0.55, 264.0, 0.34, 0.0
	)
	await _settle_particles(210)
	if not _save_frame("stage_8_landing_approach.png"):
		quit(1)
		return

	print(
		"[red-sand-visual] PASS: saved stage 1, 3, 5, and 8 "
		+ "640x360 no-HUD route frames."
	)
	route.queue_free()
	await process_frame
	quit(0)


func _prepare_stage_frame(
	route: RedSandFlight,
	ship: FlightLabShip,
	segment_index: int,
	segment_progress: float,
	ship_y: float,
	throttle: float,
	boost: float
) -> void:
	var definition: FlightRouteDefinition = route.get_route_definition()
	var segment: FlightRouteSegment = definition.segments[segment_index]
	ship.clear_propulsion_feedback()
	ship.position = Vector2(
		route.route_origin_x + lerpf(
			segment.start_distance,
			segment.end_distance,
			clampf(segment_progress, 0.0, 1.0)
		),
		ship_y
	)
	ship.velocity = Vector2(300.0, 0.0)
	ship.rotation = deg_to_rad(2.0 if segment_index < STORM_SEGMENT_INDEX else 0.5)
	ship.integrate_motion(throttle, 0.0, 0.0, 0.2, boost)
	ship._update_engine_feedback()
	route.advance_route_state()
	route._physics_process(1.0 / 60.0)
	route._process(0.0)
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	if feedback != null:
		feedback.set_segment(segment)
		feedback.set_ship_feedback(
			ship.get_speed(),
			throttle,
			ship.get_boost_feedback_strength(),
			ship.air_density,
			false
		)


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
