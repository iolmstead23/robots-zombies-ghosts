extends Node2D

## Hexagonal Grid Navigation System - Signal-Based Architecture
## This main script now delegates to SessionController and feature controllers
## Input handling is managed by IOController with signal-based communication

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D
@onready var agent: CharacterBody2D = get_node_or_null("CharacterBody2D")

# IOController - will be created programmatically if not in scene
var io_controller: IOController

# Track selected cell for visualization
var selected_cell: HexCell = null

# Multi-agent support
var agent_manager: AgentController = null
var active_agent_data: AgentData = null

func _ready() -> void:
	# Check if SessionController exists
	if not session_controller:
		push_error("CRITICAL: SessionController not found!")
		return

	# Configure navmesh integration before initialization
	var nav_region: NavigationRegion2D = $NavigationRegion2D

	if nav_region:
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true  # Grid dimensions auto-calculated from navmesh
		session_controller.navmesh_sample_points = 5
	else:
		push_warning("NavigationRegion2D not found - integration disabled")

	# CRITICAL FIX: Create IOController BEFORE session initialization
	await _create_io_controller()

	# Wait for session initialization
	await session_controller.session_initialized

	# Get agent manager reference and connect signals
	agent_manager = session_controller.get_agent_manager()
	if agent_manager:
		agent_manager.agent_turn_started.connect(_on_agent_turn_started)
		agent_manager.agent_turn_ended.connect(_on_agent_turn_ended)
		agent_manager.movement_action_completed.connect(_on_movement_action_completed)
		agent_manager.all_agents_completed_round.connect(_on_all_agents_completed_round)

		# Get initial active agent
		active_agent_data = agent_manager.get_active_agent()

	# Connect to navigation controller signals for logging
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		# Real-time navigation signals (disabled for turn-based gameplay)
		# nav_controller.navigation_started.connect(_on_navigation_started)
		# nav_controller.navigation_completed.connect(_on_navigation_completed)
		nav_controller.navigation_failed.connect(_on_navigation_failed)
		# nav_controller.waypoint_reached.connect(_on_waypoint_reached)
		nav_controller.path_found.connect(_on_path_found)
		nav_controller.path_not_found.connect(_on_path_not_found)

	# Add NavAgent2D follower to agent for automatic movement (only if single agent exists)
	if agent:
		var nav_follower = preload("res://Controllers/NavigationController/Packages/Pathfinding/hex_pathfinder.gd").new()
		nav_follower.name = "NavAgent2DFollower"
		nav_follower.movement_speed = 100.0
		agent.add_child(nav_follower)
		nav_follower.activate()

	# Connect IOController to session components (after session initialized)
	_connect_io_controller()

	# Ensure camera free roam is enabled if debug mode active
	await _ensure_camera_free_roam_if_debug()

	# Setup DebugOverlay
	_setup_debug_overlay()

	# Setup SelectionOverlay
	_setup_selection_overlay()

func _create_io_controller() -> void:
	"""Create IOController and set dependencies BEFORE session initialization"""
	# Check if IOController exists in scene tree
	io_controller = get_node_or_null("IOController")

	# If not in scene, create it programmatically
	if not io_controller:
		io_controller = preload("res://Controllers/IOController/Core/io_controller.gd").new()
		io_controller.name = "IOController"

		# Create input handler components
		var mouse_handler = preload("res://Controllers/IOController/Input/mouse_input_handler.gd").new()
		mouse_handler.name = "MouseInputHandler"

		var keyboard_handler = preload("res://Controllers/IOController/Input/keyboard_input_handler.gd").new()
		keyboard_handler.name = "KeyboardInputHandler"

		var camera_handler = preload("res://Controllers/IOController/Input/camera_input_handler.gd").new()
		camera_handler.name = "CameraInputHandler"

		# CRITICAL FIX: Set dependencies BEFORE adding as children
		mouse_handler.set_camera(camera)
		mouse_handler.set_viewport(get_viewport())

		# Now add IOController and handlers to scene tree
		add_child(io_controller)
		io_controller.add_child(mouse_handler)
		io_controller.add_child(keyboard_handler)
		io_controller.add_child(camera_handler)

	# Set dependencies for IOController itself
	io_controller.set_camera(camera)
	io_controller.set_viewport(get_viewport())

	# Wait one frame for handlers to be fully ready
	await get_tree().process_frame

