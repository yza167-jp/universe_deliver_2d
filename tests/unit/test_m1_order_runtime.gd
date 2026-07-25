extends ProjectTestSuite

const ORDER_PATH: String = "res://data/orders/red_sand_m0.tres"
const SAVE_PATH: String = "user://t103_order_runtime.json"
const TEMP_PATH: String = "user://t103_order_runtime.tmp"
const BACKUP_PATH: String = "user://t103_order_runtime.backup.json"
const REJECTED_PATH: String = "user://t103_order_runtime.invalid.json"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_order_model(failures)
	_test_one_active_order_and_mainline_safety(failures)
	_test_side_failure_abandonment_and_retry_policy(failures)
	_test_unlock_conditions_use_m1_progress(failures)
	_test_reward_idempotency(failures)
	_test_express_timing_and_reduced_reward(failures)
	_test_revisit_and_archive_states(failures)
	_test_save_service_preserves_active_and_completed_state(failures)
	_cleanup_save_files()
	return failures


func _test_order_model(failures: Array[String]) -> void:
	var main_order: OrderDefinition = _make_order(
		&"order_test_main",
		OrderDefinition.OrderType.MAIN
	)
	var side_order: OrderDefinition = _make_order(
		&"side_test_model",
		OrderDefinition.OrderType.SIDE
	)
	var revisit_order: OrderDefinition = _make_order(
		&"order_test_revisit",
		OrderDefinition.OrderType.REVISIT
	)
	side_order.delivery_type = OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP
	side_order.repeat_policy = OrderDefinition.RepeatPolicy.REPEATABLE
	expect_true(
		main_order.order_type == OrderDefinition.OrderType.MAIN
		and side_order.order_type == OrderDefinition.OrderType.SIDE
		and revisit_order.order_type == OrderDefinition.OrderType.REVISIT,
		"MAIN, SIDE, and REVISIT must remain distinct typed order categories.",
		failures
	)
	expect_true(
		main_order.delivery_type == OrderDefinition.DeliveryType.LANDING
		and side_order.delivery_type
		== OrderDefinition.DeliveryType.LOW_ALTITUDE_DROP,
		"Order delivery types must be limited to landing and low-altitude drop.",
		failures
	)
	expect_true(
		main_order.repeat_policy == OrderDefinition.RepeatPolicy.UNIQUE
		and side_order.repeat_policy == OrderDefinition.RepeatPolicy.REPEATABLE,
		"Order repeat policy must be typed rather than inferred from IDs.",
		failures
	)


