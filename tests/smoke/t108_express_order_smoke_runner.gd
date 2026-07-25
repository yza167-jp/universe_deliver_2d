extends SceneTree

const APP_SCENE_PATH: String = "res://scenes/app/app.tscn"
const EXPRESS_HUD_SCENE_PATH: String = "res://scenes/ui/express_order_hud.tscn"
const FLIGHT_HELP_SCENE_PATH: String = "res://scenes/ui/flight_controls_help.tscn"
const RED_SAND_HUD_SCENE_PATH: String = "res://scenes/ui/red_sand_route_hud.tscn"
const ORDER_TERMINAL_SCENE_PATH: String = "res://scenes/ui/order_terminal.tscn"
const RESULTS_SCENE_PATH: String = "res://scenes/app/results.tscn"
const DIALOGUE_SEQUENCE_PATH: String = (
	"res://data/dialogue/lao_pi_system_test.tres"
)
const TIDAL_EXPRESS_ORDER_PATH: String = (
	"res://data/orders/side_tidal_beacon_before_eye.tres"
)
const M0_ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const TEST_ROUTE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _app: UniverseDeliverApp


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_check(_game_state != null, "GameState autoload is unavailable.")
	var registered_order: OrderDefinition = load(
		TIDAL_EXPRESS_ORDER_PATH
	) as OrderDefinition
	var fixture: OrderDefinition = _make_playable_fixture(registered_order)
	_check(
		registered_order != null
		and fixture != null
		and registered_order.content_readiness
		== OrderDefinition.ContentReadiness.REGISTERED_ONLY,
		"Express smoke fixture is unavailable or changed the registered packet.",
	)
	if _game_state == null or fixture == null:
		await _finish(original_locale)
		return

	var app_scene: PackedScene = load(APP_SCENE_PATH) as PackedScene
	_app = app_scene.instantiate() as UniverseDeliverApp
	_check(_app != null, "App scene did not instantiate.")
	if _app == null:
		await _finish(original_locale)
		return
	root.add_child(_app)
	await _settle_frames(3)
	var hud: ExpressOrderHUD = _app.get_node_or_null(
		"PersistentUI/ExpressOrderHUD"
	) as ExpressOrderHUD
	_check(hud != null, "App PersistentUI is missing the express HUD driver.")
	if hud == null:
		await _finish(original_locale)
		return
	hud.set_process(false)
	_game_state.reset_runtime_state()
	_check(
		_game_state.accept_order(fixture),
		"Playable express smoke fixture could not be accepted.",
	)
	hud.set_order_override(fixture)
	hud.set_pause_state_override(false, false, false)
	_check(
		hud.advance_timing(30.0)
		and is_equal_approx(_game_state.order_run_state.elapsed_time, 30.0),
		"The persistent driver did not accumulate active express time.",
	)

	await _check_single_driver_and_scene_survival(hud, fixture)
	await _check_pause_sources(hud)
	await _check_hud_states_and_layout(hud)
	await _check_order_terminal_detail(fixture)
	await _check_express_and_m0_results(fixture)
	await _finish(original_locale)


