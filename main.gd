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
	print("\n" + "=".repeat(60))
	print("MAIN.GD _ready() CALLED")
	print("=".repeat(60))

	# Check if SessionController exists
	if not session_controller:
		push_error("CRITICAL: SessionController not found!")
		return

	print("SessionController found: ", session_controller.name)

	# Configure navmesh integration before initialization
	var nav_region: NavigationRegion2D = $NavigationRegion2D

	if nav_region:
		print("Found NavigationRegion2D")
		session_controller.navigation_region = nav_region
		session_controller.integrate_with_navmesh = true  # Grid dimensions auto-calculated from navmesh
		session_controller.navmesh_sample_points = 5
		print("Navmesh integration enabled")
	else:
		push_warning("NavigationRegion2D not found - integration disabled")

	print("Waiting for session initialization...")

	# Wait for session initialization
	await session_controller.session_initialized

	print("Session initialized signal received!")

	# Get agent manager reference and connect signals
	agent_manager = session_controller.get_agent_manager()
	if agent_manager:
		agent_manager.agent_turn_started.connect(_on_agent_turn_started)
		agent_manager.agent_turn_ended.connect(_on_agent_turn_ended)
		agent_manager.movement_action_completed.connect(_on_movement_action_completed)
		agent_manager.all_agents_completed_round.connect(_on_all_agents_completed_round)

		# Get initial active agent
		active_agent_data = agent_manager.get_active_agent()
		print("AgentController initialized - Active agent: %s" % (active_agent_data.agent_name if active_agent_data else "None"))

	# Connect to navigation controller signals for logging
	var nav_controller = session_controller.get_navigation_controller()
	if nav_controller:
		nav_controller.navigation_started.connect(_on_navigation_started)
		nav_controller.navigation_completed.connect(_on_navigation_completed)
		nav_controller.navigation_failed.connect(_on_navigation_failed)
		nav_controller.waypoint_reached.connect(_on_waypoint_reached)
		nav_controller.path_found.connect(_on_path_found)
		nav_controller.path_not_found.connect(_on_path_not_found)

	# Add NavAgent2D follower to agent for automatic movement (only if single agent exists)
	if agent:
		var nav_follower = preload("res://Controllers/NavigationController/Packages/Pathfinding/hex_pathfinder.gd").new()
		nav_follower.name = "NavAgent2DFollower"
		nav_follower.movement_speed = 100.0
		agent.add_child(nav_follower)
		nav_follower.activate()
		print("NavAgent2DFollower added and activated on agent")
	else:
		print("No single agent found - using multi-agent system")

	# Configure IOController with dependencies
	_setup_io_controller()

	# Setup DebugUI overlay
	_setup_debug_ui()

	# Setup SelectionOverlay
	_setup_selection_overlay()

	print("\n" + "=".repeat(60))
	print("HEX NAVIGATION SYSTEM READY - Multi-Agent Turn-Based")
	print("=".repeat(60))
	if agent_manager:
		var all_agents = agent_manager.get_all_agents()
		var agent_count = all_agents.size()
		print("Agents: %d active" % agent_count)
		print("Active Agent: %s" % (active_agent_data.agent_name if active_agent_data else "None"))
		print("Distance Per Turn: %d meters" % (active_agent_data.max_distance_per_turn if active_agent_data else 10))
		print("")
	print("Click a hex cell to navigate the active agent")
	if agent_manager:
		var active = agent_manager.get_active_agent()
		if active:
			print("Each agent can travel %d meters per turn (1 hex cell = 1 meter)" % active.max_distance_per_turn)
	print("Turns automatically switch when distance is exhausted")
	print("")
	print("Controls:")
	print("  Left-click hex: Move active agent")
	print("  Right-click hex: Toggle cell enabled/disabled")
	print("  Space/Enter: End current turn early")
	print("  R: Generate pathfinding report")
	print("  C: Clear path history")
	print("  E: Export path data to JSON")
	print("  F3: Toggle debug mode")
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
		var mouse_handler = preload("res://Controllers/IOController/Input/mouse_input_handler.gd").new()
		mouse_handler.name = "MouseInputHandler"
		io_controller.add_child(mouse_handler)

		var keyboard_handler = preload("res://Controllers/IOController/Input/keyboard_input_handler.gd").new()
		keyboard_handler.name = "KeyboardInputHandler"
		io_controller.add_child(keyboard_handler)

		var camera_handler = preload("res://Controllers/IOController/Input/camera_input_handler.gd").new()
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
	io_controller.end_turn_requested.connect(_on_io_end_turn_requested)

	print("IOController configured and signals connected")

