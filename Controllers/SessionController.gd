# Controllers/SessionController.gd
extends Node
class_name SessionController

## Manages overall navigation state and coordinates between systems
## Handles waypoint following and navigation mode switching

# Controller references
var navigation_controller: NavigationController
var player_controller: Node  # Your PlayerController

# Navigation modes
enum NavigationMode {
	HEXGRID,     # Hex grid pathfinding
	DIRECT,      # Direct navigation (no pathfinding)
	DISABLED     # Navigation disabled
}

@export var current_navigation_mode := NavigationMode.HEXGRID

# Navigation state
var is_navigating := false
var current_target := Vector2.ZERO
var path_waypoints: Array[Vector2] = []
var current_waypoint_index := 0

# Navigation parameters
@export var waypoint_reached_distance := 16.0  # Distance to consider waypoint reached
@export var path_update_interval := 0.5  # How often to check for path updates (seconds)
@export var auto_repath_on_stuck := true  # Automatically recalculate path if stuck
@export var stuck_time_threshold := 2.0  # Time without progress before considering stuck

# Debug
@export var debug_mode := false
@export var visualize_waypoints := true

# Internal state
var _last_player_position := Vector2.ZERO
var _time_since_progress := 0.0
var _time_since_path_update := 0.0

# Signals
signal navigation_started(target: Vector2)
signal navigation_completed()
signal navigation_cancelled()
signal waypoint_reached(index: int, total: int)
signal navigation_mode_changed(mode: NavigationMode)
signal stuck_detected()

func _ready() -> void:
	# Try to find controllers automatically
	if not navigation_controller:
		navigation_controller = _find_navigation_controller()
	
	if not player_controller:
		player_controller = _find_player_controller()
	
	# Connect signals
	if navigation_controller:
		navigation_controller.path_calculated.connect(_on_path_calculated)
		navigation_controller.pathfinding_failed.connect(_on_pathfinding_failed)
		if debug_mode:
			print("SessionController: Connected to NavigationController")
	else:
		push_warning("SessionController: NavigationController not found")
	
	if not player_controller:
		push_warning("SessionController: PlayerController not found")
	
	set_process(false)  # Only process when navigating

func _find_navigation_controller() -> NavigationController:
	# First try to find it as a sibling
	var sibling = get_parent().get_node_or_null("NavigationController")
	if sibling and is_instance_of(sibling, NavigationController):
		return sibling
	
	# Search scene tree by type
	return _find_node_by_type(get_tree().root, NavigationController)

func _find_player_controller() -> Node:
	# Search for common player node names
	var player_names := ["Robot Player", "Player", "RobotPlayer"]
	
	for player_name in player_names:
		var player = get_tree().root.find_child(player_name, true, false)
		if player:
			return player
	
	return null

func _find_node_by_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = _find_node_by_type(child, type)
		if result:
			return result
	
	return null

## Request navigation to target position
func request_navigation(target: Vector2) -> bool:
	if not navigation_controller:
		push_error("SessionController: NavigationController not available")
		return false
	
	if not player_controller:
		push_error("SessionController: PlayerController not available")
		return false
	
	if current_navigation_mode == NavigationMode.DISABLED:
		if debug_mode:
			print("SessionController: Navigation is disabled")
		return false
	
	current_target = target
	var start_pos = player_controller.global_position
	
	# Calculate path based on mode
	var path: Array[Vector2] = []
	
	match current_navigation_mode:
		NavigationMode.HEXGRID:
			path = navigation_controller.find_path(start_pos, target)
		NavigationMode.DIRECT:
			path = [start_pos, target]
	
	if path.is_empty():
		if debug_mode:
			print("SessionController: No path found to target")
		return false
	
	# Initialize navigation
	path_waypoints = path
	current_waypoint_index = 0
	is_navigating = true
	_last_player_position = start_pos
	_time_since_progress = 0.0
	_time_since_path_update = 0.0
	
	set_process(true)
	navigation_started.emit(target)
	
	if debug_mode:
		print("SessionController: Navigation started with %d waypoints" % path_waypoints.size())
	
	# Set initial waypoint target
	_update_player_target()
	
	return true

## Process navigation updates
func _process(delta: float) -> void:
	if not is_navigating or path_waypoints.is_empty():
		set_process(false)
		return
	
	if not player_controller:
		return
	
	var player_pos = player_controller.global_position
	
	# Update timers
	_time_since_path_update += delta
	
	# Check for progress
	var distance_moved = player_pos.distance_to(_last_player_position)
	if distance_moved > 1.0:  # Moved more than 1 pixel
		_time_since_progress = 0.0
		_last_player_position = player_pos
	else:
		_time_since_progress += delta
	
	# Stuck detection
	if auto_repath_on_stuck and _time_since_progress > stuck_time_threshold:
		if debug_mode:
			print("SessionController: Stuck detected, recalculating path")
		stuck_detected.emit()
		_recalculate_path()
		_time_since_progress = 0.0
	
	# Check waypoint progress
	if current_waypoint_index < path_waypoints.size():
		var waypoint = path_waypoints[current_waypoint_index]
		var distance = player_pos.distance_to(waypoint)
		
		if distance < waypoint_reached_distance:
			_on_waypoint_reached()
	
	# Periodic path updates (optional, for dynamic environments)
	if _time_since_path_update > path_update_interval:
		_time_since_path_update = 0.0
		# Could check for path validity here

