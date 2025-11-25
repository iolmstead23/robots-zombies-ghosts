extends Node2D

## Hexagonal Grid Navigation System - Signal-Based Architecture
## This main script now delegates to SessionController and feature controllers

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D
@onready var robot: CharacterBody2D = $"Robot Player"

# Track selected cell for visualization
var selected_cell: HexCell = null

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("MAIN.GD _ready() CALLED")
	print("=".repeat(60))

	# Check if SessionController exists
	if not session_controller:
		push_error("CRITICAL: SessionController not found!")
		return

	print("SessionController found: ", session_controller.name)

	# Configure navmesh integration before initialization
	var nav_region: NavigationRegion2D = $SessionController/NavigationRegion2D

	if nav_region:
		print("Found NavigationRegion2D")
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true  # Grid dimensions auto-calculated from navmesh
		session_controller.navmesh_sample_points = 5
		session_controller.robot = robot
		print("Navmesh integration enabled")
	else:
		push_warning("NavigationRegion2D not found - integration disabled")

	print("Waiting for session initialization...")

	# Wait for session initialization
	await session_controller.session_initialized

	print("Session initialized signal received!")

	# Connect to navigation controller signals for logging
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		nav_controller.navigation_started.connect(_on_navigation_started)
		nav_controller.navigation_completed.connect(_on_navigation_completed)
		nav_controller.navigation_failed.connect(_on_navigation_failed)
		nav_controller.waypoint_reached.connect(_on_waypoint_reached)
		nav_controller.path_found.connect(_on_path_found)
		nav_controller.path_not_found.connect(_on_path_not_found)

	# Add NavAgent2D follower to robot for automatic movement
	var nav_follower = preload("res://Robot/Scripts/NavAgent2DFollower.gd").new()
	nav_follower.name = "NavAgent2DFollower"
	nav_follower.movement_speed = 100.0
	robot.add_child(nav_follower)
	nav_follower.activate()
	print("NavAgent2DFollower added and activated on robot")

	print("\n" + "=".repeat(60))
	print("HEX NAVIGATION SYSTEM READY - Signal-Based Architecture")
	print("=".repeat(60))
	print("Click a hex cell to navigate the robot")
	print("Right-click to toggle cell enabled/disabled")
	print("Press R to generate pathfinding report")
	print("Press C to clear path history")
	print("Press E to export path data to JSON")
	print("Press F3 to toggle debug mode")
	print("=".repeat(60) + "\n")

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
				var cell := grid.get_cell_at_world_position(mouse_pos)
				if cell:
					_handle_cell_click(cell)

			# Right click - toggle cell enabled/disabled
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				var cell := grid.get_cell_at_world_position(mouse_pos)
				if cell:
					_toggle_cell(cell)

			# Camera zoom
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom *= 1.1
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom *= 0.9

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		var nav_controller = session_controller.get_navigation_controller()
		if not nav_controller:
			return

		# R - Generate pathfinding report
		if event.keycode == KEY_R:
			var tracker = nav_controller.get_path_tracker()
			if tracker:
				tracker.print_report()

		# C - Clear path history
		elif event.keycode == KEY_C:
			var tracker = nav_controller.get_path_tracker()
			if tracker:
				tracker.clear_history()
				print("Path history cleared")

		# E - Export path data to JSON
		elif event.keycode == KEY_E:
			var tracker = nav_controller.get_path_tracker()
			if tracker:
				var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
				var filename = "user://pathfinding_data_%s.json" % timestamp
				tracker.export_to_json(filename)

func _handle_cell_click(cell: HexCell) -> void:
	"""Handle clicking on a hex cell - request navigation via SessionController"""
	print("\n" + "=".repeat(60))
	print("HEX CELL SELECTION & NAVIGATION REQUEST")
	print("=".repeat(60))

	selected_cell = cell

	print("\n--- Target Cell Info ---")
	print("Cell Coordinates: (%d, %d)" % [cell.q, cell.r])
	print("World Position: %s" % cell.world_position)
	print("Cell Enabled: %s" % cell.enabled)

	if not cell.enabled:
		print("\n❌ NAVIGATION BLOCKED: Cell is disabled")
		print("=".repeat(60) + "\n")
		return

	print("\n--- Robot Current State ---")
	print("Robot Position: %s" % robot.global_position)

	# Request navigation via SessionController (signal-based)
	session_controller.navigate_to_position(cell.world_position)

	print("=".repeat(60) + "\n")

