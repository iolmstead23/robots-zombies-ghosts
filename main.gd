extends Node2D

## Hexagonal Grid Navigation System with NavMesh Integration and Robot Control

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D
@onready var robot: CharacterBody2D = $"Robot Player"  # Your robot player

# Hex navigation components
var hex_cell_selector: HexCellSelector
var hex_path_visualizer: HexPathVisualizer
var hex_robot_navigator: HexRobotNavigator
var hex_path_tracker: HexPathTracker
var hex_pathfinder: HexPathfinder

var selected_cell: HexCell = null

func _ready() -> void:
	# Configure navmesh integration before initialization
	var nav_region: NavigationRegion2D = $SessionController/NavigationRegion2D

	if nav_region:
		print("Found NavigationRegion2D")
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true
		session_controller.navmesh_sample_points = 5
		print("Navmesh integration configured")
	else:
		push_warning("NavigationRegion2D not found - integration disabled")

	# Wait for session initialization
	await session_controller.terrain_initialized

	# Initialize hex navigation system
	_setup_hex_navigation()

	# Diagnose sprite positions
	print("\n" + "==============")
	print("SPRITE POSITION DIAGNOSTIC")
	print("==============")

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
	print("HEX NAVIGATION SYSTEM READY")
	print("Click a hex cell to navigate the robot")
	print("Press R to generate pathfinding report")
	print("Press C to clear path history")
	print("==============\n")

func _setup_hex_navigation() -> void:
	"""Initialize all hex navigation components"""
	var grid = session_controller.get_terrain()

	# Create pathfinder
	hex_pathfinder = HexPathfinder.new()
	hex_pathfinder.name = "HexPathfinder"
	hex_pathfinder.hex_grid = grid
	add_child(hex_pathfinder)

	# Create cell selector
	hex_cell_selector = HexCellSelector.new()
	hex_cell_selector.name = "HexCellSelector"
	hex_cell_selector.hex_grid = grid
	hex_cell_selector.cell_selected.connect(_on_cell_selected)
	add_child(hex_cell_selector)

	# Create path visualizer
	hex_path_visualizer = HexPathVisualizer.new()
	hex_path_visualizer.name = "HexPathVisualizer"
	hex_path_visualizer.hex_grid = grid
	add_child(hex_path_visualizer)

	# Add NavAgent2D follower to robot for automatic movement
	var nav_follower = preload("res://Robot/Scripts/NavAgent2DFollower.gd").new()
	nav_follower.name = "NavAgent2DFollower"
	nav_follower.movement_speed = 100.0  # Adjust speed as needed
	robot.add_child(nav_follower)
	nav_follower.activate()
	print("NavAgent2DFollower added and activated on robot")

	# Create robot navigator
	hex_robot_navigator = HexRobotNavigator.new()
	hex_robot_navigator.name = "HexRobotNavigator"
	hex_robot_navigator.hex_grid = grid
	hex_robot_navigator.hex_pathfinder = hex_pathfinder
	hex_robot_navigator.robot = robot
	hex_robot_navigator.waypoint_reach_distance = 15.0  # Slightly larger for smoother movement
	hex_robot_navigator.navigation_started.connect(_on_navigation_started)
	hex_robot_navigator.navigation_completed.connect(_on_navigation_completed)
	hex_robot_navigator.navigation_failed.connect(_on_navigation_failed)
	hex_robot_navigator.waypoint_reached.connect(_on_waypoint_reached)
	add_child(hex_robot_navigator)

	# Create path tracker
	hex_path_tracker = HexPathTracker.new()
	hex_path_tracker.name = "HexPathTracker"
	add_child(hex_path_tracker)

	print("Hex navigation components initialized")

