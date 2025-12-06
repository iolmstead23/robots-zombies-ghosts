class_name CameraBoundsCalculator
extends RefCounted

## Calculates camera viewport bounds and zoom levels
## Handles zoom calculation to fit agent movement range on screen
## Manages camera bounds to prevent showing void at map edges

# ============================================================================
# DEPENDENCIES
# ============================================================================

var _viewport: Viewport = null

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_viewport(viewport: Viewport) -> void:
	"""Set the viewport for size calculations"""
	_viewport = viewport

# ============================================================================
# ZOOM CALCULATION
# ============================================================================

func calculate_zoom_for_agent_range(
	agent_data: AgentData,
	buffer_multiplier: float = 1.5
) -> float:
	"""
	Calculate optimal zoom level to show agent's full movement range.

	Args:
		agent_data: The agent whose movement range to display
		buffer_multiplier: Multiplier for showing extra context (1.5 = 150%)

	Returns:
		Zoom level that fits agent's range on screen

	Example:
		Agent with 10-meter range on 1920x1080 screen:
		- Range: 320 pixels (10 * 32px)
		- Buffered radius: 480 pixels (320 * 1.5)
		- Required diameter: 960 pixels
		- Calculated zoom: 1.125 (fits 960px content in 1080px height)
	"""
	if not _viewport or not agent_data:
		return CameraTypes.DEFAULT_ZOOM

	# Get agent's maximum movement range in meters (hex cells)
	var max_distance = agent_data.max_distance_per_turn  # e.g., 10 meters

	# Convert to pixels (each hex = 32 pixels = 1 meter)
	var range_pixels = max_distance * CameraTypes.PIXELS_PER_METER

	# Apply buffer (show 1.5x the range for context)
	var required_radius_pixels = range_pixels * buffer_multiplier

	# Calculate required viewport dimensions (diameter = 2 * radius)
	var required_width_pixels = required_radius_pixels * 2.0
	var required_height_pixels = required_radius_pixels * 2.0

	# Get current viewport size
	var viewport_size = _viewport.get_visible_rect().size

	# Calculate zoom to fit the required area
	# zoom = viewport_pixels / required_world_pixels
	var zoom_for_width = viewport_size.x / required_width_pixels
	var zoom_for_height = viewport_size.y / required_height_pixels

	# Use smaller zoom to ensure everything fits
	var calculated_zoom = min(zoom_for_width, zoom_for_height)

	# Clamp to reasonable limits
	calculated_zoom = clamp(calculated_zoom, CameraTypes.MIN_ZOOM, CameraTypes.MAX_ZOOM)

	return calculated_zoom

func get_viewport_size_in_world_space(zoom: float) -> Vector2:
	"""
	Calculate world-space size of viewport at given zoom level.

	Args:
		zoom: Current zoom level

	Returns:
		Vector2 representing viewport size in world pixels
	"""
	if not _viewport:
		return Vector2.ZERO

	var viewport_pixels = _viewport.get_visible_rect().size
	return viewport_pixels / zoom

# ============================================================================
# CAMERA BOUNDS CALCULATION
# ============================================================================

func calculate_camera_bounds(grid: HexGrid, padding: float = 200.0) -> Rect2:
	"""
	Calculate world-space bounds for camera movement.
	Prevents camera from showing void at grid edges.

	Args:
		grid: The hex grid to calculate bounds from
		padding: Extra pixels around grid edges

	Returns:
		Rect2 representing allowed camera area
	"""
	if not grid or grid.enabled_cells.is_empty():
		return Rect2()

	# Find extremes of the grid
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF

	for cell in grid.enabled_cells:
		min_x = min(min_x, cell.world_position.x)
		min_y = min(min_y, cell.world_position.y)
		max_x = max(max_x, cell.world_position.x)
		max_y = max(max_y, cell.world_position.y)

	# Apply padding
	min_x -= padding
	min_y -= padding
	max_x += padding
	max_y += padding

	# Create bounds rect
	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)

func apply_bounds_to_position(position: Vector2, zoom: float, bounds: Rect2) -> Vector2:
	"""
	Clamp camera position to keep viewport within bounds.

	Args:
		position: Desired camera position
		zoom: Current zoom level
		bounds: Camera movement bounds

	Returns:
		Clamped position that stays within bounds
	"""
	if not bounds.has_area():
		return position

	# Calculate viewport size at current zoom
	var viewport_world_size = get_viewport_size_in_world_space(zoom)
	var half_viewport = viewport_world_size * 0.5

	# Clamp camera position to keep viewport within bounds
	var clamped_x = clamp(
		position.x,
		bounds.position.x + half_viewport.x,
		bounds.position.x + bounds.size.x - half_viewport.x
	)
	var clamped_y = clamp(
		position.y,
		bounds.position.y + half_viewport.y,
		bounds.position.y + bounds.size.y - half_viewport.y
	)

	return Vector2(clamped_x, clamped_y)

func calculate_viewport_bounds_for_agent(agent_data: AgentData) -> Rect2:
	"""
	Calculate viewport area needed for an agent's movement range.

	Args:
		agent_data: The agent to calculate bounds for

	Returns:
		Rect2 representing required viewport area
	"""
	if not agent_data:
		return Rect2()

	var agent_position = agent_data.current_position
	var max_reach_meters = agent_data.max_distance_per_turn
	var max_reach_pixels = max_reach_meters * CameraTypes.PIXELS_PER_METER

	# Add buffer
	var viewport_radius = max_reach_pixels * 1.5

	return Rect2(
		agent_position - Vector2(viewport_radius, viewport_radius),
		Vector2(viewport_radius * 2, viewport_radius * 2)
	)
