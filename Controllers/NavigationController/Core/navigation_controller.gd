class_name NavigationController
extends Node

## Manages pathfinding and agent navigation independently
## Communicates exclusively through signals - no direct dependencies on other features

# ============================================================================
# SIGNALS - State Changes (Emitted)
# ============================================================================

## Emitted when a path is successfully calculated
signal path_found(start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float)

## Emitted when pathfinding fails
signal path_not_found(start_pos: Vector2, goal_pos: Vector2, reason: String)

## Emitted when agent navigation starts
signal navigation_started(target: HexCell)

## Emitted when agent navigation completes successfully
signal navigation_completed()

## Emitted when agent navigation fails
signal navigation_failed(reason: String)

## Emitted when agent reaches a waypoint
signal waypoint_reached(cell: HexCell, index: int, remaining: int)

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

# Components
var hex_pathfinder: HexPathfinder = null
var hex_agent_navigator: HexAgentNavigator = null
var hex_path_tracker: HexPathTracker = null
var hex_path_visualizer: HexPathVisualizer = null
var hex_cell_selector: HexCellSelector = null

# Agent reference (set by SessionController)
var agent: CharacterBody2D = null

# Current navigation state
var navigation_active: bool = false
var current_path: Array[HexCell] = []
var current_target: HexCell = null

# Pending requests (for async cell queries)
var pending_path_requests: Dictionary = {}  # request_id -> {start_pos, goal_pos}
var pending_nav_requests: Dictionary = {}  # request_id -> target_pos

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready():
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
	agent = agent_node

	# Create pathfinder
	hex_pathfinder = HexPathfinder.new()
	hex_pathfinder.name = "HexPathfinder"
	hex_pathfinder.hex_grid = grid
	add_child(hex_pathfinder)

	# Create agent navigator
	hex_agent_navigator = HexAgentNavigator.new()
	hex_agent_navigator.name = "HexAgentNavigator"
	hex_agent_navigator.hex_grid = grid
	hex_agent_navigator.hex_pathfinder = hex_pathfinder
	hex_agent_navigator.agent = agent
	hex_agent_navigator.waypoint_reach_distance = 15.0
	hex_agent_navigator.navigation_started.connect(_on_agent_navigation_started)
	hex_agent_navigator.navigation_completed.connect(_on_agent_navigation_completed)
	hex_agent_navigator.navigation_failed.connect(_on_agent_navigation_failed)
	hex_agent_navigator.waypoint_reached.connect(_on_agent_waypoint_reached)
	add_child(hex_agent_navigator)

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
	# Store the request
	pending_path_requests[request_id] = {
		"start_pos": start_pos,
		"goal_pos": goal_pos
	}

	# Query for start cell
	var start_request_id = request_id + "_start"
	query_cell_at_position.emit(start_request_id, start_pos)

	# Query for goal cell
	var goal_request_id = request_id + "_goal"
	query_cell_at_position.emit(goal_request_id, goal_pos)

func _on_navigate_to_position_requested(target_pos: Vector2):
	var request_id = "nav_" + str(Time.get_ticks_msec())
	pending_nav_requests[request_id] = target_pos

	# Query for target cell
	query_cell_at_position.emit(request_id, target_pos)

func _on_navigate_to_cell_requested(target_cell: HexCell):
	if not hex_agent_navigator:
		push_error("NavigationController: Cannot navigate - not initialized yet")
		navigation_failed.emit("Navigation controller not initialized")
		return

	if not target_cell or not target_cell.enabled:
		navigation_failed.emit("Target cell is invalid or disabled")
		return

	# Select the cell
	if hex_cell_selector:
		hex_cell_selector.select_cell(target_cell)

	current_target = target_cell
	hex_agent_navigator.navigate_to_cell(target_cell)

func _on_cancel_navigation_requested():
	if hex_agent_navigator:
		hex_agent_navigator.cancel_navigation()
	_clear_navigation_state()

# ============================================================================
# RESPONSE HANDLERS (from HexGridController)
# ============================================================================

func _on_cell_at_position_response(request_id: String, cell: HexCell):
	# Check if this is a pathfinding request
	for path_request_id in pending_path_requests.keys():
		if request_id.begins_with(path_request_id):
			_handle_path_request_response(path_request_id, request_id, cell)
			return

	# Check if this is a navigation request
	if request_id in pending_nav_requests:
		_handle_nav_request_response(request_id, cell)
		return

func _handle_path_request_response(path_request_id: String, cell_request_id: String, cell: HexCell):
	var request = pending_path_requests[path_request_id]

	# Store the cell response
	if cell_request_id.ends_with("_start"):
		request["start_cell"] = cell
	elif cell_request_id.ends_with("_goal"):
		request["goal_cell"] = cell

	# Check if we have both cells
	if request.has("start_cell") and request.has("goal_cell"):
		var start_cell = request.start_cell
		var goal_cell = request.goal_cell

		# Clean up
		pending_path_requests.erase(path_request_id)

		# Check if pathfinder is initialized
		if not hex_pathfinder:
			push_error("NavigationController: Pathfinder not initialized")
			path_not_found.emit(request.start_pos, request.goal_pos, "Navigation controller not initialized")
			return

		# Validate cells
		if not start_cell:
			path_not_found.emit(request.start_pos, request.goal_pos, "Start position is not on the grid")
			return

		if not goal_cell:
			path_not_found.emit(request.start_pos, request.goal_pos, "Goal position is not on the grid")
			return

		if not goal_cell.enabled:
			path_not_found.emit(request.start_pos, request.goal_pos, "Goal cell is disabled")
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
	pending_nav_requests.erase(request_id)

	if not cell:
		navigation_failed.emit("Target position is not on the grid")
		return

	if not cell.enabled:
		navigation_failed.emit("Target cell is disabled")
		return

	# Navigate to the cell
	navigate_to_cell_requested.emit(cell)

# ============================================================================
# AGENT NAVIGATOR CALLBACKS
# ============================================================================

func _on_agent_navigation_started(target_cell: HexCell):
	navigation_active = true
	current_path = hex_agent_navigator.get_current_path()
	current_target = target_cell

	# Visualize the navigation path
	if hex_path_visualizer and current_path.size() > 0:
		hex_path_visualizer.set_path(current_path)

	navigation_started.emit(target_cell)
	_emit_navigation_state()

func _on_agent_navigation_completed():
	navigation_active = false
	navigation_completed.emit()
	_clear_navigation_state()

func _on_agent_navigation_failed(reason: String):
	navigation_active = false
	navigation_failed.emit(reason)
	_clear_navigation_state()

func _on_agent_waypoint_reached(cell: HexCell, index: int):
	var remaining = hex_agent_navigator.get_remaining_distance()
	waypoint_reached.emit(cell, index, remaining)
	_emit_navigation_state()

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _emit_navigation_state():
	var path_length = current_path.size()
	var remaining = hex_agent_navigator.get_remaining_distance() if hex_agent_navigator else 0
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
