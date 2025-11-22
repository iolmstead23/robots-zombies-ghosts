class_name HexPathfinder
extends Node

## A* Pathfinding for Hexagonal Grid
## Stub implementation ready for completion after grid system is finalized

signal path_found(path: Array[HexCell])
signal path_failed(start: HexCell, goal: HexCell)

@export var hex_grid: HexGrid
@export var diagonal_cost: float = 1.0  ## Cost to move to adjacent hex (always 1 for hex grids)

## Internal pathfinding state
var _open_set: Array[HexCell] = []
var _closed_set: Dictionary = {}  # Key: HexCell, Value: bool
var _came_from: Dictionary = {}   # Key: HexCell, Value: HexCell
var _g_score: Dictionary = {}     # Key: HexCell, Value: float
var _f_score: Dictionary = {}     # Key: HexCell, Value: float

func find_path(start: HexCell, goal: HexCell) -> Array[HexCell]:
	"""
	Find the shortest path from start to goal using A* algorithm
	Returns an array of HexCells representing the path (including start and goal)
	Returns empty array if no path exists
	"""
	
	if not hex_grid:
		push_error("HexPathfinder: No HexGrid assigned")
		return []
	
	if not start or not goal:
		push_error("HexPathfinder: Invalid start or goal cell")
		return []
	
	if not start.enabled or not goal.enabled:
		push_warning("HexPathfinder: Start or goal cell is disabled")
		return []
	
	# Initialize pathfinding state
	_reset_pathfinding_state()
	
	# Add start to open set
	_open_set.append(start)
	_g_score[start] = 0.0
	_f_score[start] = _heuristic(start, goal)
	
	# A* main loop
	while not _open_set.is_empty():
		var current: HexCell = _get_lowest_f_score_cell()
		
		# Goal reached
		if current == goal:
			var path := _reconstruct_path(current)
			path_found.emit(path)
			return path
		
		# Move current from open to closed
		_open_set.erase(current)
		_closed_set[current] = true
		
		# Process neighbors
		var neighbors := hex_grid.get_enabled_neighbors(current)
		for neighbor in neighbors:
			if _closed_set.has(neighbor):
				continue  # Already evaluated
			
			# Calculate tentative g_score
			var tentative_g_score: float = _g_score[current] + _movement_cost(current, neighbor)
			
			# Discover new node or found better path
			if not neighbor in _open_set:
				_open_set.append(neighbor)
			elif tentative_g_score >= _g_score.get(neighbor, INF):
				continue  # Not a better path
			
			# This is the best path so far, record it
			_came_from[neighbor] = current
			_g_score[neighbor] = tentative_g_score
			_f_score[neighbor] = tentative_g_score + _heuristic(neighbor, goal)
	
	# No path found
	path_failed.emit(start, goal)
	return []

func find_path_world(start_pos: Vector2, goal_pos: Vector2) -> Array[HexCell]:
	"""Find path between two world positions"""
	if not hex_grid:
		return []
	
	var start_cell := hex_grid.get_cell_at_world_position(start_pos)
	var goal_cell := hex_grid.get_cell_at_world_position(goal_pos)
	
	return find_path(start_cell, goal_cell)

func find_path_to_range(start: HexCell, goal: HexCell, range_cells: int) -> Array[HexCell]:
	"""
	Find path to get within 'range' cells of the goal
	Useful for ranged attacks or interactions
	"""
	if not hex_grid or not start or not goal:
		return []
	
	# Get all enabled cells within range of goal
	var valid_targets := hex_grid.get_enabled_cells_in_range(goal, range_cells)
	
	if valid_targets.is_empty():
		return []
	
	# Find the closest reachable cell to start
	var best_path: Array[HexCell] = []
	var shortest_distance: float = INF
	
	for target in valid_targets:
		if target == start:
			return [start]  # Already in range
		
		var path := find_path(start, target)
		if not path.is_empty():
			var path_length: float = path.size()
			if path_length < shortest_distance:
				shortest_distance = path_length
				best_path = path
	
	return best_path

