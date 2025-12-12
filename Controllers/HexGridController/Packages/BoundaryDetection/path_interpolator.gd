class_name PathInterpolator
extends RefCounted

# Generates interpolated waypoints and midpoints for hex cell paths
# Supports straight path alignment and curved path generation
# Creates natural-looking paths that follow hex cell boundaries

# Generate midpoint-interpolated points through multiple layers
# Each layer creates midpoints between consecutive points from the previous layer
# positions: Base positions (typically hex cell centers)
# layers: Number of interpolation passes (1-3 recommended)
# Returns: Array with interpolated positions
func generate_midpoint_interpolation(positions: Array[Vector2], layers: int) -> Array[Vector2]:
	if positions.size() < 2:
		return positions.duplicate()

	var result: Array[Vector2] = positions.duplicate()

	for layer_idx in range(layers):
		result = _apply_midpoint_layer(result)

		if OS.is_debug_build():
			print("PathInterpolator: Layer %d produced %d points" % [layer_idx + 1, result.size()])

	return result


# Generate waypoints for a path that create natural curves
# Waypoints are positioned to follow the path flow while staying in hex boundaries
# path: Array of HexCell objects forming the path
# tension: Controls how much waypoints offset on turns (typically 0.5-2.0)
# Returns: Array of Vector2 waypoints
func generate_path_waypoints(path: Array[HexCell], tension: float = 1.0) -> Array[Vector2]:
	if path.size() < 2:
		return _cells_to_positions(path)

	# Check if path is straight (constant direction) or requires curves
	var alignment := _check_path_alignment(path)

	if alignment.is_straight:
		return _generate_straight_waypoints(path, alignment)
	else:
		return _generate_curved_waypoints(path, tension)


# Single pass of midpoint generation
# Creates midpoints between consecutive points while preserving start and end
# Input: [A, B, C] -> Output: [A, mid(A,B), mid(B,C), C]
func _apply_midpoint_layer(points: Array[Vector2]) -> Array[Vector2]:
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


# Check if path is horizontal, vertical, or straight (constant direction)
func _check_path_alignment(path: Array[HexCell]) -> Dictionary:
	if path.size() < 2:
		return {"is_horizontal": false, "is_vertical": false, "is_straight": true}

	# Check if path has constant direction (truly straight)
	var is_straight := true
	var first_direction := Vector2.ZERO

	for i in range(1, path.size()):
		var current_direction := (path[i].world_position - path[i-1].world_position).normalized()

		if i == 1:
			first_direction = current_direction
		else:
			# Check if direction changed (angle > 5 degrees indicates a turn)
			var angle_diff := first_direction.angle_to(current_direction)
			if abs(angle_diff) > 0.087:  # ~5 degrees tolerance
				is_straight = false
				break

	# Legacy horizontal/vertical checks for backwards compatibility
	var is_horizontal := true
	var is_vertical := true
	var first_q := path[0].q
	var first_r := path[0].r

	for cell in path:
		if cell.q != first_q:
			is_vertical = false
		if cell.r != first_r:
			is_horizontal = false

	return {
		"is_horizontal": is_horizontal,
		"is_vertical": is_vertical,
		"is_straight": is_straight or is_horizontal or is_vertical
	}


# Generate waypoints for straight paths (any direction)
# Uses hex cell centers directly for clean, straight lines
func _generate_straight_waypoints(path: Array[HexCell], alignment: Dictionary) -> Array[Vector2]:
	var waypoints: Array[Vector2] = []

	# For truly straight paths, just use cell centers - no offsets needed
	for cell in path:
		waypoints.append(cell.world_position)

	return waypoints


# Generate waypoints for curved paths
# Offsets waypoints at turns to create smoother curves
func _generate_curved_waypoints(path: Array[HexCell], tension: float) -> Array[Vector2]:
	var waypoints: Array[Vector2] = []

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


# Convert array of HexCell objects to array of Vector2 positions
func _cells_to_positions(cells: Array[HexCell]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for cell in cells:
		positions.append(cell.world_position)
	return positions