func _check_single_driver_and_scene_survival(
	hud: ExpressOrderHUD,
	fixture: OrderDefinition
) -> void:
	_check(
		get_nodes_in_group(ExpressOrderHUD.DRIVER_GROUP).size() == 1,
		"App must contain exactly one persistent express timer driver.",
	)
	var duplicate_scene: PackedScene = load(EXPRESS_HUD_SCENE_PATH) as PackedScene
	var duplicate: ExpressOrderHUD = duplicate_scene.instantiate() as ExpressOrderHUD
	_app.get_node("PersistentUI").add_child(duplicate)
	await process_frame
	duplicate.set_process(false)
	duplicate.set_game_state_override(_game_state)
	duplicate.set_order_override(fixture)
	duplicate.set_pause_state_override(false, false, false)
	var elapsed_before_duplicate: float = _game_state.order_run_state.elapsed_time
	_check(
		hud.advance_timing(1.0)
		and not duplicate.advance_timing(1.0)
		and is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_duplicate + 1.0
		),
		"A duplicate HUD must not accumulate a second delta in the same frame.",
	)
	duplicate.queue_free()
	await _settle_frames(2)
	_check(
		get_nodes_in_group(ExpressOrderHUD.DRIVER_GROUP).size() == 1,
		"Removing a duplicate must leave the App driver authoritative.",
	)

	var hud_instance_id: int = hud.get_instance_id()
	var scene_router: SceneRouterService = root.get_node_or_null(
		"SceneRouter"
	) as SceneRouterService
	_check(scene_router != null, "SceneRouter autoload is unavailable.")
	if scene_router == null:
		return
	_check(
		scene_router.debug_switch_to_stage(SceneRouterService.Stage.STATION),
		"Express smoke could not switch to Station.",
	)
	await _settle_frames(3)
	var elapsed_before_scene: float = _game_state.order_run_state.elapsed_time
	_check(
		_app.get_node_or_null("PersistentUI/ExpressOrderHUD") == hud
		and hud.get_instance_id() == hud_instance_id
		and hud.advance_timing(2.0)
		and is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_scene + 2.0
		),
		"Scene changes must retain the same timer and elapsed value.",
	)
	_check(
		scene_router.debug_switch_to_stage_scene(
			SceneRouterService.Stage.FLIGHT,
			UniverseDeliverApp.DELIVERY_LAB_SCENE_PATH
		),
		"Express smoke could not open Delivery Lab for checkpoint retry.",
	)
	await _settle_frames(3)
	var delivery_lab: DeliveryLab = _app.scene_container.get_child(0) as DeliveryLab
	var elapsed_before_retry: float = _game_state.order_run_state.elapsed_time
	_check(
		delivery_lab != null
		and delivery_lab.restart_from_checkpoint(false)
		and is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_retry
		),
		"R/checkpoint retry must not clear active express elapsed time.",
	)


func _check_pause_sources(hud: ExpressOrderHUD) -> void:
	hud.clear_pause_state_override()
	var elapsed_before_pause: float = _game_state.order_run_state.elapsed_time
	var dialogue_ui: DialogueUI = _app.get_node_or_null(
		"PersistentUI/DialogueUI"
	) as DialogueUI
	_check(dialogue_ui != null, "Persistent DialogueUI is unavailable.")
	if dialogue_ui != null:
		if dialogue_ui.visible:
			dialogue_ui.cancel_dialogue()
			await process_frame
		var dialogue_sequence: DialogueSequence = load(
			DIALOGUE_SEQUENCE_PATH
		) as DialogueSequence
		_check(
			dialogue_sequence != null
			and dialogue_ui.start_dialogue(dialogue_sequence, _game_state),
			"Express pause dialogue fixture could not start.",
		)
		hud.advance_timing(4.0)
		_check(
			is_equal_approx(
				_game_state.order_run_state.elapsed_time,
				elapsed_before_pause
			)
			and dialogue_ui.is_express_pause_notice_visible(),
			"Visible dialogue must freeze timing and show its express notice.",
		)
		dialogue_ui.cancel_dialogue()
		await process_frame

	var help_scene: PackedScene = load(FLIGHT_HELP_SCENE_PATH) as PackedScene
	var help: FlightControlsHelp = help_scene.instantiate() as FlightControlsHelp
	root.add_child(help)
	await process_frame
	help.show_help(false, false)
	hud.advance_timing(4.0)
	_check(
		is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_pause
		)
		and help.is_express_pause_notice_visible(),
		"Visible flight help must freeze timing and show its express notice.",
	)
	help.hide_help()
	help.queue_free()
	await process_frame

	paused = true
	hud.advance_timing(4.0)
	_check(
		is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_pause
		)
		and hud.get_timing_status() == M1OrderRules.TIMING_STATUS_PAUSED
		and hud.get_primary_text().contains("已暂停"),
		"SceneTree pause must freeze timing and expose the paused HUD state.",
	)
	paused = false
	hud.advance_timing(1.0)
	_check(
		is_equal_approx(
			_game_state.order_run_state.elapsed_time,
			elapsed_before_pause + 1.0
		),
		"Timing must resume once all pause sources close.",
	)


