extends ProjectTestSuite

var _persistent_change_count: int = 0


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_v1_migration_runtime_start(failures)
	_test_main_story_chapter_sequence(failures)
	_test_planet_unlock_rules(failures)
	_test_extensible_planet_unlock_context(failures)
	_test_relation_and_unique_events(failures)
	_test_permission_codex_souvenir_and_revisit(failures)
	_test_schema_v2_runtime_round_trip(failures)
	return failures


func _test_v1_migration_runtime_start(failures: Array[String]) -> void:
	var completed_progress: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 1,
		"game_progress": {
			"completed_order_ids": [
				String(GameProgressData.LEGACY_RED_SAND_ORDER_ID),
			],
		},
	})
	var completed_state: GameStateModel = GameStateModel.new()
	expect_true(
		completed_progress.is_valid() and completed_progress.apply_to(completed_state),
		"A completed v1 fixture must migrate and apply.",
		failures
	)
	expect_true(
		completed_state.get_main_story_chapter()
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and completed_state.is_planet_unlocked(M1ProgressRules.PLANET_RED_SAND)
		and not completed_state.is_planet_unlocked(
			M1ProgressRules.PLANET_WHITE_NOISE
		),
		"M0 completion must enter Red Sand revisit with only Red Sand unlocked.",
		failures
	)

	var incomplete_progress: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 1,
		"game_progress": {
			"story_flags": ["m0_first_delivery_not_finished"],
		},
	})
	var incomplete_state: GameStateModel = GameStateModel.new()
	expect_true(
		incomplete_progress.is_valid() and incomplete_progress.apply_to(incomplete_state),
		"An incomplete v1 fixture must migrate and apply.",
		failures
	)
	expect_true(
		incomplete_state.get_main_story_chapter().is_empty()
		and incomplete_state.unlocked_planet_ids.is_empty()
		and incomplete_state.planet_permission_ids.is_empty()
		and incomplete_state.planet_relation_values.is_empty(),
		"An incomplete M0 save must receive no M1 chapter, planet, permission, or relation.",
		failures
	)
	completed_state.free()
	incomplete_state.free()


func _test_main_story_chapter_sequence(failures: Array[String]) -> void:
	var game_state: GameStateModel = _create_observed_state()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE
	var expected_sequence: Array[StringName] = [
		M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT,
		M1ProgressRules.CHAPTER_M1_WHITE_NOISE,
		M1ProgressRules.CHAPTER_M1_CANOPY_WORLD,
		M1ProgressRules.CHAPTER_M1_TIDAL_ARCHIPELAGO,
		M1ProgressRules.CHAPTER_M1_DEMO_EPILOGUE,
	]
	for next_chapter: StringName in expected_sequence:
		var previous_chapter: StringName = game_state.get_main_story_chapter()
		var result: ProgressChangeResult = game_state.advance_main_story_chapter(
			next_chapter
		)
		expect_true(
			result.success
			and result.changed
			and result.previous_value == previous_chapter
			and result.current_value == next_chapter
			and game_state.get_main_story_chapter() == next_chapter,
			"Each direct chapter successor must advance atomically: %s." % next_chapter,
			failures
		)
	expect_true(
		_persistent_change_count == expected_sequence.size(),
		"Each real chapter advance must emit one persistent change.",
		failures
	)
	expect_true(
		game_state.has_reached_main_story_chapter(
			M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		),
		"Reached/passed queries must recognize earlier chapters.",
		failures
	)

	var before_rejected_changes: int = _persistent_change_count
	var repeated: ProgressChangeResult = game_state.advance_main_story_chapter(
		M1ProgressRules.CHAPTER_M1_DEMO_EPILOGUE
	)
	var regression: ProgressChangeResult = game_state.advance_main_story_chapter(
		M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	)
	var invalid: ProgressChangeResult = game_state.advance_main_story_chapter(
		&"chapter_not_registered"
	)
	expect_true(
		repeated.success
		and not repeated.changed
		and repeated.reason_key == M1ProgressRules.REASON_ALREADY_CURRENT
		and not regression.success
		and regression.reason_key == M1ProgressRules.REASON_CHAPTER_REGRESSION
		and not invalid.success
		and invalid.reason_key == M1ProgressRules.REASON_INVALID_CHAPTER
		and _persistent_change_count == before_rejected_changes,
		"Repeated, regressive, and invalid chapters must not mutate or emit.",
		failures
	)

	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	var skipped: ProgressChangeResult = game_state.advance_main_story_chapter(
		M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
	)
	expect_true(
		not skipped.success
		and skipped.reason_key == M1ProgressRules.REASON_CHAPTER_SKIPPED
		and game_state.get_main_story_chapter()
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT,
		"Red Sand revisit must not skip directly to Canopy World.",
		failures
	)
	game_state.free()


