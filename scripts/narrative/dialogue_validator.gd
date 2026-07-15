class_name DialogueValidator
extends RefCounted

const DEFINITION_ID_PATTERN: String = "^[a-z][a-z0-9_]*$"


static func validate(
	sequence: DialogueSequence,
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray
) -> PackedStringArray:
	var errors: PackedStringArray = []
	if sequence == null:
		return PackedStringArray(["DialogueSequence is missing."])
	if catalog == null:
		return PackedStringArray(["LocalizationCatalog is missing."])
	for catalog_error: String in catalog.errors:
		errors.append(catalog_error)

	_validate_id("DialogueSequence", sequence.id, errors)
	var known_line_ids: Dictionary[StringName, bool] = {}
	for index: int in sequence.lines.size():
		var line: DialogueLine = sequence.lines[index]
		if line == null:
			errors.append("DialogueSequence '%s' line %d is missing." % [sequence.id, index])
			continue
		_validate_id("DialogueLine", line.id, errors)
		if known_line_ids.has(line.id):
			errors.append("DialogueSequence '%s' repeats line ID '%s'." % [sequence.id, line.id])
		else:
			known_line_ids[line.id] = true

	if sequence.start_line_id.is_empty():
		errors.append("DialogueSequence '%s' start_line_id is empty." % sequence.id)
	elif not known_line_ids.has(sequence.start_line_id):
		errors.append(
			"DialogueSequence '%s' start_line_id references missing line '%s'."
			% [sequence.id, sequence.start_line_id]
		)

	for line: DialogueLine in sequence.lines:
		if line == null:
			continue
		_validate_line(sequence, line, known_line_ids, catalog, required_locales, errors)
	return errors


static func _validate_line(
	sequence: DialogueSequence,
	line: DialogueLine,
	known_line_ids: Dictionary[StringName, bool],
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray,
	errors: PackedStringArray
) -> void:
	var label: String = "DialogueSequence '%s' line '%s'" % [sequence.id, line.id]
	if line.speaker == null:
		errors.append("%s has no speaker." % label)
	else:
		_validate_text_key(
			"%s speaker display_name_key" % label,
			line.speaker.display_name_key,
			catalog,
			required_locales,
			errors
		)
	_validate_text_key("%s text_key" % label, line.text_key, catalog, required_locales, errors)
	if line.portrait_expression.is_empty():
		errors.append("%s portrait_expression is empty." % label)
	_validate_conditions(label, line.conditions, errors)
	_validate_effects(label, line.effects, errors)
	_validate_line_reference(label, "next_line_id", line.next_line_id, known_line_ids, errors)

	var known_choice_ids: Dictionary[StringName, bool] = {}
	for index: int in line.choices.size():
		var choice: DialogueChoice = line.choices[index]
		if choice == null:
			errors.append("%s choice %d is missing." % [label, index])
			continue
		_validate_id("DialogueChoice", choice.id, errors)
		if known_choice_ids.has(choice.id):
			errors.append("%s repeats choice ID '%s'." % [label, choice.id])
		else:
			known_choice_ids[choice.id] = true
		_validate_text_key(
			"%s choice '%s' text_key" % [label, choice.id],
			choice.text_key,
			catalog,
			required_locales,
			errors
		)
		_validate_conditions("%s choice '%s'" % [label, choice.id], choice.conditions, errors)
		_validate_effects("%s choice '%s'" % [label, choice.id], choice.effects, errors)
		if choice.next_line_id.is_empty():
			errors.append("%s choice '%s' next_line_id is empty." % [label, choice.id])
		else:
			_validate_line_reference(
				"%s choice '%s'" % [label, choice.id],
				"next_line_id",
				choice.next_line_id,
				known_line_ids,
				errors
			)


static func _validate_conditions(
	label: String,
	conditions: Array[DialogueCondition],
	errors: PackedStringArray
) -> void:
	for index: int in conditions.size():
		var condition: DialogueCondition = conditions[index]
		if condition == null:
			errors.append("%s condition %d is missing." % [label, index])
			continue
		if (
			condition.condition_type < DialogueCondition.ConditionType.STORY_FLAG_EQUALS
			or condition.condition_type > DialogueCondition.ConditionType.STORY_FLAG_EQUALS
		):
			errors.append("%s condition %d has an unsupported type." % [label, index])
		if condition.flag_id.is_empty():
			errors.append("%s condition %d flag_id is empty." % [label, index])


static func _validate_effects(
	label: String,
	effects: Array[DialogueEffect],
	errors: PackedStringArray
) -> void:
	for index: int in effects.size():
		var effect: DialogueEffect = effects[index]
		if effect == null:
			errors.append("%s effect %d is missing." % [label, index])
			continue
		if (
			effect.effect_type < DialogueEffect.EffectType.SET_STORY_FLAG
			or effect.effect_type > DialogueEffect.EffectType.EMIT_FLOW_EVENT
		):
			errors.append("%s effect %d has an unsupported type." % [label, index])
		if effect.effect_id.is_empty():
			errors.append("%s effect %d effect_id is empty." % [label, index])


static func _validate_line_reference(
	label: String,
	field_name: String,
	line_id: StringName,
	known_line_ids: Dictionary[StringName, bool],
	errors: PackedStringArray
) -> void:
	if not line_id.is_empty() and not known_line_ids.has(line_id):
		errors.append("%s %s references missing line '%s'." % [label, field_name, line_id])


static func _validate_text_key(
	label: String,
	message_key: StringName,
	catalog: LocalizationCatalog,
	required_locales: PackedStringArray,
	errors: PackedStringArray
) -> void:
	if message_key.is_empty():
		errors.append("%s is empty." % label)
		return
	if not catalog.has_key(message_key):
		errors.append("%s references missing localization key '%s'." % [label, message_key])
		return
	for locale: String in required_locales:
		if not catalog.has_translation(message_key, StringName(locale)):
			errors.append("%s key '%s' is missing locale '%s'." % [label, message_key, locale])


static func _validate_id(label: String, definition_id: StringName, errors: PackedStringArray) -> void:
	if definition_id.is_empty():
		errors.append("%s has an empty ID." % label)
		return
	var pattern: RegEx = RegEx.new()
	if pattern.compile(DEFINITION_ID_PATTERN) != OK or pattern.search(String(definition_id)) == null:
		errors.append("%s ID '%s' must use lower snake_case." % [label, definition_id])
