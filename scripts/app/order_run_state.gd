class_name OrderRunState
extends RefCounted

const DEFAULT_RESOURCE_VALUE: float = 100.0

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
