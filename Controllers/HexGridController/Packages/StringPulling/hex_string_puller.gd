class_name HexStringPuller
extends RefCounted

# Utility for creating smooth curves through hex cell boundaries
# Supports both Catmull-Rom spline and Chaikin subdivision algorithms

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

# Which curve algorithm to use
var curve_method: CurveMethod = CurveMethod.CHAIKIN

# Number of smoothing iterations (Chaikin) or segments per point (Catmull-Rom)
var smoothing_iterations: int = 2

# Angle threshold for simplification (radians) - points with smaller angle deviation are removed
var simplification_threshold: float = 0.3

# Midpoint interpolation configuration
var interpolation_layers: int = 1  # 1-3 layers of midpoint interpolation
var enable_string_pulling: bool = true  # Apply string pulling after interpolation
var hex_size: float = 32.0  # Hex size for boundary validation

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
# PATH STRING PULLING - Linear paths through hexagons
# ============================================================================

func pull_string_through_path(path: Array[HexCell], tension: float = 0.5, layers: int = 1, hex_size_param: float = 32.0) -> PackedVector2Array:
	# Generate smooth curve through linear path of hex cells
	# Uses midpoint interpolation followed by string pulling
	# Ensures path stays within hexagon boundaries
	#
	# Parameters:
	#   path: Ordered array of HexCell from start to goal
	#   tension: 0.0 = tight corners, 1.0 = smooth wide curves (legacy parameter)
	#   layers: 1-3 layers of midpoint interpolation
	#   hex_size_param: Size of hexagons for boundary validation
	#
	# Returns: PackedVector2Array of smooth curve points

	if path.size() < 2:
		# Single cell or empty path
		var result := PackedVector2Array()
		for cell in path:
			result.append(cell.world_position)
		return result

	hex_size = hex_size_param

	# Step 1: Extract world positions from path cells
	var base_positions: Array[Vector2] = []
	for cell in path:
		base_positions.append(cell.world_position)

	# Step 2: Apply midpoint interpolation (1-3 layers)
	var clamped_layers := clampi(layers, 1, 3)
	var interpolated := _generate_midpoint_interpolation(base_positions, clamped_layers)

	if OS.is_debug_build():
		print("HexStringPuller: Interpolated %d base points to %d points with %d layers" % [
			base_positions.size(), interpolated.size(), clamped_layers
		])

	# Step 3: Apply string pulling to tighten the path
	var pulled: Array[Vector2]
	if enable_string_pulling:
		pulled = _apply_string_pulling(interpolated, path)
	else:
		pulled = interpolated

	# Step 4: Optional final smoothing pass (Chaikin or Catmull-Rom)
	if smoothing_iterations > 0:
		match curve_method:
			CurveMethod.CHAIKIN:
				return _generate_chaikin_curve_open(pulled)
			CurveMethod.CATMULL_ROM:
				return _generate_catmull_rom_curve(pulled, false)

	return PackedVector2Array(pulled)


func _generate_path_waypoints(path: Array[HexCell], tension: float) -> Array[Vector2]:
	# Generate waypoints for path that create natural curves
	# Waypoints are positioned to follow the path flow while staying in hex boundaries

	var waypoints: Array[Vector2] = []

	# Check if path is purely horizontal (same r) or vertical (same q)
	var is_horizontal := true
	var is_vertical := true
	var first_q := path[0].q
	var first_r := path[0].r

	for cell in path:
		if cell.q != first_q:
			is_vertical = false
		if cell.r != first_r:
			is_horizontal = false

	# For straight horizontal/vertical paths, align waypoints perfectly
	if is_horizontal or is_vertical:
		# Calculate average position to align waypoints
		var avg_pos := Vector2.ZERO
		for cell in path:
			avg_pos += cell.world_position
		avg_pos /= path.size()

		for cell in path:
			var pos := cell.world_position
			if is_horizontal:
				# Align Y coordinates for horizontal paths
				waypoints.append(Vector2(pos.x, avg_pos.y))
			else:
				# Align X coordinates for vertical paths
				waypoints.append(Vector2(avg_pos.x, pos.y))
	else:
		# Curved path: use normal waypoint generation
		for i in range(path.size()):
			var cell := path[i]
			var pos := cell.world_position

			# First and last cells: use center
			if i == 0 or i == path.size() - 1:
				waypoints.append(pos)
				continue

			# Middle cells: calculate waypoint based on path flow
			var prev_cell := path[i - 1]
			var next_cell := path[i + 1]

			# Calculate direction vectors
			var dir_in := (pos - prev_cell.world_position).normalized()
			var dir_out := (next_cell.world_position - pos).normalized()

			# Check if path is turning
			var dot := dir_in.dot(dir_out)

			if dot > 0.999:
				# Nearly straight section: use cell center
				waypoints.append(pos)
			else:
				# Turn: offset waypoint to create smoother curve
				var turn_offset := (dir_in + dir_out).normalized() * tension * 5.0
				waypoints.append(pos + turn_offset)

	return waypoints


