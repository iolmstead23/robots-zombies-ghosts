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
	if OS.is_debug_build() and navigation_region and navigation_region.navigation_polygon:
		var validation := validate_coverage(navigation_region.navigation_polygon)
		print("HexNavmeshIntegration: Coverage validation - %d/%d cells (%.1f%%)" % [
			validation.enabled_cells,
			validation.expected_cells,
			validation.coverage_ratio * 100.0
		])
		if not validation.fully_covered:
			push_warning("HexNavmeshIntegration: Grid may not fully cover navmesh area!")

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
	if not _validate_navmesh_ready():
		return false

	var local_point := _get_local_point(point)
	var nav_poly := navigation_region.navigation_polygon

	for i in range(nav_poly.get_polygon_count()):
		if _is_point_in_polygon_at_index(nav_poly, i, local_point):
			return true

	return false

func _validate_navmesh_ready() -> bool:
	if not navigation_map.is_valid():
		return false
	if not navigation_region or not navigation_region.navigation_polygon:
		return false
	var vertices := navigation_region.navigation_polygon.get_vertices()
	return vertices.size() > 0

func _get_local_point(point: Vector2) -> Vector2:
	return point - navigation_region.global_position

func _is_point_in_polygon_at_index(nav_poly: NavigationPolygon, polygon_index: int, local_point: Vector2) -> bool:
	var polygon_points := _get_polygon_points(nav_poly, polygon_index)
	if polygon_points.size() < 3:
		return false
	return Geometry2D.is_point_in_polygon(local_point, polygon_points)

func _get_polygon_points(nav_poly: NavigationPolygon, polygon_index: int) -> PackedVector2Array:
	var polygon := nav_poly.get_polygon(polygon_index)
	var vertices := nav_poly.get_vertices()
	var points: PackedVector2Array = []
	for vertex_index in polygon:
		if vertex_index < vertices.size():
			points.append(vertices[vertex_index])
	return points

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

func validate_coverage(nav_poly: NavigationPolygon) -> Dictionary:
	# Calculate coverage statistics
	var bounds := _calculate_bounds(nav_poly)
	var coverage_area := bounds.size.x * bounds.size.y
	var cell_area := hex_grid.hex_size * hex_grid.hex_size * 2.598  # Hex area formula (3*sqrt(3)/2 * r^2)
	var expected_cells := ceili(coverage_area / cell_area)

	var enabled_count := hex_grid.enabled_cells.size()
	var coverage_ratio := float(enabled_count) / float(expected_cells) if expected_cells > 0 else 0.0

	return {
		"expected_cells": expected_cells,
		"enabled_cells": enabled_count,
		"coverage_ratio": coverage_ratio,
		"fully_covered": coverage_ratio >= 0.9,  # 90% threshold
		"bounds": bounds
	}

func _calculate_bounds(nav_poly: NavigationPolygon) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for i in nav_poly.get_outline_count():
		var outline := nav_poly.get_outline(i)
		for v in outline:
			min_pos = min_pos.min(v)
			max_pos = max_pos.max(v)

	if min_pos.x == INF:
		return Rect2()

	return Rect2(min_pos, max_pos - min_pos)

func get_integration_stats() -> Dictionary:
	if not hex_grid:
		return {}

	var stats := hex_grid.get_grid_stats()
	stats["navmesh_integrated"] = navigation_map.is_valid()
	stats["sample_points_per_cell"] = sample_points_per_cell
	return stats
