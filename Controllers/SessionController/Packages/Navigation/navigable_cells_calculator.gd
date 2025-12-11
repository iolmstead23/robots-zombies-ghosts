class_name NavigableCellsCalculator
extends RefCounted

signal calculation_completed(cells: Array[HexCell], agent_cell: HexCell)

# Distance filter configuration
var use_distance_filter: bool = true
var distance_tolerance: float = 2.0  # 100% tolerance to account for distortion variance

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

	# Create distance validation filter if enabled
	var distance_filter = null
	if use_distance_filter and context.grid.use_isometric_transform:
		distance_filter = func(cell: HexCell) -> bool:
			var logical_dist := context.agent_cell.distance_to(cell)
			if logical_dist == 0:
				return true
			var visual_dist := IsoDistanceCalculator.calculate_isometric_distance(context.agent_cell, cell)
			var avg_spacing := (context.grid.horizontal_spacing + context.grid.vertical_spacing) / 2.0
			var expected_visual := float(logical_dist) * avg_spacing
			return visual_dist <= expected_visual * distance_tolerance

	return flood_fill.get_reachable_cells(
		context.agent_cell,
		context.grid,
		context.remaining_distance,
		distance_filter
	)
