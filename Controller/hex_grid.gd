class_name HexGrid
extends Node

## Hexagonal Grid Controller with Isometric Projection Support
## This version correctly handles coordinate transformations for isometric views

signal cell_enabled_changed(cell: HexCell, enabled: bool)
signal grid_initialized()

## Grid configuration
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var layout_flat_top: bool = true
@export var grid_offset: Vector2 = Vector2.ZERO

@export_group("Isometric Settings")
@export var use_isometric: bool = false  ## Enable isometric projection
@export var iso_angle: float = 30.0     ## Isometric angle (standard is 30°)
@export var sprite_vertical_offset: float = 0.0  ## Vertical offset for sprite alignment
@export var click_isometric_correction: bool = false

## Computed transformation matrices
var iso_matrix: Transform2D = Transform2D.IDENTITY
var iso_inverse: Transform2D = Transform2D.IDENTITY

## Grid storage
var cells: Array[HexCell] = []
var cells_by_coords: Dictionary = {}
var enabled_cells: Array[HexCell] = []

## Layout calculations
var hex_width: float
var hex_height: float
var horizontal_spacing: float
var vertical_spacing: float

func _ready() -> void:
	_calculate_layout_metrics()
	_setup_isometric_transform()

func initialize_grid(width: int = -1, height: int = -1) -> void:
	if width > 0:
		grid_width = width
	if height > 0:
		grid_height = height
	
	_calculate_layout_metrics()
	_setup_isometric_transform()
	_create_grid()
	grid_initialized.emit()
	
	print("HexGrid initialized: %d x %d = %d cells (Isometric: %s)" % [grid_width, grid_height, cells.size(), use_isometric])

func _calculate_layout_metrics() -> void:
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

func _setup_isometric_transform() -> void:
	"""Setup for pre-rendered isometric sprites - no transformation needed"""
	# For pre-rendered sprites: sprites are already isometric
	# We use identity transforms (no matrix transformation)
	iso_inverse = Transform2D.IDENTITY
	iso_matrix = Transform2D.IDENTITY
	print("Pre-rendered sprite mode: Using identity transforms")
	

func _create_grid() -> void:
	cells.clear()
	cells_by_coords.clear()
	enabled_cells.clear()
	
	var index: int = 0
	
	for r in range(grid_height):
		for q in range(grid_width):
			var cell := HexCell.new(q, r, index)
			cell.world_position = _axial_to_world_position(q, r)
			
			cells.append(cell)
			cells_by_coords[Vector2i(q, r)] = cell
			enabled_cells.append(cell)
			
			index += 1

func _axial_to_world_position(q: int, r: int) -> Vector2:
	"""Convert axial coordinates to world pixel position"""
	var x: float
	var y: float
	
	# Flat 2D positioning - sprites are already isometric
	if layout_flat_top:
		x = hex_size * (1.5 * q)
		y = hex_size * (sqrt(3.0) * (r + 0.5 * (q & 1)))
	else:
		x = hex_size * (sqrt(3.0) * (q + 0.5 * (r & 1)))
		y = hex_size * (1.5 * r)
	
	# NO transform here - sprites handle isometric visuals
	return Vector2(x, y) + grid_offset

func world_position_to_axial(world_pos: Vector2) -> Vector2i:
	"""Convert world pixel position to nearest hex axial coordinates (pre-rendered sprites)"""
	var relative_pos: Vector2 = world_pos - grid_offset
	
	# Apply simple vertical offset for pre-rendered sprite alignment
	# (No complex transformation matrix - sprites are already isometric)
	var adjusted_pos := relative_pos
	if sprite_vertical_offset != 0.0:
		adjusted_pos.y += sprite_vertical_offset
	
	var q: float
	var r: float
	
	# Standard flat-top hex coordinate math
	if layout_flat_top:
		q = (2.0 / 3.0 * adjusted_pos.x) / hex_size
		r = (-1.0 / 3.0 * adjusted_pos.x + sqrt(3.0) / 3.0 * adjusted_pos.y) / hex_size
	else:
		q = (sqrt(3.0) / 3.0 * adjusted_pos.x - 1.0 / 3.0 * adjusted_pos.y) / hex_size
		r = (2.0 / 3.0 * adjusted_pos.y) / hex_size
	
	return _round_to_hex(q, r)

