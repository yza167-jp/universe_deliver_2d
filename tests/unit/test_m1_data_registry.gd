extends ProjectTestSuite

const M0_REGISTRY_PATH: String = "res://data/m0_data_registry.tres"
const M1_REGISTRY_PATH: String = "res://data/m1_data_registry.tres"
const LOCALIZATION_PATH: String = "res://data/localization/game_text.csv"
const LOCALIZATION_MISSING_EN_PATH: String = (
	"res://tests/fixtures/localization_missing_en.txt"
)
const LOCALIZATION_MISSING_ZH_PATH: String = (
	"res://tests/fixtures/localization_missing_zh.txt"
)
const REQUIRED_LOCALES: PackedStringArray = ["zh_CN", "en"]

const NEW_PLANET_IDS: Array[StringName] = [
	&"planet_white_noise",
	&"planet_canopy_world",
	&"planet_tidal_archipelago",
]
const REQUIRED_ORDER_IDS: Array[StringName] = [
	&"order_red_sand_m0",
	&"order_m1_red_sand_shielding_retrofit",
	&"order_m1_white_noise_archive_core",
	&"order_m1_canopy_ecology_cargo",
	&"order_m1_tidal_weather_core",
	&"side_white_noise_returned_memory",
	&"side_canopy_spore_drop",
	&"side_tidal_beacon_before_eye",
]
const REQUIRED_CARGO_IDS: Array[StringName] = [
	&"cargo_red_sand_m0",
	&"cargo_relay_pattern_shielding_materials",
	&"cargo_white_noise_archive_core",
	&"cargo_canopy_ecology_sample",
	&"cargo_tidal_weather_control_core",
	&"cargo_returned_memory_case",
	&"cargo_canopy_spore_stabilizer",
	&"cargo_tidal_beacon_cells",
]
const REQUIRED_MODULE_IDS: Array[StringName] = [
	&"module_standard_drive",
	&"module_atmospheric_shield",
	&"module_asteroid_laser",
	&"module_shield_backup_power",
	&"module_high_voltage_shielding",
	&"module_biosignal_isolation",
	&"module_crosswind_stabilizer",
]
const REQUIRED_CHARACTER_IDS: Array[StringName] = [
	&"character_company_dispatch",
	&"character_red_sand_recipient",
	&"character_lao_pi",
	&"character_white_noise_archivist",
	&"character_white_noise_memory_owner",
	&"character_canopy_route_keeper",
	&"character_canopy_canopy_clinic_worker",
	&"character_tidal_weather_keeper",
	&"character_tidal_city_representative",
	&"character_company_archive_service",
	&"character_company_weather_custodian",
]


func run() -> Array[String]:
	var failures: Array[String] = []
	var registry: GameDataRegistry = load(M1_REGISTRY_PATH) as GameDataRegistry
	expect_true(registry != null, "M1 data registry must load.", failures)
	if registry == null:
		return failures

	_test_valid_registry_and_counts(registry, failures)
	_test_m0_registry_is_frozen(registry, failures)
	_test_planet_registration_contract(registry, failures)
	_test_packet_resources(registry, failures)
	_test_order_contracts(registry, failures)
	_test_typed_collections(registry, failures)
	_test_localization(registry, failures)
	_test_negative_validation(registry, failures)
	return failures


func _test_valid_registry_and_counts(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		errors.is_empty(),
		"M1 registry must validate without errors: %s" % "; ".join(errors),
		failures
	)
	expect_true(
		registry.registry_id == &"m1_four_planet_demo"
		and registry.planets.size() == 4
		and registry.orders.size() == 8
		and registry.cargo_items.size() == 8
		and registry.modules.size() == 7
		and registry.characters.size() == 11,
		"M1 registry must expose exact required Planet/Order/Cargo/Module/Character counts.",
		failures
	)
	expect_true(
		registry.codex_entries.size() == 19 and registry.souvenirs.size() == 4,
		"M1 registry must use typed codex and souvenir catalogs.",
		failures
	)
	for order_id: StringName in REQUIRED_ORDER_IDS:
		expect_true(
			registry.find_order(order_id) != null,
			"M1 registry must include order '%s'." % order_id,
			failures
		)
	for cargo_id: StringName in REQUIRED_CARGO_IDS:
		expect_true(
			registry.find_cargo(cargo_id) != null,
			"M1 registry must include cargo '%s'." % cargo_id,
			failures
		)
	for module_id: StringName in REQUIRED_MODULE_IDS:
		expect_true(
			registry.find_module(module_id) != null,
			"M1 registry must include module '%s'." % module_id,
			failures
		)
	for character_id: StringName in REQUIRED_CHARACTER_IDS:
		expect_true(
			registry.find_character(character_id) != null,
			"M1 registry must include character '%s'." % character_id,
			failures
		)