func _test_planet_unlock_rules(failures: Array[String]) -> void:
	var game_state: GameStateModel = _create_observed_state()
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	expect_true(
		game_state.is_planet_unlocked(M1ProgressRules.PLANET_RED_SAND)
		and not game_state.is_planet_unlocked(M1ProgressRules.PLANET_WHITE_NOISE)
		and game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == M1ProgressRules.REASON_REQUIRED_CHAPTER,
		"Red Sand revisit must retain Red Sand while White Noise remains chapter-locked.",
		failures
	)

	expect_true(
		game_state.advance_main_story_chapter(
			M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		).success,
		"Red Sand revisit must advance directly to White Noise.",
		failures
	)
	expect_true(
		game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == M1ProgressRules.REASON_REQUIRED_STORY_FLAG,
		"White Noise must retain the completed-revisit story gate.",
		failures
	)
	game_state.set_story_flag(
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	)
	expect_true(
		game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == M1ProgressRules.REASON_REQUIRED_COMPLETED_ORDER,
		"White Noise must retain the exact completed-revisit order gate.",
		failures
	)
	game_state.completed_order_ids[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = true
	expect_true(
		game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == M1ProgressRules.REASON_REQUIRED_MODULE,
		"White Noise must remain locked without high-voltage shielding.",
		failures
	)
	game_state.ship_upgrade_ids.append(
		M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	)
	var signals_before_unlock: int = _persistent_change_count
	var unlocked: ProgressChangeResult = game_state.unlock_planet(
		M1ProgressRules.PLANET_WHITE_NOISE
	)
	var repeated: ProgressChangeResult = game_state.unlock_planet(
		M1ProgressRules.PLANET_WHITE_NOISE
	)
	expect_true(
		unlocked.success
		and unlocked.changed
		and repeated.success
		and not repeated.changed
		and repeated.reason_key == M1ProgressRules.REASON_ALREADY_UNLOCKED
		and game_state.unlocked_planet_ids.count(
			M1ProgressRules.PLANET_WHITE_NOISE
		) == 1
		and _persistent_change_count == signals_before_unlock + 1,
		"White Noise unlock must require its module and remain idempotent.",
		failures
	)

	expect_true(
		game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_CANOPY_WORLD
		) == M1ProgressRules.REASON_REQUIRED_CHAPTER
		and game_state.get_planet_unlock_reason(
			M1ProgressRules.PLANET_TIDAL_ARCHIPELAGO
		) == M1ProgressRules.REASON_REQUIRED_CHAPTER,
		"Canopy World and Tidal Archipelago must not unlock before their chapters.",
		failures
	)
	expect_true(
		game_state.advance_main_story_chapter(
			M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
		).changed
		and game_state.unlock_planet(
			M1ProgressRules.PLANET_CANOPY_WORLD
		).changed
		and game_state.advance_main_story_chapter(
			M1ProgressRules.CHAPTER_M1_TIDAL_ARCHIPELAGO
		).changed
		and game_state.unlock_planet(
			M1ProgressRules.PLANET_TIDAL_ARCHIPELAGO
		).changed,
		"Canopy World and Tidal Archipelago must unlock only in sequence.",
		failures
	)
	var invalid: ProgressChangeResult = game_state.unlock_planet(
		&"planet_not_registered"
	)
	expect_true(
		not invalid.success
		and invalid.reason_key == M1ProgressRules.REASON_INVALID_PLANET,
		"Unknown planet IDs must be rejected.",
		failures
	)

	var equipped_state: GameStateModel = GameStateModel.new()
	equipped_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	equipped_state.unlocked_planet_ids = [M1ProgressRules.PLANET_RED_SAND]
	equipped_state.story_flags[
		M1ProgressRules.STORY_RED_SAND_SHIELDING_RETROFIT_COMPLETED
	] = true
	equipped_state.completed_order_ids[
		M1ProgressRules.ORDER_RED_SAND_SHIELDING_RETROFIT
	] = true
	equipped_state.ship_configuration[
		ShipLoadoutRules.SLOT_DEFENSE
	] = M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
	expect_true(
		equipped_state.can_unlock_planet(M1ProgressRules.PLANET_WHITE_NOISE),
		"Planet access must recognize a required module in the installed loadout.",
		failures
	)
	equipped_state.free()
	game_state.free()


