# Controllers/NavigationController.gd
extends Node2D
class_name NavigationController

# Grid settings and state
var hex_cells: Dictionary = {}
var navigation_region: NavigationRegion2D
var grid_bounds: Rect2
var hex_size: float = 16.0

# Obstacle detection
@export var obstacle_collision_layer := 1
@export var obstacle_check_radius := 16.0
@export var use_shape_cast := true
@export var exclude_player_from_obstacles := true

var player_node: Node
var player_collision_rids: Array[RID] = []

# Visual
@export var grid_visible := true
@export var grid_color := Color(0.3, 0.7, 1.0, 0.5)
@export var disabled_cell_color := Color(1.0, 0.3, 0.3, 0.2)
@export var grid_line_width := 1.5
@export var draw_disabled_cells := false

@export var path_color := Color.YELLOW
@export var path_width := 3.0
@export var draw_path_nodes := true
@export var path_node_radius := 4.0

# State/cache
var current_path: Array[Vector3i] = []
var path_generation_time := 0.0
var grid_generation_time := 0.0
var total_cells := 0
var enabled_cells := 0
var _grid_ready := false

# Signals
signal path_calculated(path: Array[Vector2])
signal grid_generated(total: int, enabled: int)
signal pathfinding_failed(start: Vector2, end: Vector2)
signal grid_ready()

func _ready() -> void:
	set_process(false)
	_initialize_navigation()
	if navigation_region:
		_cache_player_obstacles()
		_wait_for_navigation_map()
	else:
		push_error("NavigationController: NavigationRegion2D not found!")

func _initialize_navigation() -> void:
	# Try to find the navigation region
	navigation_region = get_parent().get_node_or_null("NavigationRegion2D")
	if not navigation_region:
		navigation_region = _find_navigation_region()

func _find_navigation_region() -> NavigationRegion2D:
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

func _wait_for_navigation_map() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not navigation_region.enabled:
		navigation_region.enabled = true
		await get_tree().process_frame
	var nav_poly = navigation_region.navigation_polygon
	if not nav_poly or (nav_poly.get_polygon_count() == 0 and nav_poly.get_outline_count() == 0):
		push_error("NavigationController: No NavigationPolygon assigned or baked!")
		return
	if nav_poly.get_polygon_count() == 0 and nav_poly.get_outline_count() > 0:
		nav_poly.make_polygons_from_outlines()
		await get_tree().process_frame
	generate_grid()

func _cache_player_obstacles() -> void:
	player_node = null
	player_collision_rids.clear()
	if not exclude_player_from_obstacles:
		return

	for player_name in ["Robot Player", "Player", "RobotPlayer", "robot_player"]:
		player_node = get_tree().root.find_child(player_name, true, false)
		if player_node: break
	if not player_node:
		return

	_collect_player_collision_rids(player_node)

func _collect_player_collision_rids(node: Node) -> void:
	if node is CollisionObject2D:
		player_collision_rids.append(node.get_rid())
	for child in node.get_children():
		_collect_player_collision_rids(child)

func generate_grid() -> void:
	var start_time = Time.get_ticks_msec()
	hex_cells.clear()
	_grid_ready = false
	var nav_polygon = navigation_region.navigation_polygon
	if not nav_polygon or nav_polygon.get_outline_count() == 0:
		push_error("NavigationController: No navigation polygon!")
		return
	_set_grid_bounds(nav_polygon)
	var bounds = _get_cube_bounds()
	var min_q = bounds[0]
	var max_q = bounds[1]
	var min_r = bounds[2]
	var max_r = bounds[3]
	var map_rid = navigation_region.get_navigation_map()
	var rejection_counters = [0, 0, 0]  # bounds, navmesh, obstacle
	var stats = [0, 0]  # total, enabled
	for q in range(min_q, max_q + 1):
		for r in range(min_r, max_r + 1):
			var s = -q - r
			var cube = Vector3i(q, r, s)
			var world_pos = HexGrid.cube_to_world(cube, hex_size)
			if not grid_bounds.has_point(world_pos):
				rejection_counters[0] += 1
				continue
			var closest_point = NavigationServer2D.map_get_closest_point(map_rid, world_pos)
			if world_pos.distance_to(closest_point) >= hex_size * 1.5:
				rejection_counters[1] += 1
				continue
			if not _check_cell_clearance(world_pos):
				rejection_counters[2] += 1
				hex_cells[cube] = false
				stats[0] += 1
				continue
			hex_cells[cube] = true
			stats[0] += 1
			stats[1] += 1
	total_cells = stats[0]
	enabled_cells = stats[1]
	grid_generation_time = Time.get_ticks_msec() - start_time
	_grid_ready = true
	grid_generated.emit(total_cells, enabled_cells)
	grid_ready.emit()
	queue_redraw()

func _set_grid_bounds(nav_polygon: NavigationPolygon) -> void:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for i in nav_polygon.get_outline_count():
		for vertex in nav_polygon.get_outline(i):
			var pos = navigation_region.to_global(vertex)
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.y = min(min_pos.y, pos.y)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.y = max(max_pos.y, pos.y)
	grid_bounds = Rect2(min_pos, max_pos - min_pos)

func _get_cube_bounds() -> Array:
	var corners = [
		HexGrid.world_to_cube(grid_bounds.position, hex_size),
		HexGrid.world_to_cube(Vector2(grid_bounds.position.x + grid_bounds.size.x, grid_bounds.position.y), hex_size),
		HexGrid.world_to_cube(Vector2(grid_bounds.position.x, grid_bounds.position.y + grid_bounds.size.y), hex_size),
		HexGrid.world_to_cube(grid_bounds.position + grid_bounds.size, hex_size)
	]
	var qs = [corners[0].x, corners[1].x, corners[2].x, corners[3].x]
	var rs = [corners[0].y, corners[1].y, corners[2].y, corners[3].y]
	var padding = 2
	return [
		qs.min() - padding,
		qs.max() + padding,
		rs.min() - padding,
		rs.max() + padding
	]