func _smooth_path_waypoints(waypoints: Array[Vector2]) -> PackedVector2Array:
	# Apply smoothing algorithm to waypoints
	# Use Catmull-Rom for smooth curves through waypoints

	# Apply curve smoothing - Catmull-Rom creates smooth interpolation automatically
	if smoothing_iterations > 0:
		match curve_method:
			CurveMethod.CHAIKIN:
				return _generate_chaikin_curve_open(waypoints)
			CurveMethod.CATMULL_ROM:
				return _generate_catmull_rom_curve(waypoints, false)

	# No smoothing - just return waypoints as straight lines
	return PackedVector2Array(waypoints)


func _interpolate_waypoints(waypoints: Array[Vector2], points_between: int) -> Array[Vector2]:
	# Add interpolated points between each pair of waypoints for smooth curves
	# points_between: number of points to add between each waypoint pair

	if waypoints.size() < 2:
		return waypoints

	var result: Array[Vector2] = []

	for i in range(waypoints.size() - 1):
		var start := waypoints[i]
		var end := waypoints[i + 1]

		# Add the start point
		result.append(start)

		# Add interpolated points between start and end
		for j in range(1, points_between + 1):
			var t := float(j) / float(points_between + 1)
			var interpolated_point := start.lerp(end, t)
			result.append(interpolated_point)

	# Add the final point
	result.append(waypoints[waypoints.size() - 1])

	return result


func _generate_chaikin_curve_open(positions: Array[Vector2]) -> PackedVector2Array:
	# Chaikin subdivision for OPEN curves - not closed loops
	# Similar to _chaikin_subdivide but doesn't close the curve

	var result: Array[Vector2] = positions.duplicate()

	for _iter in range(smoothing_iterations):
		var new_points: Array[Vector2] = []

		# First point: keep as-is
		new_points.append(result[0])

		# Middle points: subdivide
		for i in range(result.size() - 1):
			var p0 := result[i]
			var p1 := result[i + 1]

			# Cut corners at 25% and 75%
			var q := p0.lerp(p1, 0.25)
			var r := p0.lerp(p1, 0.75)

			new_points.append(q)
			new_points.append(r)

		# Last point: keep as-is
		new_points.append(result[result.size() - 1])

		result = new_points

	return PackedVector2Array(result)

# ============================================================================
# MIDPOINT INTERPOLATION
# ============================================================================

func _generate_midpoint_interpolation(positions: Array[Vector2], layers: int) -> Array[Vector2]:
	# Generate midpoint-interpolated points through multiple layers
	# Each layer creates midpoints between consecutive points from the previous layer
	#
	# Parameters:
	#   positions: Base positions (typically hex cell centers)
	#   layers: Number of interpolation passes (1-3)
	#
	# Returns: Array with interpolated positions

	if positions.size() < 2:
		return positions.duplicate()

	var result: Array[Vector2] = positions.duplicate()

	for layer_idx in range(layers):
		result = _apply_midpoint_layer(result)

		if OS.is_debug_build():
			print("HexStringPuller: Layer %d produced %d points" % [layer_idx + 1, result.size()])

	return result


