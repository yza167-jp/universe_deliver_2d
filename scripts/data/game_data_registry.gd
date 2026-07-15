class_name GameDataRegistry
extends Resource

@export var planets: Array[PlanetDefinition] = []
@export var orders: Array[OrderDefinition] = []
@export var cargo_items: Array[CargoDefinition] = []
@export var modules: Array[ShipModuleDefinition] = []
@export var characters: Array[CharacterDefinition] = []


func find_planet(definition_id: StringName) -> PlanetDefinition:
	for definition: PlanetDefinition in planets:
		if definition != null and definition.id == definition_id:
			return definition
	return null


func find_order(definition_id: StringName) -> OrderDefinition:
	for definition: OrderDefinition in orders:
		if definition != null and definition.id == definition_id:
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
