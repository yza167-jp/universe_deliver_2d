class_name M1DestinationPreparationStatus
extends RefCounted

enum State {
	NOT_APPLICABLE,
	PREVIOUS_MAIN_REQUIRED,
	MODULE_NOT_OBTAINED,
	MODULE_NOT_INSTALLED,
	QUALIFIED_ROUTE_PENDING,
	READY,
}

var order: OrderDefinition
var planet: PlanetDefinition
var state: State = State.NOT_APPLICABLE
var qualification_reason: StringName = &""
var hint_key: StringName = &""
var is_visible: bool = false
var is_navigation_unlocked: bool = false
var is_route_qualified: bool = false
var is_formal_route_available: bool = false
var required_module_state: int = -1
