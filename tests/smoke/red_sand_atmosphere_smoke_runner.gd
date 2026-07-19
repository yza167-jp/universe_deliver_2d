extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const ATMOSPHERE_SEGMENT_INDEX: int = 3
const STORM_SEGMENT_INDEX: int = 4
const LANDING_SEGMENT_INDEX: int = 7

var _failures: Array[String] = []
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Red Sand route scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Red Sand atmosphere route controller is missing.")
	if route == null:
		_finish()
		return
	root.add_child(route)
	await process_frame
	await process_frame
	route.set_process(false)
	route.set_physics_process(false)

	var ship: FlightLabShip = route.get_flight_ship()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	var definition: FlightRouteDefinition = route.get_route_definition()
	var route_visuals: RedSandRouteVisuals = route.get_node_or_null(
		"World/RouteGeometry"
	) as RedSandRouteVisuals
	_check(ship != null, "Red Sand atmosphere smoke is missing the ship.")
	_check(feedback != null, "Red Sand atmosphere smoke is missing environment feedback.")
	_check(definition != null, "Red Sand atmosphere smoke is missing route data.")
	_check(route_visuals != null, "Red Sand atmosphere smoke is missing route visuals.")
	if ship == null or feedback == null or definition == null or route_visuals == null:
		route.queue_free()
		await process_frame
		_finish()
		return
	ship.set_physics_process(false)
	feedback.set_process(false)

	_test_depth_layers(route)
	_test_ship_feedback(ship)
	_test_stage_feedback(route, feedback, definition, route_visuals)
	_test_mix_headroom(route, feedback)

	route.queue_free()
	await process_frame
	_finish()


func _test_depth_layers(route: RedSandFlight) -> void:
	var background_layers: Node = route.get_node_or_null("BackgroundLayers")
	var parallax_count: int = 0
	if background_layers != null:
		for child: Node in background_layers.get_children():
			if child is Parallax2D:
				parallax_count += 1
	_check(
		parallax_count >= 5
		and route.get_node_or_null("Backdrop/PlanetAnchor/PlanetDisc") is Polygon2D,
		"Atmosphere pass must combine at least five parallax layers with the planet layer."
	)


func _test_ship_feedback(ship: FlightLabShip) -> void:
	var engine_particles: CPUParticles2D = ship.get_engine_trail_particles()
	var boost_particles: CPUParticles2D = ship.get_boost_trail_particles()
	var engine_audio: AudioStreamPlayer2D = ship.get_engine_audio()
	var boost_audio: AudioStreamPlayer2D = ship.get_boost_audio()
	var collision_audio: AudioStreamPlayer2D = ship.get_collision_audio()
	_check(
		engine_particles != null
		and boost_particles != null
		and engine_particles.texture != null
		and boost_particles.texture != null,
		"Propulsion and Boost particle emitters must use visible local textures."
	)
	_check(
		engine_audio != null
		and engine_audio.stream is AudioStreamWAV
		and _stream_has_signal(engine_audio.stream as AudioStreamWAV)
		and boost_audio != null
		and boost_audio.stream is AudioStreamWAV
		and _stream_has_signal(boost_audio.stream as AudioStreamWAV)
		and collision_audio != null
		and collision_audio.stream is AudioStreamWAV
		and _stream_has_signal(collision_audio.stream as AudioStreamWAV),
		"Engine, Boost, and collision feedback must use generated audio streams."
	)
	ship.effective_throttle_input = 0.8
	ship.effective_boost_input = 1.0
	ship._update_engine_feedback()
	_check(
		engine_particles != null
		and engine_particles.emitting
		and boost_particles != null
		and boost_particles.emitting,
		"Throttle and Boost must activate distinct propulsion particle trails."
	)
	ship.effective_throttle_input = 0.0
	ship.effective_boost_input = 0.0
	ship._update_engine_feedback()


