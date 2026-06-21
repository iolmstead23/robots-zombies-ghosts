extends Node
class_name AgentNavigation

## Wraps NavigationAgent2D for isometric point-and-click movement.
## Requires a NavigationRegion2D with a baked polygon in the scene.

const ARRIVAL_DISTANCE := 64.0
const OFF_NAVMESH_THRESHOLD := 32.0
const AVOIDANCE_RADIUS_BUFFER := 60.0  # Extra buffer beyond navigation agent radius
const STUCK_CHECK_INTERVAL := 0.5  # Check for stuck every 0.5 seconds
const STUCK_MIN_MOVEMENT := 20.0  # Minimum pixels moved to not be stuck
const STUCK_MAX_FRAMES := 3  # Number of stuck checks before canceling

var player: CharacterBody2D
var state_manager: AgentState
var movement_component: AgentMovementComponent
var navigation_agent: NavigationAgent2D
var _last_delta: float = 0.0

var _navigation_start_pos := Vector2.ZERO
var _last_position_delta := Vector2.ZERO
var _position_history := []
const MAX_POSITION_HISTORY := 20

var _stuck_check_timer := 0.0
var _last_checked_pos := Vector2.ZERO
var _consecutive_stuck_frames := 0

signal navigation_started()
signal navigation_completed()

func initialize(
	player_ref: CharacterBody2D,
	state_ref: AgentState,
	movement_ref: AgentMovementComponent,
	nav_agent: NavigationAgent2D
) -> void:
	player = player_ref
	state_manager = state_ref
	movement_component = movement_ref
	navigation_agent = nav_agent
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

func navigate_to(world_pos: Vector2) -> void:
	var map_rid := navigation_agent.get_navigation_map()
	var target_pos := world_pos

	if map_rid.is_valid():
		var closest := NavigationServer2D.map_get_closest_point(map_rid, world_pos)
		if world_pos.distance_to(closest) > OFF_NAVMESH_THRESHOLD:
			if OS.is_debug_build():
				print_debug("NAV: off-navmesh click (%.0fpx from edge) — ignored" % world_pos.distance_to(closest))
			return

		# Adjust target to account for avoidance radius
		var adjusted := _adjust_target_for_avoidance(closest, world_pos)
		target_pos = adjusted

	if OS.is_debug_build():
		print_debug("NAV: move to %.0f,%.0f (from %.0f,%.0f)" % [target_pos.x, target_pos.y, player.global_position.x, player.global_position.y])

	navigation_agent.target_position = target_pos
	_navigation_start_pos = player.global_position
	_position_history.clear()
	_last_checked_pos = player.global_position
	_stuck_check_timer = 0.0
	_consecutive_stuck_frames = 0
	state_manager.set_state_value("is_moving", true)
	navigation_started.emit()

func process(delta: float) -> void:
	_last_delta = delta
	if not state_manager.get_state_value("is_moving"):
		return

	if navigation_agent.is_navigation_finished():
		_on_arrived()
		return

	var next_pos := navigation_agent.get_next_path_position()
	var to_next := next_pos - player.global_position

	# Secondary arrival gate: actual distance to clicked target (not intermediate waypoints)
	if player.global_position.distance_to(navigation_agent.target_position) <= ARRIVAL_DISTANCE:
		_on_arrived()
		return

	var desired_velocity := to_next.normalized() * movement_component.SPEED
	# Use avoidance if enabled on the NavigationAgent2D; otherwise apply directly
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = desired_velocity
	else:
		_apply_velocity(desired_velocity)

	# Check if stuck every STUCK_CHECK_INTERVAL seconds
	_stuck_check_timer += delta
	if _stuck_check_timer >= STUCK_CHECK_INTERVAL:
		_stuck_check_timer = 0.0
		_check_if_stuck()

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if not state_manager.get_state_value("is_moving"):
		return
	_apply_velocity(safe_velocity)

