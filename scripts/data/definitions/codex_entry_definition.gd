class_name CodexEntryDefinition
extends Resource

enum Category {
	PLANET,
	CHARACTER,
	CARGO,
	ANOMALY,
	SOUVENIR,
}

@export var id: StringName = &""
@export var category: Category = Category.PLANET
@export var title_key: StringName = &""
@export var description_key: StringName = &""
@export var related_planet_id: StringName = &""
@export var hidden_when_locked: bool = true
