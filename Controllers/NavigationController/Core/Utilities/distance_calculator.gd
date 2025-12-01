extends Node
class_name DistanceCalculator

"""
Utility functions for distance calculations and conversions.

Design notes:
- Pure static utility functions
- No state, no dependencies
- Used across all navigation components
"""

# ----------------------
# Distance Calculations
# ----------------------

## Calculate Euclidean distance between two Vector2 points
static func distance_between(a: Vector2, b: Vector2) -> int:
	return int(a.distance_to(b))

## Calculate squared distance (faster than distance_between, useful for comparisons)
static func distance_squared_between(a: Vector2, b: Vector2) -> int:
	return int(a.distance_squared_to(b))

## Calculate total distance along a path of Vector2 points
static func path_distance(path: Array[Vector2]) -> int:
	if path.size() < 2:
		return 0

	var total: int = 0
	for i in range(path.size() - 1):
		total += int(path[i].distance_to(path[i + 1]))
	return total

## Calculate distance from start to a specific index in path
static func distance_to_index(path: Array[Vector2], index: int) -> int:
	if index < 0 or index >= path.size():
		return 0

	var total: int = 0
	for i in range(index):
		total += int(path[i].distance_to(path[i + 1]))
	return total

# ----------------------
# Unit Conversions
# ----------------------

## Convert meters to pixels (using standard conversion factor)
static func meters_to_pixels(meters: int) -> int:
	return meters * 32 # PIXELS_PER_METER

## Convert pixels to meters
static func pixels_to_meters(pixels: int) -> int:
	return pixels / 32 # PIXELS_PER_METER

# ----------------------
# Distance Checks
# ----------------------

## Check if two points are within a certain distance
static func is_within_distance(a: Vector2, b: Vector2, max_distance: int) -> bool:
	return a.distance_squared_to(b) <= max_distance * max_distance

## Check if a point is near arrival (within threshold)
static func is_near_arrival(current: Vector2, target: Vector2, arrival_threshold: int = 5) -> bool:
	return is_within_distance(current, target, arrival_threshold)

## Find the closest point in a path to a given position
static func find_closest_point_index(path: Array[Vector2], position: Vector2) -> int:
	if path.is_empty():
		return -1

	var closest_index: int = 0
	var closest_distance: int = int(position.distance_squared_to(path[0]))

	for i in range(1, path.size()):
		var dist: int = int(position.distance_squared_to(path[i]))
		if dist < closest_distance:
			closest_distance = dist
			closest_index = i

	return closest_index