func _setup_debug_ui() -> void:
	"""Create and configure DebugUI overlay"""
	# Check if DebugUI already exists in scene
	var debug_ui = get_node_or_null("DebugUI")

	# If not in scene, load and instance it
	if not debug_ui:
		print("DebugUI not found in scene - loading from scene file")
		var debug_ui_scene = load("res://Controllers/DebugController/UI/debug_ui.tscn")
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

func _setup_selection_overlay() -> void:
	"""Create and configure SelectionOverlay UI"""
	# Check if SelectionOverlay already exists in scene
	var selection_overlay = get_node_or_null("SelectionOverlay")

	# If not in scene, load and instance it
	if not selection_overlay:
		print("SelectionOverlay not found in scene - loading from scene file")
		var selection_overlay_scene = load("res://Controllers/UIController/UI/selection_overlay.tscn")
		if selection_overlay_scene:
			selection_overlay = selection_overlay_scene.instantiate()
			add_child(selection_overlay)
			print("SelectionOverlay created and added to scene")
		else:
			push_error("Failed to load SelectionOverlay.tscn")
			return
	else:
		print("SelectionOverlay found in scene tree")

	print("SelectionOverlay configured")

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

func _on_io_end_turn_requested() -> void:
	"""Handle end turn request from IOController"""
	if agent_manager and active_agent_data:
		print("\n" + "⏭".repeat(30))
		print("⏭ MANUALLY ENDING TURN FOR %s" % active_agent_data.agent_name.to_upper())
		print("⏭".repeat(30))
		print("Movements Used: %d/%d" % [
			active_agent_data.movements_used_this_turn,
			active_agent_data.max_movements_per_turn
		])
		print("⏭".repeat(30) + "\n")
		agent_manager.end_current_agent_turn()
	else:
		print("Cannot end turn - no active agent")

func _handle_cell_click(cell: HexCell) -> void:
	"""Handle clicking on a hex cell - request navigation for active agent"""
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

	# Check if we have an active agent
	if not active_agent_data:
		print("\n❌ NAVIGATION BLOCKED: No active agent")
		print("=".repeat(60) + "\n")
		return

	# Check if active agent can move
	if not active_agent_data.can_move():
		print("\n❌ NAVIGATION BLOCKED: %s has no movements remaining (%d/%d used)" % [
			active_agent_data.agent_name,
			active_agent_data.movements_used_this_turn,
			active_agent_data.max_movements_per_turn
		])
		print("=".repeat(60) + "\n")
		return

	print("\n--- Active Agent Info ---")
	print("Agent: %s" % active_agent_data.agent_name)
	print("Current Position: %s" % active_agent_data.current_position)
	print("Movements Remaining: %d/%d" % [
		active_agent_data.get_movements_remaining(),
		active_agent_data.max_movements_per_turn
	])

	# Get the active agent's controller
	print("[main.gd] About to get agent_controller for agent_id=%s, agent_name=%s, agent_controller=%s" % [str(active_agent_data.agent_id), str(active_agent_data.agent_name), str(active_agent_data.agent_controller)])
	var controller_node = active_agent_data.agent_controller
	var script_type = controller_node.get_script() if controller_node else null
	var script_class_name = script_type.get_class() if (script_type and script_type.has_method("get_class")) else ""
	print("[DEBUG] Controller node type: %s, get_class(): %s, script: %s, script_class_name: %s" % [
		controller_node,
		controller_node.get_class() if controller_node else "null",
		str(script_type),
		str(script_class_name)
	])

	# Use controller_node directly instead of casting (cast can fail with dynamically loaded scenes)
	var agent_controller = controller_node
	if not agent_controller or not agent_controller.turn_based_controller:
		print("\n❌ ERROR: Active agent has no turn_based_controller")
		print("=".repeat(60) + "\n")
		return

	# Navigate the active agent directly - pathfinding will calculate path
	if agent_controller.turn_based_controller:
		# Pass the agent's actual remaining distance to the movement controller
		var remaining_distance = int(active_agent_data.get_distance_remaining())
		print("[main.gd] Calling request_movement_to() with position: %s, remaining distance: %d m" % [str(cell.world_position), remaining_distance])
		agent_controller.turn_based_controller.request_movement_to(cell.world_position, remaining_distance)
		# Small delay for pathfinding to complete
		await get_tree().create_timer(0.1).timeout

		var is_awaiting = agent_controller.turn_based_controller.is_awaiting_confirmation()
		print("[main.gd] After request_movement_to, is_awaiting_confirmation: %s" % str(is_awaiting))

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
						print("\n✅ Movement confirmed: %d meters (%d hex cells)" % [full_path_length, full_path_length])
						print("   Distance remaining: %d meters" % int(active_agent_data.get_distance_remaining()))
					else:
						agent_controller.turn_based_controller.cancel_movement()
						print("\n❌ Failed to record movement")
				else:
					# Path exceeds budget - need to truncate to available distance
					var distance_to_move = distance_available

					if distance_to_move <= 0:
						agent_controller.turn_based_controller.cancel_movement()
						print("\n❌ No distance remaining this turn")
						print("=".repeat(60) + "\n")
						return

					print("\n⚠️ Path truncated: %d meters requested, %d meters available" % [full_path_length, distance_to_move])

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
						print("✅ Movement confirmed: %d meters (truncated from %d meters)" % [distance_to_move, full_path_length])
						print("   Distance remaining: %d meters" % int(active_agent_data.get_distance_remaining()))
					else:
						agent_controller.turn_based_controller.cancel_movement()
						print("\n❌ Failed to record movement")
			else:
				print("\n❌ Pathfinding failed - no valid path")
	else:
		print("\n❌ ERROR: Agent has no turn_based_controller")

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
	"""Called when agent navigation starts"""
	print("\n" + "█".repeat(60))
	print("🤖 AGENT NAVIGATION STARTED")
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
	"""Called when navigation reaches destination"""
	print("\n" + "█".repeat(60))

	# Get current position from either agent or active agent
	var current_position: Vector2
	var entity_name: String

	if agent:
		current_position = agent.global_position
		entity_name = "AGENT"
	elif active_agent_data and active_agent_data.agent_controller:
		current_position = active_agent_data.agent_controller.global_position
		entity_name = active_agent_data.agent_name.to_upper()
	else:
		print("❌ ERROR: No valid entity to track")
		print("█".repeat(60) + "\n")
		return

	print("✅ %s NAVIGATION COMPLETED" % entity_name)
	print("█".repeat(60))
	print("%s Position: %s" % [entity_name.capitalize(), current_position])

	if selected_cell:
		var distance_to_target = current_position.distance_to(selected_cell.world_position)
		print("Distance to Target Center: %.2f pixels" % distance_to_target)
		if distance_to_target < 20:
			print("🎯 %s reached target accurately!" % entity_name.capitalize())
		else:
			print("⚠️ %s stopped %.2f pixels from target" % [entity_name.capitalize(), distance_to_target])

	print("█".repeat(60) + "\n")

