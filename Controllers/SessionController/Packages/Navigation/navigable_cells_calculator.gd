class_name NavigableCellsCalculator
extends RefCounted

const HEX_DISTANCE_MULTIPLIER := 2.0

signal calculation_completed(cells: Array[HexCell], agent_cell: HexCell)

var _last_agent_cell: HexCell = null


func get_last_agent_cell() -> HexCell:
	return _last_agent_cell


func calculate(agent: AgentData, grid: HexGrid, pathfinder) -> Array[HexCell]:
	var agent_cell := resolve_agent_cell(agent, grid)
	_last_agent_cell = agent_cell

	var context := SessionTypes.NavigableContext.build(agent, grid, pathfinder, agent_cell)
	if not context.is_valid:
		calculation_completed.emit([] as Array[HexCell], null)
		return []

	var result := _filter_reachable_cells(context)
	calculation_completed.emit(result, agent_cell)
	return result


func resolve_agent_cell(agent: AgentData, grid: HexGrid) -> HexCell:
	if not agent or not grid:
		return null

	if agent.get("current_cell") != null:
		return agent.current_cell

	var controller = agent.get("agent_controller")
	if not controller:
		return null

	if controller.get("current_cell") != null:
		return controller.current_cell

	if controller.get("global_position") != null:
		return grid.get_cell_at_world_position(controller.global_position)

	return null


func _filter_reachable_cells(context: SessionTypes.NavigableContext) -> Array[HexCell]:
	var result: Array[HexCell] = []
	var max_hex_range := int(context.remaining_distance * HEX_DISTANCE_MULTIPLIER)
	var candidates := context.grid.get_enabled_cells_in_range(context.agent_cell, max_hex_range)

	for cell in candidates:
		if _is_cell_reachable(cell, context):
			result.append(cell)

	return result


func _is_cell_reachable(cell: HexCell, context: SessionTypes.NavigableContext) -> bool:
	if cell == context.agent_cell:
		return true

	var path: Array = context.pathfinder.find_path(context.agent_cell, cell)
	if path.is_empty():
		return false

	var path_distance := path.size() - 1
	return path_distance <= context.remaining_distance
