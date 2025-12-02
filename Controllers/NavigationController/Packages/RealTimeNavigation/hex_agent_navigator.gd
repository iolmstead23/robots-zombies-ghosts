class_name HexAgentNavigator
extends Node

## Bridges hex pathfinding with agent navigation (REAL-TIME MODE)
##
## STATUS: DISABLED - This real-time navigation system is currently disabled
## The game uses turn-based movement via TurnBasedMovementController
## This code is preserved for future use when real-time navigation may be needed
##
## To enable real-time navigation:
## 1. Uncomment the hex_agent_navigator initialization in NavigationController.initialize()
## 2. Uncomment the related callback functions in NavigationController
## 3. Switch agent movement mode from turn-based to real-time
##
## Refactored to use Core components for better organization and reusability.

signal navigation_started(target_cell: HexCell)
signal navigation_completed()
signal navigation_failed(reason: String)
signal waypoint_reached(cell: HexCell, index: int)

@export var hex_grid: HexGrid
@export var hex_pathfinder: HexPathfinder
@export var agent: CharacterBody2D

# Core components
var _nav_state: NavigationState = null
var _waypoint_tracker: WaypointTracker = null

# Configuration storage (applied after _waypoint_tracker is ready)
var _pending_waypoint_reach_distance: int = -1

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	if not hex_grid:
		push_error("HexAgentNavigator: No HexGrid assigned")
	if not hex_pathfinder:
		push_error("HexAgentNavigator: No HexPathfinder assigned")

	# Initialize Core components
	_nav_state = NavigationState.new()
	_waypoint_tracker = WaypointTracker.new()

	add_child(_nav_state)
	add_child(_waypoint_tracker)

	# Apply pending configuration
	if _pending_waypoint_reach_distance >= 0:
		_waypoint_tracker.waypoint_reach_distance = _pending_waypoint_reach_distance

	# Connect signals
	_waypoint_tracker.waypoint_reached.connect(_on_waypoint_reached)
	_waypoint_tracker.all_waypoints_reached.connect(_on_all_waypoints_reached)

# ============================================================================
# PUBLIC API - NAVIGATION
# ============================================================================

func navigate_to_cell(target_cell: HexCell) -> bool:
	if not PathValidator.is_cell_valid(target_cell):
		navigation_failed.emit("Target invalid or disabled")
		return false
	if not _validate_agent(agent, "HexAgentNavigator.navigate_to_cell"):
		navigation_failed.emit("Agent validation failed (see error log)")
		return false

	var start_cell := hex_grid.get_cell_at_world_position(agent.global_position)
	if not start_cell:
		navigation_failed.emit("Agent not on hex grid")
		return false

	var path := hex_pathfinder.find_path(start_cell, target_cell)
	if path.is_empty():
		navigation_failed.emit("No path found")
		return false

	_start_navigation(target_cell, path)
	return true

func navigate_to_world_position(world_pos: Vector2) -> bool:
	var target_cell := hex_grid.get_cell_at_world_position(world_pos)
	if not target_cell:
		navigation_failed.emit("Position not on grid")
		return false

	return navigate_to_cell(target_cell)

func cancel_navigation() -> void:
	if not _nav_state.is_navigating:
		return

	_nav_state.clear_navigation()
	_waypoint_tracker.stop_tracking()

	_cancel_agent_navigation()

# ============================================================================
# PUBLIC API - STATE QUERIES
# ============================================================================

func get_current_path() -> Array[HexCell]:
	return _nav_state.current_hex_path

func get_remaining_distance() -> int:
	return _waypoint_tracker.get_remaining_count(_nav_state.current_hex_path.size())

func is_navigation_active() -> bool:
	return _nav_state.is_navigating

# ============================================================================
# PUBLIC API - CONFIGURATION
# ============================================================================

## Set the distance threshold for waypoint advancement
var waypoint_reach_distance: int:
	get:
		if _waypoint_tracker:
			return _waypoint_tracker.waypoint_reach_distance
		return _pending_waypoint_reach_distance
	set(value):
		if _waypoint_tracker:
			_waypoint_tracker.waypoint_reach_distance = value
		else:
			_pending_waypoint_reach_distance = value

# ============================================================================
# INTERNAL - NAVIGATION
# ============================================================================

func _start_navigation(target_cell: HexCell, path: Array[HexCell]) -> void:
	_nav_state.start_navigation(target_cell, path)
	_waypoint_tracker.start_tracking()

	navigation_started.emit(target_cell)
	_navigate_to_next_waypoint()

func _navigate_to_next_waypoint() -> void:
	var waypoint := _nav_state.get_current_waypoint()
	if not waypoint:
		return

	_waypoint_tracker.reset_waypoint_tracking()

	var nav_set := _set_agent_nav_target(waypoint)

	if OS.is_debug_build():
		print("  → Waypoint %d: (%d,%d) at %s%s" % [
			_nav_state.current_waypoint_index + 1,
			waypoint.q,
			waypoint.r,
			waypoint.world_position,
			"" if nav_set else " [WARNING: NavAgent2D not found]"
		])

