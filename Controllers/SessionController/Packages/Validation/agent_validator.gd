class_name AgentValidator
extends RefCounted

func validate_agent(agent: Variant, index: int = -1, context: String = "") -> SessionTypes.ValidationResult:
	if not agent or not is_instance_valid(agent):
		return SessionTypes.ValidationResult.fail("Invalid agent ref at %d (%s)" % [index, context])

	if agent is AgentData:
		var controller = agent.agent_controller
		if not controller or not is_instance_valid(controller):
			return SessionTypes.ValidationResult.fail("Invalid agent controller at %d (%s)" % [index, context])
		if not controller is CharacterBody2D:
			return SessionTypes.ValidationResult.fail("Agent controller is not CharacterBody2D at %d (%s)" % [index, context])
		return SessionTypes.ValidationResult.ok()

	if agent is CharacterBody2D:
		return SessionTypes.ValidationResult.ok()

	return SessionTypes.ValidationResult.fail("Unknown agent type at %d (%s): %s" % [index, context, typeof(agent)])


func validate_agents_array(agents: Array, context: String = "") -> SessionTypes.ValidationResult:
	if agents.is_empty():
		return SessionTypes.ValidationResult.fail("Empty agents array (%s)" % context)

	for i in agents.size():
		var result := validate_agent(agents[i], i, context)
		if not result.success:
			return result

	return SessionTypes.ValidationResult.ok()


func validate_movement_request(agent: AgentData, target_cell: HexCell) -> SessionTypes.ValidationResult:
	if not agent:
		return SessionTypes.ValidationResult.fail("No agent provided")

	if not target_cell:
		return SessionTypes.ValidationResult.fail("No target cell provided")

	if not target_cell.enabled:
		return SessionTypes.ValidationResult.fail("Target cell is disabled")

	if not agent.can_move():
		return SessionTypes.ValidationResult.fail("Agent has no movements remaining")

	var controller = agent.agent_controller
	if not controller:
		return SessionTypes.ValidationResult.fail("Agent controller not found")

	return SessionTypes.ValidationResult.ok()
