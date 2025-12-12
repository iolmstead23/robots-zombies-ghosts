class_name NavigableCellsCalculator
extends RefCounted

signal calculation_completed(cells: Array[HexCell], agent_cell: HexCell)

# Distance filter configuration
# Creates circular movement area by constraining to pixel radius
# Radius based on minimum neighbor distance (from HexConstants)
const USE_DISTANCE_FILTER: bool = true
const DISTANCE_TOLERANCE: float = HexConstants.DISTANCE_TOLERANCE

var _last_agent_cell: HexCell = null


func get_last_agent_cell() -> HexCell:
	return _last_agent_cell


func calculate(agent: AgentData, grid_api, pathfinder) -> Array[HexCell]:
	var agent_cell: HexCell = resolve_agent_cell(agent, grid_api)
	_last_agent_cell = agent_cell

	var context := SessionTypes.NavigableContext.build(agent, grid_api, pathfinder, agent_cell)
	if not context.is_valid:
		calculation_completed.emit([] as Array[HexCell], null)
		return []

	var result := _filter_reachable_cells(context)
	calculation_completed.emit(result, agent_cell)
	return result


func resolve_agent_cell(agent: AgentData, grid_api) -> Variant:  # Returns HexCell or null
	if not agent or not grid_api:
		push_warning("[NavigableCellsCalculator] Cannot resolve agent cell: agent or grid_api is null")
		return null

	if agent.get("current_cell") != null:
		return agent.current_cell

	var controller = agent.get("agent_controller")
	if not controller:
		push_warning("[NavigableCellsCalculator] Agent has no controller")
		return null

	if controller.get("current_cell") != null:
		return controller.current_cell

	if controller.get("global_position") != null:
		return grid_api.get_cell_at_world_position(controller.global_position)

	push_warning("[NavigableCellsCalculator] Could not resolve agent cell from any source")
	return null


func _filter_reachable_cells(context: SessionTypes.NavigableContext) -> Array[HexCell]:
	# Use HexFloodFill for efficient area calculation
	var flood_fill := HexFloodFill.new()

	# Create distance validation filter if enabled
	var distance_filter = null
	if USE_DISTANCE_FILTER and context.grid.use_isometric_transform:
		var pixel_radius := context.remaining_distance
		distance_filter = func(cell: HexCell) -> bool:
			if cell == context.agent_cell:
				return true
			var visual_dist := IsoDistanceCalculator.calculate_isometric_distance(context.agent_cell, cell)
			return visual_dist <= pixel_radius * DISTANCE_TOLERANCE

	return flood_fill.get_reachable_cells(
		context.agent_cell,
		context.grid,
		context.remaining_distance,
		distance_filter
	)
