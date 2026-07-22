class_name FlightRouteDefinition
extends Resource

const MIN_FAST_DURATION_SECONDS: float = 60.0
const MAX_FAST_DURATION_SECONDS: float = 100.0
const MIN_BALANCED_DURATION_SECONDS: float = 90.0
const MAX_BALANCED_DURATION_SECONDS: float = 150.0
const MIN_SCENIC_DURATION_SECONDS: float = 120.0
const MAX_SCENIC_DURATION_SECONDS: float = 180.0
const DISTANCE_EPSILON: float = 0.01

@export var id: StringName = &""
@export_range(1.0, 3600.0, 1.0, "or_greater")
var nominal_fast_duration_seconds: float = 80.0
@export_range(1.0, 3600.0, 1.0, "or_greater")
var expected_duration_seconds: float = 120.0
@export_range(1.0, 3600.0, 1.0, "or_greater")
var nominal_scenic_duration_seconds: float = 165.0
@export_range(0.0, 5000.0, 1.0, "or_greater")
var reverse_allowance_distance: float = 640.0
@export_range(0.0, 5000.0, 1.0, "or_greater")
var finish_hold_distance: float = 360.0
@export var segments: Array[FlightRouteSegment] = []


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("Flight route ID must not be empty.")
	if segments.is_empty():
		errors.append("Flight route must contain at least one segment.")
		return errors
	if (
		nominal_fast_duration_seconds < MIN_FAST_DURATION_SECONDS
		or nominal_fast_duration_seconds > MAX_FAST_DURATION_SECONDS
	):
		errors.append("Flight route fast duration must stay within 60-100 seconds.")
	if (
		expected_duration_seconds < MIN_BALANCED_DURATION_SECONDS
		or expected_duration_seconds > MAX_BALANCED_DURATION_SECONDS
	):
		errors.append("Flight route balanced duration must stay within 90-150 seconds.")
	if (
		nominal_scenic_duration_seconds < MIN_SCENIC_DURATION_SECONDS
		or nominal_scenic_duration_seconds > MAX_SCENIC_DURATION_SECONDS
	):
		errors.append("Flight route scenic duration must stay within 120-180 seconds.")
	if not (
		nominal_fast_duration_seconds < expected_duration_seconds
		and expected_duration_seconds < nominal_scenic_duration_seconds
	):
		errors.append("Flight route duration profiles must stay ordered fast to scenic.")

	var previous_end: float = 0.0
	var previous_planet_scale: float = 0.0
	var seen_ids: Dictionary[StringName, bool] = {}
	var seen_checkpoints: Dictionary[StringName, bool] = {}
	for index: int in segments.size():
		var segment: FlightRouteSegment = segments[index]
		if segment == null:
			errors.append("Flight route segment %d is missing." % index)
			continue
		if segment.id.is_empty():
			errors.append("Flight route segment %d has an empty ID." % index)
		elif seen_ids.has(segment.id):
			errors.append("Flight route repeats segment ID '%s'." % segment.id)
		else:
			seen_ids[segment.id] = true
		if segment.display_name_key.is_empty() or segment.instruction_key.is_empty():
			errors.append("Flight route segment '%s' is missing localization keys." % segment.id)
		if segment.checkpoint_id.is_empty():
			errors.append("Flight route segment '%s' has an empty checkpoint ID." % segment.id)
		elif seen_checkpoints.has(segment.checkpoint_id):
			errors.append(
				"Flight route repeats checkpoint ID '%s'." % segment.checkpoint_id
			)
		else:
			seen_checkpoints[segment.checkpoint_id] = true
		if segment.environment_profile == null:
			errors.append("Flight route segment '%s' has no environment profile." % segment.id)
		if segment.get_length() <= 0.0:
			errors.append("Flight route segment '%s' has no positive length." % segment.id)
		if not is_equal_approx(segment.start_distance, previous_end):
			errors.append(
				"Flight route segment '%s' does not begin at %.1f."
				% [segment.id, previous_end]
			)
		if segment.planet_scale_start + DISTANCE_EPSILON < previous_planet_scale:
			errors.append("Flight route planet scale decreases before '%s'." % segment.id)
		if segment.planet_scale_end + DISTANCE_EPSILON < segment.planet_scale_start:
			errors.append("Flight route planet scale decreases inside '%s'." % segment.id)
		previous_end = segment.end_distance
		previous_planet_scale = segment.planet_scale_end
	return errors


func get_total_distance() -> float:
	if segments.is_empty() or segments[-1] == null:
		return 0.0
	return maxf(segments[-1].end_distance, 0.0)


func get_estimated_cruise_speed() -> float:
	if expected_duration_seconds <= 0.0:
		return 0.0
	return get_total_distance() / expected_duration_seconds


func get_segment_index(route_distance: float) -> int:
	if segments.is_empty():
		return -1
	var clamped_distance: float = maxf(route_distance, 0.0)
	for index: int in segments.size():
		var segment: FlightRouteSegment = segments[index]
		if segment != null and clamped_distance < segment.end_distance:
			return index
	return segments.size() - 1


func get_segment(route_distance: float) -> FlightRouteSegment:
	var index: int = get_segment_index(route_distance)
	if index < 0:
		return null
	return segments[index]


func get_overall_progress(route_distance: float) -> float:
	var total_distance: float = get_total_distance()
	if total_distance <= 0.0:
		return 0.0
	return clampf(route_distance / total_distance, 0.0, 1.0)


func get_planet_scale(route_distance: float) -> float:
	var segment: FlightRouteSegment = get_segment(route_distance)
	if segment == null:
		return 1.0
	return segment.get_planet_scale(route_distance)


## Returns the compressed route-surface datum used by graybox geometry and diagnostics.
## Player-visible altitude is provided separately by FlightAltitudeReferenceProvider.
func get_altitude_reference_y(route_distance: float) -> float:
	var segment_index: int = get_segment_index(route_distance)
	if segment_index < 0:
		return 0.0
	var segment: FlightRouteSegment = segments[segment_index]
	if segment == null:
		return 0.0
	var start_y: float = (
		segment.floor_y
		if segment_index == 0 or segments[segment_index - 1] == null
		else segments[segment_index - 1].floor_y
	)
	return lerpf(start_y, segment.floor_y, segment.get_progress(route_distance))
