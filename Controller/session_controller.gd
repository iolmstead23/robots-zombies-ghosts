class_name SessionController
extends Node

## Session Controller
## Initializes game sessions, manages state, and coordinates the hex grid terrain system

signal session_started()
signal session_ended()
signal terrain_initialized()

## Grid configuration
@export_group("Grid Configuration")
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var auto_initialize: bool = true

@export_group("Navigation Integration")
@export var navigation_region: NavigationRegion2D  ## Your NavigationRegion2D node
@export var integrate_with_navmesh: bool = true  ## Auto-sync with navmesh
@export var navmesh_sample_points: int = 5  ## Accuracy of navmesh detection

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true

## Node references
var hex_grid: HexGrid
var hex_grid_debug: HexGridDebug
var navmesh_integration: HexNavmeshIntegration

## Session state
var session_active: bool = false
var session_start_time: float = 0.0

func _ready() -> void:
	if auto_initialize:
		await get_tree().process_frame  # Wait for scene to be fully loaded
		initialize_session()

func initialize_session() -> void:
	"""Initialize a new game session with the hexagonal terrain grid"""
	print("SessionController: Initializing session...")
	
	# Create and setup hex grid
	_setup_hex_grid()
	
	# Create and setup debug visualization
	_setup_debug_system()
	
	# Initialize the grid
	hex_grid.initialize_grid(grid_width, grid_height)
	
	# Setup navmesh integration if NavigationRegion2D is assigned
	if integrate_with_navmesh and navigation_region:
		_setup_navmesh_integration()
	
	# Mark session as active
	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	
	terrain_initialized.emit()
	session_started.emit()
	
	print("SessionController: Session initialized successfully")
	_print_grid_stats()

func _setup_hex_grid() -> void:
	"""Create and configure the HexGrid controller"""
	hex_grid = HexGrid.new()
	hex_grid.name = "HexGrid"
	hex_grid.grid_width = grid_width
	hex_grid.grid_height = grid_height
	hex_grid.hex_size = hex_size
	hex_grid.layout_flat_top = true  # Flat-top for isometric view
	
	hex_grid.sprite_vertical_offset = 0.0
	
	add_child(hex_grid)

func _setup_debug_system() -> void:
	"""Create and configure the debug visualization system"""
	hex_grid_debug = HexGridDebug.new()
	hex_grid_debug.name = "HexGridDebug"
	hex_grid_debug.hex_grid = hex_grid
	hex_grid_debug.debug_enabled = debug_mode
	hex_grid_debug.show_disabled_outlines = false  # Only show enabled cells by default
	
	add_child(hex_grid_debug)

func _setup_navmesh_integration() -> void:
	"""Create and configure navmesh integration"""
	
	# Calculate grid offset based on NavigationRegion2D bounds
	if navigation_region and navigation_region.navigation_polygon:
		var nav_poly: NavigationPolygon = navigation_region.navigation_polygon
		var nav_global_pos: Vector2 = navigation_region.global_position
		
		# Calculate bounds manually from vertices
		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		
		# Get bounds from all outline vertices
		for i in range(nav_poly.get_outline_count()):
			var outline: PackedVector2Array = nav_poly.get_outline(i)
			for vertex in outline:
				min_pos.x = min(min_pos.x, vertex.x)
				min_pos.y = min(min_pos.y, vertex.y)
				max_pos.x = max(max_pos.x, vertex.x)
				max_pos.y = max(max_pos.y, vertex.y)
		
		# Set the grid offset to start at the navmesh origin
		if min_pos.x != INF:  # Check if we found valid vertices
			var bounds_pos := min_pos
			var bounds_size := max_pos - min_pos
			hex_grid.grid_offset = nav_global_pos + bounds_pos
			
			print("Positioning hex grid at navmesh bounds:")
			print("  Nav region global position: ", nav_global_pos)
			print("  Calculated bounds: pos=", bounds_pos, " size=", bounds_size)
			print("  Grid offset set to: ", hex_grid.grid_offset)
		else:
			push_warning("NavigationPolygon has no vertices - cannot calculate offset")
			hex_grid.grid_offset = nav_global_pos
			print("  Using nav region position as offset: ", nav_global_pos)
		
		# Re-initialize cells with new offset
		for cell in hex_grid.cells:
			cell.world_position = hex_grid._axial_to_world_position(cell.q, cell.r)
		
		print("  Updated cell positions with offset")
	
	navmesh_integration = HexNavmeshIntegration.new()
	navmesh_integration.name = "NavmeshIntegration"
	navmesh_integration.hex_grid = hex_grid
	navmesh_integration.navigation_region = navigation_region
	navmesh_integration.sample_points_per_cell = navmesh_sample_points
	navmesh_integration.auto_integrate_on_ready = false  # We'll call it manually
	
	add_child(navmesh_integration)
	
	# Wait for navigation to be ready, then integrate
	await navmesh_integration.integrate_with_navmesh()
	
	print("SessionController: Navmesh integration complete")
	
	# Update debug visualization
	if hex_grid_debug and hex_grid_debug.debug_enabled:
		hex_grid_debug.queue_redraw()

