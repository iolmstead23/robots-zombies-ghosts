extends Node2D

## Hexagonal Grid Navigation System with NavMesh Integration

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D

var selected_cell: HexCell = null

func _ready() -> void:
	# ⭐ CONFIGURE NAVMESH INTEGRATION BEFORE INITIALIZATION
	var nav_region: NavigationRegion2D = $SessionController/NavigationRegion2D
	
	if nav_region:
		print("✓ Found NavigationRegion2D")
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true
		session_controller.navmesh_sample_points = 5
		print("✓ Navmesh integration configured")
	else:
		push_warning("NavigationRegion2D not found - integration disabled")
	
	# Wait for session initialization
	await session_controller.terrain_initialized
	
	print("\n=== Hexagonal Grid System Demo ===\n")
	
	# Example 1: Accessing the grid
	var grid: HexGrid = session_controller.get_terrain()
	print("Grid has %d total cells" % grid.cells.size())
	print("Grid offset: %s" % grid.grid_offset)
	print("Navigable cells: %d" % grid.enabled_cells.size())
	print("Blocked cells: %d" % (grid.cells.size() - grid.enabled_cells.size()))
	
	# Example 2: Get a specific cell
	var center_cell := grid.get_cell_at_coords(Vector2i(10, 7))
	if center_cell:
		print("Center cell: %s at position %s" % [center_cell, center_cell.world_position])
	
	# Example 3: Don't create manual obstacle pattern - navmesh handles this now!
	# _create_obstacle_pattern(grid)  # ← REMOVED - navmesh does this automatically
	
	# Example 4: Distance calculations
	var cell_a := grid.get_cell_at_coords(Vector2i(5, 5))
	var cell_b := grid.get_cell_at_coords(Vector2i(8, 7))
	if cell_a and cell_b:
		var distance: int = cell_a.distance_to(cell_b)
		print("Distance from (%d,%d) to (%d,%d): %d meters" % [
			cell_a.q, cell_a.r, cell_b.q, cell_b.r, distance
		])
	
	# Example 5: Get cells in range
	if center_cell:
		var cells_in_range := grid.get_enabled_cells_in_range(center_cell, 3)
		print("Found %d navigable cells within 3 meters of center" % cells_in_range.size())
	
	print("\nControls:")
	print("  F3 - Toggle debug visualization")
	print("  Left Click - Select cell and show info")
	print("  Right Click - Toggle cell enabled/disabled")
	print("  Mouse Wheel - Zoom camera")
	print("\n")

func _input(event: InputEvent) -> void:
	var grid: HexGrid = session_controller.get_terrain()
	if not grid:
		return
	
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.pressed:
			var mouse_pos: Vector2 = get_global_mouse_position()
			
			# Debug: Show click information
			if event.button_index == MOUSE_BUTTON_LEFT:
				print("\n=== CLICK DEBUG ===")
				print("Mouse position: ", mouse_pos)
				print("Grid offset: ", grid.grid_offset)
			
			var cell := grid.get_cell_at_world_position(mouse_pos)
			
			if cell:
				if event.button_index == MOUSE_BUTTON_LEFT:
					# Debug: Show distance between click and cell center
					var distance := mouse_pos.distance_to(cell.world_position)
					print("✓ Found cell: (%d, %d)" % [cell.q, cell.r])
					print("  Cell center: ", cell.world_position)
					print("  Distance: %.1f pixels" % distance)
					if distance > 20:
						print("  ⚠️ WARNING: Click is far from cell center!")
						print("  Hex size may need adjustment")
					
					_select_cell(cell)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_cell(cell, grid)
			else:
				if event.button_index == MOUSE_BUTTON_LEFT:
					print("✗ No cell found at click position")
					print("  Click may be outside grid or grid offset is wrong")
			
			# Camera zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom *= 0.9

func _select_cell(cell: HexCell) -> void:
	"""Select a cell and display its information"""
	selected_cell = cell
	
	print("\n--- Selected Cell ---")
	print("Index: %d" % cell.index)
	print("Coordinates: (%d, %d)" % [cell.q, cell.r])
	print("World Position: %s" % cell.world_position)
	print("Enabled: %s" % cell.enabled)
	print("Cube Coords: %s" % cell.get_cube_coords())
	
	# Show neighbors
	var grid: HexGrid = session_controller.get_terrain()
	var neighbors := grid.get_neighbors(cell)
	var enabled_neighbors := grid.get_enabled_neighbors(cell)
	print("Neighbors: %d total, %d enabled" % [neighbors.size(), enabled_neighbors.size()])
	
	# Calculate distance to grid center
	var center_cell := grid.get_cell_at_coords(Vector2i(grid.grid_width / 2, grid.grid_height / 2))
	if center_cell:
		var distance: int = cell.distance_to(center_cell)
		print("Distance to center: %d meters" % distance)

func _toggle_cell(cell: HexCell, grid: HexGrid) -> void:
	"""Toggle a cell between enabled and disabled"""
	grid.set_cell_enabled(cell, not cell.enabled)
	print("Cell (%d,%d) %s" % [cell.q, cell.r, "enabled" if cell.enabled else "disabled"])

func _draw() -> void:
	# Draw selection indicator if a cell is selected
	if selected_cell and session_controller.debug_mode:
		var pos: Vector2 = selected_cell.world_position
		var radius: float = session_controller.hex_grid.hex_size * 1.2
		draw_circle(pos, radius, Color(1, 1, 0, 0.3))

func _process(_delta: float) -> void:
	# Continuous redraw if debug is enabled and we have a selection
	if session_controller.debug_mode and selected_cell:
		queue_redraw()
