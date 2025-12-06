class_name HexStringPuller
extends RefCounted

## Utility for creating smooth curves through hex cell boundaries
## Supports both Catmull-Rom spline and Chaikin subdivision algorithms

# ============================================================================
# CURVE METHOD ENUM
# ============================================================================

enum CurveMethod {
	CATMULL_ROM,  # Original - smooth but can overshoot
	CHAIKIN       # Stable - never overshoots, good for boundaries
}

# ============================================================================
# CONFIGURATION
# ============================================================================

## Which curve algorithm to use
var curve_method: CurveMethod = CurveMethod.CHAIKIN

## Number of smoothing iterations (Chaikin) or segments per point (Catmull-Rom)
var smoothing_iterations: int = 2

## Angle threshold for simplification (radians) - points with smaller angle deviation are removed
var simplification_threshold: float = 0.3

# Flat-top hex directions for neighbor checking
const FLAT_TOP_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # Direction 0 (right)
	Vector2i(1, -1),   # Direction 1 (upper-right)
	Vector2i(0, -1),   # Direction 2 (upper-left)
	Vector2i(-1, 0),   # Direction 3 (left)
	Vector2i(-1, 1),   # Direction 4 (lower-left)
	Vector2i(0, 1)     # Direction 5 (lower-right)
]

# ============================================================================
# MAIN API
# ============================================================================

func pull_string(navigable_cells: Array[HexCell], navigable_set: Dictionary) -> PackedVector2Array:
	# Main entry point: generates a smooth boundary curve for the given navigable cells
	if navigable_cells.is_empty():
		return PackedVector2Array()

	# Step 1: Find boundary cells
	var boundary_cells := get_boundary_cells(navigable_cells, navigable_set)
	if boundary_cells.size() < 3:
		# Need at least 3 points for a meaningful curve
		return _points_from_cells(boundary_cells)

	# Step 2: Order cells to form continuous contour (angle-from-centroid)
	var ordered_cells := order_boundary_contour(boundary_cells)

	# Step 3: Generate smooth curve using selected method
	return generate_smooth_curve(ordered_cells)


func pull_string_from_positions(positions: Array[Vector2]) -> PackedVector2Array:
	# Generate smooth curve from arbitrary world positions
	if positions.size() < 3:
		var result := PackedVector2Array()
		for pos in positions:
			result.append(pos)
		return result

	match curve_method:
		CurveMethod.CHAIKIN:
			return _generate_chaikin_curve(positions)
		CurveMethod.CATMULL_ROM:
			return _generate_catmull_rom_curve(positions, true)

	return PackedVector2Array(positions)

# ============================================================================
# CURVE METHOD CONTROL
# ============================================================================

func set_curve_method(method: CurveMethod) -> void:
	curve_method = method


func get_curve_method() -> CurveMethod:
	return curve_method

# ============================================================================
# BOUNDARY DETECTION
# ============================================================================

func get_boundary_cells(navigable_cells: Array[HexCell], navigable_set: Dictionary) -> Array[HexCell]:
	# Find all cells that have at least one non-navigable neighbor (boundary cells)
	var boundary: Array[HexCell] = []

	for cell in navigable_cells:
		if _is_boundary_cell(cell, navigable_set):
			boundary.append(cell)

	return boundary


func _is_boundary_cell(cell: HexCell, navigable_set: Dictionary) -> bool:
	# Check if a cell has at least one non-navigable neighbor
	var cell_coords := Vector2i(cell.q, cell.r)

	for dir in FLAT_TOP_DIRECTIONS:
		var neighbor_coords := cell_coords + dir
		if not navigable_set.has(neighbor_coords):
			return true

	return false

# ============================================================================
# CONTOUR ORDERING - Wall-following with right-hand rule
# ============================================================================

func order_boundary_contour(boundary_cells: Array[HexCell]) -> Array[HexCell]:
	# Order boundary cells using right-hand rule for proper contour tracing
	if boundary_cells.size() < 3:
		return boundary_cells.duplicate()

	# Build lookup set for O(1) adjacency checking
	var boundary_set: Dictionary = {}
	for cell in boundary_cells:
		boundary_set[Vector2i(cell.q, cell.r)] = cell

	var ordered: Array[HexCell] = []
	var visited: Dictionary = {}

	# Start with the topmost-leftmost cell for consistent ordering
	var start_cell: HexCell = boundary_cells[0]
	for cell in boundary_cells:
		if cell.world_position.y < start_cell.world_position.y or \
		   (cell.world_position.y == start_cell.world_position.y and cell.world_position.x < start_cell.world_position.x):
			start_cell = cell

	var current: HexCell = start_cell
	ordered.append(current)
	visited[Vector2i(current.q, current.r)] = true

	# Start by trying to go right (direction 0)
	var last_dir_index := 0

	while ordered.size() < boundary_cells.size():
		var next_result := _find_next_boundary_cell_wall_following(current, boundary_set, visited, last_dir_index)

		if next_result.cell == null:
			# Wall following failed - use nearest unvisited as fallback
			var next_cell := _find_nearest_unvisited(current, boundary_cells, visited)
			if next_cell == null:
				break
			ordered.append(next_cell)
			visited[Vector2i(next_cell.q, next_cell.r)] = true
			current = next_cell
			last_dir_index = 0  # Reset direction
		else:
			ordered.append(next_result.cell)
			visited[Vector2i(next_result.cell.q, next_result.cell.r)] = true
			current = next_result.cell
			last_dir_index = next_result.direction

	return ordered


