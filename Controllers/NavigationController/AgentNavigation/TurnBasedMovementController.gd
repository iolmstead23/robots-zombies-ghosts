extends Node
class_name TurnBasedMovementController

"""
Manages turn-based movement execution with preview and confirmation.

Design notes:
- Public API functions are grouped under "Public API" and alphabetized.
- Godot callbacks are grouped and alphabetized.
- Internal helpers are alphabetized.
- Signal handlers are grouped and alphabetized.
- All names use snake_case. Member variables are declared at file top and typed where applicable.
"""

# ----------------------
# Constants & config
# ----------------------
const PIXELS_PER_FOOT: float = 32.0
const ARRIVAL_DISTANCE_PIXELS: float = 5.0
const TARGET_POINT_THRESHOLD_PIXELS: float = 1.0
const NEAR_FINISH_PROGRESS: float = 0.99
const PROGRESS_BUMP_ON_POINT_REACHED: float = 0.05
const DEBUG: bool = false

# ----------------------
# Enums
# ----------------------
enum TurnState {
	IDLE,
	PLANNING,
	PREVIEW,
	AWAITING_CONFIRMATION,
	EXECUTING,
	COMPLETED
}

# ----------------------
# Signals
# ----------------------
signal turn_started(turn_number: int)
signal movement_started()
signal movement_completed(distance_moved: float)
signal turn_ended(turn_number: int)

# ----------------------
# Member variables (state & components)
# ----------------------
var current_state: int = TurnState.IDLE
var current_turn: int = 0

var movement_progress: float = 0.0
var movement_speed: float = 400.0  # pixels / second during execution
var movement_used_this_turn: float = 0.0

var current_path_index: int = 0

# Components - set by initialize()
var pathfinder: TurnBasedPathfinder = null
var player: CharacterBody2D = null
var movement_component: MovementComponent = null
var state_manager: StateManager = null

# UI elements (created in _setup_ui)
var path_preview_line: Line2D = null
var distance_label: Label = null
var confirm_button: Button = null
var cancel_button: Button = null

var is_active: bool = false  # Track if turn-based mode is active

# ----------------------
# Godot callbacks (alphabetized)
# ----------------------
func _physics_process(delta: float) -> void:
	"""Physics loop; runs movement execution when in EXECUTING state."""
	if not is_active or current_state != TurnState.EXECUTING:
		return

	if pathfinder == null or pathfinder.current_path == null or pathfinder.current_path.is_empty():
		push_error("TurnBasedMovementController: Executing with empty or missing path!")
		_complete_movement()
		return

	# Update progress (based on speed & total path distance)
	_update_movement_progress(delta)

	# Compute movement direction toward the current target position
	var target_pos: Vector2 = pathfinder.get_next_position(movement_progress)
	var current_pos: Vector2 = player.global_position
	var direction: Vector2 = _compute_direction_to_target(current_pos, target_pos)

	# Debugging info periodically
	if DEBUG and Engine.get_physics_frames() % 30 == 0:
		var final_destination: Vector2 = pathfinder.current_path[-1]
		print("Movement progress: %.2f%% | Current: %s | Target: %s | Final: %s" % [
			movement_progress * 100,
			current_pos,
			target_pos,
			final_destination
		])

	# Check if we've reached the final destination
	var distance_to_final: float = current_pos.distance_to(pathfinder.current_path[-1])
	if distance_to_final <= ARRIVAL_DISTANCE_PIXELS or movement_progress >= NEAR_FINISH_PROGRESS:
		# Snap to destination and complete
		player.global_position = pathfinder.current_path[-1]
		_complete_movement()
		return

	# If direction is zero (very close to target), bump progress and recompute
	if direction.length() <= 0.0:
		movement_progress = min(movement_progress + PROGRESS_BUMP_ON_POINT_REACHED, 1.0)
		target_pos = pathfinder.get_next_position(movement_progress)
		direction = _compute_direction_to_target(current_pos, target_pos)

	# Update animation & state
	_update_animation_and_state(direction)

	# Move the player
	player.velocity = direction * movement_speed
	player.move_and_slide()

	# Allow player to update animation if they expose a controller API
	if player.has_method("animation_controller"):
		player.animation_controller.update_animation()


