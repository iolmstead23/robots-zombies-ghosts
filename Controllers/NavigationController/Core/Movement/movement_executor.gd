extends Node
class_name MovementExecutor

"""
Executes movement along a path with progress tracking.

Design notes:
- Handles movement physics and progress updates
- Works with both turn-based and real-time movement
- Emits signals for movement milestones
"""

# ----------------------
# Signals
# ----------------------

signal movement_started()
signal movement_progress_updated(progress: float, position: Vector2)
signal movement_completed(distance_moved: float)
signal movement_failed(reason: String)

# ----------------------
# Configuration
# ----------------------

var movement_speed: int = 400 # pixels/second
var arrival_distance: int = 5 # pixels

# ----------------------
# State
# ----------------------

var is_executing: bool = false
var current_progress: float = 0.0
var total_distance: int = 0
var distance_moved: int = 0

# ----------------------
# Movement Execution
# ----------------------

## Start executing movement along a path
func start_execution(path: Array[Vector2]) -> bool:
	if path.is_empty():
		movement_failed.emit("Empty path")
		return false

	is_executing = true
	current_progress = 0.0
	distance_moved = 0
	total_distance = DistanceCalculator.path_distance(path)

	movement_started.emit()
	return true

## Update movement progress based on delta time
func update_progress(delta: float) -> float:
	if not is_executing or total_distance <= 0:
		return current_progress

	var distance_increment := int(movement_speed * delta)
	distance_moved += distance_increment

	current_progress = InterpolationUtils.update_progress(
		current_progress,
		movement_speed,
		total_distance,
		delta
	)

	return current_progress

## Complete movement execution
func complete_execution() -> void:
	if not is_executing:
		return

	is_executing = false
	current_progress = 1.0

	movement_completed.emit(distance_moved)

## Cancel movement execution
func cancel_execution() -> void:
	is_executing = false
	current_progress = 0.0
	distance_moved = 0
	total_distance = 0

# ----------------------
# Movement Calculations
# ----------------------

## Calculate next position based on current progress
func get_next_position(path: Array[Vector2]) -> Vector2:
	return InterpolationUtils.get_position_at_progress(path, current_progress)

## Calculate direction to target
func get_direction_to_target(current_pos: Vector2, target_pos: Vector2) -> Vector2:
	return DirectionUtils.direction_to_with_threshold(current_pos, target_pos, arrival_distance)

## Check if near arrival
func is_near_arrival(current_pos: Vector2, target_pos: Vector2) -> bool:
	return DistanceCalculator.is_near_arrival(current_pos, target_pos, arrival_distance)

## Check if near completion
func is_near_completion() -> bool:
	return InterpolationUtils.is_near_completion(current_progress, MovementConstants.NEAR_FINISH_PROGRESS)

# ----------------------
# State Queries
# ----------------------

## Get movement progress (0.0 to 1.0)
func get_progress() -> float:
	return current_progress

## Get distance moved so far
func get_distance_moved() -> int:
	return distance_moved

## Get total distance
func get_total_distance() -> int:
	return total_distance

## Get remaining distance
func get_remaining_distance() -> int:
	return max(0, total_distance - distance_moved)

# ----------------------
# Debug
# ----------------------

func get_execution_info() -> Dictionary:
	return {
		"is_executing": is_executing,
		"progress": current_progress,
		"distance_moved": distance_moved,
		"total_distance": total_distance,
		"remaining_distance": get_remaining_distance(),
		"movement_speed": movement_speed
	}
