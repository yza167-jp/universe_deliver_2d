extends ProjectTestSuite

const TUNING_PATH: String = "res://data/tuning/flight_tuning_m0.tres"


func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning: FlightTuning = load(TUNING_PATH) as FlightTuning
	expect_true(tuning != null, "M0 FlightTuning must load.", failures)
	if tuning == null:
		return failures
	_test_boost_consumption_and_cargo_cap(tuning, failures)
	_test_reverse_boost_block_prevents_resource_cost(tuning, failures)
	_test_boost_recovery_and_hover_block(tuning, failures)
	_test_shield_backup_regeneration_gates(tuning, failures)
	_test_emergency_thrust_prevents_fuel_deadlock(tuning, failures)
	_test_shield_absorbs_all_flight_damage(failures)
	_test_shield_overflow_scales_hull_and_cargo_damage(failures)
	_test_environment_hazard_uses_the_same_damage_order(failures)
	_test_delivery_cargo_damage_clamps_and_reports(failures)
	_test_resource_snapshot_is_independent(failures)
	return failures


func _test_shield_backup_regeneration_gates(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.shield = 40.0
	expect_true(
		is_zero_approx(
			resources.step_shield_regeneration(false, false, false, tuning, 1.0)
		)
		and is_equal_approx(resources.shield, 40.0),
		"Shield must not regenerate without the optional backup module.",
		failures
	)
	var recovered: float = resources.step_shield_regeneration(
		true,
		false,
		false,
		tuning,
		2.0
	)
	expect_true(
		is_equal_approx(recovered, tuning.shield_regeneration_per_second * 2.0)
		and is_equal_approx(resources.shield, 40.0 + recovered)
		and is_equal_approx(
			resources.shield_regeneration_rate,
			tuning.shield_regeneration_per_second
		),
		"Installed backup power must slowly restore an incomplete shield.",
		failures
	)
	var shield_before_gate: float = resources.shield
	expect_true(
		is_zero_approx(
			resources.step_shield_regeneration(true, true, false, tuning, 1.0)
		)
		and is_zero_approx(
			resources.step_shield_regeneration(true, false, true, tuning, 1.0)
		)
		and is_equal_approx(resources.shield, shield_before_gate)
		and is_zero_approx(resources.shield_regeneration_rate),
		"Boost and reverse states must each suspend shield regeneration.",
		failures
	)
	resources.shield = 99.0
	resources.step_shield_regeneration(true, false, false, tuning, 2.0)
	expect_true(
		is_equal_approx(resources.shield, FlightResources.MAX_RESOURCE_VALUE),
		"Shield regeneration must clamp at the 100-point maximum.",
		failures
	)


func _test_boost_consumption_and_cargo_cap(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	var effective_input: Vector2 = resources.step_propulsion(
		0.0,
		1.0,
		0.0,
		CargoDefinition.BoostPolicy.LIMITED,
		false,
		tuning,
		1.0
	)
	expect_true(
		is_equal_approx(effective_input.y, tuning.limited_cargo_boost_cap),
		"Limited cargo must cap effective Boost input.",
		failures
	)
	expect_true(
		resources.boost_energy < FlightResources.MAX_RESOURCE_VALUE
		and resources.fuel < FlightResources.MAX_RESOURCE_VALUE
		and resources.boost_energy_cost_rate > 0.0
		and resources.propulsion_fuel_cost_rate > 0.0,
		"Boost must consume both Boost energy and additional fuel.",
		failures
	)

	var forbidden_resources: FlightResources = FlightResources.new()
	var forbidden_input: Vector2 = forbidden_resources.step_propulsion(
		0.0,
		1.0,
		0.0,
		CargoDefinition.BoostPolicy.FORBIDDEN,
		false,
		tuning,
		1.0
	)
	expect_true(
		is_zero_approx(forbidden_input.y)
		and is_equal_approx(
			forbidden_resources.boost_energy,
			FlightResources.MAX_RESOURCE_VALUE
		),
		"Forbidden cargo must prevent Boost without consuming its energy.",
		failures
	)


func _test_reverse_boost_block_prevents_resource_cost(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.fuel = 50.0
	resources.boost_energy = 50.0
	var effective_input: Vector2 = resources.step_propulsion(
		0.0,
		1.0,
		0.0,
		CargoDefinition.BoostPolicy.ALLOWED,
		false,
		tuning,
		1.0,
		true
	)
	expect_true(
		is_zero_approx(effective_input.y)
		and is_zero_approx(resources.boost_energy_cost_rate)
		and is_zero_approx(resources.propulsion_fuel_cost_rate)
		and is_equal_approx(resources.fuel, 50.0)
		and resources.boost_energy >= 50.0,
		"Reverse Boost gating must prevent activation and resource consumption.",
		failures
	)


func _test_boost_recovery_and_hover_block(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.boost_energy = 40.0
	resources.step_propulsion(
		0.0,
		0.0,
		0.0,
		CargoDefinition.BoostPolicy.ALLOWED,
		true,
		tuning,
		1.0
	)
	expect_true(
		is_equal_approx(resources.boost_energy, 40.0),
		"100% paid hover must block natural Boost recovery.",
		failures
	)
	resources.step_propulsion(
		0.0,
		0.0,
		0.0,
		CargoDefinition.BoostPolicy.ALLOWED,
		false,
		tuning,
		1.0
	)
	expect_true(
		resources.boost_energy > 40.0
		and resources.boost_recovery_rate
		== tuning.boost_energy_recovery_per_second,
		"Boost must recover when it is idle and hover is not blocking recovery.",
		failures
	)


func _test_emergency_thrust_prevents_fuel_deadlock(
	tuning: FlightTuning,
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.fuel = 0.0
	var effective_input: Vector2 = resources.step_propulsion(
		1.0,
		1.0,
		0.0,
		CargoDefinition.BoostPolicy.ALLOWED,
		false,
		tuning,
		1.0
	)
	expect_true(
		is_equal_approx(effective_input.x, tuning.emergency_thrust_multiplier)
		and is_zero_approx(effective_input.y)
		and is_zero_approx(resources.fuel),
		"Zero fuel must retain configurable emergency thrust while disabling Boost.",
		failures
	)


func _test_shield_absorbs_all_flight_damage(failures: Array[String]) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.shield = 30.0
	var impact: FlightCollisionResult = FlightCollisionResult.new()
	impact.severity = FlightCollisionResult.Severity.HARD
	impact.total_damage = 24.0
	impact.cargo_damage = 12.0
	var damage_result: FlightDamageResult = resources.apply_collision(impact)
	expect_true(
		is_equal_approx(resources.shield, 6.0)
		and is_equal_approx(resources.hull, 100.0)
		and is_equal_approx(resources.cargo_integrity, 100.0)
		and is_equal_approx(damage_result.shield_damage, 24.0)
		and is_zero_approx(damage_result.hull_damage)
		and is_zero_approx(damage_result.cargo_damage),
		"Sufficient shield must absorb collision damage without hull or cargo loss.",
		failures
	)

	var fatal: FlightCollisionResult = FlightCollisionResult.new()
	fatal.severity = FlightCollisionResult.Severity.FATAL
	fatal.should_fail = true
	fatal.total_damage = 1.0
	fatal.cargo_damage = 100.0
	var fatal_result: FlightDamageResult = resources.apply_collision(fatal)
	expect_true(
		is_zero_approx(resources.hull)
		and is_equal_approx(resources.cargo_integrity, 100.0)
		and fatal_result.forced_failure,
		"Fatal impact may force failure but must not bypass remaining shield into cargo.",
		failures
	)


func _test_shield_overflow_scales_hull_and_cargo_damage(
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.shield = 10.0
	var damage_result: FlightDamageResult = resources.apply_flight_damage(
		&"test_overflow",
		24.0,
		12.0
	)
	expect_true(
		is_zero_approx(resources.shield)
		and is_equal_approx(resources.hull, 86.0)
		and is_equal_approx(resources.cargo_integrity, 93.0)
		and is_equal_approx(damage_result.penetration_ratio, 14.0 / 24.0)
		and is_equal_approx(damage_result.hull_damage, 14.0)
		and is_equal_approx(damage_result.cargo_damage, 7.0),
		"Shield break must apply only the penetrated fraction to hull and cargo.",
		failures
	)


func _test_resource_snapshot_is_independent(failures: Array[String]) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.hull = 73.0
	resources.shield = 41.0
	resources.fuel = 62.0
	resources.boost_energy = 28.0
	resources.cargo_integrity = 84.0
	var snapshot: FlightResources = resources.duplicate_state()
	resources.reset()
	expect_true(
		is_equal_approx(snapshot.hull, 73.0)
		and is_equal_approx(snapshot.shield, 41.0)
		and is_equal_approx(snapshot.fuel, 62.0)
		and is_equal_approx(snapshot.boost_energy, 28.0)
		and is_equal_approx(snapshot.cargo_integrity, 84.0),
		"Checkpoint resource snapshots must not alias later runtime mutations.",
		failures
	)


func _test_environment_hazard_uses_the_same_damage_order(
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.shield = 12.0
	var penetrated_result: FlightDamageResult = resources.apply_hazard_damage(
		28.0,
		3.0,
		&"test_hazard"
	)
	expect_true(
		is_zero_approx(resources.shield)
		and is_equal_approx(resources.hull, 84.0)
		and is_equal_approx(resources.cargo_integrity, 100.0 - 3.0 * 16.0 / 28.0)
		and is_equal_approx(penetrated_result.hull_damage, 16.0),
		"Environmental damage must use the same shield overflow ratio.",
		failures
	)

	resources.shield = 0.0
	var unshielded_hull: float = resources.hull
	var unshielded_cargo: float = resources.cargo_integrity
	var unshielded_result: FlightDamageResult = resources.apply_hazard_damage(
		10.0,
		4.0,
		&"test_unshielded_hazard"
	)
	expect_true(
		is_equal_approx(resources.hull, unshielded_hull - 10.0)
		and is_equal_approx(resources.cargo_integrity, unshielded_cargo - 4.0)
		and is_equal_approx(unshielded_result.penetration_ratio, 1.0),
		"Unshielded environmental damage must affect both hull and cargo once.",
		failures
	)


func _test_delivery_cargo_damage_clamps_and_reports(
	failures: Array[String]
) -> void:
	var resources: FlightResources = FlightResources.new()
	resources.cargo_integrity = 4.0
	var applied_damage: float = resources.apply_cargo_damage(9.0)
	expect_true(
		is_equal_approx(applied_damage, 4.0)
		and is_zero_approx(resources.cargo_integrity)
		and is_zero_approx(resources.apply_cargo_damage(-3.0)),
		"Delivery cargo damage must clamp at zero and report only actual loss.",
		failures
	)