func _unhandled_input(event: InputEvent) -> void:
	"""Handle input when turn-based mode is active (mouse clicks and confirm/cancel)."""
	if not is_active:
		return

	# NOTE: Mouse click handling disabled - main.gd controls movement via IOController
	# This prevents duplicate handling of the same click event
	# # Left click to request movement when idle
	# if current_state == TurnState.IDLE:
	# 	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
	# 		var click_pos: Vector2 = get_viewport().get_mouse_position()
	# 		if DEBUG:
	# 			print("Turn-based: Requesting movement to ", click_pos)
	# 		request_movement_to(click_pos)
	# 		get_viewport().set_input_as_handled()
	# 		return

	# Confirmation / cancellation while awaiting confirmation
	if current_state == TurnState.AWAITING_CONFIRMATION:
		if event.is_action_pressed("ui_accept"):  # Space or Enter
			confirm_movement()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):  # Escape
			cancel_movement()
			get_viewport().set_input_as_handled()
			return
		# NOTE: Mouse click auto-confirmation disabled - main.gd now controls confirmation flow
		# This allows distance validation before confirming movements
		# if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 	confirm_movement()
		# 	get_viewport().set_input_as_handled()
		# 	return

# ----------------------
# Public API (alphabetized)
# ----------------------
func activate() -> void:
	"""Activate turn-based mode (enable input & physics processing)."""
	is_active = true
	set_physics_process(true)
	set_process_unhandled_input(true)
	start_new_turn()
	if DEBUG:
		print("Turn-based mode activated")


func cancel_movement() -> void:
	"""Cancel the currently planned movement (only valid in AWAITING_CONFIRMATION)."""
	if current_state != TurnState.AWAITING_CONFIRMATION:
		return

	if DEBUG:
		print("Movement cancelled")
	if pathfinder != null:
		pathfinder.cancel_path()

	current_state = TurnState.IDLE
	if path_preview_line != null:
		path_preview_line.clear_points()


func confirm_movement() -> void:
	"""Confirm the planned movement and start execution (only valid in AWAITING_CONFIRMATION)."""
	if current_state != TurnState.AWAITING_CONFIRMATION or not is_active:
		return

	if DEBUG:
		print("Movement confirmed - executing")
	if pathfinder != null:
		pathfinder.confirm_path()

	current_state = TurnState.EXECUTING
	movement_progress = 0.0
	current_path_index = 0

	# Hide preview
	if path_preview_line != null:
		path_preview_line.clear_points()

	# Emit movement started
	movement_started.emit()

	# Disable player's normal input if supported
	if player != null and player.has_method("set_movement_mode"):
		player.set_movement_mode("none")  # expect a "none" mode to exist externally


func deactivate() -> void:
	"""Deactivate turn-based mode (disable input & physics)."""
	is_active = false
	set_physics_process(false)
	set_process_unhandled_input(false)

	if path_preview_line != null:
		path_preview_line.clear_points()

	current_state = TurnState.IDLE
	if DEBUG:
		print("Turn-based mode deactivated")


func end_turn() -> void:
	"""End the current turn and emit the turn_ended signal."""
	if not is_active:
		return

	current_state = TurnState.IDLE
	turn_ended.emit(current_turn)
	if DEBUG:
		print("Turn %d ended" % current_turn)

	# Reset per-turn movement usage for the next turn
	movement_used_this_turn = 0.0


func initialize(player_ref: CharacterBody2D, movement_ref: MovementComponent, state_ref: StateManager, hex_grid: HexGrid = null, hex_pathfinder: HexPathfinder = null) -> void:
	"""
	Initialize controller with the player and related components.

	This:
	- stores references to player, movement_component, state_manager
	- creates and initializes the pathfinder (child node)
	- connects pathfinder signals
	- sets up UI elements
	- disables processing by default
	"""
	player = player_ref
	movement_component = movement_ref
	state_manager = state_ref

	# Create & initialize pathfinder
	if pathfinder == null:
		pathfinder = TurnBasedPathfinder.new()
		add_child(pathfinder)

	# Initialize pathfinder with player only
	pathfinder.initialize(player)

	# Set hex components if provided
	if hex_grid and hex_pathfinder:
		pathfinder.set_hex_components(hex_grid, hex_pathfinder)

	# Connect signals (use safe connecting)
	if not pathfinder.path_calculated.is_connected(_on_path_calculated):
		pathfinder.path_calculated.connect(_on_path_calculated)
	if not pathfinder.path_confirmed.is_connected(_on_path_confirmed):
		pathfinder.path_confirmed.connect(_on_path_confirmed)
	if not pathfinder.path_cancelled.is_connected(_on_path_cancelled):
		pathfinder.path_cancelled.connect(_on_path_cancelled)

	# UI setup
	_setup_ui()

	# Start disabled
	set_physics_process(false)
	set_process_unhandled_input(false)

