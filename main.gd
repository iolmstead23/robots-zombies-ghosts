extends Node2D

## Hexagonal Grid Navigation System - Signal-Based Architecture
## This main script now delegates to SessionController and feature controllers
## Input handling is managed by IOController with signal-based communication

@onready var session_controller: SessionController = $SessionController
@onready var camera: Camera2D = $Camera2D
@onready var agent: CharacterBody2D = get_node_or_null("CharacterBody2D")

# Track selected cell for visualization
var selected_cell: HexCell = null

# Multi-agent support
var agent_manager: AgentManager = null
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

	# Configure camera and viewport for IOController
	session_controller.camera = camera
	session_controller.viewport = get_viewport()
	print("Camera and viewport configured for SessionController")

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
		print("AgentManager initialized - Active agent: %s" % (active_agent_data.agent_name if active_agent_data else "None"))

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
		var nav_follower = preload("res://Controllers/NavigationController/AgentNavigation/NavAgent2DFollower.gd").new()
		nav_follower.name = "NavAgent2DFollower"
		nav_follower.movement_speed = 100.0
		agent.add_child(nav_follower)
		nav_follower.activate()
		print("NavAgent2DFollower added and activated on agent")
	else:
		print("No single agent found - using multi-agent system")

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

func _setup_selection_overlay() -> void:
	"""Create and configure SelectionOverlay UI"""
	# Check if SelectionOverlay already exists in scene
	var selection_overlay = get_node_or_null("SelectionOverlay")

	# If not in scene, load and instance it
	if not selection_overlay:
		print("SelectionOverlay not found in scene - loading from scene file")
		var selection_overlay_scene = load("res://Controllers/UIController/UI/SelectionOverlay.tscn")
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
