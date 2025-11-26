class_name HexPathfinder
extends Node

## A* pathfinding for hexagonal grid

signal path_found(path: Array[HexCell])
signal path_failed(start: HexCell, goal: HexCell)

@export var hex_grid: HexGrid
@export var diagonal_cost := 1.0

var _open_set: Array[HexCell] = []
var _closed_set := {}
var _came_from := {}
var _g_score := {}
var _f_score := {}

func find_path(start: HexCell, goal: HexCell) -> Array[HexCell]:
	if not _validate_pathfinding(start, goal):
		return []
	
	_reset_state()
	_initialize_start(start, goal)
	
	return _execute_astar(start, goal)

func _validate_pathfinding(start: HexCell, goal: HexCell) -> bool:
	if not hex_grid:
		push_error("HexPathfinder: No HexGrid assigned")
		return false
	
	if not start or not goal:
		push_error("HexPathfinder: Invalid start or goal cell")
		return false
	
	if not start.enabled or not goal.enabled:
		if OS.is_debug_build():
			push_warning("HexPathfinder: Start or goal disabled")
		return false
	
	return true

func _reset_state() -> void:
	_open_set.clear()
	_closed_set.clear()
	_came_from.clear()
	_g_score.clear()
	_f_score.clear()

func _initialize_start(start: HexCell, goal: HexCell) -> void:
	_open_set.append(start)
	_g_score[start] = 0.0
	_f_score[start] = _heuristic(start, goal)

func _execute_astar(start: HexCell, goal: HexCell) -> Array[HexCell]:
	while not _open_set.is_empty():
		var current := _get_lowest_f_score()
		
		if current == goal:
			var path := _reconstruct_path(goal)
			path_found.emit(path)
			return path
		
		_open_set.erase(current)
		_closed_set[current] = true
		
		_process_neighbors(current, goal)
	
	path_failed.emit(start, goal)
	return []

func _process_neighbors(current: HexCell, goal: HexCell) -> void:
	for neighbor in hex_grid.get_enabled_neighbors(current):
		if _closed_set.has(neighbor):
			continue
		
		var tentative: int = _g_score[current] + _movement_cost(current, neighbor)
		
		if neighbor not in _open_set:
			_open_set.append(neighbor)
		elif tentative >= _g_score.get(neighbor, INF):
			continue
		
		_came_from[neighbor] = current
		_g_score[neighbor] = tentative
		_f_score[neighbor] = tentative + _heuristic(neighbor, goal)

func find_path_world(start_pos: Vector2, goal_pos: Vector2) -> Array[HexCell]:
	if not hex_grid:
		return []
	
	var start_cell := hex_grid.get_cell_at_world_position(start_pos)
	var goal_cell := hex_grid.get_cell_at_world_position(goal_pos)
	return find_path(start_cell, goal_cell)

func find_path_to_range(start: HexCell, goal: HexCell, range_cells: int) -> Array[HexCell]:
	if not hex_grid or not start or not goal:
		return []
	
	var candidates := hex_grid.get_enabled_cells_in_range(goal, range_cells)
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
	if not hex_grid or not start:
		return []
	
	var reachable := [start]
	var visited := {start: 0}
	var frontier := [start]
	
	while not frontier.is_empty():
		var current: HexCell = frontier.pop_front()
		var cost: int = visited[current]
		
		if cost >= movement_points:
			continue
		
		for neighbor in hex_grid.get_enabled_neighbors(current):
			var new_cost := cost + 1
			
			if not visited.has(neighbor) or new_cost < visited[neighbor]:
				visited[neighbor] = new_cost
				frontier.append(neighbor)
				if neighbor not in reachable:
					reachable.append(neighbor)
	
	return reachable

func _get_lowest_f_score() -> HexCell:
	var best := _open_set[0]
	var best_score: int = _f_score.get(best, INF)
	
	for cell in _open_set:
		var score: int = _f_score.get(cell, INF)
		if score < best_score:
			best = cell
			best_score = score
	
	return best

func _heuristic(from: HexCell, to: HexCell) -> float:
	return float(from.distance_to(to))

func _movement_cost(_from: HexCell, _to: HexCell) -> float:
	return diagonal_cost

func _reconstruct_path(goal: HexCell) -> Array[HexCell]:
	var path: Array[HexCell] = [goal]
	var current := goal
	
	while _came_from.has(current):
		current = _came_from[current]
		path.insert(0, current)
	
	return path

# Debug utilities
func get_pathfinding_stats() -> Dictionary:
	return {
		"open_set_size": _open_set.size(),
		"closed_set_size": _closed_set.size(),
		"nodes_evaluated": _closed_set.size(),
		"path_stored": not _came_from.is_empty()
	}