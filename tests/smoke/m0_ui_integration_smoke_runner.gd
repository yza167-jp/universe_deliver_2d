extends SceneTree

const COCKPIT_SCENE_PATH: String = "res://scenes/cockpit/cockpit.tscn"
const ROUTE_SCENE_PATH: String = "res://scenes/flight/red_sand_flight.tscn"
const RESULTS_SCENE_PATH: String = "res://scenes/app/results.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const TEST_SETTINGS_PATH: String = "user://t053_m0_ui_settings.cfg"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []
var _game_state: GameStateModel
var _settings_service: SettingsServiceModel


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	_game_state = root.get_node_or_null("GameState") as GameStateModel
	_settings_service = SettingsServiceModel.new()
	_settings_service.storage_path = TEST_SETTINGS_PATH
	_remove_test_settings()

	if _prepare_active_order():
		await _check_cockpit_company_briefing()
		await _check_route_guidance_and_company_alert()
		await _check_results_next_step()

	if _game_state != null:
		_game_state.reset_runtime_state()
	_remove_test_settings()
	if is_instance_valid(_settings_service):
		_settings_service.free()
	TranslationServer.set_locale(original_locale)
	await process_frame
	if _failures.is_empty():
		print(
			"[m0-ui-integration] PASS: cockpit risk briefing, player-facing assist "
			+ "toggles, independent company alert, and results next step."
		)
		quit(0)
		return
	for failure: String in _failures:
		printerr("[m0-ui-integration] %s" % failure)
	quit(1)


func _prepare_active_order() -> bool:
	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	_check(_game_state != null, "GameState autoload is unavailable.")
	_check(order != null, "Red Sand order could not be loaded.")
	if _game_state == null or order == null:
		return false
	_game_state.reset_runtime_state()
	_check(_game_state.accept_order(order), "Red Sand order could not be accepted.")
	return not _game_state.current_order_id.is_empty()


func _check_cockpit_company_briefing() -> void:
	var packed_scene: PackedScene = load(COCKPIT_SCENE_PATH) as PackedScene
	var cockpit: Cockpit = packed_scene.instantiate() as Cockpit if packed_scene != null else null
	_check(cockpit != null, "Cockpit scene could not be instantiated.")
	if cockpit == null:
		return
	root.add_child(cockpit)
	await process_frame
	await process_frame
	_check(
		cockpit.activate_hotspot(&"company_terminal"),
		"Company terminal could not be activated."
	)
	var briefing: String = cockpit.get_device_panel_body()
	_check(
		briefing.contains("航线风险：2/5")
		and briefing.contains("优先保护护盾与货物")
		and briefing.contains("自愿职业成长"),
		"Cockpit company terminal lacks actionable risk or management-humor text."
	)
	var device_panel: Control = cockpit.get_node_or_null("ModalLayer/DevicePanel") as Control
	_check(
		device_panel != null and VIEWPORT_RECT.encloses(device_panel.get_global_rect()),
		"Cockpit company briefing leaves the 640x360 viewport."
	)
	cockpit.queue_free()
	await process_frame
	await process_frame


