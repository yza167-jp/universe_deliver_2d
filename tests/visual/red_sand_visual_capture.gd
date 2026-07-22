extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const CAPTURE_DIRECTORY: String = "res://.omx/artifacts/t045_gate_c_round_4_rework"
const SYSTEM_EDGE_SEGMENT_INDEX: int = 0
const NEAR_ORBIT_SEGMENT_INDEX: int = 2
const ATMOSPHERE_SEGMENT_INDEX: int = 3
const STORM_SEGMENT_INDEX: int = 4
const LOW_ALTITUDE_CONTROL_SEGMENT_INDEX: int = 5
const LANDING_PREPARATION_SEGMENT_INDEX: int = 6
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
	if not _save_frame("stage_1_orbital_hud.png"):
		quit(1)
		return
	if hud != null:
		hud.visible = false

	_prepare_stage_frame(
		route, ship, NEAR_ORBIT_SEGMENT_INDEX, 0.95, 170.0, 1.0, 1.0
	)
	await _settle_particles(45)
	if not _save_frame("stage_3_near_orbit.png"):
		quit(1)
		return

	_prepare_stage_frame(
		route, ship, NEAR_ORBIT_SEGMENT_INDEX, 0.99998, 174.0, 0.9, 0.0
	)
	await _settle_particles(2)
	if not _save_frame("stage_3_boundary_last.png"):
		quit(1)
		return
	_prepare_stage_frame(
		route, ship, ATMOSPHERE_SEGMENT_INDEX, 0.0, 174.0, 0.9, 0.0
	)
	await _settle_particles(2)
	if not _save_frame("stage_4_boundary_first.png"):
		quit(1)
		return
	_prepare_stage_frame(
		route, ship, ATMOSPHERE_SEGMENT_INDEX, 0.08889, 176.0, 0.9, 0.0
	)
	await _settle_particles(12)
	if not _save_frame("stage_4_transition_mid.png"):
		quit(1)
		return
	_prepare_stage_frame(
		route, ship, ATMOSPHERE_SEGMENT_INDEX, 0.33334, 180.0, 0.82, 0.0
	)
	await _settle_particles(12)
	if not _save_frame("stage_4_atmosphere_horizon.png"):
		quit(1)
		return
	if hud != null:
		hud.visible = true
	await _settle_particles(2)
	if not _save_frame("stage_4_atmosphere_altitude_hud.png"):
		quit(1)
		return
	if hud != null:
		hud.visible = false

	_prepare_stage_frame(
		route, ship, STORM_SEGMENT_INDEX, 0.55, 142.0, 0.82, 0.0
	)
	await _settle_particles(90)
	if not _save_frame("stage_5_storm_layer.png"):
		quit(1)
		return

	_prepare_stage_frame(
		route, ship, LOW_ALTITUDE_CONTROL_SEGMENT_INDEX, 0.18, -80.0, 0.0, 0.0
	)
	ship.velocity = Vector2.ZERO
	ship.clear_propulsion_feedback()
	ship._update_engine_feedback()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	if feedback != null:
		feedback.set_ship_feedback(0.0, 0.0, 0.0, ship.air_density, false)
	await _settle_particles(3)
	if not _save_frame("stage_6_effect_static.png"):
		quit(1)
		return
	ship.integrate_motion(1.0, 0.0, 0.0, 0.24, 0.0)
	ship._update_engine_feedback()
	if feedback != null:
		feedback.set_ship_feedback(
			ship.get_speed(), 1.0, ship.get_boost_feedback_strength(), ship.air_density, false
		)
	await _settle_particles(12)
	if not _save_frame("stage_6_effect_throttle.png"):
		quit(1)
		return
	ship.integrate_motion(1.0, 0.0, 0.0, 0.24, 1.0)
	ship._update_engine_feedback()
	if feedback != null:
		feedback.set_ship_feedback(
			ship.get_speed(), 1.0, ship.get_boost_feedback_strength(), ship.air_density, false
		)
	await _settle_particles(12)
	if not _save_frame("stage_6_effect_boost.png"):
		quit(1)
		return
	ship.velocity = Vector2.ZERO
	ship.clear_propulsion_feedback()
	ship._update_engine_feedback()
	if feedback != null:
		feedback.set_ship_feedback(0.0, 0.0, 0.0, ship.air_density, false)
	ship.set_laser_enabled(true)
	ship.begin_laser_beam()
	await _settle_particles(3)
	if not _save_frame("stage_6_effect_laser.png"):
		quit(1)
		return
	ship.cancel_held_fire(true)
	ship.apply_environment_damage(1.0, 0.0, &"UI_RED_SAND_RADAR_NOTICE_LOCKED")
	await _settle_particles(3)
	if not _save_frame("stage_6_effect_collision.png"):
		quit(1)
		return
	route.restart_from_checkpoint(false)
	await _settle_particles(3)
	if not _save_frame("stage_6_effect_retry.png"):
		quit(1)
		return

	if hud != null:
		hud.visible = true
	_prepare_stage_frame(
		route, ship, LOW_ALTITUDE_CONTROL_SEGMENT_INDEX, 0.42, 96.0, 0.45, 0.0
	)
	await _settle_particles(12)
	if not _save_frame("stage_6_high_altitude_safe.png"):
		quit(1)
		return
	_prepare_stage_frame(
		route, ship, LOW_ALTITUDE_CONTROL_SEGMENT_INDEX, 0.62, 396.0, 0.45, 0.0
	)
	route._physics_process(0.7)
	route._process(0.0)
	await _settle_particles(12)
	if not _save_frame("stage_6_low_altitude_warning.png"):
		quit(1)
		return
	route._physics_process(0.8)
	route._process(0.0)
	await _settle_particles(2)
	if not _save_frame("stage_6_low_altitude_pulse.png"):
		quit(1)
		return
	_prepare_stage_frame(
		route, ship, LANDING_PREPARATION_SEGMENT_INDEX, 0.3, -80.0, 0.34, 0.0
	)
	await _settle_particles(12)
	if not _save_frame("stage_7_preparation_hud.png"):
		quit(1)
		return
	if hud != null:
		hud.toggle_full_diagnostics()
	await _settle_particles(2)
	if not _save_frame("stage_7_full_diagnostics.png"):
		quit(1)
		return
	if hud != null:
		hud.toggle_full_diagnostics()

	_prepare_stage_frame(
		route, ship, LANDING_SEGMENT_INDEX, 0.0, -80.0, 0.34, 0.0
	)
	await _settle_particles(45)
	if not _save_frame("stage_8_high_descent_entry.png"):
		quit(1)
		return

	print(
		"[red-sand-visual] PASS: saved boundary-continuous atmosphere, orbital/AGL HUD, "
		+ "isolated effect lifecycle, radar, diagnostics, storm, and landing entry frames."
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
	var route_distance: float = lerpf(
			segment.start_distance,
			segment.end_distance,
			clampf(segment_progress, 0.0, 1.0)
		)
	ship.position = Vector2(
		route.route_origin_x + route_distance,
		ship_y
	)
	ship.velocity = Vector2(300.0, 0.0)
	ship.rotation = deg_to_rad(2.0 if segment_index < STORM_SEGMENT_INDEX else 0.5)
	ship.integrate_motion(throttle, 0.0, 0.0, 0.2, boost)
	ship._update_engine_feedback()
	route.advance_route_state()
	var altitude_provider: FlightAltitudeReferenceProvider = (
		route.get_altitude_reference_provider()
	)
	if altitude_provider != null:
		route._reset_altitude_reference()
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
