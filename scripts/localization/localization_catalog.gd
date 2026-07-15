class_name LocalizationCatalog
extends RefCounted

var locales: PackedStringArray = []
var errors: PackedStringArray = []

var _messages: Dictionary[StringName, Dictionary] = {}


static func load_csv(resource_path: String) -> LocalizationCatalog:
	var catalog: LocalizationCatalog = LocalizationCatalog.new()
	catalog._load_csv(resource_path)
	return catalog


func has_key(message_key: StringName) -> bool:
	return _messages.has(message_key)


func has_translation(message_key: StringName, locale: StringName) -> bool:
	if not _messages.has(message_key):
		return false
	var translations: Dictionary = _messages[message_key]
	return translations.has(locale) and not String(translations[locale]).is_empty()


func get_message(message_key: StringName, locale: StringName) -> String:
	if not has_translation(message_key, locale):
		return ""
	var translations: Dictionary = _messages[message_key]
	return String(translations[locale])


func _load_csv(resource_path: String) -> void:
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		errors.append("Localization table could not be opened: %s" % resource_path)
		return

	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2 or headers[0].strip_edges() != "keys":
		errors.append("Localization table must start with a keys column and at least one locale.")
		return

	for column_index: int in range(1, headers.size()):
		var locale: String = headers[column_index].strip_edges()
		if locale.is_empty():
			errors.append("Localization table has an empty locale header at column %d." % column_index)
		elif locales.has(locale):
			errors.append("Localization table repeats locale '%s'." % locale)
		else:
			locales.append(locale)

	var row_number: int = 1
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		row_number += 1
		if row.size() == 1 and row[0].strip_edges().is_empty():
			continue
		if row.size() != headers.size():
			errors.append(
				"Localization row %d has %d columns; expected %d."
				% [row_number, row.size(), headers.size()]
			)
			continue

		var message_key: StringName = StringName(row[0].strip_edges())
		if message_key.is_empty():
			errors.append("Localization row %d has an empty key." % row_number)
			continue
		if _messages.has(message_key):
			errors.append("Localization table repeats key '%s'." % message_key)
			continue

		var translations: Dictionary[StringName, String] = {}
		for column_index: int in range(1, headers.size()):
			var locale: StringName = StringName(headers[column_index].strip_edges())
			var message: String = row[column_index].strip_edges()
			if message.is_empty():
				errors.append(
					"Localization key '%s' has an empty '%s' translation."
					% [message_key, locale]
				)
			translations[locale] = message
		_messages[message_key] = translations
