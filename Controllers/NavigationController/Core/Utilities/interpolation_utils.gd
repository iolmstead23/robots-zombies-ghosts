extends Node
class_name InterpolationUtils

"""
Utility functions for path interpolation and progress calculations.

Design notes:
- Pure static utility functions for interpolation
- No state, no dependencies
- Used by movement controllers for smooth path following
"""

# ----------------------
# Path Interpolation
# ----------------------

## Get position along path based on progress (0.0 to 1.0)
static func get_position_at_progress(path: Array[Vector2], progress: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO

	if path.size() == 1:
		return path[0]

	# Clamp progress
	progress = clamp(progress, 0.0, 1.0)

	# Calculate total path distance
	var total_distance: int = DistanceCalculator.path_distance(path)
	if total_distance <= 0:
		return path[0]

	# Find target distance along path
	var target_distance: int = int(progress * total_distance)

	# Traverse path to find interpolation point
	var accumulated_distance: int = 0
	for i in range(path.size() - 1):
		var segment_distance: int = int(path[i].distance_to(path[i + 1]))

		# Skip zero-length segments (identical consecutive points)
		if segment_distance == 0:
			continue

		if accumulated_distance + segment_distance >= target_distance:
			# Found the segment containing our target
			var segment_progress: float = float(target_distance - accumulated_distance) / float(segment_distance)
			return path[i].lerp(path[i + 1], segment_progress)

		accumulated_distance += segment_distance

	# If we reached here, return the last point
	return path[-1]

## Get position at a specific distance along path
static func get_position_at_distance(path: Array[Vector2], distance: int) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO

	if path.size() == 1:
		return path[0]

	if distance <= 0:
		return path[0]

	var accumulated_distance: int = 0
	for i in range(path.size() - 1):
		var segment_distance: int = int(path[i].distance_to(path[i + 1]))

		# Skip zero-length segments (identical consecutive points)
		if segment_distance == 0:
			continue

		if accumulated_distance + segment_distance >= distance:
			var segment_progress: float = float(distance - accumulated_distance) / float(segment_distance)
			return path[i].lerp(path[i + 1], segment_progress)

		accumulated_distance += segment_distance

	return path[-1]

## Calculate progress (0.0 to 1.0) based on current position along path
static func get_progress_from_position(path: Array[Vector2], position: Vector2) -> float:
	if path.is_empty():
		return 0.0

	var total_distance: int = DistanceCalculator.path_distance(path)
	if total_distance <= 0:
		return 1.0

	var closest_index: int = DistanceCalculator.find_closest_point_index(path, position)
	var distance_to_closest: int = DistanceCalculator.distance_to_index(path, closest_index)

	return clamp(float(distance_to_closest) / float(total_distance), 0.0, 1.0)

# ----------------------
# Segment Interpolation
# ----------------------

## Interpolate between two points with easing
static func lerp_smooth(a: Vector2, b: Vector2, t: float) -> Vector2:
	# Smooth step easing
	t = clamp(t, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return a.lerp(b, t)

## Cubic interpolation between points
static func cubic_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t

	var x: float = 0.5 * (
		(2.0 * p1.x) +
		(-p0.x + p2.x) * t +
		(2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 +
		(-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3
	)

	var y: float = 0.5 * (
		(2.0 * p1.y) +
		(-p0.y + p2.y) * t +
		(2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * t2 +
		(-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * t3
	)

	return Vector2(x, y)

# ----------------------
# Progress Utilities
# ----------------------

## Increment progress based on speed and delta time
static func update_progress(current_progress: float, speed: int, total_distance: int, delta: float) -> float:
	if total_distance <= 0:
		return 1.0

	var distance_increment: float = speed * delta
	var progress_increment: float = distance_increment / float(total_distance)

	return clamp(current_progress + progress_increment, 0.0, 1.0)

## Check if progress is near completion
static func is_near_completion(progress: float, threshold: float = 0.99) -> bool:
	return progress >= threshold
