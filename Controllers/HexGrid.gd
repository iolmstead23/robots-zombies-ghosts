# Controllers/HexGrid.gd
extends Resource
class_name HexGrid

## Handles hexagonal grid calculations and conversions
## Uses flat-top hexagonal layout

const SQRT3 := 1.732050808

# Orientation constants for flat-top hexagons
const ORIENTATION_F0 := 3.0 / 2.0
const ORIENTATION_F1 := 0.0
const ORIENTATION_F2 := SQRT3 / 2.0
const ORIENTATION_F3 := SQRT3

# Inverse orientation for world to cube conversion
const ORIENTATION_B0 := 2.0 / 3.0
const ORIENTATION_B1 := 0.0
const ORIENTATION_B2 := -1.0 / 3.0
const ORIENTATION_B3 := SQRT3 / 3.0

## Convert cube coordinates to world position (flat-top orientation)
## FIXED: hex_size is now properly passed as parameter
static func cube_to_world(cube: Vector3i, hex_size: float) -> Vector2:
	var x = hex_size * (ORIENTATION_F0 * cube.x + ORIENTATION_F1 * cube.y)
	var y = hex_size * (ORIENTATION_F2 * cube.x + ORIENTATION_F3 * cube.y)
	return Vector2(x, y)

## Convert world position to cube coordinates (flat-top orientation)
## FIXED: hex_size is now properly passed as parameter
static func world_to_cube(world_pos: Vector2, hex_size: float) -> Vector3i:
	var pt = world_pos / hex_size
	var q = ORIENTATION_B0 * pt.x + ORIENTATION_B1 * pt.y
	var r = ORIENTATION_B2 * pt.x + ORIENTATION_B3 * pt.y
	var s = -q - r
	
	return _cube_round(Vector3(q, r, s))

## Round fractional cube coordinates to nearest integer cube
static func _cube_round(cube: Vector3) -> Vector3i:
	var rq := roundi(cube.x)
	var rr := roundi(cube.y)
	var rs := roundi(cube.z)
	
	var q_diff := absf(rq - cube.x)
	var r_diff := absf(rr - cube.y)
	var s_diff := absf(rs - cube.z)
	
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	else:
		rs = -rq - rr
	
	return Vector3i(rq, rr, rs)

## Get all 6 neighboring cube coordinates (flat-top)
static func get_cube_neighbors(cube: Vector3i) -> Array[Vector3i]:
	var neighbors: Array[Vector3i] = []
	var directions := [
		Vector3i(1, -1, 0),   # East
		Vector3i(1, 0, -1),   # Southeast
		Vector3i(0, 1, -1),   # Southwest
		Vector3i(-1, 1, 0),   # West
		Vector3i(-1, 0, 1),   # Northwest
		Vector3i(0, -1, 1)    # Northeast
	]
	for dir in directions:
		neighbors.append(cube + dir)
	return neighbors

## Get specific neighbor by direction (0-5)
static func get_cube_neighbor(cube: Vector3i, direction: int) -> Vector3i:
	var directions := [
		Vector3i(1, -1, 0),   # 0: East
		Vector3i(1, 0, -1),   # 1: Southeast
		Vector3i(0, 1, -1),   # 2: Southwest
		Vector3i(-1, 1, 0),   # 3: West
		Vector3i(-1, 0, 1),   # 4: Northwest
		Vector3i(0, -1, 1)    # 5: Northeast
	]
	return cube + directions[direction % 6]

## Calculate Manhattan distance between two hexes in cube coordinates
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return (abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z)) / 2

## Get all hexes within a certain distance (ring)
static func get_hexes_in_range(center: Vector3i, range_distance: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	for dx in range(-range_distance, range_distance + 1):
		for dy in range(max(-range_distance, -dx - range_distance), 
						min(range_distance, -dx + range_distance) + 1):
			var dz = -dx - dy
			results.append(center + Vector3i(dx, dy, dz))
	return results

## Get hexes in a ring at specific distance
static func get_ring(center: Vector3i, radius: int) -> Array[Vector3i]:
	var results: Array[Vector3i] = []
	if radius == 0:
		results.append(center)
		return results
	
	var hex = center + Vector3i(0, -radius, radius)
	var directions := [
		Vector3i(1, -1, 0), Vector3i(1, 0, -1), Vector3i(0, 1, -1),
		Vector3i(-1, 1, 0), Vector3i(-1, 0, 1), Vector3i(0, -1, 1)
	]
	
	for i in range(6):
		for j in range(radius):
			results.append(hex)
			hex = hex + directions[i]
	
	return results

## Get vertices of a hexagon for rendering (flat-top orientation)
## FIXED: hex_size is now properly passed as parameter
static func get_hex_vertices(center: Vector2, hex_size: float) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	# Flat-top hexagon has vertices at angles: 0°, 60°, 120°, 180°, 240°, 300°
	for i in range(6):
		var angle_deg = 60.0 * i
		var angle_rad = deg_to_rad(angle_deg)
		vertices.append(center + Vector2(
			hex_size * cos(angle_rad),
			hex_size * sin(angle_rad)
		))
	return vertices

## Get hex corner position
## FIXED: hex_size is now properly passed as parameter
static func get_hex_corner(center: Vector2, corner_index: int, hex_size: float) -> Vector2:
	var angle_deg = 60.0 * corner_index
	var angle_rad = deg_to_rad(angle_deg)
	return center + Vector2(
		hex_size * cos(angle_rad),
		hex_size * sin(angle_rad)
	)

## Linear interpolation between two cubes
static func cube_lerp(a: Vector3, b: Vector3, t: float) -> Vector3:
	return Vector3(
		lerpf(a.x, b.x, t),
		lerpf(a.y, b.y, t),
		lerpf(a.z, b.z, t)
	)

## Get line of hexes between two cube coordinates
static func cube_line(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var distance = cube_distance(a, b)
	var results: Array[Vector3i] = []
	
	for i in range(distance + 1):
		var t = 0.0 if distance == 0 else float(i) / float(distance)
		results.append(_cube_round(cube_lerp(Vector3(a), Vector3(b), t)))
	
	return results

## Check if a cube coordinate is valid (q + r + s = 0)
static func is_valid_cube(cube: Vector3i) -> bool:
	return (cube.x + cube.y + cube.z) == 0

## Convert axial coordinates (q, r) to cube coordinates
static func axial_to_cube(q: int, r: int) -> Vector3i:
	return Vector3i(q, r, -q - r)

## Convert cube coordinates to axial (returns Vector2i with q, r)
static func cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.y)

## Get center offset for even-q offset coordinates
static func offset_to_cube_evenq(col: int, row: int) -> Vector3i:
	var q = col
	@warning_ignore("integer_division")
	var r = row - (col + (col & 1)) / 2
	return Vector3i(q, r, -q - r)

## Convert cube to even-q offset coordinates
static func cube_to_offset_evenq(cube: Vector3i) -> Vector2i:
	var col = cube.x
	@warning_ignore("integer_division")
	var row = cube.y + (cube.x + (cube.x & 1)) / 2
	return Vector2i(col, row)
