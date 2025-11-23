extends Node2D

## Hexagonal Grid Navigation System with NavMesh Integration

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D

var selected_cell: HexCell = null

func _ready() -> void:
	# â­ CONFIGURE NAVMESH INTEGRATION BEFORE INITIALIZATION
	var nav_region: NavigationRegion2D = $SessionController/NavigationRegion2D
	
	if nav_region:
		print("âœ“ Found NavigationRegion2D")
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true
		session_controller.navmesh_sample_points = 5
		print("âœ“ Navmesh integration configured")
	else:
		push_warning("NavigationRegion2D not found - integration disabled")
	
	# Wait for session initialization
	await session_controller.terrain_initialized
	
	# 🔍 DIAGNOSE ACTUAL SPRITE POSITIONS
	print("\n" + "==============")
	print("SPRITE POSITION DIAGNOSTIC")
	print("\n" + "==============")
	
	var grid = session_controller.get_terrain()
	print("Grid offset: ", grid.grid_offset)
	print("Hex size: ", grid.hex_size)
	
	# Check where hex cells are positioned
	var sample_cell = grid.get_cell_at_coords(Vector2i(15, 15))
	if sample_cell:
		print("\nSample hex cell (15, 15):")
		print("  World position: ", sample_cell.world_position)
		print("  Enabled: ", sample_cell.enabled)
	
	# Check actual floor sprite positions
	var ground = get_node_or_null("Ground")
	if ground and ground.get_child_count() > 0:
		print("\nFloor sprites:")
		for i in range(min(3, ground.get_child_count())):
			var sprite = ground.get_child(i)
			print("  Sprite %d: %s" % [i, sprite.global_position])
			if sprite is Sprite2D:
				print("    Offset: ", sprite.offset)
				print("    Centered: ", sprite.centered)
	
	print("\n" + "==============")

func _input(event: InputEvent) -> void:
	var grid: HexGrid = session_controller.get_terrain()
	if not grid:
		return
	
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.pressed:
			# âœ… CORRECTED: Get mouse position accounting for camera transformation
			var mouse_pos: Vector2 = _get_world_mouse_position()
			
			# Debug: Show click information
			if event.button_index == MOUSE_BUTTON_LEFT:
				print("\n=== CLICK DEBUG ===")
				print("Mouse position (world): ", mouse_pos)
				print("Camera position: ", camera.position)
				print("Camera zoom: ", camera.zoom)
				print("Grid offset: ", grid.grid_offset)
			
			var cell := grid.get_cell_at_world_position(mouse_pos)
			
			if cell:
				if event.button_index == MOUSE_BUTTON_LEFT:
					# Debug: Show distance between click and cell center
					var distance := mouse_pos.distance_to(cell.world_position)
					print("âœ“ Found cell: (%d, %d)" % [cell.q, cell.r])
					print("  Cell center: ", cell.world_position)
					print("  Distance: %.1f pixels" % distance)
					if distance > 20:
						print("  âš ï¸ WARNING: Click is far from cell center!")
						print("  Hex size may need adjustment")
					
					_select_cell(cell)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_cell(cell, grid)
			else:
				if event.button_index == MOUSE_BUTTON_LEFT:
					print("âœ— No cell found at click position")
					print("  Click may be outside grid bounds")
					
					# Additional debug: Try to show what axial coords would be
					var axial_coords := grid.world_position_to_axial(mouse_pos)
					print("  Calculated axial coords: ", axial_coords)
					print("  Grid bounds: (0,0) to (%d,%d)" % [grid.grid_width - 1, grid.grid_height - 1])
			
			# Camera zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom *= 0.9

func _get_world_mouse_position() -> Vector2:
	var viewport_pos: Vector2 = get_viewport().get_mouse_position()
	var canvas_transform: Transform2D = camera.get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_pos

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
	@warning_ignore("integer_division")
	var center_cell := grid.get_cell_at_coords(Vector2i(grid.grid_width / 2, grid.grid_height / 2))
	if center_cell:
		var distance: int = cell.distance_to(center_cell)
		print("Distance to center: %d meters" % distance)
	
	# Force redraw to show selection
	queue_redraw()

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
