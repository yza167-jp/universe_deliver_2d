extends SceneTree

const STATION_SCENE_PATH: String = "res://scenes/station/station_hub.tscn"
const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const VIEWPORT_RECT: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var original_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var game_state: GameStateModel = root.get_node_or_null("GameState") as GameStateModel
	_check(game_state != null, "GameState autoload is unavailable.")
	if game_state == null:
		_finish_smoke(original_locale)
		return
	game_state.reset_runtime_state()
	game_state.set_story_flag(StationTutorialController.COMPLETION_FLAG)

	var order: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var station_scene: PackedScene = load(STATION_SCENE_PATH) as PackedScene
	var station: StationHub = station_scene.instantiate() as StationHub
	root.add_child(station)
	await process_frame
	await process_frame

	var player: StationPlayer = station.get_station_player()
	var loadout_ui: ShipLoadoutUI = station.get_ship_loadout_ui()
	var workbench: Interactable2D = station.get_node_or_null(
		"Interactables/ShipWorkbench"
	) as Interactable2D
	_check(player != null, "Station player is missing.")
	_check(loadout_ui != null, "Ship loadout UI is missing from the station.")
	_check(workbench != null, "Ship workbench interactable is missing.")
	if player == null or loadout_ui == null or workbench == null:
		station.queue_free()
		game_state.reset_runtime_state()
		await process_frame
		_finish_smoke(original_locale)
		return

	_check(workbench.interact(player), "Ship workbench interaction was rejected.")
	await process_frame
	_check(loadout_ui.visible, "Ship workbench did not open the loadout UI.")
	_check(not player.is_input_enabled(), "Station movement must pause while loadout is open.")
	_check(
		VIEWPORT_RECT.encloses(loadout_ui.get_panel_rect()),
		"Ship loadout panel leaves the 640x360 viewport: %s" % loadout_ui.get_panel_rect()
	)
	_check(loadout_ui.get_status_text() == "等待订单", "Pre-order loadout status is unclear.")
	_check(not loadout_ui.is_confirm_enabled(), "Departure is enabled without an accepted order.")
	_check(
		loadout_ui.get_feedback_text().contains("先在订单终端"),
		"Pre-order loadout does not direct the player to the order terminal."
	)
	_check(
		loadout_ui.get_stat_summary_text().count("100 / 100") == 4
		and loadout_ui.get_stat_summary_text().contains("1 / 1"),
		"Fixed ship hull, shield, fuel, Boost, and cargo stats are incomplete."
	)
	_check(
		loadout_ui.get_slot_status_text(ShipModuleDefinition.SlotType.POWER).contains("主线必需")
		and loadout_ui.get_slot_status_text(ShipModuleDefinition.SlotType.POWER).contains("已安装")
		and loadout_ui.get_slot_status_text(ShipModuleDefinition.SlotType.DEFENSE).contains("已安装"),
		"Standard issue required modules are not visibly installed."
	)
	_check(not loadout_ui.is_laser_mount_visible(), "Laser mount is visible before installation.")
	loadout_ui.close_loadout()
	await process_frame
	_check(player.is_input_enabled(), "Station movement did not resume after closing loadout.")

	_check(game_state.accept_order(order), "Red Sand order could not be accepted for loadout smoke.")
	_check(workbench.interact(player), "Accepted order could not reopen the workbench.")
	await process_frame
	_check(loadout_ui.is_confirm_enabled(), "Complete standard loadout cannot confirm departure.")
	_check(loadout_ui.get_status_text() == "可以出发", "Ready loadout status is unclear.")
	_check(
		loadout_ui.get_cargo_assignment_text().contains("深层冷却泵核心"),
		"Accepted cargo is missing from the ship loadout."
	)
	_check(
		loadout_ui.get_requirements_text().contains("必需 2/2")
		and loadout_ui.get_requirements_text().contains("可选 0/2")
		and loadout_ui.get_slot_status_text(
			ShipModuleDefinition.SlotType.UTILITY
		).contains("订单推荐")
		and loadout_ui.get_shield_backup_power_status_text().contains("订单推荐"),
		"Required modules and both optional Red Sand modules are not clearly separated."
	)

	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.DEFENSE),
		"Defense module could not be removed."
	)
	_check(not loadout_ui.is_confirm_enabled(), "Departure remained enabled without defense.")
	_check(
		loadout_ui.get_status_text() == "配置不完整"
		and loadout_ui.get_feedback_text().contains("大气防护模块"),
		"Missing required defense did not produce a clear localized reason."
	)
	_check(
		VIEWPORT_RECT.encloses(loadout_ui.get_panel_rect()),
		"Missing-module feedback expanded the loadout beyond 640x360."
	)
	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.DEFENSE),
		"Standard defense module could not be reinstalled without purchase."
	)
	_check(loadout_ui.is_confirm_enabled(), "Reinstalling defense did not restore readiness.")

	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.UTILITY),
		"Optional asteroid laser could not be installed."
	)
	var module_catalog: Array[ShipModuleDefinition] = ShipLoadoutRules.get_order_modules(order)
	_check(loadout_ui.is_laser_mount_visible(), "Installing the laser did not update the ship preview.")
	_check(
		game_state.ship_configuration[ShipLoadoutRules.SLOT_UTILITY]
		== ShipLoadoutRules.LASER_MODULE_ID,
		"Laser installation did not persist in GameState."
	)
	_check(
		game_state.has_ship_capability(
			ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY,
			module_catalog
		),
		"Installed laser did not expose its later flight capability."
	)
	_check(
		loadout_ui.toggle_module_by_id(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		),
		"Optional shield backup power could not be installed."
	)
	_check(
		loadout_ui.is_shield_backup_power_visual_visible()
		and loadout_ui.get_shield_backup_power_status_text().contains("已安装")
		and game_state.is_ship_module_equipped(
			ShipLoadoutRules.SHIELD_BACKUP_POWER_MODULE_ID
		)
		and game_state.has_ship_capability(
			ShipLoadoutRules.SHIELD_REGENERATION_CAPABILITY,
			module_catalog
		),
		"Shield backup installation did not persist or expose regeneration capability."
	)
	_check(
		loadout_ui.get_requirements_text().contains("可选 2/2"),
		"Installing both optional modules did not update the compact requirement summary."
	)
	_check(
		game_state.is_ship_module_equipped(ShipLoadoutRules.LASER_MODULE_ID),
		"Installing shield backup power replaced the independently installed laser."
	)
	_check(loadout_ui.confirm_departure(), "Valid loadout could not confirm departure.")
	_check(
		game_state.is_departure_confirmed_for_order(order)
		and loadout_ui.get_status_text() == "出发已确认"
		and loadout_ui.get_feedback_text().contains("驾驶舱入口"),
		"Departure confirmation was not persisted or clearly acknowledged."
	)
	_check(
		VIEWPORT_RECT.encloses(loadout_ui.get_panel_rect()),
		"Confirmed-departure feedback expanded the loadout beyond 640x360."
	)
	loadout_ui.close_loadout()
	await process_frame
	_check(player.is_input_enabled(), "Player input did not resume after confirmed loadout closed.")

	_check(workbench.interact(player), "Confirmed loadout could not be reviewed.")
	await process_frame
	_check(loadout_ui.is_laser_mount_visible(), "Reopened loadout lost the installed laser visual.")
	_check(
		loadout_ui.is_shield_backup_power_visual_visible(),
		"Reopened loadout lost the installed shield backup visual."
	)
	_check(
		loadout_ui.toggle_module_for_slot(ShipModuleDefinition.SlotType.UTILITY),
		"Installed laser could not be removed."
	)
	_check(
		not game_state.departure_confirmed
		and not game_state.has_ship_capability(
			ShipLoadoutRules.ASTEROID_BREAK_CAPABILITY,
			module_catalog
		)
		and game_state.has_ship_capability(
			ShipLoadoutRules.SHIELD_REGENERATION_CAPABILITY,
			module_catalog
		),
		"Removing the laser did not invalidate confirmation and later flight capability."
	)
	_check(loadout_ui.confirm_departure(), "Laser-free optional loadout could not reconfirm departure.")
	loadout_ui.close_loadout()

	station.queue_free()
	game_state.reset_runtime_state()
	await process_frame
	_finish_smoke(original_locale)


func _finish_smoke(original_locale: String) -> void:
	TranslationServer.set_locale(original_locale)
	if _failures.is_empty():
		print("[ship-loadout] PASS: fixed ship stats, slot persistence, requirements, laser capability, and departure confirmation.")
		quit(0)
		return
	for failure: String in _failures:
		printerr("[ship-loadout] %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
