class_name HexEdgeSegment
extends RefCounted

## Represents a single edge of a hex cell on the boundary (adjacent to non-navigable terrain)
## Each edge connects two corner vertices of the hexagon

# The navigable hex cell this edge belongs to
var cell: HexCell

# Direction index (0-5) indicating which neighbor is non-navigable
# 0=right, 1=upper-right, 2=upper-left, 3=left, 4=lower-left, 5=lower-right
var direction: int

# World positions of the two corner vertices that form this edge
var corner_a: Vector2
var corner_b: Vector2

func _init(p_cell: HexCell, p_direction: int, p_corner_a: Vector2, p_corner_b: Vector2) -> void:
	cell = p_cell
	direction = p_direction
	corner_a = p_corner_a
	corner_b = p_corner_b


func get_center() -> Vector2:
	# Returns the world position of the edge's midpoint
	return (corner_a + corner_b) * 0.5


func get_length() -> float:
	# Returns the length of this edge
	return corner_a.distance_to(corner_b)


func _to_string() -> String:
	# Returns a string representation for debugging
	return "EdgeSegment(cell=(%d,%d), dir=%d, corners=[%.1f,%.1f]->[%.1f,%.1f])" % [
		cell.q, cell.r, direction,
		corner_a.x, corner_a.y, corner_b.x, corner_b.y
	]
