class_name OrderSettlementResult
extends RefCounted

var order_id: StringName = &""
var base_reward: int = 0
var cargo_adjustment: int = 0
var cargo_adjusted_reward: int = 0
var is_express: bool = false
var elapsed_time: float = 0.0
var target_seconds: float = 0.0
var timing_status: StringName = M1OrderRules.TIMING_STATUS_NONE
var reward_ratio: float = 1.0
var time_adjustment: int = 0
var earned_on_time_relation_bonus: bool = false
var on_time_relation_bonus: int = 0
var total_reward: int = 0
var cargo_integrity: float = 0.0
var entry_style: StringName = &""
var landing_result: StringName = &""
var narrative_result: StringName = &""
