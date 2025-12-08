extends Node
class_name TurnBasedPathfinder

# Turn-based pathfinder using hex grid navigation
# Refactored to use Core components for better organization and reusability.

signal path_calculated(segments: Array, total_distance: int)
signal path_confirmed()
signal path_cancelled()

# Path data
var current_path: Array[Vector2] = []
var path_segments: Array[Array] = []
var total_path_distance: int = 0
var is_path_valid: bool = false
var current_hex_path: Array[HexCell] = []

# Visualization
var preview_path: Array[Vector2] = []
var preview_color: Color = Color.CYAN
var confirmed_color: Color = Color.GREEN

# References
var player: CharacterBody2D
var hex_grid: HexGrid
var hex_pathfinder: HexPathfinder

# Path smoothing components
var _path_interpolator: PathInterpolator = PathInterpolator.new()
var _string_pull_validator: StringPullValidator = StringPullValidator.new()
var _catmull_rom_smoother: CatmullRomSmoother = CatmullRomSmoother.new()

# Midpoint interpolation settings
var interpolation_layers: int = 1  # 1-3 layers

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(player_ref: CharacterBody2D, grid: HexGrid = null, hex_pathfinder_ref: HexPathfinder = null) -> void:
	player = player_ref
	hex_grid = grid
	hex_pathfinder = hex_pathfinder_ref

	# Initialize smoothing components
	_catmull_rom_smoother.set_smoothing_iterations(3)  # Moderate smoothing - 3 segments per edge

	# Components may be deferred - will be set via set_hex_components()
	# Validation happens in _validate_components() when pathfinding is attempted

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Initialized")

func set_hex_components(grid: HexGrid, hex_pathfinder_ref: HexPathfinder) -> void:
	hex_grid = grid
	hex_pathfinder = hex_pathfinder_ref

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Hex components set")

# ============================================================================
# PATH CALCULATION
# ============================================================================

func calculate_path_to(destination: Vector2, max_distance: int = -1) -> bool:
	# Calculate a path to the destination
	#
	# Args:
	#   destination: Target world position
	#   max_distance: Maximum distance in meters (if -1, uses MovementConstants.MAX_MOVEMENT_DISTANCE)
	if not _validate_components():
		return false

	_reset_path_data()

	var start_cell := hex_grid.get_cell_at_world_position(player.global_position)
	var dest_cell := hex_grid.get_cell_at_world_position(destination)

	if not PathValidator.are_cells_valid(start_cell, dest_cell):
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Invalid start or destination cell")
		return false

	current_hex_path = hex_pathfinder.find_path(start_cell, dest_cell)

	if current_hex_path.is_empty():
		_log_path_failure()
		return false

	# Use provided max_distance, or fall back to constant
	var distance_limit := max_distance if max_distance >= 0 else MovementConstants.MAX_MOVEMENT_DISTANCE
	_process_hex_path(distance_limit)
	_log_path_success()

	path_calculated.emit(path_segments, total_path_distance)
	return is_path_valid

# ============================================================================
# PATH MANAGEMENT
# ============================================================================

func cancel_path() -> void:
	_reset_path_data()
	preview_path.clear()
	path_cancelled.emit()

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Path cancelled")

func confirm_path() -> void:
	if is_path_valid:
		path_confirmed.emit()
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Path confirmed (%d waypoints)" % current_path.size())
	else:
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Cannot confirm invalid path")

func get_next_position(progress: float) -> Vector2:
	if current_path.is_empty():
		return player.global_position if player else Vector2.ZERO

	# Use Core interpolation utility
	return InterpolationUtils.get_position_at_progress(current_path, progress)

func get_hex_path() -> Array[HexCell]:
	return current_hex_path

# ============================================================================
# INTERNAL - VALIDATION
# ============================================================================

