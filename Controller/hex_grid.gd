class_name HexGrid
extends Node

## Handles a 2D hexagonal grid (with optional isometric projection)
signal cell_enabled_changed(cell: HexCell, enabled: bool)
signal grid_initialized()

# Grid configuration
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var layout_flat_top: bool = true
@export var grid_offset: Vector2 = Vector2.ZERO

# Isometric (pre-rendered) settings
@export_group("Isometric Settings")
@export var use_isometric: bool = false
@export var iso_angle: float = 30.0
@export var sprite_vertical_offset: float = 0.0
@export var click_isometric_correction: bool = false

# Transformation matrices (for future expansion)
var iso_matrix: Transform2D = Transform2D.IDENTITY
var iso_inverse: Transform2D = Transform2D.IDENTITY

# Grid storage
var cells: Array[HexCell] = []
var cells_by_coords: Dictionary = {}
var enabled_cells: Array[HexCell] = []

# Layout metrics
var hex_width: float
var hex_height: float
var horizontal_spacing: float
var vertical_spacing: float

func _ready() -> void:
	_calculate_layout()
	_setup_isometric()
	
func initialize_grid(width: int = -1, height: int = -1) -> void:
	if width > 0:
		grid_width = width
	if height > 0:
		grid_height = height
	_calculate_layout()
	_setup_isometric()
	_create_grid()
	emit_signal("grid_initialized")
	print_debug("HexGrid initialized with %d x %d cells. Isometric: %s" % [grid_width, grid_height, use_isometric])

func _calculate_layout() -> void:
	if layout_flat_top:
		hex_width = hex_size * 2.0
		hex_height = sqrt(3.0) * hex_size
		horizontal_spacing = hex_width * 0.75
		vertical_spacing = hex_height
	else:
		hex_width = sqrt(3.0) * hex_size
		hex_height = hex_size * 2.0
		horizontal_spacing = hex_width
		vertical_spacing = hex_height * 0.75

func _setup_isometric() -> void:
	# Pre-rendered sprites: identity transforms
	iso_matrix = Transform2D.IDENTITY
	iso_inverse = Transform2D.IDENTITY
	print_debug("Isometric: %s, using identity transforms" % use_isometric)

func _create_grid() -> void:
	cells.clear()
	cells_by_coords.clear()
	enabled_cells.clear()
	var idx := 0
	for r in range(grid_height):
		for q in range(grid_width):
			var cell := HexCell.new(q, r, idx)
			cell.world_position = _axial_to_world(q, r)
			cells.append(cell)
			cells_by_coords[Vector2i(q, r)] = cell
			enabled_cells.append(cell)
			idx += 1

func _axial_to_world(q: int, r: int) -> Vector2:
	# Converts hex axial (q, r) to world (pixel) position
	var x: float
	var y: float
	if layout_flat_top:
		x = hex_size * (1.5 * q)
		y = hex_size * (sqrt(3.0) * (r + 0.5 * (q & 1)))
	else:
		x = hex_size * (sqrt(3.0) * (q + 0.5 * (r & 1)))
		y = hex_size * (1.5 * r)
	return Vector2(x, y) + grid_offset

func world_position_to_axial(world_pos: Vector2) -> Vector2i:
	# Converts pixel position to nearest axial hex
	var p = world_pos - grid_offset
	if sprite_vertical_offset != 0.0:
		p.y += sprite_vertical_offset
	var q: float
	var r: float
	if layout_flat_top:
		q = (2.0 / 3.0 * p.x) / hex_size
		r = (-1.0 / 3.0 * p.x + sqrt(3.0) / 3.0 * p.y) / hex_size
	else:
		q = (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y) / hex_size
		r = (2.0 / 3.0 * p.y) / hex_size
	return _hex_round(q, r)

func _hex_round(q: float, r: float) -> Vector2i:
	# Rounds fractional axial to nearest hex grid cell
	var x := q
	var z := r
	var y := -x - z
	var rx: int = round(x)
	var ry: int = round(y)
	var rz: int = round(z)
	var dx: int = abs(rx - x)
	var dy: int = abs(ry - y)
	var dz: int = abs(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)

# --- Retrieval & Querying ---

func get_cell_at_coords(coords: Vector2i) -> HexCell:
	return cells_by_coords.get(coords)

func get_cell_at_index(index: int) -> HexCell:
	if index >= 0 and index < cells.size():
		return cells[index]
	return null

func get_cell_at_world_position(world_pos: Vector2) -> HexCell:
	var coords = world_position_to_axial(world_pos)
	return get_cell_at_coords(coords)

func is_valid_coords(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_width and coords.y >= 0 and coords.y < grid_height

# --- Cell Enable/Disable ---

func set_cell_enabled(cell: HexCell, enabled: bool) -> void:
	if cell.enabled == enabled:
		return
	cell.enabled = enabled
	if enabled:
		if not enabled_cells.has(cell):
			enabled_cells.append(cell)
	else:
		enabled_cells.erase(cell)
	emit_signal("cell_enabled_changed", cell, enabled)

func set_cell_enabled_at_coords(coords: Vector2i, enabled: bool) -> void:
	var cell = get_cell_at_coords(coords)
	if cell:
		set_cell_enabled(cell, enabled)

func set_cell_enabled_at_index(index: int, enabled: bool) -> void:
	var cell = get_cell_at_index(index)
	if cell:
		set_cell_enabled(cell, enabled)

func enable_cells_in_area(center_pos: Vector2, radius: int) -> void:
	var center = get_cell_at_world_position(center_pos)
	if not center:
		return
	for cell in cells:
		if cell.distance_to(center) <= radius:
			set_cell_enabled(cell, true)

func disable_cells_in_area(center_pos: Vector2, radius: int) -> void:
	var center = get_cell_at_world_position(center_pos)
	if not center:
		return
	for cell in cells:
		if cell.distance_to(center) <= radius:
			set_cell_enabled(cell, false)

# --- Neighbors & Ranges ---

func get_neighbors(cell: HexCell) -> Array:
	var neighbors: Array = []
	for coords in cell.get_neighbors_coords():
		var n = get_cell_at_coords(coords)
		if n:
			neighbors.append(n)
	return neighbors

func get_enabled_neighbors(cell: HexCell) -> Array:
	var en: Array = []
	var neighbors = get_neighbors(cell)
	for n in neighbors:
		if n.enabled:
			en.append(n)
	return en

func get_distance(from: HexCell, to: HexCell) -> int:
	return from.distance_to(to)

func get_distance_world(from: Vector2, to: Vector2) -> int:
	var a = get_cell_at_world_position(from)
	var b = get_cell_at_world_position(to)
	if a and b:
		return a.distance_to(b)
	return -1

func get_cells_in_range(center: HexCell, radius: int) -> Array:
	var result: Array = []
	for cell in cells:
		if cell.distance_to(center) <= radius:
			result.append(cell)
	return result

func get_enabled_cells_in_range(center: HexCell, radius: int) -> Array:
	var result: Array = []
	var in_range = get_cells_in_range(center, radius)
	for cell in in_range:
		if cell.enabled:
			result.append(cell)
	return result

# --- Maintenance & Debug ---

func clear_grid() -> void:
	cells.clear()
	cells_by_coords.clear()
	enabled_cells.clear()

func get_grid_stats() -> Dictionary:
	return {
		"total_cells": cells.size(),
		"enabled_cells": enabled_cells.size(),
		"disabled_cells": cells.size() - enabled_cells.size(),
		"grid_dimensions": Vector2i(grid_width, grid_height), # <-- back to original name!
		"hex_size": hex_size,
		"isometric": use_isometric,
	}
