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
@export var use_isometric_transform: bool = false

# Distance calculation settings
@export_group("Distance Settings")
@export var use_hybrid_range: bool = false
@export_range(0.0, 1.0) var hybrid_alpha: float = 0.5

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
	if use_isometric_transform and layout_flat_top:
		var metrics := IsoCornerCalculator.calculate_isometric_metrics(hex_size)
		hex_width = metrics.width
		hex_height = metrics.height
		horizontal_spacing = metrics.horizontal_spacing
		vertical_spacing = metrics.vertical_spacing
		if OS.is_debug_build():
			print("HexGrid: Using 30° ROTATED isometric transform")
			print("  - Rotation: 30° diagonal axis")
			print("  - Horizontal spacing: %.2f" % horizontal_spacing)
			print("  - Vertical spacing: %.2f" % vertical_spacing)
			print("  - Ratio: %.2f:1" % metrics.ratio)
			var dist_check := IsoDistanceCalculator.verify_equal_distances(hex_size)
			print("  - Distance variance: %.4f (equal=%s)" % [dist_check.variance, dist_check.are_equal])
			print("  - Finding optimal Y-scale factor...")
			var optimal := IsoDistanceCalculator.find_optimal_scale(hex_size)
			print("  - OPTIMAL: scale_y=%.3f, variance=%.4f" % [optimal.best_scale, optimal.best_variance])
			print("  - Current DISTANCE_SCALE=%.3f needs adjustment!" % IsoTransform.DISTANCE_SCALE)
		return

	if layout_flat_top:
		hex_width = hex_size * 2.0
		hex_height = sqrt(3.0) * hex_size
		horizontal_spacing = hex_width * 0.75
		vertical_spacing = hex_height
		if OS.is_debug_build():
			print("HexGrid: Using STANDARD flat-top layout")
			print("  - Horizontal spacing: %.2f" % horizontal_spacing)
			print("  - Vertical spacing: %.2f" % vertical_spacing)
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
	if use_isometric_transform:
		return IsoTransform.axial_to_isometric(q, r, hex_size, grid_offset)

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
	if use_isometric_transform:
		return IsoTransform.isometric_to_axial(world_pos, hex_size, grid_offset)

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

func get_cells_in_range(center: HexCell, radius: int) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells:
		if cell.distance_to(center) <= radius:
			result.append(cell)
	return result

func get_enabled_cells_in_range(center: HexCell, radius: int) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in get_cells_in_range(center, radius):
		if cell.enabled:
			result.append(cell)
	return result

func get_cells_in_visual_range(center: HexCell, pixel_radius: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells:
		var visual_dist := IsoDistanceCalculator.calculate_isometric_distance(center, cell)
		if visual_dist <= pixel_radius:
			result.append(cell)
	return result

func get_enabled_cells_in_visual_range(center: HexCell, pixel_radius: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in get_cells_in_visual_range(center, pixel_radius):
		if cell.enabled:
			result.append(cell)
	return result

func get_cells_in_hybrid_range(center: HexCell, radius: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in cells:
		var hybrid_dist := IsoDistanceCalculator.calculate_hybrid_distance(center, cell, hybrid_alpha)
		if hybrid_dist <= radius:
			result.append(cell)
	return result

func get_enabled_cells_in_hybrid_range(center: HexCell, radius: float) -> Array[HexCell]:
	var result: Array[HexCell] = []
	for cell in get_cells_in_hybrid_range(center, radius):
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