func _test_extensible_planet_unlock_context(failures: Array[String]) -> void:
	var rule: M1ProgressRules.PlanetUnlockRule = (
		M1ProgressRules.get_planet_unlock_rule(M1ProgressRules.PLANET_RED_SAND)
	)
	rule.required_permission_ids = [
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS,
	]
	rule.required_story_flag_ids = [&"story_test_unlock"]
	rule.required_completed_order_ids = [&"order_test_unlock"]
	rule.required_context_ids = [&"context_test_unlock"]
	var unlocked_planets: Array[StringName] = []
	var ship_upgrades: Array[StringName] = []
	var permission_ids: Array[StringName] = []
	var story_flags: Dictionary[StringName, bool] = {}
	var completed_order_ids: Dictionary[StringName, bool] = {}
	var whitelist_context: Dictionary[StringName, bool] = {}
	var configuration: Dictionary[StringName, StringName] = (
		ShipLoadoutRules.create_default_configuration()
	)
	expect_true(
		M1ProgressRules.evaluate_planet_unlock_rule(
			rule,
			M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE,
			unlocked_planets,
			configuration,
			ship_upgrades,
			permission_ids,
			story_flags,
			completed_order_ids,
			whitelist_context
		) == M1ProgressRules.REASON_REQUIRED_PERMISSION,
		"Extensible planet rules must read permission requirements.",
		failures
	)
	permission_ids.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	expect_true(
		M1ProgressRules.evaluate_planet_unlock_rule(
			rule,
			M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE,
			unlocked_planets,
			configuration,
			ship_upgrades,
			permission_ids,
			story_flags,
			completed_order_ids,
			whitelist_context
		) == M1ProgressRules.REASON_REQUIRED_STORY_FLAG,
		"Extensible planet rules must read story-flag requirements.",
		failures
	)
	story_flags[&"story_test_unlock"] = true
	expect_true(
		M1ProgressRules.evaluate_planet_unlock_rule(
			rule,
			M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE,
			unlocked_planets,
			configuration,
			ship_upgrades,
			permission_ids,
			story_flags,
			completed_order_ids,
			whitelist_context
		) == M1ProgressRules.REASON_REQUIRED_COMPLETED_ORDER,
		"Extensible planet rules must read completed-order requirements.",
		failures
	)
	completed_order_ids[&"order_test_unlock"] = true
	expect_true(
		M1ProgressRules.evaluate_planet_unlock_rule(
			rule,
			M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE,
			unlocked_planets,
			configuration,
			ship_upgrades,
			permission_ids,
			story_flags,
			completed_order_ids,
			whitelist_context
		) == M1ProgressRules.REASON_REQUIRED_CONTEXT,
		"Extensible planet rules must read caller-provided whitelist context.",
		failures
	)
	whitelist_context[&"context_test_unlock"] = true
	expect_true(
		M1ProgressRules.evaluate_planet_unlock_rule(
			rule,
			M1ProgressRules.CHAPTER_M0_RED_SAND_COMPLETE,
			unlocked_planets,
			configuration,
			ship_upgrades,
			permission_ids,
			story_flags,
			completed_order_ids,
			whitelist_context
		).is_empty(),
		"An extensible planet rule must pass when every whitelisted condition is met.",
		failures
	)


