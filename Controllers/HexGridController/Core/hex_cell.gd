class_name HexCell
extends RefCounted

## Single hexagonal cell (1 meter unit for distance calculations)

# Axial coordinates
var q: int
var r: int
var index: int

# State
var enabled: bool = true
var world_position: Vector2
var metadata: Dictionary = {}

func _init(q_coord: int, r_coord: int, cell_index: int) -> void:
	q = q_coord
	r = r_coord
	index = cell_index

func get_axial_coords() -> Vector2i:
	return Vector2i(q, r)

func get_cube_coords() -> Vector3i:
	return Vector3i(q, r, -q - r)

func distance_to(other: HexCell) -> int:
	var cube_a := get_cube_coords()
	var cube_b := other.get_cube_coords()
	var dx: int = abs(cube_a.x - cube_b.x)
	var dy: int = abs(cube_a.y - cube_b.y)
	var dz: int = abs(cube_a.z - cube_b.z)
	@warning_ignore("integer_division")
	return (dx + dy + dz) / 2

func get_neighbors_coords() -> Array[Vector2i]:
	const FLAT_TOP_DIRECTIONS := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var neighbors: Array[Vector2i] = []
	for dir in FLAT_TOP_DIRECTIONS:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))
	return neighbors

func set_metadata(key: String, value: Variant) -> void:
	metadata[key] = value

func get_metadata(key: String, default_value: Variant = null) -> Variant:
	return metadata.get(key, default_value)

func to_type_string() -> String:
	return "HexCell(q=%d, r=%d, index=%d, enabled=%s)" % [q, r, index, enabled]

func get_coords() -> Vector2i:
	# Helper method for consistent coordinate access
	return Vector2i(q, r)

func get_selection_data() -> Dictionary:
	# Return selection data for UI display when hex cell is selected
	return {
		"has_selection": true,
		"item_type": "Hex Cell",
		"item_name": "Cell (%d, %d)" % [q, r],
		"metadata": {
			"coordinates": "(q=%d, r=%d)" % [q, r],
			"index": index,
			"world_position": world_position,
			"enabled": enabled,
			"navigable": enabled
		}
	}
