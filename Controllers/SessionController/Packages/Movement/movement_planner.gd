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


func configure(nav_ctrl, grid_ctrl, agent_mgr) -> void:
	navigation_controller = nav_ctrl
	hex_grid_controller = grid_ctrl
	agent_manager = agent_mgr


func has_planned_movement() -> bool:
	return _planned.is_valid()


func get_planned_path() -> Array[HexCell]:
	return _planned.path


func get_planned_target() -> HexCell:
	return _planned.target_cell


func plan_movement(agent: AgentData, target_cell: HexCell) -> bool:
	var validation := _validator.validate_movement_request(agent, target_cell)
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

	var path_distance := _planned.path.size() - 1
	if not _record_movement(path_distance):
		cancel_movement()
		movement_failed.emit("Cannot record movement action")
		return

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
	_connect_completion_handler(turn_based)
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

	var grid = hex_grid_controller.get_hex_grid()
	if not grid:
		return null

	return grid.get_cell_at_world_position(controller.global_position)


func _calculate_path(start: HexCell, goal: HexCell) -> Array[HexCell]:
	var pathfinder = navigation_controller.get_pathfinder()
	if not pathfinder:
		return []
	return pathfinder.find_path(start, goal)


func _get_max_distance(agent: AgentData) -> int:
	if agent.has_method("get_distance_remaining"):
		return agent.get_distance_remaining()
	return agent.max_movements_per_turn


func _truncate_path_if_needed(path: Array[HexCell], max_distance: int) -> Array[HexCell]:
	var path_distance := path.size() - 1
	if path_distance <= max_distance:
		return path
	return path.slice(0, max_distance + 1)


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


func _record_movement(distance: int) -> bool:
	if not agent_manager:
		return false
	return agent_manager.record_movement_action(distance)


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


func _connect_completion_handler(turn_based) -> void:
	var agent_data = _planned.agent
	# Distance is tracked through agent state, not recalculated from movement
	var handler := func(_distance_moved: int):
		if agent_manager:
			agent_manager.update_agent_position_after_movement(agent_data)

	if not turn_based.movement_completed.is_connected(handler):
		turn_based.movement_completed.connect(handler, CONNECT_ONE_SHOT)
