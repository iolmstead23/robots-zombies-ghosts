class_name HexGeometry
extends RefCounted

# Centralized utility for hexagon drawing and geometry calculations
# Supports flat-top hexagon orientation
# All drawing methods work with Godot's CanvasItem (Node2D, Control, etc.)

# Draw a hexagon outline with specified line width
static func draw_hexagon_outline(canvas: CanvasItem, center: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	var points := get_hex_corners(center, radius)

	# Draw outline by connecting all 6 corners
	for i in range(6):
		var next_i := (i + 1) % 6
		canvas.draw_line(points[i], points[next_i], color, width)


# Draw a filled hexagon polygon
static func draw_hexagon_filled(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := get_hex_corners(center, radius)
	canvas.draw_colored_polygon(points, color)


# Generate the 6 corner vertices of a flat-top hexagon centered at a position
# Corners are at 0°, 60°, 120°, 180°, 240°, 300°
static func get_hex_corners(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()

	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		var x := center.x + radius * cos(angle_rad)
		var y := center.y + radius * sin(angle_rad)
		points.append(Vector2(x, y))

	return points


# Get pre-calculated corner offsets (relative to center) for performance
# Useful when drawing multiple hexagons with the same size
static func get_hex_corner_offsets(radius: float) -> PackedVector2Array:
	var offsets := PackedVector2Array()

	# Flat-top hexagon: corners at 0, 60, 120, 180, 240, 300 degrees
	for i in range(6):
		var angle_deg := 60.0 * i
		var angle_rad := deg_to_rad(angle_deg)
		offsets.append(Vector2(radius * cos(angle_rad), radius * sin(angle_rad)))

	return offsets


# Check if a point is inside a hexagon
# Uses Godot's built-in Geometry2D for robust point-in-polygon testing
static func is_point_in_hex(point: Vector2, hex_center: Vector2, hex_size: float) -> bool:
	var polygon := get_hex_corners(hex_center, hex_size)
	return Geometry2D.is_point_in_polygon(point, polygon)


# Calculate flat-top hexagon metrics
# Returns dictionary with width, height, and other useful measurements
static func calculate_flat_top_metrics(hex_size: float) -> Dictionary:
	return {
		"width": hex_size * 2.0,
		"height": hex_size * sqrt(3.0),
		"horizontal_spacing": hex_size * 1.5,
		"vertical_spacing": hex_size * sqrt(3.0),
		"radius": hex_size
	}