func _check_cell_clearance(world_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	if use_shape_cast:
		var shape = CircleShape2D.new()
		shape.radius = obstacle_check_radius
		var query = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, world_pos)
		query.collision_mask = obstacle_collision_layer
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if exclude_player_from_obstacles and not player_collision_rids.is_empty():
			query.exclude = player_collision_rids
		return space_state.intersect_shape(query, 1).is_empty()
	else:
		var query = PhysicsPointQueryParameters2D.new()
		query.position = world_pos
		query.collision_mask = obstacle_collision_layer
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if exclude_player_from_obstacles and not player_collision_rids.is_empty():
			query.exclude = player_collision_rids
		return space_state.intersect_point(query, 1).is_empty()

func is_grid_ready() -> bool:
	return _grid_ready and total_cells > 0

func is_cell_enabled(cube: Vector3i) -> bool:
	return hex_cells.get(cube, false)

func get_cell_world_position(cube: Vector3i) -> Vector2:
	return HexGrid.cube_to_world(cube, hex_size)

func get_cell_at_position(world_pos: Vector2) -> Vector3i:
	return HexGrid.world_to_cube(world_pos, hex_size)

func find_path(start_world: Vector2, end_world: Vector2) -> Array[Vector2]:
	if not is_grid_ready():
		pathfinding_failed.emit(start_world, end_world)
		return []
	var start_cube = HexGrid.world_to_cube(start_world, hex_size)
	var end_cube = HexGrid.world_to_cube(end_world, hex_size)
	if not is_cell_enabled(start_cube):
		start_cube = find_nearest_enabled_cell(start_cube)
		if start_cube == Vector3i.ZERO and not is_cell_enabled(Vector3i.ZERO):
			pathfinding_failed.emit(start_world, end_world)
			return []
	if not is_cell_enabled(end_cube):
		end_cube = find_nearest_enabled_cell(end_cube)
		if end_cube == Vector3i.ZERO and not is_cell_enabled(Vector3i.ZERO):
			pathfinding_failed.emit(start_world, end_world)
			return []
	var start_time = Time.get_ticks_usec()
	var path_cubes = _astar_hex_path(start_cube, end_cube)
	if path_cubes.is_empty():
		pathfinding_failed.emit(start_world, end_world)
		return []
	var world_path = []
	for cube in path_cubes:
		world_path.append(HexGrid.cube_to_world(cube, hex_size))
	var smoothed = PathSmoother.smooth_path_simple(world_path, 15.0)
	if smoothed.size() < world_path.size() * 0.8 or smoothed.size() < 10:
		world_path = smoothed
	current_path = path_cubes
	path_generation_time = (Time.get_ticks_usec() - start_time) / 1000.0
	path_calculated.emit(world_path)
	queue_redraw()
	return world_path

func _astar_hex_path(start: Vector3i, goal: Vector3i) -> Array[Vector3i]:
	var open_set: Array[Vector3i] = [start]
	var came_from := {}
	var g_score := {start: 0}
	var f_score := {start: HexGrid.cube_distance(start, goal)}
	while not open_set.is_empty():
		var current: Vector3i = open_set[0]
		for node in open_set:
			if f_score.get(node, INF) < f_score.get(current, INF):
				current = node
		if current == goal:
			return _reconstruct_path(came_from, current, start)
		open_set.erase(current)
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
	return []

func _reconstruct_path(came_from: Dictionary, current: Vector3i, start: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	while current in came_from:
		path.push_front(current)
		current = came_from[current]
	path.push_front(start)
	return path

func find_nearest_enabled_cell(cube: Vector3i, max_distance: int = 10) -> Vector3i:
	if is_cell_enabled(cube):
		return cube
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
	return Vector3i.ZERO

func clear_path() -> void:
	current_path.clear()
	queue_redraw()

func regenerate_grid() -> void:
	_cache_player_obstacles()
	_wait_for_navigation_map()

func regenerate_grid_immediate() -> void:
	_cache_player_obstacles()
	generate_grid()

func _draw() -> void:
	if not grid_visible:
		return
	for cube in hex_cells:
		var is_enabled = hex_cells[cube]
		if not is_enabled and not draw_disabled_cells:
			continue
		var center = HexGrid.cube_to_world(cube, hex_size)
		var vertices = HexGrid.get_hex_vertices(center, hex_size * 0.9)
		var color = grid_color if is_enabled else disabled_cell_color
		for i in range(6):
			draw_line(vertices[i], vertices[(i + 1) % 6], color, grid_line_width)
	if current_path.size() > 1:
		var path_points := PackedVector2Array()
		for cube in current_path:
			path_points.append(HexGrid.cube_to_world(cube, hex_size))
		draw_polyline(path_points, path_color, path_width)
		if draw_path_nodes:
			for point in path_points:
				draw_circle(point, path_node_radius, path_color)

func toggle_grid_visibility() -> void:
	grid_visible = not grid_visible
	queue_redraw()

func set_grid_visible(toggle_visible: bool) -> void:
	grid_visible = toggle_visible
	queue_redraw()

func get_grid_stats() -> Dictionary:
	return {
		"total_cells": total_cells,
		"enabled_cells": enabled_cells,
		"disabled_cells": total_cells - enabled_cells,
		"grid_bounds": grid_bounds,
		"generation_time_ms": grid_generation_time,
		"last_path_time_ms": path_generation_time,
		"last_path_length": current_path.size(),
		"grid_ready": _grid_ready
	}
