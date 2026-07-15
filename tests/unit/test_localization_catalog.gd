extends ProjectTestSuite

const CATALOG_PATH: String = "res://data/localization/game_text.csv"
const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"
const DIALOGUE_PATH: String = "res://data/dialogue/lao_pi_system_test.tres"
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
		"station hub title": &"UI_STATION_HUB_TITLE",
		"station order terminal": &"UI_STATION_ORDER_TERMINAL",
		"station workbench": &"UI_STATION_WORKBENCH",
		"station cockpit entry": &"UI_STATION_COCKPIT_ENTRY",
		"station lao pi rest": &"UI_STATION_LAO_PI_REST",
		"station memorabilia wall": &"UI_STATION_MEMORABILIA_WALL",
		"station entrance": &"UI_STATION_ENTRANCE",
		"interaction prompt": &"UI_INTERACTION_PROMPT",
		"interaction feedback": &"UI_INTERACTION_FEEDBACK",
		"interaction order terminal": &"UI_INTERACTION_ORDER_TERMINAL",
		"interaction workbench": &"UI_INTERACTION_WORKBENCH",
		"interaction cockpit entry": &"UI_INTERACTION_COCKPIT_ENTRY",
		"interaction lao pi rest": &"UI_INTERACTION_LAO_PI_REST",
		"interaction memorabilia wall": &"UI_INTERACTION_MEMORABILIA_WALL",
		"interaction lao pi": &"UI_INTERACTION_LAO_PI",
		"tutorial movement objective": &"UI_TUTORIAL_OBJECTIVE_MOVE",
		"tutorial lao pi objective": &"UI_TUTORIAL_OBJECTIVE_TALK_TO_LAO_PI",
		"tutorial terminal objective": &"UI_TUTORIAL_OBJECTIVE_ORDER_TERMINAL",
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
