# Controllers/NavigationController.gd
extends Node2D
class_name NavigationController

## Manages the hexagonal grid overlay and pathfinding
## Overlays hex grid on navigation mesh and manages cell states

# Grid data
var hex_cells := {}  # Dictionary[Vector3i, bool] - cube coords to enabled state
var navigation_region: NavigationRegion2D
var grid_bounds := Rect2()
var hex_size := 8.0  # 2 meters of ground - adjust to your scale

# Collision detection parameters
@export var obstacle_collision_layer := 1  # Physics layer for static obstacles
@export var obstacle_check_radius := 16.0  # Radius for obstacle detection
@export var use_shape_cast := true  # Use shape casting for better accuracy

# Visualization settings
@export var grid_visible := true
@export var grid_color := Color(0.3, 0.7, 1.0, 0.5)
@export var disabled_cell_color := Color(1.0, 0.3, 0.3, 0.2)  # Optional: show disabled
@export var grid_line_width := 1.5
@export var draw_disabled_cells := false  # Set to true to see disabled cells

# Path visualization
@export var path_color := Color.YELLOW
@export var path_width := 3.0
@export var draw_path_nodes := true
@export var path_node_radius := 4.0

# Pathfinding cache
var current_path: Array[Vector3i] = []
var path_generation_time := 0.0

# Performance
var grid_generation_time := 0.0
var total_cells := 0
var enabled_cells := 0

# Debug
@export var debug_mode := false
@export var show_grid_stats := true

signal path_calculated(path: Array[Vector2])
signal grid_generated(total: int, enabled: int)
signal pathfinding_failed(start: Vector2, end: Vector2)

func _ready() -> void:
	set_process(false)  # Only process when needed
	
	# Find navigation region - try sibling first, then search
	if not navigation_region:
		# Try to find sibling first (most common case based on your scene tree)
		navigation_region = get_parent().get_node_or_null("NavigationRegion2D")
		
		if not navigation_region:
			# Fallback to scene-wide search
			navigation_region = _find_navigation_region()
	
	if navigation_region:
		if debug_mode:
			print("NavigationController: Found NavigationRegion2D at ", navigation_region.get_path())
		call_deferred("generate_grid")
	else:
		push_error("NavigationController: NavigationRegion2D not found!")

func _find_navigation_region() -> NavigationRegion2D:
	# Search in scene tree
	var root = get_tree().root
	return _find_node_recursive(root, NavigationRegion2D)

func _find_node_recursive(node: Node, node_type) -> NavigationRegion2D:
	if is_instance_of(node, node_type):
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, node_type)
		if result:
			return result
	
	return null

## Generate hexagonal grid overlay on navigation mesh
func generate_grid() -> void:
	var start_time = Time.get_ticks_msec()
	
	if not navigation_region:
		push_error("NavigationController: No NavigationRegion2D found!")
		return
	
	hex_cells.clear()
	
	# Get navigation polygon bounds
	var nav_polygon = navigation_region.navigation_polygon
	if not nav_polygon or nav_polygon.get_outline_count() == 0:
		push_error("NavigationController: No navigation polygon found!")
		return
	
	# Calculate grid bounds from navigation polygon
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for i in range(nav_polygon.get_outline_count()):
		var outline = nav_polygon.get_outline(i)
		for vertex in outline:
			var world_pos = navigation_region.to_global(vertex)
			min_pos.x = min(min_pos.x, world_pos.x)
			min_pos.y = min(min_pos.y, world_pos.y)
			max_pos.x = max(max_pos.x, world_pos.x)
			max_pos.y = max(max_pos.y, world_pos.y)
	
	grid_bounds = Rect2(min_pos, max_pos - min_pos)
	
	# Generate hex cells within bounds
	var cells_generated := 0
	var cells_enabled := 0
	
	# Calculate the hex grid range
	var min_cube = HexGrid.world_to_cube(min_pos, hex_size)
	var max_cube = HexGrid.world_to_cube(max_pos, hex_size)
	
	# Add padding to ensure full coverage
	var padding := 2
	
	# Iterate through potential hex cells
	for q in range(min_cube.x - padding, max_cube.x + padding + 1):
		for r in range(min_cube.y - padding, max_cube.y + padding + 1):
			var s = -q - r
			var cube = Vector3i(q, r, s)
			var world_pos = HexGrid.cube_to_world(cube, hex_size)
			
			# Check if cell center is within navigation polygon bounds
			if not grid_bounds.has_point(world_pos):
				continue
			
			var local_pos = navigation_region.to_local(world_pos)
			
			# Check if navigable via NavigationServer
			var is_navigable = NavigationServer2D.region_owns_point(
				navigation_region.get_rid(),
				navigation_region.to_global(local_pos)
			)
			
			if is_navigable:
				# Check for static obstacles using physics
				var is_clear = _check_cell_clearance(world_pos)
				
				hex_cells[cube] = is_clear
				cells_generated += 1
				if is_clear:
					cells_enabled += 1
	
	total_cells = cells_generated
	enabled_cells = cells_enabled
	grid_generation_time = Time.get_ticks_msec() - start_time
	
	if show_grid_stats:
		print("NavigationController: Grid generated in %d ms" % grid_generation_time)
		print("  Total cells: %d" % total_cells)
		print("  Enabled cells: %d (%.1f%%)" % [enabled_cells, (float(enabled_cells) / total_cells) * 100.0 if total_cells > 0 else 0.0])
		print("  Disabled cells: %d" % (total_cells - enabled_cells))
	
	grid_generated.emit(total_cells, enabled_cells)
	queue_redraw()