func _check_hud_states_and_layout(hud: ExpressOrderHUD) -> void:
	hud.set_pause_state_override(false, false, false)
	_game_state.order_run_state.elapsed_time = 30.0
	hud.refresh_from_state()
	_check(
		hud.is_timing_visible()
		and hud.get_timing_status() == M1OrderRules.TIMING_STATUS_FULL_REWARD
		and hud.get_primary_text().contains("00:30")
		and hud.get_primary_text().contains("01:30")
		and hud.get_secondary_text().contains("100%"),
		"Full-reward HUD state must show elapsed, remaining, and 100 percent.",
	)
	_game_state.order_run_state.elapsed_time = 150.0
	hud.refresh_from_state()
	_check(
		hud.get_timing_status() == M1OrderRules.TIMING_STATUS_GRACE
		and hud.get_primary_text().contains("超时")
		and hud.get_secondary_text().contains("75%"),
		"Grace HUD state must show overtime and the current linear ratio.",
	)
	_game_state.order_run_state.elapsed_time = 240.0
	hud.refresh_from_state()
	_check(
		hud.get_timing_status() == M1OrderRules.TIMING_STATUS_FLOOR
		and hud.get_secondary_text().contains("最低报酬")
		and hud.get_secondary_text().contains("50%"),
		"Floor HUD state must describe a minimum payout rather than failure.",
	)
	hud.set_pause_state_override(true, false, false)
	_check(
		hud.get_timing_status() == M1OrderRules.TIMING_STATUS_PAUSED
		and hud.get_primary_text().contains("已暂停")
		and hud.get_secondary_text().contains("冻结"),
		"Paused HUD state must make the frozen timer explicit.",
	)
	hud.set_pause_state_override(false, false, false)
	_check(
		VIEWPORT_RECT.encloses(hud.get_panel_rect())
		and hud.get_child_count() == 1,
		"Express HUD must stay inside 640x360 with one compact two-line panel.",
	)

	var route_hud_scene: PackedScene = load(RED_SAND_HUD_SCENE_PATH) as PackedScene
	var route_hud: RedSandRouteHUD = (
		route_hud_scene.instantiate() as RedSandRouteHUD
	)
	root.add_child(route_hud)
	await process_frame
	for panel_path: String in [
		"FlightPanel",
		"DiagnosticsPanel",
		"RoutePanel",
		"RadarPanel",
		"LandingPanel",
		"StatusPanel",
	]:
		var panel: Control = route_hud.get_node_or_null(panel_path) as Control
		_check(
			panel != null
			and not hud.get_panel_rect().intersects(panel.get_global_rect(), false),
			"Express HUD overlaps Red Sand core panel %s." % panel_path,
		)
	route_hud.queue_free()
	await process_frame
	var m0_order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	_game_state.reset_runtime_state()
	_game_state.accept_order(m0_order)
	hud.set_order_override(m0_order)
	hud.refresh_from_state()
	_check(
		not hud.is_timing_visible()
		and not hud.advance_timing(5.0)
		and is_zero_approx(_game_state.order_run_state.elapsed_time),
		"Non-express orders must hide the HUD and never accumulate time.",
	)


func _check_order_terminal_detail(fixture: OrderDefinition) -> void:
	var terminal_state: GameStateModel = GameStateModel.new()
	terminal_state.accept_order(fixture)
	var terminal_scene: PackedScene = load(ORDER_TERMINAL_SCENE_PATH) as PackedScene
	var terminal: OrderTerminalUI = terminal_scene.instantiate() as OrderTerminalUI
	terminal.game_state_override = terminal_state
	terminal.order_definition = fixture
	root.add_child(terminal)
	await process_frame
	_check(terminal.open_terminal(), "Express order terminal did not open.")
	await process_frame
	var timing_label: Label = terminal.get_node_or_null(
		"%ExpressTimingLabel"
	) as Label
	_check(
		terminal.is_express_timing_visible()
		and terminal.get_express_timing_text().contains("02:00")
		and terminal.get_express_timing_text().contains("01:00")
		and terminal.get_express_timing_text().contains("50%")
		and terminal.get_express_timing_text().contains("不会直接失败")
		and timing_label != null
		and terminal.get_detail_scroll_rect().intersects(
			timing_label.get_global_rect(),
			false
		),
		"Order detail must visibly explain target, grace, floor, and no hard failure.",
	)
	var m0_order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	var m0_state: GameStateModel = GameStateModel.new()
	m0_state.accept_order(m0_order)
	terminal.set_game_state_override(m0_state)
	terminal.set_order_definition(m0_order)
	_check(
		not terminal.is_express_timing_visible()
		and terminal.get_express_timing_text().is_empty(),
		"Non-express order detail must remove the timing row completely.",
	)
	terminal.queue_free()
	await process_frame
	terminal_state.free()
	m0_state.free()


