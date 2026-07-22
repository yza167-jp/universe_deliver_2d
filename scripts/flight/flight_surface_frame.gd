class_name FlightSurfaceFrame
extends RefCounted

## Establishes the terrain's vertical datum before the first physical surface appears.
## It never moves or rewrites the ship; every surface consumer receives one shared offset.

const DISTANCE_EPSILON: float = 0.01

var prepare_start_distance: float = 0.0
var lock_distance: float = 0.0
var minimum_entry_altitude_meters: float = 0.0
var descent_reaction_seconds: float = 0.0
var meters_per_route_unit: float = 1.0

var offset_y: float = 0.0
var baseline_offset_y: float = 0.0
var predicted_entry_altitude_meters: float = 0.0
var acquired_route_distance: float = 0.0
var is_acquired: bool = false
var is_locked: bool = false

var _is_configured: bool = false


func configure(
	requested_prepare_start_distance: float,
	requested_lock_distance: float,
	requested_minimum_entry_altitude_meters: float,
	requested_descent_reaction_seconds: float,
	requested_meters_per_route_unit: float = 1.0
) -> bool:
	if (
		requested_prepare_start_distance < 0.0
		or requested_lock_distance <= requested_prepare_start_distance
		or requested_minimum_entry_altitude_meters <= 0.0
		or requested_descent_reaction_seconds < 0.0
		or requested_meters_per_route_unit <= 0.0
	):
		_is_configured = false
		return false
	prepare_start_distance = requested_prepare_start_distance
	lock_distance = requested_lock_distance
	minimum_entry_altitude_meters = requested_minimum_entry_altitude_meters
	descent_reaction_seconds = requested_descent_reaction_seconds
	meters_per_route_unit = requested_meters_per_route_unit
	_is_configured = true
	reset()
	return true


func reset() -> void:
	offset_y = 0.0
	baseline_offset_y = 0.0
	predicted_entry_altitude_meters = 0.0
	acquired_route_distance = 0.0
	is_acquired = false
	is_locked = false


func update(
	route_distance: float,
	ship_reference_route_y: float,
	vertical_speed_route_units: float,
	base_ground_route_y: float,
	lock_ground_route_y: float,
	virtual_altitude_meters: float
) -> bool:
	if not _is_configured or is_locked:
		return false
	if route_distance + DISTANCE_EPSILON < prepare_start_distance:
		return false
	if not (
		is_finite(ship_reference_route_y)
		and is_finite(vertical_speed_route_units)
		and is_finite(base_ground_route_y)
		and is_finite(lock_ground_route_y)
		and is_finite(virtual_altitude_meters)
	):
		return false

	var safe_scale: float = maxf(meters_per_route_unit, 0.001)
	if not is_acquired:
		baseline_offset_y = (
			ship_reference_route_y
			+ maxf(virtual_altitude_meters, 0.0) / safe_scale
			- base_ground_route_y
		)
		offset_y = baseline_offset_y
		acquired_route_distance = route_distance
		is_acquired = true

	var protected_entry_altitude_meters: float = (
		minimum_entry_altitude_meters
		+ maxf(vertical_speed_route_units, 0.0)
		* safe_scale
		* descent_reaction_seconds
	)
	var required_offset_y: float = (
		ship_reference_route_y
		+ protected_entry_altitude_meters / safe_scale
		- lock_ground_route_y
	)
	offset_y = maxf(baseline_offset_y, required_offset_y)
	predicted_entry_altitude_meters = (
		lock_ground_route_y + offset_y - ship_reference_route_y
	) * safe_scale
	if route_distance + DISTANCE_EPSILON >= lock_distance:
		is_locked = true
	return true


func is_configured() -> bool:
	return _is_configured
