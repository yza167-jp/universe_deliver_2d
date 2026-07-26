class_name WhiteNoiseSettlementContract
extends Resource

## Authoritative T-125 contract for White Noise routing and choice settlement.

@export var id: StringName = &""
@export var order: OrderDefinition
@export var arrival_contract: WhiteNoiseArrivalContract
@export_file("*.tscn") var flight_scene_path: String = ""
@export_file("*.tscn") var arrival_scene_path: String = ""
@export var minimum_index_codex: CodexEntryDefinition
@export var keep_sealed_codex: CodexEntryDefinition
@export var local_custody_codex: CodexEntryDefinition
@export var choice_settled_flag: StringName = &""
@export var archive_terminal_updated_flag: StringName = &""
@export var canopy_precursor_flag: StringName = &""
@export var revisit_state_id: StringName = &""
@export var ending_flag_id: StringName = &""
@export var minimum_index_ending_value: StringName = &""
@export var keep_sealed_ending_value: StringName = &""
@export var local_custody_ending_value: StringName = &""
@export var relation_planet_id: StringName = &""
@export_range(1, 3, 1) var privacy_relation_bonus: int = 1
@export var results_eyebrow_key: StringName = &""
@export var minimum_index_narrative_key: StringName = &""
@export var keep_sealed_narrative_key: StringName = &""
@export var local_custody_narrative_key: StringName = &""
@export var station_change_key: StringName = &""
@export var next_step_key: StringName = &""


func validate(registry: GameDataRegistry) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not M1ProgressRules.is_stable_id(id):
		errors.append("White Noise settlement contract ID is invalid.")
	if (
		registry == null
		or order == null
		or registry.find_order(order.id) != order
		or order.id != GameDataValidator.M1_WHITE_NOISE_ORDER_ID
	):
		errors.append("White Noise settlement contract order is invalid.")
	if (
		arrival_contract == null
		or not arrival_contract.validate().is_empty()
		or (
			order != null
			and arrival_contract.order_id != order.id
		)
	):
		errors.append("White Noise settlement arrival contract is invalid.")
	if (
		flight_scene_path != "res://scenes/flight/white_noise_flight.tscn"
		or arrival_scene_path
		!= "res://scenes/arrival/white_noise_arrival.tscn"
		or not ResourceLoader.exists(flight_scene_path)
		or not ResourceLoader.exists(arrival_scene_path)
	):
		errors.append("White Noise production scene paths are invalid.")
	if (
		order != null
		and (
			order.content_readiness
			!= OrderDefinition.ContentReadiness.PLAYABLE
			or order.destination_planet == null
			or order.destination_planet.content_readiness
			!= PlanetDefinition.ContentReadiness.PLAYABLE
			or order.destination_planet.flight_scene_path != flight_scene_path
			or not is_equal_approx(order.route_distance, 34000.0)
			or order.chapter_reward != M1ProgressRules.CHAPTER_M1_CANOPY_WORLD
			or not order.planet_unlock_rewards.has(
				M1ProgressRules.PLANET_CANOPY_WORLD
			)
			or order.revisit_state_rewards.get(
				M1ProgressRules.PLANET_WHITE_NOISE,
				&""
			) != revisit_state_id
		)
	):
		errors.append("White Noise formal order progression rewards are incomplete.")
	var codex_entries: Array[CodexEntryDefinition] = [
		minimum_index_codex,
		keep_sealed_codex,
		local_custody_codex,
	]
	var codex_ids: Dictionary[StringName, bool] = {}
	for entry: CodexEntryDefinition in codex_entries:
		if (
			entry == null
			or registry == null
			or registry.find_codex_entry(entry.id) != entry
			or entry.category != CodexEntryDefinition.Category.ANOMALY
			or order == null
			or entry.related_planet_id != order.planet_id
			or codex_ids.has(entry.id)
		):
			errors.append(
				"White Noise choice codex entries must be registered and unique."
			)
			break
		codex_ids[entry.id] = true
	var stable_ids: Array[StringName] = [
		choice_settled_flag,
		archive_terminal_updated_flag,
		canopy_precursor_flag,
		revisit_state_id,
		ending_flag_id,
		minimum_index_ending_value,
		keep_sealed_ending_value,
		local_custody_ending_value,
	]
	var seen_ids: Dictionary[StringName, bool] = {}
	for stable_id: StringName in stable_ids:
		if (
			not M1ProgressRules.is_stable_id(stable_id)
			or seen_ids.has(stable_id)
		):
			errors.append(
				"White Noise settlement state IDs must be stable and unique."
			)
			break
		seen_ids[stable_id] = true
	if (
		not M1ProgressRules.is_known_planet(relation_planet_id)
		or order == null
		or relation_planet_id != order.planet_id
		or privacy_relation_bonus <= 0
	):
		errors.append("White Noise choice relation reward is invalid.")
	for key: StringName in [
		results_eyebrow_key,
		minimum_index_narrative_key,
		keep_sealed_narrative_key,
		local_custody_narrative_key,
		station_change_key,
		next_step_key,
	]:
		if key.is_empty():
			errors.append("White Noise settlement presentation key is empty.")
			break
	return errors


