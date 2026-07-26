class_name WhiteNoiseSideOrderContract
extends Resource

## Authoritative T-126 contract for the optional returned-memory side order.

@export var id: StringName = &""
@export var order: OrderDefinition
@export var arrival_dialogue: DialogueSequence
@export var cockpit_manual_dialogue: DialogueSequence
@export var cockpit_travel_main_dialogue: DialogueSequence
@export var cockpit_travel_radio_dialogue: DialogueSequence
@export var cockpit_travel_cargo_dialogue: DialogueSequence
@export var cockpit_travel_phase_name_keys: Array[StringName] = []
@export var cockpit_travel_phase_detail_keys: Array[StringName] = []
@export var cockpit_company_note_key: StringName = &""
@export var cockpit_cargo_note_key: StringName = &""
@export var cockpit_travel_completion_flag: StringName = &""
@export_file("*.tscn") var flight_scene_path: String = ""
@export_file("*.tscn") var arrival_scene_path: String = ""
@export_range(0, 5, 1) var route_start_segment_index: int = 3
@export_range(0.0, 100000.0, 1.0) var route_start_distance: float = 17000.0
@export var arrival_dialogue_completion_flag: StringName = &""
@export var choice_recorded_flag: StringName = &""
@export var keep_private_flag: StringName = &""
@export var anonymous_index_flag: StringName = &""
@export var local_original_flag: StringName = &""
@export var choice_settled_flag: StringName = &""
@export var ending_flag_id: StringName = &""
@export var keep_private_ending_value: StringName = &""
@export var anonymous_index_ending_value: StringName = &""
@export var local_original_ending_value: StringName = &""
@export var relation_planet_id: StringName = &""
@export_range(0.0, 100.0, 1.0) var relation_integrity_threshold: float = 70.0
@export_range(1, 3, 1) var damaged_relation_penalty: int = 1
@export var results_eyebrow_key: StringName = &""
@export var keep_private_narrative_key: StringName = &""
@export var anonymous_index_narrative_key: StringName = &""
@export var local_original_narrative_key: StringName = &""
@export var cargo_intact_key: StringName = &""
@export var cargo_damaged_key: StringName = &""
@export var station_change_key: StringName = &""
@export var next_step_key: StringName = &""