func _input(event: InputEvent) -> void:
	var grid: HexGrid = session_controller.get_terrain()
	if not grid:
		return

	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.pressed:
			var mouse_pos: Vector2 = _get_world_mouse_position()

			# Left click - select cell and navigate
			if event.button_index == MOUSE_BUTTON_LEFT:
				print("\n=== CLICK DEBUG ===")
				print("Mouse position (world): ", mouse_pos)
				print("Camera position: ", camera.position)
				print("Camera zoom: ", camera.zoom)
				print("Grid offset: ", grid.grid_offset)

				var cell := grid.get_cell_at_world_position(mouse_pos)

				if cell:
					var distance := mouse_pos.distance_to(cell.world_position)
					print("Found cell: (%d, %d)" % [cell.q, cell.r])
					print("  Cell center: ", cell.world_position)
					print("  Distance: %.1f pixels" % distance)
					if distance > 20:
						print("  WARNING: Click is far from cell center!")

					_handle_cell_click(cell)
				else:
					print("No cell found at click position")
					var axial_coords := grid.world_position_to_axial(mouse_pos)
					print("  Calculated axial coords: ", axial_coords)
					print("  Grid bounds: (0,0) to (%d,%d)" % [grid.grid_width - 1, grid.grid_height - 1])

			# Right click - toggle cell enabled/disabled
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var cell := grid.get_cell_at_world_position(mouse_pos)
				if cell:
					_toggle_cell(cell, grid)

			# Camera zoom
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom *= 0.9

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		# R - Generate pathfinding report
		if event.keycode == KEY_R:
			hex_path_tracker.print_report()
		# C - Clear path history
		elif event.keycode == KEY_C:
			hex_path_tracker.clear_history()
			print("Path history cleared")
		# E - Export path data to JSON
		elif event.keycode == KEY_E:
			var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
			var filename = "user://pathfinding_data_%s.json" % timestamp
			hex_path_tracker.export_to_json(filename)

func _handle_cell_click(cell: HexCell) -> void:
	"""Handle clicking on a hex cell - select it and navigate robot to it"""
	print("\n" + "=".repeat(60))
	print("HEX CELL SELECTION & NAVIGATION")
	print("=".repeat(60))

	# Select the cell
	hex_cell_selector.select_cell(cell)
	selected_cell = cell

	print("\n--- Target Cell Info ---")
	print("Cell Coordinates: (%d, %d)" % [cell.q, cell.r])
	print("World Position: %s" % cell.world_position)
	print("Cell Enabled: %s" % cell.enabled)

	if not cell.enabled:
		print("\n❌ NAVIGATION BLOCKED: Cell is disabled")
		print("=".repeat(60) + "\n")
		return

	# Get robot's current position
	var robot_pos = robot.global_position
	var start_cell = session_controller.get_terrain().get_cell_at_world_position(robot_pos)

	if not start_cell:
		print("\n❌ NAVIGATION BLOCKED: Robot is not on the grid!")
		print("Robot Position: %s" % robot_pos)
		print("=".repeat(60) + "\n")
		return

	print("\n--- Robot Current State ---")
	print("Robot Position: %s" % robot_pos)
	print("Current Cell: (%d, %d)" % [start_cell.q, start_cell.r])
	print("Distance to Target: %d cells" % start_cell.distance_to(cell))

	# Calculate path
	print("\n--- Pathfinding ---")
	var start_time = Time.get_ticks_msec()
	var path = hex_pathfinder.find_path(start_cell, cell)
	var duration = Time.get_ticks_msec() - start_time

	print("Pathfinding Time: %.3f ms" % duration)
	print("Path Found: %s" % ("Yes" if path.size() > 0 else "No"))

	# Visualize the path
	hex_path_visualizer.set_path(path)

	# Log the path for tracking
	hex_path_tracker.log_path(start_cell, cell, path, float(duration))

	# Navigate the robot
	if path.size() > 0:
		print("\n--- Starting Navigation ---")
		print("Path Length: %d cells" % path.size())
		print("Movement Steps: %d" % (path.size() - 1))
		print("✅ Robot navigation started!")
		hex_robot_navigator.navigate_to_cell(cell)
	else:
		print("\n❌ NAVIGATION FAILED: No path found")

	print("=".repeat(60) + "\n")

func _on_cell_selected(_cell: HexCell) -> void:
	"""Called when a cell is selected"""
	# This is now logged in _handle_cell_click with more detail
	pass

func _on_navigation_started(target_cell: HexCell) -> void:
	"""Called when robot navigation starts"""
	print("\n" + "█".repeat(60))
	print("🤖 ROBOT NAVIGATION STARTED")
	print("█".repeat(60))
	print("Target Cell: (%d, %d)" % [target_cell.q, target_cell.r])
	print("Target Position: %s" % target_cell.world_position)

	var current_path = hex_robot_navigator.get_current_path()
	if current_path.size() > 0:
		print("Total Waypoints: %d" % current_path.size())
		print("Remaining Distance: %d cells" % hex_robot_navigator.get_remaining_distance())
	print("█".repeat(60) + "\n")

