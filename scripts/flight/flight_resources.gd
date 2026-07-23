class_name FlightResources
extends RefCounted

const MAX_RESOURCE_VALUE: float = 100.0

var hull: float = MAX_RESOURCE_VALUE
var shield: float = MAX_RESOURCE_VALUE
var fuel: float = MAX_RESOURCE_VALUE
var boost_energy: float = MAX_RESOURCE_VALUE
var cargo_integrity: float = MAX_RESOURCE_VALUE
var propulsion_fuel_cost_rate: float = 0.0
var boost_energy_cost_rate: float = 0.0
var boost_recovery_rate: float = 0.0

var _boost_recovery_delay_remaining: float = 0.0


func reset() -> void:
	hull = MAX_RESOURCE_VALUE
	shield = MAX_RESOURCE_VALUE
	fuel = MAX_RESOURCE_VALUE
	boost_energy = MAX_RESOURCE_VALUE
	cargo_integrity = MAX_RESOURCE_VALUE
	clear_telemetry()
	_boost_recovery_delay_remaining = 0.0


func duplicate_state() -> FlightResources:
	var copy: FlightResources = FlightResources.new()
	copy.restore_from(self)
	return copy


func restore_from(source: FlightResources) -> void:
	if source == null:
		reset()
		return
	hull = clampf(source.hull, 0.0, MAX_RESOURCE_VALUE)
	shield = clampf(source.shield, 0.0, MAX_RESOURCE_VALUE)
	fuel = clampf(source.fuel, 0.0, MAX_RESOURCE_VALUE)
	boost_energy = clampf(source.boost_energy, 0.0, MAX_RESOURCE_VALUE)
	cargo_integrity = clampf(source.cargo_integrity, 0.0, MAX_RESOURCE_VALUE)
	propulsion_fuel_cost_rate = maxf(source.propulsion_fuel_cost_rate, 0.0)
	boost_energy_cost_rate = maxf(source.boost_energy_cost_rate, 0.0)
	boost_recovery_rate = maxf(source.boost_recovery_rate, 0.0)
	_boost_recovery_delay_remaining = maxf(
		source._boost_recovery_delay_remaining,
		0.0
	)


## Advances fuel and Boost while returning effective throttle and Boost inputs.
func step_propulsion(
	requested_throttle: float,
	requested_boost: float,
	assist_fuel_cost_rate: float,
	boost_policy: int,
	block_boost_recovery: bool,
	tuning: FlightTuning,
	delta: float,
	block_boost_activation: bool = false
) -> Vector2:
	clear_telemetry()
	var safe_throttle: float = clampf(requested_throttle, 0.0, 1.0)
	var safe_boost: float = 0.0 if block_boost_activation else clampf(
		requested_boost,
		0.0,
		1.0
	)
	if tuning == null or delta <= 0.0:
		return Vector2(safe_throttle, 0.0)

	var effective_throttle: float = safe_throttle
	if fuel <= 0.0:
		effective_throttle *= clampf(tuning.emergency_thrust_multiplier, 0.0, 1.0)

	var effective_boost: float = 0.0
	if fuel > 0.0 and boost_energy > 0.0:
		effective_boost = safe_boost * _get_boost_policy_cap(boost_policy, tuning)
		var energy_cost_per_input: float = maxf(
			tuning.boost_energy_cost_per_second,
			0.0
		) * delta
		if energy_cost_per_input > 0.0:
			effective_boost = minf(
				effective_boost,
				boost_energy / energy_cost_per_input
			)

	var paid_throttle: float = safe_throttle if fuel > 0.0 else 0.0
	propulsion_fuel_cost_rate = (
		paid_throttle * maxf(tuning.thrust_fuel_cost_per_second, 0.0)
		+ effective_boost * maxf(tuning.boost_fuel_cost_per_second, 0.0)
		+ maxf(assist_fuel_cost_rate, 0.0)
	)
	boost_energy_cost_rate = (
		effective_boost * maxf(tuning.boost_energy_cost_per_second, 0.0)
	)
	fuel = maxf(fuel - propulsion_fuel_cost_rate * delta, 0.0)
	boost_energy = maxf(boost_energy - boost_energy_cost_rate * delta, 0.0)

	if effective_boost > 0.0:
		_boost_recovery_delay_remaining = maxf(
			tuning.boost_recovery_delay_seconds,
			0.0
		)
	else:
		_boost_recovery_delay_remaining = maxf(
			_boost_recovery_delay_remaining - delta,
			0.0
		)
		if not block_boost_recovery and _boost_recovery_delay_remaining <= 0.0:
			boost_recovery_rate = maxf(
				tuning.boost_energy_recovery_per_second,
				0.0
			)
			boost_energy = minf(
				boost_energy + boost_recovery_rate * delta,
				MAX_RESOURCE_VALUE
			)

	return Vector2(effective_throttle, effective_boost)


func apply_collision(result: FlightCollisionResult) -> FlightDamageResult:
	if result == null or not result.is_impact():
		return FlightDamageResult.new()
	var damage_result: FlightDamageResult = apply_flight_damage(
		&"flight_collision",
		result.total_damage,
		result.cargo_damage
	)
	damage_result.forced_failure = result.should_fail
	if result.should_fail and hull > 0.0:
		damage_result.hull_damage += hull
		hull = 0.0
	return damage_result


func apply_hazard_damage(
	total_damage: float,
	hazard_cargo_damage: float = 0.0,
	source: StringName = &"flight_environment"
) -> FlightDamageResult:
	return apply_flight_damage(source, total_damage, hazard_cargo_damage)


## Settles every ordinary flight hit shield-first; cargo receives only penetrated loss.
func apply_flight_damage(
	source: StringName,
	base_damage: float,
	full_penetration_cargo_damage: float
) -> FlightDamageResult:
	var result: FlightDamageResult = FlightDamageResult.new()
	result.source = source
	result.requested_damage = maxf(base_damage, 0.0)
	result.requested_cargo_damage = maxf(full_penetration_cargo_damage, 0.0)
	if result.requested_damage <= 0.0:
		return result

	result.shield_damage = minf(shield, result.requested_damage)
	shield = maxf(shield - result.shield_damage, 0.0)
	var overflow_damage: float = maxf(
		result.requested_damage - result.shield_damage,
		0.0
	)
	result.penetration_ratio = clampf(
		overflow_damage / result.requested_damage,
		0.0,
		1.0
	)
	result.hull_damage = minf(hull, overflow_damage)
	hull = maxf(hull - result.hull_damage, 0.0)
	result.cargo_damage = apply_cargo_damage(
		result.requested_cargo_damage * result.penetration_ratio
	)
	return result


func apply_cargo_damage(applied_cargo_damage: float) -> float:
	var previous_integrity: float = cargo_integrity
	cargo_integrity = maxf(
		cargo_integrity - maxf(applied_cargo_damage, 0.0),
		0.0
	)
	return previous_integrity - cargo_integrity


func clear_telemetry() -> void:
	propulsion_fuel_cost_rate = 0.0
	boost_energy_cost_rate = 0.0
	boost_recovery_rate = 0.0


static func _get_boost_policy_cap(
	boost_policy: int,
	tuning: FlightTuning
) -> float:
	match boost_policy:
		CargoDefinition.BoostPolicy.FORBIDDEN:
			return 0.0
		CargoDefinition.BoostPolicy.LIMITED:
			return clampf(tuning.limited_cargo_boost_cap, 0.0, 1.0)
	return 1.0
