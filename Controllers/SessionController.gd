extends Node
class_name SessionController

## Manages path navigation state and navigation mode switching

var navigation_controller: NavigationController
var player_controller: Node

enum NavigationMode {
	HEXGRID,
	DIRECT,
	DISABLED
}

@export var current_navigation_mode := NavigationMode.HEXGRID

# Navigation state
var is_navigating := false
var current_target := Vector2.ZERO
var path_waypoints: Array[Vector2] = []
var current_waypoint_index := 0

# Navigation parameters
@export var waypoint_reached_distance := 8.0
@export var path_update_interval := 0.5
@export var auto_repath_on_stuck := true
@export var stuck_time_threshold := 3.0
@export var stuck_distance_threshold := 5.0
@export var skip_waypoints_when_stuck := true

# Visualization options (for UI/Debug, implement elsewhere!)
@export var visualize_waypoints := true

# Internal state
var _last_player_position := Vector2.ZERO
var _time_since_progress := 0.0
var _time_since_path_update := 0.0
var _grid_ready := false
var _stuck_count := 0

# Signals
signal navigation_started(target: Vector2)
signal navigation_completed()
signal navigation_cancelled()
signal waypoint_reached(index: int, total: int)
signal navigation_mode_changed(mode: NavigationMode)
signal stuck_detected()
signal grid_ready()

func _ready() -> void:
	navigation_controller = _find_navigation_controller()
	player_controller = _find_player_controller()
	_connect_navigation_signals()
	set_process(false)

func _connect_navigation_signals() -> void:
	if navigation_controller:
		navigation_controller.path_calculated.connect(_on_path_calculated)
		navigation_controller.pathfinding_failed.connect(_on_pathfinding_failed)
		navigation_controller.grid_ready.connect(_on_grid_ready)
		waypoint_reached_distance = navigation_controller.hex_size * 1.0

func _on_grid_ready() -> void:
	_grid_ready = true
	grid_ready.emit()

func _find_navigation_controller() -> NavigationController:
	var node = get_parent().get_node_or_null("NavigationController")
	if node and is_instance_of(node, NavigationController):
		return node
	return _find_node_by_type(get_tree().root, NavigationController)

func _find_player_controller() -> Node:
	var names = ["Robot Player", "Player", "RobotPlayer", "robot_player"]
	for player_name in names:
		var pc = get_tree().root.find_child(player_name, true, false)
		if pc:
			return pc
	# Fallback: match lowercase names containing "player"
	for node in get_tree().root.get_children():
		if "player" in node.name.to_lower() and node is Node2D:
			return node
	return null

func _find_node_by_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var result = _find_node_by_type(child, type)
		if result:
			return result
	return null

func request_navigation(target: Vector2) -> bool:
	if not navigation_controller or not player_controller:
		return false
	if current_navigation_mode == NavigationMode.HEXGRID and not _grid_ready:
		if navigation_controller.has_signal("grid_ready"):
			await navigation_controller.grid_ready
		else:
			return false
	if current_navigation_mode == NavigationMode.DISABLED:
		return false

	current_target = target
	var start_pos = player_controller.global_position
	if start_pos == Vector2.ZERO:
		return false

	var path: Array[Vector2]
	match current_navigation_mode:
		NavigationMode.HEXGRID:
			path = navigation_controller.find_path(start_pos, target)
		NavigationMode.DIRECT:
			path = [start_pos, target]
	if path.is_empty():
		return false

	path_waypoints = path
	current_waypoint_index = 0
	is_navigating = true
	_last_player_position = start_pos
	_time_since_progress = 0.0
	_time_since_path_update = 0.0
	_stuck_count = 0

	set_process(true)
	navigation_started.emit(target)
	_update_player_target()
	return true

func _process(delta: float) -> void:
	if not is_navigating or path_waypoints.is_empty():
		set_process(false)
		return
	if not player_controller:
		return

	var player_pos = player_controller.global_position
	_time_since_path_update += delta
	var distance_moved = player_pos.distance_to(_last_player_position)
	if distance_moved > stuck_distance_threshold:
		_time_since_progress = 0.0
		_last_player_position = player_pos
		_stuck_count = 0
	else:
		_time_since_progress += delta

	if auto_repath_on_stuck and _time_since_progress > stuck_time_threshold:
		stuck_detected.emit()
		_handle_stuck()
		_time_since_progress = 0.0
		_last_player_position = player_pos

	if current_waypoint_index < path_waypoints.size():
		var waypoint = path_waypoints[current_waypoint_index]
		if player_pos.distance_to(waypoint) < waypoint_reached_distance:
			_on_waypoint_reached()

