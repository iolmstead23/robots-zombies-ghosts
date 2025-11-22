class_name HexNavmeshIntegration
extends Node

## Integrates HexGrid with Godot's NavigationRegion2D
## Automatically disables hex cells that are outside the navmesh or blocked by obstacles

signal integration_complete()

@export var hex_grid: HexGrid
@export var navigation_region: NavigationRegion2D
@export var sample_points_per_cell: int = 5  ## How many points to test per hex
@export var auto_integrate_on_ready: bool = true

## Navigation queries
var navigation_map: RID

func _ready() -> void:
	if auto_integrate_on_ready:
		await get_tree().process_frame
		integrate_with_navmesh()

func integrate_with_navmesh() -> void:
	"""Sync hex grid cells with NavigationRegion2D"""
	if not hex_grid:
		push_error("HexGridNavmeshIntegration: No HexGrid assigned")
		return
	
	if not navigation_region:
		push_error("HexGridNavmeshIntegration: No NavigationRegion2D assigned")
		return
	
	# Wait for navigation server to be ready
	await get_tree().physics_frame
	
	# Get navigation map
	navigation_map = navigation_region.get_navigation_map()
	
	if not navigation_map.is_valid():
		push_warning("HexGridNavmeshIntegration: Navigation map not ready, retrying...")
		await get_tree().create_timer(0.1).timeout
		integrate_with_navmesh()
		return
	
	print("HexGridNavmeshIntegration: Starting integration with navmesh...")
	
	var enabled_count: int = 0
	var disabled_count: int = 0
	
	# Check each hex cell
	for cell in hex_grid.cells:
		var is_navigable := _is_cell_navigable(cell)
		
		if is_navigable and not cell.enabled:
			hex_grid.set_cell_enabled(cell, true)
			enabled_count += 1
		elif not is_navigable and cell.enabled:
			hex_grid.set_cell_enabled(cell, false)
			disabled_count += 1
	
	print("HexGridNavmeshIntegration: Integration complete!")
	print("  Enabled: %d cells" % enabled_count)
	print("  Disabled: %d cells" % disabled_count)
	print("  Total navigable: %d cells" % hex_grid.enabled_cells.size())
	
	integration_complete.emit()

func _is_cell_navigable(cell: HexCell) -> bool:
	"""Check if a hex cell is within navigable space"""
	var center_pos := cell.world_position
	
	# Test center point
	if _is_point_on_navmesh(center_pos):
		return true
	
	# If center isn't navigable, test sample points around the hex
	if sample_points_per_cell > 1:
		var navigable_samples: int = 0
		var test_radius: float = hex_grid.hex_size * 0.7  # Test within 70% of hex radius
		
		for i in range(sample_points_per_cell):
			var angle: float = (TAU / sample_points_per_cell) * i
			var offset := Vector2(
				test_radius * cos(angle),
				test_radius * sin(angle)
			)
			var test_pos := center_pos + offset
			
			if _is_point_on_navmesh(test_pos):
				navigable_samples += 1
		
		# Consider cell navigable if majority of samples are on navmesh
		return navigable_samples > (sample_points_per_cell / 2)
	
	return false

func _is_point_on_navmesh(point: Vector2) -> bool:
	"""Check if a point is on the navigation mesh"""
	if not navigation_map.is_valid():
		return false
	
	# Get closest point on navmesh
	var closest_point := NavigationServer2D.map_get_closest_point(navigation_map, point)
	
	# Check if the point is close enough to the navmesh
	var distance := point.distance_to(closest_point)
	
	# If distance is very small, the point is on/near the navmesh
	return distance < 1.0  # Tolerance of 1 pixel

func update_cell_at_position(world_pos: Vector2) -> void:
	"""Update a specific hex cell based on navmesh at that position"""
	if not hex_grid:
		return
	
	var cell := hex_grid.get_cell_at_world_position(world_pos)
	if not cell:
		return
	
	var is_navigable := _is_cell_navigable(cell)
	hex_grid.set_cell_enabled(cell, is_navigable)

func update_cells_in_area(center_pos: Vector2, radius_cells: int) -> void:
	"""Update hex cells in an area based on current navmesh state"""
	if not hex_grid:
		return
	
	var center_cell := hex_grid.get_cell_at_world_position(center_pos)
	if not center_cell:
		return
	
	var cells_to_update := hex_grid.get_cells_in_range(center_cell, radius_cells)
	
	for cell in cells_to_update:
		var is_navigable := _is_cell_navigable(cell)
		hex_grid.set_cell_enabled(cell, is_navigable)

func get_navigable_neighbor(from_cell: HexCell, to_cell: HexCell) -> HexCell:
	"""
	Check if there's a valid navigation path between two cells
	Returns to_cell if navigable, null otherwise
	"""
	if not from_cell or not to_cell:
		return null
	
	if not to_cell.enabled:
		return null
	
	# Check if navigation path exists between cells
	var path := NavigationServer2D.map_get_path(
		navigation_map,
		from_cell.world_position,
		to_cell.world_position,
		true  # optimize
	)
	
	# If we got a valid path, the cell is reachable
	if path.size() > 0:
		return to_cell
	
	return null

func refresh_integration() -> void:
	"""Re-run the navmesh integration (call after baking new obstacles)"""
	integrate_with_navmesh()

func get_integration_stats() -> Dictionary:
	"""Get statistics about the navmesh integration"""
	if not hex_grid:
		return {}
	
	var stats := hex_grid.get_grid_stats()
	stats["navmesh_integrated"] = navigation_map.is_valid()
	stats["sample_points_per_cell"] = sample_points_per_cell
	
	return stats