func _round_to_hex(q: float, r: float) -> Vector2i:
	"""Round fractional hex coordinates to nearest hex"""
	var x: float = q
	var z: float = r
	var y: float = -x - z
	
	var rx: int = round(x)
	var ry: int = round(y)
	var rz: int = round(z)
	
	var x_diff: float = abs(rx - x)
	var y_diff: float = abs(ry - y)
	var z_diff: float = abs(rz - z)
	
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	
	return Vector2i(rx, rz)

func get_cell_at_coords(coords: Vector2i) -> HexCell:
	return cells_by_coords.get(coords)

func get_cell_at_index(index: int) -> HexCell:
	if index >= 0 and index < cells.size():
		return cells[index]
	return null

func get_cell_at_world_position(world_pos: Vector2) -> HexCell:
	var coords := world_position_to_axial(world_pos)
	return get_cell_at_coords(coords)

func is_valid_coords(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_width and coords.y >= 0 and coords.y < grid_height

func set_cell_enabled(cell: HexCell, enabled: bool) -> void:
	if cell.enabled == enabled:
		return
	
	cell.enabled = enabled
	
	if enabled:
		if not cell in enabled_cells:
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

func disable_cells_in_area(center_world_pos: Vector2, radius_meters: int) -> void:
	var center_cell := get_cell_at_world_position(center_world_pos)
	if not center_cell:
		return
	
	for cell in cells:
		if cell.distance_to(center_cell) <= radius_meters:
			set_cell_enabled(cell, false)

func enable_cells_in_area(center_world_pos: Vector2, radius_meters: int) -> void:
	var center_cell := get_cell_at_world_position(center_world_pos)
	if not center_cell:
		return
	
	for cell in cells:
		if cell.distance_to(center_cell) <= radius_meters:
			set_cell_enabled(cell, true)

func get_neighbors(cell: HexCell) -> Array[HexCell]:
	var neighbors: Array[HexCell] = []
	var neighbor_coords := cell.get_neighbors_coords()
	
	for coords in neighbor_coords:
		var neighbor := get_cell_at_coords(coords)
		if neighbor:
			neighbors.append(neighbor)
	
	return neighbors

func get_enabled_neighbors(cell: HexCell) -> Array[HexCell]:
	var neighbors := get_neighbors(cell)
	var enabled_neighbors: Array[HexCell] = []
	
	for neighbor in neighbors:
		if neighbor.enabled:
			enabled_neighbors.append(neighbor)
	
	return enabled_neighbors

func get_distance(from_cell: HexCell, to_cell: HexCell) -> int:
	return from_cell.distance_to(to_cell)

func get_distance_world(from_pos: Vector2, to_pos: Vector2) -> int:
	var from_cell := get_cell_at_world_position(from_pos)
	var to_cell := get_cell_at_world_position(to_pos)
	
	if from_cell and to_cell:
		return from_cell.distance_to(to_cell)
	
	return -1

func get_cells_in_range(center_cell: HexCell, range_meters: int) -> Array[HexCell]:
	var cells_in_range: Array[HexCell] = []
	
	for cell in cells:
		if cell.distance_to(center_cell) <= range_meters:
			cells_in_range.append(cell)
	
	return cells_in_range

func get_enabled_cells_in_range(center_cell: HexCell, range_meters: int) -> Array[HexCell]:
	var cells_in_range := get_cells_in_range(center_cell, range_meters)
	var enabled_in_range: Array[HexCell] = []
	
	for cell in cells_in_range:
		if cell.enabled:
			enabled_in_range.append(cell)
	
	return enabled_in_range

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
		"isometric": use_isometric
	}
