class_name RedSandRevisitContract
extends Resource

## Authoritative data contract for the short playable Red Sand revisit.

@export var id: StringName = &""
@export var order: OrderDefinition
@export var arrival_dialogue: DialogueSequence
@export var optional_dialogue: DialogueSequence
@export var cockpit_manual_dialogue: DialogueSequence
@export var cockpit_travel_main_dialogue: DialogueSequence
@export var cockpit_travel_radio_dialogue: DialogueSequence
@export var cockpit_travel_cargo_dialogue: DialogueSequence
@export var source_route: FlightRouteDefinition
@export var route_variant_id: StringName = &""
@export var route_entry_checkpoint_id: StringName = &""
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var route_entry_distance: float = 0.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var route_end_distance: float = 0.0
@export_range(1.0, 3600.0, 0.1, "or_greater")
var nominal_route_seconds: float = 1.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var changed_facility_route_distance: float = 0.0
@export var route_stage_display_name_keys: Array[StringName] = []
@export var route_stage_instruction_keys: Array[StringName] = []
@export var route_hud_stage_format_key: StringName = &""
@export var cockpit_travel_phase_name_keys: Array[StringName] = []
@export var cockpit_travel_phase_detail_keys: Array[StringName] = []
@export var cockpit_company_note_key: StringName = &""
@export var cockpit_cargo_note_key: StringName = &""
@export var cockpit_travel_completion_flag: StringName = &""
@export var flight_landing_smooth_key: StringName = &""
@export var flight_landing_rough_key: StringName = &""
@export var arrival_landing_smooth_key: StringName = &""
@export var arrival_landing_rough_key: StringName = &""
@export var arrival_technician_prompt_key: StringName = &""
@export var arrival_record_prompt_key: StringName = &""
@export var arrival_return_prompt_key: StringName = &""
@export var arrival_cooling_prompt_key: StringName = &""
@export var available_state_id: StringName = &""
@export var accepted_state_id: StringName = &""
@export var completed_state_id: StringName = &""
@export var upload_full_record_flag: StringName = &""
@export var keep_local_record_flag: StringName = &""
@export var completion_dialogue_flag: StringName = &""
@export var optional_dialogue_completion_flag: StringName = &""
@export var record_choice_relation_planet_id: StringName = &""
@export_range(0, 10, 1, "or_greater") var keep_local_relation_bonus: int = 0
@export var auto_equip_module_id: StringName = &""
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
	if optional_dialogue == null:
		errors.append("Red Sand revisit optional dialogue is missing.")
	var cockpit_dialogues: Array[DialogueSequence] = [
		cockpit_manual_dialogue,
		cockpit_travel_main_dialogue,
		cockpit_travel_radio_dialogue,
		cockpit_travel_cargo_dialogue,
	]
	var cockpit_dialogue_ids: Dictionary[StringName, bool] = {}
	for dialogue: DialogueSequence in cockpit_dialogues:
		if (
			dialogue == null
			or not M1ProgressRules.is_stable_id(dialogue.id)
			or cockpit_dialogue_ids.has(dialogue.id)
		):
			errors.append(
				"Red Sand revisit cockpit dialogues must be present and unique."
			)
			break
		cockpit_dialogue_ids[dialogue.id] = true
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
	if (
		not is_finite(changed_facility_route_distance)
		or changed_facility_route_distance < route_entry_distance
		or changed_facility_route_distance >= route_end_distance
	):
		errors.append("Red Sand revisit changed-facility distance is invalid.")
	var route_segment_count: int = get_route_segment_count()
	if (
		route_segment_count <= 0
		or route_stage_display_name_keys.size() != route_segment_count
		or route_stage_instruction_keys.size() != route_segment_count
	):
		errors.append("Red Sand revisit route-stage localization is incomplete.")
	else:
		for key: StringName in (
			route_stage_display_name_keys + route_stage_instruction_keys
		):
			if key.is_empty():
				errors.append("Red Sand revisit route-stage localization key is empty.")
				break
	if (
		route_hud_stage_format_key.is_empty()
		or cockpit_travel_phase_name_keys.size() != 4
		or cockpit_travel_phase_detail_keys.size() != 4
	):
		errors.append("Red Sand revisit cockpit and route presentation is incomplete.")
	else:
		var presentation_keys: Array[StringName] = [
			route_hud_stage_format_key,
			cockpit_company_note_key,
			cockpit_cargo_note_key,
			flight_landing_smooth_key,
			flight_landing_rough_key,
			arrival_landing_smooth_key,
			arrival_landing_rough_key,
			arrival_technician_prompt_key,
			arrival_record_prompt_key,
			arrival_return_prompt_key,
			arrival_cooling_prompt_key,
		]
		presentation_keys.append_array(cockpit_travel_phase_name_keys)
		presentation_keys.append_array(cockpit_travel_phase_detail_keys)
		for key: StringName in presentation_keys:
			if key.is_empty():
				errors.append(
					"Red Sand revisit presentation contains an empty key."
				)
				break
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
	if not M1ProgressRules.is_stable_id(completion_dialogue_flag):
		errors.append("Red Sand revisit completion dialogue flag is invalid.")
	if not M1ProgressRules.is_stable_id(optional_dialogue_completion_flag):
		errors.append("Red Sand revisit optional dialogue completion flag is invalid.")
	if not M1ProgressRules.is_stable_id(cockpit_travel_completion_flag):
		errors.append("Red Sand revisit cockpit travel completion flag is invalid.")
	if (
		not M1ProgressRules.is_known_planet(record_choice_relation_planet_id)
		or order == null
		or record_choice_relation_planet_id != order.planet_id
		or keep_local_relation_bonus <= 0
	):
		errors.append("Red Sand revisit choice relation reward is invalid.")
	var auto_equip_module: ShipModuleDefinition = registry.find_module(
		auto_equip_module_id
	)
	if (
		auto_equip_module == null
		or order == null
		or not order.ship_upgrade_rewards.has(auto_equip_module_id)
		or not ShipLoadoutRules.is_valid_slot_id(
			ShipLoadoutRules.get_configuration_slot_id(auto_equip_module)
		)
	):
		errors.append("Red Sand revisit auto-equipped reward module is invalid.")
	if (
		debug_scenario_id
		!= M1DebugScenarioCatalog.SCENARIO_RED_SAND_REVISIT
	):
		errors.append("Red Sand revisit debug scenario ID is invalid.")
	return errors


