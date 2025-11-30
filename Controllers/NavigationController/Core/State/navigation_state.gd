extends Node
class_name NavigationState

"""
Manages navigation state for an agent.

Design notes:
- Tracks current navigation status, target, and path
- Provides state query methods
- Emits signals on state changes
"""

# ----------------------
# Signals
# ----------------------

signal state_changed(is_active: bool, target: HexCell)
signal progress_updated(waypoint_index: int, total_waypoints: int)

# ----------------------
# State Variables
# ----------------------

var is_navigating: bool = false
var current_target_cell: HexCell = null
var current_hex_path: Array[HexCell] = []
var current_waypoint_index: int = 0

# Tracking
var navigation_start_time: int = 0
var total_distance: int = 0

# ----------------------
# State Management
# ----------------------

## Start navigation with a new target and path
func start_navigation(target: HexCell, path: Array[HexCell]) -> void:
	is_navigating = true
	current_target_cell = target
	current_hex_path = path
	current_waypoint_index = 0
	navigation_start_time = Time.get_ticks_msec()

	_calculate_total_distance()
	state_changed.emit(is_navigating, current_target_cell)

## Clear navigation state
func clear_navigation() -> void:
	is_navigating = false
	current_target_cell = null
	current_hex_path.clear()
	current_waypoint_index = 0
	total_distance = 0

	state_changed.emit(is_navigating, null)

## Advance to next waypoint
func advance_waypoint() -> bool:
	if current_waypoint_index >= current_hex_path.size() - 1:
		return false # Already at last waypoint

	current_waypoint_index += 1
	progress_updated.emit(current_waypoint_index, current_hex_path.size())
	return true

## Check if reached final waypoint
func is_at_final_waypoint() -> bool:
	return current_waypoint_index >= current_hex_path.size() - 1

# ----------------------
# State Queries
# ----------------------

## Get current waypoint cell
func get_current_waypoint() -> HexCell:
	if current_waypoint_index < current_hex_path.size():
		return current_hex_path[current_waypoint_index]
	return null

## Get remaining waypoints
func get_remaining_waypoint_count() -> int:
	return max(0, current_hex_path.size() - current_waypoint_index - 1)

## Get navigation progress (0.0 to 1.0)
func get_progress() -> float:
	if current_hex_path.is_empty():
		return 0.0

	return float(current_waypoint_index) / float(current_hex_path.size() - 1)

## Get elapsed navigation time (in milliseconds)
func get_elapsed_time() -> int:
	if not is_navigating:
		return 0

	return Time.get_ticks_msec() - navigation_start_time

# ----------------------
# Internal Utilities
# ----------------------

func _calculate_total_distance() -> void:
	total_distance = 0

	if current_hex_path.size() < 2:
		return

	for i in range(current_hex_path.size() - 1):
		var from := current_hex_path[i].world_position
		var to := current_hex_path[i + 1].world_position
		total_distance += int(from.distance_to(to))

# ----------------------
# Debug
# ----------------------

func get_state_info() -> Dictionary:
	return {
		"is_navigating": is_navigating,
		"target": current_target_cell,
		"path_length": current_hex_path.size(),
		"waypoint_index": current_waypoint_index,
		"progress": get_progress(),
		"elapsed_time": get_elapsed_time(),
		"total_distance": total_distance
	}