func end_session() -> void:
	"""End the current game session"""
	if not session_active:
		return
	
	print("SessionController: Ending session...")
	
	session_active = false
	
	if hex_grid:
		hex_grid.clear_grid()
	
	session_ended.emit()
	
	print("SessionController: Session ended")

func reset_session() -> void:
	"""Reset the current session"""
	end_session()
	await get_tree().process_frame
	initialize_session()

func set_debug_mode(enabled: bool) -> void:
	"""Toggle debug visualization"""
	debug_mode = enabled
	if hex_grid_debug:
		hex_grid_debug.set_debug_enabled(enabled)
	
	print("SessionController: Debug mode %s" % ("enabled" if enabled else "disabled"))

func toggle_debug_mode() -> void:
	"""Toggle debug mode on/off"""
	set_debug_mode(not debug_mode)

func _input(event: InputEvent) -> void:
	if not debug_hotkey_enabled:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			toggle_debug_mode()
			get_viewport().set_input_as_handled()

func get_terrain() -> HexGrid:
	"""Get reference to the terrain grid"""
	return hex_grid

func get_session_duration() -> float:
	"""Get duration of current session in seconds"""
	if not session_active:
		return 0.0
	
	return (Time.get_ticks_msec() / 1000.0) - session_start_time

func _print_grid_stats() -> void:
	"""Print grid statistics to console"""
	if not hex_grid:
		return
	
	var stats: Dictionary = hex_grid.get_grid_stats()
	print("Grid Stats:")
	print("  Dimensions: %dx%d" % [stats.grid_dimensions.x, stats.grid_dimensions.y])
	print("  Total Cells: %d" % stats.total_cells)
	print("  Enabled: %d" % stats.enabled_cells)
	print("  Disabled: %d" % stats.disabled_cells)
	print("  Hex Size: %.1f pixels" % stats.hex_size)

## Utility methods for game logic

func disable_terrain_at_position(world_pos: Vector2, radius_meters: int = 1) -> void:
	"""Disable terrain cells around a world position (e.g., placing an obstacle)"""
	if not hex_grid:
		return
	
	hex_grid.disable_cells_in_area(world_pos, radius_meters)

func enable_terrain_at_position(world_pos: Vector2, radius_meters: int = 1) -> void:
	"""Enable terrain cells around a world position (e.g., removing an obstacle)"""
	if not hex_grid:
		return
	
	hex_grid.enable_cells_in_area(world_pos, radius_meters)

func get_cell_at_position(world_pos: Vector2) -> HexCell:
	"""Get the hex cell at a world position"""
	if not hex_grid:
		return null
	
	return hex_grid.get_cell_at_world_position(world_pos)

func is_position_navigable(world_pos: Vector2) -> bool:
	"""Check if a world position is on navigable terrain"""
	var cell := get_cell_at_position(world_pos)
	return cell != null and cell.enabled

func get_distance_between_positions(from_pos: Vector2, to_pos: Vector2) -> int:
	"""Get distance in meters between two world positions"""
	if not hex_grid:
		return -1
	
	return hex_grid.get_distance_world(from_pos, to_pos)

func get_navigable_cells_in_range(center_pos: Vector2, range_meters: int) -> Array[HexCell]:
	"""Get all navigable cells within range of a position"""
	if not hex_grid:
		return []
	
	var center_cell := hex_grid.get_cell_at_world_position(center_pos)
	if not center_cell:
		return []
	
	return hex_grid.get_enabled_cells_in_range(center_cell, range_meters)

func refresh_navmesh_integration() -> void:
	"""Refresh hex grid based on current navmesh state (call after baking new obstacles)"""
	if navmesh_integration:
		navmesh_integration.refresh_integration()
		
		# Update debug visualization
		if hex_grid_debug and hex_grid_debug.debug_enabled:
			hex_grid_debug.queue_redraw()
		
		print("SessionController: Navmesh integration refreshed")
