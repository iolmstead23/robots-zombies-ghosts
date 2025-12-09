class_name NavigableCellsCalculator
extends RefCounted

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
	# Use HexFloodFill for efficient area calculation
	var flood_fill := HexFloodFill.new()
	var result := flood_fill.get_reachable_cells(
		context.agent_cell,
		context.grid,
		context.remaining_distance
	)
	return result
