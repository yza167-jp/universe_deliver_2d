class_name GameDataRegistry
extends Resource

@export var registry_id: StringName = &""
@export var planets: Array[PlanetDefinition] = []
@export var orders: Array[OrderDefinition] = []
@export var cargo_items: Array[CargoDefinition] = []
@export var modules: Array[ShipModuleDefinition] = []
@export var characters: Array[CharacterDefinition] = []
@export var codex_entries: Array[CodexEntryDefinition] = []
@export var souvenirs: Array[SouvenirDefinition] = []
## Compatibility aliases never create a second accept-able OrderDefinition.
@export var order_aliases: Dictionary[StringName, StringName] = {}


func find_planet(definition_id: StringName) -> PlanetDefinition:
	for definition: PlanetDefinition in planets:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_order(definition_id: StringName) -> OrderDefinition:
	var resolved_id: StringName = resolve_order_id(definition_id)
	for definition: OrderDefinition in orders:
		if definition != null and definition.id == resolved_id:
			return definition
	return null


func find_cargo(definition_id: StringName) -> CargoDefinition:
	for definition: CargoDefinition in cargo_items:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_module(definition_id: StringName) -> ShipModuleDefinition:
	for definition: ShipModuleDefinition in modules:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_character(definition_id: StringName) -> CharacterDefinition:
	for definition: CharacterDefinition in characters:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_codex_entry(definition_id: StringName) -> CodexEntryDefinition:
	for definition: CodexEntryDefinition in codex_entries:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_souvenir(definition_id: StringName) -> SouvenirDefinition:
	for definition: SouvenirDefinition in souvenirs:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func resolve_order_id(definition_id: StringName) -> StringName:
	return order_aliases.get(definition_id, definition_id)


func has_codex_reward_id(entry_id: StringName) -> bool:
	return find_codex_entry(entry_id) != null


func has_souvenir_reward_id(souvenir_id: StringName) -> bool:
	return find_souvenir(souvenir_id) != null
