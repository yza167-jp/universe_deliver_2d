extends SceneTree

const DELIVERY_LAB_SCENE_PATH: String = "res://scenes/flight/delivery_lab.tscn"

var _failures: Array[String] = []
var _original_locale: String = ""


func _initialize() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var game_state: GameStateModel = root.get_node_or_null("GameState") as GameStateModel
	if game_state != null:
		game_state.reset_runtime_state()
	var initial_credits: int = 0 if game_state == null else game_state.credits

	var packed_scene: PackedScene = load(DELIVERY_LAB_SCENE_PATH) as PackedScene
	_check(packed_scene != null, "Delivery Lab scene could not be loaded.")
	if packed_scene == null:
		_finish()
		return
	var delivery_lab: DeliveryLab = packed_scene.instantiate() as DeliveryLab
	_check(delivery_lab != null, "Delivery Lab root controller is missing.")
	if delivery_lab == null:
		_finish()
		return
	root.add_child(delivery_lab)
	await process_frame
	await process_frame

	var profile: LowAltitudeDropProfile = delivery_lab.get_drop_profile()
	var ship: FlightLabShip = delivery_lab.get_flight_ship()
	_check(profile != null and profile.validate().is_empty(), "Drop profile is invalid.")
	_check(
		ship != null
		and ship.get_checkpoint_id() == DeliveryLab.LAB_CHECKPOINT_ID
		and delivery_lab.is_cargo_available()
		and delivery_lab.get_drop_model().get_release_count() == 0,
		"Delivery Lab did not begin with one restorable cargo at its checkpoint."
	)
	_check_input_contract()
	_check_hud_layout(delivery_lab)
	if profile == null or ship == null:
		delivery_lab.queue_free()
		_finish()
		return

	var invalid_result: LowAltitudeDropResult
	delivery_lab.debug_set_ship_state(
		1100.0,
		profile.minimum_release_altitude - 1.0,
		profile.minimum_release_speed
	)
	invalid_result = delivery_lab.request_drop()
	_check(
		invalid_result != null
		and invalid_result.status == LowAltitudeDropModel.Status.INVALID_RELEASE
		and invalid_result.reason_key == LowAltitudeDropModel.REASON_ALTITUDE_TOO_LOW
		and delivery_lab.is_cargo_available()
		and delivery_lab.get_drop_model().get_release_count() == 0
		and delivery_lab.get_result_text().contains(
			str(roundi(profile.minimum_release_altitude))
		),
		"Invalid altitude did not explain the rejection while preserving cargo."
	)

	var altitude: float = 150.0
	var speed: float = 140.0
	var inherited_travel: float = _calculate_inherited_travel(
		profile,
		altitude,
		speed
	)
	var core_release_x: float = delivery_lab.target_center_x - inherited_travel
	delivery_lab.debug_set_ship_state(core_release_x, altitude, speed)
	var core_result: LowAltitudeDropResult = delivery_lab.request_drop()
	_check(
		core_result != null
		and core_result.status == LowAltitudeDropModel.Status.CORE_SUCCESS
		and not delivery_lab.is_cargo_available()
		and delivery_lab.is_cargo_in_flight()
		and delivery_lab.get_drop_model().get_release_count() == 1,
		"A valid core release did not consume exactly one cargo and start descent."
	)
	var repeated_result: LowAltitudeDropResult = delivery_lab.request_drop()
	_check(
		repeated_result != null
		and repeated_result.status == LowAltitudeDropModel.Status.INVALID_RELEASE
		and repeated_result.reason_key == LowAltitudeDropModel.REASON_ALREADY_RELEASED
		and delivery_lab.get_drop_model().get_release_count() == 1
		and delivery_lab.get_settled_result() == core_result,
		"Repeated delivery input created or replaced a second cargo result."
	)
	delivery_lab.debug_complete_cargo_fall()
	_check(
		delivery_lab.is_result_settled()
		and not delivery_lab.is_cargo_in_flight()
		and delivery_lab.get_settled_result().status
		== LowAltitudeDropModel.Status.CORE_SUCCESS
		and delivery_lab.get_result_text().contains(
			tr("UI_DELIVERY_DROP_RESULT_CORE")
		),
		"Core cargo did not visibly settle as a full success: %s"
		% delivery_lab.get_result_text()
	)

	_check(
		delivery_lab.restart_from_checkpoint()
		and delivery_lab.is_cargo_available()
		and not delivery_lab.is_result_settled()
		and delivery_lab.get_drop_model().get_release_count() == 0
		and delivery_lab.get_settled_result().status
		== LowAltitudeDropModel.Status.PENDING
		and ship.position.is_equal_approx(delivery_lab.checkpoint_position)
		and ship.velocity.is_equal_approx(delivery_lab.checkpoint_velocity),
		"Checkpoint retry did not restore ship, cargo, and pending delivery state."
	)

	var partial_landing_x: float = (
		delivery_lab.target_center_x
		+ profile.core_zone_half_width
		+ 20.0
	)
	delivery_lab.debug_set_ship_state(
		partial_landing_x - inherited_travel,
		altitude,
		speed
	)
	var partial_result: LowAltitudeDropResult = delivery_lab.request_drop()
	delivery_lab.debug_complete_cargo_fall()
	_check(
		partial_result.status == LowAltitudeDropModel.Status.OUTER_PARTIAL
		and is_equal_approx(
			partial_result.quality_ratio,
			profile.partial_quality_ratio
		)
		and is_equal_approx(
			partial_result.reward_ratio,
			profile.partial_reward_ratio
		)
		and delivery_lab.get_result_text().contains(
			tr("UI_DELIVERY_DROP_RESULT_OUTER")
		),
		"Outer-zone cargo did not settle with configured partial quality and reward: %s"
		% delivery_lab.get_result_text()
	)

	delivery_lab.restart_from_checkpoint()
	var missed_landing_x: float = (
		delivery_lab.target_center_x
		+ profile.outer_zone_half_width
		+ 30.0
	)
	delivery_lab.debug_set_ship_state(
		missed_landing_x - inherited_travel,
		altitude,
		speed
	)
	var missed_result: LowAltitudeDropResult = delivery_lab.request_drop()
	delivery_lab.debug_complete_cargo_fall()
	_check(
		missed_result.status == LowAltitudeDropModel.Status.MISSED
		and delivery_lab.get_result_text().contains(
			tr("UI_DELIVERY_DROP_RESULT_MISSED")
		),
		"A landing outside the fixed outer zone did not become a retriable miss."
	)

	_check(
		game_state == null
		or (
			game_state.credits == initial_credits
			and game_state.current_order_id.is_empty()
		),
		"Isolated Delivery Lab must not mutate campaign order or reward state."
	)

	delivery_lab.queue_free()
	await process_frame
	_finish()


