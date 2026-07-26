class_name WhiteNoiseMainOrderContent
extends Resource

## Order-scoped cockpit presentation for the White Noise mainline shipment.

@export var id: StringName = &""
@export var order: OrderDefinition
@export var cockpit_manual_dialogue: DialogueSequence
@export var cockpit_travel_main_dialogue: DialogueSequence
@export var cockpit_travel_radio_dialogue: DialogueSequence
@export var cockpit_travel_cargo_dialogue: DialogueSequence
@export var cockpit_travel_phase_name_keys: Array[StringName] = []
@export var cockpit_travel_phase_detail_keys: Array[StringName] = []
@export var cockpit_company_note_key: StringName = &""
@export var cockpit_cargo_note_key: StringName = &""
@export var cockpit_travel_completion_flag: StringName = &""


func validate(registry: GameDataRegistry) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not M1ProgressRules.is_stable_id(id):
		errors.append("White Noise main-order content ID is invalid.")
	if (
		registry == null
		or order == null
		or registry.find_order(order.id) != order
		or order.id != GameDataValidator.M1_WHITE_NOISE_ORDER_ID
	):
		errors.append("White Noise main-order content order is invalid.")
	var dialogues: Array[DialogueSequence] = [
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
				"White Noise cockpit dialogues must be present and unique."
			)
			break
		dialogue_ids[dialogue.id] = true
	if (
		cockpit_travel_phase_name_keys.size() != 4
		or cockpit_travel_phase_detail_keys.size() != 4
	):
		errors.append("White Noise cockpit travel presentation is incomplete.")
	else:
		var presentation_keys: Array[StringName] = [
			cockpit_company_note_key,
			cockpit_cargo_note_key,
		]
		presentation_keys.append_array(cockpit_travel_phase_name_keys)
		presentation_keys.append_array(cockpit_travel_phase_detail_keys)
		for key: StringName in presentation_keys:
			if key.is_empty():
				errors.append(
					"White Noise cockpit presentation contains an empty key."
				)
				break
	if not M1ProgressRules.is_stable_id(cockpit_travel_completion_flag):
		errors.append("White Noise cockpit completion flag is invalid.")
	return errors


func is_main_order(order_id: StringName) -> bool:
	return order != null and order.id == order_id


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
