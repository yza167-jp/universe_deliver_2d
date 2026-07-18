extends ProjectTestSuite

const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"
const COCKPIT_DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_cockpit_graybox.tres"
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(CATALOG_PATH)
	expect_true(
		catalog.errors.is_empty(),
		"Localization table must parse cleanly: %s" % "; ".join(catalog.errors),
		failures
	)
	expect_true(catalog.locales.has("zh_CN"), "Localization table must contain zh_CN.", failures)
	expect_true(catalog.locales.has("en"), "Localization table must contain an English column.", failures)
	expect_true(
		catalog.get_message(&"CHARACTER_LAO_PI_NAME", &"zh_CN") == "老皮",
		"Chinese must be the source text for Lao Pi.",
		failures
	)
	expect_true(
		not catalog.get_message(&"DIALOGUE_TEST_INTRO", &"en").is_empty(),
		"English placeholder dialogue must not be empty.",
		failures
	)

	var registry: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var registry_errors: PackedStringArray = LocalizationValidator.validate_registry(
		registry,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		registry_errors.is_empty(),
		"All registered data keys must be localized: %s" % "; ".join(registry_errors),
		failures
	)

	var ui_keys: Dictionary[String, StringName] = {
		"main menu eyebrow": &"UI_MAIN_MENU_EYEBROW",
		"main menu brief": &"UI_MAIN_MENU_BRIEF",
		"main menu controls": &"UI_MAIN_MENU_CONTROLS",
		"main menu new game": &"UI_MAIN_MENU_NEW_GAME",
		"main menu start unavailable": &"UI_MAIN_MENU_START_UNAVAILABLE",
		"dialogue quick show": &"UI_DIALOGUE_QUICK_SHOW",
		"dialogue skip read": &"UI_DIALOGUE_SKIP_READ",
		"dialogue history": &"UI_DIALOGUE_HISTORY",
		"dialogue continue": &"UI_DIALOGUE_CONTINUE",
		"dialogue history empty": &"UI_DIALOGUE_HISTORY_EMPTY",
		"dialogue history title": &"UI_DIALOGUE_HISTORY_TITLE",
		"dialogue history close": &"UI_DIALOGUE_HISTORY_CLOSE",
		"dialogue demo title": &"UI_DIALOGUE_DEMO_TITLE",
		"debug settings title": &"UI_DEBUG_SETTINGS_TITLE",
		"debug slow motion": &"UI_DEBUG_SLOW_MOTION",
		"debug route hints": &"UI_DEBUG_ROUTE_HINTS",
		"debug high contrast": &"UI_DEBUG_HIGH_CONTRAST",
		"debug flight assist": &"UI_DEBUG_FLIGHT_ASSIST",
		"debug setting on": &"UI_DEBUG_SETTING_ON",
		"debug setting off": &"UI_DEBUG_SETTING_OFF",
		"debug settings ready": &"UI_DEBUG_SETTINGS_READY",
		"debug settings saved": &"UI_DEBUG_SETTINGS_SAVED",
		"debug settings save failed": &"UI_DEBUG_SETTINGS_SAVE_FAILED",
		"debug settings unavailable": &"UI_DEBUG_SETTINGS_UNAVAILABLE",
		"flight lab title": &"UI_FLIGHT_LAB_TITLE",
		"flight lab hints": &"UI_FLIGHT_LAB_HINTS",
		"flight lab ready": &"UI_FLIGHT_LAB_STATUS_READY",
		"flight lab reset": &"UI_FLIGHT_LAB_STATUS_RESET",
		"flight debug speed": &"UI_FLIGHT_DEBUG_SPEED",
		"flight debug vertical speed": &"UI_FLIGHT_DEBUG_VERTICAL_SPEED",
		"flight debug pitch": &"UI_FLIGHT_DEBUG_PITCH",
		"flight debug zone": &"UI_FLIGHT_DEBUG_ZONE",
		"flight debug gravity": &"UI_FLIGHT_DEBUG_GRAVITY",
		"flight debug fuel": &"UI_FLIGHT_DEBUG_FUEL",
		"flight debug boost": &"UI_FLIGHT_DEBUG_BOOST",
		"flight debug assist": &"UI_FLIGHT_DEBUG_ASSIST",
		"flight debug collision": &"UI_FLIGHT_DEBUG_COLLISION",
		"flight lab deep space": &"UI_FLIGHT_LAB_ZONE_DEEP_SPACE",
		"flight lab collision clear": &"UI_FLIGHT_LAB_COLLISION_CLEAR",
		"station hub title": &"UI_STATION_HUB_TITLE",
		"station order terminal": &"UI_STATION_ORDER_TERMINAL",
		"station workbench": &"UI_STATION_WORKBENCH",
		"station cockpit entry": &"UI_STATION_COCKPIT_ENTRY",
		"station cockpit ready": &"UI_STATION_COCKPIT_ENTRY_READY",
		"station lao pi rest": &"UI_STATION_LAO_PI_REST",
		"station memorabilia wall": &"UI_STATION_MEMORABILIA_WALL",
		"station entrance": &"UI_STATION_ENTRANCE",
		"interaction prompt": &"UI_INTERACTION_PROMPT",
		"interaction feedback": &"UI_INTERACTION_FEEDBACK",
		"interaction order terminal": &"UI_INTERACTION_ORDER_TERMINAL",
		"interaction workbench": &"UI_INTERACTION_WORKBENCH",
		"interaction cockpit entry": &"UI_INTERACTION_COCKPIT_ENTRY",
		"interaction cockpit locked order": &"UI_INTERACTION_COCKPIT_ENTRY_LOCKED_ORDER",
		"interaction cockpit locked loadout": &"UI_INTERACTION_COCKPIT_ENTRY_LOCKED_LOADOUT",
		"interaction cockpit ready": &"UI_INTERACTION_COCKPIT_ENTRY_READY",
		"interaction lao pi rest": &"UI_INTERACTION_LAO_PI_REST",
		"interaction memorabilia wall": &"UI_INTERACTION_MEMORABILIA_WALL",
		"interaction lao pi": &"UI_INTERACTION_LAO_PI",
		"tutorial movement objective": &"UI_TUTORIAL_OBJECTIVE_MOVE",
		"tutorial lao pi objective": &"UI_TUTORIAL_OBJECTIVE_TALK_TO_LAO_PI",
		"tutorial terminal objective": &"UI_TUTORIAL_OBJECTIVE_ORDER_TERMINAL",
		"station accept order objective": &"UI_STATION_OBJECTIVE_ACCEPT_ORDER",
		"station configure ship objective": &"UI_STATION_OBJECTIVE_CONFIGURE_SHIP",
		"station enter cockpit objective": &"UI_STATION_OBJECTIVE_ENTER_COCKPIT",
		"station cockpit blocked order": &"UI_STATION_COCKPIT_BLOCKED_ORDER",
		"station cockpit blocked loadout": &"UI_STATION_COCKPIT_BLOCKED_LOADOUT",
		"departure gate title": &"UI_DEPARTURE_GATE_TITLE",
		"departure gate summary": &"UI_DEPARTURE_GATE_SUMMARY",
		"departure gate body": &"UI_DEPARTURE_GATE_BODY",
		"departure gate close": &"UI_DEPARTURE_GATE_CLOSE",
		"departure gate enter cockpit": &"UI_DEPARTURE_GATE_ENTER_COCKPIT",
		"cockpit title": &"UI_COCKPIT_TITLE",
		"cockpit instructions": &"UI_COCKPIT_INSTRUCTIONS",
		"cockpit ready status": &"UI_COCKPIT_STATUS_READY",
		"cockpit active status": &"UI_COCKPIT_STATUS_ACTIVE_FORMAT",
		"cockpit ready feedback": &"UI_COCKPIT_FEEDBACK_READY",
		"cockpit navigation hotspot": &"UI_COCKPIT_HOTSPOT_NAVIGATION",
		"cockpit window hotspot": &"UI_COCKPIT_HOTSPOT_WINDOW",
		"cockpit lao pi hotspot": &"UI_COCKPIT_HOTSPOT_LAO_PI",
		"cockpit company terminal hotspot": &"UI_COCKPIT_HOTSPOT_COMPANY_TERMINAL",
		"cockpit radio hotspot": &"UI_COCKPIT_HOTSPOT_RADIO",
		"cockpit cargo hotspot": &"UI_COCKPIT_HOTSPOT_CARGO",
		"cockpit navigation description": &"UI_COCKPIT_DESC_NAVIGATION",
		"cockpit window description": &"UI_COCKPIT_DESC_WINDOW",
		"cockpit lao pi description": &"UI_COCKPIT_DESC_LAO_PI",
		"cockpit company description": &"UI_COCKPIT_DESC_COMPANY_TERMINAL",
		"cockpit radio description": &"UI_COCKPIT_DESC_RADIO",
		"cockpit cargo description": &"UI_COCKPIT_DESC_CARGO",
		"cockpit select prompt": &"UI_COCKPIT_SELECT_PROMPT",
		"cockpit focus prompt": &"UI_COCKPIT_FOCUS_PROMPT_FORMAT",
		"cockpit navigation action": &"UI_COCKPIT_ACTION_NAVIGATION",
		"cockpit window action": &"UI_COCKPIT_ACTION_WINDOW",
		"cockpit lao pi action": &"UI_COCKPIT_ACTION_LAO_PI",
		"cockpit company action": &"UI_COCKPIT_ACTION_COMPANY_TERMINAL",
		"cockpit radio action": &"UI_COCKPIT_ACTION_RADIO",
		"cockpit cargo action": &"UI_COCKPIT_ACTION_CARGO",
		"cockpit radio on": &"UI_COCKPIT_RADIO_ON",
		"cockpit radio off": &"UI_COCKPIT_RADIO_OFF",
		"cockpit radio status": &"UI_COCKPIT_RADIO_STATUS_FORMAT",
		"cockpit radio button": &"UI_COCKPIT_RADIO_BUTTON_FORMAT",
		"cockpit panel close": &"UI_COCKPIT_PANEL_CLOSE",
		"cockpit unavailable value": &"UI_COCKPIT_VALUE_UNAVAILABLE",
		"cockpit navigation panel title": &"UI_COCKPIT_NAV_PANEL_TITLE",
		"cockpit navigation no order": &"UI_COCKPIT_NAV_NO_ORDER",
		"cockpit navigation order": &"UI_COCKPIT_NAV_ORDER_FORMAT",
		"cockpit destination unset": &"UI_COCKPIT_NAV_DESTINATION_UNSET",
		"cockpit destination": &"UI_COCKPIT_NAV_DESTINATION_FORMAT",
		"cockpit route pending": &"UI_COCKPIT_NAV_ROUTE_PENDING",
		"cockpit route no order": &"UI_COCKPIT_NAV_ROUTE_NO_ORDER",
		"cockpit route ready": &"UI_COCKPIT_NAV_ROUTE_READY",
		"cockpit route active": &"UI_COCKPIT_NAV_ROUTE_ACTIVE",
		"cockpit route completed": &"UI_COCKPIT_NAV_ROUTE_COMPLETED",
		"cockpit route unavailable": &"UI_COCKPIT_NAV_ROUTE_UNAVAILABLE",
		"cockpit confirm destination": &"UI_COCKPIT_NAV_CONFIRM_AND_DEPART",
		"cockpit company panel title": &"UI_COCKPIT_COMPANY_PANEL_TITLE",
		"cockpit company link": &"UI_COCKPIT_COMPANY_LINK_STATUS",
		"cockpit company no order": &"UI_COCKPIT_COMPANY_NO_ACTIVE_ORDER",
		"cockpit company active order": &"UI_COCKPIT_COMPANY_ACTIVE_ORDER_FORMAT",
		"cockpit company travel notice": &"UI_COCKPIT_COMPANY_TRAVEL_NOTICE",
		"cockpit company departure": &"UI_COCKPIT_COMPANY_TRAVEL_DEPARTURE",
		"cockpit company cruise": &"UI_COCKPIT_COMPANY_TRAVEL_CRUISE",
		"cockpit company approach": &"UI_COCKPIT_COMPANY_TRAVEL_APPROACH",
		"cockpit company completed": &"UI_COCKPIT_COMPANY_TRAVEL_COMPLETED",
		"cockpit cargo panel title": &"UI_COCKPIT_CARGO_PANEL_TITLE",
		"cockpit cargo empty": &"UI_COCKPIT_CARGO_EMPTY",
		"cockpit cargo loaded": &"UI_COCKPIT_CARGO_LOADED_FORMAT",
		"cockpit cargo integrity": &"UI_COCKPIT_CARGO_INTEGRITY_PLACEHOLDER",
		"cockpit cargo lock": &"UI_COCKPIT_CARGO_LOCK_STATUS",
		"cockpit window observation": &"UI_COCKPIT_WINDOW_OBSERVATION",
		"cockpit window departure": &"UI_COCKPIT_WINDOW_DEPARTURE",
		"cockpit window cruise": &"UI_COCKPIT_WINDOW_CRUISE",
		"cockpit window approach": &"UI_COCKPIT_WINDOW_APPROACH",
		"cockpit travel idle": &"UI_COCKPIT_TRAVEL_PHASE_IDLE",
		"cockpit travel departure": &"UI_COCKPIT_TRAVEL_PHASE_DEPARTURE",
		"cockpit travel cruise": &"UI_COCKPIT_TRAVEL_PHASE_CRUISE",
		"cockpit travel approach": &"UI_COCKPIT_TRAVEL_PHASE_APPROACH",
		"cockpit travel completed": &"UI_COCKPIT_TRAVEL_PHASE_COMPLETED",
		"cockpit travel idle detail": &"UI_COCKPIT_TRAVEL_DETAIL_IDLE",
		"cockpit travel departure detail": &"UI_COCKPIT_TRAVEL_DETAIL_DEPARTURE",
		"cockpit travel cruise detail": &"UI_COCKPIT_TRAVEL_DETAIL_CRUISE",
		"cockpit travel approach detail": &"UI_COCKPIT_TRAVEL_DETAIL_APPROACH",
		"cockpit travel completed detail": &"UI_COCKPIT_TRAVEL_DETAIL_COMPLETED",
		"cockpit travel skip": &"UI_COCKPIT_TRAVEL_SKIP",
		"cockpit travel skip locked": &"UI_COCKPIT_TRAVEL_SKIP_LOCKED",
		"cockpit travel ready for flight": &"UI_COCKPIT_TRAVEL_READY_FOR_FLIGHT",
		"cockpit travel no order error": &"UI_COCKPIT_TRAVEL_ERROR_NO_ORDER",
		"cockpit travel preflight error": &"UI_COCKPIT_TRAVEL_ERROR_PREFLIGHT",
		"cockpit travel destination error": &"UI_COCKPIT_TRAVEL_ERROR_DESTINATION",
		"cockpit travel active error": &"UI_COCKPIT_TRAVEL_ERROR_ACTIVE",
		"cockpit travel completed error": &"UI_COCKPIT_TRAVEL_ERROR_COMPLETED",
		"order terminal title": &"UI_ORDER_TERMINAL_TITLE",
		"order not accepted status": &"UI_ORDER_STATUS_NOT_ACCEPTED",
		"order accepted status": &"UI_ORDER_STATUS_ACCEPTED",
		"order completed status": &"UI_ORDER_STATUS_COMPLETED",
		"order unavailable status": &"UI_ORDER_STATUS_UNAVAILABLE",
		"order parties format": &"UI_ORDER_PARTIES_FORMAT",
		"order route format": &"UI_ORDER_ROUTE_FORMAT",
		"order reward format": &"UI_ORDER_REWARD_FORMAT",
		"order environment heading": &"UI_ORDER_ENVIRONMENT_HEADING",
		"order cargo heading": &"UI_ORDER_CARGO_HEADING",
		"order required modules heading": &"UI_ORDER_REQUIRED_MODULES_HEADING",
		"order customer history heading": &"UI_ORDER_CUSTOMER_HISTORY_HEADING",
		"order future heading": &"UI_ORDER_FUTURE_HEADING",
		"order future placeholder": &"UI_ORDER_FUTURE_PLACEHOLDER",
		"order ready feedback": &"UI_ORDER_FEEDBACK_READY",
		"order accepted feedback": &"UI_ORDER_FEEDBACK_ACCEPTED",
		"order completed feedback": &"UI_ORDER_FEEDBACK_COMPLETED",
		"order missing data error": &"UI_ORDER_ERROR_MISSING_DATA",
		"order story requirement error": &"UI_ORDER_ERROR_STORY_REQUIREMENT",
		"order active error": &"UI_ORDER_ERROR_ACTIVE_ORDER",
		"order state unavailable error": &"UI_ORDER_ERROR_STATE_UNAVAILABLE",
		"order unavailable value": &"UI_ORDER_VALUE_UNAVAILABLE",
		"order accept": &"UI_ORDER_ACCEPT",
		"order accepted button": &"UI_ORDER_ACCEPTED_BUTTON",
		"order completed button": &"UI_ORDER_COMPLETED_BUTTON",
		"order close": &"UI_ORDER_CLOSE",
		"order landing": &"UI_ORDER_DELIVERY_LANDING",
		"order airdrop": &"UI_ORDER_DELIVERY_AIRDROP",
		"order checkpoint": &"UI_ORDER_DELIVERY_CHECKPOINT",
		"order docking": &"UI_ORDER_DELIVERY_DOCKING",
		"order no required modules": &"UI_ORDER_NO_REQUIRED_MODULES",
		"order list entry": &"UI_ORDER_LIST_ENTRY_FORMAT",
		"ship name": &"SHIP_PLAYER_COURIER_NAME",
		"loadout title": &"UI_LOADOUT_TITLE",
		"loadout ship subtitle": &"UI_LOADOUT_FIXED_SHIP_SUBTITLE",
		"loadout waiting status": &"UI_LOADOUT_STATUS_WAITING_ORDER",
		"loadout incomplete status": &"UI_LOADOUT_STATUS_INCOMPLETE",
		"loadout ready status": &"UI_LOADOUT_STATUS_READY",
		"loadout confirmed status": &"UI_LOADOUT_STATUS_CONFIRMED",
		"loadout unavailable status": &"UI_LOADOUT_STATUS_UNAVAILABLE",
		"loadout cargo assigned": &"UI_LOADOUT_CARGO_ASSIGNED_FORMAT",
		"loadout cargo unassigned": &"UI_LOADOUT_CARGO_UNASSIGNED",
		"loadout hull": &"UI_LOADOUT_STAT_HULL",
		"loadout shield": &"UI_LOADOUT_STAT_SHIELD",
		"loadout fuel": &"UI_LOADOUT_STAT_FUEL",
		"loadout boost": &"UI_LOADOUT_STAT_BOOST",
		"loadout cargo": &"UI_LOADOUT_STAT_CARGO",
		"loadout resource value": &"UI_LOADOUT_RESOURCE_VALUE_FORMAT",
		"loadout cargo value": &"UI_LOADOUT_CARGO_VALUE_FORMAT",
		"loadout slots heading": &"UI_LOADOUT_SLOTS_HEADING",
		"loadout power slot": &"UI_LOADOUT_SLOT_POWER",
		"loadout defense slot": &"UI_LOADOUT_SLOT_DEFENSE",
		"loadout utility slot": &"UI_LOADOUT_SLOT_UTILITY",
		"loadout required role": &"UI_LOADOUT_ROLE_REQUIRED",
		"loadout recommended role": &"UI_LOADOUT_ROLE_RECOMMENDED",
		"loadout installed state": &"UI_LOADOUT_STATE_INSTALLED",
		"loadout empty state": &"UI_LOADOUT_STATE_EMPTY",
		"loadout missing state": &"UI_LOADOUT_STATE_MISSING",
		"loadout optional state": &"UI_LOADOUT_STATE_OPTIONAL",
		"loadout slot status": &"UI_LOADOUT_SLOT_STATUS_FORMAT",
		"loadout install": &"UI_LOADOUT_INSTALL",
		"loadout uninstall": &"UI_LOADOUT_UNINSTALL",
		"loadout requirements heading": &"UI_LOADOUT_REQUIREMENTS_HEADING",
		"loadout required format": &"UI_LOADOUT_REQUIREMENT_REQUIRED_FORMAT",
		"loadout recommended format": &"UI_LOADOUT_REQUIREMENT_RECOMMENDED_FORMAT",
		"loadout standard issue note": &"UI_LOADOUT_STANDARD_ISSUE_NOTE",
		"loadout waiting feedback": &"UI_LOADOUT_FEEDBACK_WAITING_ORDER",
		"loadout missing feedback": &"UI_LOADOUT_FEEDBACK_MISSING_REQUIRED_FORMAT",
		"loadout ready feedback": &"UI_LOADOUT_FEEDBACK_READY",
		"loadout confirmed feedback": &"UI_LOADOUT_FEEDBACK_CONFIRMED",
		"loadout state unavailable": &"UI_LOADOUT_FEEDBACK_STATE_UNAVAILABLE",
		"loadout data unavailable": &"UI_LOADOUT_FEEDBACK_DATA_UNAVAILABLE",
		"loadout confirm": &"UI_LOADOUT_CONFIRM_DEPARTURE",
		"loadout confirmed button": &"UI_LOADOUT_CONFIRMED_BUTTON",
		"loadout close": &"UI_LOADOUT_CLOSE",
		"loadout unavailable value": &"UI_LOADOUT_VALUE_UNAVAILABLE",
		"loadout list separator": &"UI_LOADOUT_LIST_SEPARATOR",
	}
	var ui_errors: PackedStringArray = LocalizationValidator.validate_keys(
		ui_keys,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		ui_errors.is_empty(),
		"Dialogue UI keys must be localized: %s" % "; ".join(ui_errors),
		failures
	)

	var sequence: DialogueSequence = load(DIALOGUE_PATH) as DialogueSequence
	var dialogue_errors: PackedStringArray = DialogueValidator.validate(
		sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		dialogue_errors.is_empty(),
		"Lao Pi test dialogue must validate: %s" % "; ".join(dialogue_errors),
		failures
	)
	var cockpit_sequence: DialogueSequence = load(COCKPIT_DIALOGUE_PATH) as DialogueSequence
	var cockpit_dialogue_errors: PackedStringArray = DialogueValidator.validate(
		cockpit_sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		cockpit_dialogue_errors.is_empty(),
		"Lao Pi cockpit dialogue must validate: %s" % "; ".join(cockpit_dialogue_errors),
		failures
	)

	var missing_key_sequence: DialogueSequence = DialogueSequence.new()
	missing_key_sequence.id = &"dialogue_missing_key_fixture"
	missing_key_sequence.start_line_id = &"missing_key_line"
	var missing_key_line: DialogueLine = DialogueLine.new()
	missing_key_line.id = &"missing_key_line"
	missing_key_line.speaker = registry.find_character(&"character_lao_pi")
	missing_key_line.text_key = &"DIALOGUE_KEY_THAT_DOES_NOT_EXIST"
	missing_key_sequence.lines.append(missing_key_line)
	var missing_key_errors: PackedStringArray = DialogueValidator.validate(
		missing_key_sequence,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		_contains_error(missing_key_errors, "missing localization key"),
		"Dialogue validation must report a missing localization key.",
		failures
	)
	return failures


func _contains_error(errors: PackedStringArray, expected_fragment: String) -> bool:
	for error: String in errors:
		if error.contains(expected_fragment):
			return true
	return false
