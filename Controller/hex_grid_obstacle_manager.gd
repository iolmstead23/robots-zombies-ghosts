class_name HexGridObstacleManager
extends Node2D

## Manages automatic detection and handling of obstacles in the hex grid
## Integrates with Godot's 2D collision system to disable cells blocked by obstacles

signal obstacle_detected(world_pos: Vector2, cell: HexCell)
signal obstacle_removed(world_pos: Vector2, cell: HexCell)

@export var hex_grid: HexGrid
@export var auto_scan_on_ready: bool = false
@export var collision_mask: int = 1  ## Which physics layers to check for obstacles
@export var scan_radius: float = 10.0  ## Radius around each hex center to check for collisions

## Physics query
var space_state: PhysicsDirectSpaceState2D

func _ready() -> void:
	if auto_scan_on_ready and hex_grid:
		await get_tree().process_frame
		scan_all_cells()

func _physics_process(_delta: float) -> void:
	if not space_state:
		space_state = get_world_2d().direct_space_state

func scan_all_cells() -> void:
	"""Scan all cells in the grid and disable those with obstacles"""
	if not hex_grid:
		push_error("HexGridObstacleManager: No HexGrid assigned")
		return
	
	if not space_state:
		space_state = get_world_2d().direct_space_state
	
	print("HexGridObstacleManager: Scanning %d cells for obstacles..." % hex_grid.cells.size())
	
	var disabled_count: int = 0
	
	for cell in hex_grid.cells:
		var has_obstacle := check_cell_for_obstacle(cell)
		if has_obstacle and cell.enabled:
			hex_grid.set_cell_enabled(cell, false)
			disabled_count += 1
			obstacle_detected.emit(cell.world_position, cell)
	
	print("HexGridObstacleManager: Scan complete. %d cells disabled due to obstacles." % disabled_count)

func check_cell_for_obstacle(cell: HexCell) -> bool:
	"""Check if a specific cell has an obstacle using physics raycasting"""
	if not space_state:
		return false
	
	var center: Vector2 = cell.world_position
	
	# Create a circular query around the cell center
	var query := PhysicsPointQueryParameters2D.new()
	query.position = center
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	# Check for intersections
	var results: Array[Dictionary] = space_state.intersect_point(query, 1)
	
	return not results.is_empty()

func check_cell_for_obstacle_at_coords(coords: Vector2i) -> bool:
	"""Check if cell at coordinates has an obstacle"""
	if not hex_grid:
		return false
	
	var cell := hex_grid.get_cell_at_coords(coords)
	if not cell:
		return false
	
	return check_cell_for_obstacle(cell)

func scan_area(center_pos: Vector2, radius_cells: int) -> void:
	"""Scan cells in an area for obstacles"""
	if not hex_grid:
		return
	
	var center_cell := hex_grid.get_cell_at_world_position(center_pos)
	if not center_cell:
		return
	
	var cells_to_check := hex_grid.get_cells_in_range(center_cell, radius_cells)
	
	for cell in cells_to_check:
		var has_obstacle := check_cell_for_obstacle(cell)
		if has_obstacle and cell.enabled:
			hex_grid.set_cell_enabled(cell, false)
			obstacle_detected.emit(cell.world_position, cell)
		elif not has_obstacle and not cell.enabled:
			hex_grid.set_cell_enabled(cell, true)
			obstacle_removed.emit(cell.world_position, cell)

func register_static_obstacle(obstacle_body: Node2D, radius_cells: int = 1) -> void:
	"""Register a static obstacle and disable surrounding cells"""
	if not hex_grid or not obstacle_body:
		return
	
	var obstacle_pos: Vector2 = obstacle_body.global_position
	hex_grid.disable_cells_in_area(obstacle_pos, radius_cells)
	
	print("HexGridObstacleManager: Registered obstacle at %s with radius %d" % [obstacle_pos, radius_cells])

func unregister_static_obstacle(obstacle_body: Node2D, radius_cells: int = 1) -> void:
	"""Remove a static obstacle and re-enable surrounding cells"""
	if not hex_grid or not obstacle_body:
		return
	
	var obstacle_pos: Vector2 = obstacle_body.global_position
	hex_grid.enable_cells_in_area(obstacle_pos, radius_cells)
	
	print("HexGridObstacleManager: Unregistered obstacle at %s" % obstacle_pos)

func batch_register_obstacles(obstacles: Array[Node2D], radius_cells: int = 1) -> void:
	"""Register multiple obstacles at once"""
	for obstacle in obstacles:
		register_static_obstacle(obstacle, radius_cells)

func update_cell_at_position(world_pos: Vector2) -> void:
	"""Update a single cell's state based on current obstacle presence"""
	var cell := hex_grid.get_cell_at_world_position(world_pos)
	if not cell:
		return
	
	var has_obstacle := check_cell_for_obstacle(cell)
	
	if has_obstacle and cell.enabled:
		hex_grid.set_cell_enabled(cell, false)
		obstacle_detected.emit(world_pos, cell)
	elif not has_obstacle and not cell.enabled:
		hex_grid.set_cell_enabled(cell, true)
		obstacle_removed.emit(world_pos, cell)

func get_obstacle_statistics() -> Dictionary:
	"""Get statistics about obstacles in the grid"""
	if not hex_grid:
		return {}
	
	var stats: Dictionary = hex_grid.get_grid_stats()
	stats["obstacle_coverage_percent"] = (float(stats.disabled_cells) / float(stats.total_cells)) * 100.0
	
	return stats
