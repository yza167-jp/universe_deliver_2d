class_name PlanetDefinition
extends Resource

enum ContentReadiness {
	REGISTERED_ONLY,
	PLAYABLE,
}

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export_range(0.01, 10.0, 0.01, "or_greater") var gravity_scale: float = 1.0
@export var flight_environment_profile: FlightEnvironmentProfile
## Registered-only planets are valid catalog entries but cannot be selected for flight.
@export var content_readiness: ContentReadiness = ContentReadiness.PLAYABLE
@export_file("*.tscn") var flight_scene_path: String = ""
@export var required_story_flags: Array[StringName] = []


func is_playable() -> bool:
	return content_readiness == ContentReadiness.PLAYABLE
