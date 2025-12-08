class_name HexDirections
extends RefCounted

# Centralized direction constants and mappings for flat-top hexagons
# Uses odd-q offset coordinate system where odd columns are shifted down
# Provides constants and utilities for neighbor detection and edge mapping

# Flat-top hex directions for neighbor checking
# Direction 0 = right, 1 = upper-right, 2 = upper-left, 3 = left, 4 = lower-left, 5 = lower-right
const FLAT_TOP_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),    # Direction 0 (right)
	Vector2i(1, -1),   # Direction 1 (upper-right)
	Vector2i(0, -1),   # Direction 2 (upper-left)
	Vector2i(-1, 0),   # Direction 3 (left)
	Vector2i(-1, 1),   # Direction 4 (lower-left)
	Vector2i(0, 1)     # Direction 5 (lower-right)
]

# Direction to edge mapping for EVEN columns (q % 2 == 0)
# Maps direction index to the hex corner indices (0-5) that form that edge
# For flat-top hexagon with corners at 0°, 60°, 120°, 180°, 240°, 300°
const DIRECTION_TO_EDGE_EVEN: Array[Vector2i] = [
	Vector2i(0, 1),  # Direction 0 (+q): neighbor is lower-right -> edge 0-1
	Vector2i(5, 0),  # Direction 1 (+q-r): neighbor is upper-right -> edge 5-0
	Vector2i(4, 5),  # Direction 2 (-r): neighbor is up -> edge 4-5
	Vector2i(3, 4),  # Direction 3 (-q): neighbor is upper-left -> edge 3-4
	Vector2i(2, 3),  # Direction 4 (-q+r): neighbor is lower-left -> edge 2-3
	Vector2i(1, 2),  # Direction 5 (+r): neighbor is down -> edge 1-2
]

# Direction to edge mapping for ODD columns (q % 2 == 1)
# Odd columns are shifted down, so the edge mappings differ from even columns
const DIRECTION_TO_EDGE_ODD: Array[Vector2i] = [
	Vector2i(5, 0),  # Direction 0 (+q): neighbor is upper-right -> edge 5-0
	Vector2i(4, 5),  # Direction 1 (+q-r): neighbor is up -> edge 4-5
	Vector2i(3, 4),  # Direction 2 (-r): neighbor is upper-left -> edge 3-4
	Vector2i(2, 3),  # Direction 3 (-q): neighbor is lower-left -> edge 2-3
	Vector2i(1, 2),  # Direction 4 (-q+r): neighbor is down -> edge 1-2
	Vector2i(0, 1),  # Direction 5 (+r): neighbor is lower-right -> edge 0-1
]


# Get the appropriate edge mapping based on column parity
static func get_edge_mapping_for_column(q: int) -> Array[Vector2i]:
	if q % 2 == 0:
		return DIRECTION_TO_EDGE_EVEN
	else:
		return DIRECTION_TO_EDGE_ODD


# Get neighbor coordinates for a cell at (q, r)
# Returns array of 6 Vector2i coordinates representing all neighbors
static func get_neighbors_coords(q: int, r: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []

	for direction in FLAT_TOP_DIRECTIONS:
		neighbors.append(Vector2i(q + direction.x, r + direction.y))

	return neighbors


# Get a specific neighbor coordinate by direction index (0-5)
static func get_neighbor_in_direction(q: int, r: int, direction_index: int) -> Vector2i:
	if direction_index < 0 or direction_index >= 6:
		push_error("Invalid direction index: %d (must be 0-5)" % direction_index)
		return Vector2i(q, r)

	var direction := FLAT_TOP_DIRECTIONS[direction_index]
	return Vector2i(q + direction.x, r + direction.y)


# Get edge corner indices for a specific direction and column
# Returns Vector2i where x is the first corner index and y is the second corner index
static func get_edge_for_direction(q: int, direction_index: int) -> Vector2i:
	if direction_index < 0 or direction_index >= 6:
		push_error("Invalid direction index: %d (must be 0-5)" % direction_index)
		return Vector2i(-1, -1)

	var edge_mapping := get_edge_mapping_for_column(q)
	return edge_mapping[direction_index]
