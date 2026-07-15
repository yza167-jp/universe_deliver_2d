class_name InteractionCandidate
extends RefCounted

var candidate_id: StringName
var priority: int
var distance_squared: float
var facing_alignment: float
var payload: Variant


func _init(
	new_candidate_id: StringName,
	new_priority: int,
	new_distance_squared: float,
	new_facing_alignment: float,
	new_payload: Variant = null
) -> void:
	candidate_id = new_candidate_id
	priority = new_priority
	distance_squared = maxf(new_distance_squared, 0.0)
	facing_alignment = clampf(new_facing_alignment, -1.0, 1.0)
	payload = new_payload
