class_name MovementPlanner
extends RefCounted

signal movement_planned(path: Array[HexCell])
signal movement_executed()
signal movement_cancelled()
signal movement_failed(reason: String)

var _planned: SessionTypes.PlannedMovement = SessionTypes.PlannedMovement.new()
var _validator: AgentValidator = AgentValidator.new()

var navigation_controller = null
var hex_grid_controller = null
var agent_manager = null
var session_controller = null


func configure(nav_ctrl, grid_ctrl, agent_mgr, session_ctrl = null) -> void:
	navigation_controller = nav_ctrl
	hex_grid_controller = grid_ctrl
	agent_manager = agent_mgr
	session_controller = session_ctrl


func has_planned_movement() -> bool:
	return _planned.is_valid()


func get_planned_path() -> Array[HexCell]:
	return _planned.path


func get_planned_target() -> HexCell:
	return _planned.target_cell


func plan_movement(agent: AgentData, target_cell: HexCell) -> bool:
	# Pass session_controller to validator for navigability check
	var validation := _validator.validate_movement_request(agent, target_cell, session_controller)
	if not validation.success:
		_clear_planned()
		return false

	if not _has_required_controllers():
		_clear_planned()
		return false

	var agent_cell := _get_agent_cell(agent)
	if not agent_cell:
		_clear_planned()
		return false

	var path := _calculate_path(agent_cell, target_cell)
	if path.is_empty():
		_clear_planned()
		return false

	var max_distance := _get_max_distance(agent)
	var truncated_path := _truncate_path_if_needed(path, max_distance)

	_apply_plan(agent, truncated_path)
	_visualize_path(truncated_path)
	movement_planned.emit(truncated_path)
	return true


func execute_movement(scene_tree: SceneTree) -> void:
	if not _planned.is_valid():
		movement_failed.emit("No planned movement to execute")
		return

	# Don't record distance yet - wait for actual movement to complete
	var path_distance := _calculate_path_pixel_distance(_planned.path)
	print("[MovementPlanner] Planned distance: %.2f pixels (will record after movement)" % path_distance)

	var agent_controller = _planned.agent.agent_controller
	if not agent_controller:
		cancel_movement()
		movement_failed.emit("Agent controller not found")
		return

	var turn_based = agent_controller.turn_based_controller
	if not turn_based:
		cancel_movement()
		movement_failed.emit("Turn-based controller not found")
		return

	await _ensure_controller_active(turn_based, scene_tree)
	_connect_completion_handler(turn_based, path_distance)
	turn_based.request_movement_to(_planned.target_cell.world_position, path_distance)

	await scene_tree.process_frame
	turn_based.confirm_movement()

	_clear_planned()
	movement_executed.emit()


func cancel_movement() -> void:
	var had_plan := _planned.is_valid()
	_clear_planned()
	_clear_visualization()
	if had_plan:
		movement_cancelled.emit()


func _has_required_controllers() -> bool:
	return navigation_controller != null and hex_grid_controller != null


func _get_agent_cell(agent: AgentData) -> HexCell:
	var controller = agent.agent_controller
	if not controller:
		return null

	if not session_controller:
		return null

	# Use SessionController API instead of direct grid access
	return session_controller.get_cell_at_world_position(controller.global_position)


func _calculate_path(start: HexCell, goal: HexCell) -> Array[HexCell]:
	var pathfinder = navigation_controller.get_pathfinder()
	if not pathfinder:
		return []
	return pathfinder.find_path(start, goal)


func _get_max_distance(agent: AgentData) -> float:
	if agent.has_method("get_distance_remaining"):
		return agent.get_distance_remaining()
	return float(agent.max_movements_per_turn)


func _truncate_path_if_needed(path: Array[HexCell], max_distance: float) -> Array[HexCell]:
	if path.size() <= 1:
		return path

	# Use hex cell count for distance calculation (clean, discrete movement)
	# Each hex cell = NEIGHBOR_DISTANCE_PIXELS
	var truncated_path: Array[HexCell] = [path[0]]

	for i in range(1, path.size()):
		var next_distance := float(i) * HexConstants.NEIGHBOR_DISTANCE_PIXELS
		if next_distance > max_distance:
			break
		truncated_path.append(path[i])

	return truncated_path


func _apply_plan(agent: AgentData, path: Array[HexCell]) -> void:
	_planned.agent = agent
	_planned.path = path
	_planned.target_cell = path[path.size() - 1] if path.size() > 0 else null
	_planned.path_distance = path.size() - 1


func _visualize_path(path: Array[HexCell]) -> void:
	var visualizer = navigation_controller.get_path_visualizer()
	if visualizer:
		visualizer.set_path(path)


func _clear_visualization() -> void:
	if not navigation_controller:
		return
	var visualizer = navigation_controller.get_path_visualizer()
	if visualizer:
		visualizer.clear_path()


func _clear_planned() -> void:
	_planned.clear()


func _calculate_path_pixel_distance(path: Array[HexCell]) -> float:
	if path.size() <= 1:
		print("[MovementPlanner] Path too short for distance calculation: size=%d" % path.size())
		return 0.0

	# Calculate distance based on hex cell count for clean, discrete movement
	# This ensures agents always move in whole hex cell increments
	var hex_cell_count := path.size() - 1
	var total_distance := float(hex_cell_count) * HexConstants.NEIGHBOR_DISTANCE_PIXELS

	print("[MovementPlanner] Path: %d hex cells = %.2f pixels (%.2f per cell)" % [
		hex_cell_count,
		total_distance,
		HexConstants.NEIGHBOR_DISTANCE_PIXELS
	])
	return total_distance


func _record_movement(distance: float) -> bool:
	if not agent_manager:
		return false
	print("[MovementPlanner] Recording movement: %.2f pixels" % distance)
	var result: bool = agent_manager.record_movement_action(distance)
	print("[MovementPlanner] Record result: %s" % result)
	return result


func _ensure_controller_active(turn_based, scene_tree: SceneTree) -> void:
	if not turn_based.is_active:
		turn_based.activate()
		await scene_tree.process_frame

	# Ensure state is IDLE before proceeding
	if not turn_based.is_in_state(NavigationTypes.TurnState.IDLE):
		var max_wait_frames := 60  # ~1 second at 60fps
		var frames_waited := 0
		while not turn_based.is_in_state(NavigationTypes.TurnState.IDLE) and frames_waited < max_wait_frames:
			await scene_tree.process_frame
			frames_waited += 1


func _connect_completion_handler(turn_based, planned_distance: float) -> void:
	var agent_data = _planned.agent
	# Record distance AFTER movement completes
	var handler := func(_distance_moved: int):
		print("[MovementPlanner] Movement completed, recording distance: %.2f pixels" % planned_distance)
		if agent_manager:
			agent_manager.record_movement_action(planned_distance)
			agent_manager.update_agent_position_after_movement(agent_data)

	if not turn_based.movement_completed.is_connected(handler):
		turn_based.movement_completed.connect(handler, CONNECT_ONE_SHOT)
