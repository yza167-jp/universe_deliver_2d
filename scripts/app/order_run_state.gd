class_name OrderRunState
extends RefCounted

const DEFAULT_RESOURCE_VALUE: float = 100.0
const LANDING_RESULT_NONE: StringName = &""
const LANDING_RESULT_SMOOTH: StringName = &"landing_smooth"
const LANDING_RESULT_ROUGH: StringName = &"landing_rough"

var order_id: StringName = &""
var cargo_integrity: float = DEFAULT_RESOURCE_VALUE
var hull: float = DEFAULT_RESOURCE_VALUE
var shield: float = DEFAULT_RESOURCE_VALUE
var fuel: float = DEFAULT_RESOURCE_VALUE
var boost_energy: float = DEFAULT_RESOURCE_VALUE
var active_checkpoint_id: StringName = &""
var entry_style: StringName = &""
var entry_duration: float = 0.0
var max_downward_speed: float = 0.0
var max_total_speed: float = 0.0
var max_risk_or_heat: float = 0.0
var scenic_trigger_count: int = 0
var late_pull_up_detected: bool = false
var collision_count: int = 0
var landing_result: StringName = LANDING_RESULT_NONE
var landing_cargo_damage: float = 0.0
var elapsed_time: float = 0.0
var optional_trigger_ids: Array[StringName] = []
var result_tags: Array[StringName] = []


func reset(requested_order_id: StringName = &"") -> void:
	order_id = requested_order_id
	cargo_integrity = DEFAULT_RESOURCE_VALUE
	hull = DEFAULT_RESOURCE_VALUE
	shield = DEFAULT_RESOURCE_VALUE
	fuel = DEFAULT_RESOURCE_VALUE
	boost_energy = DEFAULT_RESOURCE_VALUE
	active_checkpoint_id = &""
	elapsed_time = 0.0
	landing_result = LANDING_RESULT_NONE
	landing_cargo_damage = 0.0
	result_tags.clear()
	reset_entry_result()


func reset_entry_result() -> void:
	entry_style = &""
	entry_duration = 0.0
	max_downward_speed = 0.0
	max_total_speed = 0.0
	max_risk_or_heat = 0.0
	scenic_trigger_count = 0
	late_pull_up_detected = false
	collision_count = 0
	optional_trigger_ids.clear()


func record_landing_result(result_id: StringName, cargo_damage: float) -> bool:
	if result_id not in [LANDING_RESULT_SMOOTH, LANDING_RESULT_ROUGH]:
		return false
	landing_result = result_id
	landing_cargo_damage = maxf(cargo_damage, 0.0)
	if not result_tags.has(result_id):
		result_tags.append(result_id)
	return true