func is_white_noise_order(order_id: StringName) -> bool:
	return order != null and order.id == order_id


func is_delivery_ready(game_state: GameStateModel) -> bool:
	return (
		arrival_contract != null
		and arrival_contract.is_delivery_ready(game_state)
	)


func get_choice_codex_rewards(
	game_state: GameStateModel
) -> Array[StringName]:
	var rewards: Array[StringName] = []
	var entry: CodexEntryDefinition = _get_choice_codex(game_state)
	if entry != null:
		rewards.append(entry.id)
	return rewards


func get_choice_relation_rewards(
	game_state: GameStateModel
) -> Dictionary[StringName, int]:
	var rewards: Dictionary[StringName, int] = {}
	if arrival_contract == null:
		return rewards
	var selected_choice: StringName = (
		arrival_contract.get_selected_choice_id(game_state)
	)
	if selected_choice in [
		arrival_contract.keep_sealed_flag,
		arrival_contract.local_custody_flag,
	]:
		rewards[relation_planet_id] = privacy_relation_bonus
	return rewards


func get_demo_ending_flags(
	game_state: GameStateModel
) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	var ending_value: StringName = _get_choice_ending_value(game_state)
	if not ending_value.is_empty():
		flags[ending_flag_id] = ending_value
	return flags


func get_settlement_flags() -> Array[StringName]:
	return [
		choice_settled_flag,
		archive_terminal_updated_flag,
		canopy_precursor_flag,
	]


func get_result_narrative_key(game_state: GameStateModel) -> StringName:
	if arrival_contract == null:
		return &""
	var selected_choice: StringName = (
		arrival_contract.get_selected_choice_id(game_state)
	)
	if selected_choice == arrival_contract.minimum_index_flag:
		return minimum_index_narrative_key
	if selected_choice == arrival_contract.keep_sealed_flag:
		return keep_sealed_narrative_key
	if selected_choice == arrival_contract.local_custody_flag:
		return local_custody_narrative_key
	return &""


func _get_choice_codex(game_state: GameStateModel) -> CodexEntryDefinition:
	if arrival_contract == null:
		return null
	var selected_choice: StringName = (
		arrival_contract.get_selected_choice_id(game_state)
	)
	if selected_choice == arrival_contract.minimum_index_flag:
		return minimum_index_codex
	if selected_choice == arrival_contract.keep_sealed_flag:
		return keep_sealed_codex
	if selected_choice == arrival_contract.local_custody_flag:
		return local_custody_codex
	return null


func _get_choice_ending_value(game_state: GameStateModel) -> StringName:
	if arrival_contract == null:
		return &""
	var selected_choice: StringName = (
		arrival_contract.get_selected_choice_id(game_state)
	)
	if selected_choice == arrival_contract.minimum_index_flag:
		return minimum_index_ending_value
	if selected_choice == arrival_contract.keep_sealed_flag:
		return keep_sealed_ending_value
	if selected_choice == arrival_contract.local_custody_flag:
		return local_custody_ending_value
	return &""
