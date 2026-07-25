class_name M1OrderCatalogEntry
extends RefCounted

enum DisplayCategory {
	HIDDEN,
	CURRENT_ACCEPTED,
	CURRENT_MAINLINE,
	OPTIONAL,
	NEXT_CLUE,
	HISTORY,
}

var order: OrderDefinition
var order_id: StringName = &""
var order_type: OrderDefinition.OrderType = OrderDefinition.OrderType.MAIN
var status: GameStateModel.OrderStatus = GameStateModel.OrderStatus.AVAILABLE
var display_category: DisplayCategory = DisplayCategory.HIDDEN
var is_visible: bool = false
var is_selectable: bool = false
var accept_enabled: bool = false
var lock_reason: StringName = &""
var lock_hint_key: StringName = &""
var destination: PlanetDefinition
var is_express: bool = false
var content_playable: bool = false
var destination_playable: bool = false
var is_name_disclosed: bool = false
var required_modules: Array[ShipModuleDefinition] = []
var recommended_modules: Array[ShipModuleDefinition] = []


func is_history() -> bool:
	return display_category == DisplayCategory.HISTORY
