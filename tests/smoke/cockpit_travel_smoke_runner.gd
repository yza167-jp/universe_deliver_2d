extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"

var _failures: PackedStringArray = []
var _original_locale: String = ""
var _app: UniverseDeliverApp
var _game_state: GameStateModel
var _scene_router: SceneRouterService
var _registry: GameDataRegistry
var _order: OrderDefinition


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_scene_router = root.get_node_or_null("SceneRouter") as SceneRouterService
	_registry = load(REGISTRY_PATH) as GameDataRegistry
	_order = (
		_registry.find_order(&"order_red_sand_m0")
		if _registry != null
		else null
	)
	_check(_game_state != null, "Travel smoke requires the GameState autoload.")
	_check(_scene_router != null, "Travel smoke requires the SceneRouter autoload.")
	_check(_registry != null, "Travel smoke could not load the M0 data registry.")
	_check(_order != null, "Travel smoke could not find the Red Sand order.")
	if _game_state == null or _scene_router == null or _order == null:
		_finish_smoke()
		return

	_game_state.reset_runtime_state()
	var packed_app: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_check(packed_app != null, "App scene could not be loaded for travel smoke.")
	if packed_app == null:
		_finish_smoke()
		return
	_app = packed_app.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene root is not UniverseDeliverApp.")
	if _app == null:
		_finish_smoke()
		return
	root.add_child(_app)
	await process_frame
	await process_frame

	_check(_scene_router.debug_switch_to_stage(SceneRouterService.Stage.COCKPIT), "Could not open cockpit for blocked travel checks.")
	await process_frame
	await process_frame
	var cockpit: Cockpit = _get_active_cockpit()
	_check(cockpit != null, "Blocked travel check did not instantiate Cockpit.")
	if cockpit == null:
		await _cleanup()
		_finish_smoke()
		return
	var travel_audio: AudioStreamPlayer = cockpit.get_node_or_null(
		"TravelAudioPlayer"
	) as AudioStreamPlayer
	_check(
		travel_audio != null and travel_audio.stream is AudioStreamGenerator,
		"Cockpit must configure a local audio stream for travel phase cues."
	)
	_check(cockpit.activate_hotspot(&"navigation_screen"), "Navigation panel could not open without an order.")
	await process_frame
	_check(
		not cockpit.is_navigation_action_enabled()
		and cockpit.get_device_panel_body().contains(tr("UI_COCKPIT_NAV_ROUTE_NO_ORDER")),
		"No-order navigation state must visibly block departure."
	)
	_check(not cockpit.start_configured_travel(), "No-order cockpit incorrectly started travel.")
	cockpit.close_active_modal()
	await process_frame

	_prepare_confirmed_order()
	var expected_destination: StringName = _game_state.destination_id
	var expected_cargo: StringName = _game_state.cargo_id
	var expected_configuration: Dictionary[StringName, StringName] = (
		_game_state.ship_configuration.duplicate()
	)
	_check(cockpit.activate_hotspot(&"navigation_screen"), "Navigation panel could not reopen for the active order.")
	await process_frame
	_check(
		cockpit.is_navigation_action_enabled()
		and cockpit.get_device_panel_body().contains(tr("PLANET_RED_SAND_NAME"))
		and cockpit.get_device_panel_body().contains(tr("UI_COCKPIT_NAV_ROUTE_READY")),
		"Confirmed order must expose the Red Sand destination and departure action."
	)
	var action_button: Button = cockpit.get_node_or_null(
		"ModalLayer/DevicePanel/Margin/Content/Actions/DeviceActionButton"
	) as Button
	_check(action_button != null, "Navigation action button is missing.")
	if action_button != null:
		action_button.pressed.emit()
	await process_frame
	_check(
		_game_state.travel_state == GameStateModel.TravelState.DEPARTURE
		and cockpit.is_travel_status_visible()
		and cockpit.get_travel_phase_text() == tr("UI_COCKPIT_TRAVEL_PHASE_DEPARTURE"),
		"Mouse confirmation must start the visible departure phase."
	)
	_check(
		not cockpit.is_skip_travel_visible(),
		"The first Red Sand journey must not expose skip."
	)
	var controller: TravelSequenceController = cockpit.get_travel_controller()
	_check(controller != null, "Cockpit travel controller is unavailable.")
	if controller != null:
		controller.set_process(false)
		controller.advance_travel(
			controller.departure_duration
			+ controller.cruise_duration
			+ controller.approach_duration
			+ 0.1
		)
	await process_frame
	await process_frame
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.FLIGHT,
		"Completing cockpit travel must transition to FLIGHT."
	)
	_check(
		_game_state.travel_state == GameStateModel.TravelState.COMPLETED
		and _game_state.current_order_id == _order.id
		and _game_state.destination_id == expected_destination
		and _game_state.cargo_id == expected_cargo
		and _game_state.ship_configuration == expected_configuration,
		"FLIGHT handoff must retain the order, destination, cargo, and ship configuration."
	)
	_check(
		_game_state.has_seen_travel(expected_destination),
		"Completing the first journey must unlock its seen-route flag."
	)

	_check(
		_scene_router.debug_switch_to_stage(SceneRouterService.Stage.COCKPIT),
		"Could not reopen Cockpit to check duplicate departure protection."
	)
	await process_frame
	await process_frame
	await process_frame
	_check(
		_scene_router.current_stage == SceneRouterService.Stage.COCKPIT,
		"Reopening a completed cockpit state must not auto-trigger departure."
	)
	var reopened_cockpit: Cockpit = _get_active_cockpit()
	_check(reopened_cockpit != null, "Completed-state cockpit did not instantiate.")
	if reopened_cockpit != null:
		_check(
			not reopened_cockpit.start_configured_travel()
			and _game_state.last_travel_error
			== GameStateModel.TRAVEL_ERROR_ALREADY_COMPLETED,
			"Completed travel must reject a repeated departure trigger."
		)

	_game_state.reset_runtime_state()
	_prepare_confirmed_order()
	_game_state.mark_travel_seen(_order.destination_planet.id)
	if reopened_cockpit != null:
		_check(reopened_cockpit.activate_hotspot(&"navigation_screen"), "Keyboard travel check could not open Navigation.")
		await process_frame
		var keyboard_action: Button = reopened_cockpit.get_node_or_null(
			"ModalLayer/DevicePanel/Margin/Content/Actions/DeviceActionButton"
		) as Button
		_check(
			keyboard_action != null and keyboard_action.has_focus(),
			"Enabled destination confirmation must receive keyboard focus."
		)
		_push_accept_key()
		await process_frame
		_check(
			_game_state.travel_state == GameStateModel.TravelState.DEPARTURE,
			"Keyboard activation must start the same departure flow as mouse activation."
		)
		_check(
			reopened_cockpit.is_skip_travel_visible(),
			"A restored seen-route flag must expose the travel skip control."
		)
		var skip_button: Button = reopened_cockpit.get_node_or_null(
			"SkipTravelButton"
		) as Button
		_check(skip_button != null, "Seen-route skip button is missing.")
		if skip_button != null:
			skip_button.pressed.emit()
		await process_frame
		await process_frame
		_check(
			_scene_router.current_stage == SceneRouterService.Stage.FLIGHT
			and _game_state.travel_state == GameStateModel.TravelState.COMPLETED,
			"Skipping a seen journey must complete the route and hand off to FLIGHT."
		)

	await _cleanup()
	_finish_smoke()


