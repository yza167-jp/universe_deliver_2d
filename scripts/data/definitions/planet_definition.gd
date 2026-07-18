class_name PlanetDefinition
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export_range(0.01, 10.0, 0.01, "or_greater") var gravity_scale: float = 1.0
@export var flight_environment_profile: FlightEnvironmentProfile
@export_file("*.tscn") var flight_scene_path: String = ""
@export var required_story_flags: Array[StringName] = []
