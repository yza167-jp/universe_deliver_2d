class_name M1PlanetCatalogEntry
extends RefCounted

var planet: PlanetDefinition
var planet_id: StringName = &""
var is_discovered: bool = false
var is_progression_unlocked: bool = false
var is_content_playable: bool = false
var is_current_destination: bool = false
var is_departure_selectable: bool = false
var lock_reason: StringName = &""
var lock_hint_key: StringName = &""
var is_name_disclosed: bool = false
var preparation_status: M1DestinationPreparationStatus
