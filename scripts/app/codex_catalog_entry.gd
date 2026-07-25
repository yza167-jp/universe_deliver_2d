class_name CodexCatalogEntry
extends RefCounted

var id: StringName = &""
var category: CodexEntryDefinition.Category = CodexEntryDefinition.Category.PLANET
var title_key: StringName = &""
var description_key: StringName = &""
var related_planet_id: StringName = &""
var is_unlocked: bool = false
var is_locked_placeholder: bool = false
var codex_definition: CodexEntryDefinition
var souvenir_definition: SouvenirDefinition
