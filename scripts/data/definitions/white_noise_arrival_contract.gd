class_name WhiteNoiseArrivalContract
extends Resource

## Stable destination contract for the bounded White Noise archive scene.

@export var id: StringName = &""
@export var order_id: StringName = &""
@export var main_dialogue: DialogueSequence
@export var memory_owner_dialogue: DialogueSequence
@export var main_dialogue_completion_flag: StringName = &""
@export var choice_recorded_flag: StringName = &""
@export var minimum_index_flag: StringName = &""
@export var keep_sealed_flag: StringName = &""
@export var local_custody_flag: StringName = &""
@export var memory_owner_dialogue_completion_flag: StringName = &""
@export var relay_record_inspected_flag: StringName = &""


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not M1ProgressRules.is_stable_id(id):
		errors.append("White Noise arrival contract ID is invalid.")
	if order_id != GameDataValidator.M1_WHITE_NOISE_ORDER_ID:
		errors.append("White Noise arrival contract order ID is invalid.")
	if main_dialogue == null or memory_owner_dialogue == null:
		errors.append("White Noise arrival dialogues are incomplete.")
	elif (
		not M1ProgressRules.is_stable_id(main_dialogue.id)
		or not M1ProgressRules.is_stable_id(memory_owner_dialogue.id)
		or main_dialogue.id == memory_owner_dialogue.id
	):
		errors.append("White Noise arrival dialogue IDs must be stable and unique.")
	var state_ids: Array[StringName] = [
		main_dialogue_completion_flag,
		choice_recorded_flag,
		minimum_index_flag,
		keep_sealed_flag,
		local_custody_flag,
		memory_owner_dialogue_completion_flag,
		relay_record_inspected_flag,
	]
	var seen_ids: Dictionary[StringName, bool] = {}
	for state_id: StringName in state_ids:
		if (
			not M1ProgressRules.is_stable_id(state_id)
			or seen_ids.has(state_id)
		):
			errors.append(
				"White Noise arrival story flags must be stable and unique."
			)
			break
		seen_ids[state_id] = true
	return errors


func get_choice_flags() -> Array[StringName]:
	return [
		minimum_index_flag,
		keep_sealed_flag,
		local_custody_flag,
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
		and game_state.has_story_flag(main_dialogue_completion_flag)
		and has_valid_choice(game_state)
	)