func _test_relation_and_unique_events(failures: Array[String]) -> void:
	var game_state: GameStateModel = _create_observed_state()
	var first: ProgressChangeResult = game_state.change_planet_relation(
		M1ProgressRules.PLANET_RED_SAND,
		8,
		&"first_delivery_kind"
	)
	var signal_count_after_first: int = _persistent_change_count
	var repeated: ProgressChangeResult = game_state.change_planet_relation(
		M1ProgressRules.PLANET_RED_SAND,
		8,
		&"first_delivery_kind"
	)
	var at_limit: ProgressChangeResult = game_state.change_planet_relation(
		M1ProgressRules.PLANET_RED_SAND,
		1,
		&"unused_at_positive_limit"
	)
	expect_true(
		first.success
		and first.changed
		and game_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND)
		== M1ProgressRules.RELATION_MAXIMUM
		and repeated.success
		and not repeated.changed
		and repeated.reason_key == M1ProgressRules.REASON_ALREADY_APPLIED
		and at_limit.success
		and not at_limit.changed
		and not game_state.has_applied_planet_relation_event(
			M1ProgressRules.PLANET_RED_SAND,
			&"unused_at_positive_limit"
		)
		and _persistent_change_count == signal_count_after_first,
		"Relations must clamp and unique events must not repeat or consume at limits.",
		failures
	)

	var decrease: ProgressChangeResult = game_state.change_planet_relation(
		M1ProgressRules.PLANET_RED_SAND,
		-20,
		&"archive_choice_private"
	)
	var corrected: ProgressChangeResult = game_state.set_planet_relation(
		M1ProgressRules.PLANET_RED_SAND,
		99
	)
	var invalid: ProgressChangeResult = game_state.change_planet_relation(
		&"planet_invalid",
		1,
		&"valid_event"
	)
	expect_true(
		decrease.success
		and decrease.current_value == M1ProgressRules.RELATION_MINIMUM
		and corrected.success
		and corrected.current_value == M1ProgressRules.RELATION_MAXIMUM
		and not invalid.success
		and invalid.reason_key == M1ProgressRules.REASON_INVALID_PLANET,
		"Relation decrease, internal bounded set, and invalid planet rejection must work.",
		failures
	)
	game_state.free()


