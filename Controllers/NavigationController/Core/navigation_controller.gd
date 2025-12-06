class_name NavigationController
extends Node

## Manages pathfinding and agent navigation independently
## Communicates exclusively through signals - no direct dependencies on other features
##
## NAVIGATION MODE: Turn-based movement is ACTIVE
## Real-time navigation is DISABLED but code is preserved for future use
##
## Refactored to use Core components for better organization and reusability.

# ============================================================================
# SIGNALS - State Changes (Emitted)
# ============================================================================

## Emitted when a path is successfully calculated
signal path_found(start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float)

## Emitted when pathfinding fails
signal path_not_found(start_pos: Vector2, goal_pos: Vector2, reason: String)

## Emitted when agent navigation fails
signal navigation_failed(reason: String)

## Emitted when navigation state changes
signal navigation_state_changed(active: bool, path_length: int, remaining_distance: int)

# ============================================================================
# SIGNALS - Commands (Received from SessionController/UI)
# ============================================================================

## Request to calculate a path
signal calculate_path_requested(request_id: String, start_pos: Vector2, goal_pos: Vector2)

## Request to navigate agent to position
signal navigate_to_position_requested(target_pos: Vector2)

## Request to navigate agent to cell
signal navigate_to_cell_requested(target_cell: HexCell)

## Request to cancel current navigation
signal cancel_navigation_requested()

# ============================================================================
# SIGNALS - Queries to HexGridController (Emitted to SessionController)
# ============================================================================

## Request cell at position from grid controller
signal query_cell_at_position(request_id: String, world_pos: Vector2)

# ============================================================================
# SIGNALS - Responses from HexGridController (Received from SessionController)
# ============================================================================

## Receive cell response from grid controller
signal on_cell_at_position_response(request_id: String, cell: HexCell)

# ============================================================================
# STATE
# ============================================================================

# Pathfinding Components (Shared by both navigation modes)
var hex_pathfinder: HexPathfinder = null
var hex_path_tracker: HexPathTracker = null
var hex_path_visualizer: HexPathVisualizer = null
var hex_cell_selector: HexCellSelector = null

# REAL-TIME NAVIGATION (DISABLED - Preserved for future use)
# var hex_agent_navigator: HexAgentNavigator = null

# TURN-BASED NAVIGATION (ACTIVE)
var turn_based_controller: TurnBasedMovementController = null

# Agent reference (set by SessionController)
var agent: CharacterBody2D = null

# Current navigation state
var navigation_active: bool = false
var current_path: Array[HexCell] = []
var current_target: HexCell = null

# Core components
var _request_manager: RequestManager = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
	# Initialize Core components
	_request_manager = RequestManager.new()
	add_child(_request_manager)

	# Connect to command signals
	calculate_path_requested.connect(_on_calculate_path_requested)
	navigate_to_position_requested.connect(_on_navigate_to_position_requested)
	navigate_to_cell_requested.connect(_on_navigate_to_cell_requested)
	cancel_navigation_requested.connect(_on_cancel_navigation_requested)

	# Connect to response signals from grid controller
	on_cell_at_position_response.connect(_on_cell_at_position_response)

# ============================================================================
# INITIALIZATION (called by SessionController)
# ============================================================================

func initialize(grid: HexGrid, agent_node: CharacterBody2D):
	# Agent is optional - only needed for real-time navigation (which is disabled)
	# Turn-based navigation uses agents' individual pathfinders
	if agent_node != null:
		if not _validate_agent(agent_node, "NavigationController.initialize"):
			push_warning("[NavigationController] Invalid agent_node passed to initialize(). Agent not set, but continuing with initialization.")
		else:
			agent = agent_node

	# Create pathfinder (shared by both turn-based and real-time navigation)
	hex_pathfinder = HexPathfinder.new()
	hex_pathfinder.name = "HexPathfinder"
	hex_pathfinder.hex_grid = grid
	add_child(hex_pathfinder)

	# ========== REAL-TIME NAVIGATION (DISABLED) ==========
	# Real-time navigation is disabled but code preserved for future use
	# To enable: Uncomment the section below
	#
	# hex_agent_navigator = HexAgentNavigator.new()
	# hex_agent_navigator.name = "HexAgentNavigator"
	# hex_agent_navigator.hex_grid = grid
	# hex_agent_navigator.hex_pathfinder = hex_pathfinder
	# hex_agent_navigator.agent = agent
	# hex_agent_navigator.waypoint_reach_distance = 15
	# hex_agent_navigator.navigation_started.connect(_on_agent_navigation_started)
	# hex_agent_navigator.navigation_completed.connect(_on_agent_navigation_completed)
	# hex_agent_navigator.navigation_failed.connect(_on_agent_navigation_failed)
	# hex_agent_navigator.waypoint_reached.connect(_on_agent_waypoint_reached)
	# add_child(hex_agent_navigator)
	# ====================================================

	# ========== TURN-BASED NAVIGATION (ACTIVE) ==========
	# Turn-based movement is the current active navigation system
	# Note: TurnBasedMovementController is typically managed by individual agents
	# This controller primarily provides pathfinding support for turn-based movement
	# ====================================================

	# Create path tracker
	hex_path_tracker = HexPathTracker.new()
	hex_path_tracker.name = "HexPathTracker"
	add_child(hex_path_tracker)

	# Create path visualizer
	hex_path_visualizer = HexPathVisualizer.new()
	hex_path_visualizer.name = "HexPathVisualizer"
	hex_path_visualizer.hex_grid = grid
	add_child(hex_path_visualizer)

	# Create cell selector
	hex_cell_selector = HexCellSelector.new()
	hex_cell_selector.name = "HexCellSelector"
	hex_cell_selector.hex_grid = grid
	add_child(hex_cell_selector)

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

