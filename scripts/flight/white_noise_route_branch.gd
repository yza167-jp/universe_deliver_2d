class_name WhiteNoiseRouteBranch
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var instruction_key: StringName = &""
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var split_distance: float = 0.0
@export_range(0.0, 1000000.0, 1.0, "or_greater")
var join_distance: float = 1.0
@export_range(-2000.0, 2000.0, 1.0)
var lane_min_y: float = 0.0
@export_range(-2000.0, 2000.0, 1.0)
var lane_max_y: float = 640.0
@export_range(-2000.0, 2000.0, 1.0)
var retry_y: float = 240.0
@export_range(1.0, 600.0, 1.0, "or_greater")
var nominal_duration_seconds: float = 24.0
@export var guide_color: Color = Color(0.55, 0.9, 1.0, 1.0)


func contains_lane_y(ship_y: float) -> bool:
	return ship_y >= lane_min_y and ship_y < lane_max_y


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("White Noise branch ID must not be empty.")
	if display_name_key.is_empty() or instruction_key.is_empty():
		errors.append("White Noise branch '%s' needs localization keys." % id)
	if join_distance <= split_distance:
		errors.append("White Noise branch '%s' must join after its split." % id)
	if lane_max_y <= lane_min_y:
		errors.append("White Noise branch '%s' has an invalid lane range." % id)
	if retry_y < lane_min_y or retry_y >= lane_max_y:
		errors.append("White Noise branch '%s' retry Y must stay inside its lane." % id)
	if nominal_duration_seconds <= 0.0:
		errors.append("White Noise branch '%s' needs a positive duration." % id)
	return errors
