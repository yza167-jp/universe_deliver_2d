extends SceneTree

const FLIGHT_LAB_SCENE_PATH: String = "res://scenes/flight/flight_lab.tscn"

var _failures: Array[String] = []
var _failure_count: int = 0
var _company_warning_count: int = 0
var _last_company_warning_key: StringName = &""
var _laser_fired_count: int = 0
var _laser_rejected_count: int = 0
var _laser_hit_count: int = 0
var _last_laser_rejection_key: StringName = &""
var _last_laser_target_id: StringName = &""
var _boost_blocked_count: int = 0
var _last_boost_blocked_key: StringName = &""
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
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
	var smoke_game_state: GameStateModel = GameStateModel.new()
	var smoke_order: OrderDefinition = flight_lab.data_registry.find_order(
		&"order_red_sand_m0"
	)
	_check(
		smoke_order != null and smoke_game_state.accept_order(smoke_order),
		"Flight Lab smoke could not initialize an active order-run result."
	)
	flight_lab.game_state_override = smoke_game_state
	root.add_child(flight_lab)
	await process_frame
	await process_frame

	var flight_ship: FlightLabShip = flight_lab.get_flight_ship()
	var flight_camera: Camera2D = flight_lab.get_flight_camera()
	var debug_hud: FlightDebugHUD = flight_lab.get_debug_hud()
	var course: FlightLabCourse = flight_lab.get_course()
	var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	_check(flight_ship != null, "Flight Lab ship is missing.")
	_check(flight_camera != null and flight_camera.enabled, "Flight Lab camera is not active.")
	_check(debug_hud != null and debug_hud.visible, "Flight debug HUD is not visible.")
	_check(
		course != null
		and course.get_exercise_count() == 5
		and course.get_completed_count() == 0,
		"Flight Lab did not start with an empty five-exercise Gate B course."
	)
	if flight_ship != null:
		flight_ship.flight_failed.connect(_on_flight_failed)
		flight_ship.company_warning_requested.connect(_on_company_warning_requested)
		flight_ship.laser_fired.connect(_on_laser_fired)
		flight_ship.laser_fire_rejected.connect(_on_laser_fire_rejected)
		flight_ship.laser_target_hit.connect(_on_laser_target_hit)
		flight_ship.boost_blocked.connect(_on_boost_blocked)
	if debug_hud != null:
		var motion_rect: Rect2 = debug_hud.get_essential_motion_rect()
		var resources_rect: Rect2 = debug_hud.get_essential_resources_rect()
		var status_rect: Rect2 = debug_hud.get_status_rect()
		var route_rect: Rect2 = debug_hud.get_route_rect()
		_check(
			viewport_bounds.encloses(motion_rect)
			and viewport_bounds.encloses(resources_rect)
			and viewport_bounds.encloses(status_rect)
			and viewport_bounds.encloses(route_rect),
			"Essential Flight HUD leaves the 640x360 viewport."
		)
		_check(
			not motion_rect.intersects(resources_rect)
			and not motion_rect.intersects(route_rect)
			and not resources_rect.intersects(route_rect)
			and not status_rect.intersects(route_rect),
			"Essential motion, resources, route, or status panels overlap at 640x360."
		)
		_check(
			route_rect.size.x <= 640.0 * 0.4
			and not motion_rect.intersects(Rect2(288.0, 166.0, 64.0, 48.0))
			and not resources_rect.intersects(Rect2(288.0, 166.0, 64.0, 48.0))
			and not route_rect.intersects(Rect2(480.0, 168.0, 48.0, 44.0)),
			"Default HUD obscures the initial ship or first asteroid target."
		)
		_check(
			not debug_hud.is_full_diagnostics_visible()
			and debug_hud.get_diagnostics_rect() == Rect2()
			and not debug_hud.has_visible_mouse_interception(),
			"Full Diagnostics must start hidden without a residual input blocker."
		)
		_check(
			debug_hud.is_route_guide_visible()
			and not debug_hud.is_route_expanded()
			and not debug_hud.is_route_checklist_visible()
			and debug_hud.get_route_progress_text().contains("1/5")
			and debug_hud.get_route_title_text().contains(
				tr("UI_FLIGHT_LAB_COURSE_STEP_ASSIST")
			)
			and debug_hud.get_route_instruction_text().contains("V")
			and debug_hud.get_route_instruction_text().contains("G"),
			"The default Gate B card must show only current progress, name, and compact hint."
		)
		_check(
			debug_hud.get_shortcut_text()
			== tr("UI_FLIGHT_LAB_HINTS_COMPACT")
			and not debug_hud.get_shortcut_text().contains("F3")
			and not debug_hud.get_shortcut_text().contains("F4")
			and not debug_hud.get_shortcut_text().contains("F5")
			and not debug_hud.get_shortcut_text().contains("F6"),
			"Default Flight Lab HUD still exposes the legacy function-key list."
		)
		_check(
			debug_hud.get_forward_speed_text().contains(
				tr("UI_FLIGHT_HUD_FORWARD_SPEED") % "0"
			)
			and debug_hud.get_environment_assist_text().contains(
				tr(FlightAssistMode.LIMITED_NAME_KEY)
			),
			"Essential Flight HUD did not render signed speed and assist mode."
		)
		_check(
			debug_hud.get_environment_text().contains("0%")
			and not debug_hud.get_terminal_text().is_empty(),
			"Flight debug HUD did not render environment and terminal telemetry."
		)
		_check(
			debug_hud.get_durability_text().contains("100%")
			and debug_hud.get_checkpoint_text().contains(
				String(FlightLab.LAB_CHECKPOINT_ID)
			),
			"Flight debug HUD did not render five-resource and checkpoint telemetry."
		)
		_check(
			debug_hud.get_laser_text().contains(
				tr("UI_FLIGHT_LASER_LOADOUT_UNINSTALLED")
			)
			and debug_hud.get_laser_text().contains(
				tr("UI_FLIGHT_LASER_STATE_UNAVAILABLE")
			),
			"Flight debug HUD did not render the unavailable default laser loadout."
		)
		_check(
			debug_hud.get_entry_style_text().contains(
				tr("UI_FLIGHT_ENTRY_STYLE_PENDING")
			),
			"Flight debug HUD did not render the pending entry-style state."
		)
		debug_hud._process(FlightDebugHUD.STATUS_DURATION_SECONDS + 0.1)
		_check(
			not debug_hud.is_status_visible()
			and debug_hud.get_status_rect() == Rect2(),
			"Inactive company/status feedback must not reserve a persistent bottom panel."
		)
	_check(
		flight_lab.environment_profiles.size() == 2
		and flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id == &"environment_deep_space",
		"Flight Lab did not start in the deterministic deep-space preset."
	)
	_check(
		UniverseDeliverApp.should_start_in_flight_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_FLIGHT_LAB_ARGUMENT])
		),
		"The direct Flight Lab debug route is unavailable."
	)

	var small_asteroid: DestructibleAsteroid = flight_lab.get_node_or_null(
		"World/DestructibleAsteroids/SmallAsteroid"
	) as DestructibleAsteroid
	var large_asteroid: DestructibleAsteroid = flight_lab.get_node_or_null(
		"World/DestructibleAsteroids/LargeAsteroid"
	) as DestructibleAsteroid
	var scenic_ridge: FlightScenicTrigger = flight_lab.get_node_or_null(
		"World/ScenicTriggers/ScenicRidge"
	) as FlightScenicTrigger
	var scenic_storm: FlightScenicTrigger = flight_lab.get_node_or_null(
		"World/ScenicTriggers/ScenicStorm"
	) as FlightScenicTrigger
	_check(
		flight_ship != null
		and not flight_ship.is_laser_enabled()
		and small_asteroid != null
		and large_asteroid != null,
		"Flight Lab did not start with the default uninstalled laser and both targets."
	)
	if flight_ship != null and small_asteroid != null and large_asteroid != null:
		await _tap_action_for_physics_frames(FlightLabShip.FIRE_ACTION)
		_check(
			_laser_fired_count == 0
			and _laser_rejected_count == 1
			and _last_laser_rejection_key == FlightLaserWeapon.FIRE_UNAVAILABLE_KEY
			and not flight_ship.is_failed,
			"Uninstalled laser input did not give non-blocking rejection feedback."
		)
		if debug_hud != null:
			_check(
				debug_hud.get_status_text()
				== tr("UI_FLIGHT_LAB_STATUS_LASER_UNAVAILABLE"),
				"Uninstalled laser feedback was not localized in the status panel."
			)

		var laser_toggle_event: InputEventAction = InputEventAction.new()
		laser_toggle_event.action = FlightLab.LASER_TOGGLE_ACTION
		laser_toggle_event.pressed = true
		flight_lab._unhandled_input(laser_toggle_event)
		_check(
			flight_ship.is_laser_enabled()
			and flight_ship.is_laser_ready()
			and debug_hud != null
			and debug_hud.get_laser_text().contains(
				tr("UI_FLIGHT_LASER_LOADOUT_INSTALLED")
			),
			"L action did not expose the isolated Flight Lab laser loadout toggle."
		)

		await _tap_action_for_physics_frames(FlightLabShip.FIRE_ACTION)
		var laser_weapon: FlightLaserWeapon = flight_ship.get_laser_weapon()
		var laser_stream: AudioStreamWAV = (
			laser_weapon.get_shot_audio().stream as AudioStreamWAV
			if laser_weapon != null and laser_weapon.get_shot_audio() != null
			else null
		)
		_check(
			_laser_fired_count == 1
			and _laser_hit_count == 1
			and _last_laser_target_id == small_asteroid.target_id
			and small_asteroid.is_destroyed()
			and small_asteroid.collision_layer == 0
			and not flight_ship.is_fire_input_held(),
			"A short laser press must fire exactly one pulse and stop on release."
		)
		_check(
			laser_weapon != null
			and laser_weapon.get_beam() != null
			and laser_weapon.get_beam().visible
			and laser_weapon.get_shot_audio() != null
			and laser_stream != null
			and not laser_stream.data.is_empty()
			and small_asteroid.get_destruction_fragments() != null
			and small_asteroid.get_destruction_fragments().emitting,
			"Laser hit did not expose beam, synthesized sound, and fragment feedback."
		)

		var large_durability_before_cooldown: int = large_asteroid.get_current_durability()
		var immediate_result: FlightLaserWeapon.FireResult = flight_ship.request_laser_fire()
		_check(
			immediate_result == FlightLaserWeapon.FireResult.COOLDOWN
			and _laser_rejected_count == 2
			and _last_laser_rejection_key == FlightLaserWeapon.FIRE_COOLDOWN_KEY
			and large_asteroid.get_current_durability()
			== large_durability_before_cooldown,
			"Laser cooldown did not reject repeated fire without damaging the next target."
		)
		if debug_hud != null:
			_check(
				debug_hud.get_status_text().contains("冷却"),
				"Laser cooldown did not provide concise Chinese status feedback."
			)

		await _wait_for_laser_ready(flight_ship)
		var fired_before_hold: int = _laser_fired_count
		Input.action_press(FlightLabShip.FIRE_ACTION)
		for _frame_index: int in 48:
			await physics_frame
		var fired_while_held: int = _laser_fired_count - fired_before_hold
		_check(
			flight_ship.is_fire_input_held()
			and fired_while_held >= 3
			and fired_while_held <= 5
			and _laser_hit_count == 4,
			"Held fire must repeat at the configured cooldown without a low-frame burst."
		)
		Input.action_release(FlightLabShip.FIRE_ACTION)
		await physics_frame
		var fired_after_release: int = _laser_fired_count
		for _frame_index: int in 24:
			await physics_frame
		_check(
			not flight_ship.is_fire_input_held()
			and _laser_fired_count == fired_after_release,
			"Releasing the shared fire action must stop repeated laser pulses immediately."
		)
		_check(
			large_asteroid.is_destroyed()
			and large_asteroid.collision_layer == 0
			and large_asteroid.get_visual_root() != null
			and not large_asteroid.get_visual_root().visible
			and large_asteroid.get_destruction_fragments() != null,
			"The durable asteroid did not open the route with fragment feedback."
		)
		_check(
			course != null
			and course.is_exercise_complete(FlightLabCourse.Exercise.LASER),
			"Destroying both Flight Lab asteroid types did not update the Gate B route."
		)
		if debug_hud != null:
			debug_hud.refresh()
			_check(
				debug_hud.is_status_visible()
				and not debug_hud.get_status_text().is_empty(),
				"Held-fire laser feedback did not remain visible in the compact status line."
			)
			_check(
				debug_hud.get_route_progress_text().contains("1/5")
				and debug_hud.get_route_checklist_text().contains(
					"✓ 5"
				),
				"Laser course completion was not visible in the localized route guide "
				+ "(progress=%s, checklist=%s)." % [
					debug_hud.get_route_progress_text(),
					debug_hud.get_route_checklist_text(),
				]
			)

		await _wait_for_laser_ready(flight_ship)
		var hits_before_miss: int = _laser_hit_count
		_check(
			flight_ship.request_laser_fire() == FlightLaserWeapon.FireResult.FIRED
			and _laser_hit_count == hits_before_miss,
			"A clear route should produce a harmless laser miss, not another target hit."
		)
		if debug_hud != null:
			_check(
				debug_hud.get_status_text() == tr("UI_FLIGHT_LAB_STATUS_LASER_MISS"),
				"Laser miss did not provide localized feedback."
			)

		Input.action_press(FlightLabShip.FIRE_ACTION)
		await physics_frame
		await physics_frame
		_check(
			flight_ship.is_fire_input_held(),
			"Held-fire state was not entered before reset coverage."
		)
		_check(
			flight_lab.restart_from_checkpoint(false)
			and not flight_ship.is_fire_input_held()
			and not small_asteroid.is_destroyed()
			and small_asteroid.get_current_durability() == small_asteroid.max_durability
			and not large_asteroid.is_destroyed()
			and large_asteroid.get_current_durability() == large_asteroid.max_durability,
			"Checkpoint restart did not restore destructible asteroid state."
		)
		Input.action_release(FlightLabShip.FIRE_ACTION)
		_check(
			course != null
			and course.is_exercise_complete(FlightLabCourse.Exercise.LASER),
			"Checkpoint restart erased the already attempted laser exercise."
		)
		flight_lab._unhandled_input(laser_toggle_event)
		_check(
			not flight_ship.is_laser_enabled(),
			"Second L action did not return to the uninstalled laser loadout."
		)

	var toggle_event: InputEventAction = InputEventAction.new()
	toggle_event.action = FlightLab.HUD_TOGGLE_ACTION
	toggle_event.pressed = true
	flight_lab._unhandled_input(toggle_event)
	_check(
		debug_hud != null
		and debug_hud.visible
		and debug_hud.is_full_diagnostics_visible(),
		"H action did not open Full Diagnostics while preserving Essential HUD."
	)
	flight_lab._unhandled_input(toggle_event)
	_check(
		debug_hud != null
		and debug_hud.visible
		and not debug_hud.is_full_diagnostics_visible()
		and debug_hud.get_diagnostics_rect() == Rect2(),
		"Second H action did not fully hide Full Diagnostics."
	)
	var route_event: InputEventAction = InputEventAction.new()
	route_event.action = FlightLab.ROUTE_HINT_ACTION
	route_event.pressed = true
	flight_lab._unhandled_input(route_event)
	_check(
		debug_hud != null
		and debug_hud.is_route_guide_visible()
		and debug_hud.is_route_expanded()
		and debug_hud.is_route_checklist_visible()
		and debug_hud.get_route_rect().size.y > FlightDebugHUD.COMPACT_ROUTE_HEIGHT
		and viewport_bounds.encloses(debug_hud.get_route_rect())
		and not debug_hud.get_route_rect().intersects(
			Rect2(288.0, 166.0, 64.0, 48.0)
		)
		and not debug_hud.get_route_rect().intersects(
			Rect2(480.0, 168.0, 48.0, 44.0)
		),
		"Tab action did not expand the complete Gate B route."
	)
	flight_lab._unhandled_input(route_event)
	_check(
		debug_hud != null
		and debug_hud.is_route_guide_visible()
		and not debug_hud.is_route_expanded()
		and not debug_hud.is_route_checklist_visible(),
		"Second Tab action did not collapse the Gate B route."
	)

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

		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not restore its stable checkpoint before Boost smoke."
		)
		var fuel_before_boost: float = flight_ship.fuel
		var energy_before_boost: float = flight_ship.boost_energy
		await _hold_action_for_physics_frames(FlightLabShip.BOOST_ACTION, 12)
		var energy_after_boost: float = flight_ship.boost_energy
		_check(
			flight_ship.get_speed() > 30.0
			and flight_ship.fuel < fuel_before_boost
			and energy_after_boost < energy_before_boost
			and flight_ship.effective_boost_input > 0.0,
			"Shift Boost did not accelerate or consume both fuel and Boost energy."
		)
		var boost_glow: Polygon2D = flight_ship.get_node_or_null("BoostGlow") as Polygon2D
		_check(
			boost_glow != null and boost_glow.visible,
			"Active Boost did not expose its minimum visual feedback."
		)
		for _frame_index: int in 48:
			await physics_frame
		_check(
			flight_ship.boost_energy > energy_after_boost,
			"Idle Boost energy did not recover after its configured delay."
		)

		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not restore its stable checkpoint before reverse smoke."
		)
		flight_ship.velocity = Vector2(100.0, 0.0)
		await _hold_action_for_physics_frames(FlightLabShip.BRAKE_ACTION, 1)
		_check(
			flight_ship.get_forward_speed() > 0.0
			and flight_ship.get_forward_speed() < 100.0,
			"S must first reduce positive forward speed instead of applying full reverse."
		)
		Input.action_press(FlightLabShip.BRAKE_ACTION)
		for _frame_index: int in 120:
			await physics_frame
			if flight_ship.get_forward_speed() < -20.0:
				break
		var reverse_glow: Polygon2D = flight_ship.get_node_or_null(
			"ReverseGlow"
		) as Polygon2D
		_check(
			flight_ship.get_forward_speed() < 0.0
			and flight_ship.effective_reverse_input > 0.0
			and reverse_glow != null
			and reverse_glow.visible,
			"Continuing to hold S after zero must enter visible limited reverse."
		)
		for _frame_index: int in 180:
			await physics_frame
		var max_reverse_speed: float = flight_ship.tuning.get_max_reverse_speed()
		_check(
			flight_ship.get_forward_speed() >= -max_reverse_speed - 0.1
			and flight_ship.get_forward_speed() <= -max_reverse_speed * 0.9,
			"Reverse speed exceeded or failed to approach the configured limit."
		)
		if debug_hud != null:
			debug_hud.refresh()
			_check(
				debug_hud.get_forward_speed_text().contains("倒车")
				and debug_hud.get_forward_speed_text().contains("-"),
				"Essential HUD did not identify negative forward speed as reverse."
			)

		flight_ship.fuel = 50.0
		flight_ship.boost_energy = 50.0
		_boost_blocked_count = 0
		Input.action_press(FlightLabShip.BOOST_ACTION)
		for _frame_index: int in 8:
			await physics_frame
		_check(
			is_zero_approx(flight_ship.effective_boost_input)
			and is_zero_approx(flight_ship.resources.boost_energy_cost_rate)
			and flight_ship.fuel >= 49.99
			and flight_ship.boost_energy >= 50.0
			and _boost_blocked_count == 1
			and _last_boost_blocked_key
			== FlightLabShip.REVERSE_BOOST_BLOCKED_KEY,
			"Reverse Boost input must be blocked once without consuming resources."
		)
		if debug_hud != null:
			_check(
				debug_hud.get_status_text()
				== tr(FlightLabShip.REVERSE_BOOST_BLOCKED_KEY),
				"Reverse Boost rejection did not use the compact localized status line."
			)
		Input.action_release(FlightLabShip.BOOST_ACTION)
		await physics_frame
		Input.action_release(FlightLabShip.BRAKE_ACTION)
		var pitch_before_reverse_control: float = flight_ship.rotation
		await _hold_action_for_physics_frames(FlightLabShip.PITCH_UP_ACTION, 6)
		_check(
			flight_ship.rotation < pitch_before_reverse_control
			and flight_ship.rotation >= -flight_ship.tuning.get_max_pitch_radians(),
			"Reverse motion inverted pitch-up or bypassed the normal pitch limit."
		)
		await _hold_action_for_physics_frames(FlightLabShip.THROTTLE_ACTION, 90)
		_check(
			flight_ship.get_forward_speed() > 0.0,
			"W did not cancel negative speed and return the ship to forward motion."
		)
		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not reset after reverse smoke."
		)

	var environment_event: InputEventAction = InputEventAction.new()
	environment_event.action = FlightLab.ENVIRONMENT_CYCLE_ACTION
	environment_event.pressed = true
	flight_lab._unhandled_input(environment_event)
	_check(
		flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id
		== &"environment_red_sand_atmosphere",
		"V action did not select the Red Sand atmosphere preset."
	)
	if flight_ship != null:
		for _frame_index: int in 10:
			await physics_frame
		_check(
			flight_ship.gravity_blend > 0.0
			and flight_ship.gravity_blend < 1.0
			and flight_ship.air_density > 0.0
			and flight_ship.air_density < 1.0,
			"Atmosphere gravity and density did not blend in gradually."
		)
		await process_frame
		_check(
			flight_lab.atmosphere_tint.color.a > 0.0
			and debug_hud != null
			and debug_hud.get_environment_text().contains("%")
			and debug_hud.get_environment_text() != "UI_FLIGHT_DEBUG_ENVIRONMENT",
			"Atmosphere transition did not provide visible tint and localized HUD feedback."
		)
		var style_tracker: FlightStyleTracker = flight_lab.get_entry_style_tracker()
		_check(
			style_tracker != null
			and style_tracker.is_tracking()
			and style_tracker.get_run_state() == smoke_game_state.order_run_state
			and style_tracker.get_run_state().entry_duration > 0.0,
			"Entering atmosphere did not begin live tracking on the active order result "
			+ "(tracking=%s, same_result=%s, duration=%.3f)." % [
				style_tracker != null and style_tracker.is_tracking(),
				style_tracker != null
				and style_tracker.get_run_state() == smoke_game_state.order_run_state,
				0.0 if style_tracker == null or style_tracker.get_run_state() == null
				else style_tracker.get_run_state().entry_duration,
			]
		)
		if style_tracker != null:
			for _sample_index: int in 9:
				style_tracker.record_sample(
					1.0,
					Vector2(80.0, 60.0),
					0.2,
					flight_ship.tuning
				)
			_check(
				scenic_ridge != null
				and scenic_ridge.try_trigger(flight_ship)
				and not scenic_ridge.try_trigger(flight_ship)
				and scenic_storm != null
				and scenic_storm.try_trigger(flight_ship)
				and flight_lab.get_entry_style_candidate()
				== FlightStyleTracker.STYLE_GLIDE,
				"A long calm Flight Lab sample did not produce the GLIDE candidate."
			)
		await process_frame
		_check(
			debug_hud != null
			and debug_hud.get_entry_style_text().contains(
				tr("UI_FLIGHT_ENTRY_STYLE_GLIDE")
			),
			"Flight debug HUD did not show the live localized GLIDE candidate: %s"
			% ("<missing>" if debug_hud == null else debug_hud.get_entry_style_text())
		)
		flight_ship.reset_to_start(
			0.75,
			flight_lab.get_active_environment_profile(),
			true
		)
		for _frame_index: int in 120:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			flight_ship.velocity.y > 0.0
			and flight_ship.velocity.y
			< flight_ship.get_terminal_fall_speed_safety(),
			"Default atmosphere assist did not produce a controlled downward fall."
		)
		flight_ship.velocity = Vector2(240.0, 0.0)
		for _frame_index: int in 60:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			flight_ship.velocity.x < 190.0,
			"Atmosphere did not decay horizontal speed with its independent drag."
		)

		flight_ship.reset_to_start(
			1.0,
			flight_lab.get_active_environment_profile(),
			true
		)
		for _frame_index: int in 60:
			flight_ship.integrate_motion(0.0, 0.0, 0.0, 1.0 / 60.0)
		_check(
			absf(flight_ship.velocity.y) < 0.01
			and flight_ship.fuel < FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.assist_fuel_cost_rate > 0.0,
			"100% assist did not hover with an explicit fuel cost."
		)
		for _frame_index: int in 40:
			await physics_frame

	var assist_event: InputEventAction = InputEventAction.new()
	assist_event.action = FlightLab.ASSIST_CYCLE_ACTION
	assist_event.pressed = true
	var observed_assist_presets: Array[int] = []
	for _preset_index: int in 3:
		flight_lab._unhandled_input(assist_event)
		observed_assist_presets.append(
			roundi(flight_lab.get_active_assist_strength() * 100.0)
		)
	observed_assist_presets.sort()
	_check(
		observed_assist_presets == [0, 75, 100],
		"G action did not cycle all accepted gravity-assist presets."
	)
	_check(
		course != null
		and course.is_exercise_complete(FlightLabCourse.Exercise.ASSIST_HOVER),
		"The integrated preset cycle and full-assist hover did not update the Gate B route."
	)

	flight_lab._unhandled_input(environment_event)
	_check(
		flight_lab.get_active_environment_profile() != null
		and flight_lab.get_active_environment_profile().id == &"environment_deep_space",
		"Second V action did not return to deep space."
	)
	_check(
		smoke_game_state.get_order_entry_style() == FlightStyleTracker.STYLE_GLIDE
		and not flight_lab.get_entry_style_tracker().is_tracking()
		and smoke_game_state.order_run_state.active_checkpoint_id
		== FlightLab.LAB_CHECKPOINT_ID
		and debug_hud != null
		and debug_hud.get_status_text().contains(
			tr("UI_FLIGHT_ENTRY_STYLE_GLIDE")
		),
		"Leaving atmosphere did not finalize GLIDE into the order-run result "
		+ "(style=%s, tracking=%s, checkpoint=%s, status=%s)." % [
			String(smoke_game_state.get_order_entry_style()),
			flight_lab.get_entry_style_tracker().is_tracking(),
			String(smoke_game_state.order_run_state.active_checkpoint_id),
			"<missing>" if debug_hud == null else debug_hud.get_status_text(),
		]
	)

	if flight_ship != null:
		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not restore its deep-space checkpoint before impacts."
		)
		flight_ship.cargo_integrity = 91.0
		var hard_impact: FlightCollisionResult = flight_ship.resolve_impact(
			Vector2(250.0, 0.0),
			Vector2.LEFT
		)
		_check(
			hard_impact.severity == FlightCollisionResult.Severity.HARD
			and flight_ship.shield < FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.hull == FlightLabShip.DEFAULT_RESOURCE_VALUE
			and flight_ship.cargo_integrity < 90.0,
			"Hard impact did not damage shield and cargo without failing the run."
		)
		_check(
			_company_warning_count == 1
			and _last_company_warning_key
			== &"UI_FLIGHT_COMPANY_WARNING_CARGO_HIGH",
			"Crossing 90% cargo integrity did not trigger the company warning interface."
		)
		for _frame_index: int in 12:
			await physics_frame
		flight_ship.resolve_impact(Vector2(250.0, 0.0), Vector2.LEFT)
		_check(
			_company_warning_count == 1,
			"The same cargo warning threshold repeated during one checkpoint attempt."
		)

		_check(
			flight_lab.restart_from_checkpoint(false),
			"Flight Lab could not reset before fatal terrain collision smoke."
		)
		_failure_count = 0
		flight_ship.position = Vector2(520.0, 241.0)
		flight_ship.velocity = Vector2(320.0, 0.0)
		for _frame_index: int in 20:
			await physics_frame
			if _failure_count > 0:
				break
		_check(
			_failure_count == 1
			and flight_ship.is_failed
			and flight_lab.is_retry_pending(),
			"High-speed collision with real terrain did not enter rapid failure retry."
		)
		_check(
			course != null
			and course.is_exercise_complete(
				FlightLabCourse.Exercise.COLLISION_RETRY
			),
			"Nonfatal and fatal impacts did not update the Gate B collision route."
		)
		await process_frame
		if debug_hud != null:
			var failure_status_rect: Rect2 = debug_hud.get_status_rect()
			_check(
				viewport_bounds.encloses(failure_status_rect)
				and not debug_hud.get_stats_rect().intersects(failure_status_rect),
				"Localized failure status expanded outside or over telemetry."
			)
		var retry_frames: int = 0
		while flight_lab.is_retry_pending() and retry_frames < 60:
			await physics_frame
			retry_frames += 1
		_check(
			retry_frames < 60
			and not flight_ship.is_failed
			and flight_ship.position == flight_ship.stable_start_position
			and flight_ship.velocity == Vector2.ZERO
			and is_equal_approx(
				flight_ship.hull,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(
				flight_ship.cargo_integrity,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			),
			"Fatal impact did not return control with checkpoint-defined resources."
		)

	if flight_ship != null:
		flight_ship.position = Vector2(812.0, 54.0)
		flight_ship.velocity = Vector2(220.0, 96.0)
		flight_ship.rotation = -0.55
		flight_ship.angular_velocity = -1.25
		flight_ship.throttle_input = 1.0
		flight_ship.brake_input = 1.0
		flight_ship.pitch_input = -1.0
		flight_ship.boost_input = 1.0
		flight_ship.hull = 9.0
		flight_ship.shield = 7.0
		flight_ship.fuel = 4.0
		flight_ship.boost_energy = 8.0
		flight_ship.cargo_integrity = 6.0
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
			and is_zero_approx(flight_ship.pitch_input)
			and is_zero_approx(flight_ship.boost_input),
			"R action left linear, angular, or input drift after reset."
		)
		_check(
			is_equal_approx(flight_ship.hull, FlightLabShip.DEFAULT_RESOURCE_VALUE)
			and is_equal_approx(
				flight_ship.shield,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(flight_ship.fuel, FlightLabShip.DEFAULT_RESOURCE_VALUE)
			and is_equal_approx(
				flight_ship.boost_energy,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			)
			and is_equal_approx(
				flight_ship.cargo_integrity,
				FlightLabShip.DEFAULT_RESOURCE_VALUE
			),
			"R action did not restore all five checkpoint resources."
		)
		_check(
			is_zero_approx(flight_ship.gravity_acceleration)
			and is_zero_approx(flight_ship.gravity_blend)
			and is_zero_approx(flight_ship.air_density),
			"R action did not snap the selected deep-space environment baseline."
		)
	if flight_camera != null and flight_ship != null:
		_check(
			flight_camera.position == flight_ship.stable_start_position,
			"Camera did not snap back to the stable start."
		)
	_check(
		scenic_ridge != null
		and not scenic_ridge.is_triggered()
		and scenic_storm != null
		and not scenic_storm.is_triggered(),
		"Checkpoint reset did not re-arm both scenic trigger gates."
	)
	_check(
		course != null
		and course.is_exercise_complete(FlightLabCourse.Exercise.ASSIST_HOVER)
		and course.is_exercise_complete(
			FlightLabCourse.Exercise.COLLISION_RETRY
		)
		and course.is_exercise_complete(FlightLabCourse.Exercise.LASER),
		"Manual and automatic retries erased completed Gate B exercises."
	)

	flight_lab.queue_free()
	await process_frame
	smoke_game_state.free()
	_finish()


func _hold_action_for_physics_frames(action: StringName, frame_count: int) -> void:
	Input.action_press(action)
	for _frame_index: int in frame_count:
		await physics_frame
	Input.action_release(action)


func _tap_action_for_physics_frames(action: StringName) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await physics_frame
	await physics_frame


func _wait_for_laser_ready(flight_ship: FlightLabShip) -> void:
	for _frame_index: int in 30:
		if flight_ship.is_laser_ready():
			return
		await physics_frame
	_check(flight_ship.is_laser_ready(), "Laser cooldown exceeded 30 physics frames.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[flight-lab] PASS: compact/expanded Gate B HUD, H/V/G/L controls, held laser, "
			+ "limited reverse and Boost gate, assist resources, environment, entry style, "
			+ "collision bands, cargo warning, rapid retry, and checkpoint reset."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[flight-lab] %s" % failure)
	quit(1)


func _on_flight_failed(_reason_key: StringName) -> void:
	_failure_count += 1


func _on_company_warning_requested(
	warning_key: StringName,
	_cargo_integrity: float
) -> void:
	_company_warning_count += 1
	_last_company_warning_key = warning_key


func _on_laser_fired(_hit_target: bool) -> void:
	_laser_fired_count += 1


func _on_laser_fire_rejected(reason_key: StringName) -> void:
	_laser_rejected_count += 1
	_last_laser_rejection_key = reason_key


func _on_laser_target_hit(
	target_id: StringName,
	_remaining_durability: int,
	_target_destroyed: bool
) -> void:
	_laser_hit_count += 1
	_last_laser_target_id = target_id


func _on_boost_blocked(reason_key: StringName) -> void:
	_boost_blocked_count += 1
	_last_boost_blocked_key = reason_key
