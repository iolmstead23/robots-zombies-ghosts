class_name HexCell
extends RefCounted

## Represents a single hexagonal cell in the grid
## Each cell = 1 meter unit for distance calculations

## Axial coordinates for the hex cell
var q: int  # Column coordinate
var r: int  # Row coordinate

## Grid array index for quick lookup
var index: int

## Navigation state
var enabled: bool = true

## World position (center of the hex in pixels)
var world_position: Vector2

## Custom metadata (can store terrain type, cost, etc.)
var metadata: Dictionary = {}

func _init(q_coord: int, r_coord: int, cell_index: int) -> void:
	q = q_coord
	r = r_coord
	index = cell_index

func get_axial_coords() -> Vector2i:
	"""Returns the axial coordinates as a Vector2i"""
	return Vector2i(q, r)

func get_cube_coords() -> Vector3i:
	"""Converts axial to cube coordinates for easier distance calculations"""
	var x: int = q
	var z: int = r
	var y: int = -x - z
	return Vector3i(x, y, z)

func distance_to(other: HexCell) -> int:
	"""Returns distance in cells/meters to another hex cell"""
	var cube_a: Vector3i = get_cube_coords()
	var cube_b: Vector3i = other.get_cube_coords()
	return (abs(cube_a.x - cube_b.x) + abs(cube_a.y - cube_b.y) + abs(cube_a.z - cube_b.z)) / 2

func get_neighbors_coords() -> Array[Vector2i]:
	"""Returns the axial coordinates of all 6 neighboring cells"""
	var neighbors: Array[Vector2i] = []
	# Flat-top hex directions (for isometric view)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),   # East
		Vector2i(1, -1),  # Northeast
		Vector2i(0, -1),  # Northwest
		Vector2i(-1, 0),  # West
		Vector2i(-1, 1),  # Southwest
		Vector2i(0, 1)    # Southeast
	]
	
	for direction in directions:
		neighbors.append(Vector2i(q + direction.x, r + direction.y))
	
	return neighbors

func set_metadata(key: String, value: Variant) -> void:
	"""Store custom metadata for this cell"""
	metadata[key] = value

func get_metadata(key: String, default_value: Variant = null) -> Variant:
	"""Retrieve custom metadata"""
	return metadata.get(key, default_value)

func to_type_string() -> String:
	return "HexCell(q=%d, r=%d, index=%d, enabled=%s)" % [q, r, index, enabled]