func get_route_distance() -> float:
	return maxf(route_end_distance - route_entry_distance, 0.0)


func get_route_segment_count() -> int:
	if source_route == null or source_route.segments.is_empty():
		return 0
	var entry_index: int = source_route.get_segment_index(route_entry_distance)
	var end_index: int = source_route.get_segment_index(
		maxf(route_end_distance - 0.001, route_entry_distance)
	)
	return maxi(end_index - entry_index + 1, 0)


func get_local_stage_index(source_segment_index: int) -> int:
	if source_route == null:
		return 0
	return maxi(
		source_segment_index
		- source_route.get_segment_index(route_entry_distance),
		0
	)


func get_stage_display_name_key(source_segment_index: int) -> StringName:
	var local_index: int = get_local_stage_index(source_segment_index)
	if local_index < 0 or local_index >= route_stage_display_name_keys.size():
		return &""
	return route_stage_display_name_keys[local_index]


func get_stage_instruction_key(source_segment_index: int) -> StringName:
	var local_index: int = get_local_stage_index(source_segment_index)
	if local_index < 0 or local_index >= route_stage_instruction_keys.size():
		return &""
	return route_stage_instruction_keys[local_index]


func get_cockpit_travel_phase_name_key(
	phase: GameStateModel.TravelState
) -> StringName:
	var index: int = _get_cockpit_travel_phase_index(phase)
	if index < 0 or index >= cockpit_travel_phase_name_keys.size():
		return &""
	return cockpit_travel_phase_name_keys[index]


func get_cockpit_travel_phase_detail_key(
	phase: GameStateModel.TravelState
) -> StringName:
	var index: int = _get_cockpit_travel_phase_index(phase)
	if index < 0 or index >= cockpit_travel_phase_detail_keys.size():
		return &""
	return cockpit_travel_phase_detail_keys[index]


func is_revisit_order(order_id: StringName) -> bool:
	return order != null and order_id == order.id


func has_valid_record_choice(game_state: GameStateModel) -> bool:
	if game_state == null:
		return false
	var uploaded: bool = game_state.has_story_flag(upload_full_record_flag)
	var kept_local: bool = game_state.has_story_flag(keep_local_record_flag)
	return uploaded != kept_local


func is_delivery_ready(game_state: GameStateModel) -> bool:
	return (
		game_state != null
		and game_state.has_story_flag(completion_dialogue_flag)
		and has_valid_record_choice(game_state)
	)


func get_choice_relation_rewards(
	game_state: GameStateModel
) -> Dictionary[StringName, int]:
	var rewards: Dictionary[StringName, int] = {}
	if (
		has_valid_record_choice(game_state)
		and game_state.has_story_flag(keep_local_record_flag)
	):
		rewards[record_choice_relation_planet_id] = keep_local_relation_bonus
	return rewards


func _get_cockpit_travel_phase_index(
	phase: GameStateModel.TravelState
) -> int:
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			return 0
		GameStateModel.TravelState.CRUISE:
			return 1
		GameStateModel.TravelState.APPROACH:
			return 2
		GameStateModel.TravelState.COMPLETED:
			return 3
	return -1
