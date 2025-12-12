extends Node
class_name AStarPathfinder

# Core A* pathfinding algorithm for hexagonal grids.
#
# Design notes:
# - Pure algorithm implementation
# - Stateless between calls (resets state on each pathfind)
# - Uses heuristics and path reconstruction from separate utilities
# - Can be used independently of navigation controllers

# ----------------------
# State (reset between pathfinding operations)
# ----------------------

var _open_set: Array[HexCell] = []
var _closed_set := {}
var _came_from := {}
var _g_score := {}
var _f_score := {}

# ----------------------
# Core A* Algorithm
# ----------------------

## Execute A* pathfinding from start to goal
## Accepts grid_provider (SessionController or HexGrid) for API compliance
func find_path(start: HexCell, goal: HexCell, grid_provider, movement_cost: float = 1.0) -> Array[HexCell]:
	# Extract actual grid for performance - avoids hundreds of indirect calls in A* loop
	var hex_grid: HexGrid = null
	if grid_provider.has_method("get_hex_grid_for_pathfinding"):
		hex_grid = grid_provider.get_hex_grid_for_pathfinding()
	elif grid_provider is HexGrid:
		hex_grid = grid_provider

	if not _validate_pathfinding(start, goal, hex_grid):
		return []

	_reset_state()
	_initialize_start(start, goal)

	return _execute_astar(goal, hex_grid, movement_cost)

## Execute A* algorithm main loop
func _execute_astar(goal: HexCell, hex_grid: HexGrid, movement_cost: float) -> Array[HexCell]:
	while not _open_set.is_empty():
		var current := _get_lowest_f_score()

		if current == goal:
			return PathReconstructor.reconstruct_path(goal, _came_from)

		_open_set.erase(current)
		_closed_set[current] = true

		_process_neighbors(current, goal, hex_grid, movement_cost)

	# No path found
	return []

## Process all neighbors of current cell
func _process_neighbors(current: HexCell, goal: HexCell, hex_grid: HexGrid, movement_cost: float) -> void:
	for neighbor in hex_grid.get_enabled_neighbors(current):
		if _closed_set.has(neighbor):
			continue

		var tentative: float = _g_score[current] + movement_cost

		if neighbor not in _open_set:
			_open_set.append(neighbor)
		elif tentative >= _g_score.get(neighbor, INF):
			continue

		_came_from[neighbor] = current
		_g_score[neighbor] = tentative
		_f_score[neighbor] = tentative + Heuristics.hex_distance(neighbor, goal)

# ----------------------
# State Management
# ----------------------

## Reset all internal state
func _reset_state() -> void:
	_open_set.clear()
	_closed_set.clear()
	_came_from.clear()
	_g_score.clear()
	_f_score.clear()

## Initialize starting cell
func _initialize_start(start: HexCell, goal: HexCell) -> void:
	_open_set.append(start)
	_g_score[start] = 0.0
	_f_score[start] = Heuristics.hex_distance(start, goal)

# ----------------------
# Internal Utilities
# ----------------------

## Get cell with lowest f_score from open set
func _get_lowest_f_score() -> HexCell:
	var best := _open_set[0]
	var best_score: float = _f_score.get(best, INF)

	for cell in _open_set:
		var score: float = _f_score.get(cell, INF)
		if score < best_score:
			best = cell
			best_score = score

	return best

## Validate pathfinding inputs
func _validate_pathfinding(start: HexCell, goal: HexCell, hex_grid: HexGrid) -> bool:
	if not hex_grid:
		push_error("AStarPathfinder: No HexGrid provided")
		return false

	if not start or not goal:
		push_error("AStarPathfinder: Invalid start or goal cell")
		return false

	if not start.enabled or not goal.enabled:
		if OS.is_debug_build():
			push_warning("AStarPathfinder: Start or goal disabled")
		return false

	return true

# ----------------------
# Debug Utilities
# ----------------------

## Get current pathfinding statistics
func get_stats() -> Dictionary:
	return {
		"open_set_size": _open_set.size(),
		"closed_set_size": _closed_set.size(),
		"nodes_evaluated": _closed_set.size(),
		"path_stored": not _came_from.is_empty()
	}
