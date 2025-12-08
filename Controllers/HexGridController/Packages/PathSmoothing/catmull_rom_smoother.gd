class_name CatmullRomSmoother
extends PathSmootherBase

# Implements Catmull-Rom spline interpolation for curve smoothing
# Creates smooth curves that pass through all control points
# Can overshoot - produces visually smooth results but may extend beyond boundaries

# Smooth a curve using Catmull-Rom spline interpolation
# positions: Array of Vector2 points to smooth
# closed: Whether the curve forms a closed loop
# Returns: Smoothed curve as PackedVector2Array
func smooth_curve(positions: Array[Vector2], closed: bool) -> PackedVector2Array:
	if not _is_valid_positions(positions):
		return PackedVector2Array()

	return _generate_catmull_rom_spline(positions, closed)


# Generate Catmull-Rom spline from positions
# Uses 4 control points (p0, p1, p2, p3) to interpolate between p1 and p2
# smoothing_iterations determines the number of segments between each pair of points
func _generate_catmull_rom_spline(positions: Array[Vector2], closed: bool) -> PackedVector2Array:
	var points := PackedVector2Array()

	if positions.size() < 2:
		return _to_packed(positions)

	var n := positions.size()

	# For closed curves, we loop through all points
	# For open curves, we stop at n-1
	var loop_count := n if closed else n - 1

	for i in range(loop_count):
		# Get 4 control points for Catmull-Rom interpolation
		var p0: Vector2
		var p1: Vector2
		var p2: Vector2
		var p3: Vector2

		if closed:
			# Closed curve: wrap around using modulo
			p0 = positions[(i - 1 + n) % n]
			p1 = positions[i]
			p2 = positions[(i + 1) % n]
			p3 = positions[(i + 2) % n]
		else:
			# Open curve: clamp at boundaries
			p0 = positions[max(i - 1, 0)]
			p1 = positions[i]
			p2 = positions[min(i + 1, n - 1)]
			p3 = positions[min(i + 2, n - 1)]

		# Generate interpolated points between p1 and p2
		for seg in range(smoothing_iterations):
			var t := float(seg) / float(smoothing_iterations)
			points.append(_catmull_rom_interpolate(p0, p1, p2, p3, t))

	# Close the curve by adding the first point
	if closed and not points.is_empty():
		points.append(points[0])

	return points


# Catmull-Rom spline interpolation between p1 and p2
# p0 and p3 are used to determine the tangent at p1 and p2
# t is the interpolation parameter [0, 1]
# Returns: Interpolated point on the spline
func _catmull_rom_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t

	# Catmull-Rom basis matrix formula
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


# Generate a smooth closed curve and return it
# Convenience method that wraps smooth_curve for closed loops
func generate_closed_curve(positions: Array[Vector2]) -> PackedVector2Array:
	return smooth_curve(positions, true)


# Generate a smooth open path and return it
# Convenience method that wraps smooth_curve for open paths
func generate_open_path(positions: Array[Vector2]) -> PackedVector2Array:
	return smooth_curve(positions, false)


# Set number of segments per edge
# Higher values create smoother curves but more points
func set_segments_per_edge(segments: int) -> void:
	set_smoothing_iterations(max(1, segments))


# Get current number of segments per edge
func get_segments_per_edge() -> int:
	return smoothing_iterations