func _find_next_boundary_cell_wall_following(current: HexCell, boundary_set: Dictionary, visited: Dictionary, from_dir: int) -> Dictionary:
	# Use right-hand rule to follow boundary contour
	# Returns: {cell: HexCell, direction: int} or {cell: null}
	var current_coords := Vector2i(current.q, current.r)

	# When arriving from direction D, we want to try directions in this order:
	# Start 2 steps clockwise from where we came (turn right sharply)
	# This ensures we follow the outer boundary
	var opposite_dir := (from_dir + 3) % 6
	var start_search_dir := (opposite_dir + 2) % 6  # Turn right from opposite

	# Try each direction in clockwise order
	for i in range(6):
		var try_dir := (start_search_dir + i) % 6
		var neighbor_coords := current_coords + FLAT_TOP_DIRECTIONS[try_dir]

		if boundary_set.has(neighbor_coords) and not visited.has(neighbor_coords):
			return {
				"cell": boundary_set[neighbor_coords],
				"direction": try_dir
			}

	return {"cell": null}


func _find_nearest_unvisited(current: HexCell, boundary_cells: Array[HexCell], visited: Dictionary) -> HexCell:
	# Find nearest unvisited boundary cell
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

# ============================================================================
# CURVE GENERATION
# ============================================================================

func generate_smooth_curve(ordered_cells: Array[HexCell]) -> PackedVector2Array:
	# Generate a smooth closed curve through the ordered cell centers
	var positions: Array[Vector2] = []

	for cell in ordered_cells:
		positions.append(cell.world_position)

	if positions.size() < 3:
		return PackedVector2Array(positions)

	match curve_method:
		CurveMethod.CHAIKIN:
			return _generate_chaikin_curve(positions)
		CurveMethod.CATMULL_ROM:
			return _generate_catmull_rom_curve(positions, true)

	return PackedVector2Array(positions)

# ============================================================================
# CHAIKIN CURVE GENERATION
# ============================================================================

func _generate_chaikin_curve(positions: Array[Vector2]) -> PackedVector2Array:
	# Generate smooth curve using Chaikin's corner-cutting algorithm
	var smooth_points := _chaikin_subdivide(positions, smoothing_iterations)

	# Close the curve
	if not smooth_points.is_empty():
		smooth_points.append(smooth_points[0])

	return smooth_points


func _chaikin_subdivide(points: Array[Vector2], iterations: int = 2) -> PackedVector2Array:
	# Chaikin's corner-cutting algorithm for smooth curves
	var result: Array[Vector2] = points.duplicate()

	for _iter in range(iterations):
		var new_points: Array[Vector2] = []
		var n := result.size()

		for i in range(n):
			var p0 := result[i]
			var p1 := result[(i + 1) % n]

			# Cut corners at 25% and 75%
			var q := p0.lerp(p1, 0.25)
			var r := p0.lerp(p1, 0.75)

			new_points.append(q)
			new_points.append(r)

		result = new_points

	return PackedVector2Array(result)

# ============================================================================
# CATMULL-ROM CURVE GENERATION
# ============================================================================

func _generate_catmull_rom_curve(positions: Array[Vector2], closed: bool) -> PackedVector2Array:
	# Generate Catmull-Rom spline from positions
	var points := PackedVector2Array()

	if positions.size() < 2:
		for pos in positions:
			points.append(pos)
		return points

	var n := positions.size()

	# For closed curves, we need to wrap around
	var loop_count := n if closed else n - 1

	for i in range(loop_count):
		# Get 4 control points for Catmull-Rom
		var p0: Vector2
		var p1: Vector2
		var p2: Vector2
		var p3: Vector2

		if closed:
			p0 = positions[(i - 1 + n) % n]
			p1 = positions[i]
			p2 = positions[(i + 1) % n]
			p3 = positions[(i + 2) % n]
		else:
			p0 = positions[max(i - 1, 0)]
			p1 = positions[i]
			p2 = positions[min(i + 1, n - 1)]
			p3 = positions[min(i + 2, n - 1)]

		# Generate interpolated points
		for seg in range(smoothing_iterations):
			var t := float(seg) / float(smoothing_iterations)
			points.append(_catmull_rom(p0, p1, p2, p3, t))

	# Close the curve by adding the first point
	if closed and not points.is_empty():
		points.append(points[0])

	return points


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# Catmull-Rom spline interpolation between p1 and p2
	var t2 := t * t
	var t3 := t2 * t

	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

# ============================================================================
# UTILITY
# ============================================================================

func _points_from_cells(cells: Array[HexCell]) -> PackedVector2Array:
	# Convert cell array to position array
	var points := PackedVector2Array()
	for cell in cells:
		points.append(cell.world_position)
	return points
