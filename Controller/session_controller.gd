class_name SessionController
extends Node

## Manages game session with hex grid and navmesh integration

signal session_started()
signal session_ended()
signal terrain_initialized()

@export_group("Grid Configuration")
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var auto_initialize: bool = true

@export_group("Navigation Integration")
@export var navigation_region: NavigationRegion2D
@export var integrate_with_navmesh: bool = true
@export var navmesh_sample_points: int = 5

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true

# Components
var hex_grid: HexGrid
var hex_grid_debug: HexGridDebug
var navmesh_integration: HexNavmeshIntegration

# Session state
var session_active: bool = false
var session_start_time: float = 0.0

func _ready() -> void:
	if auto_initialize:
		await get_tree().process_frame
		initialize_session()

func initialize_session() -> void:
	_init_hex_grid()
	_init_debug()
	hex_grid.initialize_grid(grid_width, grid_height)
	
	if integrate_with_navmesh and navigation_region:
		await _init_navmesh()
	
	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	terrain_initialized.emit()
	session_started.emit()
	_print_stats()

func _init_hex_grid() -> void:
	hex_grid = HexGrid.new()
	hex_grid.name = "HexGrid"
	hex_grid.grid_width = grid_width
	hex_grid.grid_height = grid_height
	hex_grid.hex_size = hex_size
	hex_grid.layout_flat_top = true
	hex_grid.sprite_vertical_offset = 0.0
	add_child(hex_grid)

func _init_debug() -> void:
	hex_grid_debug = HexGridDebug.new()
	hex_grid_debug.name = "HexGridDebug"
	hex_grid_debug.hex_grid = hex_grid
	hex_grid_debug.debug_enabled = debug_mode
	hex_grid_debug.show_disabled_outlines = false
	add_child(hex_grid_debug)

func _init_navmesh() -> void:
	if not navigation_region or not navigation_region.navigation_polygon:
		return
	
	var nav_poly := navigation_region.navigation_polygon
	var nav_global_pos := navigation_region.global_position
	var bounds := _calculate_navmesh_bounds(nav_poly)
	
	hex_grid.grid_offset = nav_global_pos + bounds.position if bounds else nav_global_pos
	
	# Update cell positions
	for cell in hex_grid.cells:
		cell.world_position = hex_grid._axial_to_world(cell.q, cell.r)
	
	# Create and configure integration
	navmesh_integration = HexNavmeshIntegration.new()
	navmesh_integration.name = "NavmeshIntegration"
	navmesh_integration.hex_grid = hex_grid
	navmesh_integration.navigation_region = navigation_region
	navmesh_integration.sample_points_per_cell = navmesh_sample_points
	navmesh_integration.auto_integrate_on_ready = false
	add_child(navmesh_integration)
	
	await navmesh_integration.integrate_with_navmesh()
	
	if hex_grid_debug.debug_enabled:
		hex_grid_debug.queue_redraw()

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

func end_session() -> void:
	if not session_active:
		return
	
	session_active = false
	hex_grid.clear_grid()
	session_ended.emit()

func reset_session() -> void:
	end_session()
	await get_tree().process_frame
	initialize_session()

func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	hex_grid_debug.set_debug_enabled(enabled)
	
	if OS.is_debug_build():
		print("SessionController: Debug mode %s" % ("ON" if enabled else "OFF"))

func toggle_debug_mode() -> void:
	set_debug_mode(not debug_mode)

func _input(event: InputEvent) -> void:
	if not debug_hotkey_enabled:
		return
	
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle_debug_mode()
		get_viewport().set_input_as_handled()

# Accessors
func get_terrain() -> HexGrid:
	return hex_grid

func get_session_duration() -> float:
	if not session_active:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - session_start_time

func _print_stats() -> void:
	if not hex_grid or not OS.is_debug_build():
		return
	
	var stats := hex_grid.get_grid_stats()
	print("SessionController: Grid initialized")
	print("  Dimensions: %dx%d" % [stats.grid_dimensions.x, stats.grid_dimensions.y])
	print("  Total: %d | Enabled: %d | Disabled: %d" % [stats.total_cells, stats.enabled_cells, stats.disabled_cells])

# Game logic utilities
func disable_terrain_at_position(world_pos: Vector2, radius: int = 1) -> void:
	hex_grid.disable_cells_in_area(world_pos, radius)

func enable_terrain_at_position(world_pos: Vector2, radius: int = 1) -> void:
	hex_grid.enable_cells_in_area(world_pos, radius)

func get_cell_at_position(world_pos: Vector2) -> HexCell:
	return hex_grid.get_cell_at_world_position(world_pos) if hex_grid else null

func is_position_navigable(world_pos: Vector2) -> bool:
	var cell := get_cell_at_position(world_pos)
	return cell != null and cell.enabled

func get_distance_between_positions(from_pos: Vector2, to_pos: Vector2) -> int:
	return hex_grid.get_distance_world(from_pos, to_pos) if hex_grid else -1

func get_navigable_cells_in_range(center_pos: Vector2, range_meters: int) -> Array[HexCell]:
	if not hex_grid:
		return []
	
	var center_cell := hex_grid.get_cell_at_world_position(center_pos)
	return hex_grid.get_enabled_cells_in_range(center_cell, range_meters) if center_cell else []

func refresh_navmesh_integration() -> void:
	if navmesh_integration:
		navmesh_integration.refresh_integration()
		if hex_grid_debug.debug_enabled:
			hex_grid_debug.queue_redraw()
		
		if OS.is_debug_build():
			print("SessionController: Navmesh integration refreshed")