extends Node
class_name PathReconstructor

"""
Utility functions for reconstructing paths from pathfinding algorithms.

Design notes:
- Pure static utility functions
- No state, no dependencies
- Reconstructs paths from came_from dictionaries produced by A*
"""

# ----------------------
# Path Reconstruction
# ----------------------

## Reconstruct path from goal using came_from dictionary
static func reconstruct_path(goal: HexCell, came_from: Dictionary) -> Array[HexCell]:
	var path: Array[HexCell] = [goal]
	var current := goal

	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)

	return path

## Reconstruct path and convert to world positions
static func reconstruct_path_world(goal: HexCell, came_from: Dictionary) -> Array[Vector2]:
	var hex_path := reconstruct_path(goal, came_from)
	var world_path: Array[Vector2] = []

	for cell in hex_path:
		world_path.append(cell.world_position)

	return world_path

## Reconstruct partial path up to a certain cell
static func reconstruct_partial_path(target: HexCell, came_from: Dictionary, max_length: int = -1) -> Array[HexCell]:
	var path: Array[HexCell] = [target]
	var current := target
	var count: int = 1

	while came_from.has(current):
		if max_length > 0 and count >= max_length:
			break

		current = came_from[current]
		path.insert(0, current)
		count += 1

	return path

# ----------------------
# Path Validation
# ----------------------

## Verify that a reconstructed path is valid
static func is_path_valid(path: Array[HexCell]) -> bool:
	if path.is_empty():
		return false

	# Check that all cells are valid
	for cell in path:
		if cell == null or not cell.enabled:
			return false

	return true

## Get path without start cell (useful for movement)
static func path_without_start(path: Array[HexCell]) -> Array[HexCell]:
	if path.size() <= 1:
		return []

	var result: Array[HexCell] = []
	for i in range(1, path.size()):
		result.append(path[i])

	return result

# ----------------------
# Path Transformation
# ----------------------

## Reverse a path
static func reverse_path(path: Array[HexCell]) -> Array[HexCell]:
	var reversed: Array[HexCell] = []
	for i in range(path.size() - 1, -1, -1):
		reversed.append(path[i])
	return reversed

## Get waypoints from path (every Nth cell)
static func get_waypoints(path: Array[HexCell], interval: int = 3) -> Array[HexCell]:
	if path.is_empty():
		return []

	var waypoints: Array[HexCell] = [path[0]] # Always include start

	for i in range(interval, path.size(), interval):
		waypoints.append(path[i])

	# Always include goal if not already included
	if waypoints[-1] != path[-1]:
		waypoints.append(path[-1])

	return waypoints

## Smooth path by removing redundant waypoints
static func smooth_path(path: Array[HexCell], hex_grid: HexGrid) -> Array[HexCell]:
	if path.size() <= 2:
		return path

	var smoothed: Array[HexCell] = [path[0]]
	var current_index: int = 0

	while current_index < path.size() - 1:
		var farthest_visible: int = current_index + 1

		# Find farthest cell we can see from current
		for i in range(current_index + 2, path.size()):
			if _is_line_of_sight(path[current_index], path[i], hex_grid):
				farthest_visible = i

		smoothed.append(path[farthest_visible])
		current_index = farthest_visible

	return smoothed

## Check if there's line of sight between two cells
static func _is_line_of_sight(from: HexCell, to: HexCell, hex_grid: HexGrid) -> bool:
	# Simple implementation - can be improved with Bresenham's line algorithm
	var neighbors := hex_grid.get_enabled_neighbors(from)

	if to in neighbors:
		return true

	# For now, only adjacent cells have line of sight
	# A more sophisticated implementation would check intermediate cells
	return false
