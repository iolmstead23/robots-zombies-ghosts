extends Node2D

## Hexagonal Grid Navigation System - Signal-Based Architecture
## This main script now delegates to SessionController and feature controllers
## Input handling is managed by IOController with signal-based communication

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D
@onready var robot: CharacterBody2D = $"Robot Player"

# IOController - will be created programmatically if not in scene
var io_controller: IOController

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
	var nav_follower = preload("res://Controllers/NavigationController/RobotNavigation/NavAgent2DFollower.gd").new()
	nav_follower.name = "NavAgent2DFollower"
	nav_follower.movement_speed = 100.0
	robot.add_child(nav_follower)
	nav_follower.activate()
	print("NavAgent2DFollower added and activated on robot")

	# Configure IOController with dependencies
	_setup_io_controller()

	# Setup DebugUI overlay
	_setup_debug_ui()

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

func _setup_io_controller() -> void:
	"""Configure IOController with necessary dependencies and connect signals"""
	# Check if IOController exists in scene tree
	io_controller = get_node_or_null("IOController")

	# If not in scene, create it programmatically
	if not io_controller:
		print("IOController not found in scene - creating programmatically")
		io_controller = preload("res://Controllers/IOController/Core/io_controller.gd").new()
		io_controller.name = "IOController"
		add_child(io_controller)

		# Create and add input handler components
		var mouse_handler = preload("res://Controllers/IOController/Input/MouseInputHandler.gd").new()
		mouse_handler.name = "MouseInputHandler"
		io_controller.add_child(mouse_handler)

		var keyboard_handler = preload("res://Controllers/IOController/Input/KeyboardInputHandler.gd").new()
		keyboard_handler.name = "KeyboardInputHandler"
		io_controller.add_child(keyboard_handler)

		var camera_handler = preload("res://Controllers/IOController/Input/CameraInputHandler.gd").new()
		camera_handler.name = "CameraInputHandler"
		io_controller.add_child(camera_handler)

		# Set dependencies directly on mouse handler (timing fix)
		mouse_handler.set_camera(camera)
		mouse_handler.set_viewport(get_viewport())

		print("IOController and input handlers created")
	else:
		print("IOController found in scene tree")

	# Set dependencies for IOController
	io_controller.set_camera(camera)
	io_controller.set_viewport(get_viewport())

	var grid: HexGrid = session_controller.get_terrain()
	if grid:
		io_controller.set_hex_grid(grid)

	# Connect to IOController signals
	io_controller.hex_cell_left_clicked.connect(_on_io_cell_left_clicked)
	io_controller.hex_cell_right_clicked.connect(_on_io_cell_right_clicked)
	io_controller.hex_cell_hovered.connect(_on_io_cell_hovered)
	io_controller.hex_cell_hover_ended.connect(_on_io_cell_hover_ended)
	io_controller.camera_zoom_in_requested.connect(_on_io_zoom_in)
	io_controller.camera_zoom_out_requested.connect(_on_io_zoom_out)
	io_controller.debug_report_requested.connect(_on_io_debug_report)
	io_controller.clear_history_requested.connect(_on_io_clear_history)
	io_controller.export_data_requested.connect(_on_io_export_data)

	print("IOController configured and signals connected")

func _setup_debug_ui() -> void:
	"""Create and configure DebugUI overlay"""
	# Check if DebugUI already exists in scene
	var debug_ui = get_node_or_null("DebugUI")

	# If not in scene, load and instance it
	if not debug_ui:
		print("DebugUI not found in scene - loading from scene file")
		var debug_ui_scene = load("res://Controllers/DebugController/UI/DebugUI.tscn")
		if debug_ui_scene:
			debug_ui = debug_ui_scene.instantiate()
			add_child(debug_ui)
			print("DebugUI created and added to scene")
		else:
			push_error("Failed to load DebugUI.tscn")
			return
	else:
		print("DebugUI found in scene tree")

	print("DebugUI configured")

# ============================================================================
# IO CONTROLLER SIGNAL HANDLERS
# ============================================================================

func _on_io_cell_left_clicked(cell: HexCell) -> void:
	"""Handle left click on hex cell from IOController"""
	_handle_cell_click(cell)

func _on_io_cell_right_clicked(cell: HexCell) -> void:
	"""Handle right click on hex cell from IOController"""
	_toggle_cell(cell)

func _on_io_cell_hovered(cell: HexCell) -> void:
	"""Handle hover on hex cell from IOController"""
	var debug_controller = session_controller.get_debug_controller()
	if debug_controller:
		debug_controller.set_hovered_cell(cell)

func _on_io_cell_hover_ended() -> void:
	"""Handle hover end from IOController"""
	var debug_controller = session_controller.get_debug_controller()
	if debug_controller:
		debug_controller.set_hovered_cell(null)

func _on_io_zoom_in() -> void:
	"""Handle zoom in request from IOController"""
	camera.zoom *= 1.1

func _on_io_zoom_out() -> void:
	"""Handle zoom out request from IOController"""
	camera.zoom *= 0.9

func _on_io_debug_report() -> void:
	"""Handle debug report request from IOController"""
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		var tracker = nav_controller.get_path_tracker()
		if tracker:
			tracker.print_report()

func _on_io_clear_history() -> void:
	"""Handle clear history request from IOController"""
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		var tracker = nav_controller.get_path_tracker()
		if tracker:
			tracker.clear_history()
			print("Path history cleared")

func _on_io_export_data() -> void:
	"""Handle export data request from IOController"""
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
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
# Note: Path visualization is now handled by HexPathVisualizer in NavigationController
# This respects debug mode settings and avoids duplicate rendering
