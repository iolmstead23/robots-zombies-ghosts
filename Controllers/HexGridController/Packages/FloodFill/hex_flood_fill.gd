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

# Result container for flood fill operations
# Provides type-safe storage for reachable cells and their costs
class FloodFillResult:
	# Array of all reachable cells
	var cells: Array[HexCell] = []

	# Cost to reach each cell (HexCell -> int mapping)
	var costs: Dictionary = {}

	func _init(p_cells: Array[HexCell] = [], p_costs: Dictionary = {}):
		cells = p_cells
		costs = p_costs

	# Get cells at specific cost
	func get_cells_at_cost(cost: int) -> Array[HexCell]:
		var result: Array[HexCell] = []
		for cell in costs:
			if costs[cell] == cost:
				result.append(cell)
		return result

	# Get cells in cost range (inclusive)
	func get_cells_in_cost_range(min_cost: int, max_cost: int) -> Array[HexCell]:
		var result: Array[HexCell] = []
		for cell in costs:
			var cell_cost: int = costs[cell]
			if cell_cost >= min_cost and cell_cost <= max_cost:
				result.append(cell)
		return result

	# Check if result is empty
	func is_empty() -> bool:
		return cells.is_empty()

	# Get cell count
	func size() -> int:
		return cells.size()

# ============================================================================
# PUBLIC API
# ============================================================================

# Flood fill from start cell within max_cost, optionally filtering cells
# Returns FloodFillResult with reachable cells and their costs
# Filter signature: func(cell: HexCell) -> bool (return true to include)
func flood_fill(
	start: HexCell,
	hex_grid: HexGrid,
	max_cost: int,
	filter: Callable = Callable()
) -> FloodFillResult:
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

	return FloodFillResult.new(reachable, costs)


# Simplified API - returns only cells array
# Useful when you only need the cells, not the costs
func get_reachable_cells(
	start: HexCell,
	hex_grid: HexGrid,
	max_cost: int,
	filter: Callable = Callable()
) -> Array[HexCell]:
	var result: FloodFillResult = flood_fill(start, hex_grid, max_cost, filter)
	return result.cells


# Get all cells that have exactly the specified cost
# Useful for creating range rings or distance-based zones
# Example: get_cells_at_cost(result, 3) returns all cells at distance 3
# NOTE: Deprecated - use FloodFillResult.get_cells_at_cost() instead
func get_cells_at_cost(flood_result: FloodFillResult, cost: int) -> Array[HexCell]:
	return flood_result.get_cells_at_cost(cost)


# Get all cells within a cost range (inclusive)
# Useful for creating zones or layers based on distance
# Example: get_cells_in_cost_range(result, 0, 2) returns cells at cost 0, 1, or 2
# NOTE: Deprecated - use FloodFillResult.get_cells_in_cost_range() instead
func get_cells_in_cost_range(
	flood_result: FloodFillResult,
	min_cost: int,
	max_cost: int
) -> Array[HexCell]:
	return flood_result.get_cells_in_cost_range(min_cost, max_cost)


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


# Return empty result
func _empty_result() -> FloodFillResult:
	return FloodFillResult.new([], {})
