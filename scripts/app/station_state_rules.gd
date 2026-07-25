class_name StationStateRules
extends RefCounted

## Exact station-state IDs are authoritative. The integer level is only a
## monotonic summary for migrations, analytics, and coarse chapter checks.

const ARCHIVE_TERMINAL_ID: StringName = &"station_state_archive_terminal"
const ECOLOGY_CORNER_ID: StringName = &"station_state_ecology_corner"
const RELAY_OBSERVATORY_ID: StringName = &"station_state_relay_observatory"

const STATE_IDS: Array[StringName] = [
	ARCHIVE_TERMINAL_ID,
	ECOLOGY_CORNER_ID,
	RELAY_OBSERVATORY_ID,
]

const M0_FIRST_DELIVERY_LEVEL: int = 1
const ARCHIVE_TERMINAL_LEVEL: int = 2
const ECOLOGY_CORNER_LEVEL: int = 3
const RELAY_OBSERVATORY_LEVEL: int = 4
const REASON_INVALID_STATION_STATE: StringName = &"invalid_station_state"


static func is_known_state_id(state_id: StringName) -> bool:
	return STATE_IDS.has(state_id)


static func is_station_state_candidate(state_id: StringName) -> bool:
	return String(state_id).begins_with("station_state_")


static func get_state_level(state_id: StringName) -> int:
	match state_id:
		ARCHIVE_TERMINAL_ID:
			return ARCHIVE_TERMINAL_LEVEL
		ECOLOGY_CORNER_ID:
			return ECOLOGY_CORNER_LEVEL
		RELAY_OBSERVATORY_ID:
			return RELAY_OBSERVATORY_LEVEL
	return 0


static func get_required_summary_level(
	station_upgrade_ids: Dictionary[StringName, bool]
) -> int:
	var required_level: int = 0
	if station_upgrade_ids.get(
		M0ProgressIds.STATION_UPGRADE_FIRST_DELIVERY_DISPLAY,
		false
	):
		required_level = M0_FIRST_DELIVERY_LEVEL
	for state_id: StringName in STATE_IDS:
		if station_upgrade_ids.get(state_id, false):
			required_level = maxi(required_level, get_state_level(state_id))
	return required_level