# ============================================================================
# NAVIGATION CONTROLLER CALLBACKS
# ============================================================================

func _on_path_found(_start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float) -> void:
	print("\n--- Pathfinding Result ---")
	print("Path Found: Yes")
	print("Path Length: %d cells" % path.size())
	print("Pathfinding Time: %.3f ms" % duration_ms)
	print("Target: (%d, %d)" % [goal.q, goal.r])

func _on_path_not_found(_start_pos: Vector2, _goal_pos: Vector2, reason: String) -> void:
	print("\n--- Pathfinding Result ---")
	print("Path Found: No")
	print("Reason: %s" % reason)

func _on_navigation_started(target_cell: HexCell) -> void:
	"""Called when robot navigation starts"""
	print("\n" + "█".repeat(60))
	print("🤖 ROBOT NAVIGATION STARTED")
	print("█".repeat(60))
	print("Target Cell: (%d, %d)" % [target_cell.q, target_cell.r])
	print("Target Position: %s" % target_cell.world_position)

	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		var current_path = nav_controller.get_current_path()
		if current_path.size() > 0:
			print("Total Waypoints: %d" % current_path.size())

	print("█".repeat(60) + "\n")

func _on_navigation_completed() -> void:
	"""Called when robot reaches destination"""
	print("\n" + "█".repeat(60))
	print("✅ ROBOT NAVIGATION COMPLETED")
	print("█".repeat(60))
	print("Robot Position: %s" % robot.global_position)

	if selected_cell:
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

func _on_waypoint_reached(cell: HexCell, index: int, remaining: int) -> void:
	"""Called when robot reaches each waypoint"""
	var nav_controller = session_controller.get_navigation_controller()
	var total_waypoints = nav_controller.get_current_path().size() if nav_controller else 0

	print("📍 Waypoint %d/%d reached: (%d, %d) | %d cells remaining" % [
		index + 1,
		total_waypoints,
		cell.q,
		cell.r,
		remaining
	])

# ============================================================================
# HELPER METHODS
# ============================================================================

func _get_world_mouse_position() -> Vector2:
	var viewport_pos: Vector2 = get_viewport().get_mouse_position()
	var canvas_transform: Transform2D = camera.get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_pos

func _toggle_cell(cell: HexCell) -> void:
	"""Toggle a cell between enabled and disabled via SessionController"""
	var hex_grid_controller = session_controller.get_hex_grid_controller()
	if not hex_grid_controller:
		return

	var coords = Vector2i(cell.q, cell.r)
	hex_grid_controller.set_cell_enabled_requested.emit(coords, not cell.enabled)

	print("Cell (%d,%d) %s" % [cell.q, cell.r, "enabled" if not cell.enabled else "disabled"])

# ============================================================================
# DEBUG VISUALIZATION
# ============================================================================

func _draw() -> void:
	if not session_controller.debug_mode:
		return

	# Draw selection indicator if a cell is selected
	if selected_cell:
		var pos: Vector2 = selected_cell.world_position
		var grid = session_controller.get_terrain()
		var radius: float = grid.hex_size * 1.2 if grid else 38.4
		draw_circle(pos, radius, Color(1, 1, 0, 0.3))

	# Draw navigation debug info
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller and nav_controller.is_navigation_active():
		var current_path = nav_controller.get_current_path()

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

func _process(_delta: float) -> void:
	# Continuous redraw if debug is enabled and we have navigation or selection
	if session_controller.debug_mode:
		var nav_controller = session_controller.get_navigation_controller()
		if selected_cell or (nav_controller and nav_controller.is_navigation_active()):
			queue_redraw()
