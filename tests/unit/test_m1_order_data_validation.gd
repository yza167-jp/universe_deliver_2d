extends ProjectTestSuite

const REGISTRY_PATH: String = "res://data/m0_data_registry.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_valid_extended_order(failures)
	_test_missing_planet_and_chapter_references(failures)
	_test_missing_reward_references(failures)
	_test_duplicate_order_and_invalid_delivery_type(failures)
	_test_invalid_unlock_condition_and_main_repeat_policy(failures)
	_test_save_rejects_multiple_active_and_unknown_status(failures)
	return failures


func _test_valid_extended_order(failures: Array[String]) -> void:
	var registry: GameDataRegistry = _make_registry_with_extended_order()
	var errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		errors.is_empty(),
		"A complete M1 order definition must validate: %s" % "; ".join(errors),
		failures
	)


func _test_missing_planet_and_chapter_references(
	failures: Array[String]
) -> void:
	var planet_registry: GameDataRegistry = _make_registry_with_extended_order()
	planet_registry.orders[1].planet_id = &"planet_missing"
	var planet_errors: PackedStringArray = GameDataValidator.validate(planet_registry)
	expect_true(
		_contains_error(planet_errors, "unknown planet_id"),
		"Order validation must reject a nonexistent planet_id with a clear reason.",
		failures
	)

	var chapter_registry: GameDataRegistry = _make_registry_with_extended_order()
	chapter_registry.orders[1].required_chapter = &"chapter_missing"
	var chapter_errors: PackedStringArray = GameDataValidator.validate(chapter_registry)
	expect_true(
		_contains_error(chapter_errors, "unknown chapter_id"),
		"Order validation must reject a nonexistent chapter_id with a clear reason.",
		failures
	)


func _test_missing_reward_references(failures: Array[String]) -> void:
	var registry: GameDataRegistry = _make_registry_with_extended_order()
	var order: OrderDefinition = registry.orders[1]
	order.relation_rewards[&"planet_missing"] = 1
	order.permission_rewards.append(&"permission_missing")
	order.codex_rewards.append(&"codex_missing")
	order.souvenir_rewards.append(&"souvenir_missing")
	var errors: PackedStringArray = GameDataValidator.validate(registry)
	expect_true(
		_contains_error(errors, "relation reward references unknown planet_id")
		and _contains_error(errors, "unknown permission reward ID")
		and _contains_error(errors, "unknown codex reward ID")
		and _contains_error(errors, "unknown souvenir reward ID"),
		"All missing reward references must fail validation with field-specific reasons.",
		failures
	)


func _test_duplicate_order_and_invalid_delivery_type(
	failures: Array[String]
) -> void:
	var duplicate_registry: GameDataRegistry = _make_registry_with_extended_order()
	var duplicate_order: OrderDefinition = duplicate_registry.orders[1].duplicate(
		false
	) as OrderDefinition
	duplicate_registry.orders.append(duplicate_order)
	var duplicate_errors: PackedStringArray = GameDataValidator.validate(
		duplicate_registry
	)
	expect_true(
		_contains_error(duplicate_errors, "Duplicate ID"),
		"Duplicate order_id values must fail registry validation.",
		failures
	)

	var delivery_registry: GameDataRegistry = _make_registry_with_extended_order()
	delivery_registry.orders[1].delivery_type = 99 as OrderDefinition.DeliveryType
	var delivery_errors: PackedStringArray = GameDataValidator.validate(delivery_registry)
	expect_true(
		_contains_error(delivery_errors, "delivery_type is invalid"),
		"Unsupported delivery types must fail validation.",
		failures
	)


func _test_invalid_unlock_condition_and_main_repeat_policy(
	failures: Array[String]
) -> void:
	var condition_registry: GameDataRegistry = _make_registry_with_extended_order()
	condition_registry.orders[1].unlock_conditions[0].reference_id = &"module_missing"
	var condition_errors: PackedStringArray = GameDataValidator.validate(
		condition_registry
	)
	expect_true(
		_contains_error(condition_errors, "unknown module ID"),
		"Unlock conditions must reject an unregistered module reference.",
		failures
	)

	var policy_registry: GameDataRegistry = _make_registry_with_extended_order()
	var main_order: OrderDefinition = policy_registry.orders[0]
	main_order.repeat_policy = OrderDefinition.RepeatPolicy.REPEATABLE
	var policy_errors: PackedStringArray = GameDataValidator.validate(policy_registry)
	expect_true(
		_contains_error(policy_errors, "mainline orders must use UNIQUE"),
		"Main and revisit orders must not opt into a repeatable reward loop.",
		failures
	)


func _test_save_rejects_multiple_active_and_unknown_status(
	failures: Array[String]
) -> void:
	var multiple_active: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"current_order_id": "side_active_one",
			"destination_id": "planet_red_sand",
			"cargo_id": "cargo_red_sand_m0",
			"order_run_state": {
				"order_id": "side_active_one",
			},
			"order_states": {
				"side_active_one": "ACCEPTED",
				"side_active_two": "ACCEPTED",
			},
		},
	})
	expect_true(
		not multiple_active.is_valid()
		and multiple_active.validation_error.contains("Only one order"),
		"Schema v2 must reject multiple ACCEPTED active orders.",
		failures
	)

	var unknown_status: GameProgressData = GameProgressData.from_dictionary({
		"schema_version": 2,
		"game_progress": {
			"order_states": {
				"side_unknown_state": "BROKEN",
			},
		},
	})
	expect_true(
		not unknown_status.is_valid()
		and unknown_status.validation_error.contains("Unknown order status"),
		"Schema v2 must reject an unknown order transition state with a clear reason.",
		failures
	)


func _make_registry_with_extended_order() -> GameDataRegistry:
	var source: GameDataRegistry = load(REGISTRY_PATH) as GameDataRegistry
	var registry: GameDataRegistry = source.duplicate(true) as GameDataRegistry
	registry.codex_reward_ids = [&"codex_test_order_reward"]
	registry.souvenir_reward_ids = [&"souvenir_test_order_reward"]
	var order: OrderDefinition = registry.orders[0].duplicate(false) as OrderDefinition
	order.id = &"side_test_valid_extended"
	order.order_type = OrderDefinition.OrderType.SIDE
	order.required_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	order.planet_id = M1ProgressRules.PLANET_RED_SAND
	order.destination_id = &"destination_red_sand_repair_yard"
	order.delivery_type = OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
	order.credit_reward = 80
	order.relation_rewards[M1ProgressRules.PLANET_RED_SAND] = 1
	order.permission_rewards = [
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS,
	]
	order.codex_rewards = [&"codex_test_order_reward"]
	order.souvenir_rewards = [&"souvenir_test_order_reward"]
	order.repeat_policy = OrderDefinition.RepeatPolicy.UNIQUE
	order.is_express = true
	order.target_seconds = 60.0
	order.grace_seconds = 30.0
	order.minimum_reward_ratio = 0.5
	order.relation_bonus_on_time = 1
	var module_condition: OrderUnlockCondition = OrderUnlockCondition.new()
	module_condition.condition_type = OrderUnlockCondition.ConditionType.MODULE_AVAILABLE
	module_condition.reference_id = ShipLoadoutRules.LASER_MODULE_ID
	order.unlock_conditions = [module_condition]
	registry.orders.append(order)
	return registry


func _contains_error(errors: PackedStringArray, expected_fragment: String) -> bool:
	for error: String in errors:
		if error.contains(expected_fragment):
			return true
	return false
