extends SceneTree

const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const STORM_SEGMENT_INDEX: int = 4
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: Array[String] = []
var _original_locale: String = ""
var _original_time_scale: float = 1.0


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	_original_time_scale = Engine.time_scale
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Red Sand route scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return

	var settings_service: SettingsServiceModel = SettingsServiceModel.new()
	settings_service.settings.slow_motion_assist = true
	settings_service.settings.flight_assist_strength = 0.75
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight
	_check(route != null, "Red Sand route controller is missing.")
	if route == null:
		settings_service.free()
		_finish()
		return
	route.settings_service_override = settings_service
	root.add_child(route)
	await process_frame
	await process_frame
	route.set_process(false)
	route.set_physics_process(false)

	var ship: FlightLabShip = route.get_flight_ship()
	var hazards: RedSandHazardDirector = route.get_hazard_director()
	var feedback: RedSandEnvironmentFeedback = route.get_environment_feedback()
	var hud: RedSandRouteHUD = route.get_route_hud()
	var definition: FlightRouteDefinition = route.get_route_definition()
	_check(ship != null, "Red Sand route ship is missing.")
	_check(hazards != null, "Red Sand hazard director is missing.")
	_check(feedback != null, "Red Sand environment feedback is missing.")
	_check(hud != null, "Red Sand route HUD is missing.")
	_check(definition != null, "Red Sand route definition is missing.")
	if (
		ship == null
		or hazards == null
		or feedback == null
		or hud == null
		or definition == null
	):
		route.queue_free()
		await process_frame
		settings_service.free()
		_finish()
		return
	ship.set_physics_process(false)
	feedback.set_process(false)

	_test_fixed_asteroid_route(route, ship, hazards, definition)
	await physics_frame
	_test_laser_route_and_checkpoint_reset(ship, hazards)
	await physics_frame
	_test_storm_partition(route, ship, hazards, feedback, definition)
	await _test_lightning_warning_and_assist(
		route,
		ship,
		hazards,
		feedback,
		hud,
		settings_service,
		definition
	)

	hazards.cancel_slow_motion()
	route.queue_free()
	await process_frame
	settings_service.free()
	_finish()


func _test_fixed_asteroid_route(
	route: RedSandFlight,
	ship: FlightLabShip,
	hazards: RedSandHazardDirector,
	definition: FlightRouteDefinition
) -> void:
	var asteroids: Array[DestructibleAsteroid] = hazards.get_asteroids()
	_check(hazards.validate().is_empty(), "Red Sand fixed hazard layout did not validate.")
	_check(asteroids.size() == 8, "Asteroid lane must contain eight fixed obstacles.")
	var lane: FlightRouteSegment = definition.segments[1]
	var has_small: bool = false
	var has_large: bool = false
	var minimum_y: float = INF
	var maximum_y: float = -INF
	for asteroid: DestructibleAsteroid in asteroids:
		var route_distance: float = asteroid.position.x - route.route_origin_x
		_check(
			route_distance >= lane.start_distance
			and route_distance < lane.end_distance,
			"Fixed asteroid '%s' is outside the debris-lane segment." % asteroid.target_id
		)
		has_small = has_small or asteroid.max_durability == 1
		has_large = has_large or asteroid.max_durability >= 3
		minimum_y = minf(minimum_y, asteroid.position.y)
		maximum_y = maxf(maximum_y, asteroid.position.y)
	_check(
		has_small and has_large and maximum_y - minimum_y >= 180.0,
		"Asteroid layout must support both laser durability choices and vertical detours."
	)
	_check(
		ship.collision_mask & FlightWeaponRules.DESTRUCTIBLE_ASTEROID_LAYER != 0,
		"Route ship must physically collide with the fixed asteroid lane."
	)


func _test_laser_route_and_checkpoint_reset(
	ship: FlightLabShip,
	hazards: RedSandHazardDirector
) -> void:
	var asteroids: Array[DestructibleAsteroid] = hazards.get_asteroids()
	if asteroids.is_empty():
		return
	var target: DestructibleAsteroid = asteroids[0]
	ship.position = target.position - Vector2(300.0, 0.0)
	ship.rotation = 0.0
	ship.velocity = Vector2.ZERO
	ship.set_laser_enabled(true)
	var fire_result: FlightLaserWeapon.FireResult = ship.request_laser_fire()
	_check(
		fire_result == FlightLaserWeapon.FireResult.FIRED
		and target.is_destroyed(),
		"Installed asteroid laser did not open the fixed direct route."
	)
	hazards.reset_for_checkpoint(0.0)
	_check(
		not target.is_destroyed()
		and target.get_current_durability() == target.max_durability,
		"Checkpoint reset did not restore fixed asteroid state."
	)


