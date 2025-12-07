class_name HexEdgeSmoother
extends RefCounted

## Applies Chaikin subdivision smoothing to edge chains
## Handles both open paths (preserves endpoints) and closed loops

# Number of smoothing iterations (more = smoother but more points)
var smoothing_iterations: int = 1


func _init(iterations: int = 1) -> void:
	smoothing_iterations = iterations


func smooth_chain(chain: HexEdgeChain) -> PackedVector2Array:
	# Smooths an edge chain using Chaikin subdivision
	if chain.is_empty() or chain.polyline.size() < 2:
		return chain.polyline

	if chain.is_closed:
		return _smooth_closed(chain.polyline)
	else:
		return _smooth_open(chain.polyline)


func _smooth_closed(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var result := _array_from_packed(points)

	for _iter in range(smoothing_iterations):
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

	# Close the loop by adding first point at the end
	var packed := PackedVector2Array(result)
	if not packed.is_empty() and not packed[0].is_equal_approx(packed[packed.size() - 1]):
		packed.append(packed[0])

	return packed


func _smooth_open(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var result := _array_from_packed(points)

	for _iter in range(smoothing_iterations):
		var new_points: Array[Vector2] = []

		# Preserve first endpoint
		new_points.append(result[0])

		# Apply corner cutting to interior segments
		for i in range(result.size() - 1):
			var p0 := result[i]
			var p1 := result[i + 1]

			# Cut corner at 25% and 75%
			var q := p0.lerp(p1, 0.25)
			var r := p0.lerp(p1, 0.75)

			# For interior segments, add both points
			# For the last segment, only add q (r would be too close to endpoint)
			if i < result.size() - 2:
				new_points.append(q)
				new_points.append(r)
			else:
				# Last segment: only add q, preserve endpoint
				new_points.append(q)

		# Preserve last endpoint
		new_points.append(result[result.size() - 1])

		result = new_points

	return PackedVector2Array(result)


func _array_from_packed(packed: PackedVector2Array) -> Array[Vector2]:
	# Converts PackedVector2Array to typed Array[Vector2]
	var arr: Array[Vector2] = []
	for p in packed:
		arr.append(p)
	return arr