func set_hex_components(hex_grid: HexGrid, hex_pathfinder: HexPathfinder) -> void:
	"""Set hex components after initialization"""
	if pathfinder:
		pathfinder.set_hex_components(hex_grid, hex_pathfinder)
		print("TurnBasedMovementController: Hex components set")


func request_movement_to(destination: Vector2) -> void:
	"""
	Request movement to a destination.
	- Validates remaining movement distance.
	- Asks pathfinder to calculate a path.
	- Shows preview and waits for confirmation if path successful.
	"""
	if current_state != TurnState.IDLE or not is_active:
		if DEBUG:
			print("Cannot request movement - state: ", current_state, " active: ", is_active)
		return

	current_state = TurnState.PLANNING

	# Calculate remaining movement allowed this turn
	var remaining_movement: float = pathfinder.MAX_MOVEMENT_DISTANCE - movement_used_this_turn
	if remaining_movement <= 0.0:
		if DEBUG:
			print("No movement remaining this turn")
		current_state = TurnState.IDLE
		return

	if DEBUG:
		print("Calculating path to ", destination)

	# Ask pathfinder to calculate (assumes method returns bool and populates path_segments & total_path_distance)
	var found_path: bool = false
	if pathfinder != null:
		found_path = pathfinder.calculate_path_to(destination)

	if found_path:
		current_state = TurnState.AWAITING_CONFIRMATION
		_show_path_preview()
		if DEBUG:
			print("Path calculated - awaiting confirmation (press SPACE or click again to confirm, ESC to cancel)")
	else:
		if DEBUG:
			print("No valid path found")
		current_state = TurnState.IDLE


func start_new_turn() -> void:
	"""Begin a new movement turn (reset per-turn counters and emit turn_started)."""
	if not is_active:
		return

	current_turn += 1
	movement_used_this_turn = 0.0
	current_state = TurnState.IDLE
	turn_started.emit(current_turn)
	if DEBUG:
		print("Turn %d started - Ready for input" % current_turn)

# ----------------------
# Internal helpers (alphabetized)
# ----------------------
func _compute_direction_to_target(current_pos: Vector2, target_pos: Vector2) -> Vector2:
	"""
	Compute the unit direction from current_pos toward target_pos.
	Returns Vector2.ZERO if the target is very close.
	"""
	var dist: float = current_pos.distance_to(target_pos)
	if dist <= TARGET_POINT_THRESHOLD_PIXELS:
		return Vector2.ZERO
	return (target_pos - current_pos).normalized()


func _complete_movement() -> void:
	"""Complete the current movement: finalize values, emit signals, and decide whether to end turn."""
	if not is_active:
		return

	# Accumulate movement used in pixels
	if pathfinder != null:
		movement_used_this_turn += pathfinder.total_path_distance

	if DEBUG:
		print("Movement complete - moved %.1f feet" % ((pathfinder.total_path_distance) / PIXELS_PER_FOOT))

	# Update state manager
	if state_manager != null:
		state_manager.set_state_value("is_moving", false)
		state_manager.set_state_value("has_input", false)

	current_state = TurnState.COMPLETED
	movement_completed.emit(pathfinder.total_path_distance)

	# Clear pathfinder internal state
	if pathfinder != null:
		pathfinder.cancel_path()

	# Decide whether turn ends or allows more movement
	if movement_used_this_turn >= pathfinder.MAX_MOVEMENT_DISTANCE * 0.95:
		end_turn()
	else:
		current_state = TurnState.IDLE
		if DEBUG:
			print("%.1f feet of movement remaining this turn" % ((pathfinder.MAX_MOVEMENT_DISTANCE - movement_used_this_turn) / PIXELS_PER_FOOT))


