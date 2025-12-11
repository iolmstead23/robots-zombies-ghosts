class_name IsoCornerCalculator
extends RefCounted

# Calculate hexagon corners in isometric space
# Transforms standard flat-top corners to achieve 2:1 visual ratio

# Generate 6 corner vertices for flat-top hexagon in isometric space
static func get_isometric_hex_corners(center: Vector2, radius: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in range(6):
		var standard_corner := _get_standard_corner(i, radius)
		var iso_corner := IsoTransform.to_isometric(standard_corner)
		corners.append(center + iso_corner)
	return corners

# Get pre-calculated isometric corner offsets (relative to center)
static func get_isometric_corner_offsets(radius: float) -> PackedVector2Array:
	var offsets := PackedVector2Array()
	for i in range(6):
		var standard_corner := _get_standard_corner(i, radius)
		var iso_offset := IsoTransform.to_isometric(standard_corner)
		offsets.append(iso_offset)
	return offsets

# Calculate standard flat-top hex corner offset (0-5)
static func _get_standard_corner(corner_index: int, radius: float) -> Vector2:
	var angle_deg := 60.0 * corner_index
	var angle_rad := deg_to_rad(angle_deg)
	return Vector2(radius * cos(angle_rad), radius * sin(angle_rad))

# Calculate isometric hex metrics
static func calculate_isometric_metrics(hex_size: float) -> Dictionary:
	var spacing := IsoTransform.get_isometric_spacing(hex_size)
	var standard_width := hex_size * 2.0
	var standard_height := hex_size * sqrt(3.0)
	var width_vec := IsoTransform.to_isometric(Vector2(standard_width, 0.0))
	var height_vec := IsoTransform.to_isometric(Vector2(0.0, standard_height))
	return {
		"width": width_vec.length(),
		"height": height_vec.length(),
		"horizontal_spacing": spacing.horizontal,
		"vertical_spacing": spacing.vertical,
		"ratio": spacing.ratio,
		"radius": hex_size
	}