func _apply_velocity(velocity: Vector2) -> void:
	var prev_pos := player.global_position
	movement_component.set_velocity(velocity)
	player.velocity = velocity
	_update_facing(velocity)
	player.move_and_slide()

	_last_position_delta = player.global_position - prev_pos
	_record_position_history(player.global_position)

	if OS.is_debug_build() and _last_delta > 0.0:
		var actual := _last_position_delta
		var expected := velocity * _last_delta
		var err := actual.distance_to(expected)

		var remaining_dist := player.global_position.distance_to(navigation_agent.target_position)
		var start_dist := _navigation_start_pos.distance_to(navigation_agent.target_position)
		var progress := 1.0 - (remaining_dist / start_dist) if start_dist > 0.0 else 0.0

		if err > 5.0 or remaining_dist < 100.0:
			print_debug("NAV_TRACK: pos=(%.0f,%.0f) delta=(%.0f,%.0f) target_dist=%.0f progress=%.0f%% err=%.1f" % [
				player.global_position.x, player.global_position.y, actual.x, actual.y, remaining_dist, progress * 100, err
			])

func _update_facing(velocity: Vector2) -> void:
	if velocity.length() < 1.0:
		return
	var dir_name := DirectionHelper.vector_to_direction_name(velocity.normalized())
	if dir_name != "":
		state_manager.set_state_value("facing_direction", dir_name)

func _record_position_history(current_pos: Vector2) -> void:
	var entry := {
		"pos": current_pos,
		"time": Time.get_ticks_msec() / 1000.0,
		"frame": Engine.get_physics_frames()
	}
	_position_history.append(entry)
	if _position_history.size() > MAX_POSITION_HISTORY:
		_position_history.pop_front()

func _on_arrived() -> void:
	if OS.is_debug_build():
		print_debug("NAV: arrived at %.0f,%.0f" % [player.global_position.x, player.global_position.y])
	movement_component.set_velocity(Vector2.ZERO)
	player.velocity = Vector2.ZERO
	state_manager.set_state_values({
		"is_moving": false,
		"is_running": false
	})
	navigation_completed.emit()

func cancel_navigation() -> void:
	navigation_agent.target_position = player.global_position
	_on_arrived()

func _adjust_target_for_avoidance(closest_point: Vector2, clicked_point: Vector2) -> Vector2:
	# Get the collision radius from the navigation agent, add buffer
	var total_radius: float = navigation_agent.radius + AVOIDANCE_RADIUS_BUFFER

	# Direction from closest valid point toward the clicked point
	var direction: Vector2 = (clicked_point - closest_point).normalized()

	# Place target outside the collision radius
	var adjusted_target: Vector2 = closest_point + direction * total_radius

	# Verify the adjusted point is valid on the navmesh
	var map_rid := navigation_agent.get_navigation_map()
	if map_rid.is_valid():
		var verified: Vector2 = NavigationServer2D.map_get_closest_point(map_rid, adjusted_target)
		if adjusted_target.distance_to(verified) <= 16.0:  # Within tolerance
			return verified
		else:
			# Fallback: return the closest valid point with some outward offset
			return closest_point + direction * (total_radius * 0.8)

	return adjusted_target

func _check_if_stuck() -> void:
	var current_pos := player.global_position
	var movement := current_pos.distance_to(_last_checked_pos)

	if movement < STUCK_MIN_MOVEMENT:
		_consecutive_stuck_frames += 1
		if OS.is_debug_build():
			print_debug("NAV: stuck check #%d (moved %.1fpx)" % [_consecutive_stuck_frames, movement])

		if _consecutive_stuck_frames >= STUCK_MAX_FRAMES:
			if OS.is_debug_build():
				print_debug("NAV: robot stuck, canceling navigation")
			cancel_navigation()
			return
	else:
		# Reset stuck counter when making progress
		_consecutive_stuck_frames = 0

	_last_checked_pos = current_pos
