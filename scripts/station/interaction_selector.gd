class_name InteractionSelector
extends RefCounted

const ALIGNMENT_EPSILON: float = 0.0001
const DISTANCE_EPSILON: float = 0.01


## Returns the same winner regardless of candidate discovery order.
## Ranking is priority, facing alignment, distance, then stable ID.
static func select_best(candidates: Array[InteractionCandidate]) -> InteractionCandidate:
	var best: InteractionCandidate = null
	for candidate: InteractionCandidate in candidates:
		if candidate == null:
			continue
		if best == null or _is_better(candidate, best):
			best = candidate
	return best


static func _is_better(candidate: InteractionCandidate, incumbent: InteractionCandidate) -> bool:
	if candidate.priority != incumbent.priority:
		return candidate.priority > incumbent.priority
	var alignment_delta: float = candidate.facing_alignment - incumbent.facing_alignment
	if absf(alignment_delta) > ALIGNMENT_EPSILON:
		return alignment_delta > 0.0
	var distance_delta: float = candidate.distance_squared - incumbent.distance_squared
	if absf(distance_delta) > DISTANCE_EPSILON:
		return distance_delta < 0.0
	return String(candidate.candidate_id) < String(incumbent.candidate_id)