func _on_calculate_path_requested(request_id: String, start_pos: Vector2, goal_pos: Vector2):
	# Store the request using Core RequestManager
	var req_id := _request_manager.create_path_request(start_pos, goal_pos)

	# Override with provided request_id if different
	if req_id != request_id:
		# For compatibility, use the provided request_id
		_request_manager.cancel_path_request(req_id)
		req_id = request_id
		_request_manager.pending_path_requests[request_id] = {
			"start_pos": start_pos,
			"goal_pos": goal_pos,
			"timestamp": Time.get_ticks_msec()
		}

	# Query for start cell
	var start_request_id = request_id + "_start"
	query_cell_at_position.emit(start_request_id, start_pos)

	# Query for goal cell
	var goal_request_id = request_id + "_goal"
	query_cell_at_position.emit(goal_request_id, goal_pos)

func _on_navigate_to_position_requested(target_pos: Vector2):
	# Use Core RequestManager to create navigation request
	var request_id := _request_manager.create_nav_request(target_pos)

	# Query for target cell
	query_cell_at_position.emit(request_id, target_pos)

func _on_navigate_to_cell_requested(target_cell: HexCell):
	# REAL-TIME NAVIGATION DISABLED
	# This function is preserved but disabled for turn-based gameplay
	# Turn-based movement is handled by TurnBasedMovementController in each agent
	if not target_cell or not target_cell.enabled:
		navigation_failed.emit("Target cell is invalid or disabled")
		return

	# Select the cell
	if hex_cell_selector:
		hex_cell_selector.select_cell(target_cell)

	current_target = target_cell

	# DISABLED: Real-time navigation
	# hex_agent_navigator.navigate_to_cell(target_cell)

	# NOTE: For turn-based movement, agents should use their own TurnBasedMovementController
	push_warning("NavigationController: Real-time navigation is disabled. Use TurnBasedMovementController for turn-based movement.")

func _on_cancel_navigation_requested():
	# DISABLED: Real-time navigation cancellation
	# if hex_agent_navigator:
	# 	hex_agent_navigator.cancel_navigation()
	_clear_navigation_state()

# ============================================================================
# RESPONSE HANDLERS (from HexGridController)
# ============================================================================

func _on_cell_at_position_response(request_id: String, cell: HexCell):
	# Check if this is a pathfinding request using Core RequestManager
	var path_request_id := _request_manager.find_path_request_for_cell(request_id)
	if path_request_id != "":
		_handle_path_request_response(path_request_id, request_id, cell)
		return

	# Check if this is a navigation request
	if _request_manager.is_nav_request(request_id):
		_handle_nav_request_response(request_id, cell)
		return

func _handle_path_request_response(path_request_id: String, cell_request_id: String, cell: HexCell):
	# Update request using Core RequestManager
	_request_manager.update_path_request(path_request_id, cell_request_id, cell)

	# Check if request is complete
	if not _request_manager.is_path_request_complete(path_request_id):
		return

	# Get and complete the request
	var request = _request_manager.complete_path_request(path_request_id)
	var start_cell = request.get("start_cell")
	var goal_cell = request.get("goal_cell")

	# Check if pathfinder is initialized
	if not hex_pathfinder:
		push_error("NavigationController: Pathfinder not initialized")
		path_not_found.emit(request.start_pos, request.goal_pos, "Navigation controller not initialized")
		return

	# Validate cells using Core PathValidator
	if not PathValidator.are_cells_valid(start_cell, goal_cell):
		path_not_found.emit(request.start_pos, request.goal_pos, "Invalid start or goal cell")
		return

	# Calculate path
	var start_time = Time.get_ticks_msec()
	var path = hex_pathfinder.find_path(start_cell, goal_cell)
	var duration = Time.get_ticks_msec() - start_time

	if path.size() > 0:
		# Visualize the path
		if hex_path_visualizer:
			hex_path_visualizer.set_path(path)

		# Log the path
		if hex_path_tracker:
			hex_path_tracker.log_path(start_cell, goal_cell, path, float(duration))

		path_found.emit(start_cell, goal_cell, path, float(duration))
	else:
		path_not_found.emit(request.start_pos, request.goal_pos, "No path found")

