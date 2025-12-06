## ProgressTracker - Tracks movement progress with detailed metrics
##
## Design notes:
## - Tracks progress along paths
## - Provides progress metrics and statistics
## - Handles progress bumps and adjustments

extends Node
class_name ProgressTracker

# ----------------------
# Signals
# ----------------------

signal progress_updated(progress: float, metrics: Dictionary)
signal milestone_reached(progress: float)

# ----------------------
# Configuration
# ----------------------

var milestones: Array[float] = [0.25, 0.5, 0.75, 1.0] # Progress milestones to track

# ----------------------
# State
# ----------------------

var current_progress: float = 0.0
var total_distance: int = 0
var distance_traveled: int = 0
var last_milestone_index: int = -1

var start_time: int = 0
var start_position: Vector2 = Vector2.ZERO

# ----------------------
# Progress Tracking
# ----------------------

## Initialize progress tracking
func start_tracking(path: Array[Vector2], start_pos: Vector2) -> void:
	current_progress = 0.0
	distance_traveled = 0
	last_milestone_index = -1

	total_distance = DistanceCalculator.path_distance(path)
	start_time = Time.get_ticks_msec()
	start_position = start_pos

## Update progress based on current position
func update_from_position(current_pos: Vector2, path: Array[Vector2]) -> float:
	current_progress = InterpolationUtils.get_progress_from_position(path, current_pos)
	distance_traveled = int(current_progress * total_distance)

	_check_milestones()
	_emit_progress()

	return current_progress

## Update progress based on movement
func update_from_movement(speed: int, delta: float) -> float:
	current_progress = InterpolationUtils.update_progress(
		current_progress,
		speed,
		total_distance,
		delta
	)

	distance_traveled = int(current_progress * total_distance)

	_check_milestones()
	_emit_progress()

	return current_progress

## Bump progress forward (for waypoint advancement)
func bump_progress(amount: float = MovementConstants.PROGRESS_BUMP_ON_POINT_REACHED) -> void:
	current_progress = min(1.0, current_progress + amount)
	distance_traveled = int(current_progress * total_distance)
	_emit_progress()

## Set progress directly
func set_progress(progress: float) -> void:
	current_progress = clamp(progress, 0.0, 1.0)
	distance_traveled = int(current_progress * total_distance)
	_emit_progress()

# ----------------------
# Progress Queries
# ----------------------

## Get current progress (0.0 to 1.0)
func get_progress() -> float:
	return current_progress

## Get distance traveled
func get_distance_traveled() -> int:
	return distance_traveled

## Get remaining distance
func get_remaining_distance() -> int:
	return max(0, total_distance - distance_traveled)

## Get total distance
func get_total_distance() -> int:
	return total_distance

## Get elapsed time (in milliseconds)
func get_elapsed_time() -> int:
	return Time.get_ticks_msec() - start_time

## Get average speed (pixels/second)
func get_average_speed() -> int:
	var elapsed := get_elapsed_time()
	if elapsed <= 0:
		return 0

	return int(float(distance_traveled * 1000) / float(elapsed))

## Check if near completion
func is_near_completion(threshold: float = MovementConstants.NEAR_FINISH_PROGRESS) -> bool:
	return current_progress >= threshold

# ----------------------
# Milestone Tracking
# ----------------------

func _check_milestones() -> void:
	for i in range(last_milestone_index + 1, milestones.size()):
		if current_progress >= milestones[i]:
			last_milestone_index = i
			milestone_reached.emit(milestones[i])

## Reset milestone tracking
func reset_milestones() -> void:
	last_milestone_index = -1

# ----------------------
# Internal
# ----------------------

func _emit_progress() -> void:
	progress_updated.emit(current_progress, get_metrics())

## Get progress metrics
func get_metrics() -> Dictionary:
	return {
		"progress": current_progress,
		"distance_traveled": distance_traveled,
		"remaining_distance": get_remaining_distance(),
		"total_distance": total_distance,
		"elapsed_time": get_elapsed_time(),
		"average_speed": get_average_speed()
	}

# ----------------------
# Debug
# ----------------------

func get_tracking_info() -> Dictionary:
	return get_metrics().duplicate()
