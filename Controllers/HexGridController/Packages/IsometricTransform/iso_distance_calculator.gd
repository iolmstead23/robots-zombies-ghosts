class_name IsoDistanceCalculator
extends RefCounted

# Calculate distances in isometric space considering visual distortion
# Provides visual, logical, and hybrid distance measurements

# Calculate visual distance between two cells in isometric space
# Note: cell.world_position is already in isometric screen space (via axial_to_isometric)
# so we use it directly without additional transformation
static func calculate_isometric_distance(cell_a: HexCell, cell_b: HexCell) -> float:
	if not cell_a or not cell_b:
		push_error("[IsoDistanceCalculator] Cannot calculate distance with null cell(s): a=%s, b=%s" % [cell_a != null, cell_b != null])
		return 0.0

	return cell_a.world_position.distance_to(cell_b.world_position)

# Calculate logical hex distance (unchanged, uses axial coordinates)
static func calculate_logical_distance(cell_a: HexCell, cell_b: HexCell) -> int:
	if not cell_a or not cell_b:
		push_error("[IsoDistanceCalculator] Cannot calculate logical distance with null cell(s): a=%s, b=%s" % [cell_a != null, cell_b != null])
		return 0

	return cell_a.distance_to(cell_b)

# Get distance ratio between isometric and logical space
static func get_distance_ratio(cell_a: HexCell, cell_b: HexCell) -> float:
	if not cell_a or not cell_b:
		push_error("[IsoDistanceCalculator] Cannot calculate distance ratio with null cell(s)")
		return 1.0

	var logical := float(calculate_logical_distance(cell_a, cell_b))
	if logical == 0.0:
		return 1.0
	var visual := calculate_isometric_distance(cell_a, cell_b)
	return visual / logical

# Calculate weighted distance considering both logical and visual distance
static func calculate_hybrid_distance(cell_a: HexCell, cell_b: HexCell, alpha: float) -> float:
	if not cell_a or not cell_b:
		push_error("[IsoDistanceCalculator] Cannot calculate hybrid distance with null cell(s)")
		return 0.0

	var logical := float(calculate_logical_distance(cell_a, cell_b))
	var visual := calculate_isometric_distance(cell_a, cell_b)
	return lerp(logical, visual, alpha)

# Verify that all 6 hex directions have equal visual distance
# Uses HEX_Y_SCALE to match the actual transformation applied in axial_to_isometric
static func verify_equal_distances(hex_size: float) -> Dictionary:
	var distances: Array[float] = []
	var y_scale := IsoTransform.HEX_Y_SCALE
	var neighbor_offsets := [
		Vector2(hex_size * 1.5, 0),
		Vector2(hex_size * 0.75, -hex_size * sqrt(3.0) * 0.5 * y_scale),
		Vector2(-hex_size * 0.75, -hex_size * sqrt(3.0) * 0.5 * y_scale),
		Vector2(-hex_size * 1.5, 0),
		Vector2(-hex_size * 0.75, hex_size * sqrt(3.0) * 0.5 * y_scale),
		Vector2(hex_size * 0.75, hex_size * sqrt(3.0) * 0.5 * y_scale)
	]
	for offset in neighbor_offsets:
		var iso_vec := IsoTransform.to_isometric(offset)
		distances.append(iso_vec.length())
	var min_dist: float = distances.min()
	var max_dist: float = distances.max()
	var sum := 0.0
	for d in distances:
		sum += d
	return {
		"distances": distances,
		"min": min_dist,
		"max": max_dist,
		"average": sum / 6.0,
		"variance": max_dist - min_dist,
		"are_equal": abs(max_dist - min_dist) < 0.01
	}

# Test different Y-scale factors to find optimal value
static func find_optimal_scale(hex_size: float) -> Dictionary:
	var test_scales := [0.3, 0.4, 0.5, 0.577, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5]
	var best_scale := 0.577
	var best_variance := 999.9
	var results: Array[Dictionary] = []
	for scale in test_scales:
		var variance := _test_scale_factor(hex_size, scale)
		results.append({"scale": scale, "variance": variance})
		if variance < best_variance:
			best_variance = variance
			best_scale = scale
	return {
		"best_scale": best_scale,
		"best_variance": best_variance,
		"all_results": results
	}

# Test a specific scale factor and return variance
static func _test_scale_factor(hex_size: float, scale_y: float) -> float:
	var cos_30 := 0.866025403784
	var sin_30 := 0.5
	var distances: Array[float] = []
	var neighbor_offsets := [
		Vector2(hex_size * 1.5, 0),
		Vector2(hex_size * 0.75, -hex_size * sqrt(3.0) * 0.5),
		Vector2(-hex_size * 0.75, -hex_size * sqrt(3.0) * 0.5),
		Vector2(-hex_size * 1.5, 0),
		Vector2(-hex_size * 0.75, hex_size * sqrt(3.0) * 0.5),
		Vector2(hex_size * 0.75, hex_size * sqrt(3.0) * 0.5)
	]
	for offset in neighbor_offsets:
		var rx: float = offset.x * cos_30 - offset.y * sin_30
		var ry: float = (offset.x * sin_30 + offset.y * cos_30) * scale_y
		var length := sqrt(rx * rx + ry * ry)
		distances.append(length)
	var min_d: float = distances.min()
	var max_d: float = distances.max()
	return max_d - min_d
