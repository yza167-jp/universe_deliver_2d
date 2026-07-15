class_name OrderDefinition
extends Resource

enum OrderType {
	MAIN,
	SIDE,
}

enum DeliveryMethod {
	LANDING,
	AIRDROP,
	CHECKPOINT,
	DOCKING,
}

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var order_type: OrderType = OrderType.MAIN
@export var sender: CharacterDefinition
@export var recipient: CharacterDefinition
@export var destination_planet: PlanetDefinition
@export var cargo: CargoDefinition
@export_range(0, 1000000, 1, "or_greater") var reward_credits: int = 0
@export_range(0.01, 1000000.0, 0.01, "or_greater") var route_distance: float = 1.0
@export_range(0, 5, 1) var risk_level: int = 0
@export var required_modules: Array[ShipModuleDefinition] = []
@export var recommended_modules: Array[ShipModuleDefinition] = []
@export var delivery_method: DeliveryMethod = DeliveryMethod.LANDING
@export var customer_history_keys: Array[StringName] = []
@export var story_requirements: Array[StringName] = []
@export var completion_flags: Array[StringName] = []