func _handle_stuck() -> void:
	_stuck_count += 1
	if _stuck_count == 1:
		_recalculate_path()
	elif _stuck_count == 2 and skip_waypoints_when_stuck:
		if current_waypoint_index < path_waypoints.size() - 1:
			current_waypoint_index += 1
			_update_player_target()
		else:
			_complete_navigation()
	elif _stuck_count >= 3 and skip_waypoints_when_stuck:
		if current_waypoint_index < path_waypoints.size() - 2:
			current_waypoint_index += 2
			_update_player_target()
		else:
			_complete_navigation()
	else:
		_recalculate_path()

func _on_waypoint_reached() -> void:
	waypoint_reached.emit(current_waypoint_index, path_waypoints.size())
	current_waypoint_index += 1
	_stuck_count = 0
	if current_waypoint_index >= path_waypoints.size():
		_complete_navigation()
	else:
		_update_player_target()

func _update_player_target() -> void:
	if current_waypoint_index >= path_waypoints.size():
		return
	var target = path_waypoints[current_waypoint_index]
	if player_controller.has_method("set_navigation_target"):
		player_controller.set_navigation_target(target)
	elif player_controller.has_method("set_destination"):
		player_controller.set_destination(target)

func _recalculate_path() -> void:
	if not is_navigating or not player_controller or not navigation_controller:
		return
	var current_pos = player_controller.global_position
	if current_waypoint_index < path_waypoints.size():
		var current_waypoint = path_waypoints[current_waypoint_index]
		var dist_to_current = current_pos.distance_to(current_waypoint)
		if dist_to_current < waypoint_reached_distance * 2.0 and current_waypoint_index < path_waypoints.size() - 1:
			current_waypoint_index += 1
			_update_player_target()
			return
	var new_path = navigation_controller.find_path(current_pos, current_target)
	if not new_path.is_empty():
		path_waypoints = new_path
		current_waypoint_index = 0
		_update_player_target()
	elif current_waypoint_index < path_waypoints.size() - 1:
		current_waypoint_index += 1
		_update_player_target()
	else:
		_complete_navigation()

func _complete_navigation() -> void:
	is_navigating = false
	path_waypoints.clear()
	current_waypoint_index = 0
	_stuck_count = 0
	set_process(false)
	navigation_completed.emit()

func cancel_navigation() -> void:
	if not is_navigating:
		return
	is_navigating = false
	path_waypoints.clear()
	current_waypoint_index = 0
	_stuck_count = 0
	set_process(false)
	if player_controller:
		if player_controller.has_method("cancel_pathfinding"):
			player_controller.cancel_pathfinding()
		elif player_controller.has_method("stop_navigation"):
			player_controller.stop_navigation()
	if navigation_controller:
		navigation_controller.clear_path()
	navigation_cancelled.emit()

func set_navigation_mode(mode: NavigationMode) -> void:
	if current_navigation_mode == mode:
		return
	current_navigation_mode = mode
	if is_navigating:
		cancel_navigation()
	navigation_mode_changed.emit(mode)

func get_current_waypoint() -> Vector2:
	if current_waypoint_index < path_waypoints.size():
		return path_waypoints[current_waypoint_index]
	return Vector2.ZERO

func get_remaining_waypoints() -> Array[Vector2]:
	var remaining: Array[Vector2] = []
	for i in range(current_waypoint_index, path_waypoints.size()):
		remaining.append(path_waypoints[i])
	return remaining

func get_distance_to_waypoint() -> float:
	if not player_controller or current_waypoint_index >= path_waypoints.size():
		return 0.0
	return player_controller.global_position.distance_to(path_waypoints[current_waypoint_index])

func get_distance_to_target() -> float:
	if not player_controller or not is_navigating:
		return 0.0
	return player_controller.global_position.distance_to(current_target)

func is_navigation_active() -> bool:
	return is_navigating

func get_navigation_progress() -> float:
	if path_waypoints.is_empty():
		return 0.0
	return float(current_waypoint_index) / float(path_waypoints.size())

func is_grid_ready() -> bool:
	return _grid_ready

func _on_path_calculated(_path: Array[Vector2]) -> void:
	pass

func _on_pathfinding_failed(_start: Vector2, _end: Vector2) -> void:
	pass

func get_navigation_info() -> Dictionary:
	return {
		"is_navigating": is_navigating,
		"mode": NavigationMode.keys()[current_navigation_mode],
		"target": current_target,
		"waypoints_total": path_waypoints.size(),
		"waypoints_remaining": path_waypoints.size() - current_waypoint_index,
		"progress": get_navigation_progress(),
		"distance_to_waypoint": get_distance_to_waypoint(),
		"distance_to_target": get_distance_to_target(),
		"grid_ready": _grid_ready,
		"stuck_count": _stuck_count
	}
