class_name StringPullValidator
extends RefCounted

# Applies string pulling algorithm to tighten interpolated paths
# Iteratively moves interior points toward direct lines between neighbors
# Validates points stay within valid hex cell boundaries using polygon containment

# Hex size for polygon generation (must be set before validation)
var hex_size: float = 32.0


# Apply string pulling to tighten an interpolated path
# Moves interior points toward the direct line between neighbors
# Validates all movements keep points within valid path hexagons
# points: Interpolated waypoints to tighten
# path_cells: Original hex cells forming the path (for boundary validation)
# Returns: Tightened path as Array[Vector2]
func pull_string_through_path(points: Array[Vector2], path_cells: Array[HexCell]) -> Array[Vector2]:
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
			print("StringPullValidator: Iteration %d, max movement: %.2f" % [iteration, max_movement])

		# Stop if convergence reached
		if max_movement < min_movement_threshold:
			break

	return pulled


# Validate that a point falls within any hexagon in the path
# point: Point to validate
# path_cells: Array of HexCell objects forming the valid path
# hex_size_override: Optional hex size override (uses instance hex_size if not provided)
# Returns: true if point is within any path hex, false otherwise
func validate_point_within_path_hexes(point: Vector2, path_cells: Array[HexCell],
									   hex_size_override: float = -1.0) -> bool:
	var size := hex_size_override if hex_size_override > 0 else hex_size

	for cell in path_cells:
		if HexGeometry.is_point_in_hex(point, cell.world_position, size):
			return true

	return false


# Set the hex size for validation
func set_hex_size(size: float) -> void:
	hex_size = size


# Project a point onto a line segment, clamping to segment bounds
func _project_point_to_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2) -> Vector2:
	var line := line_end - line_start
	var line_length_sq := line.length_squared()

	if line_length_sq < 0.0001:
		return line_start

	var t := clampf((point - line_start).dot(line) / line_length_sq, 0.0, 1.0)
	return line_start + line * t


# Attempt to move current position toward target while staying in valid hexes
# Uses decreasing pull amounts to find a valid position
func _try_pull_toward(current: Vector2, target: Vector2, path_cells: Array[HexCell]) -> Vector2:
	# First try full movement
	if validate_point_within_path_hexes(target, path_cells):
		return target

	# Try decreasing amounts (75%, 50%, 25%, 10%)
	var pull_amounts := [0.75, 0.5, 0.25, 0.1]

	for amount in pull_amounts:
		var candidate := current.lerp(target, amount)
		if validate_point_within_path_hexes(candidate, path_cells):
			return candidate

	# Could not pull at all - return original
	return current
