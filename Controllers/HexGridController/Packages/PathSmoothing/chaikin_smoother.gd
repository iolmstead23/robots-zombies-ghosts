class_name ChaikinSmoother
extends PathSmootherBase

# Implements Chaikin's corner-cutting algorithm for curve smoothing
# Stable algorithm that never overshoots - ideal for boundary curves
# Each iteration cuts corners at 25% and 75% points, doubling the point count

# Smooth a curve using Chaikin's corner-cutting algorithm
# positions: Array of Vector2 points to smooth
# closed: Whether the curve forms a closed loop
# Returns: Smoothed curve as PackedVector2Array
func smooth_curve(positions: Array[Vector2], closed: bool) -> PackedVector2Array:
	if not _is_valid_positions(positions):
		return PackedVector2Array()

	if closed:
		return _subdivide_closed(positions)
	else:
		return _subdivide_open(positions)


# Chaikin subdivision for closed curves (loops)
# Each iteration doubles the number of points by cutting corners
func _subdivide_closed(positions: Array[Vector2]) -> PackedVector2Array:
	var result: Array[Vector2] = positions.duplicate()

	for _iter in range(smoothing_iterations):
		var new_points: Array[Vector2] = []
		var n := result.size()

		for i in range(n):
			var p0 := result[i]
			var p1 := result[(i + 1) % n]  # Wrap around for closed loop

			# Cut corner at 25% and 75% along the edge
			var q := p0.lerp(p1, 0.25)
			var r := p0.lerp(p1, 0.75)

			new_points.append(q)
			new_points.append(r)

		result = new_points

	# Close the curve by appending the first point
	var packed := _to_packed(result)
	if not packed.is_empty():
		packed.append(packed[0])

	return packed


# Chaikin subdivision for open curves (paths)
# Preserves the first and last points while smoothing the middle
func _subdivide_open(positions: Array[Vector2]) -> PackedVector2Array:
	var result: Array[Vector2] = positions.duplicate()

	for _iter in range(smoothing_iterations):
		var new_points: Array[Vector2] = []

		# First point: preserve as-is (don't smooth endpoints)
		new_points.append(result[0])

		# Middle points: subdivide edges
		for i in range(result.size() - 1):
			var p0 := result[i]
			var p1 := result[i + 1]

			# Cut corner at 25% and 75% along the edge
			var q := p0.lerp(p1, 0.25)
			var r := p0.lerp(p1, 0.75)

			new_points.append(q)
			new_points.append(r)

		# Last point: preserve as-is (don't smooth endpoints)
		new_points.append(result[result.size() - 1])

		result = new_points

	return _to_packed(result)


# Generate a smooth closed curve and return it
# Convenience method that wraps smooth_curve for closed loops
func generate_closed_curve(positions: Array[Vector2]) -> PackedVector2Array:
	return smooth_curve(positions, true)


# Generate a smooth open path and return it
# Convenience method that wraps smooth_curve for open paths
func generate_open_path(positions: Array[Vector2]) -> PackedVector2Array:
	return smooth_curve(positions, false)