func _test_stage_feedback(
	route: RedSandFlight,
	feedback: RedSandEnvironmentFeedback,
	definition: FlightRouteDefinition,
	route_visuals: RedSandRouteVisuals
) -> void:
	feedback.set_ship_feedback(360.0, 0.7, 0.0, 0.0, false)
	_check(
		feedback.are_speed_streaks_emitting(),
		"Cruise speed must remain readable through screen-space streaks without HUD."
	)

	var atmosphere_segment: FlightRouteSegment = definition.segments[
		ATMOSPHERE_SEGMENT_INDEX
	]
	feedback.set_segment(atmosphere_segment)
	_check(
		feedback.are_entry_particles_emitting()
		and not feedback.are_storm_particles_emitting()
		and feedback.get_target_music_intensity() >= 0.6,
		"Atmospheric entry must activate its own heat streaks and music pressure."
	)

	var storm_segment: FlightRouteSegment = definition.segments[STORM_SEGMENT_INDEX]
	feedback.set_segment(storm_segment)
	feedback._process(2.0)
	_check(
		feedback.are_storm_particles_emitting()
		and not feedback.are_entry_particles_emitting()
		and feedback.are_wind_bands_visible()
		and is_equal_approx(feedback.get_music_intensity(), 1.0),
		"Storm stage must combine dust, wind bands, and maximum music pressure."
	)

	var landing_segment: FlightRouteSegment = definition.segments[
		LANDING_SEGMENT_INDEX
	]
	feedback.set_segment(landing_segment)
	route_visuals.update_visuals(
		landing_segment.start_distance + landing_segment.get_length() * 0.5
	)
	var far_terrain: Parallax2D = route.get_node_or_null(
		"BackgroundLayers/FarTerrain"
	) as Parallax2D
	var near_facilities: Parallax2D = route.get_node_or_null(
		"BackgroundLayers/NearFacilities"
	) as Parallax2D
	_check(
		feedback.are_landing_particles_emitting()
		and not feedback.are_storm_particles_emitting()
		and far_terrain != null
		and far_terrain.modulate.a >= 0.95
		and near_facilities != null
		and near_facilities.modulate.a >= 0.7,
		"Landing approach must reveal desert terrain, facilities, and surface dust."
	)
	feedback.burst_landing_dust()
	_check(
		feedback.is_landing_burst_emitting()
		and not feedback.are_landing_particles_emitting(),
		"Touchdown must replace approach dust with a distinct landing burst."
	)


func _test_mix_headroom(
	route: RedSandFlight,
	feedback: RedSandEnvironmentFeedback
) -> void:
	var music_audio: AudioStreamPlayer = feedback.get_music_audio()
	var ambience_audio: AudioStreamPlayer = feedback.get_node_or_null(
		"AmbienceAudio"
	) as AudioStreamPlayer
	var warning_audio: AudioStreamPlayer2D = route.get_node_or_null(
		"World/Hazards/LightningStrikes/StrikeA/WarningAudio"
	) as AudioStreamPlayer2D
	_check(
		music_audio != null
		and music_audio.stream is AudioStreamWAV
		and _stream_has_signal(music_audio.stream as AudioStreamWAV)
		and ambience_audio != null
		and ambience_audio.stream is AudioStreamWAV
		and _stream_has_signal(ambience_audio.stream as AudioStreamWAV),
		"Route music and environment ambience must both use generated streams."
	)
	_check(
		warning_audio != null
		and music_audio != null
		and music_audio.volume_db <= warning_audio.volume_db - 6.0
		and ambience_audio != null
		and ambience_audio.volume_db <= warning_audio.volume_db - 6.0,
		"Music and ambience must preserve at least 6 dB for lightning warnings."
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _stream_has_signal(stream: AudioStreamWAV) -> bool:
	if stream == null or stream.data.is_empty():
		return false
	var sample_stride: int = maxi(stream.data.size() / 256, 1)
	for byte_index: int in range(0, stream.data.size(), sample_stride):
		if stream.data[byte_index] != 0:
			return true
	return false


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[red-sand-atmosphere] PASS: five-layer parallax, propulsion and "
			+ "stage particles, synthesized SFX, dynamic music, and warning headroom."
		)
		quit(0)
		return
	printerr("[red-sand-atmosphere] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
