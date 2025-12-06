class_name CameraTransitionHandler
extends RefCounted

## Handles camera transition calculations
## Computes target positions and manages transition state

# ============================================================================
# CONFIGURATION
# ============================================================================

var bounds_calculator: CameraBoundsCalculator = null

func set_bounds_calculator(calculator: CameraBoundsCalculator) -> void:
	"""Set the bounds calculator for target position clamping"""
	bounds_calculator = calculator

# ============================================================================
# TARGET CALCULATION
# ============================================================================

func calculate_target_for_agent(agent_data: AgentData, grid: HexGrid) -> Dictionary:
	"""
	Calculate target camera position and zoom for an agent.

	Args:
		agent_data: The agent to focus on
		grid: The hex grid (for bounds calculation)

	Returns:
		Dictionary with keys:
			- position: Vector2 target camera position
			- zoom: float target zoom level
	"""
	if not agent_data:
		return {
			"position": Vector2.ZERO,
			"zoom": CameraTypes.DEFAULT_ZOOM
		}

	# Target camera at agent's LIVE position (always read from controller for accuracy)
	var target_position = agent_data.current_position
	if agent_data.agent_controller:
		target_position = agent_data.agent_controller.global_position

	# Calculate zoom if bounds calculator is available
	var target_zoom = CameraTypes.DEFAULT_ZOOM
	if bounds_calculator:
		target_zoom = bounds_calculator.calculate_zoom_for_agent_range(agent_data)

	return {
		"position": target_position,
		"zoom": target_zoom
	}

func should_skip_transition(
	current_position: Vector2,
	target_position: Vector2,
	current_zoom: float,
	target_zoom: float
) -> bool:
	"""
	Determine if transition should be skipped (already at target).

	Args:
		current_position: Current camera position
		target_position: Desired camera position
		current_zoom: Current zoom level
		target_zoom: Desired zoom level

	Returns:
		true if already close enough to skip transition
	"""
	var position_delta = current_position.distance_to(target_position)
	var zoom_delta = abs(current_zoom - target_zoom)

	return (
		position_delta < CameraTypes.SKIP_TRANSITION_DISTANCE_THRESHOLD and
		zoom_delta < CameraTypes.SKIP_TRANSITION_ZOOM_THRESHOLD
	)
