extends SceneTree

const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene: PackedScene = load(FLIGHT_LAB_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Flight Lab scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return
	var flight_lab: FlightLab = packed_scene.instantiate() as FlightLab
	_check(flight_lab != null, "Flight Lab root controller is missing.")
	if flight_lab == null:
		_finish()
		return
	root.add_child(flight_lab)
	await process_frame
	await process_frame

	var flight_ship: FlightLabShip = flight_lab.get_flight_ship()
	var flight_camera: Camera2D = flight_lab.get_flight_camera()
	var debug_hud: FlightDebugHUD = flight_lab.get_debug_hud()
	_check(flight_ship != null, "Flight Lab ship is missing.")
	_check(flight_camera != null and flight_camera.enabled, "Flight Lab camera is not active.")
	_check(debug_hud != null and debug_hud.visible, "Flight debug HUD is not visible.")
	if debug_hud != null:
		var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
		_check(
			viewport_bounds.encloses(debug_hud.get_header_rect())
			and viewport_bounds.encloses(debug_hud.get_stats_rect()),
			"Flight debug HUD leaves the 640x360 viewport."
		)
		_check(
			debug_hud.get_speed_text() == tr("UI_FLIGHT_DEBUG_SPEED") % 0.0,
			"Flight debug HUD did not render the reset telemetry."
		)
	_check(
		UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"The direct Flight Lab debug route is unavailable."
	)

	var toggle_event: InputEventAction = InputEventAction.new()
	toggle_event.action = FlightLab.HUD_TOGGLE_ACTION
	toggle_event.pressed = true
	flight_lab._unhandled_input(toggle_event)
	_check(debug_hud != null and not debug_hud.visible, "F3 action did not hide the debug HUD.")
	flight_lab._unhandled_input(toggle_event)
	_check(debug_hud != null and debug_hud.visible, "F3 action did not restore the debug HUD.")

	if flight_ship != null:
		var start_position: Vector2 = flight_ship.position
		await _hold_action_for_physics_frames(FlightLabShip.THROTTLE_ACTION, 12)
		var accelerated_speed: float = flight_ship.get_speed()
		_check(
			accelerated_speed > 20.0 and flight_ship.position.x > start_position.x,
			"Throttle action did not accelerate the ship forward."
		)
		for _frame_index: int in 6:
			await physics_frame
		_check(
			flight_ship.get_speed() > accelerated_speed * 0.9,
			"Released throttle removed space inertia too quickly."
		)
		var speed_before_brake: float = flight_ship.get_speed()
		await _hold_action_for_physics_frames(FlightLabShip.BRAKE_ACTION, 3)
		_check(
			flight_ship.get_speed() < speed_before_brake
			and flight_ship.get_speed() > 0.0,
			"Brake action must decelerate without instantly reversing or stopping."
		)
		await _hold_action_for_physics_frames(FlightLabShip.PITCH_DOWN_ACTION, 6)
		_check(
			flight_ship.rotation > 0.0 and flight_ship.angular_velocity > 0.0,
			"Pitch-down action did not build positive angular motion."
		)
		if debug_hud != null:
			await process_frame
			_check(
				not debug_hud.get_angular_velocity_text().is_empty()
				and debug_hud.get_angular_velocity_text()
				!= "UI_FLIGHT_DEBUG_ANGULAR_VELOCITY",
				"Flight debug HUD did not display angular velocity."
			)

	if flight_ship != null:
		flight_ship.position = Vector2(812.0, 54.0)
		flight_ship.velocity = Vector2(220.0, 96.0)
		flight_ship.rotation = -0.55
		flight_ship.angular_velocity = -1.25
		flight_ship.throttle_input = 1.0
		flight_ship.brake_input = 1.0
		flight_ship.pitch_input = -1.0
		flight_ship.fuel = 4.0
		flight_ship.boost_energy = 8.0
	var restart_event: InputEventAction = InputEventAction.new()
	restart_event.action = FlightLab.RESTART_ACTION
	restart_event.pressed = true
	flight_lab._unhandled_input(restart_event)
	if flight_ship != null:
		_check(
			flight_ship.position == flight_ship.stable_start_position
			and flight_ship.velocity == Vector2.ZERO
			and is_zero_approx(flight_ship.rotation)
			and is_zero_approx(flight_ship.angular_velocity)
			and is_zero_approx(flight_ship.throttle_input)
			and is_zero_approx(flight_ship.brake_input)
			and is_zero_approx(flight_ship.pitch_input),
			"R action left linear, angular, or input drift after reset."
		)
		_check(
			is_equal_approx(flight_ship.fuel, FlightLabShip.DEFAULT_RESOURCE_VALUE)
			and is_equal_approx(
				flight_ship.boost_energy,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			),
			"R action left stale fuel or Boost after reset."
		)
	if flight_camera != null and flight_ship != null:
		_check(
			flight_camera.position == flight_ship.stable_start_position,
			"Camera did not snap back to the stable start."
		)

	flight_lab.queue_free()
	await process_frame
	_finish()


func _hold_action_for_physics_frames(action: StringName, frame_count: int) -> void:
	Input.action_press(action)
	for _frame_index: int in frame_count:
		await physics_frame
	Input.action_release(action)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"[flight-lab] PASS: explicit thrust, inertia, brake, pitch, HUD, "
			+ "direct route, and deterministic reset."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[flight-lab] %s" % failure)
	quit(1)
