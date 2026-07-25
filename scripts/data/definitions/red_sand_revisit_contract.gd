class_name RedSandRevisitContract
extends Resource

## T-110 data contract for the short Red Sand revisit.
## It describes the future route and story handoff without making it playable.

@export var id: StringName = &""
@export var order: OrderDefinition
@export var arrival_dialogue: DialogueSequence
@export var source_route: FlightRouteDefinition
@export var route_variant_id: StringName = &""
@export var route_entry_checkpoint_id: StringName = &""
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var route_entry_distance: float = 0.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var route_end_distance: float = 0.0
@export_range(1.0, 3600.0, 0.1, "or_greater")
var nominal_route_seconds: float = 1.0
@export var available_state_id: StringName = &""
@export var accepted_state_id: StringName = &""
@export var completed_state_id: StringName = &""
@export var upload_full_record_flag: StringName = &""
@export var keep_local_record_flag: StringName = &""
@export var debug_scenario_id: StringName = &""


func validate(registry: GameDataRegistry) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not M1ProgressRules.is_stable_id(id):
		errors.append("Red Sand revisit contract ID is invalid.")
	if registry == null:
		errors.append("Red Sand revisit contract requires the M1 registry.")
		return errors
	if (
		order == null
		or registry.find_order(order.id) != order
		or order.id
		!= GameDataValidator.M1_RED_SAND_REVISIT_ORDER_ID
	):
		errors.append("Red Sand revisit contract order is invalid.")
	if arrival_dialogue == null:
		errors.append("Red Sand revisit arrival dialogue is missing.")
	if source_route == null or source_route.id != &"route_red_sand_m0":
		errors.append("Red Sand revisit must reuse the validated M0 route source.")
	if not M1ProgressRules.is_stable_id(route_variant_id):
		errors.append("Red Sand revisit route variant ID is invalid.")
	if not M1ProgressRules.is_stable_id(route_entry_checkpoint_id):
		errors.append("Red Sand revisit entry checkpoint ID is invalid.")
	if (
		not is_finite(route_entry_distance)
		or not is_finite(route_end_distance)
		or route_entry_distance < 0.0
		or route_end_distance <= route_entry_distance
		or (
			source_route != null
			and route_end_distance > source_route.get_total_distance()
		)
	):
		errors.append("Red Sand revisit route window is invalid.")
	if not is_finite(nominal_route_seconds) or nominal_route_seconds <= 0.0:
		errors.append("Red Sand revisit nominal route time is invalid.")
	var state_ids: Array[StringName] = [
		available_state_id,
		accepted_state_id,
		completed_state_id,
	]
	var seen_states: Dictionary[StringName, bool] = {}
	for state_id: StringName in state_ids:
		if (
			not M1ProgressRules.is_valid_revisit_state_id(state_id)
			or seen_states.has(state_id)
		):
			errors.append("Red Sand revisit state IDs must be stable and unique.")
			break
		seen_states[state_id] = true
	if (
		not M1ProgressRules.is_stable_id(upload_full_record_flag)
		or not M1ProgressRules.is_stable_id(keep_local_record_flag)
		or upload_full_record_flag == keep_local_record_flag
	):
		errors.append("Red Sand revisit record-choice flags are invalid.")
	if (
		debug_scenario_id
		!= M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT
	):
		errors.append("Red Sand revisit debug scenario ID is invalid.")
	return errors


func get_route_distance() -> float:
	return maxf(route_end_distance - route_entry_distance, 0.0)