func _check_route_guidance_and_company_alert() -> void:
	var packed_scene: PackedScene = load(ROUTE_SCENE_PATH) as PackedScene
	var route: RedSandFlight = packed_scene.instantiate() as RedSandFlight if packed_scene != null else null
	_check(route != null, "Red Sand route scene could not be instantiated.")
	if route == null:
		return
	route.settings_service_override = _settings_service
	route.force_direct_test_mode = true
	root.add_child(route)
	await process_frame
	await process_frame
	await process_frame

	var hud: RedSandRouteHUD = route.get_route_hud()
	var visuals: RedSandRouteVisuals = route.get_route_visuals()
	var help: FlightControlsHelp = hud.get_controls_help() if hud != null else null
	_check(route.is_controls_help_open(), "Initial flight controls help did not open.")
	_check(help != null and help.visible, "Flight controls help is unavailable.")
	if help != null:
		_check(
			help.is_route_hints_enabled()
			and help.get_route_hints_button().text.contains("已开启")
			and not help.is_high_contrast_enabled()
			and help.get_high_contrast_button().text.contains("已关闭"),
			"Flight controls help does not expose textual assist-setting states."
		)
		_check(
			help.get_route_hints_button().focus_mode == Control.FOCUS_ALL
			and help.get_high_contrast_button().focus_mode == Control.FOCUS_ALL,
			"Assist settings are not keyboard focusable."
		)
		help.get_route_hints_button().button_pressed = false
		await process_frame
		_check(
			not _settings_service.settings.route_hints_enabled
			and visuals != null
			and not visuals.are_route_hints_visible()
			and help.get_route_hints_button().text.contains("已关闭"),
			"Route guidance toggle did not update settings, text, and route visuals."
		)
		help.get_high_contrast_button().button_pressed = true
		await process_frame
		_check(
			_settings_service.settings.high_contrast_terrain
			and visuals != null
			and visuals.is_high_contrast_enabled()
			and visuals.get_floor_edge_width() >= 4.9
			and route.get_low_flight_course().is_high_contrast_enabled()
			and route.get_landing_zone().is_high_contrast_enabled()
			and help.get_high_contrast_button().text.contains("已开启"),
			"High-contrast toggle did not update all Red Sand terrain consumers."
		)
		_check(
			FileAccess.file_exists(TEST_SETTINGS_PATH)
			and help.get_settings_feedback_text().contains("已保存"),
			"Player-facing assist settings did not confirm persistence."
		)

	route.close_controls_help()
	await process_frame
	if hud != null:
		hud.show_company_warning(&"UI_FLIGHT_COMPANY_WARNING_CARGO_MEDIUM", 58.0)
		var company_message: String = hud.get_company_alert_body_text()
		_check(
			hud.is_company_alert_visible()
			and hud.get_company_alert_heading_text().contains("！！")
			and hud.get_company_alert_heading_text().contains("风险警告")
			and company_message.contains("货物完整度 58%")
			and company_message.contains("优先保护货物并降低速度")
			and company_message.contains("事故表格"),
			"Company alert lacks severity, actionable information, or institutional humor."
		)
		_check(
			VIEWPORT_RECT.encloses(hud.get_company_alert_rect())
			and hud.get_route_panel_rect() == Rect2(),
			"Company alert does not reuse the reserved route-card footprint."
		)
		hud.show_lightning_hit(8.0)
		_check(
			hud.get_status_text().contains("雷击命中")
			and hud.is_company_alert_visible()
			and hud.get_company_alert_body_text() == company_message,
			"General flight feedback overwrote the dedicated company alert."
		)
		hud._process(RedSandRouteHUD.COMPANY_ALERT_DURATION_SECONDS + 0.1)
		_check(
			not hud.is_company_alert_visible()
			and not hud.get_route_panel_rect().is_equal_approx(Rect2()),
			"Company alert did not restore the route card after its bounded duration."
		)

	route.queue_free()
	await process_frame
	await process_frame


func _check_results_next_step() -> void:
	if not _prepare_active_order():
		return
	var run_state: OrderRunState = _game_state.get_active_order_run_state()
	_check(run_state != null, "Results fixture has no order run state.")
	if run_state == null:
		return
	run_state.entry_style = FlightStyleTracker.STYLE_BALANCED
	run_state.cargo_integrity = 92.0
	run_state.record_landing_result(OrderRunState.LANDING_RESULT_SMOOTH, 0.0)

	var packed_scene: PackedScene = load(RESULTS_SCENE_PATH) as PackedScene
	var results: OrderResults = packed_scene.instantiate() as OrderResults if packed_scene != null else null
	_check(results != null, "Results scene could not be instantiated.")
	if results == null:
		return
	root.add_child(results)
	await process_frame
	await process_frame
	_check(
		results.is_settlement_committed()
		and results.get_next_step_text().contains("下一步")
		and results.get_next_step_text().contains("返回快递站")
		and results.get_next_step_text().contains("老皮"),
		"Results scene does not state the next player action."
	)
	var next_step_label: Label = results.get_node_or_null(
		"ContentPanel/Margin/Content/NextStepLabel"
	) as Label
	_check(
		next_step_label != null
		and VIEWPORT_RECT.encloses(next_step_label.get_global_rect()),
		"Results next-step guidance leaves the 640x360 viewport."
	)
	results.queue_free()
	await process_frame
	await process_frame


func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
