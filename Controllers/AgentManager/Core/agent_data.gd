class_name AgentData
extends RefCounted

## AgentData
##
## Tracks individual agent state and turn-based movement data.
## Provides atomized data structure for agent session tracking.


## Unique identifier for this agent
var agent_id: String = ""

## Reference to the AgentController node
var agent_controller: Node = null

## Current position in world coordinates
var current_position: Vector2 = Vector2.ZERO

## Spawn position (for reference/reset)
var spawn_position: Vector2 = Vector2.ZERO

## Movement tracking
var movements_used_this_turn: int = 0
var max_movements_per_turn: int = 10
var total_movements_lifetime: int = 0

## Uses distance-based movement (meters per turn) instead of action-based.

signal distance_traveled(distance_remaining: int)
signal turn_started(agent_id: String)
signal turn_ended(agent_id: String, total_distance: int)

## Movement tracking (distance-based in meters)
var distance_traveled_this_turn: int = 0
var max_distance_per_turn: int = 10  # 10 meters per turn
var total_distance_lifetime: int = 0

## Turn state
var is_active_agent: bool = false
var turn_number: int = 0

## Metadata
var creation_time: float = 0.0
var agent_name: String = ""


func _init(id: String = "", controller: Node = null) -> void:
	agent_id = id if id != "" else _generate_agent_id()
	agent_controller = controller
	creation_time = Time.get_ticks_msec() / 1000.0
	agent_name = "Agent_%s" % agent_id
	print("[AgentData] _init called: id=%s, controller=%s, agent_name=%s, self=%s" % [str(agent_id), str(agent_controller), str(agent_name), str(self)])


func _generate_agent_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi() % 1000]


## Set the spawn position and current position
func set_spawn_position(pos: Vector2) -> void:
	spawn_position = pos
	current_position = pos
	if agent_controller:
		agent_controller.global_position = pos


## Update current position (called after movement)
func update_position(pos: Vector2) -> void:
	current_position = pos


## Use a movement action (returns true if movement allowed)
## distance_meters: number of hex cells traveled (each cell = 1 meter)
func use_movement_action(distance_meters: int = 0) -> bool:
	# Check if adding this distance would exceed the limit
	var new_total = distance_traveled_this_turn + distance_meters
	if new_total > max_distance_per_turn:
		return false

	# Record the distance traveled
	distance_traveled_this_turn += distance_meters
	total_distance_lifetime += distance_meters
	movements_used_this_turn += 1  # Still track action count for legacy compatibility
	total_movements_lifetime += 1

	distance_traveled.emit(get_distance_remaining())
	return true


## Get remaining distance this turn (in meters)
func get_distance_remaining() -> int:
	return max(0, max_distance_per_turn - distance_traveled_this_turn)


## Get remaining movements this turn (legacy - returns distance remaining)
func get_movements_remaining() -> int:
	return get_distance_remaining()


## Check if agent can still move this turn
func can_move() -> bool:
	return distance_traveled_this_turn < max_distance_per_turn


## Start a new turn for this agent
func start_turn() -> void:
	movements_used_this_turn = 0
	distance_traveled_this_turn = 0
	is_active_agent = true
	turn_number += 1
	turn_started.emit(agent_id)


## End the turn for this agent
func end_turn() -> void:
	is_active_agent = false
	turn_ended.emit(agent_id, int(distance_traveled_this_turn))


## Reset all turn-based data
func reset_session() -> void:
	movements_used_this_turn = 0
	distance_traveled_this_turn = 0
	total_movements_lifetime = 0
	total_distance_lifetime = 0
	turn_number = 0
	is_active_agent = false


## Get agent state as dictionary for debugging
func get_state() -> Dictionary:
	return {
		"agent_id": agent_id,
		"agent_name": agent_name,
		"is_active": is_active_agent,
		"current_position": current_position,
		"spawn_position": spawn_position,
		"movements_used": movements_used_this_turn,
		"movements_remaining": get_movements_remaining(),
		"max_movements": max_movements_per_turn,
		"turn_number": turn_number,
		"total_movements": total_movements_lifetime,
		"creation_time": creation_time
	}


## Print debug information
func print_state() -> void:
	var state = get_state()
	print("=== Agent State: %s ===" % agent_name)
	for key in state:
		print("  %s: %s" % [key, state[key]])