class_name BoundaryTracer
extends RefCounted

# Detects and orders boundary cells using wall-following algorithm
# Uses right-hand rule to trace the contour of navigable areas
# Produces consistently ordered boundary cells for smooth curve generation

# Get all boundary cells (cells with at least one non-navigable neighbor)
# navigable_cells: Array of all navigable HexCell objects
# navigable_set: Dictionary for O(1) lookup (Vector2i -> bool or HexCell)
# Returns: Array of boundary HexCell objects
func get_boundary_cells(navigable_cells: Array[HexCell], navigable_set: Dictionary) -> Array[HexCell]:
	var boundary: Array[HexCell] = []

	for cell in navigable_cells:
		if _is_boundary_cell(cell, navigable_set):
			boundary.append(cell)

	return boundary


# Order boundary cells into a contour using wall-following algorithm
# Uses right-hand rule for consistent, clockwise traversal
# boundary_cells: Unordered array of boundary cells
# Returns: Ordered array of boundary cells forming a contour
func trace_boundary(boundary_cells: Array[HexCell]) -> Array[HexCell]:
	if boundary_cells.size() < 3:
		return boundary_cells.duplicate()

	# Build lookup dictionary for O(1) boundary cell checking
	var boundary_set: Dictionary = {}
	for cell in boundary_cells:
		boundary_set[Vector2i(cell.q, cell.r)] = cell

	# Start from topmost-leftmost cell for consistent ordering
	var start_cell := _find_start_cell(boundary_cells)

	# Trace the boundary using wall-following
	var ordered := _follow_wall(start_cell, boundary_set, boundary_cells)

	return ordered


# Check if a cell is on the boundary (has at least one non-navigable neighbor)
func _is_boundary_cell(cell: HexCell, navigable_set: Dictionary) -> bool:
	var cell_coords := Vector2i(cell.q, cell.r)

	for dir in HexDirections.FLAT_TOP_DIRECTIONS:
		var neighbor_coords := cell_coords + dir
		if not navigable_set.has(neighbor_coords):
			return true

	return false


# Find the starting cell for boundary tracing
# Chooses the topmost-leftmost cell for consistent ordering
func _find_start_cell(boundary_cells: Array[HexCell]) -> HexCell:
	var start_cell: HexCell = boundary_cells[0]

	for cell in boundary_cells:
		# Prioritize topmost (lowest Y), then leftmost (lowest X)
		if cell.world_position.y < start_cell.world_position.y or \
		   (cell.world_position.y == start_cell.world_position.y and \
		    cell.world_position.x < start_cell.world_position.x):
			start_cell = cell

	return start_cell


# Follow the wall using right-hand rule to order boundary cells
# start: Starting boundary cell
# boundary_set: Dictionary mapping Vector2i coords to HexCell objects
# boundary_cells: Full array of boundary cells (for fallback)
# Returns: Ordered array of boundary cells
func _follow_wall(start: HexCell, boundary_set: Dictionary, boundary_cells: Array[HexCell]) -> Array[HexCell]:
	var ordered: Array[HexCell] = []
	var visited: Dictionary = {}

	var current: HexCell = start
	ordered.append(current)
	visited[Vector2i(current.q, current.r)] = true

	# Start by trying to go right (direction 0)
	var last_dir_index := 0

	# Trace boundary until all cells visited
	while ordered.size() < boundary_cells.size():
		var next_result := _find_next_cell_wall_following(current, boundary_set, visited, last_dir_index)

		if next_result.cell == null:
			# Wall following failed - use nearest unvisited as fallback
			var next_cell := _find_nearest_unvisited(current, boundary_cells, visited)
			if next_cell == null:
				break  # No more cells to visit

			ordered.append(next_cell)
			visited[Vector2i(next_cell.q, next_cell.r)] = true
			current = next_cell
			last_dir_index = 0  # Reset direction
		else:
			# Successfully found next cell via wall-following
			ordered.append(next_result.cell)
			visited[Vector2i(next_result.cell.q, next_result.cell.r)] = true
			current = next_result.cell
			last_dir_index = next_result.direction

	return ordered


# Find next boundary cell using right-hand rule
# current: Current cell
# boundary_set: Lookup dictionary for boundary cells
# visited: Dictionary tracking visited cells
# from_dir: Direction we arrived from (0-5)
# Returns: Dictionary with {cell: HexCell, direction: int} or {cell: null}
func _find_next_cell_wall_following(current: HexCell, boundary_set: Dictionary,
									 visited: Dictionary, from_dir: int) -> Dictionary:
	var current_coords := Vector2i(current.q, current.r)

	# Right-hand rule: When arriving from direction D, turn right sharply
	# This ensures we follow the outer boundary contour
	var opposite_dir := (from_dir + 3) % 6  # Opposite of arrival direction
	var start_search_dir := (opposite_dir + 2) % 6  # Turn right from opposite

	# Try each direction in clockwise order (right-hand rule)
	for i in range(6):
		var try_dir := (start_search_dir + i) % 6
		var neighbor_coords := current_coords + HexDirections.FLAT_TOP_DIRECTIONS[try_dir]

		# Check if neighbor is a boundary cell and not yet visited
		if boundary_set.has(neighbor_coords) and not visited.has(neighbor_coords):
			return {
				"cell": boundary_set[neighbor_coords],
				"direction": try_dir
			}

	# No valid next cell found
	return {"cell": null}


# Find nearest unvisited boundary cell (fallback when wall-following fails)
# current: Current cell
# boundary_cells: All boundary cells
# visited: Dictionary tracking visited cells
# Returns: Nearest unvisited HexCell or null
func _find_nearest_unvisited(current: HexCell, boundary_cells: Array[HexCell],
							  visited: Dictionary) -> HexCell:
	var nearest: HexCell = null
	var nearest_dist := INF

	for cell in boundary_cells:
		var coords := Vector2i(cell.q, cell.r)
		if visited.has(coords):
			continue

		var dist := current.world_position.distance_squared_to(cell.world_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = cell

	return nearest