func _check_express_and_m0_results(fixture: OrderDefinition) -> void:
	var results_scene: PackedScene = load(RESULTS_SCENE_PATH) as PackedScene
	var express_state: GameStateModel = GameStateModel.new()
	express_state.accept_order(fixture)
	express_state.order_run_state.cargo_integrity = 50.0
	express_state.order_run_state.elapsed_time = 150.0
	var express_results: OrderResults = results_scene.instantiate() as OrderResults
	express_results.order = fixture
	express_results.game_state_override = express_state
	root.add_child(express_results)
	await _settle_frames(2)
	var express_settlement: OrderSettlementResult = (
		express_results.get_settlement_result()
	)
	var reward_grid: Control = express_results.get_node_or_null(
		"ContentPanel/Margin/Content/RewardGrid"
	) as Control
	var narrative_label: Control = express_results.get_node_or_null(
		"%NarrativeLabel"
	) as Control
	_check(
		express_results.is_settlement_committed()
		and express_settlement != null
		and express_settlement.total_reward == 72
		and express_settlement.time_adjustment == -24
		and express_results.is_timing_panel_visible()
		and express_results.get_timing_text().contains("02:30")
		and express_results.get_timing_text().contains("宽限")
		and express_results.get_timing_text().contains("75%")
		and express_results.get_timing_text().contains("-24"),
		"Express results must visibly show the single cargo-then-time settlement.",
	)
	_check(
		VIEWPORT_RECT.encloses(express_results.get_timing_panel_rect())
		and reward_grid != null
		and narrative_label != null
		and not express_results.get_timing_panel_rect().intersects(
			reward_grid.get_global_rect(),
			false
		)
		and not express_results.get_timing_panel_rect().intersects(
			narrative_label.get_global_rect(),
			false
		),
		(
			"Express timing results overlap another 640x360 results section: "
			+ "timing=%s reward=%s narrative=%s"
			% [
				express_results.get_timing_panel_rect(),
				reward_grid.get_global_rect() if reward_grid != null else Rect2(),
				narrative_label.get_global_rect()
				if narrative_label != null
				else Rect2(),
			]
		),
	)
	express_results.queue_free()
	await process_frame
	express_state.free()

	var m0_order: OrderDefinition = load(M0_ORDER_PATH) as OrderDefinition
	var m0_state: GameStateModel = GameStateModel.new()
	m0_state.accept_order(m0_order)
	m0_state.order_run_state.cargo_integrity = 92.0
	m0_state.order_run_state.record_landing_result(
		OrderRunState.LANDING_RESULT_SMOOTH,
		0.0
	)
	var m0_results: OrderResults = results_scene.instantiate() as OrderResults
	m0_results.order = m0_order
	m0_results.game_state_override = m0_state
	root.add_child(m0_results)
	await _settle_frames(2)
	_check(
		m0_results.is_settlement_committed()
		and m0_results.get_settlement_result() != null
		and m0_results.get_settlement_result().total_reward == 97
		and not m0_results.is_timing_panel_visible()
		and m0_results.get_timing_text().is_empty()
		and m0_results.get_station_change_text().contains("中继铭牌"),
		"M0 results must retain 97 credits, layout content, and no timing row.",
	)
	m0_results.queue_free()
	await process_frame
	m0_state.free()


func _make_playable_fixture(
	registered_order: OrderDefinition
) -> OrderDefinition:
	if registered_order == null or registered_order.destination_planet == null:
		return null
	var order: OrderDefinition = registered_order.duplicate(true) as OrderDefinition
	var planet: PlanetDefinition = (
		registered_order.destination_planet.duplicate(true) as PlanetDefinition
	)
	order.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	order.required_chapter = &""
	order.unlock_conditions.clear()
	order.story_requirements.clear()
	planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	planet.flight_scene_path = TEST_ROUTE_PATH
	planet.required_story_flags.clear()
	order.destination_planet = planet
	return order


func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in frame_count:
		await process_frame


func _finish(original_locale: String) -> void:
	paused = false
	if _game_state != null:
		_game_state.reset_runtime_state()
	if is_instance_valid(_app):
		_app.queue_free()
		await _settle_frames(2)
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print(
			"[t108-express] PASS: persistent timing, pause sources, HUD, "
			+ "terminal details, settlement order, and M0 layout."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[t108-express] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
