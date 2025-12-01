extends Node
class_name TurnBasedMovementController

"""
Manages turn-based movement execution with preview and confirmation.

STATUS: ACTIVE - This is the primary navigation system for the game
Turn-based movement is currently active and handles all agent navigation.
Real-time navigation (HexAgentNavigator, NavAgent2DFollower) is disabled but preserved.

FEATURES:
- Turn-based movement with action point system
- Path preview with distance calculation
- Movement confirmation before execution
- Integrates with hex grid pathfinding
- Smooth movement execution along calculated paths

Refactored to use Core components for better organization and reusability.

Design notes:
- Public API functions are grouped under "Public API" and alphabetized.
- Godot callbacks are grouped and alphabetized.
- Internal helpers are alphabetized.
- Signal handlers are grouped and alphabetized.
- All names use snake_case. Member variables are declared at file top and typed where applicable.
"""

# ----------------------
# Signals
# ----------------------
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal movement_started()
signal movement_completed(distance_moved: int)

# ----------------------
# Member variables (state & components)
# ----------------------
var movement_used_this_turn: int = 0

# Components - set by initialize()
var pathfinder: TurnBasedPathfinder = null
var player: CharacterBody2D = null
var movement_component: MovementComponent = null
var state_manager: StateManager = null

# Core components
var _turn_state: TurnStateMachine = null
var _movement_executor: MovementExecutor = null
var _progress_tracker: ProgressTracker = null

# UI elements (created in _setup_ui)
var path_preview_line: Line2D = null
var distance_label: Label = null
var confirm_button: Button = null
var cancel_button: Button = null

var is_active: bool = false # Track if turn-based mode is active

const DEBUG: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Initialize Core components
	_turn_state = TurnStateMachine.new()
	_movement_executor = MovementExecutor.new()
	_progress_tracker = ProgressTracker.new()

	add_child(_turn_state)
	add_child(_movement_executor)
	add_child(_progress_tracker)

	# Connect turn state signals to forward them
	_turn_state.turn_ended.connect(_on_turn_state_ended)

	# Configure movement executor
	_movement_executor.movement_speed = MovementConstants.DEFAULT_MOVEMENT_SPEED

	# Start disabled
	set_physics_process(false)
	set_process_unhandled_input(false)

# ============================================================================
# GODOT CALLBACKS
# ============================================================================

