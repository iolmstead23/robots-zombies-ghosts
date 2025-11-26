class_name HexGridController
extends Node

## Manages hex grid state and logic independently
## Communicates exclusively through signals - no direct dependencies on other features

# ============================================================================
# SIGNALS - State Changes (Emitted)
# ============================================================================

## Emitted when the grid is fully initialized
signal grid_initialized(grid_data: Dictionary)

## Emitted when a cell's enabled state changes
signal cell_state_changed(coords: Vector2i, enabled: bool)

## Emitted when multiple cells in an area change
signal cells_in_area_changed(center: Vector2, radius: int)

## Emitted when grid statistics are updated
signal grid_stats_changed(stats: Dictionary)

# ============================================================================
# SIGNALS - Query Responses (Emitted)
# ============================================================================

## Response to request_cell_at_position
signal cell_at_position_response(request_id: String, cell: HexCell)

## Response to request_distance
signal distance_calculated(request_id: String, distance: int)

## Response to request_cells_in_range
signal cells_in_range_response(request_id: String, cells: Array[HexCell])

## Response to request_is_navigable
signal is_navigable_response(request_id: String, navigable: bool)

# ============================================================================
# SIGNALS - Commands (Received from SessionController)
# ============================================================================

## Initialize the grid with specified parameters
signal initialize_grid_requested(width: int, height: int, hex_size: float, offset: Vector2)

## Set a specific cell's enabled state
signal set_cell_enabled_requested(coords: Vector2i, enabled: bool)

## Set cells in an area
signal set_cells_in_area_requested(center: Vector2, radius: int, enabled: bool)

## Clear the entire grid
signal clear_grid_requested()

## Integrate with navigation mesh
signal integrate_navmesh_requested(nav_region: NavigationRegion2D, sample_points: int)

# ============================================================================
# SIGNALS - Queries (Received from other controllers via SessionController)
# ============================================================================

## Query for cell at world position
signal request_cell_at_position(request_id: String, world_pos: Vector2)

## Query for distance between two positions
signal request_distance(request_id: String, from_pos: Vector2, to_pos: Vector2)

## Query for cells in range
signal request_cells_in_range(request_id: String, center_pos: Vector2, range: int)

## Query if position is navigable
signal request_is_navigable(request_id: String, world_pos: Vector2)

# ============================================================================
# STATE
# ============================================================================

var hex_grid: HexGrid = null
var hex_grid_debug: HexGridDebug = null
var navmesh_integration: HexNavmeshIntegration = null

# Configuration
var grid_width: int = 20
var grid_height: int = 15
var hex_size: float = 32.0
var grid_offset: Vector2 = Vector2.ZERO

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Connect to command signals
	initialize_grid_requested.connect(_on_initialize_grid_requested)
	set_cell_enabled_requested.connect(_on_set_cell_enabled_requested)
	set_cells_in_area_requested.connect(_on_set_cells_in_area_requested)
	clear_grid_requested.connect(_on_clear_grid_requested)
	integrate_navmesh_requested.connect(_on_integrate_navmesh_requested)

	# Connect to query signals
	request_cell_at_position.connect(_on_request_cell_at_position)
	request_distance.connect(_on_request_distance)
	request_cells_in_range.connect(_on_request_cells_in_range)
	request_is_navigable.connect(_on_request_is_navigable)

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

func _on_initialize_grid_requested(width: int, height: int, size: float, offset: Vector2):
	grid_width = width
	grid_height = height
	hex_size = size
	grid_offset = offset

	_init_hex_grid()
	hex_grid.initialize_grid(grid_width, grid_height)

	var stats = hex_grid.get_grid_stats()
	var grid_data = {
		"width": grid_width,
		"height": grid_height,
		"hex_size": hex_size,
		"offset": grid_offset,
		"total_cells": stats.total_cells,
		"enabled_cells": stats.enabled_cells,
		"disabled_cells": stats.disabled_cells
	}

	grid_initialized.emit(grid_data)
	grid_stats_changed.emit(stats)

func _on_set_cell_enabled_requested(coords: Vector2i, enabled: bool):
	if not hex_grid:
		return

	var cell = hex_grid.get_cell_at_coords(coords)
	if cell:
		hex_grid.set_cell_enabled(cell, enabled)
		cell_state_changed.emit(coords, enabled)
		_emit_grid_stats()

func _on_set_cells_in_area_requested(center: Vector2, radius: int, enabled: bool):
	if not hex_grid:
		return

	if enabled:
		hex_grid.enable_cells_in_area(center, radius)
	else:
		hex_grid.disable_cells_in_area(center, radius)

	cells_in_area_changed.emit(center, radius)
	_emit_grid_stats()

