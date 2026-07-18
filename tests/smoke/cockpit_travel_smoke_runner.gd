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
	_check(
		cockpit.focus_hotspot(&"window_view")
		and cockpit.get_selected_hotspot_id() == &"window_view",
		"Forward Window could not prepare the residual-focus regression check."
	)
	var forward_window: Button = cockpit.get_hotspot_button(&"window_view")
	var forward_window_rect: Rect2 = cockpit.get_forward_window_rect()
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
	var status_panel: PanelContainer = cockpit.get_node_or_null("StatusPanel") as PanelContainer
	var travel_progress: ProgressBar = cockpit.get_node_or_null(
		"StatusPanel/Margin/Content/TravelProgressBar"
	) as ProgressBar
	var travel_prompt: Label = cockpit.get_node_or_null(
		"StatusPanel/Margin/Content/StatusRow/PromptLabel"
	) as Label
	_check(
		cockpit.is_forward_window_passive()
		and forward_window != null
		and not forward_window.visible
		and forward_window.focus_mode == Control.FOCUS_NONE
		and forward_window.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and not forward_window.has_focus()
		and cockpit.get_selected_hotspot_id() != &"window_view",
		"Active travel must clear and disable all Forward Window interaction state."
	)
	var selected_before_hover: StringName = cockpit.get_selected_hotspot_id()
	if forward_window != null:
		forward_window.mouse_entered.emit()
	_check(
		cockpit.get_selected_hotspot_id() == selected_before_hover
		and not cockpit.focus_hotspot(&"window_view")
		and not cockpit.activate_hotspot(&"window_view"),
		"Forward Window must ignore hover, focus, and activation during travel."
	)
	_check(
		status_panel != null
		and status_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and travel_progress != null
		and travel_progress.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and travel_prompt != null
		and travel_prompt.max_lines_visible == 2
		and not cockpit.get_travel_hud_rect().intersects(forward_window_rect, false),
		"Travel HUD must remain compact, mouse-passive, and outside the Forward Window."
	)
	_check(
		cockpit.activate_hotspot(&"navigation_screen"),
		"Navigation should remain inspectable while travel is active."
	)
	await process_frame
	_check(
		not cockpit.is_navigation_action_enabled()
		and cockpit.get_device_panel_body().contains(tr("UI_COCKPIT_NAV_ROUTE_ACTIVE")),
		"Navigation must visibly report that the route is already active."
	)
	var phase_before_repeat: GameStateModel.TravelState = _game_state.travel_state
	if action_button != null:
		action_button.pressed.emit()
	_check(
		_game_state.travel_state == phase_before_repeat
		and not cockpit.start_configured_travel()
		and _game_state.last_travel_error == GameStateModel.TRAVEL_ERROR_ALREADY_STARTED,
		"Navigation must not start a second travel sequence."
	)
	cockpit.close_active_modal()
	await process_frame

	var radio_button: Button = cockpit.get_hotspot_button(&"radio")
	var radio_player: AudioStreamPlayer = cockpit.get_radio_audio_player()
	var radio_feedback: CockpitRadioFeedback = cockpit.get_radio_feedback()
	var dialogue_ui: DialogueUI = cockpit.get_dialogue_ui()
	var radio_player_id: int = 0 if radio_player == null else radio_player.get_instance_id()
	var radio_stream_id: int = (
		0
		if radio_player == null or radio_player.stream == null
		else radio_player.stream.get_instance_id()
	)
	_check(
		radio_button != null
		and radio_player != null
		and radio_player.stream is AudioStreamWAV
		and radio_feedback != null,
		"Radio requires one local loop player and one visual feedback control."
	)
	if radio_button != null:
		radio_button.pressed.emit()
	await process_frame
	_check(
		cockpit.is_radio_on()
		and cockpit.is_radio_audio_playing()
		and radio_feedback != null
		and radio_feedback.is_active()
		and dialogue_ui != null
		and cockpit.is_dialogue_active()
		and cockpit.get_active_dialogue_id() == &"dialogue_lao_pi_travel_radio"
		and controller != null
		and controller.is_narrative_held(),
		"First travel Radio activation must start its optional dialogue and hold the route."
	)
	_check(
		not cockpit.activate_hotspot(&"cargo_indicator"),
		"Cargo dialogue must not overlap an active Radio dialogue."
	)
	if controller != null:
		controller.advance_travel(controller.departure_duration * 2.0)
	_check(
		_game_state.travel_state == GameStateModel.TravelState.DEPARTURE,
		"Travel time must remain stable while an optional dialogue owns attention."
	)
	if dialogue_ui != null:
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"Radio dialogue must support the common whole-sequence skip."
		)
	await process_frame
	_check(
		not cockpit.is_dialogue_active()
		and controller != null
		and not controller.is_narrative_held()
		and _game_state.has_read_dialogue_line(
			&"dialogue_lao_pi_travel_radio",
			&"radio_company"
		),
		"Finishing Radio dialogue must record read state and resume travel."
	)
	if radio_feedback != null:
		var radio_phase_before: float = radio_feedback.get_pulse_phase()
		radio_feedback.advance_animation(0.2)
		_check(
			not is_equal_approx(radio_feedback.get_pulse_phase(), radio_phase_before),
			"Radio On feedback must visibly animate."
		)
	_check(cockpit.focus_hotspot(&"radio"), "Radio must remain keyboard-focusable during travel.")
	_push_interact_action()
	await process_frame
	_check(
		not cockpit.is_radio_on()
		and not cockpit.is_radio_audio_playing()
		and radio_feedback != null
		and not radio_feedback.is_active(),
		"Keyboard activation must stop the same radio loop and visual waveform."
	)
	if radio_button != null:
		radio_button.pressed.emit()
		radio_button.pressed.emit()
	await process_frame
	_check(
		not cockpit.is_radio_on()
		and radio_player != null
		and radio_player.get_instance_id() == radio_player_id
		and radio_player.stream != null
		and radio_player.stream.get_instance_id() == radio_stream_id,
		"Repeated Radio toggles must not stack players or replace the loop stream."
	)
	_check(
		cockpit.get_travel_phase_text() == tr("UI_COCKPIT_TRAVEL_PHASE_DEPARTURE"),
		"Optional Radio interaction must not replace the active travel status."
	)

	_check(
		cockpit.activate_hotspot(&"cargo_indicator"),
		"Cargo indicator must start its unread optional travel dialogue."
	)
	await process_frame
	_check(
		cockpit.is_dialogue_active()
		and cockpit.get_active_dialogue_id() == &"dialogue_lao_pi_travel_cargo"
		and controller != null
		and controller.is_narrative_held()
		and not _game_state.has_story_flag(Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG),
		"Cargo dialogue must remain optional and distinct from the required dialogue."
	)
	if dialogue_ui != null:
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"Cargo dialogue must support the common whole-sequence skip."
		)
	await process_frame
	_check(
		not cockpit.is_dialogue_active()
		and controller != null
		and not controller.is_narrative_held()
		and _game_state.has_read_dialogue_line(
			&"dialogue_lao_pi_travel_cargo",
			&"cargo_people"
		),
		"Finishing Cargo dialogue must record read state and resume travel."
	)
	_check(
		cockpit.activate_hotspot(&"cargo_indicator"),
		"A read Cargo dialogue must return the hotspot to its status panel."
	)
	await process_frame
	_check(
		cockpit.get_open_panel_id() == &"cargo_indicator" and not cockpit.is_dialogue_active(),
		"Read Cargo interaction must not replay its optional dialogue."
	)
	cockpit.close_active_modal()
	await process_frame

	if controller != null:
		controller.advance_travel(controller.departure_duration + 0.1)
	await process_frame
	await process_frame
	_check(
		_game_state.travel_state == GameStateModel.TravelState.CRUISE
		and cockpit.is_dialogue_active()
		and cockpit.get_active_dialogue_id() == &"dialogue_lao_pi_travel_main"
		and controller != null
		and controller.is_narrative_held(),
		"Cruise must automatically start the required Lao Pi travel dialogue."
	)
	_check(
		not cockpit.activate_hotspot(&"radio")
		and not cockpit.activate_hotspot(&"cargo_indicator"),
		"Optional hotspot dialogues must not overlap the required travel dialogue."
	)
	_check(
		cockpit.close_active_modal(),
		"The required dialogue must still respond to the common cancel action."
	)
	await process_frame
	await process_frame
	_check(
		cockpit.is_dialogue_active()
		and cockpit.get_active_dialogue_id() == &"dialogue_lao_pi_travel_main"
		and not _game_state.has_story_flag(Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)
		and controller != null
		and controller.is_narrative_held(),
		"Canceling required content must safely re-present it without advancing travel."
	)
	if dialogue_ui != null:
		dialogue_ui.quick_show_current_line()
		_check(
			dialogue_ui.continue_dialogue(),
			"Required travel dialogue could not reach its loadout-specific comment."
		)
		dialogue_ui.quick_show_current_line()
		_check(
			dialogue_ui.get_full_text() == tr("DIALOGUE_LAO_PI_TRAVEL_MAIN_NO_LASER"),
			"Default loadout must receive Lao Pi's no-laser travel comment."
		)
		_check(
			dialogue_ui.skip_dialogue_sequence()
			== DialogueRuntime.SequenceSkipResult.FINISHED,
			"Required travel dialogue must remain explicitly skippable."
		)
	await process_frame
	_check(
		_game_state.has_story_flag(Cockpit.TRAVEL_MAIN_DIALOGUE_COMPLETED_FLAG)
		and not cockpit.is_dialogue_active()
		and controller != null
		and not controller.is_narrative_held(),
		"Completing required dialogue must persist its flag and resume travel once."
	)
	_check(
		cockpit.activate_hotspot(&"radio"),
		"Read Radio hotspot must keep its normal toggle behavior after the dialogue."
	)
	_check(
		not cockpit.is_dialogue_active(),
		"Read Radio dialogue must not replay after required content."
	)
	if cockpit.is_radio_on():
		cockpit.activate_hotspot(&"radio")
	if controller != null:
		controller.advance_travel(controller.cruise_duration + 0.1)
	_check(
		_game_state.travel_state == GameStateModel.TravelState.APPROACH
		and cockpit.get_travel_detail_text()
		== tr("UI_COCKPIT_TRAVEL_DETAIL_APPROACH"),
		"Approach must present the localized side-view flight control hint."
	)
	if controller != null:
		controller.advance_travel(controller.approach_duration + 0.1)
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
			reopened_cockpit.is_forward_window_passive(),
			"Completed handoff state must keep Forward Window interaction passive."
		)
		_check(
			not reopened_cockpit.start_configured_travel()
			and _game_state.last_travel_error
			== GameStateModel.TRAVEL_ERROR_ALREADY_COMPLETED,
			"Completed travel must reject a repeated departure trigger."
		)

	_game_state.reset_runtime_state()
	await process_frame
	if reopened_cockpit != null:
		var restored_window: Button = reopened_cockpit.get_hotspot_button(&"window_view")
		_check(
			not reopened_cockpit.is_forward_window_passive()
			and not reopened_cockpit.is_travel_status_visible()
			and restored_window != null
			and restored_window.visible
			and restored_window.focus_mode == Control.FOCUS_ALL
			and restored_window.mouse_filter == Control.MOUSE_FILTER_STOP
			and reopened_cockpit.focus_hotspot(&"window_view"),
			"Returning to idle must restore Forward Window visuals and input."
		)
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
			"StatusPanel/Margin/Content/StatusRow/SkipTravelButton"
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


func _push_interact_action() -> void:
	var input_event: InputEventAction = InputEventAction.new()
	input_event.action = Cockpit.INTERACT_ACTION
	input_event.pressed = true
	root.push_input(input_event)
	var release_event: InputEventAction = input_event.duplicate() as InputEventAction
	release_event.pressed = false
	root.push_input(release_event)


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
			"[cockpit-travel] PASS: required and optional dialogue isolation, narrative holds, "
			+ "loadout comment, control hint, and retained FLIGHT handoff."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[cockpit-travel] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