func _on_navigation_completed() -> void:
	"""Called when robot reaches destination"""
	print("\n" + "█".repeat(60))
	print("✅ ROBOT NAVIGATION COMPLETED")
	print("█".repeat(60))
	print("Robot Position: %s" % robot.global_position)

	if selected_cell:
		var final_cell = session_controller.get_terrain().get_cell_at_world_position(robot.global_position)
		if final_cell:
			print("Final Cell: (%d, %d)" % [final_cell.q, final_cell.r])
			var distance_to_target = robot.global_position.distance_to(selected_cell.world_position)
			print("Distance to Target Center: %.2f pixels" % distance_to_target)
			if distance_to_target < 20:
				print("🎯 Robot reached target accurately!")
			else:
				print("⚠️ Robot stopped %.2f pixels from target" % distance_to_target)

	print("█".repeat(60) + "\n")

func _on_navigation_failed(reason: String) -> void:
	"""Called when robot navigation fails"""
	print("\n" + "█".repeat(60))
	print("❌ ROBOT NAVIGATION FAILED")
	print("█".repeat(60))
	print("Reason: %s" % reason)
	print("Robot Position: %s" % robot.global_position)
	print("█".repeat(60) + "\n")
	push_warning("Navigation failed: %s" % reason)

func _on_waypoint_reached(cell: HexCell, index: int) -> void:
	"""Called when robot reaches each waypoint"""
	var total_waypoints = hex_robot_navigator.get_current_path().size()
	var remaining = hex_robot_navigator.get_remaining_distance()

	print("📍 Waypoint %d/%d reached: (%d, %d) | %d cells remaining" % [
		index + 1,
		total_waypoints,
		cell.q,
		cell.r,
		remaining
	])

func _get_world_mouse_position() -> Vector2:
	var viewport_pos: Vector2 = get_viewport().get_mouse_position()
	var canvas_transform: Transform2D = camera.get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_pos

func _toggle_cell(cell: HexCell, grid: HexGrid) -> void:
	"""Toggle a cell between enabled and disabled"""
	grid.set_cell_enabled(cell, not cell.enabled)
	print("Cell (%d,%d) %s" % [cell.q, cell.r, "enabled" if cell.enabled else "disabled"])

	# Update visualization if a path is currently shown
	if hex_path_visualizer.get_current_path().size() > 0:
		# Recalculate path if it passes through the toggled cell
		var current_path = hex_path_visualizer.get_current_path()
		if cell in current_path:
			print("Toggled cell is on current path - recalculating")
			if selected_cell:
				_handle_cell_click(selected_cell)

func _draw() -> void:
	if not session_controller.debug_mode:
		return

	# Draw selection indicator if a cell is selected
	if selected_cell:
		var pos: Vector2 = selected_cell.world_position
		var radius: float = session_controller.hex_grid.hex_size * 1.2
		draw_circle(pos, radius, Color(1, 1, 0, 0.3))

	# Draw navigation debug info
	if hex_robot_navigator and hex_robot_navigator.is_navigation_active():
		var current_path = hex_robot_navigator.get_current_path()

		if current_path.size() > 0:
			# Draw waypoint indicators
			for i in range(current_path.size()):
				var cell = current_path[i]
				var waypoint_pos = cell.world_position

				# Different colors for different waypoints
				var color: Color
				if i == 0:
					color = Color(0, 1, 0, 0.5)  # Green for start
				elif i == current_path.size() - 1:
					color = Color(1, 0, 0, 0.7)  # Red for target
				else:
					color = Color(0, 0.8, 1, 0.4)  # Cyan for intermediate

				# Draw waypoint circle
				draw_circle(waypoint_pos, 8, color)

				# Draw waypoint number
				var font = ThemeDB.fallback_font
				var text = str(i)
				var text_pos = waypoint_pos - Vector2(4, -4)
				draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

			# Draw line from robot to next waypoint
			var next_waypoint_index = hex_robot_navigator.current_waypoint_index
			if next_waypoint_index < current_path.size():
				var next_waypoint = current_path[next_waypoint_index]
				draw_line(robot.global_position, next_waypoint.world_position, Color(1, 0.5, 0, 0.8), 2.0)

				# Draw distance text
				var distance = robot.global_position.distance_to(next_waypoint.world_position)
				var mid_point = (robot.global_position + next_waypoint.world_position) / 2
				var font = ThemeDB.fallback_font
				var text = "%.0f px" % distance
				draw_string(font, mid_point, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.YELLOW)

func _process(_delta: float) -> void:
	# Continuous redraw if debug is enabled and we have navigation or selection
	if session_controller.debug_mode:
		if selected_cell or (hex_robot_navigator and hex_robot_navigator.is_navigation_active()):
			queue_redraw()
