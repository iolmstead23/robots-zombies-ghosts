extends Node
class_name WaypointTracker

"""
Tracks waypoint advancement and timeout detection.

Design notes:
- Manages waypoint progression along a path
- Detects stuck/timeout conditions
- Provides waypoint advancement logic
"""

# ----------------------
# Signals
# ----------------------

signal waypoint_reached(waypoint: Vector2, index: int, remaining: int)
signal waypoint_timeout(waypoint: Vector2, index: int)
signal all_waypoints_reached()

# ----------------------
# Configuration
# ----------------------

var waypoint_reach_distance: int = MovementConstants.WAYPOINT_ADVANCEMENT_DISTANCE
var waypoint_timeout_duration: int = MovementConstants.WAYPOINT_TIMEOUT

# ----------------------
# State
# ----------------------

var current_waypoint_index: int = 0
var waypoint_start_time: int = 0
var last_distance_to_waypoint: int = 999999999  # Large sentinel value for "not yet measured"
var is_tracking: bool = false

# ----------------------
# Waypoint Tracking
# ----------------------

## Start tracking waypoints
func start_tracking() -> void:
	current_waypoint_index = 0
	waypoint_start_time = Time.get_ticks_msec()
	last_distance_to_waypoint = 999999999
	is_tracking = true

## Stop tracking waypoints
func stop_tracking() -> void:
	is_tracking = false
	current_waypoint_index = 0

## Update waypoint tracking
func update_tracking(current_pos: Vector2, path: Array[Vector2]) -> bool:
	if not is_tracking or path.is_empty():
		return false

	if current_waypoint_index >= path.size():
		all_waypoints_reached.emit()
		return true # All waypoints reached

	var waypoint := path[current_waypoint_index]
	var distance := int(current_pos.distance_to(waypoint))

	if should_advance_waypoint(distance, waypoint):
		advance_waypoint(waypoint, path.size())
		return true

	return false

## Check if should advance to next waypoint
func should_advance_waypoint(distance: int, waypoint: Vector2) -> bool:
	var within_reach := distance < waypoint_reach_distance
	var is_stuck := check_if_stuck(distance, waypoint)

	return within_reach or is_stuck

## Advance to next waypoint
func advance_waypoint(waypoint: Vector2, total_waypoints: int) -> void:
	var remaining := total_waypoints - current_waypoint_index - 1

	waypoint_reached.emit(waypoint, current_waypoint_index, remaining)
	current_waypoint_index += 1

	if current_waypoint_index < total_waypoints:
		reset_waypoint_tracking()

# ----------------------
# Stuck/Timeout Detection
# ----------------------

## Check if stuck at waypoint (timeout with no progress)
func check_if_stuck(current_distance: int, waypoint: Vector2) -> bool:
	var time_elapsed := Time.get_ticks_msec() - waypoint_start_time
	var distance_improved := last_distance_to_waypoint - current_distance

	last_distance_to_waypoint = current_distance

	var is_stuck := time_elapsed > waypoint_timeout_duration and distance_improved < 1

	if is_stuck:
		waypoint_timeout.emit(
			waypoint,
			current_waypoint_index
		)

	return is_stuck

## Reset waypoint tracking for next waypoint
func reset_waypoint_tracking() -> void:
	waypoint_start_time = Time.get_ticks_msec()
	last_distance_to_waypoint = 999999999

# ----------------------
# State Queries
# ----------------------

## Get current waypoint index
func get_current_index() -> int:
	return current_waypoint_index

## Get remaining waypoint count
func get_remaining_count(total_waypoints: int) -> int:
	return max(0, total_waypoints - current_waypoint_index)

## Get current waypoint
func get_current_waypoint(path: Array[Vector2]) -> Vector2:
	if current_waypoint_index < path.size():
		return path[current_waypoint_index]
	return Vector2.ZERO

## Check if at final waypoint
func is_at_final_waypoint(total_waypoints: int) -> bool:
	return current_waypoint_index >= total_waypoints - 1

## Get elapsed time at current waypoint (in milliseconds)
func get_elapsed_time() -> int:
	return Time.get_ticks_msec() - waypoint_start_time

# ----------------------
# Debug
# ----------------------

func get_tracking_info() -> Dictionary:
	return {
		"is_tracking": is_tracking,
		"current_index": current_waypoint_index,
		"elapsed_time": get_elapsed_time(),
		"last_distance": last_distance_to_waypoint
	}