func _handle_nav_request_response(request_id: String, cell: HexCell):
	# Update and complete request using Core RequestManager
	_request_manager.update_nav_request(request_id, cell)
	var _request = _request_manager.complete_nav_request(request_id)

	# Validate cell using Core PathValidator
	if not PathValidator.is_cell_valid(cell):
		navigation_failed.emit("Target cell is invalid or disabled")
		return

	# Navigate to the cell
	navigate_to_cell_requested.emit(cell)

# ============================================================================
# AGENT NAVIGATOR CALLBACKS (DISABLED - Real-time navigation)
# ============================================================================
# These callbacks are preserved but disabled for turn-based gameplay
# To enable: Uncomment and reconnect to hex_agent_navigator signals

# func _on_agent_navigation_started(target_cell: HexCell):
# 	navigation_active = true
# 	current_path = hex_agent_navigator.get_current_path()
# 	current_target = target_cell
#
# 	# Visualize the navigation path
# 	if hex_path_visualizer and current_path.size() > 0:
# 		hex_path_visualizer.set_path(current_path)
#
# 	navigation_started.emit(target_cell)
# 	_emit_navigation_state()
#
# func _on_agent_navigation_completed():
# 	navigation_active = false
# 	navigation_completed.emit()
# 	_clear_navigation_state()
#
# func _on_agent_navigation_failed(reason: String):
# 	navigation_active = false
# 	navigation_failed.emit(reason)
# 	_clear_navigation_state()
#
# func _on_agent_waypoint_reached(cell: HexCell, index: int):
# 	var remaining = hex_agent_navigator.get_remaining_distance()
# 	waypoint_reached.emit(cell, index, remaining)
# 	_emit_navigation_state()

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _emit_navigation_state():
	var path_length = current_path.size()
	# DISABLED: Real-time navigation distance tracking
	var remaining = 0 # hex_agent_navigator.get_remaining_distance() if hex_agent_navigator else 0
	navigation_state_changed.emit(navigation_active, path_length, remaining)

func _clear_navigation_state():
	navigation_active = false
	current_path = []
	current_target = null

	# Clear path visualization
	if hex_path_visualizer:
		hex_path_visualizer.clear_path()

	_emit_navigation_state()

# ============================================================================
# PUBLIC API - Accessors
# ============================================================================

func is_navigation_active() -> bool:
	return navigation_active

func get_current_path() -> Array[HexCell]:
	return current_path

func get_current_target() -> HexCell:
	return current_target

func get_path_tracker() -> HexPathTracker:
	return hex_path_tracker

func get_path_visualizer() -> HexPathVisualizer:
	return hex_path_visualizer

func get_pathfinder() -> HexPathfinder:
	return hex_pathfinder

func set_active_agent(agent_node: CharacterBody2D) -> void:
	"""Set the active agent for navigation"""
	if not _validate_agent(agent_node, "NavigationController.set_active_agent"):
		push_error("[NavigationController] Invalid agent_node passed to set_active_agent(). See log above for details. Agent not set.")
		return
	agent = agent_node

	# DISABLED: Real-time navigation agent update
	# Update agent reference in navigator
	# if hex_agent_navigator:
	# 	hex_agent_navigator.agent = agent_node

# =============================================================================
# INTERNAL - AGENT VALIDATION
# =============================================================================
func _validate_agent(agent_ref: Variant, context: String) -> bool:
	# Accepts agent node, context string for diagnostics.
	var is_valid := true
	var messages := []
	var conditions := {
		"null_or_freed": (agent_ref == null or (typeof(agent_ref) == TYPE_OBJECT and agent_ref.is_queued_for_deletion())),
		"not_character_body": (not (agent_ref is CharacterBody2D)),
	}
	if conditions["null_or_freed"]:
		is_valid = false
		messages.append("Agent is null or freed.")
	if conditions["not_character_body"]:
		is_valid = false
		messages.append("Agent is not a CharacterBody2D (got type: %s)." % [typeof(agent_ref)])

	if not is_valid:
		push_error("[Agent Validation Error] in %s: Failing agent reference. Details: type=%s value=%s; Checks=[%s]\nCallstack:\n%s"
			% [
				context,
				typeof(agent_ref),
				str(agent_ref),
				", ".join(messages),
				get_stack()
			]
		)
	return is_valid
