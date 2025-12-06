class_name SessionTypes
extends RefCounted

enum SessionState { IDLE, INITIALIZING, ACTIVE, PAUSED, ENDED }
enum MovementState { NONE, PLANNING, READY, EXECUTING }
enum InitResult { SUCCESS, TIMEOUT, FAILED }

class TurnInfo:
	var turn_number: int = 0
	var agent_name: String = ""
	var agent_index: int = 0
	var total_agents: int = 0
	var movements_left: int = 0
	var actions_left: Variant = "-"

	func _init(data: Dictionary = {}) -> void:
		turn_number = data.get("turn_number", 0)
		agent_name = data.get("agent_name", "")
		agent_index = data.get("agent_index", 0)
		total_agents = data.get("total_agents", 0)
		movements_left = data.get("movements_left", 0)
		actions_left = data.get("actions_left", "-")

	func to_dict() -> Dictionary:
		return {
			"turn_number": turn_number,
			"agent_name": agent_name,
			"agent_index": agent_index,
			"total_agents": total_agents,
			"movements_left": movements_left,
			"actions_left": actions_left
		}


class PlannedMovement:
	var target_cell: HexCell = null
	var path: Array[HexCell] = []
	var agent: AgentData = null
	var path_distance: int = 0

	func is_valid() -> bool:
		return target_cell != null and agent != null and path.size() > 0

	func clear() -> void:
		target_cell = null
		path.clear()
		agent = null
		path_distance = 0


class NavigableContext:
	var agent: AgentData = null
	var agent_cell: HexCell = null
	var grid: HexGrid = null
	var pathfinder = null
	var remaining_distance: int = 0
	var is_valid: bool = false

	static func build(p_agent: AgentData, p_grid: HexGrid, p_pathfinder, p_agent_cell: HexCell) -> NavigableContext:
		var ctx := NavigableContext.new()
		ctx.agent = p_agent
		ctx.grid = p_grid
		ctx.pathfinder = p_pathfinder
		ctx.agent_cell = p_agent_cell

		if not p_agent or not p_grid or not p_pathfinder or not p_agent_cell:
			ctx.is_valid = false
			return ctx

		ctx.remaining_distance = int(p_agent.get_distance_remaining()) if p_agent.has_method("get_distance_remaining") else 10
		ctx.is_valid = ctx.remaining_distance > 0
		return ctx


class ValidationResult:
	var success: bool = false
	var message: String = ""

	static func ok() -> ValidationResult:
		var r := ValidationResult.new()
		r.success = true
		return r

	static func fail(msg: String) -> ValidationResult:
		var r := ValidationResult.new()
		r.success = false
		r.message = msg
		return r