func validate(
	registry: GameDataRegistry,
	route_definition: WhiteNoiseRouteDefinition = null
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not M1ProgressRules.is_stable_id(id):
		errors.append("White Noise side-order contract ID is invalid.")
	if (
		registry == null
		or order == null
		or registry.find_order(order.id) != order
		or order.id != GameDataValidator.M1_WHITE_NOISE_SIDE_ORDER_ID
		or order.order_type != OrderDefinition.OrderType.SIDE
		or not order.is_playable()
	):
		errors.append("White Noise side-order contract order is invalid.")
	if (
		flight_scene_path != "res://scenes/flight/white_noise_flight.tscn"
		or arrival_scene_path != "res://scenes/arrival/white_noise_arrival.tscn"
		or not ResourceLoader.exists(flight_scene_path, "PackedScene")
		or not ResourceLoader.exists(arrival_scene_path, "PackedScene")
	):
		errors.append("White Noise side-order scene paths are invalid.")
	if route_definition != null:
		if (
			route_start_segment_index < 0
			or route_start_segment_index >= route_definition.segments.size()
			or not is_equal_approx(
				route_definition.segments[
					route_start_segment_index
				].start_distance,
				route_start_distance
			)
			or order == null
			or not is_equal_approx(
				order.route_distance,
				route_definition.get_total_distance() - route_start_distance
			)
		):
			errors.append(
				"White Noise side order must reuse a valid shortened main-route window."
			)
	var dialogues: Array[DialogueSequence] = [
		arrival_dialogue,
		cockpit_manual_dialogue,
		cockpit_travel_main_dialogue,
		cockpit_travel_radio_dialogue,
		cockpit_travel_cargo_dialogue,
	]
	var dialogue_ids: Dictionary[StringName, bool] = {}
	for dialogue: DialogueSequence in dialogues:
		if (
			dialogue == null
			or not M1ProgressRules.is_stable_id(dialogue.id)
			or dialogue_ids.has(dialogue.id)
		):
			errors.append(
				"White Noise side-order dialogues must be present and unique."
			)
			break
		dialogue_ids[dialogue.id] = true
	if (
		cockpit_travel_phase_name_keys.size() != 4
		or cockpit_travel_phase_detail_keys.size() != 4
	):
		errors.append(
			"White Noise side-order cockpit travel presentation is incomplete."
		)
	var presentation_keys: Array[StringName] = [
		cockpit_company_note_key,
		cockpit_cargo_note_key,
		results_eyebrow_key,
		keep_private_narrative_key,
		anonymous_index_narrative_key,
		local_original_narrative_key,
		cargo_intact_key,
		cargo_damaged_key,
		station_change_key,
		next_step_key,
	]
	presentation_keys.append_array(cockpit_travel_phase_name_keys)
	presentation_keys.append_array(cockpit_travel_phase_detail_keys)
	for key: StringName in presentation_keys:
		if key.is_empty():
			errors.append(
				"White Noise side-order presentation contains an empty key."
			)
			break
	var state_ids: Array[StringName] = [
		cockpit_travel_completion_flag,
		arrival_dialogue_completion_flag,
		choice_recorded_flag,
		keep_private_flag,
		anonymous_index_flag,
		local_original_flag,
		choice_settled_flag,
		ending_flag_id,
		keep_private_ending_value,
		anonymous_index_ending_value,
		local_original_ending_value,
	]
	var seen_ids: Dictionary[StringName, bool] = {}
	for state_id: StringName in state_ids:
		if (
			not M1ProgressRules.is_stable_id(state_id)
			or seen_ids.has(state_id)
		):
			errors.append(
				"White Noise side-order state IDs must be stable and unique."
			)
			break
		seen_ids[state_id] = true
	if (
		not M1ProgressRules.is_known_planet(relation_planet_id)
		or order == null
		or relation_planet_id != order.planet_id
		or relation_integrity_threshold <= 0.0
		or relation_integrity_threshold >= 100.0
		or damaged_relation_penalty <= 0
		or order.relation_rewards.get(relation_planet_id, 0)
		< damaged_relation_penalty
	):
		errors.append("White Noise side-order relation tuning is invalid.")
	return errors


func is_side_order(order_id: StringName) -> bool:
	return order != null and order.id == order_id


func get_choice_flags() -> Array[StringName]:
	return [
		keep_private_flag,
		anonymous_index_flag,
		local_original_flag,
	]


func get_selected_choice_id(game_state: GameStateModel) -> StringName:
	if game_state == null:
		return &""
	var selected_flag: StringName = &""
	for choice_flag: StringName in get_choice_flags():
		if not game_state.has_story_flag(choice_flag):
			continue
		if not selected_flag.is_empty():
			return &""
		selected_flag = choice_flag
	return selected_flag


func has_valid_choice(game_state: GameStateModel) -> bool:
	return (
		game_state != null
		and game_state.has_story_flag(choice_recorded_flag)
		and not get_selected_choice_id(game_state).is_empty()
	)


func is_delivery_ready(game_state: GameStateModel) -> bool:
	return (
		game_state != null
		and game_state.has_story_flag(arrival_dialogue_completion_flag)
		and has_valid_choice(game_state)
	)


func is_cargo_relation_penalized(cargo_integrity: float) -> bool:
	return cargo_integrity < relation_integrity_threshold


func get_choice_relation_rewards(
	run_state: OrderRunState
) -> Dictionary[StringName, int]:
	var rewards: Dictionary[StringName, int] = {}
	if (
		run_state != null
		and is_cargo_relation_penalized(run_state.cargo_integrity)
	):
		rewards[relation_planet_id] = -damaged_relation_penalty
	return rewards


func get_settlement_flags() -> Array[StringName]:
	return [choice_settled_flag]


func get_demo_ending_flags(
	game_state: GameStateModel
) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	var ending_value: StringName = get_choice_ending_value(game_state)
	if not ending_value.is_empty():
		flags[ending_flag_id] = ending_value
	return flags


func get_choice_ending_value(game_state: GameStateModel) -> StringName:
	var selected_choice: StringName = get_selected_choice_id(game_state)
	if selected_choice == keep_private_flag:
		return keep_private_ending_value
	if selected_choice == anonymous_index_flag:
		return anonymous_index_ending_value
	if selected_choice == local_original_flag:
		return local_original_ending_value
	return &""


func get_result_narrative_key(game_state: GameStateModel) -> StringName:
	var selected_choice: StringName = get_selected_choice_id(game_state)
	if selected_choice == keep_private_flag:
		return keep_private_narrative_key
	if selected_choice == anonymous_index_flag:
		return anonymous_index_narrative_key
	if selected_choice == local_original_flag:
		return local_original_narrative_key
	return &""


func get_cockpit_travel_phase_name_key(
	phase: GameStateModel.TravelState
) -> StringName:
	return _get_phase_key(cockpit_travel_phase_name_keys, phase)


func get_cockpit_travel_phase_detail_key(
	phase: GameStateModel.TravelState
) -> StringName:
	return _get_phase_key(cockpit_travel_phase_detail_keys, phase)


func _get_phase_key(
	keys: Array[StringName],
	phase: GameStateModel.TravelState
) -> StringName:
	var index: int = -1
	match phase:
		GameStateModel.TravelState.DEPARTURE:
			index = 0
		GameStateModel.TravelState.CRUISE:
			index = 1
		GameStateModel.TravelState.APPROACH:
			index = 2
		GameStateModel.TravelState.COMPLETED:
			index = 3
	return &"" if index < 0 or index >= keys.size() else keys[index]
