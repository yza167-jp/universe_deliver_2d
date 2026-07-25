class_name M1CatalogHintResolver
extends RefCounted

## Converts internal progression and runtime reasons into stable player-facing hint keys.

const REASON_REGISTERED_ONLY: StringName = &"registered_only"
const REASON_PLANET_REGISTERED_ONLY: StringName = &"planet_registered_only"
const REASON_MISSING_ROUTE: StringName = &"missing_route"
const REASON_NO_ACTIVE_ORDER: StringName = &"no_active_order"


static func get_hint_key(
	reason: StringName,
	reference_id: StringName = &""
) -> StringName:
	if reason in [
		M1ProgressRules.REASON_REQUIRED_CHAPTER,
		M1ProgressRules.REASON_REQUIRED_PLANET,
		M1ProgressRules.REASON_REQUIRED_COMPLETED_ORDER,
	]:
		return &"UI_CATALOG_HINT_PREVIOUS_MAIN"
	if reason in [
		M1ProgressRules.REASON_REQUIRED_MODULE,
		GameStateModel.LOADOUT_ERROR_MISSING_REQUIRED_MODULES,
	]:
		if reference_id == M1ProgressRules.MODULE_HIGH_VOLTAGE_SHIELDING:
			return &"UI_CATALOG_HINT_HIGH_VOLTAGE"
		return &"UI_CATALOG_HINT_REQUIRED_MODULE"
	if reason == M1ProgressRules.REASON_REQUIRED_PERMISSION:
		if (
			reference_id
			== M1ProgressRules.PERMISSION_WHITE_NOISE_ARCHIVE_ACCESS
		):
			return &"UI_CATALOG_HINT_WHITE_NOISE_ARCHIVE_PERMISSION"
		return &"UI_CATALOG_HINT_REQUIRED_PERMISSION"
	if reason in [
		M1ProgressRules.REASON_REQUIRED_STORY_FLAG,
		GameStateModel.ORDER_ERROR_STORY_REQUIREMENT,
	]:
		return &"UI_CATALOG_HINT_STORY_PROGRESS"
	if reason in [
		GameStateModel.ORDER_ERROR_ACTIVE_ORDER,
		GameStateModel.ORDER_ERROR_ALREADY_ACCEPTED,
	]:
		return &"UI_CATALOG_HINT_ACTIVE_ORDER"
	if reason == &"already_completed":
		return &"UI_CATALOG_HINT_ALREADY_COMPLETED"
	if reason in [
		GameStateModel.ORDER_ERROR_ARCHIVED,
		GameStateModel.ORDER_ERROR_ARCHIVED_ONLY,
	]:
		return &"UI_CATALOG_HINT_ARCHIVED"
	if reason == REASON_REGISTERED_ONLY:
		return &"UI_CATALOG_HINT_REGISTERED_ONLY"
	if reason == REASON_PLANET_REGISTERED_ONLY:
		return &"UI_CATALOG_HINT_PLANET_REGISTERED_ONLY"
	if reason == REASON_MISSING_ROUTE:
		return &"UI_CATALOG_HINT_MISSING_ROUTE"
	if reason in [
		REASON_NO_ACTIVE_ORDER,
		GameStateModel.TRAVEL_ERROR_ORDER_NOT_ACTIVE,
		GameStateModel.LOADOUT_ERROR_ORDER_NOT_ACCEPTED,
	]:
		return &"UI_CATALOG_HINT_NO_ACTIVE_ORDER"
	if reason == GameStateModel.TRAVEL_ERROR_DEPARTURE_NOT_CONFIRMED:
		return &"UI_CATALOG_HINT_DEPARTURE_NOT_CONFIRMED"
	if reason == GameStateModel.TRAVEL_ERROR_DESTINATION_NOT_ALLOWED:
		return &"UI_CATALOG_HINT_ACTIVE_DESTINATION_ONLY"
	if reason == GameStateModel.TRAVEL_ERROR_ALREADY_STARTED:
		return &"UI_CATALOG_HINT_ROUTE_ACTIVE"
	if reason == GameStateModel.ORDER_ERROR_RETRY_NOT_ALLOWED:
		return &"UI_CATALOG_HINT_RETRY_UNAVAILABLE"
	if reason == &"missing_data":
		return &"UI_CATALOG_HINT_DATA_UNAVAILABLE"
	return &"UI_CATALOG_HINT_STORY_PROGRESS"


static func get_order_gate_reference(
	order: OrderDefinition,
	reason: StringName
) -> StringName:
	if order == null:
		return &""
	if reason == M1ProgressRules.REASON_REQUIRED_CHAPTER:
		return order.required_chapter
	for condition: OrderUnlockCondition in order.unlock_conditions:
		if condition == null:
			continue
		match reason:
			M1ProgressRules.REASON_REQUIRED_PLANET:
				if (
					condition.condition_type
					== OrderUnlockCondition.ConditionType.PLANET_UNLOCKED
				):
					return condition.reference_id
			M1ProgressRules.REASON_REQUIRED_MODULE:
				if (
					condition.condition_type
					== OrderUnlockCondition.ConditionType.MODULE_AVAILABLE
				):
					return condition.reference_id
			M1ProgressRules.REASON_REQUIRED_PERMISSION:
				if (
					condition.condition_type
					== OrderUnlockCondition.ConditionType.PERMISSION_GRANTED
				):
					return condition.reference_id
	if (
		reason == GameStateModel.ORDER_ERROR_STORY_REQUIREMENT
		and not order.story_requirements.is_empty()
	):
		return order.story_requirements[0]
	return &""
