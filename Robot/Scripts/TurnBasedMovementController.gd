extends Node
class_name TurnBasedMovementController

# --- Constants ---
const PIXELS_PER_FOOT = 16.0
const ARRIVAL_DISTANCE = 5.0
const TARGET_THRESHOLD = 1.0
const NEAR_END = 0.99
const PROGRESS_BUMP = 0.05

# --- Enums ---
enum TurnState { IDLE, PLANNING, PREVIEW, AWAIT_CONFIRM, EXECUTING, COMPLETED }

# --- Signals ---
signal turn_started(turn_number: int)
signal movement_started()
signal movement_completed(distance: float)
signal turn_ended(turn_number: int)

# --- Members ---
var state: int = TurnState.IDLE
var turn_number: int = 0
var move_progress: float = 0.0
var move_speed: float = 400.0
var move_used: float = 0.0
var path_index: int = 0
var is_active: bool = false

# Components
var pathfinder: TurnBasedPathfinder = null
var player: CharacterBody2D = null
var movement_component: MovementComponent = null
var state_manager: StateManager = null

# UI
var path_line: Line2D = null
var distance_label: Label = null
var confirm_button: Button = null
var cancel_button: Button = null

# --- Godot callbacks ---
func _physics_process(delta: float) -> void:
	if not (is_active and state == TurnState.EXECUTING): return
	if not _is_path_valid():
		_complete_movement()
		return

	_update_move_progress(delta)

	var target = pathfinder.get_next_position(move_progress)
	var cur = player.global_position
	var dir = _get_dir(cur, target)

	if _has_arrived(cur, pathfinder.current_path[-1]):
		player.global_position = pathfinder.current_path[-1]
		_complete_movement()
		return

	if dir.length() <= 0.0:
		move_progress = min(move_progress + PROGRESS_BUMP, 1.0)
		target = pathfinder.get_next_position(move_progress)
		dir = _get_dir(cur, target)

	_set_animation_and_state(dir)
	player.velocity = dir * move_speed
	player.move_and_slide()
	if player.has_method("animation_controller"):
		player.animation_controller.update_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return

	if state == TurnState.IDLE and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		request_movement_to(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return

	if state == TurnState.AWAIT_CONFIRM:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			confirm_movement()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			cancel_movement()
			get_viewport().set_input_as_handled()


# --- Public API ---
func activate() -> void:
	is_active = true
	set_physics_process(true)
	set_process_unhandled_input(true)
	start_new_turn()


func cancel_movement() -> void:
	if state != TurnState.AWAIT_CONFIRM: return
	if pathfinder: pathfinder.cancel_path()
	state = TurnState.IDLE
	if path_line: path_line.clear_points()


func confirm_movement() -> void:
	if not (state == TurnState.AWAIT_CONFIRM and is_active): return
	if pathfinder: pathfinder.confirm_path()

	state = TurnState.EXECUTING
	move_progress = 0.0
	path_index = 0
	if path_line: path_line.clear_points()
	movement_started.emit()
	if player and player.has_method("set_movement_mode"):
		player.set_movement_mode("none")


func deactivate() -> void:
	is_active = false
	set_physics_process(false)
	set_process_unhandled_input(false)
	if path_line: path_line.clear_points()
	state = TurnState.IDLE


func end_turn() -> void:
	if not is_active: return
	state = TurnState.IDLE
	turn_ended.emit(turn_number)
	move_used = 0.0


func initialize(player_ref: CharacterBody2D, move_ref: MovementComponent, state_ref: StateManager) -> void:
	player = player_ref
	movement_component = move_ref
	state_manager = state_ref

	if not pathfinder:
		pathfinder = TurnBasedPathfinder.new()
		add_child(pathfinder)
	pathfinder.initialize(player)
	_connect_pathfinder_signals()
	_setup_ui()
	set_physics_process(false)
	set_process_unhandled_input(false)


func request_movement_to(dest: Vector2) -> void:
	if not (state == TurnState.IDLE and is_active): return

	state = TurnState.PLANNING
	var remain = pathfinder.MAX_MOVEMENT_DISTANCE - move_used
	if remain <= 0.0:
		state = TurnState.IDLE
		return

	if pathfinder and pathfinder.calculate_path_to(dest):
		state = TurnState.AWAIT_CONFIRM
		_show_path_preview()
	else:
		state = TurnState.IDLE


func start_new_turn() -> void:
	if not is_active: return
	turn_number += 1
	move_used = 0.0
	state = TurnState.IDLE
	turn_started.emit(turn_number)


# --- Internal helpers ---
func _get_dir(cur: Vector2, target: Vector2) -> Vector2:
	return Vector2.ZERO if cur.distance_to(target) <= TARGET_THRESHOLD else (target - cur).normalized()


func _has_arrived(cur: Vector2, dest: Vector2) -> bool:
	return cur.distance_to(dest) <= ARRIVAL_DISTANCE or move_progress >= NEAR_END


func _is_path_valid() -> bool:
	return pathfinder and pathfinder.current_path and not pathfinder.current_path.is_empty()


func _complete_movement() -> void:
	if not is_active: return
	if pathfinder: move_used += pathfinder.total_path_distance
	if state_manager:
		state_manager.set_state_value("is_moving", false)
		state_manager.set_state_value("has_input", false)
	state = TurnState.COMPLETED
	movement_completed.emit(pathfinder.total_path_distance)
	if pathfinder: pathfinder.cancel_path()
	if move_used >= pathfinder.MAX_MOVEMENT_DISTANCE * 0.95:
		end_turn()
	else:
		state = TurnState.IDLE


func _show_path_preview() -> void:
	if not (path_line and player and pathfinder): return
	path_line.clear_points()
	var pts = PackedVector2Array([player.get_parent().to_local(player.global_position)])
	for s in pathfinder.path_segments:
		for p in s:
			pts.append(player.get_parent().to_local(p))
	path_line.points = pts
	if distance_label:
		distance_label.text = "Distance: %.1f ft" % (pathfinder.total_path_distance / PIXELS_PER_FOOT)


func _setup_ui() -> void:
	if not path_line:
		path_line = Line2D.new()
		path_line.width = 3.0
		path_line.default_color = Color.CYAN
		path_line.z_index = 10
		path_line.points = PackedVector2Array()
		if player and player.get_parent():
			player.get_parent().call_deferred("add_child", path_line)
		else:
			call_deferred("add_child", path_line)


func _set_animation_and_state(direction: Vector2) -> void:
	if not state_manager: return
	var moving = direction.length() > 0.1
	if moving:
		var dir_name = DirectionHelper.vector_to_direction_name(direction)
		state_manager.set_state_value("facing_direction", dir_name)
	state_manager.set_state_value("is_moving", moving)
	state_manager.set_state_value("has_input", moving)


func _update_move_progress(delta: float) -> void:
	if not (pathfinder and pathfinder.total_path_distance > 0.0): return
	move_progress = min(move_progress + (move_speed * delta) / pathfinder.total_path_distance, 1.0)


func _connect_pathfinder_signals() -> void:
	if pathfinder:
		if not pathfinder.path_calculated.is_connected(_on_path_calculated):
			pathfinder.path_calculated.connect(_on_path_calculated)
		if not pathfinder.path_confirmed.is_connected(_on_path_confirmed):
			pathfinder.path_confirmed.connect(_on_path_confirmed)
		if not pathfinder.path_cancelled.is_connected(_on_path_cancelled):
			pathfinder.path_cancelled.connect(_on_path_cancelled)


# --- Signal handlers ---
func _on_path_calculated(_segments: Array, _distance: float) -> void: pass
func _on_path_cancelled() -> void: pass
func _on_path_confirmed() -> void: pass
