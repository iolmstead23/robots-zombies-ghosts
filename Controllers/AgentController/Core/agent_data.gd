class_name AgentData
extends RefCounted

## AgentData
##
## Tracks individual agent state and turn-based movement data.
## Provides atomized data structure for agent session tracking.


## Unique identifier for this agent
var agent_id: String = ""

## Type of agent (robot, ghost, zombie)
var agent_type: AgentTypes.Type = AgentTypes.Type.ROBOT

## Reference to the AgentController node
var agent_controller: Node = null

## Current hex cell the agent is occupying
var current_cell: HexCell = null

## Current position in world coordinates
var current_position: Vector2 = Vector2.ZERO

## Movement tracking (LEGACY - deprecated, use distance-based tracking instead)
## These properties are maintained for UI compatibility but the system
## primarily uses distance-based movement (meters) not action-based movement
var movements_used_this_turn: int = 0
var max_movements_per_turn: int = 10

signal distance_traveled(distance_remaining: float)
signal turn_started(agent_id: String)
signal turn_ended(agent_id: String)

## Movement tracking (distance-based in pixels)
var distance_traveled_this_turn: float = 0.0
var max_distance_per_turn: float = 180.0  # Pixel distance (e.g., 10 hex × 18px)

## Turn state
var is_active_agent: bool = false
var turn_number: int = 0

## Metadata
var agent_name: String = ""


func _init(id: String = "", controller: Node = null, type: AgentTypes.Type = AgentTypes.Type.ROBOT) -> void:
	agent_id = id if id != "" else _generate_agent_id()
	agent_controller = controller
	agent_type = type
	agent_name = "Agent_%s" % agent_id


func _generate_agent_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi() % 1000]


## Update current position (called after movement)
func update_position(pos: Vector2) -> void:
	current_position = pos


## Use a movement action (returns true if movement allowed)
## distance_pixels: actual pixel distance traveled
func use_movement_action(distance_pixels: float = 0.0) -> bool:
	print("[AgentData] use_movement_action called: distance=%.2f, current_traveled=%.2f, max=%.2f" % [distance_pixels, distance_traveled_this_turn, max_distance_per_turn])
	# Check if adding this distance would exceed the limit
	var new_total = distance_traveled_this_turn + distance_pixels
	if new_total > max_distance_per_turn:
		print("[AgentData] Movement rejected: new_total=%.2f > max=%.2f" % [new_total, max_distance_per_turn])
		return false

	# Record the distance traveled
	distance_traveled_this_turn += distance_pixels
	movements_used_this_turn += 1  # Still track action count for legacy compatibility
	print("[AgentData] Movement accepted: traveled=%.2f, remaining=%.2f" % [distance_traveled_this_turn, get_distance_remaining()])

	distance_traveled.emit(get_distance_remaining())
	return true


## Get remaining distance this turn (in pixels)
func get_distance_remaining() -> float:
	return max(0.0, max_distance_per_turn - distance_traveled_this_turn)


## Get remaining movements this turn (returns distance as fractional hex count)
func get_movements_remaining() -> float:
	var pixels := get_distance_remaining()
	var hex_count := HexConstants.pixels_to_hex_cells(pixels)
	print("[AgentData] get_movements_remaining called: pixels=%.2f, hex=%.2f" % [pixels, hex_count])
	return hex_count


## Check if agent can still move this turn
func can_move() -> bool:
	return distance_traveled_this_turn < max_distance_per_turn


## Set the current hex cell the agent is occupying
func set_current_cell(cell: HexCell) -> void:
	current_cell = cell


## Start a new turn for this agent
func start_turn() -> void:
	movements_used_this_turn = 0
	distance_traveled_this_turn = 0
	is_active_agent = true
	turn_number += 1
	print("[AgentData] Turn started: agent=%s, max_distance=%.2f" % [agent_name, max_distance_per_turn])
	turn_started.emit(agent_id)


## End the turn for this agent
func end_turn() -> void:
	is_active_agent = false
	turn_ended.emit(agent_id)