func _connect_io_controller() -> void:
	"""Connect IOController to session components AFTER session initialization"""

	if not io_controller:
		push_error("IOController not found in _connect_io_controller!")
		return

	# NOW set hex grid reference (available after session initialized)
	var grid: HexGrid = session_controller.get_terrain()
	if grid:
		io_controller.set_hex_grid(grid)
	else:
		push_warning("Hex grid not available")

	# Connect to IOController signals
	# NOTE: Hex cell signals now routed through SessionController for three-way communication
	# SessionController handles cell click/hover routing to NavigationController and DebugController
	io_controller.end_turn_requested.connect(_on_io_end_turn_requested)

	# Notify SessionController about IOController and connect hex cell signals
	if session_controller and session_controller.has_method("connect_io_controller"):
		session_controller.connect_io_controller(io_controller)

	# Verify IOController dependencies
	if not io_controller.verify_dependencies():
		push_error("⚠️ IOController dependency verification FAILED")

func _ensure_camera_free_roam_if_debug() -> void:
	"""Force camera into free roam mode if debug is enabled"""
	var session_debug_enabled = SessionData.is_debug_enabled()
	var camera_controller = session_controller.camera_controller

	if session_debug_enabled and camera_controller:
		# Wait one more frame to ensure everything is ready
		await get_tree().process_frame
		camera_controller.enable_free_roam()
	elif session_debug_enabled:
		push_warning("[main.gd] Debug mode enabled but camera_controller not found")

func _setup_debug_overlay() -> void:
	"""Create and configure DebugOverlay"""
	# Check if DebugOverlay already exists in scene (check both new and old names)
	var debug_overlay = get_node_or_null("DebugOverlay")
	if not debug_overlay:
		debug_overlay = get_node_or_null("DebugUI")  # Backward compatibility

	# If not in scene, load and instance it
	if not debug_overlay:
		var debug_overlay_scene = load("res://Controllers/DebugController/UI/debug_ui.tscn")
		if debug_overlay_scene:
			debug_overlay = debug_overlay_scene.instantiate()
			add_child(debug_overlay)
		else:
			push_error("Failed to load debug_ui.tscn")
			return

func _setup_selection_overlay() -> void:
	"""Create and configure SelectionOverlay UI"""
	# Check if SelectionOverlay already exists in scene
	var selection_overlay = get_node_or_null("SelectionOverlay")

	# If not in scene, load and instance it
	if not selection_overlay:
		var selection_overlay_scene = load("res://Controllers/UIController/Implementations/SelectionOverlay/SelectionOverlay.tscn")
		if selection_overlay_scene:
			selection_overlay = selection_overlay_scene.instantiate()
			add_child(selection_overlay)
		else:
			push_error("Failed to load SelectionOverlay.tscn")
			return

# ============================================================================
# IO CONTROLLER SIGNAL HANDLERS
# ============================================================================

func _on_io_cell_left_clicked(cell: HexCell) -> void:
	"""Handle left click on hex cell from IOController"""
	_handle_cell_click(cell)

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

func _on_io_end_turn_requested() -> void:
	"""Handle end turn request from IOController"""
	if agent_manager and active_agent_data:
		agent_manager.end_current_agent_turn()