func _test_storm_partition(
	route: RedSandFlight,
	ship: FlightLabShip,
	hazards: RedSandHazardDirector,
	feedback: RedSandEnvironmentFeedback,
	definition: FlightRouteDefinition
) -> void:
	var storm_segment: FlightRouteSegment = definition.segments[STORM_SEGMENT_INDEX]
	var ambience_audio: AudioStreamPlayer = feedback.get_node_or_null(
		"AmbienceAudio"
	) as AudioStreamPlayer
	ship.position = Vector2(
		route.route_origin_x + storm_segment.start_distance + 1.0,
		190.0
	)
	ship.velocity = Vector2.ZERO
	_check(route.advance_route_state(), "Storm route boundary was not detected.")
	_check(
		route.get_active_segment_index() == STORM_SEGMENT_INDEX
		and hazards.is_storm_active()
		and feedback.get_active_environment_id() == storm_segment.id
		and feedback.get_active_audio_signature() == &"storm_pressure"
		and ambience_audio != null
		and ambience_audio.stream != null
		and feedback.get_environment_tint().a >= 0.1
		and feedback.are_wind_bands_visible(),
		"Storm partition did not combine physics, audio, tint, and wind feedback."
	)

	ship.set_assist_strength(0.0)
	ship.velocity = Vector2.ZERO
	hazards.set_active_segment(&"red_sand_lower_clouds")
	hazards.set_active_segment(storm_segment.id)
	var no_assist_wind: Vector2 = hazards.step_physics(1.0 / 60.0)
	ship.set_assist_strength(1.0)
	ship.velocity = Vector2.ZERO
	hazards.set_active_segment(&"red_sand_lower_clouds")
	hazards.set_active_segment(storm_segment.id)
	var full_assist_wind: Vector2 = hazards.step_physics(1.0 / 60.0)
	_check(
		no_assist_wind.length() > full_assist_wind.length()
		and not ship.velocity.is_zero_approx()
		and hazards.get_assist_wind_mitigation() >= 0.69,
		"Flight assist did not reduce deterministic storm control pressure."
	)


func _test_lightning_warning_and_assist(
	route: RedSandFlight,
	ship: FlightLabShip,
	hazards: RedSandHazardDirector,
	feedback: RedSandEnvironmentFeedback,
	hud: RedSandRouteHUD,
	settings_service: SettingsServiceModel,
	definition: FlightRouteDefinition
) -> void:
	var strikes: Array[FlightLightningStrike] = hazards.get_lightning_strikes()
	_check(strikes.size() == 4, "Storm layer must contain four fixed lightning strikes.")
	if strikes.is_empty():
		return
	var strike: FlightLightningStrike = strikes[0]
	_check(
		strike.warning_seconds >= 1.2
		and strike.strike_route_distance - strike.trigger_route_distance >= 400.0,
		"Lightning must expose a readable visual and travel-distance warning window."
	)

	ship.position = strike.global_position
	ship.velocity = Vector2.ZERO
	ship.shield = 100.0
	var flight_camera: Camera2D = route.get_flight_camera()
	if flight_camera != null:
		flight_camera.position = ship.position
	var route_state_before: int = route.get_active_segment_index()
	var checkpoint_before: StringName = ship.get_checkpoint_id()
	hazards.advance_hazards(0.0, strike.trigger_route_distance + 1.0)
	var warning_visual: Node2D = strike.get_node_or_null("WarningVisual") as Node2D
	_check(
		strike.get_state() == FlightLightningStrike.State.WARNING
		and strike.get_warning_remaining() >= 1.2
		and warning_visual != null
		and warning_visual.visible
		and hazards.is_slow_motion_active()
		and is_equal_approx(Engine.time_scale, hazards.slow_motion_time_scale)
		and hud.get_status_text().contains("慢动作辅助"),
		"Slow-motion assist did not activate during the readable lightning warning."
	)
	_check(
		VIEWPORT_RECT.encloses(hud.get_status_rect()),
		"Lightning warning HUD must remain inside the 640x360 viewport: %s within %s."
		% [hud.get_status_rect(), VIEWPORT_RECT]
	)
	_check(
		not hud.has_visible_mouse_interception(),
		"Lightning warning HUD must pass mouse input through."
	)
	await process_frame
	await process_frame
	hazards.advance_hazards(
		strike.warning_seconds + 0.01,
		strike.trigger_route_distance + 1.0
	)
	var damage_with_slow_motion: float = 100.0 - ship.shield
	_check(
		strike.get_state() == FlightLightningStrike.State.ACTIVE
		and strike.did_hit_ship()
		and is_equal_approx(damage_with_slow_motion, strike.damage)
		and not hazards.is_slow_motion_active()
		and is_equal_approx(Engine.time_scale, _original_time_scale)
		and hud.get_status_text().contains("雷击命中"),
		"Fixed lightning did not resolve the warned hit and restore normal time."
	)
	await process_frame
	_check(
		route.get_active_segment_index() == route_state_before
		and ship.get_checkpoint_id() == checkpoint_before
		and not route.is_route_completed(),
		"Slow-motion assist must not change route or story progression."
	)

	var storm_start: float = definition.segments[STORM_SEGMENT_INDEX].start_distance
	hazards.reset_for_checkpoint(storm_start)
	hazards.set_active_segment(definition.segments[STORM_SEGMENT_INDEX].id)
	settings_service.settings.slow_motion_assist = false
	ship.position = strike.global_position
	ship.shield = 100.0
	hazards.advance_hazards(0.0, strike.trigger_route_distance + 1.0)
	_check(
		not hazards.is_slow_motion_active()
		and is_equal_approx(Engine.time_scale, _original_time_scale),
		"Disabled slow-motion assist must leave global time unchanged."
	)
	hazards.advance_hazards(
		strike.warning_seconds + 0.01,
		strike.trigger_route_distance + 1.0
	)
	var damage_without_slow_motion: float = 100.0 - ship.shield
	_check(
		is_equal_approx(damage_without_slow_motion, damage_with_slow_motion),
		"Slow-motion assist must change reaction time, not lightning outcome or damage."
	)
	feedback.flash_lightning(false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	Engine.time_scale = _original_time_scale
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[red-sand-hazards] PASS: fixed asteroid routes, deterministic assisted wind, "
			+ "warned lightning, slow-motion reaction windows, and environment feedback."
		)
		quit(0)
		return
	printerr("[red-sand-hazards] FAILED with %d error(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