func is_path_clear(start: HexCell, goal: HexCell) -> bool:
	"""Check if there's a valid path between two cells"""
	var path := find_path(start, goal)
	return not path.is_empty()

func get_path_length(path: Array[HexCell]) -> int:
	"""Get the length of a path in meters/cells"""
	if path.is_empty():
		return 0
	return path.size() - 1  # Don't count the starting cell

func _reset_pathfinding_state() -> void:
	"""Clear all pathfinding data structures"""
	_open_set.clear()
	_closed_set.clear()
	_came_from.clear()
	_g_score.clear()
	_f_score.clear()

func _get_lowest_f_score_cell() -> HexCell:
	"""Get the cell with lowest f_score from open set"""
	var lowest_cell: HexCell = _open_set[0]
	var lowest_score: float = _f_score.get(lowest_cell, INF)
	
	for cell in _open_set:
		var score: float = _f_score.get(cell, INF)
		if score < lowest_score:
			lowest_score = score
			lowest_cell = cell
	
	return lowest_cell

func _heuristic(from: HexCell, to: HexCell) -> float:
	"""
	Heuristic function for A*
	Uses hex distance (1 cell = 1 meter) as the heuristic
	This is both admissible and consistent for hex grids
	"""
	return float(from.distance_to(to))

func _movement_cost(from: HexCell, to: HexCell) -> float:
	"""
	Calculate movement cost between two adjacent cells
	Base cost is 1.0 (1 meter per hex)
	Can be extended to include terrain costs from cell metadata
	"""
	var base_cost: float = diagonal_cost
	
	# Example: Add terrain cost from metadata
	# var terrain_cost: float = to.get_metadata("movement_cost", 1.0)
	# return base_cost * terrain_cost
	
	return base_cost

func _reconstruct_path(goal: HexCell) -> Array[HexCell]:
	"""Reconstruct the path from start to goal using came_from map"""
	var path: Array[HexCell] = [goal]
	var current: HexCell = goal
	
	while _came_from.has(current):
		current = _came_from[current]
		path.insert(0, current)
	
	return path

func get_cells_in_movement_range(start: HexCell, movement_points: int) -> Array[HexCell]:
	"""
	Get all cells reachable within movement_points
	Useful for turn-based movement visualization
	"""
	if not hex_grid or not start:
		return []
	
	var reachable: Array[HexCell] = [start]
	var visited: Dictionary = {start: 0}  # Cell: cost to reach
	var frontier: Array[HexCell] = [start]
	
	while not frontier.is_empty():
		var current: HexCell = frontier.pop_front()
		var current_cost: int = visited[current]
		
		if current_cost >= movement_points:
			continue
		
		var neighbors := hex_grid.get_enabled_neighbors(current)
		for neighbor in neighbors:
			var new_cost: int = current_cost + 1
			
			if not visited.has(neighbor) or new_cost < visited[neighbor]:
				visited[neighbor] = new_cost
				frontier.append(neighbor)
				
				if not neighbor in reachable:
					reachable.append(neighbor)
	
	return reachable

## DEBUG HELPERS

func visualize_path(path: Array[HexCell], color: Color = Color.YELLOW) -> void:
	"""Helper to visualize a path (requires custom drawing logic)"""
	if path.is_empty():
		return
	
	print("Path found with %d cells:" % path.size())
	for i in range(path.size()):
		var cell: HexCell = path[i]
		print("  %d: (%d,%d) at %s" % [i, cell.q, cell.r, cell.world_position])

func get_pathfinding_stats() -> Dictionary:
	"""Get statistics about the last pathfinding operation"""
	return {
		"open_set_size": _open_set.size(),
		"closed_set_size": _closed_set.size(),
		"nodes_evaluated": _closed_set.size(),
		"path_stored": not _came_from.is_empty()
	}
