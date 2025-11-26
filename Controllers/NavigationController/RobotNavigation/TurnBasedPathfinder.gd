extends Node
class_name TurnBasedPathfinder

## Turn-based pathfinder using hex grid navigation

const MAX_MOVEMENT_DISTANCE: float = 20.0 * 32.0  # 20 ft in pixels

signal path_calculated(segments: Array, total_distance: float)
signal path_confirmed()
signal path_cancelled()

# Path data
var current_path: Array[Vector2] = []
var path_segments: Array[Array] = []
var total_path_distance: float = 0.0
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

func initialize(player_ref: CharacterBody2D, grid: HexGrid = null, hex_pathfinder_ref: HexPathfinder = null) -> void:
	player = player_ref
	hex_grid = grid
	hex_pathfinder = hex_pathfinder_ref

	if not hex_grid and OS.is_debug_build():
		push_warning("TurnBasedPathfinder: HexGrid not provided")
	if not hex_pathfinder and OS.is_debug_build():
		push_warning("TurnBasedPathfinder: HexPathfinder not provided")

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Initialized")

func set_hex_components(grid: HexGrid, hex_pathfinder_ref: HexPathfinder) -> void:
	hex_grid = grid
	hex_pathfinder = hex_pathfinder_ref

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Hex components set")

func calculate_path_to(destination: Vector2) -> bool:
	if not _validate_components():
		return false

	_reset_path_data()

	var start_cell := hex_grid.get_cell_at_world_position(player.global_position)
	var dest_cell := hex_grid.get_cell_at_world_position(destination)

	if not _validate_cells(start_cell, dest_cell):
		return false

	current_hex_path = hex_pathfinder.find_path(start_cell, dest_cell)

	if current_hex_path.is_empty():
		_log_path_failure()
		return false

	_process_hex_path()
	_log_path_success()

	path_calculated.emit(path_segments, total_path_distance)
	return is_path_valid

func _validate_components() -> bool:
	if not hex_grid or not hex_pathfinder or not player:
		if OS.is_debug_build():
			push_error("TurnBasedPathfinder: Missing components")
		return false
	return true

func _validate_cells(start_cell: HexCell, dest_cell: HexCell) -> bool:
	if not start_cell:
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Start not on grid")
		return false

	if not dest_cell:
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Destination not on grid")
		return false

	if not dest_cell.enabled:
		if OS.is_debug_build():
			print("TurnBasedPathfinder: Destination disabled")
		return false

	return true

func _reset_path_data() -> void:
	current_path.clear()
	current_hex_path.clear()
	path_segments.clear()
	total_path_distance = 0.0
	is_path_valid = false

func _process_hex_path() -> void:
	_convert_hex_to_world()
	_calculate_distance()

	if total_path_distance > MAX_MOVEMENT_DISTANCE:
		_trim_to_max_distance()

	_generate_segments()
	is_path_valid = not current_path.is_empty()

func _convert_hex_to_world() -> void:
	current_path.clear()
	for cell in current_hex_path:
		current_path.append(cell.world_position)

func _calculate_distance() -> void:
	total_path_distance = 0.0
	for i in range(1, current_path.size()):
		total_path_distance += current_path[i - 1].distance_to(current_path[i])

func _trim_to_max_distance() -> void:
	var accumulated := 0.0
	var trimmed_path: Array[Vector2] = []
	var trimmed_hex: Array[HexCell] = []

	for i in range(current_path.size()):
		if i > 0:
			var seg_dist := current_path[i - 1].distance_to(current_path[i])

			if accumulated + seg_dist > MAX_MOVEMENT_DISTANCE:
				var remaining := MAX_MOVEMENT_DISTANCE - accumulated
				var t := remaining / seg_dist
				var final_point := current_path[i - 1].lerp(current_path[i], clamp(t, 0.0, 1.0))
				trimmed_path.append(final_point)
				accumulated = MAX_MOVEMENT_DISTANCE
				break

			accumulated += seg_dist

		trimmed_path.append(current_path[i])
		if i < current_hex_path.size():
			trimmed_hex.append(current_hex_path[i])

		if accumulated >= MAX_MOVEMENT_DISTANCE:
			break

	current_path = trimmed_path
	current_hex_path = trimmed_hex
	total_path_distance = min(accumulated, MAX_MOVEMENT_DISTANCE)

	if OS.is_debug_build():
		print("TurnBasedPathfinder: Trimmed to %.1f ft" % (total_path_distance / 32.0))

func _generate_segments() -> void:
	path_segments.clear()
	if current_path.size() >= 2:
		path_segments.append(current_path.duplicate())

func _log_path_failure() -> void:
	if OS.is_debug_build():
		print("TurnBasedPathfinder: No path found")

func _log_path_success() -> void:
	if OS.is_debug_build():
		print("TurnBasedPathfinder: Path found - %d waypoints, %.1f ft" % [
			current_path.size(), total_path_distance / 32.0
		])

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

	progress = clamp(progress, 0.0, 1.0)

	if progress == 0.0:
		return current_path[0]
	if progress >= 1.0:
		return current_path[-1]

	var target_distance := total_path_distance * progress
	var accumulated := 0.0

	for i in range(1, current_path.size()):
		var seg_dist := current_path[i - 1].distance_to(current_path[i])

		if accumulated + seg_dist >= target_distance:
			var remaining := target_distance - accumulated
			var t := remaining / seg_dist if seg_dist > 0.0 else 0.0
			return current_path[i - 1].lerp(current_path[i], clamp(t, 0.0, 1.0))

		accumulated += seg_dist

	return current_path[-1]

func get_hex_path() -> Array[HexCell]:
	return current_hex_path