## Called when a waypoint is reached
func _on_waypoint_reached() -> void:
	waypoint_reached.emit(current_waypoint_index, path_waypoints.size())
	
	if debug_mode:
		print("SessionController: Waypoint %d/%d reached" % [current_waypoint_index + 1, path_waypoints.size()])
	
	current_waypoint_index += 1
	
	if current_waypoint_index >= path_waypoints.size():
		# Reached final waypoint
		_complete_navigation()
	else:
		# Update to next waypoint
		_update_player_target()

## Update player's pathfinding target
func _update_player_target() -> void:
	if current_waypoint_index >= path_waypoints.size():
		return
	
	var target = path_waypoints[current_waypoint_index]
	
	# Update player controller's target
	# This assumes your player controller has a method to set destination
	# Adjust based on your actual implementation
	if player_controller.has_method("set_navigation_target"):
		player_controller.set_navigation_target(target)
	elif player_controller.has_method("set_destination"):
		player_controller.set_destination(target)
	
	if debug_mode:
		print("SessionController: Updated target to waypoint %d at %v" % [current_waypoint_index, target])

## Recalculate path from current position
func _recalculate_path() -> void:
	if not is_navigating or not player_controller or not navigation_controller:
		return
	
	var current_pos = player_controller.global_position
	var new_path = navigation_controller.find_path(current_pos, current_target)
	
	if not new_path.is_empty():
		path_waypoints = new_path
		current_waypoint_index = 0
		_update_player_target()
		
		if debug_mode:
			print("SessionController: Path recalculated with %d waypoints" % new_path.size())
	else:
		if debug_mode:
			print("SessionController: Path recalculation failed")

## Complete navigation successfully
func _complete_navigation() -> void:
	is_navigating = false
	path_waypoints.clear()
	current_waypoint_index = 0
	set_process(false)
	
	navigation_completed.emit()
	
	if debug_mode:
		print("SessionController: Navigation completed")

## Cancel ongoing navigation
func cancel_navigation() -> void:
	if not is_navigating:
		return
	
	is_navigating = false
	path_waypoints.clear()
	current_waypoint_index = 0
	set_process(false)
	
	# Stop player movement if applicable
	if player_controller:
		if player_controller.has_method("cancel_pathfinding"):
			player_controller.cancel_pathfinding()
		elif player_controller.has_method("stop_navigation"):
			player_controller.stop_navigation()
	
	# Clear path visualization
	if navigation_controller:
		navigation_controller.clear_path()
	
	navigation_cancelled.emit()
	
	if debug_mode:
		print("SessionController: Navigation cancelled")

## Set navigation mode
func set_navigation_mode(mode: NavigationMode) -> void:
	if current_navigation_mode == mode:
		return
	
	var old_mode = current_navigation_mode
	current_navigation_mode = mode
	
	# Cancel ongoing navigation when switching modes
	if is_navigating:
		cancel_navigation()
	
	navigation_mode_changed.emit(mode)
	
	if debug_mode:
		print("SessionController: Navigation mode changed from %s to %s" % [
			NavigationMode.keys()[old_mode],
			NavigationMode.keys()[mode]
		])

## Get current waypoint position
func get_current_waypoint() -> Vector2:
	if current_waypoint_index < path_waypoints.size():
		return path_waypoints[current_waypoint_index]
	return Vector2.ZERO

## Get remaining waypoints
func get_remaining_waypoints() -> Array[Vector2]:
	if current_waypoint_index >= path_waypoints.size():
		return []
	
	var remaining: Array[Vector2] = []
	for i in range(current_waypoint_index, path_waypoints.size()):
		remaining.append(path_waypoints[i])
	return remaining

## Get distance to current waypoint
func get_distance_to_waypoint() -> float:
	if not player_controller or current_waypoint_index >= path_waypoints.size():
		return 0.0
	
	var waypoint = path_waypoints[current_waypoint_index]
	return player_controller.global_position.distance_to(waypoint)

## Get distance to final target
func get_distance_to_target() -> float:
	if not player_controller or not is_navigating:
		return 0.0
	
	return player_controller.global_position.distance_to(current_target)

## Check if currently navigating
func is_navigation_active() -> bool:
	return is_navigating

## Get navigation progress (0.0 to 1.0)
func get_navigation_progress() -> float:
	if path_waypoints.is_empty():
		return 0.0
	
	return float(current_waypoint_index) / float(path_waypoints.size())

## Signal callbacks
func _on_path_calculated(path: Array[Vector2]) -> void:
	if debug_mode:
		print("SessionController: Path calculated with %d points" % path.size())

func _on_pathfinding_failed(start: Vector2, end: Vector2) -> void:
	if debug_mode:
		print("SessionController: Pathfinding failed from %v to %v" % [start, end])
	
	# Could implement retry logic or fallback behavior here

## Get navigation state info
func get_navigation_info() -> Dictionary:
	return {
		"is_navigating": is_navigating,
		"mode": NavigationMode.keys()[current_navigation_mode],
		"target": current_target,
		"waypoints_total": path_waypoints.size(),
		"waypoints_remaining": path_waypoints.size() - current_waypoint_index,
		"progress": get_navigation_progress(),
		"distance_to_waypoint": get_distance_to_waypoint(),
		"distance_to_target": get_distance_to_target()
	}