func _set_agent_nav_target(waypoint: HexCell) -> bool:
	if not _validate_agent(agent, "HexAgentNavigator._set_agent_nav_target"):
		return false
	var nav_set := false

	if agent.has_node("NavigationAgent2D"):
		var nav_agent := agent.get_node("NavigationAgent2D") as NavigationAgent2D
		if nav_agent:
			nav_agent.target_position = waypoint.world_position
			nav_set = true

	if agent.has_method("set_destination"):
		agent.call("set_destination", waypoint.world_position)

	return nav_set

func _cancel_agent_navigation() -> void:
	if not _validate_agent(agent, "HexAgentNavigator._cancel_agent_navigation"):
		return
	if not agent or not agent.has_node("NavigationAgent2D"):
		return

	var nav_agent := agent.get_node("NavigationAgent2D") as NavigationAgent2D
	if nav_agent:
		nav_agent.target_position = agent.global_position

func _complete_navigation() -> void:
	if OS.is_debug_build() and _nav_state.current_target_cell:
		print("HexAgentNavigator: Navigation completed at (%d,%d)" % [
			_nav_state.current_target_cell.q,
			_nav_state.current_target_cell.r
		])

	navigation_completed.emit()
	_nav_state.clear_navigation()
	_waypoint_tracker.stop_tracking()

# ============================================================================
# PROCESS
# ============================================================================

func _process(_delta: float) -> void:
	if _nav_state.is_navigating:
		_update_navigation()

func _update_navigation() -> void:
	if _nav_state.is_at_final_waypoint():
		_complete_navigation()
		return

	var waypoint := _nav_state.get_current_waypoint()
	if not waypoint:
		_complete_navigation()
		return

	# Convert hex path to world positions for waypoint tracker
	var world_path: Array[Vector2] = []
	for cell in _nav_state.current_hex_path:
		world_path.append(cell.world_position)

	# Update waypoint tracking
	_waypoint_tracker.update_tracking(agent.global_position, world_path)

	# Check if NavigationAgent2D finished (alternative waypoint advancement)
	if _is_nav_agent_finished():
		_nav_state.advance_waypoint()
		if not _nav_state.is_at_final_waypoint():
			_navigate_to_next_waypoint()
		else:
			_complete_navigation()

func _is_nav_agent_finished() -> bool:
	if not _validate_agent(agent, "HexAgentNavigator._is_nav_agent_finished"):
		return false
	if not agent.has_node("NavigationAgent2D"):
		return false

	var nav_agent := agent.get_node("NavigationAgent2D") as NavigationAgent2D
	return nav_agent.is_navigation_finished() if nav_agent else false

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_waypoint_reached(waypoint: Vector2, index: int, remaining: int) -> void:
	var hex_waypoint := _nav_state.get_current_waypoint()
	if hex_waypoint:
		waypoint_reached.emit(hex_waypoint, index)

	_nav_state.advance_waypoint()

	if not _nav_state.is_at_final_waypoint():
		_navigate_to_next_waypoint()

func _on_all_waypoints_reached() -> void:
	_complete_navigation()

# =============================================================================
# INTERNAL - AGENT VALIDATION
# =============================================================================
func _validate_agent(agent_ref: Variant, context: String) -> bool:
	# Check null first before any method calls
	if agent_ref == null:
		push_error("[Agent Validation Error] in %s: Agent is null.\nCallstack:\n%s"
			% [context, OS.get_stack()])
		return false

	var is_valid := true
	var messages := []
	var conditions := {
		"is_freed": (typeof(agent_ref) == TYPE_OBJECT and agent_ref.is_queued_for_deletion()),
		"not_character_body": (not (agent_ref is CharacterBody2D)),
		"lacks_position": (typeof(agent_ref) == TYPE_OBJECT and not ("global_position" in agent_ref)),
	}

	if conditions["is_freed"]:
		is_valid = false
		messages.append("Agent is queued for deletion.")
	if conditions["not_character_body"]:
		is_valid = false
		var type_name = agent_ref.get_class() if typeof(agent_ref) == TYPE_OBJECT else str(typeof(agent_ref))
		messages.append("Agent is not a CharacterBody2D (got type: %s)." % [type_name])
	if conditions["lacks_position"]:
		is_valid = false
		messages.append("Agent lacks 'global_position' property.")

	if not is_valid:
		var type_name = agent_ref.get_class() if typeof(agent_ref) == TYPE_OBJECT else str(typeof(agent_ref))
		push_error("[Agent Validation Error] in %s: Failing agent reference. Details: type=%s value=%s; Checks=[%s]\nCallstack:\n%s"
			% [
				context,
				type_name,
				str(agent_ref),
				", ".join(messages),
				OS.get_stack()
			]
		)
	return is_valid
