extends Node
class_name PathValidator

"""
Utility functions for path validation.

Design notes:
- Pure static utility functions for validating paths
- No state, no dependencies
- Used by pathfinding and navigation components
"""

# ----------------------
# Path Validation
# ----------------------

## Check if a path is valid (not empty and has at least 2 points)
static func is_path_valid(path: Array) -> bool:
	return path != null and path.size() >= 2

## Check if a path is empty
static func is_path_empty(path: Array) -> bool:
	return path == null or path.is_empty()

## Check if a hex cell is valid for pathfinding
static func is_cell_valid(cell: HexCell) -> bool:
	return cell != null and cell.enabled

## Check if both start and goal cells are valid
static func are_cells_valid(start: HexCell, goal: HexCell) -> bool:
	return is_cell_valid(start) and is_cell_valid(goal)

## Check if a path exceeds maximum distance
static func exceeds_max_distance(path: Array[Vector2], max_distance: int) -> bool:
	if max_distance < 0:
		return false # No limit

	var total_distance: int = DistanceCalculator.path_distance(path)
	return total_distance > max_distance

## Check if all cells in a path are enabled
static func all_cells_enabled(path: Array[HexCell]) -> bool:
	if path.is_empty():
		return false

	for cell in path:
		if not is_cell_valid(cell):
			return false
	return true

# ----------------------
# Path Trimming
# ----------------------

## Trim a path to fit within maximum distance, returns trimmed path
static func trim_path_to_distance(path: Array[Vector2], max_distance: int) -> Array[Vector2]:
	if path.is_empty() or max_distance < 0:
		return path

	var result: Array[Vector2] = []
	var accumulated_distance: int = 0

	result.append(path[0])

	for i in range(1, path.size()):
		var segment_distance: int = int(path[i - 1].distance_to(path[i]))

		if accumulated_distance + segment_distance <= max_distance:
			# Can include entire segment
			result.append(path[i])
			accumulated_distance += segment_distance
		else:
			# Need to interpolate the final point
			var remaining_distance: int = max_distance - accumulated_distance
			var t: float = float(remaining_distance) / float(segment_distance)
			var final_point: Vector2 = path[i - 1].lerp(path[i], t)
			result.append(final_point)
			break

	return result

## Get the index where a path would exceed max distance
static func get_max_distance_index(path: Array[Vector2], max_distance: int) -> int:
	if path.is_empty() or max_distance < 0:
		return path.size() - 1

	var accumulated_distance: int = 0

	for i in range(1, path.size()):
		var segment_distance: int = int(path[i - 1].distance_to(path[i]))

		if accumulated_distance + segment_distance > max_distance:
			return i - 1

		accumulated_distance += segment_distance

	return path.size() - 1