func _apply_midpoint_layer(points: Array[Vector2]) -> Array[Vector2]:
	# Single pass of midpoint generation
	# Creates midpoints between consecutive points while preserving start and end
	#
	# Input: [A, B, C]
	# Output: [A, mid(A,B), mid(B,C), C]

	if points.size() < 2:
		return points.duplicate()

	var new_points: Array[Vector2] = []

	# Keep original start point
	new_points.append(points[0])

	# Generate midpoints between consecutive pairs
	for i in range(points.size() - 1):
		var midpoint := (points[i] + points[i + 1]) * 0.5
		new_points.append(midpoint)

	# Keep original end point
	new_points.append(points[points.size() - 1])

	return new_points

# ============================================================================
# STRING PULLING WITH HEX BOUNDARY VALIDATION
# ============================================================================

func _apply_string_pulling(points: Array[Vector2], path_cells: Array[HexCell]) -> Array[Vector2]:
	# Apply string pulling to tighten the interpolated path
	# Iteratively moves interior points toward the direct line between neighbors
	# while ensuring points stay within valid path hexagons
	#
	# Parameters:
	#   points: Interpolated waypoints
	#   path_cells: Original hex cells for boundary validation

	if points.size() < 3:
		return points.duplicate()

	var pulled: Array[Vector2] = points.duplicate()
	var max_iterations := 10
	var min_movement_threshold := 0.5  # Stop if movements are smaller than this

	for iteration in range(max_iterations):
		var max_movement := 0.0

		# Process interior points (not start or end)
		for i in range(1, pulled.size() - 1):
			var prev := pulled[i - 1]
			var curr := pulled[i]
			var next := pulled[i + 1]

			# Calculate ideal position on line between prev and next
			var ideal := _project_point_to_line_segment(curr, prev, next)

			# Skip if point is already at ideal position
			if curr.distance_squared_to(ideal) < 0.01:
				continue

			# Try to move toward ideal position
			var new_pos := _try_pull_toward(curr, ideal, path_cells)

			if new_pos != curr:
				var movement := curr.distance_to(new_pos)
				max_movement = max(max_movement, movement)
				pulled[i] = new_pos

		if OS.is_debug_build():
			print("HexStringPuller: String pull iteration %d, max movement: %.2f" % [iteration, max_movement])

		# Stop if convergence reached
		if max_movement < min_movement_threshold:
			break

	return pulled


func _project_point_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	# Project a point onto a line segment, clamping to segment bounds
	var line := line_end - line_start
	var line_length_sq := line.length_squared()

	if line_length_sq < 0.0001:
		return line_start

	var t := clampf((point - line_start).dot(line) / line_length_sq, 0.0, 1.0)
	return line_start + line * t


func _try_pull_toward(current: Vector2, target: Vector2, path_cells: Array[HexCell]) -> Vector2:
	# Attempt to move current position toward target while staying in valid hexes
	# Uses decreasing pull amounts to find valid position

	# First try full movement
	if _validate_point_within_path_hexes(target, path_cells):
		return target

	# Try decreasing amounts (75%, 50%, 25%, 10%)
	var pull_amounts := [0.75, 0.5, 0.25, 0.1]

	for amount in pull_amounts:
		var candidate := current.lerp(target, amount)
		if _validate_point_within_path_hexes(candidate, path_cells):
			return candidate

	# Could not pull at all - return original
	return current


func _validate_point_within_path_hexes(point: Vector2, path_cells: Array[HexCell]) -> bool:
	# Check if a point falls within any hexagon in the path
	# Uses Geometry2D for accurate polygon containment check

	for cell in path_cells:
		var hex_polygon := _get_hex_polygon(cell)
		if Geometry2D.is_point_in_polygon(point, hex_polygon):
			return true

	return false


func _get_hex_polygon(cell: HexCell) -> PackedVector2Array:
	# Generate the 6 corner vertices of a flat-top hexagon centered on cell
	var corners := PackedVector2Array()
	var center := cell.world_position

	# Flat-top hexagon corners at 0, 60, 120, 180, 240, 300 degrees
	for i in range(6):
		var angle_rad := deg_to_rad(60.0 * float(i))
		corners.append(center + Vector2(hex_size * cos(angle_rad), hex_size * sin(angle_rad)))

	return corners

# ============================================================================
# UTILITY
# ============================================================================

func _points_from_cells(cells: Array[HexCell]) -> PackedVector2Array:
	# Convert cell array to position array
	var points := PackedVector2Array()
	for cell in cells:
		points.append(cell.world_position)
	return points