func _handle_cell_click(cell: HexCell) -> void:
	"""Handle clicking on a hex cell - request navigation for active agent"""
	selected_cell = cell

	if not cell.enabled:
		return

	# Check if we have an active agent
	if not active_agent_data:
		return

	# Check if active agent can move
	if not active_agent_data.can_move():
		return

	# Use controller_node directly instead of casting (cast can fail with dynamically loaded scenes)
	var agent_controller = active_agent_data.agent_controller
	if not agent_controller or not agent_controller.turn_based_controller:
		return

	# Navigate the active agent directly - pathfinding will calculate path
	if agent_controller.turn_based_controller:
		# Pass the agent's actual remaining distance to the movement controller
		var remaining_distance = int(active_agent_data.get_distance_remaining())
		agent_controller.turn_based_controller.request_movement_to(cell.world_position, remaining_distance)
		# Small delay for pathfinding to complete
		await get_tree().create_timer(0.1).timeout

		var is_awaiting = agent_controller.turn_based_controller.is_awaiting_confirmation()

		if is_awaiting:
			# Use hex cell count as distance (each hex cell = 1 meter)
			var pathfinder = agent_controller.turn_based_controller.pathfinder
			if pathfinder and pathfinder.current_hex_path and not pathfinder.current_hex_path.is_empty():
				# Distance is measured in hex cells (each cell = 1 meter)
				var full_path_length = pathfinder.current_hex_path.size() - 1  # Subtract 1 because first cell is current position
				var distance_available = int(active_agent_data.get_distance_remaining())

				# Check if path is within available distance
				if full_path_length <= distance_available:
					# Full path fits within budget - use it all
					if agent_manager.record_movement_action(full_path_length):
						# Connect to movement_completed signal to update position after movement finishes
						var tb_controller = agent_controller.turn_based_controller
						tb_controller.movement_completed.connect(
							func(_dist):
								agent_manager.update_agent_position_after_movement(active_agent_data),
							CONNECT_ONE_SHOT
						)

						agent_controller.turn_based_controller.confirm_movement()
					else:
						agent_controller.turn_based_controller.cancel_movement()
				else:
					# Path exceeds budget - need to truncate to available distance
					var distance_to_move = distance_available

					if distance_to_move <= 0:
						agent_controller.turn_based_controller.cancel_movement()
						return

					# Record movement with available distance
					if agent_manager.record_movement_action(distance_to_move):
						# Connect to movement_completed signal to update position after movement finishes
						var tb_controller = agent_controller.turn_based_controller
						tb_controller.movement_completed.connect(
							func(_dist):
								agent_manager.update_agent_position_after_movement(active_agent_data),
							CONNECT_ONE_SHOT
						)

						agent_controller.turn_based_controller.confirm_movement()
					else:
						agent_controller.turn_based_controller.cancel_movement()

# ============================================================================
# NAVIGATION CONTROLLER CALLBACKS
# ============================================================================

func _on_path_found(_start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float) -> void:
	pass

func _on_path_not_found(_start_pos: Vector2, _goal_pos: Vector2, reason: String) -> void:
	pass

func _on_navigation_started(target_cell: HexCell) -> void:
	"""Called when agent navigation starts"""
	pass

func _on_navigation_completed() -> void:
	"""Called when navigation reaches destination"""
	pass

func _on_navigation_failed(reason: String) -> void:
	"""Called when navigation fails"""
	push_warning("Navigation failed: %s" % reason)

func _on_waypoint_reached(_cell: HexCell, _index: int, _remaining: int) -> void:
	"""Called when agent reaches each waypoint"""
	# Waypoint reached - no logging needed during normal operation
	pass

# ============================================================================
# AGENT MANAGER CALLBACKS
# ============================================================================

func _on_agent_turn_started(agent_data: AgentData) -> void:
	"""Called when a new agent's turn starts"""
	active_agent_data = agent_data

func _on_agent_turn_ended(agent_data: AgentData) -> void:
	"""Called when an agent's turn ends"""
	pass

func _on_movement_action_completed(agent_data: AgentData, movements_remaining: int) -> void:
	"""Called when an agent completes a movement action"""
	pass

func _on_all_agents_completed_round() -> void:
	"""Called when all agents have completed a round"""
	pass
