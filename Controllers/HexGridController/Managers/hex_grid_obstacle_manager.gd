class_name HexGridObstacleManager
extends Node2D

## Detects and manages obstacles in hex grid using 2D collision

signal obstacle_detected(world_pos: Vector2, cell: HexCell)
signal obstacle_removed(world_pos: Vector2, cell: HexCell)

@export var hex_grid: HexGrid
@export var auto_scan_on_ready: bool = false
@export var collision_mask: int = 1
@export var scan_radius: float = 10.0

var space_state: PhysicsDirectSpaceState2D

func _ready() -> void:
	if auto_scan_on_ready and hex_grid:
		await get_tree().process_frame
		scan_all_cells()

func _physics_process(_delta: float) -> void:
	if not space_state:
		space_state = get_world_2d().direct_space_state

func scan_all_cells() -> void:
	if not hex_grid:
		push_error("HexGridObstacleManager: No HexGrid assigned")
		return
	
	if not space_state:
		space_state = get_world_2d().direct_space_state
	
	var disabled_count := 0
	
	for cell in hex_grid.cells:
		if check_cell_for_obstacle(cell) and cell.enabled:
			hex_grid.set_cell_enabled(cell, false)
			disabled_count += 1
			obstacle_detected.emit(cell.world_position, cell)
	
	if OS.is_debug_build():
		print("HexGridObstacleManager: Disabled %d cells with obstacles" % disabled_count)

func check_cell_for_obstacle(cell: HexCell) -> bool:
	if not space_state:
		return false
	
	var query := PhysicsPointQueryParameters2D.new()
	query.position = cell.world_position
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var results: Array[Dictionary] = space_state.intersect_point(query, 1)
	return not results.is_empty()

func check_cell_for_obstacle_at_coords(coords: Vector2i) -> bool:
	if not hex_grid:
		return false
	
	var cell := hex_grid.get_cell_at_coords(coords)
	return check_cell_for_obstacle(cell) if cell else false

func scan_area(center_pos: Vector2, radius_cells: int) -> void:
	if not hex_grid:
		return
	
	var center_cell := hex_grid.get_cell_at_world_position(center_pos)
	if not center_cell:
		return
	
	for cell in hex_grid.get_cells_in_range(center_cell, radius_cells):
		var has_obstacle := check_cell_for_obstacle(cell)
		
		if has_obstacle and cell.enabled:
			hex_grid.set_cell_enabled(cell, false)
			obstacle_detected.emit(cell.world_position, cell)
		elif not has_obstacle and not cell.enabled:
			hex_grid.set_cell_enabled(cell, true)
			obstacle_removed.emit(cell.world_position, cell)

func register_static_obstacle(obstacle_body: Node2D, radius_cells: int = 1) -> void:
	if not hex_grid or not obstacle_body:
		return
	
	hex_grid.disable_cells_in_area(obstacle_body.global_position, radius_cells)
	
	if OS.is_debug_build():
		print("HexGridObstacleManager: Registered obstacle at %s (r=%d)" % [obstacle_body.global_position, radius_cells])

func unregister_static_obstacle(obstacle_body: Node2D, radius_cells: int = 1) -> void:
	if not hex_grid or not obstacle_body:
		return
	
	hex_grid.enable_cells_in_area(obstacle_body.global_position, radius_cells)

func batch_register_obstacles(obstacles: Array[Node2D], radius_cells: int = 1) -> void:
	for obstacle in obstacles:
		register_static_obstacle(obstacle, radius_cells)

func update_cell_at_position(world_pos: Vector2) -> void:
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
	if not hex_grid:
		return {}
	
	var stats := hex_grid.get_grid_stats()
	var total := float(stats.total_cells)
	stats["obstacle_coverage_percent"] = (float(stats.disabled_cells) / total) * 100.0 if total > 0 else 0.0
	return stats