func _test_m0_registry_is_frozen(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var m0_registry: GameDataRegistry = load(M0_REGISTRY_PATH) as GameDataRegistry
	expect_true(m0_registry != null, "Frozen M0 registry must still load.", failures)
	if m0_registry == null:
		return
	expect_true(
		m0_registry.planets.size() == 1
		and m0_registry.orders.size() == 1
		and m0_registry.cargo_items.size() == 1
		and m0_registry.modules.size() == 4
		and m0_registry.characters.size() == 3
		and m0_registry.codex_entries.is_empty()
		and m0_registry.souvenirs.is_empty()
		and m0_registry.order_aliases.is_empty(),
		"M0 registry shape must remain frozen while M1 grows independently.",
		failures
	)
	var actual_order: OrderDefinition = registry.find_order(&"order_red_sand_m0")
	var alias_order: OrderDefinition = registry.find_order(&"order_red_sand_cooling_core")
	expect_true(
		actual_order != null
		and actual_order == alias_order
		and actual_order.id == &"order_red_sand_m0",
		"M0 canonical history alias must resolve to the one actual accept-able order.",
		failures
	)
	expect_true(
		actual_order != null
		and actual_order.content_readiness
		== OrderDefinition.ContentReadiness.PLAYABLE,
		"The one actual M0 order must remain playable in the M1 registry.",
		failures
	)
	var actual_count: int = 0
	for order: OrderDefinition in registry.orders:
		if order != null and order.id == &"order_red_sand_m0":
			actual_count += 1
	expect_true(actual_count == 1, "M1 registry must include the actual M0 order once.", failures)
	expect_true(
		registry.find_order(&"side_red_sand_unlisted_filters") == null
		and registry.find_cargo(&"cargo_red_sand_water_filters") == null,
		"Stretch Red Sand side content must stay outside the required M1 registry.",
		failures
	)


func _test_planet_registration_contract(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var expected_gravity: Dictionary[StringName, Vector2] = {
		&"planet_white_noise": Vector2(1.2, 1.35),
		&"planet_canopy_world": Vector2(0.75, 0.9),
		&"planet_tidal_archipelago": Vector2(0.9, 1.05),
	}
	var profile_ids: Dictionary[StringName, bool] = {}
	for planet_id: StringName in NEW_PLANET_IDS:
		var planet: PlanetDefinition = registry.find_planet(planet_id)
		expect_true(planet != null, "M1 planet '%s' must be registered." % planet_id, failures)
		if planet == null:
			continue
		var gravity_range: Vector2 = expected_gravity[planet_id]
		expect_true(
			planet.gravity_scale >= gravity_range.x
			and planet.gravity_scale <= gravity_range.y,
			"M1 planet '%s' gravity must stay within its Packet range." % planet_id,
			failures
		)
		expect_true(
			planet.content_readiness == PlanetDefinition.ContentReadiness.REGISTERED_ONLY
			and planet.flight_scene_path.is_empty()
			and not planet.is_playable(),
			"M1 planet '%s' must be registered without borrowing a playable route."
			% planet_id,
			failures
		)
		expect_true(
			planet.flight_environment_profile != null
			and String(planet.flight_environment_profile.id).ends_with("_placeholder"),
			"M1 planet '%s' must own an explicit placeholder environment profile."
			% planet_id,
			failures
		)
		if planet.flight_environment_profile != null:
			profile_ids[planet.flight_environment_profile.id] = true
	expect_true(
		profile_ids.size() == NEW_PLANET_IDS.size(),
		"Every new M1 planet must use a distinct environment profile.",
		failures
	)


func _test_packet_resources(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var expected_capabilities: Dictionary[StringName, StringName] = {
		&"module_high_voltage_shielding": &"capability_high_voltage_shielding",
		&"module_biosignal_isolation": &"capability_biosignal_isolation",
		&"module_crosswind_stabilizer": &"capability_crosswind_stabilization",
	}
	for module_id: StringName in expected_capabilities:
		var module: ShipModuleDefinition = registry.find_module(module_id)
		expect_true(
			module != null
			and module.capability_tags.has(expected_capabilities[module_id])
			and module.stat_modifiers.is_empty()
			and module.cost == 0,
			"M1 module '%s' must be a no-effect Packet placeholder with its capability tag."
			% module_id,
			failures
		)
	for cargo_id: StringName in REQUIRED_CARGO_IDS:
		var cargo: CargoDefinition = registry.find_cargo(cargo_id)
		expect_true(
			cargo != null
			and cargo.collision_tolerance > 0.0
			and cargo.collision_tolerance <= 1.0
			and not cargo.attraction_risk_tags.is_empty(),
			"Cargo '%s' must define conservative handling and risk metadata." % cargo_id,
			failures
		)
	for planet_id: StringName in NEW_PLANET_IDS:
		var planet: PlanetDefinition = registry.find_planet(planet_id)
		expect_true(
			planet != null and String(planet.display_name_key).ends_with("_PROVISIONAL"),
			"New planet '%s' must use a PROVISIONAL display localization key." % planet_id,
			failures
		)
	for order: OrderDefinition in registry.orders:
		if order != null and order.id != &"order_red_sand_m0":
			expect_true(
				String(order.display_name_key).ends_with("_PROVISIONAL"),
				"M1 order '%s' must use a PROVISIONAL display localization key." % order.id,
				failures
			)
	for cargo: CargoDefinition in registry.cargo_items:
		if cargo != null and cargo.id != &"cargo_red_sand_m0":
			expect_true(
				String(cargo.display_name_key).ends_with("_PROVISIONAL"),
				"M1 cargo '%s' must use a PROVISIONAL display localization key." % cargo.id,
				failures
			)
	for character: CharacterDefinition in registry.characters:
		if (
			character != null
			and not character.id in [
				&"character_company_dispatch",
				&"character_red_sand_recipient",
				&"character_lao_pi",
			]
		):
			expect_true(
				String(character.display_name_key).ends_with("_PROVISIONAL"),
				"M1 character '%s' must use a PROVISIONAL display localization key."
				% character.id,
				failures
			)


func _test_order_contracts(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var revisit: OrderDefinition = registry.find_order(
		&"order_m1_red_sand_shielding_retrofit"
	)
	expect_true(
		revisit != null
		and revisit.order_type == OrderDefinition.OrderType.REVISIT
		and revisit.delivery_type == OrderDefinition.DeliveryType.LANDING
		and revisit.repeat_policy == OrderDefinition.RepeatPolicy.UNIQUE
		and revisit.completion_flags.has(
			&"story_m1_red_sand_shielding_retrofit_completed"
		)
		and not revisit.permission_rewards.has(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		),
		"Red Sand revisit must unlock its later module path by completion flag, not direct reward.",
		failures
	)
	var white: OrderDefinition = registry.find_order(
		&"order_m1_white_noise_archive_core"
	)
	expect_true(
		white != null
		and _has_module_id(white.required_modules, &"module_high_voltage_shielding")
		and white.permission_rewards.has(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		)
		and white.delivery_type == OrderDefinition.DeliveryType.LANDING,
		"White Noise main order must require high-voltage shielding and award archive access.",
		failures
	)
	var canopy: OrderDefinition = registry.find_order(&"order_m1_canopy_ecology_cargo")
	expect_true(
		canopy != null
		and not _has_module_id(canopy.required_modules, &"module_biosignal_isolation")
		and _has_module_id(canopy.recommended_modules, &"module_biosignal_isolation"),
		"Canopy main order must recommend, not require, biosignal isolation.",
		failures
	)
	var tidal: OrderDefinition = registry.find_order(&"order_m1_tidal_weather_core")
	expect_true(
		tidal != null
		and not _has_module_id(tidal.required_modules, &"module_crosswind_stabilizer")
		and _has_module_id(tidal.recommended_modules, &"module_crosswind_stabilizer")
		and tidal.delivery_type == OrderDefinition.DeliveryType.LANDING,
		"Tidal main order must reuse LANDING and only recommend the crosswind stabilizer.",
		failures
	)
	var white_side: OrderDefinition = registry.find_order(
		&"side_white_noise_returned_memory"
	)
	var canopy_side: OrderDefinition = registry.find_order(&"side_canopy_spore_drop")
	var tidal_side: OrderDefinition = registry.find_order(
		&"side_tidal_beacon_before_eye"
	)
	expect_true(
		white_side != null
		and not white_side.is_express
		and white_side.delivery_type == OrderDefinition.DeliveryType.LANDING
		and white_side.repeat_policy != OrderDefinition.RepeatPolicy.ARCHIVED_ONLY,
		"White Noise required side order must be optional, non-express landing content.",
		failures
	)
	expect_true(
		canopy_side != null
		and canopy_side.delivery_type == OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
		and not canopy_side.is_express,
		"Canopy required side order must use the low-altitude drop contract.",
		failures
	)
	expect_true(
		tidal_side != null
		and tidal_side.is_express
		and is_equal_approx(tidal_side.target_seconds, 120.0)
		and is_equal_approx(tidal_side.grace_seconds, 60.0)
		and is_equal_approx(tidal_side.minimum_reward_ratio, 0.5)
		and tidal_side.relation_bonus_on_time == 1,
		"Tidal side order must define the conservative express curve.",
		failures
	)
	for order: OrderDefinition in registry.orders:
		if order == null or order.id == &"order_red_sand_m0":
			continue
		expect_true(
			order.content_readiness
			== OrderDefinition.ContentReadiness.REGISTERED_ONLY
			and
			not order.required_chapter.is_empty()
			and not order.unlock_conditions.is_empty()
			and order.sender != null
			and order.recipient != null
			and order.destination_planet != null
			and order.cargo != null
			and order.customer_history_keys.size() == 3
			and not order.story_requirements.is_empty()
			and not order.completion_flags.is_empty(),
			"M1 order '%s' must consume the complete T-103 Packet field contract." % order.id,
			failures
		)


func _test_typed_collections(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	for preserved_codex_id: StringName in [
		&"codex_planet_red_sand",
		&"codex_character_iya",
		&"codex_souvenir_old_relay_plaque",
	]:
		expect_true(
			registry.has_codex_reward_id(preserved_codex_id),
			"M1 typed codex must preserve '%s'." % preserved_codex_id,
			failures
		)
	expect_true(
		registry.has_souvenir_reward_id(&"souvenir_old_relay_plaque"),
		"M1 typed souvenirs must preserve the old relay plaque.",
		failures
	)
	for planet_id: StringName in NEW_PLANET_IDS:
		var codex_count: int = 0
		for entry: CodexEntryDefinition in registry.codex_entries:
			if entry != null and entry.related_planet_id == planet_id:
				codex_count += 1
		var souvenir_count: int = 0
		for souvenir: SouvenirDefinition in registry.souvenirs:
			if souvenir != null and souvenir.related_planet_id == planet_id:
				souvenir_count += 1
		expect_true(
			codex_count >= 3 and souvenir_count >= 1,
			"Planet '%s' must register at least three codex entries and one souvenir."
			% planet_id,
			failures
		)


func _test_localization(
	registry: GameDataRegistry,
	failures: Array[String]
) -> void:
	var catalog: LocalizationCatalog = LocalizationCatalog.load_csv(LOCALIZATION_PATH)
	var errors: PackedStringArray = LocalizationValidator.validate_registry(
		registry,
		catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		errors.is_empty(),
		"M1 registry localization must include nonempty zh_CN and en values: %s"
		% "; ".join(errors),
		failures
	)
	var missing_en_catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_MISSING_EN_PATH
	)
	var missing_en_keys: Dictionary[String, StringName] = {
		"fixture missing en": &"TEST_LOCALIZATION_ONLY_ZH",
	}
	var missing_en_errors: PackedStringArray = LocalizationValidator.validate_keys(
		missing_en_keys,
		missing_en_catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		_contains_error(missing_en_errors, "missing locale 'en'"),
		"Localization validation must reject a missing English value.",
		failures
	)
	var missing_zh_catalog: LocalizationCatalog = LocalizationCatalog.load_csv(
		LOCALIZATION_MISSING_ZH_PATH
	)
	var missing_zh_keys: Dictionary[String, StringName] = {
		"fixture missing zh_CN": &"TEST_LOCALIZATION_ONLY_EN",
	}
	var missing_zh_errors: PackedStringArray = LocalizationValidator.validate_keys(
		missing_zh_keys,
		missing_zh_catalog,
		REQUIRED_LOCALES
	)
	expect_true(
		_contains_error(missing_zh_errors, "missing locale 'zh_CN'"),
		"Localization validation must reject a missing Chinese value.",
		failures
	)


func _test_negative_validation(
	source: GameDataRegistry,
	failures: Array[String]
) -> void:
	var cross_type_duplicate: CodexEntryDefinition = CodexEntryDefinition.new()
	cross_type_duplicate.id = source.characters[0].id
	cross_type_duplicate.title_key = &"TEST_CROSS_TYPE_DUPLICATE_TITLE"
	cross_type_duplicate.description_key = &"TEST_CROSS_TYPE_DUPLICATE_DESCRIPTION"
	cross_type_duplicate.related_planet_id = &"planet_red_sand"
	source.codex_entries.append(cross_type_duplicate)
	var duplicate_errors: PackedStringArray = GameDataValidator.validate(source)
	source.codex_entries.resize(source.codex_entries.size() - 1)
	expect_true(
		_contains_error(duplicate_errors, "Duplicate ID"),
		"M1 validation must reject duplicate IDs across definition types.",
		failures
	)

	var reward_order: OrderDefinition = source.orders[1]
	reward_order.codex_rewards.append(&"codex_missing_packet_reward")
	reward_order.souvenir_rewards.append(
		&"souvenir_missing_packet_reward"
	)
	var reward_errors: PackedStringArray = GameDataValidator.validate(source)
	reward_order.codex_rewards.resize(reward_order.codex_rewards.size() - 1)
	reward_order.souvenir_rewards.resize(reward_order.souvenir_rewards.size() - 1)
	expect_true(
		_contains_error(reward_errors, "unknown codex reward ID")
		and _contains_error(reward_errors, "unknown souvenir reward ID"),
		"M1 validation must reject missing typed Codex and Souvenir reward references.",
		failures
	)

	var white_order: OrderDefinition = source.find_order(
		&"order_m1_white_noise_archive_core"
	)
	var original_order_readiness: int = white_order.content_readiness
	white_order.content_readiness = OrderDefinition.ContentReadiness.PLAYABLE
	var order_readiness_errors: PackedStringArray = GameDataValidator.validate(source)
	white_order.content_readiness = (
		original_order_readiness as OrderDefinition.ContentReadiness
	)
	expect_true(
		_contains_error(
			order_readiness_errors,
			"must remain REGISTERED_ONLY"
		),
		"M1 validation must reject claiming an unbuilt order is playable.",
		failures
	)
	white_order.content_readiness = 99 as OrderDefinition.ContentReadiness
	var invalid_order_readiness_errors: PackedStringArray = (
		GameDataValidator.validate(source)
	)
	white_order.content_readiness = (
		original_order_readiness as OrderDefinition.ContentReadiness
	)
	expect_true(
		_contains_error(
			invalid_order_readiness_errors,
			"content_readiness is invalid"
		),
		"Order validation must reject values outside the readiness enum.",
		failures
	)
	var original_required_modules: Array[ShipModuleDefinition] = []
	for module: ShipModuleDefinition in white_order.required_modules:
		original_required_modules.append(module)
	white_order.required_modules = [
		source.find_module(&"module_standard_drive"),
	]
	var white_module_errors: PackedStringArray = GameDataValidator.validate(source)
	white_order.required_modules = original_required_modules
	expect_true(
		_contains_error(
			white_module_errors,
			"White Noise main order must require"
		),
		"M1 validation must reject removal of White Noise's required shielding.",
		failures
	)

	var white_planet: PlanetDefinition = source.find_planet(
		&"planet_white_noise"
	)
	var original_readiness: int = white_planet.content_readiness
	var original_scene_path: String = white_planet.flight_scene_path
	white_planet.content_readiness = PlanetDefinition.ContentReadiness.PLAYABLE
	white_planet.flight_scene_path = "res://scenes/flight/flight_level.tscn"
	var readiness_errors: PackedStringArray = GameDataValidator.validate(source)
	white_planet.content_readiness = (
		original_readiness as PlanetDefinition.ContentReadiness
	)
	white_planet.flight_scene_path = original_scene_path
	expect_true(
		_contains_error(
			readiness_errors,
			"must remain REGISTERED_ONLY"
		),
		"M1 validation must reject claiming an unbuilt planet route is playable.",
		failures
	)

	var canopy_side: OrderDefinition = source.find_order(&"side_canopy_spore_drop")
	var original_delivery_type: int = canopy_side.delivery_type
	canopy_side.delivery_type = OrderDefinition.DeliveryType.LANDING
	var delivery_errors: PackedStringArray = GameDataValidator.validate(source)
	canopy_side.delivery_type = original_delivery_type as OrderDefinition.DeliveryType
	expect_true(
		_contains_error(
			delivery_errors,
			"Canopy side order must use LOW_ALTITUDE_DROP"
		),
		"M1 validation must reject an invalid Canopy delivery contract.",
		failures
	)

	var tidal_side: OrderDefinition = source.find_order(
		&"side_tidal_beacon_before_eye"
	)
	var original_target_seconds: float = tidal_side.target_seconds
	tidal_side.target_seconds = 0.0
	var express_errors: PackedStringArray = GameDataValidator.validate(source)
	tidal_side.target_seconds = original_target_seconds
	expect_true(
		_contains_error(
			express_errors,
			"express target_seconds must be positive"
		),
		"M1 validation must reject invalid Tidal express timing.",
		failures
	)

	var original_sender: CharacterDefinition = white_order.sender
	white_order.sender = null
	var character_errors: PackedStringArray = GameDataValidator.validate(source)
	white_order.sender = original_sender
	expect_true(
		_contains_error(character_errors, "sender is missing"),
		"M1 validation must reject a missing character reference.",
		failures
	)
	var canopy_main: OrderDefinition = source.find_order(&"order_m1_canopy_ecology_cargo")
	var original_cargo: CargoDefinition = canopy_main.cargo
	canopy_main.cargo = null
	var cargo_errors: PackedStringArray = GameDataValidator.validate(source)
	canopy_main.cargo = original_cargo
	expect_true(
		_contains_error(cargo_errors, "cargo is missing"),
		"M1 validation must reject a missing cargo reference.",
		failures
	)
	var tidal_main: OrderDefinition = source.find_order(&"order_m1_tidal_weather_core")
	var original_planet_id: StringName = tidal_main.planet_id
	tidal_main.planet_id = &"planet_missing"
	var planet_errors: PackedStringArray = GameDataValidator.validate(source)
	tidal_main.planet_id = original_planet_id
	expect_true(
		_contains_error(planet_errors, "unknown planet_id"),
		"M1 validation must reject a missing planet reference.",
		failures
	)
	var missing_module: ShipModuleDefinition = ShipModuleDefinition.new()
	missing_module.id = &"module_missing"
	canopy_main.recommended_modules.append(missing_module)
	var missing_module_errors: PackedStringArray = GameDataValidator.validate(source)
	canopy_main.recommended_modules.resize(
		canopy_main.recommended_modules.size() - 1
	)
	expect_true(
		_contains_error(
			missing_module_errors,
			"references unregistered ShipModuleDefinition"
		),
		"M1 validation must reject a missing module reference.",
		failures
	)
	white_order.recommended_modules.append(
		source.find_module(&"module_high_voltage_shielding")
	)
	var duplicate_module_errors: PackedStringArray = GameDataValidator.validate(source)
	white_order.recommended_modules.resize(
		white_order.recommended_modules.size() - 1
	)
	expect_true(
		_contains_error(
			duplicate_module_errors,
			"as both required and recommended"
		),
		"M1 validation must reject the same module in required and recommended lists.",
		failures
	)
	var white_side: OrderDefinition = source.find_order(&"side_white_noise_returned_memory")
	var original_repeat_policy: int = white_side.repeat_policy
	white_side.repeat_policy = OrderDefinition.RepeatPolicy.ARCHIVED_ONLY
	var archived_side_errors: PackedStringArray = GameDataValidator.validate(source)
	white_side.repeat_policy = original_repeat_policy as OrderDefinition.RepeatPolicy
	expect_true(
		_contains_error(
			archived_side_errors,
			"cannot use ARCHIVED_ONLY"
		),
		"M1 validation must reject archiving a required side order.",
		failures
	)

	var original_alias_target: StringName = source.order_aliases.get(
		&"order_red_sand_cooling_core",
		&""
	)
	source.order_aliases[&"order_red_sand_cooling_core"] = &"order_missing"
	var alias_errors: PackedStringArray = GameDataValidator.validate(source)
	source.order_aliases[&"order_red_sand_cooling_core"] = original_alias_target
	expect_true(
		_contains_error(
			alias_errors,
			"must target exactly one registered"
		),
		"M1 validation must reject an alias without one actual order target.",
		failures
	)


func _has_module_id(
	modules: Array[ShipModuleDefinition],
	module_id: StringName
) -> bool:
	for module: ShipModuleDefinition in modules:
		if module != null and module.id == module_id:
			return true
	return false


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