func _show_path_preview() -> void:
	"""Display the calculated path using Line2D and update distance label if present."""
	if path_preview_line == null or player == null or pathfinder == null:
		return

	path_preview_line.clear_points()

	var points := PackedVector2Array()

	# Check if parent is a Node2D (required for to_local)
	var parent = player.get_parent()
	var use_local_coords = parent is Node2D

	if use_local_coords:
		points.append(parent.to_local(player.global_position))
	else:
		# Parent is not Node2D, use global coordinates directly
		points.append(player.global_position)

	# Add points from pathfinder.path_segments (assumes segments are arrays of global Vector2s)
	for segment in pathfinder.path_segments:
		for point in segment:
			if use_local_coords:
				points.append(parent.to_local(point))
			else:
				points.append(point)

	path_preview_line.points = points

	# Update distance label if present
	if distance_label != null:
		distance_label.text = "Distance: %.1f ft" % (pathfinder.total_path_distance / PIXELS_PER_FOOT)

	if DEBUG:
		print("Preview showing %.1f feet of movement" % (pathfinder.total_path_distance / PIXELS_PER_FOOT))


func _setup_ui() -> void:
	"""Create minimal UI (Line2D) for path preview. Buttons/labels are placeholders — attach them in your scene if desired."""
	# Create path preview line if missing
	if path_preview_line == null:
		path_preview_line = Line2D.new()
		path_preview_line.name = "PathPreviewLine"
		path_preview_line.width = 4.0
		path_preview_line.default_color = Color(0.0, 1.0, 1.0, 0.8)  # Bright cyan with some transparency
		path_preview_line.z_index = 100  # Draw on top
		path_preview_line.points = PackedVector2Array()
		# Add to scene root for visibility (works for both robot and multi-agent modes)
		if player != null:
			var scene_root = player.get_tree().root.get_child(player.get_tree().root.get_child_count() - 1)
			if scene_root:
				scene_root.call_deferred("add_child", path_preview_line)
			else:
				call_deferred("add_child", path_preview_line)
		else:
			# Fallback: add to this controller node if player not ready yet
			call_deferred("add_child", path_preview_line)

	# Note: distance_label, confirm_button, cancel_button are intentionally left null by default.
	# If you want visible UI, create and assign them externally or add creation logic here.


func _update_animation_and_state(direction: Vector2) -> void:
	"""
	Update facing direction and movement flags in state_manager and trigger player animations.
	Separation keeps animation / state logic out of the physics loop directly.
	"""
	if state_manager == null:
		return

	if direction.length() > 0.1:
		var direction_name: String = DirectionHelper.vector_to_direction_name(direction)
		state_manager.set_state_value("facing_direction", direction_name)
		state_manager.set_state_value("is_moving", true)
		state_manager.set_state_value("has_input", true)
	else:
		state_manager.set_state_value("is_moving", false)
		state_manager.set_state_value("has_input", false)


func _update_movement_progress(delta: float) -> void:
	"""
	Update movement_progress based on movement_speed and total path distance.
	This converts per-frame pixel movement into a normalized progress 0..1 along total_path_distance.
	"""
	if pathfinder == null or pathfinder.total_path_distance <= 0.0:
		return

	var distance_this_frame: float = movement_speed * delta
	var progress_increment: float = distance_this_frame / pathfinder.total_path_distance
	movement_progress = min(movement_progress + progress_increment, 1.0)

# ----------------------
# Signal handlers (alphabetized)
# ----------------------
func _on_path_calculated(segments: Array, distance: float) -> void:
	"""Handler called by the pathfinder when a path has been calculated."""
	if DEBUG:
		print("Path calculated with %d segments, total distance: %.1f pixels (%.1f feet)" % [
			segments.size(),
			distance,
			distance / PIXELS_PER_FOOT
		])


func _on_path_cancelled() -> void:
	"""Handler called by the pathfinder when a path is cancelled."""
	if DEBUG:
		print("Path cancelled")


func _on_path_confirmed() -> void:
	"""Handler called by the pathfinder when a path is confirmed for execution."""
	if DEBUG:
		print("Path confirmed for execution")