func _check_input_contract() -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(
		DeliveryLab.DROP_ACTION
	)
	var has_keyboard: bool = false
	var has_mouse: bool = false
	for event: InputEvent in events:
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			has_keyboard = (
				key_event.keycode == KEY_E
				or key_event.physical_keycode == KEY_E
			)
		elif event is InputEventMouseButton:
			has_mouse = (
				(event as InputEventMouseButton).button_index
				== MOUSE_BUTTON_RIGHT
			)
	_check(
		InputMap.has_action(DeliveryLab.DROP_ACTION)
		and has_keyboard
		and has_mouse,
		"Keyboard and mouse must share the delivery_drop Input Map action."
	)
	_check(
		UniverseDeliverApp.should_start_in_delivery_lab(
			true,
			PackedStringArray([UniverseDeliverApp.DEBUG_DELIVERY_LAB_ARGUMENT])
		),
		"Direct --delivery-lab routing is unavailable."
	)


func _check_hud_layout(delivery_lab: DeliveryLab) -> void:
	var viewport_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
	var rects: Array[Rect2] = delivery_lab.get_hud_rects()
	_check(rects.size() == 3, "Delivery Lab HUD must expose three bounded panels.")
	for index: int in rects.size():
		_check(
			viewport_bounds.encloses(rects[index]),
			"Delivery Lab HUD panel %d leaves the 640x360 viewport." % index
		)
		for other_index: int in range(index + 1, rects.size()):
			_check(
				not rects[index].intersects(rects[other_index]),
				"Delivery Lab HUD panels overlap at 640x360."
			)
	_check(
		delivery_lab.get_telemetry_text().contains("m")
		and delivery_lab.get_result_text() == tr("UI_DELIVERY_LAB_READY_TO_DROP"),
		"Delivery Lab HUD did not expose localized telemetry and initial guidance: %s | %s"
		% [delivery_lab.get_telemetry_text(), delivery_lab.get_result_text()]
	)


func _calculate_inherited_travel(
	profile: LowAltitudeDropProfile,
	altitude: float,
	speed: float
) -> float:
	return (
		speed
		* profile.horizontal_velocity_inheritance
		* altitude
		/ profile.cargo_descent_speed
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _finish() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[delivery-lab-smoke] PASS: input, windows, single cargo, "
			+ "core/partial/miss, retry, and campaign isolation verified."
		)
		quit(0)
		return
	printerr("[delivery-lab-smoke] FAILED with %d issue(s):" % _failures.size())
	for failure: String in _failures:
		printerr("  - %s" % failure)
	quit(1)
