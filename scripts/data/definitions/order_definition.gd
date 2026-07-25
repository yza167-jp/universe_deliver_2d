class_name OrderDefinition
extends Resource

enum OrderType {
	MAIN,
	SIDE,
	REVISIT,
}

enum DeliveryType {
	LANDING,
	LOW_ALTITUDE_DROP,
}

enum RepeatPolicy {
	UNIQUE,
	REPEATABLE,
	ARCHIVED_ONLY,
}

enum ContentReadiness {
	REGISTERED_ONLY,
	PLAYABLE,
}

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var order_type: OrderType = OrderType.MAIN
## Registered-only orders are valid catalog entries but cannot be accepted or flown.
@export var content_readiness: ContentReadiness = ContentReadiness.PLAYABLE
@export var required_chapter: StringName = &""
@export var unlock_conditions: Array[OrderUnlockCondition] = []
@export var sender: CharacterDefinition
@export var recipient: CharacterDefinition
@export var destination_planet: PlanetDefinition
@export var planet_id: StringName = &""
@export var destination_id: StringName = &""
@export var cargo: CargoDefinition
@export var delivery_type: DeliveryType = DeliveryType.LANDING
@export_range(0, 1000000, 1, "or_greater") var credit_reward: int = 0
@export var relation_rewards: Dictionary[StringName, int] = {}
@export var permission_rewards: Array[StringName] = []
@export var codex_rewards: Array[StringName] = []
@export var souvenir_rewards: Array[StringName] = []
@export var repeat_policy: RepeatPolicy = RepeatPolicy.UNIQUE
@export var is_express: bool = false
@export_range(0.0, 86400.0, 0.1, "or_greater") var target_seconds: float = 0.0
@export_range(0.0, 86400.0, 0.1, "or_greater") var grace_seconds: float = 0.0
@export_range(0.0, 1.0, 0.01) var minimum_reward_ratio: float = 1.0
@export_range(0, 10, 1, "or_greater") var relation_bonus_on_time: int = 0
@export_range(0.01, 1000000.0, 0.01, "or_greater") var route_distance: float = 1.0
@export_range(0, 5, 1) var risk_level: int = 0
@export var required_modules: Array[ShipModuleDefinition] = []
@export var recommended_modules: Array[ShipModuleDefinition] = []
@export var customer_history_keys: Array[StringName] = []
@export var story_requirements: Array[StringName] = []
@export var completion_flags: Array[StringName] = []


func is_mainline() -> bool:
	return order_type in [OrderType.MAIN, OrderType.REVISIT]


func is_playable() -> bool:
	return content_readiness == ContentReadiness.PLAYABLE
