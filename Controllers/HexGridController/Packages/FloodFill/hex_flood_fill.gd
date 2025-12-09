class_name HexFloodFill
extends RefCounted

# Dijkstra-based flood fill algorithm for hexagonal grids
# Finds all reachable cells within a cost limit with optional filtering
# Uses BFS with uniform cost (1 per step) for efficient area calculation
#
# Usage:
#   var flood_fill := HexFloodFill.new()
#   var result := flood_fill.flood_fill(start_cell, hex_grid, max_cost)
#   for cell in result.cells:
#       process_cell(cell, result.costs[cell])

# ============================================================================
# PUBLIC API
# ============================================================================

# Flood fill from start cell within max_cost, optionally filtering cells
# Returns dictionary with 'cells' array and 'costs' dictionary
# Filter signature: func(cell: HexCell) -> bool (return true to include)
func flood_fill(
	start: HexCell,
	hex_grid: HexGrid,
	max_cost: int,
	filter: Callable = Callable()
) -> Dictionary:
	if not _validate_inputs(start, hex_grid, max_cost):
		return _empty_result()

	# Check if filter rejects start cell
	if filter.is_valid() and not filter.call(start):
		return _empty_result()

	# Initialize data structures
	var reachable: Array[HexCell] = []
	var costs: Dictionary = {}
	var frontier: Array[HexCell] = []

	# Add start cell
	reachable.append(start)
	costs[start] = 0
	frontier.append(start)

	# BFS with cost tracking
	while not frontier.is_empty():
		var current: HexCell = frontier.pop_front()
		var current_cost: int = costs[current]

		# Stop expanding if at max cost
		if current_cost >= max_cost:
			continue

		# Explore neighbors
		for neighbor in hex_grid.get_enabled_neighbors(current):
			var new_cost := current_cost + 1

			# Check if we should visit this cell
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				# Apply filter if provided
				if filter.is_valid() and not filter.call(neighbor):
					continue

				# Update cost
				costs[neighbor] = new_cost

				# Add to reachable if new
				if neighbor not in reachable:
					reachable.append(neighbor)

				# Add to frontier
				frontier.append(neighbor)

	return {
		"cells": reachable,
		"costs": costs
	}


# Simplified API - returns only cells array
# Useful when you only need the cells, not the costs
func get_reachable_cells(
	start: HexCell,
	hex_grid: HexGrid,
	max_cost: int,
	filter: Callable = Callable()
) -> Array[HexCell]:
	var result := flood_fill(start, hex_grid, max_cost, filter)
	return result.cells


# Get all cells that have exactly the specified cost
# Useful for creating range rings or distance-based zones
# Example: get_cells_at_cost(result, 3) returns all cells at distance 3
func get_cells_at_cost(flood_result: Dictionary, cost: int) -> Array[HexCell]:
	var cells_at_cost: Array[HexCell] = []

	if not flood_result.has("costs"):
		if OS.is_debug_build():
			push_warning("HexFloodFill: Invalid flood_result dictionary (missing 'costs')")
		return cells_at_cost

	var costs: Dictionary = flood_result.costs

	for cell in costs:
		if costs[cell] == cost:
			cells_at_cost.append(cell)

	return cells_at_cost


# Get all cells within a cost range (inclusive)
# Useful for creating zones or layers based on distance
# Example: get_cells_in_cost_range(result, 0, 2) returns cells at cost 0, 1, or 2
func get_cells_in_cost_range(
	flood_result: Dictionary,
	min_cost: int,
	max_cost: int
) -> Array[HexCell]:
	var cells_in_range: Array[HexCell] = []

	if not flood_result.has("costs"):
		if OS.is_debug_build():
			push_warning("HexFloodFill: Invalid flood_result dictionary (missing 'costs')")
		return cells_in_range

	var costs: Dictionary = flood_result.costs

	for cell in costs:
		var cell_cost: int = costs[cell]
		if cell_cost >= min_cost and cell_cost <= max_cost:
			cells_in_range.append(cell)

	return cells_in_range


# ============================================================================
# PRIVATE HELPERS
# ============================================================================

# Validate inputs before running flood fill
func _validate_inputs(start: HexCell, hex_grid: HexGrid, max_cost: int) -> bool:
	if not start:
		if OS.is_debug_build():
			push_warning("HexFloodFill: Start cell is null")
		return false

	if not hex_grid:
		if OS.is_debug_build():
			push_warning("HexFloodFill: HexGrid is null")
		return false

	if max_cost < 0:
		if OS.is_debug_build():
			push_warning("HexFloodFill: max_cost must be >= 0 (got %d)" % max_cost)
		return false

	if not start.enabled:
		if OS.is_debug_build():
			push_warning("HexFloodFill: Start cell is not enabled")
		return false

	return true


# Return empty result dictionary
func _empty_result() -> Dictionary:
	return {
		"cells": [],
		"costs": {}
	}
