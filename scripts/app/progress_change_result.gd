class_name ProgressChangeResult
extends RefCounted

## Typed outcome for one atomic persistent progress operation.
var success: bool = false
var changed: bool = false
var reason_key: StringName = &""
var previous_value: Variant
var current_value: Variant


static func accepted(
	did_change: bool,
	previous: Variant,
	current: Variant,
	reason: StringName = &""
) -> ProgressChangeResult:
	var result: ProgressChangeResult = ProgressChangeResult.new()
	result.success = true
	result.changed = did_change
	result.reason_key = reason
	result.previous_value = previous
	result.current_value = current
	return result


static func rejected(
	reason: StringName,
	previous: Variant,
	current: Variant
) -> ProgressChangeResult:
	var result: ProgressChangeResult = ProgressChangeResult.new()
	result.reason_key = reason
	result.previous_value = previous
	result.current_value = current
	return result
