class_name HexNavmeshIntegration
extends Node
## Syncs HexGrid cells with NavigationRegion2D; disables cells blocked or off-mesh

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
	# Validate dependencies
	if not hex_grid:
		push_error("Missing HexGrid reference")
		return
	if not navigation_region:
		push_error("Missing NavigationRegion2D reference")
		return

	await get_tree().physics_frame

	navigation_map = navigation_region.get_navigation_map()
	if not navigation_map.is_valid():
		push_warning("Navigation map not ready, retrying...")
		await get_tree().create_timer(0.1).timeout
		integrate_with_navmesh()
		return

	var enabled_count := 0
	var disabled_count := 0

	for cell in hex_grid.cells:
		var navigable := _is_cell_navigable(cell)
		if navigable != cell.enabled:
			hex_grid.set_cell_enabled(cell, navigable)
			enabled_count += int(navigable)
			disabled_count += int(not navigable)

	print_debug("HexNavmeshIntegration: Integration complete!")
	print_debug("Enabled: %d, Disabled: %d, Total: %d" % [
		enabled_count, disabled_count, hex_grid.enabled_cells.size()
	])
	integration_complete.emit()

func _is_cell_navigable(cell: HexCell) -> bool:
	# Main check: center in navmesh
	var center := cell.world_position
	if _is_point_on_navmesh(center):
		return true

	# If center fails, sample more points
	if sample_points_per_cell > 1:
		var navigable_samples := 0
		var r := hex_grid.hex_size * 0.7
		for i in sample_points_per_cell:
			var angle := (TAU / sample_points_per_cell) * i
			var delta := Vector2(r * cos(angle), r * sin(angle))
			if _is_point_on_navmesh(center + delta):
				navigable_samples += 1
		@warning_ignore("integer_division")
		return navigable_samples > (sample_points_per_cell / 2)

	return false

func _is_point_on_navmesh(point: Vector2) -> bool:
	if not navigation_map.is_valid(): return false
	var closest := NavigationServer2D.map_get_closest_point(navigation_map, point)
	return point.distance_to(closest) < 1.0

func update_cell_at_position(world_pos: Vector2) -> void:
	if not hex_grid: return
	var cell := hex_grid.get_cell_at_world_position(world_pos)
	if not cell: return
	hex_grid.set_cell_enabled(cell, _is_cell_navigable(cell))

func update_cells_in_area(center_pos: Vector2, radius_cells: int) -> void:
	if not hex_grid: return
	var ctr := hex_grid.get_cell_at_world_position(center_pos)
	if not ctr: return
	for cell in hex_grid.get_cells_in_range(ctr, radius_cells):
		hex_grid.set_cell_enabled(cell, _is_cell_navigable(cell))

func get_navigable_neighbor(from_cell: HexCell, to_cell: HexCell) -> HexCell:
	# Returns to_cell if reachable from from_cell, else null
	if not from_cell or not to_cell or not to_cell.enabled:
		return null
	var path := NavigationServer2D.map_get_path(
		navigation_map, from_cell.world_position, to_cell.world_position, true
	)
	return to_cell if path.size() > 0 else null

func refresh_integration() -> void:
	integrate_with_navmesh()

func get_integration_stats() -> Dictionary:
	if not hex_grid: return {}
	var stats := hex_grid.get_grid_stats()
	stats["navmesh_integrated"] = navigation_map.is_valid()
	stats["sample_points_per_cell"] = sample_points_per_cell
	return stats
