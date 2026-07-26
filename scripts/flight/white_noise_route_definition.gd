class_name WhiteNoiseRouteDefinition
extends FlightRouteDefinition

const REQUIRED_BRANCH_IDS: Array[StringName] = [
	&"white_noise_fast",
	&"white_noise_balanced",
	&"white_noise_scenic",
]

@export var branches: Array[WhiteNoiseRouteBranch] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = super.validate()
	if branches.size() != REQUIRED_BRANCH_IDS.size():
		errors.append("White Noise route must expose exactly three local branches.")
		return errors
	var seen: Dictionary[StringName, bool] = {}
	var shared_split: float = -1.0
	var shared_join: float = -1.0
	for branch: WhiteNoiseRouteBranch in branches:
		if branch == null:
			errors.append("White Noise route contains a missing branch.")
			continue
		errors.append_array(branch.validate())
		if seen.get(branch.id, false):
			errors.append("White Noise route repeats branch '%s'." % branch.id)
		seen[branch.id] = true
		if shared_split < 0.0:
			shared_split = branch.split_distance
			shared_join = branch.join_distance
		elif (
			not is_equal_approx(branch.split_distance, shared_split)
			or not is_equal_approx(branch.join_distance, shared_join)
		):
			errors.append("White Noise branches must share one split and join window.")
	for required_id: StringName in REQUIRED_BRANCH_IDS:
		if not seen.get(required_id, false):
			errors.append("White Noise route is missing branch '%s'." % required_id)
	if (
		shared_split < 0.0
		or shared_join > get_total_distance()
		or get_segment_index(shared_split) != get_segment_index(shared_join - 0.01)
	):
		errors.append("White Noise branch window must stay inside one route segment.")
	return errors


func get_branch(branch_id: StringName) -> WhiteNoiseRouteBranch:
	for branch: WhiteNoiseRouteBranch in branches:
		if branch != null and branch.id == branch_id:
			return branch
	return null


func choose_branch(ship_y: float) -> WhiteNoiseRouteBranch:
	for branch: WhiteNoiseRouteBranch in branches:
		if branch != null and branch.contains_lane_y(ship_y):
			return branch
	return get_branch(&"white_noise_balanced")


func get_branch_split_distance() -> float:
	return 0.0 if branches.is_empty() else branches[0].split_distance


func get_branch_join_distance() -> float:
	return 0.0 if branches.is_empty() else branches[0].join_distance