func _test_permission_codex_souvenir_and_revisit(
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = _create_observed_state()
	var permission_id: StringName = (
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	var granted: ProgressChangeResult = game_state.grant_permission(permission_id)
	var signal_count_after_permission: int = _persistent_change_count
	var repeated_permission: ProgressChangeResult = game_state.grant_permission(
		permission_id
	)
	var invalid_permission: ProgressChangeResult = game_state.grant_permission(
		&"permission_unknown"
	)
	expect_true(
		granted.changed
		and game_state.has_permission(permission_id)
		and repeated_permission.success
		and not repeated_permission.changed
		and not invalid_permission.success
		and invalid_permission.reason_key
		== M1ProgressRules.REASON_INVALID_PERMISSION
		and _persistent_change_count == signal_count_after_permission,
		"Permission grants must validate, persist once, and remain idempotent.",
		failures
	)

	var codex_id: StringName = GameProgressData.RED_SAND_CODEX_ENTRY_ID
	var souvenir_id: StringName = GameProgressData.RELAY_PLAQUE_SOUVENIR_ID
	var codex_result: ProgressChangeResult = game_state.unlock_codex_entry(codex_id)
	var souvenir_result: ProgressChangeResult = game_state.add_souvenir(souvenir_id)
	var revisit_id: StringName = &"revisit_red_sand_available"
	var revisit_result: ProgressChangeResult = game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		revisit_id
	)
	var signal_count_after_collections: int = _persistent_change_count
	var repeated_codex: ProgressChangeResult = game_state.unlock_codex_entry(codex_id)
	var repeated_souvenir: ProgressChangeResult = game_state.add_souvenir(souvenir_id)
	var repeated_revisit: ProgressChangeResult = game_state.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		revisit_id
	)
	var invalid_revisit: ProgressChangeResult = game_state.set_revisit_state(
		&"planet_unknown",
		revisit_id
	)
	expect_true(
		codex_result.changed
		and souvenir_result.changed
		and revisit_result.changed
		and game_state.has_codex_entry(codex_id)
		and game_state.has_souvenir(souvenir_id)
		and game_state.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== revisit_id
		and not repeated_codex.changed
		and not repeated_souvenir.changed
		and not repeated_revisit.changed
		and not invalid_revisit.success
		and _persistent_change_count == signal_count_after_collections,
		"Codex, souvenir, and revisit operations must reject duplicates and invalid planets.",
		failures
	)
	game_state.free()


func _test_schema_v2_runtime_round_trip(failures: Array[String]) -> void:
	var source: GameStateModel = GameStateModel.new()
	source.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	source.unlocked_planet_ids = [
		M1ProgressRules.PLANET_RED_SAND,
		M1ProgressRules.PLANET_WHITE_NOISE,
	]
	source.change_planet_relation(
		M1ProgressRules.PLANET_WHITE_NOISE,
		2,
		&"archive_choice_shared"
	)
	source.grant_permission(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	source.unlock_codex_entry(&"codex_planet_white_noise")
	source.add_souvenir(&"souvenir_white_noise_memory_fragment")
	source.set_revisit_state(
		M1ProgressRules.PLANET_RED_SAND,
		&"revisit_red_sand_completed"
	)
	source.ship_upgrade_ids = [M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING]

	var captured: GameProgressData = GameProgressData.capture(source)
	var decoded: GameProgressData = GameProgressData.from_dictionary(
		captured.to_dictionary()
	)
	var restored: GameStateModel = _create_observed_state()
	_persistent_change_count = 0
	expect_true(
		captured.is_valid() and decoded.is_valid() and decoded.apply_to(restored),
		"M1 runtime state must round-trip through schema v2.",
		failures
	)
	expect_true(
		restored.get_main_story_chapter()
		== M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and restored.is_planet_unlocked(M1ProgressRules.PLANET_WHITE_NOISE)
		and restored.get_planet_relation(M1ProgressRules.PLANET_WHITE_NOISE) == 2
		and restored.has_applied_planet_relation_event(
			M1ProgressRules.PLANET_WHITE_NOISE,
			&"archive_choice_shared"
		)
		and restored.has_permission(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		)
		and restored.has_codex_entry(&"codex_planet_white_noise")
		and restored.has_souvenir(&"souvenir_white_noise_memory_fragment")
		and restored.get_revisit_state(M1ProgressRules.PLANET_RED_SAND)
		== &"revisit_red_sand_completed"
		and restored.ship_upgrade_ids
		== [M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING],
		"Restored M1 progress must preserve all runtime semantics.",
		failures
	)
	expect_true(
		_persistent_change_count == 0,
		"Loading schema v2 must not reinterpret state as rewards or persistent changes.",
		failures
	)
	source.free()
	restored.free()


func _create_observed_state() -> GameStateModel:
	_persistent_change_count = 0
	var game_state: GameStateModel = GameStateModel.new()
	game_state.persistent_state_changed.connect(_on_persistent_state_changed)
	return game_state


func _on_persistent_state_changed() -> void:
	_persistent_change_count += 1