func _physics_process(delta: float) -> void:
	"""Physics loop; runs movement execution when in EXECUTING state."""
	if not is_active or not _turn_state.is_executing():
		return

	if pathfinder == null or pathfinder.current_path == null or pathfinder.current_path.is_empty():
		push_error("TurnBasedMovementController: Executing with empty or missing path!")
		_complete_movement()
		return

	# Update progress using Core progress tracker
	_progress_tracker.update_from_movement(_movement_executor.movement_speed, delta)

	# Compute movement direction toward the current target position
	var target_pos: Vector2 = pathfinder.get_next_position(_progress_tracker.get_progress())
	var current_pos: Vector2 = player.global_position
	var direction: Vector2 = DirectionUtils.direction_to_with_threshold(
		current_pos,
		target_pos,
		MovementConstants.TARGET_POINT_THRESHOLD_PIXELS
	)

	# Debugging info periodically
	if DEBUG and Engine.get_physics_frames() % 30 == 0:
		var final_destination: Vector2 = pathfinder.current_path[-1]
		print("Movement progress: %.2f%% | Current: %s | Target: %s | Final: %s" % [
			_progress_tracker.get_progress() * 100,
			current_pos,
			target_pos,
			final_destination
		])

	# Check if we've reached the final destination
	var distance_to_final: int = DistanceCalculator.distance_between(
		current_pos,
		pathfinder.current_path[-1]
	)

	if distance_to_final <= MovementConstants.ARRIVAL_DISTANCE_PIXELS or \
	   _progress_tracker.is_near_completion():
		# Snap to destination and complete
		player.global_position = pathfinder.current_path[-1]
		_complete_movement()
		return

	# If direction is zero (very close to target), bump progress and recompute
	if direction.length() <= 0.0:
		_progress_tracker.bump_progress()
		target_pos = pathfinder.get_next_position(_progress_tracker.get_progress())
		direction = DirectionUtils.direction_to_with_threshold(
			current_pos,
			target_pos,
			MovementConstants.TARGET_POINT_THRESHOLD_PIXELS
		)

	# Update animation & state
	_update_animation_and_state(direction)

	# Move the player
	player.velocity = direction * _movement_executor.movement_speed
	player.move_and_slide()

	# Allow player to update animation if they expose a controller API
	if player.has_method("animation_controller"):
		player.animation_controller.update_animation()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle input when turn-based mode is active (confirm/cancel)."""
	if not is_active:
		return

	# Confirmation / cancellation while awaiting confirmation
	if _turn_state.is_in_state(NavigationTypes.TurnState.AWAITING_CONFIRMATION):
		if event.is_action_pressed("ui_accept"): # Space or Enter
			confirm_movement()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"): # Escape
			cancel_movement()
			get_viewport().set_input_as_handled()
			return

# ============================================================================
# PUBLIC API (alphabetized)
# ============================================================================

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
	if not _turn_state.is_in_state(NavigationTypes.TurnState.AWAITING_CONFIRMATION):
		return

	if DEBUG:
		print("Movement cancelled")
	if pathfinder != null:
		pathfinder.cancel_path()

	_turn_state.change_state(NavigationTypes.TurnState.IDLE)
	if path_preview_line != null:
		path_preview_line.clear_points()

func confirm_movement() -> void:
	"""Confirm the planned movement and start execution (only valid in AWAITING_CONFIRMATION)."""
	if not _turn_state.is_in_state(NavigationTypes.TurnState.AWAITING_CONFIRMATION) or not is_active:
		return

	if DEBUG:
		print("Movement confirmed - executing")
	if pathfinder != null:
		pathfinder.confirm_path()

	_turn_state.change_state(NavigationTypes.TurnState.EXECUTING)

	# Initialize movement execution using Core components
	_progress_tracker.start_tracking(pathfinder.current_path, player.global_position)
	_movement_executor.start_execution(pathfinder.current_path)

	# Hide preview
	if path_preview_line != null:
		path_preview_line.clear_points()

	# Emit movement started
	movement_started.emit()

	# Disable player's normal input if supported
	if player != null and player.has_method("set_movement_mode"):
		player.set_movement_mode("none") # expect a "none" mode to exist externally

func deactivate() -> void:
	"""Deactivate turn-based mode (disable input & physics)."""
	is_active = false
	set_physics_process(false)
	set_process_unhandled_input(false)

	if path_preview_line != null:
		path_preview_line.clear_points()

	_turn_state.reset()
	if DEBUG:
		print("Turn-based mode deactivated")

func end_turn() -> void:
	"""End the current turn and emit the turn_ended signal."""
	if not is_active:
		return

	_turn_state.end_turn()
	if DEBUG:
		print("Turn %d ended" % _turn_state.current_turn)

	# Reset per-turn movement usage for the next turn
	movement_used_this_turn = 0

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
	print("[TurnBasedMovementController] request_movement_to called - state: %s, is_active: %s" % [_turn_state.get_current_state_string(), is_active])
	if not _turn_state.is_in_state(NavigationTypes.TurnState.IDLE) or not is_active:
		print("[TurnBasedMovementController] Cannot request movement - state: %s, is_active: %s" % [_turn_state.get_current_state_string(), is_active])
		return

	_turn_state.change_state(NavigationTypes.TurnState.PLANNING)

	# Calculate remaining movement allowed this turn (in meters/hex cells)
	var remaining_movement_meters: int = MovementConstants.MAX_MOVEMENT_DISTANCE - movement_used_this_turn
	if remaining_movement_meters <= 0:
		print("[TurnBasedMovementController] No movement remaining this turn")
		_turn_state.change_state(NavigationTypes.TurnState.IDLE)
		return

	print("[TurnBasedMovementController] Calculating path to %s (remaining: %d m)" % [str(destination), remaining_movement_meters])
	print("[TurnBasedMovementController] Pathfinder is null: %s" % str(pathfinder == null))

	# Ask pathfinder to calculate
	var found_path: bool = false
	if pathfinder != null:
		found_path = pathfinder.calculate_path_to(destination)
		print("[TurnBasedMovementController] Pathfinder returned: %s" % str(found_path))

	if found_path:
		_turn_state.change_state(NavigationTypes.TurnState.AWAITING_CONFIRMATION)
		_show_path_preview()
		print("[TurnBasedMovementController] Path calculated - awaiting confirmation")
	else:
		print("[TurnBasedMovementController] No valid path found - resetting to IDLE")
		_turn_state.change_state(NavigationTypes.TurnState.IDLE)

func start_new_turn() -> void:
	"""Begin a new movement turn (reset per-turn counters and emit turn_started)."""
	if not is_active:
		return

	_turn_state.start_turn()
	movement_used_this_turn = 0
	turn_started.emit(_turn_state.current_turn)
	if DEBUG:
		print("Turn %d started - Ready for input" % _turn_state.current_turn)

# ============================================================================
# PUBLIC API - STATE QUERIES
# ============================================================================

func get_current_state() -> NavigationTypes.TurnState:
	"""Get the current turn state."""
	return _turn_state.current_state if _turn_state else NavigationTypes.TurnState.IDLE

func is_in_state(state: NavigationTypes.TurnState) -> bool:
	"""Check if currently in the specified state."""
	return _turn_state.is_in_state(state) if _turn_state else false

func is_awaiting_confirmation() -> bool:
	"""Check if currently awaiting movement confirmation."""
	return is_in_state(NavigationTypes.TurnState.AWAITING_CONFIRMATION)

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _complete_movement() -> void:
	"""Complete the current movement: finalize values, emit signals, and decide whether to end turn."""
	if not is_active:
		return

	# Accumulate movement used in meters (hex cells)
	if pathfinder != null:
		# Distance is measured in hex cells (each cell = 1 meter)
		var path_distance_meters = pathfinder.current_hex_path.size() - 1 # Subtract 1 for starting cell
		movement_used_this_turn += path_distance_meters

		if DEBUG:
			print("Movement complete - moved %d m (%d hex cells)" % [path_distance_meters, path_distance_meters])

	# Update state manager
	if state_manager != null:
		state_manager.set_state_value("is_moving", false)
		state_manager.set_state_value("has_input", false)

	_turn_state.change_state(NavigationTypes.TurnState.COMPLETED)
	var path_distance_meters = pathfinder.current_hex_path.size() - 1 if pathfinder else 0
	movement_completed.emit(path_distance_meters)

	# Clear pathfinder internal state
	if pathfinder != null:
		pathfinder.cancel_path()

	# Decide whether turn ends or allows more movement
	if movement_used_this_turn >= MovementConstants.MAX_MOVEMENT_DISTANCE * 0.95:
		end_turn()
	else:
		_turn_state.change_state(NavigationTypes.TurnState.IDLE)
		if DEBUG:
			var remaining := MovementConstants.MAX_MOVEMENT_DISTANCE - movement_used_this_turn
			print("%d m of movement remaining this turn" % remaining)

func _show_path_preview() -> void:
	"""Display the calculated path using Line2D and update distance label if present."""
	if path_preview_line == null or player == null or pathfinder == null:
		return

	path_preview_line.clear_points()

	# Add player position as start
	path_preview_line.add_point(player.global_position)

	# Add each point in the pathfinder's current_path
	for point in pathfinder.current_path:
		path_preview_line.add_point(point)

	# Update distance label if present
	if distance_label != null:
		# Distance is measured in hex cells (each cell = 1 meter)
		var dist_meters: int = pathfinder.current_hex_path.size() - 1 # Subtract 1 for starting cell
		distance_label.text = "Distance: %d m (%d hex cells)" % [dist_meters, dist_meters]

func _update_animation_and_state(direction: Vector2) -> void:
	"""Update movement component and state manager based on movement direction."""
	if movement_component != null:
		if direction != Vector2.ZERO:
			movement_component.update_direction(direction)

	if state_manager != null:
		state_manager.set_state_value("is_moving", direction != Vector2.ZERO)
		state_manager.set_state_value("has_input", true)

func _setup_ui() -> void:
	"""Create and configure UI elements for turn-based movement."""
	# Create path preview line
	if path_preview_line == null:
		path_preview_line = Line2D.new()
		path_preview_line.width = 2.0
		path_preview_line.default_color = Color.CYAN
		add_child(path_preview_line)

	# Note: distance_label, confirm_button, cancel_button can be assigned externally if needed

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_path_calculated(_segments: Array, total_distance: int) -> void:
	"""Called when pathfinder successfully calculates a path."""
	if DEBUG:
		print("Path calculated: %d m" % MovementConstants.pixels_to_meters(total_distance))
	_turn_state.change_state(NavigationTypes.TurnState.PREVIEW)

func _on_path_confirmed() -> void:
	"""Called when pathfinder confirms the path."""
	if DEBUG:
		print("Path confirmed")

func _on_path_cancelled() -> void:
	"""Called when pathfinder cancels the path."""
	if DEBUG:
		print("Path cancelled")
	_turn_state.change_state(NavigationTypes.TurnState.IDLE)

func _on_turn_state_ended(turn_number: int) -> void:
	"""Forward turn_ended signal from TurnStateMachine."""
	turn_ended.emit(turn_number)
