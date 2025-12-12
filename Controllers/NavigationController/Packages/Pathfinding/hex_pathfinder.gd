class_name HexPathfinder
extends Node

## A* pathfinding for hexagonal grid
##
## Refactored to use Core components for better organization and reusability.
## Delegates core algorithm to AStarPathfinder from Core/Algorithms.

signal path_found(path: Array[HexCell])
signal path_failed(start: HexCell, goal: HexCell)

@export var hex_grid: HexGrid  # DEPRECATED - use via session_controller
@export var diagonal_cost := 1.0

# API reference (preferred over direct hex_grid access)
var session_controller = null

# Core components
var _astar: AStarPathfinder = null

func _ready() -> void:
	# Initialize core pathfinding component
	_astar = AStarPathfinder.new()
	add_child(_astar)

# ============================================================================
# PUBLIC API
# ============================================================================

func find_path(start: HexCell, goal: HexCell) -> Array[HexCell]:
	if not PathValidator.are_cells_valid(start, goal):
		if OS.is_debug_build():
			push_warning("HexPathfinder: Invalid start or goal cell")
		path_failed.emit(start, goal)
		return []

	if not session_controller:
		push_error("HexPathfinder: SessionController is required")
		path_failed.emit(start, goal)
		return []

	# Use core A* algorithm with SessionController as grid_provider
	var path := _astar.find_path(start, goal, session_controller, diagonal_cost)

	if path.is_empty():
		path_failed.emit(start, goal)
		return []

	path_found.emit(path)
	return path

func find_path_world(start_pos: Vector2, goal_pos: Vector2) -> Array[HexCell]:
	if not session_controller:
		push_error("HexPathfinder: SessionController is required")
		return []

	var start_cell: HexCell = session_controller.get_cell_at_world_position(start_pos)
	var goal_cell: HexCell = session_controller.get_cell_at_world_position(goal_pos)

	return find_path(start_cell, goal_cell)

func find_path_to_range(start: HexCell, goal: HexCell, range_cells: int) -> Array[HexCell]:
	if not session_controller:
		push_error("HexPathfinder: SessionController is required")
		return []

	if not PathValidator.is_cell_valid(start) or not PathValidator.is_cell_valid(goal):
		return []

	var candidates: Array[HexCell] = session_controller.get_enabled_cells_in_range(goal, range_cells)
	if candidates.is_empty():
		return []

	var best_path: Array[HexCell] = []
	var shortest := INF

	for target in candidates:
		if target == start:
			return [start]

		var path := find_path(start, target)
		if path.is_empty():
			continue

		if path.size() < shortest:
			shortest = path.size()
			best_path = path

	return best_path

func is_path_clear(start: HexCell, goal: HexCell) -> bool:
	return not find_path(start, goal).is_empty()

func get_path_length(path: Array[HexCell]) -> int:
	return max(path.size() - 1, 0)

func get_cells_in_movement_range(start: HexCell, movement_points: int) -> Array[HexCell]:
	if not session_controller:
		push_error("HexPathfinder: SessionController is required")
		return []

	if not PathValidator.is_cell_valid(start):
		return []

	var reachable := [start]
	var visited := {start: 0}
	var frontier := [start]

	while not frontier.is_empty():
		var current: HexCell = frontier.pop_front()
		var cost: int = visited[current]

		if cost >= movement_points:
			continue

		for neighbor in session_controller.get_enabled_neighbors(current):
			var new_cost := cost + 1

			if not visited.has(neighbor) or new_cost < visited[neighbor]:
				visited[neighbor] = new_cost
				frontier.append(neighbor)
				if neighbor not in reachable:
					reachable.append(neighbor)

	return reachable

# ============================================================================
# DEBUG UTILITIES
# ============================================================================

func get_pathfinding_stats() -> Dictionary:
	if _astar:
		return _astar.get_stats()

	return {
		"open_set_size": 0,
		"closed_set_size": 0,
		"nodes_evaluated": 0,
		"path_stored": false
	}
