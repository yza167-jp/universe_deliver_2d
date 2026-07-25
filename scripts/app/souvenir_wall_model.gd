class_name SouvenirWallModel
extends RefCounted

## Stable slot projection. Locked slots intentionally retain no player-visible
## content from their source definitions.

const LOCKED_NAME_KEY: StringName = &"UI_SOUVENIR_SLOT_LOCKED"
const LOCKED_DESCRIPTION_KEY: StringName = &"UI_SOUVENIR_LOCKED_DESCRIPTION"
const RELAY_PLAQUE_ID: StringName = &"souvenir_old_relay_plaque"


static func build_entries(
	registry: GameDataRegistry,
	game_state: GameStateModel
) -> Array[SouvenirWallEntry]:
	var entries: Array[SouvenirWallEntry] = []
	if registry == null or game_state == null:
		return entries
	for definition: SouvenirDefinition in registry.souvenirs:
		if definition == null:
			continue
		var is_acquired: bool = _is_acquired(definition.id, game_state)
		var entry: SouvenirWallEntry = SouvenirWallEntry.new()
		entry.souvenir = definition
		entry.souvenir_id = definition.id
		entry.is_acquired = is_acquired
		entry.display_name_key = (
			definition.display_name_key if is_acquired else LOCKED_NAME_KEY
		)
		entry.description_key = (
			definition.description_key
			if is_acquired
			else LOCKED_DESCRIPTION_KEY
		)
		entries.append(entry)
	return entries


static func get_acquired_count(entries: Array[SouvenirWallEntry]) -> int:
	var acquired_count: int = 0
	for entry: SouvenirWallEntry in entries:
		if entry != null and entry.is_acquired:
			acquired_count += 1
	return acquired_count


static func _is_acquired(
	souvenir_id: StringName,
	game_state: GameStateModel
) -> bool:
	if game_state.has_souvenir(souvenir_id):
		return true
	return (
		souvenir_id == RELAY_PLAQUE_ID
		and game_state.has_station_upgrade(
			M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY
		)
	)