func _on_navigation_failed(reason: String) -> void:
	"""Called when navigation fails"""
	print("\n" + "█".repeat(60))

	# Get current position from either agent or active agent
	var current_position: Vector2
	var entity_name: String

	if agent:
		current_position = agent.global_position
		entity_name = "AGENT"
	elif active_agent_data and active_agent_data.agent_controller:
		current_position = active_agent_data.agent_controller.global_position
		entity_name = active_agent_data.agent_name.to_upper()
	else:
		print("❌ ERROR: No valid entity to track")
		print("█".repeat(60) + "\n")
		return

	print("❌ %s NAVIGATION FAILED" % entity_name)
	print("█".repeat(60))
	print("Reason: %s" % reason)
	print("%s Position: %s" % [entity_name.capitalize(), current_position])
	print("█".repeat(60) + "\n")
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
	print("\n" + "🎯".repeat(30))
	print("🎯 %s TURN STARTED" % agent_data.agent_name.to_upper())
	print("🎯".repeat(30))
	print("Position: %s" % agent_data.current_position)
	print("Movements Available: %d" % agent_data.max_movements_per_turn)
	print("Turn Number: %d" % agent_data.turn_number)
	print("🎯".repeat(30) + "\n")

func _on_agent_turn_ended(agent_data: AgentData) -> void:
	"""Called when an agent's turn ends"""
	print("\n" + "⏸".repeat(30))
	print("⏸ %s TURN ENDED" % agent_data.agent_name.to_upper())
	print("⏸".repeat(30))
	print("Movements Used: %d/%d" % [
		agent_data.movements_used_this_turn,
		agent_data.max_movements_per_turn
	])
	print("Total Lifetime Movements: %d" % agent_data.total_movements_lifetime)
	print("⏸".repeat(30) + "\n")

func _on_movement_action_completed(agent_data: AgentData, movements_remaining: int) -> void:
	"""Called when an agent completes a movement action"""
	print("📍 %s movement action completed (%d movements remaining)" % [
		agent_data.agent_name,
		movements_remaining
	])

func _on_all_agents_completed_round() -> void:
	"""Called when all agents have completed a round"""
	print("\n" + "🔄".repeat(30))
	print("🔄 ALL AGENTS COMPLETED ROUND")
	print("🔄".repeat(30) + "\n")

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