func _validate_components() -> bool:
	var valid = hex_grid != null and hex_pathfinder != null and player != null

	if not valid and OS.is_debug_build():
		# Provide specific warnings about what's missing
		if not hex_grid:
			push_warning("TurnBasedPathfinder: Attempted pathfinding without HexGrid")
		if not hex_pathfinder:
			push_warning("TurnBasedPathfinder: Attempted pathfinding without HexPathfinder")
		if not player:
			push_warning("TurnBasedPathfinder: Attempted pathfinding without player reference")

	return valid

# ============================================================================
# INTERNAL - PATH PROCESSING
# ============================================================================

func _reset_path_data() -> void:
	current_path.clear()
	current_hex_path.clear()
	path_segments.clear()
	total_path_distance = 0
	is_path_valid = false

func _process_hex_path(distance_limit: int) -> void:
	_convert_hex_to_world()
	_calculate_distance()

	# Distance is measured in hex cells (each cell = 1 meter)
	var path_length_meters = current_hex_path.size() - 1 # Subtract 1 because first cell is current position

	if path_length_meters > distance_limit:
		_trim_to_max_distance(distance_limit)

	_generate_segments()
	is_path_valid = not current_path.is_empty()

func _convert_hex_to_world() -> void:
	current_path.clear()

	# Generate smooth waypoints using new refactored classes
	if current_hex_path.size() > 0:
		var hex_size_value := 32.0
		if hex_grid:
			hex_size_value = hex_grid.hex_size

		# Step 1: Generate waypoints from path
		var waypoints := _path_interpolator.generate_path_waypoints(current_hex_path, 0.5)

		# Step 2: Apply midpoint interpolation
		var interpolated := _path_interpolator.generate_midpoint_interpolation(waypoints, interpolation_layers)

		# Step 3: Apply string pulling to tighten the path
		_string_pull_validator.set_hex_size(hex_size_value)
		var pulled := _string_pull_validator.pull_string_through_path(interpolated, current_hex_path)

		# Step 4: Apply final smoothing
		var smooth_waypoints := _catmull_rom_smoother.smooth_curve(pulled, false)  # false = open path

		for waypoint in smooth_waypoints:
			current_path.append(waypoint)
	else:
		# Empty path
		pass

func _calculate_distance() -> void:
	# Distance is measured in hex cells (each cell = 1 meter)
	# Subtract 1 because the first cell is the current position
	total_path_distance = current_hex_path.size() - 1

func _trim_to_max_distance(max_meters: int) -> void:
	# Trim hex path to max_meters hex cells (plus 1 for starting cell)
	var max_cells = max_meters + 1 # +1 because first cell is current position

	if current_hex_path.size() > max_cells:
		current_hex_path = current_hex_path.slice(0, max_cells)

	# Update world path to match
	_convert_hex_to_world()
	_calculate_distance()

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Trimmed to %d m (%d hex cells)" % [max_meters, current_hex_path.size() - 1])

func _generate_segments() -> void:
	path_segments.clear()
	if current_path.size() >= 2:
		path_segments.append(current_path.duplicate())

# ============================================================================
# INTERNAL - LOGGING
# ============================================================================

func _log_path_failure() -> void:
	if OS.is_debug_build():
		print("TurnBasedPathfinder: No path found")

func _log_path_success() -> void:
	if OS.is_debug_build():
		print("TurnBasedPathfinder: Path found - %d waypoints, %d m (%d hex cells)" % [
			current_path.size(),
			total_path_distance,
			total_path_distance
		])

# ============================================================================
# INTERPOLATION LAYER CONTROL
# ============================================================================

func set_interpolation_layers(layers: int) -> void:
	# Set midpoint interpolation layers (1-3) for path smoothing
	interpolation_layers = clampi(layers, 1, 3)
	# Interpolation layers is now used directly by PathInterpolator in _convert_hex_to_world()

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Interpolation layers set to: %d" % interpolation_layers)


func get_interpolation_layers() -> int:
	return interpolation_layers