func _on_clear_grid_requested():
	if hex_grid:
		hex_grid.clear_grid()
		_emit_grid_stats()

func _on_integrate_navmesh_requested(nav_region: NavigationRegion2D, sample_points: int):
	if not hex_grid or not nav_region or not nav_region.navigation_polygon:
		return

	await _init_navmesh(nav_region, sample_points)
	_emit_grid_stats()

# ============================================================================
# QUERY HANDLERS
# ============================================================================

func _on_request_cell_at_position(request_id: String, world_pos: Vector2):
	var cell = hex_grid.get_cell_at_world_position(world_pos) if hex_grid else null
	cell_at_position_response.emit(request_id, cell)

func _on_request_distance(request_id: String, from_pos: Vector2, to_pos: Vector2):
	var distance = hex_grid.get_distance_world(from_pos, to_pos) if hex_grid else -1
	distance_calculated.emit(request_id, distance)

func _on_request_cells_in_range(request_id: String, center_pos: Vector2, cell_range: int):
	var cells: Array[HexCell] = []
	if hex_grid:
		var center_cell = hex_grid.get_cell_at_world_position(center_pos)
		if center_cell:
			cells = hex_grid.get_enabled_cells_in_range(center_cell, cell_range)
	cells_in_range_response.emit(request_id, cells)

func _on_request_is_navigable(request_id: String, world_pos: Vector2):
	var navigable = false
	if hex_grid:
		var cell = hex_grid.get_cell_at_world_position(world_pos)
		navigable = cell != null and cell.enabled
	is_navigable_response.emit(request_id, navigable)

# ============================================================================
# INTERNAL METHODS
# ============================================================================

func _init_hex_grid() -> void:
	hex_grid = HexGrid.new()
	hex_grid.name = "HexGrid"
	hex_grid.grid_width = grid_width
	hex_grid.grid_height = grid_height
	hex_grid.hex_size = hex_size
	hex_grid.layout_flat_top = true
	hex_grid.sprite_vertical_offset = 0.0
	hex_grid.grid_offset = grid_offset
	add_child(hex_grid)

func _init_navmesh(nav_region: NavigationRegion2D, sample_points: int) -> void:
	if not nav_region or not nav_region.navigation_polygon:
		return

	if OS.is_debug_build():
		print("HexGridController: Starting navmesh integration with existing grid %dx%d" % [
			grid_width, grid_height
		])

	# Create and configure integration without modifying grid dimensions
	navmesh_integration = HexNavmeshIntegration.new()
	navmesh_integration.name = "NavmeshIntegration"
	navmesh_integration.hex_grid = hex_grid
	navmesh_integration.navigation_region = nav_region
	navmesh_integration.sample_points_per_cell = sample_points
	navmesh_integration.auto_integrate_on_ready = false
	add_child(navmesh_integration)

	# Run integration - this will enable/disable cells based on polygon containment
	await navmesh_integration.integrate_with_navmesh()

	# Emit stats after integration
	_emit_grid_stats()

	if OS.is_debug_build():
		print("HexGridController: Navmesh integration complete")

func _calculate_navmesh_bounds(nav_poly: NavigationPolygon) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for i in nav_poly.get_outline_count():
		var outline := nav_poly.get_outline(i)
		min_pos = _get_min_vertices(outline, min_pos)
		max_pos = _get_max_vertices(outline, max_pos)

	if min_pos.x == INF:
		push_warning("NavigationPolygon has no vertices")
		return Rect2()

	return Rect2(min_pos, max_pos - min_pos)

func _get_min_vertices(outline: PackedVector2Array, current_min: Vector2) -> Vector2:
	var result := current_min
	for vertex in outline:
		result = result.min(vertex)
	return result

func _get_max_vertices(outline: PackedVector2Array, current_max: Vector2) -> Vector2:
	var result := current_max
	for vertex in outline:
		result = result.max(vertex)
	return result

func _emit_grid_stats():
	if hex_grid:
		var stats = hex_grid.get_grid_stats()
		grid_stats_changed.emit(stats)

# ============================================================================
# PUBLIC API - Direct Accessors (for backward compatibility)
# ============================================================================

func get_hex_grid() -> HexGrid:
	return hex_grid

func get_grid_debug() -> HexGridDebug:
	return hex_grid_debug

func refresh_navmesh_integration() -> void:
	if navmesh_integration:
		navmesh_integration.refresh_integration()
