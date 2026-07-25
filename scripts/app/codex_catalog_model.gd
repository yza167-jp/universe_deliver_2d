class_name CodexCatalogModel
extends RefCounted

## Stateless projection from registry content and persistent unlock IDs.

const UNKNOWN_TITLE_KEY: StringName = &"UI_CODEX_UNKNOWN_TITLE"
const UNKNOWN_DESCRIPTION_KEY: StringName = &"UI_CODEX_UNKNOWN_DESCRIPTION"
const CATEGORY_ORDER: Array[CodexEntryDefinition.Category] = [
	CodexEntryDefinition.Category.PLANET,
	CodexEntryDefinition.Category.CHARACTER,
	CodexEntryDefinition.Category.CARGO,
	CodexEntryDefinition.Category.ANOMALY,
	CodexEntryDefinition.Category.SOUVENIR,
]


static func build_catalog(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> Array[CodexCatalogEntry]:
	var entries: Array[CodexCatalogEntry] = []
	if registry == null or game_state == null:
		return entries

	var represented_souvenir_ids: Dictionary[StringName, bool] = {}
	for definition: CodexEntryDefinition in registry.codex_entries:
		if definition == null:
			continue
		var linked_souvenir_id: StringName = _get_linked_souvenir_id(definition)
		if not linked_souvenir_id.is_empty():
			represented_souvenir_ids[linked_souvenir_id] = true
		var is_unlocked: bool = (
			game_state.has_codex_entry(definition.id)
			or (
				not linked_souvenir_id.is_empty()
				and game_state.has_souvenir(linked_souvenir_id)
			)
		)
		if not is_unlocked and definition.hidden_when_locked:
			continue
		entries.append(
			_create_codex_entry(definition, is_unlocked)
		)

	for souvenir: SouvenirDefinition in registry.souvenirs:
		if (
			souvenir == null
			or represented_souvenir_ids.get(souvenir.id, false)
		):
			continue
		var is_unlocked: bool = game_state.has_souvenir(souvenir.id)
		if not is_unlocked and souvenir.hidden_when_locked:
			continue
		entries.append(
			_create_souvenir_entry(souvenir, is_unlocked)
		)
	return entries


static func get_entries_for_category(
	registry: GameDataRegistry,
	game_state: GameStateModel,
	category: CodexEntryDefinition.Category
) -> Array[CodexCatalogEntry]:
	var category_entries: Array[CodexCatalogEntry] = []
	for entry: CodexCatalogEntry in build_catalog(registry, game_state):
		if entry.category == category:
			category_entries.append(entry)
	return category_entries


static func get_category_order() -> Array[CodexEntryDefinition.Category]:
	return CATEGORY_ORDER.duplicate()


static func _create_codex_entry(
	definition: CodexEntryDefinition,
	is_unlocked: bool
) -> CodexCatalogEntry:
	var entry: CodexCatalogEntry = CodexCatalogEntry.new()
	entry.id = definition.id
	entry.category = definition.category
	entry.related_planet_id = definition.related_planet_id
	entry.is_unlocked = is_unlocked
	entry.is_locked_placeholder = not is_unlocked
	entry.codex_definition = definition
	entry.title_key = (
		definition.title_key if is_unlocked else UNKNOWN_TITLE_KEY
	)
	entry.description_key = (
		definition.description_key
		if is_unlocked
		else UNKNOWN_DESCRIPTION_KEY
	)
	return entry


static func _create_souvenir_entry(
	definition: SouvenirDefinition,
	is_unlocked: bool
) -> CodexCatalogEntry:
	var entry: CodexCatalogEntry = CodexCatalogEntry.new()
	entry.id = definition.id
	entry.category = CodexEntryDefinition.Category.SOUVENIR
	entry.related_planet_id = definition.related_planet_id
	entry.is_unlocked = is_unlocked
	entry.is_locked_placeholder = not is_unlocked
	entry.souvenir_definition = definition
	entry.title_key = (
		definition.display_name_key if is_unlocked else UNKNOWN_TITLE_KEY
	)
	entry.description_key = (
		definition.description_key
		if is_unlocked
		else UNKNOWN_DESCRIPTION_KEY
	)
	return entry


static func _get_linked_souvenir_id(
	definition: CodexEntryDefinition
) -> StringName:
	if definition.category != CodexEntryDefinition.Category.SOUVENIR:
		return &""
	var codex_id: String = String(definition.id)
	if not codex_id.begins_with("codex_souvenir_"):
		return &""
	return StringName(codex_id.trim_prefix("codex_"))