func _test_one_active_order_and_mainline_safety(
	failures: Array[String]
) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var main_order: OrderDefinition = _make_order(
		&"order_test_mainline_flow",
		OrderDefinition.OrderType.MAIN
	)
	var side_order: OrderDefinition = _make_order(
		&"side_test_second_active",
		OrderDefinition.OrderType.SIDE
	)
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
	game_state.ship_upgrade_ids.append(&"module_story_sentinel")
	expect_true(
		not game_state.complete_order(main_order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_NOT_ACTIVE
		and game_state.get_order_status(main_order.id)
		== GameStateModel.OrderStatus.AVAILABLE,
		"AVAILABLE must not transition directly to COMPLETED.",
		failures
	)
	expect_true(game_state.accept_order(main_order), "Main order must accept when ready.", failures)
	expect_true(
		not game_state.accept_order(side_order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ACTIVE_ORDER,
		"A second order must be rejected while one active order exists.",
		failures
	)
	expect_true(
		not game_state.abandon_order(main_order)
		and game_state.last_order_error
		== GameStateModel.ORDER_ERROR_MAIN_CANNOT_ABANDON
		and game_state.get_order_status(main_order.id)
		== GameStateModel.OrderStatus.ACCEPTED,
		"Main orders must reject abandonment without changing state.",
		failures
	)
	expect_true(
		not game_state.fail_order(main_order)
		and game_state.last_order_error
		== GameStateModel.ORDER_ERROR_MAIN_RETRY_REQUIRED
		and game_state.get_order_status(main_order.id)
		== GameStateModel.OrderStatus.ACCEPTED,
		"Main-order failure must retain the active retry path instead of creating a dead end.",
		failures
	)
	expect_true(
		game_state.main_story_chapter
		== M1ProgressRules.CHAPTER_M1_RED_SAND_REVISIT
		and game_state.ship_upgrade_ids.has(&"module_story_sentinel"),
		"Rejected main failure must not regress chapters or remove modules.",
		failures
	)
	expect_true(
		game_state.complete_order(main_order)
		and game_state.get_order_status(main_order.id)
		== GameStateModel.OrderStatus.COMPLETED,
		"The active main order must complete through the legal transition.",
		failures
	)
	expect_true(
		not game_state.accept_order(main_order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED,
		"COMPLETED must never transition back to ACCEPTED.",
		failures
	)
	game_state.free()


func _test_side_failure_abandonment_and_retry_policy(
	failures: Array[String]
) -> void:
	var unique_state: GameStateModel = GameStateModel.new()
	var unique_side: OrderDefinition = _make_order(
		&"side_test_unique_failure",
		OrderDefinition.OrderType.SIDE
	)
	unique_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	unique_state.ship_upgrade_ids.append(&"module_keep_after_side_failure")
	expect_true(unique_state.accept_order(unique_side), "Unique side order must accept.", failures)
	expect_true(
		unique_state.fail_order(unique_side)
		and unique_state.get_order_status(unique_side.id)
		== GameStateModel.OrderStatus.FAILED
		and unique_state.current_order_id.is_empty(),
		"Accepted side orders must support FAILED and clear the active slot.",
		failures
	)
	expect_true(
		unique_state.main_story_chapter == M1ProgressRules.CHAPTER_M1_WHITE_NOISE
		and unique_state.ship_upgrade_ids.has(&"module_keep_after_side_failure"),
		"Side failure must not regress the chapter or remove a module.",
		failures
	)
	expect_true(
		not unique_state.accept_order(unique_side)
		and unique_state.last_order_error == GameStateModel.ORDER_ERROR_RETRY_NOT_ALLOWED,
		"FAILED UNIQUE orders must reject an implicit retry transition.",
		failures
	)
	unique_state.free()

	var abandoned_state: GameStateModel = GameStateModel.new()
	var abandoned_side: OrderDefinition = _make_order(
		&"side_test_unique_abandon",
		OrderDefinition.OrderType.SIDE
	)
	expect_true(
		abandoned_state.accept_order(abandoned_side)
		and abandoned_state.abandon_order(abandoned_side)
		and abandoned_state.get_order_status(abandoned_side.id)
		== GameStateModel.OrderStatus.ABANDONED,
		"Side orders must allow the ACCEPTED to ABANDONED transition.",
		failures
	)
	expect_true(
		not abandoned_state.accept_order(abandoned_side)
		and abandoned_state.last_order_error
		== GameStateModel.ORDER_ERROR_RETRY_NOT_ALLOWED,
		"ABANDONED UNIQUE orders must remain terminal.",
		failures
	)
	abandoned_state.free()

	var repeatable_state: GameStateModel = GameStateModel.new()
	var repeatable_side: OrderDefinition = _make_order(
		&"side_test_explicit_retry",
		OrderDefinition.OrderType.SIDE
	)
	repeatable_side.repeat_policy = OrderDefinition.RepeatPolicy.REPEATABLE
	expect_true(
		repeatable_state.accept_order(repeatable_side)
		and repeatable_state.fail_order(repeatable_side)
		and repeatable_state.accept_order(repeatable_side),
		"REPEATABLE explicitly permits retry after a side-order failure.",
		failures
	)
	expect_true(
		repeatable_state.abandon_order(repeatable_side)
		and repeatable_state.accept_order(repeatable_side),
		"REPEATABLE explicitly permits retry after abandonment.",
		failures
	)
	repeatable_state.free()


func _test_unlock_conditions_use_m1_progress(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var gated_order: OrderDefinition = _make_order(
		&"side_test_m1_conditions",
		OrderDefinition.OrderType.SIDE
	)
	gated_order.required_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	gated_order.unlock_conditions = [
		_make_condition(
			OrderUnlockCondition.ConditionType.PLANET_UNLOCKED,
			M1ProgressRules.PLANET_RED_SAND
		),
		_make_condition(
			OrderUnlockCondition.ConditionType.PERMISSION_GRANTED,
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		),
		_make_condition(
			OrderUnlockCondition.ConditionType.MODULE_AVAILABLE,
			M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING
		),
	]
	expect_true(
		game_state.get_order_acceptance_error(gated_order)
		== M1ProgressRules.REASON_REQUIRED_CHAPTER,
		"Order chapter gates must read the T-102 chapter sequence.",
		failures
	)
	game_state.main_story_chapter = M1ProgressRules.CHAPTER_M1_WHITE_NOISE
	expect_true(
		game_state.get_order_acceptance_error(gated_order)
		== M1ProgressRules.REASON_REQUIRED_PLANET,
		"An order for a locked prerequisite planet must remain unavailable.",
		failures
	)
	game_state.unlocked_planet_ids.append(M1ProgressRules.PLANET_RED_SAND)
	expect_true(
		game_state.get_order_acceptance_error(gated_order)
		== M1ProgressRules.REASON_REQUIRED_PERMISSION,
		"Order permission gates must read the T-102 permission model.",
		failures
	)
	game_state.planet_permission_ids.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	expect_true(
		game_state.get_order_acceptance_error(gated_order)
		== M1ProgressRules.REASON_REQUIRED_MODULE,
		"An order requiring an unavailable module must be rejected.",
		failures
	)
	game_state.ship_upgrade_ids.append(M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING)
	expect_true(
		game_state.accept_order(gated_order),
		"Meeting chapter, planet, permission, and module gates must unlock acceptance.",
		failures
	)
	game_state.free()


func _test_reward_idempotency(failures: Array[String]) -> void:
	var game_state: GameStateModel = GameStateModel.new()
	var reward_order: OrderDefinition = _make_order(
		&"side_test_reward_once",
		OrderDefinition.OrderType.SIDE
	)
	reward_order.credit_reward = 120
	reward_order.relation_rewards[M1ProgressRules.PLANET_RED_SAND] = 2
	reward_order.permission_rewards.append(
		M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
	)
	reward_order.codex_rewards.append(&"codex_order_reward_once")
	reward_order.souvenir_rewards.append(&"souvenir_order_reward_once")
	expect_true(
		game_state.accept_order(reward_order)
		and game_state.complete_order(reward_order),
		"A valid side order must complete and apply its reward bundle.",
		failures
	)
	expect_true(
		game_state.get_credits() == 120
		and game_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 2
		and game_state.has_permission(
			M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		)
		and game_state.has_codex_entry(&"codex_order_reward_once")
		and game_state.has_souvenir(&"souvenir_order_reward_once"),
		"Unified completion must apply credits, relation, permission, codex, and souvenir rewards.",
		failures
	)
	expect_true(
		game_state.has_applied_order_reward(reward_order.id)
		and game_state.completed_side_order_ids.has(reward_order.id),
		"Completion must persist the reward ledger and side-order result.",
		failures
	)
	expect_true(
		not game_state.complete_order(reward_order)
		and game_state.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
		and game_state.get_credits() == 120
		and game_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 2
		and game_state.codex_entry_ids.count(&"codex_order_reward_once") == 1
		and game_state.souvenir_ids.count(&"souvenir_order_reward_once") == 1,
		"Repeated completion must return already_completed without duplicating any reward.",
		failures
	)
	game_state.free()


func _test_express_timing_and_reduced_reward(failures: Array[String]) -> void:
	var on_time_state: GameStateModel = GameStateModel.new()
	var on_time_order: OrderDefinition = _make_express_order(&"side_test_express_on_time")
	expect_true(on_time_state.accept_order(on_time_order), "Express order must accept.", failures)
	expect_true(
		on_time_state.advance_active_order_time(on_time_order, 5.0)
		and on_time_state.advance_active_order_time(on_time_order, 3.0, true)
		and on_time_state.advance_active_order_time(on_time_order, 4.0, false, true)
		and on_time_state.advance_active_order_time(on_time_order, 6.0, false, false, true)
		and is_equal_approx(on_time_state.order_run_state.elapsed_time, 5.0),
		"Dialogue, help, and game pause must all pause express timing.",
		failures
	)
	expect_true(
		on_time_state.complete_order(on_time_order)
		and on_time_state.get_credits() == 100
		and on_time_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 2,
		"On-time express completion must keep full credits and apply its relation bonus.",
		failures
	)
	on_time_state.free()

	var late_state: GameStateModel = GameStateModel.new()
	var late_order: OrderDefinition = _make_express_order(&"side_test_express_late")
	expect_true(
		late_state.accept_order(late_order)
		and late_state.advance_active_order_time(late_order, 15.0)
		and is_equal_approx(late_state.get_active_order_reward_ratio(late_order), 0.75)
		and late_state.complete_order(late_order),
		"Late express completion must remain completable rather than hard-failing.",
		failures
	)
	expect_true(
		late_state.get_order_status(late_order.id) == GameStateModel.OrderStatus.COMPLETED
		and late_state.get_credits() == 75
		and late_state.get_planet_relation(M1ProgressRules.PLANET_RED_SAND) == 1,
		"Five seconds into grace must reduce credits and withhold only the on-time relation bonus.",
		failures
	)
	late_state.free()

	var ordinary_state: GameStateModel = GameStateModel.new()
	var ordinary_order: OrderDefinition = _make_order(
		&"side_test_non_express_timer",
		OrderDefinition.OrderType.SIDE
	)
	expect_true(
		ordinary_state.accept_order(ordinary_order)
		and ordinary_state.advance_active_order_time(ordinary_order, 30.0)
		and is_zero_approx(ordinary_state.order_run_state.elapsed_time),
		"Non-express orders must not accumulate countdown time.",
		failures
	)
	ordinary_state.free()


func _test_revisit_and_archive_states(failures: Array[String]) -> void:
	var revisit_state_model: GameStateModel = GameStateModel.new()
	var revisit_order: OrderDefinition = _make_order(
		&"order_test_red_sand_revisit",
		OrderDefinition.OrderType.REVISIT
	)
	expect_true(
		revisit_state_model.accept_order(revisit_order)
		and not revisit_state_model.abandon_order(revisit_order)
		and revisit_state_model.last_order_error
		== GameStateModel.ORDER_ERROR_MAIN_CANNOT_ABANDON,
		"REVISIT supports a distinct type while retaining mainline abandonment safety.",
		failures
	)
	revisit_state_model.free()

	var archive_state: GameStateModel = GameStateModel.new()
	var archived_order: OrderDefinition = _make_order(
		&"side_test_archived_only",
		OrderDefinition.OrderType.SIDE
	)
	archived_order.repeat_policy = OrderDefinition.RepeatPolicy.ARCHIVED_ONLY
	expect_true(
		not archive_state.accept_order(archived_order)
		and archive_state.last_order_error == GameStateModel.ORDER_ERROR_ARCHIVED_ONLY
		and archive_state.archive_order(archived_order)
		and archive_state.get_order_status(archived_order.id)
		== GameStateModel.OrderStatus.ARCHIVED,
		"ARCHIVED_ONLY orders must be recordable without entering the active slot.",
		failures
	)
	archive_state.free()


func _test_save_service_preserves_active_and_completed_state(
	failures: Array[String]
) -> void:
	_cleanup_save_files()
	var order: OrderDefinition = _make_express_order(&"side_test_saved_express")
	var source: GameStateModel = GameStateModel.new()
	expect_true(source.accept_order(order), "Saved express fixture must accept.", failures)
	source.order_run_state.active_checkpoint_id = &"checkpoint_saved_express"
	source.advance_active_order_time(order, 14.0)
	var writer: SaveServiceModel = _make_save_service(source)
	expect_true(writer.save_progress(), writer.last_error, failures)

	var restored: GameStateModel = GameStateModel.new()
	var persistent_events: Array[int] = [0]
	restored.persistent_state_changed.connect(
		func() -> void:
			persistent_events[0] += 1
	)
	var reader: SaveServiceModel = _make_save_service(restored)
	expect_true(reader.load_progress(), reader.last_error, failures)
	expect_true(
		restored.current_order_id == order.id
		and restored.get_order_status(order.id) == GameStateModel.OrderStatus.ACCEPTED
		and restored.order_states.get(order.id) == GameStateModel.OrderStatus.ACCEPTED
		and is_equal_approx(restored.order_run_state.elapsed_time, 14.0)
		and restored.order_run_state.active_checkpoint_id == &"checkpoint_saved_express",
		"Schema v2 must preserve the one active order, timer, and checkpoint state.",
		failures
	)
	expect_true(
		persistent_events[0] == 0 and restored.get_credits() == 0,
		"Loading an active order must not emit a reward mutation or grant credits.",
		failures
	)
	expect_true(
		restored.complete_order(order) and restored.get_credits() == 80,
		"Completing the restored order must apply the elapsed-time-adjusted reward once.",
		failures
	)
	expect_true(reader.save_progress(), reader.last_error, failures)

	var completed: GameStateModel = GameStateModel.new()
	var completed_reader: SaveServiceModel = _make_save_service(completed)
	expect_true(completed_reader.load_progress(), completed_reader.last_error, failures)
	expect_true(
		completed.get_order_status(order.id) == GameStateModel.OrderStatus.COMPLETED
		and completed.has_applied_order_reward(order.id)
		and completed.get_credits() == 80,
		"Reloading a completed order must preserve its terminal state and reward ledger.",
		failures
	)
	expect_true(
		not completed.complete_order(order)
		and completed.last_order_error == GameStateModel.ORDER_ERROR_ALREADY_COMPLETED
		and completed.get_credits() == 80,
		"Repeated loading and completion must never reapply rewards.",
		failures
	)
	writer.free()
	reader.free()
	completed_reader.free()
	source.free()
	restored.free()
	completed.free()


func _make_order(
	order_id: StringName,
	order_type: OrderDefinition.OrderType
) -> OrderDefinition:
	var source: OrderDefinition = load(ORDER_PATH) as OrderDefinition
	var order: OrderDefinition = source.duplicate(true) as OrderDefinition
	order.id = order_id
	order.order_type = order_type
	order.required_chapter = &""
	order.unlock_conditions.clear()
	order.credit_reward = 100
	order.relation_rewards.clear()
	order.permission_rewards.clear()
	order.codex_rewards.clear()
	order.souvenir_rewards.clear()
	order.repeat_policy = OrderDefinition.RepeatPolicy.UNIQUE
	order.is_express = false
	order.target_seconds = 0.0
	order.grace_seconds = 0.0
	order.minimum_reward_ratio = 1.0
	order.relation_bonus_on_time = 0
	order.completion_flags.clear()
	order.story_requirements.clear()
	return order


func _make_express_order(order_id: StringName) -> OrderDefinition:
	var order: OrderDefinition = _make_order(
		order_id,
		OrderDefinition.OrderType.SIDE
	)
	order.is_express = true
	order.target_seconds = 10.0
	order.grace_seconds = 10.0
	order.minimum_reward_ratio = 0.5
	order.relation_rewards[M1ProgressRules.PLANET_RED_SAND] = 1
	order.relation_bonus_on_time = 1
	return order


func _make_condition(
	condition_type: OrderUnlockCondition.ConditionType,
	reference_id: StringName
) -> OrderUnlockCondition:
	var condition: OrderUnlockCondition = OrderUnlockCondition.new()
	condition.condition_type = condition_type
	condition.reference_id = reference_id
	return condition


func _make_save_service(game_state: GameStateModel) -> SaveServiceModel:
	var service: SaveServiceModel = SaveServiceModel.new()
	service.game_state_override = game_state
	service.configure_storage_paths(
		SAVE_PATH,
		TEMP_PATH,
		BACKUP_PATH,
		REJECTED_PATH
	)
	return service


func _cleanup_save_files() -> void:
	for path: String in [SAVE_PATH, TEMP_PATH, BACKUP_PATH, REJECTED_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
