class_name HexNavmeshIntegration
extends Node

## Syncs HexGrid cells with NavigationRegion2D

signal integration_complete()

@export var hex_grid: HexGrid
@export var navigation_region: NavigationRegion2D
@export var sample_points_per_cell: int = 5
@export var auto_integrate_on_ready: bool = true

var navigation_map: RID

func _ready() -> void:
	if auto_integrate_on_ready:
		await get_tree().process_frame
		integrate_with_navmesh()

func integrate_with_navmesh() -> void:
	if not _validate_dependencies():
		return
	
	await get_tree().physics_frame
	
	navigation_map = navigation_region.get_navigation_map()
	if not navigation_map.is_valid():
		await _retry_integration()
		return
	
	_process_all_cells()
	_emit_completion()

func _validate_dependencies() -> bool:
	if not hex_grid:
		push_error("HexNavmeshIntegration: Missing HexGrid")
		return false
	
	if not navigation_region:
		push_error("HexNavmeshIntegration: Missing NavigationRegion2D")
		return false
	
	return true

func _retry_integration() -> void:
	if OS.is_debug_build():
		push_warning("HexNavmeshIntegration: Navigation map not ready, retrying...")
	await get_tree().create_timer(0.1).timeout
	await integrate_with_navmesh()

func _process_all_cells() -> void:
	var enabled_count := 0
	var disabled_count := 0
	var cells_changed := 0

	if OS.is_debug_build():
		print("HexNavmeshIntegration: Processing %d cells with tolerance %.1f" % [
			hex_grid.cells.size(), hex_grid.hex_size * 2.0
		])

	for cell in hex_grid.cells:
		var navigable := _is_cell_navigable(cell)
		if navigable != cell.enabled:
			hex_grid.set_cell_enabled(cell, navigable)
			cells_changed += 1
		if navigable:
			enabled_count += 1
		else:
			disabled_count += 1

	if OS.is_debug_build():
		print("HexNavmeshIntegration: Complete! Changed: %d | Now enabled: %d | Now disabled: %d | Total cells: %d" % [
			cells_changed, enabled_count, disabled_count, hex_grid.cells.size()
		])

func _emit_completion() -> void:
	integration_complete.emit()

func _is_cell_navigable(cell: HexCell) -> bool:
	if _is_point_on_navmesh(cell.world_position):
		return true
	
	if sample_points_per_cell > 1:
		return _check_sample_points(cell)
	
	return false

func _check_sample_points(cell: HexCell) -> bool:
	var navigable_samples := 0
	var radius := hex_grid.hex_size * 0.7
	
	for i in sample_points_per_cell:
		var angle := (TAU / sample_points_per_cell) * i
		var delta := Vector2(radius * cos(angle), radius * sin(angle))
		if _is_point_on_navmesh(cell.world_position + delta):
			navigable_samples += 1
	
	@warning_ignore("integer_division")
	return navigable_samples > (sample_points_per_cell / 2)

func _is_point_on_navmesh(point: Vector2) -> bool:
	if not navigation_map.is_valid():
		return false

	if not navigation_region or not navigation_region.navigation_polygon:
		return false

	var nav_poly := navigation_region.navigation_polygon
	var local_point := point - navigation_region.global_position

	# Check the BAKED navigation polygons (excludes obstacles)
	# This checks the actual navigable areas after baking, not the input outlines
	var vertices := nav_poly.get_vertices()
	if vertices.size() == 0:
		return false

	for i in range(nav_poly.get_polygon_count()):
		var polygon := nav_poly.get_polygon(i)
		# Convert polygon indices to actual vertex positions
		var polygon_points: PackedVector2Array = []
		for vertex_index in polygon:
			if vertex_index < vertices.size():
				polygon_points.append(vertices[vertex_index])

		if polygon_points.size() >= 3 and Geometry2D.is_point_in_polygon(local_point, polygon_points):
			return true

	return false

func update_cell_at_position(world_pos: Vector2) -> void:
	if not hex_grid:
		return
	
	var cell := hex_grid.get_cell_at_world_position(world_pos)
	if cell:
		hex_grid.set_cell_enabled(cell, _is_cell_navigable(cell))

func update_cells_in_area(center_pos: Vector2, radius_cells: int) -> void:
	if not hex_grid:
		return
	
	var center := hex_grid.get_cell_at_world_position(center_pos)
	if not center:
		return
	
	for cell in hex_grid.get_cells_in_range(center, radius_cells):
		hex_grid.set_cell_enabled(cell, _is_cell_navigable(cell))

func get_navigable_neighbor(from_cell: HexCell, to_cell: HexCell) -> HexCell:
	if not from_cell or not to_cell or not to_cell.enabled:
		return null
	
	var path := NavigationServer2D.map_get_path(
		navigation_map, from_cell.world_position, to_cell.world_position, true
	)
	return to_cell if path.size() > 0 else null

func refresh_integration() -> void:
	integrate_with_navmesh()

func get_integration_stats() -> Dictionary:
	if not hex_grid:
		return {}
	
	var stats := hex_grid.get_grid_stats()
	stats["navmesh_integrated"] = navigation_map.is_valid()
	stats["sample_points_per_cell"] = sample_points_per_cell
	return stats