func _prepare_confirmed_order() -> void:
	_check(_game_state.accept_order(_order), "Travel smoke could not accept the Red Sand order.")
	_check(
		_game_state.confirm_departure(_order),
		"Travel smoke could not confirm the default M0 ship loadout."
	)


func _get_active_cockpit() -> Cockpit:
	if _app == null or _app.scene_container.get_child_count() != 1:
		return null
	return _app.scene_container.get_child(0) as Cockpit


func _push_accept_key() -> void:
	var input_event: InputEventKey = InputEventKey.new()
	input_event.keycode = KEY_ENTER
	input_event.physical_keycode = KEY_ENTER
	input_event.pressed = true
	root.push_input(input_event)
	input_event = input_event.duplicate() as InputEventKey
	input_event.pressed = false
	root.push_input(input_event)


func _cleanup() -> void:
	if _app != null and is_instance_valid(_app):
		_app.queue_free()
		await process_frame
		await process_frame
	if _game_state != null:
		_game_state.reset_runtime_state()


func _finish_smoke() -> void:
	TranslationServer.set_locale(_original_locale)
	if _failures.is_empty():
		print(
			"[cockpit-travel] PASS: departure gates, mouse/keyboard confirmation, "
			+ "three phases, FLIGHT handoff, retained state, and duplicate protection."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[cockpit-travel] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
