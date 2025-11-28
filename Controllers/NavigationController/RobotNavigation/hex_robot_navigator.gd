class_name HexRobotNavigator
extends Node

## Bridges hex pathfinding with robot navigation

signal navigation_started(target_cell: HexCell)
signal navigation_completed()
signal navigation_failed(reason: String)
signal waypoint_reached(cell: HexCell, index: int)

@export var hex_grid: HexGrid
@export var hex_pathfinder: HexPathfinder
@export var robot: CharacterBody2D

# Navigation state
var current_target_cell: HexCell = null
var current_hex_path: Array[HexCell] = []
var current_waypoint_index: int = 0
var is_navigating: bool = false

# Navigation settings
var waypoint_reach_distance: float = 10.0
var waypoint_timeout: float = 5.0

# Timeout tracking
var waypoint_start_time: float = 0.0
var last_distance_to_waypoint: float = INF

func _ready() -> void:
	if not hex_grid:
		push_error("HexRobotNavigator: No HexGrid assigned")
	if not hex_pathfinder:
		push_error("HexRobotNavigator: No HexPathfinder assigned")

func navigate_to_cell(target_cell: HexCell) -> bool:
	if not _validate_navigation_request(target_cell):
		return false
	
	var start_cell := hex_grid.get_cell_at_world_position(robot.global_position)
	if not start_cell:
		navigation_failed.emit("Robot not on hex grid")
		return false
	
	var path := hex_pathfinder.find_path(start_cell, target_cell)
	if path.is_empty():
		navigation_failed.emit("No path found")
		return false
	
	_start_navigation(target_cell, path)
	return true

func _validate_navigation_request(target_cell: HexCell) -> bool:
	if not target_cell or not target_cell.enabled:
		navigation_failed.emit("Target invalid or disabled")
		return false
	
	if not robot:
		navigation_failed.emit("No robot assigned")
		return false
	
	return true

func _start_navigation(target_cell: HexCell, path: Array[HexCell]) -> void:
	current_target_cell = target_cell
	current_hex_path = path
	current_waypoint_index = 0
	is_navigating = true
	
	navigation_started.emit(target_cell)
	_navigate_to_next_waypoint()

func navigate_to_world_position(world_pos: Vector2) -> bool:
	var target_cell := hex_grid.get_cell_at_world_position(world_pos)
	if not target_cell:
		navigation_failed.emit("Position not on grid")
		return false
	
	return navigate_to_cell(target_cell)

func cancel_navigation() -> void:
	if not is_navigating:
		return
	
	is_navigating = false
	current_target_cell = null
	current_hex_path.clear()
	current_waypoint_index = 0
	
	_cancel_robot_navigation()

func _cancel_robot_navigation() -> void:
	if not robot or not robot.has_node("NavigationAgent2D"):
		return
	
	var nav_agent := robot.get_node("NavigationAgent2D") as NavigationAgent2D
	if nav_agent:
		nav_agent.target_position = robot.global_position

func _process(_delta: float) -> void:
	if is_navigating:
		_update_navigation()

func _update_navigation() -> void:
	if current_waypoint_index >= current_hex_path.size():
		_complete_navigation()
		return
	
	var waypoint := current_hex_path[current_waypoint_index]
	var distance := robot.global_position.distance_to(waypoint.world_position)
	var nav_finished := _is_nav_agent_finished()
	var is_stuck := _check_if_stuck(distance)
	
	_debug_print_progress(distance)
	
	if _should_advance_waypoint(distance, nav_finished, is_stuck):
		_handle_waypoint_reached(waypoint, distance, nav_finished, is_stuck)

func _is_nav_agent_finished() -> bool:
	if not robot.has_node("NavigationAgent2D"):
		return false
	
	var nav_agent := robot.get_node("NavigationAgent2D") as NavigationAgent2D
	return nav_agent.is_navigation_finished() if nav_agent else false

func _check_if_stuck(current_distance: float) -> bool:
	var time_elapsed := Time.get_ticks_msec() / 1000.0 - waypoint_start_time
	var distance_improved := last_distance_to_waypoint - current_distance
	
	last_distance_to_waypoint = current_distance
	
	return time_elapsed > waypoint_timeout and distance_improved < 1.0

func _should_advance_waypoint(distance: float, nav_finished: bool, is_stuck: bool) -> bool:
	return distance < waypoint_reach_distance or nav_finished or is_stuck

func _handle_waypoint_reached(waypoint: HexCell, distance: float, nav_finished: bool, is_stuck: bool) -> void:
	_print_waypoint_status(distance, nav_finished, is_stuck)
	
	waypoint_reached.emit(waypoint, current_waypoint_index)
	current_waypoint_index += 1
	
	if current_waypoint_index < current_hex_path.size():
		_navigate_to_next_waypoint()
	else:
		_complete_navigation()

func _print_waypoint_status(_distance: float, _nav_finished: bool, _is_stuck: bool) -> void:
	# Waypoint reached - continue navigation silently
	pass

func _debug_print_progress(_distance: float) -> void:
	# Debug progress logging disabled
	pass

func _navigate_to_next_waypoint() -> void:
	if current_waypoint_index >= current_hex_path.size():
		return
	
	var waypoint := current_hex_path[current_waypoint_index]
	waypoint_start_time = Time.get_ticks_msec() / 1000.0
	last_distance_to_waypoint = INF
	
	var nav_set := _set_robot_nav_target(waypoint)
	
	if OS.is_debug_build():
		print("  → Waypoint %d: (%d,%d) at %s%s" % [
			current_waypoint_index + 1, waypoint.q, waypoint.r, waypoint.world_position,
			"" if nav_set else " [WARNING: NavAgent2D not found]"
		])

func _set_robot_nav_target(waypoint: HexCell) -> bool:
	var nav_set := false
	
	if robot.has_node("NavigationAgent2D"):
		var nav_agent := robot.get_node("NavigationAgent2D") as NavigationAgent2D
		if nav_agent:
			nav_agent.target_position = waypoint.world_position
			nav_set = true
	
	if robot.has_method("set_destination"):
		robot.call("set_destination", waypoint.world_position)
	
	return nav_set

func _complete_navigation() -> void:
	is_navigating = false
	
	if OS.is_debug_build():
		print("HexRobotNavigator: Navigation completed at (%d,%d)" % [
			current_target_cell.q, current_target_cell.r
		])
	
	navigation_completed.emit()
	
	current_target_cell = null
	current_hex_path.clear()
	current_waypoint_index = 0

func get_current_path() -> Array[HexCell]:
	return current_hex_path

func get_remaining_distance() -> int:
	if not is_navigating:
		return 0
	return max(0, current_hex_path.size() - current_waypoint_index)

func is_navigation_active() -> bool:
	return is_navigating