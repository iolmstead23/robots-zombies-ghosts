extends Node2D

## Hex Alignment Diagnostic Tool (FIXED for dynamic hex_grid)
## Gets hex_grid reference from SessionController at runtime

@export var session_controller_path: NodePath  ## Path to SessionController
@export var camera: Camera2D

var hex_grid: HexGrid  # Will be set at runtime from SessionController
var session_controller: SessionController

var click_markers: Array[Node2D] = []
var MAX_MARKERS := 10

func _ready() -> void:
	# Get SessionController reference
	if session_controller_path:
		session_controller = get_node(session_controller_path)
	else:
		# Try to find it automatically
		session_controller = get_tree().get_first_node_in_group("session_controller")
		if not session_controller:
			session_controller = get_node_or_null("/root/Main/SessionController")
	
	if not session_controller:
		push_error("HexAlignmentDiagnostic: Could not find SessionController!")
		return
	
	# Wait for terrain to be initialized
	if not session_controller.session_active:
		await session_controller.terrain_initialized
	
	# Get hex_grid from SessionController
	hex_grid = session_controller.get_terrain()
	
	if not hex_grid:
		push_error("HexAlignmentDiagnostic: Could not get hex_grid from SessionController!")
		return
	
	# Auto-find camera if not set
	if not camera:
		camera = get_viewport().get_camera_2d()
	
	print("\n=== HEX ALIGNMENT DIAGNOSTIC STARTED ===")
	print("Instructions:")
	print("  - Click on hex cell centers")
	print("  - Watch console for alignment data")
	print("  - Red circles = click positions")
	print("  - Check if clicks align with hex centers")
	print("Grid Configuration:")
	print("  Grid offset: ", hex_grid.grid_offset)
	print("  Hex size: ", hex_grid.hex_size)
	print("  Grid dimensions: %dx%d" % [hex_grid.grid_width, hex_grid.grid_height])
	print("=====================================\n")

func _input(event: InputEvent) -> void:
	if not hex_grid or not camera:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var viewport_pos: Vector2 = get_viewport().get_mouse_position()
		var canvas_transform: Transform2D = camera.get_canvas_transform()
		var world_mouse_pos: Vector2 = canvas_transform.affine_inverse() * viewport_pos
		
		# Get cell at this position
		var cell := hex_grid.get_cell_at_world_position(world_mouse_pos)
		
		print("\n=== CLICK DIAGNOSTIC ===")
		print("Viewport Position: ", viewport_pos)
		print("World Mouse Position: ", world_mouse_pos)
		print("Grid Offset: ", hex_grid.grid_offset)
		print("Relative Position: ", world_mouse_pos - hex_grid.grid_offset)
		
		if cell:
			var distance := world_mouse_pos.distance_to(cell.world_position)
			var offset := world_mouse_pos - cell.world_position
			
			print("\n✓ Cell Found:")
			print("  Cell coords: (q=%d, r=%d)" % [cell.q, cell.r])
			print("  Cell center: ", cell.world_position)
			print("  Click distance from center: %.2f pixels" % distance)
			print("  Offset (X, Y): (%.2f, %.2f)" % [offset.x, offset.y])
			
			# Analyze the offset pattern
			if abs(offset.x) < 10 and abs(offset.y) > 20:
				print("\n⚠️ PATTERN DETECTED: Significant Y-offset, minimal X-offset")
				print("   Suggested fix: Add vertical offset adjustment")
				print("   Recommended offset: %.2f pixels" % -offset.y)
			elif abs(offset.x) > 20 or abs(offset.y) > 20:
				print("\n⚠️ PATTERN DETECTED: Large offset detected")
				if abs(offset.x) > 20:
					print("   X-offset issue: Adjust hex_size")
				if abs(offset.y) > 20:
					print("   Y-offset issue: Set sprite_vertical_offset = %.2f" % -offset.y)
			else:
				print("\n✓ Excellent alignment! Offset is minimal.")
		else:
			print("\n✗ No cell found at click position")
			
			# Try to calculate what the axial coords would be
			var axial := hex_grid.world_position_to_axial(world_mouse_pos)
			print("  Calculated axial: (q=%d, r=%d)" % [axial.x, axial.y])
			print("  Grid bounds: (0,0) to (%d,%d)" % [hex_grid.grid_width - 1, hex_grid.grid_height - 1])
			
			if axial.x < 0 or axial.x >= hex_grid.grid_width or axial.y < 0 or axial.y >= hex_grid.grid_height:
				print("  → Click is outside grid bounds")
				print("  Try clicking on the green hexagons")
			else:
				print("  → Coordinate calculation issue or cell disabled")
				print("  Grid offset might be incorrect: ", hex_grid.grid_offset)
		
		# Add visual marker
		_add_click_marker(world_mouse_pos)
		queue_redraw()

func _add_click_marker(pos: Vector2) -> void:
	var marker := Node2D.new()
	marker.global_position = pos
	add_child(marker)
	click_markers.append(marker)
	
	if click_markers.size() > MAX_MARKERS:
		var old_marker = click_markers.pop_front()
		old_marker.queue_free()

func _draw() -> void:
	# Draw click markers
	for marker in click_markers:
		if is_instance_valid(marker):
			draw_circle(to_local(marker.global_position), 8, Color.RED)
			draw_circle(to_local(marker.global_position), 10, Color.RED, false, 2.0)
