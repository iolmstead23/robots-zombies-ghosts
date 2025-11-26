class_name HexGrid
extends Node

## 2D hexagonal grid with optional isometric projection

signal cell_enabled_changed(cell: HexCell, enabled: bool)
signal grid_initialized()

# Grid configuration
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var layout_flat_top: bool = true
@export var grid_offset: Vector2 = Vector2.ZERO

# Isometric settings
@export_group("Isometric Settings")
@export var use_isometric: bool = false
@export var iso_angle: float = 30.0
@export var sprite_vertical_offset: float = 0.0
@export var click_isometric_correction: bool = false

# Storage
var cells: Array[HexCell] = []
var cells_by_coords: Dictionary = {}
var enabled_cells: Array[HexCell] = []

# Layout metrics (calculated)
var hex_width: float
var hex_height: float
var horizontal_spacing: float
var vertical_spacing: float

func _ready() -> void:
	_calculate_layout()

func initialize_grid(width: int = -1, height: int = -1) -> void:
	if width > 0:
		grid_width = width
	if height > 0:
		grid_height = height
	
	_calculate_layout()
	_create_grid()
	grid_initialized.emit()
	
	if OS.is_debug_build():
		print("HexGrid: Initialized %dx%d (%d cells)" % [grid_width, grid_height, cells.size()])

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
	var p := world_pos - grid_offset
	if sprite_vertical_offset != 0.0:
		p.y += sprite_vertical_offset
	
	var q: float
	var r: float
	
	if layout_flat_top:
		q = (2.0 / 3.0 * p.x) / hex_size
		var col_offset := 0.5 * (int(round(q)) & 1)
		r = (p.y / (hex_size * sqrt(3.0))) - col_offset
	else:
		r = (2.0 / 3.0 * p.y) / hex_size
		var row_offset := 0.5 * (int(round(r)) & 1)
		q = (p.x / (hex_size * sqrt(3.0))) - row_offset
	
	return _hex_round(q, r)

func _hex_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	
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

# Cell retrieval
func get_cell_at_coords(coords: Vector2i) -> HexCell:
	return cells_by_coords.get(coords)

func get_cell_at_index(index: int) -> HexCell:
	if index >= 0 and index < cells.size():
		return cells[index]
	return null

func get_cell_at_world_position(world_pos: Vector2) -> HexCell:
	return get_cell_at_coords(world_position_to_axial(world_pos))

func is_valid_coords(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_width and coords.y >= 0 and coords.y < grid_height

# Enable/disable cells
func set_cell_enabled(cell: HexCell, enabled: bool) -> void:
	if cell.enabled == enabled:
		return
	
	cell.enabled = enabled
	
	if enabled:
		if not enabled_cells.has(cell):
			enabled_cells.append(cell)
	else:
		enabled_cells.erase(cell)
	
	cell_enabled_changed.emit(cell, enabled)

func set_cell_enabled_at_coords(coords: Vector2i, enabled: bool) -> void:
	var cell := get_cell_at_coords(coords)
	if cell:
		set_cell_enabled(cell, enabled)

func set_cell_enabled_at_index(index: int, enabled: bool) -> void:
	var cell := get_cell_at_index(index)
	if cell:
		set_cell_enabled(cell, enabled)

func enable_cells_in_area(center_pos: Vector2, radius: int) -> void:
	var center := get_cell_at_world_position(center_pos)
	if not center:
		return
	
	for cell in cells:
		if cell.distance_to(center) <= radius:
			set_cell_enabled(cell, true)

func disable_cells_in_area(center_pos: Vector2, radius: int) -> void:
	var center := get_cell_at_world_position(center_pos)
	if not center:
		return
	
	for cell in cells:
		if cell.distance_to(center) <= radius:
			set_cell_enabled(cell, false)

# Neighbors and ranges
func get_neighbors(cell: HexCell) -> Array:
	var neighbors: Array = []
	for coords in cell.get_neighbors_coords():
		var n := get_cell_at_coords(coords)
		if n:
			neighbors.append(n)
	return neighbors

func get_enabled_neighbors(cell: HexCell) -> Array:
	var result: Array = []
	for n in get_neighbors(cell):
		if n.enabled:
			result.append(n)
	return result

func get_distance(from: HexCell, to: HexCell) -> int:
	return from.distance_to(to)

func get_distance_world(from: Vector2, to: Vector2) -> int:
	var a := get_cell_at_world_position(from)
	var b := get_cell_at_world_position(to)
	return a.distance_to(b) if (a and b) else -1

func get_cells_in_range(center: HexCell, radius: int) -> Array:
	var result: Array = []
	for cell in cells:
		if cell.distance_to(center) <= radius:
			result.append(cell)
	return result

func get_enabled_cells_in_range(center: HexCell, radius: int) -> Array:
	var result: Array = []
	for cell in get_cells_in_range(center, radius):
		if cell.enabled:
			result.append(cell)
	return result

func clear_grid() -> void:
	cells.clear()
	cells_by_coords.clear()
	enabled_cells.clear()

func get_grid_stats() -> Dictionary:
	return {
		"total_cells": cells.size(),
		"enabled_cells": enabled_cells.size(),
		"disabled_cells": cells.size() - enabled_cells.size(),
		"grid_dimensions": Vector2i(grid_width, grid_height),
		"hex_size": hex_size,
		"isometric": use_isometric,
	}