## Check if a cell position is clear of obstacles
func _check_cell_clearance(world_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	
	if use_shape_cast:
		# Use CircleShape2D for more accurate collision detection
		var shape = CircleShape2D.new()
		shape.radius = obstacle_check_radius
		
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, world_pos)
		query.collision_mask = obstacle_collision_layer
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_shape(query, 1)
		return result.is_empty()
	else:
		# Use point query (faster but less accurate)
		var query = PhysicsPointQueryParameters2D.new()
		query.position = world_pos
		query.collision_mask = obstacle_collision_layer
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_point(query, 1)
		return result.is_empty()

## Check if a specific cell is enabled
func is_cell_enabled(cube: Vector3i) -> bool:
	return hex_cells.get(cube, false)

## Get world position of a cell
func get_cell_world_position(cube: Vector3i) -> Vector2:
	return HexGrid.cube_to_world(cube, hex_size)

## Get cell at world position
func get_cell_at_position(world_pos: Vector2) -> Vector3i:
	return HexGrid.world_to_cube(world_pos, hex_size)

## Find path between two world positions using A* on hex grid
func find_path(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	var start_time = Time.get_ticks_usec()
	
	var start_cube = HexGrid.world_to_cube(start_world, hex_size)
	var end_cube = HexGrid.world_to_cube(end_world, hex_size)
	
	# Ensure start and end are valid cells
	if not is_cell_enabled(start_cube):
		start_cube = find_nearest_enabled_cell(start_cube)
		if start_cube == Vector3i.ZERO and not is_cell_enabled(Vector3i.ZERO):
			push_error("NavigationController: No valid start cell found near %v" % start_world)
			pathfinding_failed.emit(start_world, end_world)
			return []
	
	if not is_cell_enabled(end_cube):
		end_cube = find_nearest_enabled_cell(end_cube)
		if end_cube == Vector3i.ZERO and not is_cell_enabled(Vector3i.ZERO):
			push_error("NavigationController: No valid end cell found near %v" % end_world)
			pathfinding_failed.emit(start_world, end_world)
			return []
	
	# A* pathfinding on hex grid
	var path_cubes = _astar_hex_path(start_cube, end_cube)
	
	if path_cubes.is_empty():
		if debug_mode:
			print("NavigationController: No path found from %v to %v" % [start_cube, end_cube])
		pathfinding_failed.emit(start_world, end_world)
		return []
	
	# Convert to world positions
	var world_path: Array[Vector2] = []
	for cube in path_cubes:
		world_path.append(HexGrid.cube_to_world(cube, hex_size))
	
	current_path = path_cubes
	path_generation_time = (Time.get_ticks_usec() - start_time) / 1000.0
	
	if debug_mode:
		print("NavigationController: Path found in %.2f ms with %d nodes" % [path_generation_time, path_cubes.size()])
	
	path_calculated.emit(world_path)
	queue_redraw()  # Update visualization
	
	return world_path

## A* pathfinding algorithm on hexagonal grid
func _astar_hex_path(start: Vector3i, goal: Vector3i) -> Array[Vector3i]:
	# Priority queue using array (simple implementation)
	var open_set: Array[Vector3i] = [start]
	var came_from := {}
	var g_score := {start: 0}
	var f_score := {start: HexGrid.cube_distance(start, goal)}
	
	while not open_set.is_empty():
		# Find node with lowest f_score
		var current: Vector3i = open_set[0]
		var lowest_f = f_score.get(current, INF)
		
		for node in open_set:
			var f = f_score.get(node, INF)
			if f < lowest_f:
				current = node
				lowest_f = f
		
		# Goal reached
		if current == goal:
			return _reconstruct_path(came_from, current, start)
		
		open_set.erase(current)
		
		# Check neighbors
		for neighbor in HexGrid.get_cube_neighbors(current):
			if not is_cell_enabled(neighbor):
				continue
			
			var tentative_g = g_score.get(current, INF) + 1
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + HexGrid.cube_distance(neighbor, goal)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	return []  # No path found

## Reconstruct path from came_from dictionary
func _reconstruct_path(came_from: Dictionary, current: Vector3i, start: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	while current in came_from:
		path.push_front(current)
		current = came_from[current]
	path.push_front(start)
	return path

## Find nearest enabled cell to a given cube coordinate
func find_nearest_enabled_cell(cube: Vector3i, max_distance: int = 10) -> Vector3i:
	if is_cell_enabled(cube):
		return cube
	
	# BFS to find nearest enabled cell
	var visited := {cube: true}
	var queue: Array[Vector3i] = [cube]
	
	for distance in range(1, max_distance + 1):
		var next_queue: Array[Vector3i] = []
		for current in queue:
			for neighbor in HexGrid.get_cube_neighbors(current):
				if neighbor in visited:
					continue
				visited[neighbor] = true
				if is_cell_enabled(neighbor):
					return neighbor
				next_queue.append(neighbor)
		queue = next_queue
		
		if queue.is_empty():
			break
	
	return Vector3i.ZERO  # No enabled cell found

## Clear current path
func clear_path() -> void:
	current_path.clear()
	queue_redraw()

## Regenerate grid (call after level changes)
func regenerate_grid() -> void:
	generate_grid()

## Draw the hexagonal grid
func _draw() -> void:
	if not grid_visible:
		return
	
	# Draw hex cells
	for cube in hex_cells:
		var is_enabled = hex_cells[cube]
		
		# Skip disabled cells unless drawing them is enabled
		if not is_enabled and not draw_disabled_cells:
			continue
		
		var center = HexGrid.cube_to_world(cube, hex_size)
		var vertices = HexGrid.get_hex_vertices(center, hex_size * 0.9)
		
		# Choose color
		var color = grid_color if is_enabled else disabled_cell_color
		
		# Draw hex outline
		for i in range(6):
			var start_vertex = vertices[i]
			var end_vertex = vertices[(i + 1) % 6]
			draw_line(start_vertex, end_vertex, color, grid_line_width)
	
	# Draw current path if exists
	if current_path.size() > 1:
		var path_points := PackedVector2Array()
		for cube in current_path:
			path_points.append(HexGrid.cube_to_world(cube, hex_size))
		
		# Draw path line
		draw_polyline(path_points, path_color, path_width)
		
		# Draw path nodes
		if draw_path_nodes:
			for point in path_points:
				draw_circle(point, path_node_radius, path_color)

## Toggle grid visibility
func toggle_grid_visibility() -> void:
	grid_visible = not grid_visible
	queue_redraw()

## Set grid visibility
func set_grid_visible(toggle_visible: bool) -> void:
	grid_visible = toggle_visible
	queue_redraw()

## Enable/disable debug mode
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	show_grid_stats = enabled
	queue_redraw()

## Get grid statistics
func get_grid_stats() -> Dictionary:
	return {
		"total_cells": total_cells,
		"enabled_cells": enabled_cells,
		"disabled_cells": total_cells - enabled_cells,
		"grid_bounds": grid_bounds,
		"generation_time_ms": grid_generation_time,
		"last_path_time_ms": path_generation_time,
		"last_path_length": current_path.size()
	}
