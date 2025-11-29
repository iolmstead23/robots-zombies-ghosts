class_name AgentController
extends Node

## AgentController
##
## Manages multiple agents in a turn-based system.
## Handles agent spawning, turn order, and movement tracking.
## Atomized controller for multi-agent session management.

signal agents_spawned(agent_count: int)
signal agent_turn_started(agent_data: AgentData)
signal agent_turn_ended(agent_data: AgentData)
signal all_agents_completed_round()
signal movement_action_completed(agent_data: AgentData, movements_remaining: int)

## Agent prefab to instantiate
@export var agent_scene: PackedScene = null

## Number of agents to spawn (1-4)
@export_range(1, 4) var agent_count: int = 1

## Maximum movements per agent per turn
@export var max_movements_per_turn: int = 10

## References
var hex_grid: HexGrid = null
var navigation_controller: Node = null

## Agent tracking
var agents: Array[AgentData] = []
var active_agent_index: int = 0
var current_round: int = 0

## State
var is_initialized: bool = false
var session_active: bool = false


func _ready() -> void:
	_ensure_agent_scene_loaded()


## Ensure agent scene is loaded
func _ensure_agent_scene_loaded() -> void:
	if agent_scene == null:
		# Try to load default agent scene
		agent_scene = load("res://Agents/agent.tscn")
		if agent_scene == null:
			push_error("[AgentController] Failed to load default agent scene from res://Agents/agent.tscn")


## Initialize the agent manager with required references
func initialize(grid: HexGrid, nav_controller: Node) -> void:
	hex_grid = grid
	navigation_controller = nav_controller
	_ensure_agent_scene_loaded()
	is_initialized = true
	print("[AgentController] Initialized with grid and navigation controller")


## Spawn agents at random positions within the navigation map
func spawn_agents(count: int = -1) -> void:
	print("[AgentController] ===== SPAWN_AGENTS CALLED =====")
	print("[AgentController] Requested count: %d" % count)
	print("[AgentController] Initialized: %s" % is_initialized)
	print("[AgentController] In scene tree: %s" % is_inside_tree())
	print("[AgentController] Agent scene: %s" % ("Loaded" if agent_scene != null else "NULL"))

	if not is_initialized:
		push_error("[AgentController] Cannot spawn agents - not initialized")
		return

	if count > 0:
		agent_count = clamp(count, 1, 4)

	print("[AgentController] Will spawn %d agents" % agent_count)

	# Clear existing agents
	_clear_agents()

	# Get valid spawn positions
	var spawn_positions = _get_random_spawn_positions(agent_count)
	print("[AgentController] Found %d valid spawn positions (need %d)" % [spawn_positions.size(), agent_count])

	if spawn_positions.size() < agent_count:
		push_error("[AgentController] Not enough valid spawn positions found")
		return

	# Spawn each agent
	for i in range(agent_count):
		print("[AgentController] Spawning agent %d/%d..." % [i + 1, agent_count])
		var agent = _spawn_agent(i, spawn_positions[i])
		if agent:
			agents.append(agent)
			print("[AgentController] ✓ Agent %d spawned successfully" % (i + 1))
		else:
			push_error("[AgentController] ✗ Failed to spawn agent %d" % (i + 1))

	print("[AgentController] ===== SPAWN COMPLETE: %d/%d agents spawned =====" % [agents.size(), agent_count])
	
	# Strict validation: Agents array must be exactly agent_count in length, and must not contain nulls
	var valid_agent_count := (agents.size() == agent_count)
	var has_null_agent := false
	for a in agents:
		if a == null:
			has_null_agent = true
			break

	if not valid_agent_count or has_null_agent:
		push_error("[AgentController] ERROR - Agent array invalid after spawn: Expected %d, Got %d, Null: %s" % [
			agent_count, agents.size(), str(has_null_agent)
		])
		_clear_agents()
		return

	agents_spawned.emit(agents.size())

	# Start the first turn
	if agents.size() > 0:
		session_active = true
		_start_next_agent_turn()
	else:
		push_error("[AgentController] No agents were successfully spawned!")


## Get random spawn positions within the navigation map
func _get_random_spawn_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var max_attempts = 100
	var attempts = 0
	var min_distance_between_agents = 100.0 # Minimum pixels between agents

	while positions.size() < count and attempts < max_attempts:
		attempts += 1

		# Get random position within grid bounds
		var random_q = randi_range(0, hex_grid.grid_width - 1)
		var random_r = randi_range(0, hex_grid.grid_height - 1)

		var cell = hex_grid.get_cell_at_coords(Vector2i(random_q, random_r))
		if cell == null or not cell.enabled:
			continue

		var world_pos = cell.world_position

		# Check if position is too close to existing spawn points
		var too_close = false
		for existing_pos in positions:
			if world_pos.distance_to(existing_pos) < min_distance_between_agents:
				too_close = true
				break

		if not too_close:
			positions.append(world_pos)

	return positions


## Spawn a single agent at the specified position
func _spawn_agent(index: int, position: Vector2) -> AgentData:
	print("  [_spawn_agent] Creating agent %d at %s" % [index, position])

	if agent_scene == null:
		push_error("  [_spawn_agent] Agent scene is NULL!")
		return null

	print("  [_spawn_agent] Agent scene is valid, attempting instantiate...")

	# Instantiate agent controller
	var agent_controller = agent_scene.instantiate()

	print("  [_spawn_agent] Instantiate returned: %s" % ("Valid node" if agent_controller != null else "NULL"))

	if agent_controller == null:
		push_error("  [_spawn_agent] Failed to instantiate agent scene")
		return null

	print("  [_spawn_agent] Agent controller type: %s" % agent_controller.get_class())
	print("  [_spawn_agent] Adding to scene tree (parent: %s, in_tree: %s)" % [name, is_inside_tree()])

	# Add to scene tree
	add_child(agent_controller)

	print("  [_spawn_agent] Agent added to scene tree successfully")

	agent_controller.global_position = position

	print("  [_spawn_agent] Position set to %s" % position)

	# Create agent data
	var agent_id = "agent_%d" % index
	var agent_data = AgentData.new(agent_id, agent_controller)
	agent_data.max_movements_per_turn = max_movements_per_turn
	agent_data.set_spawn_position(position)
	agent_data.agent_name = "Agent %d" % (index + 1)

	# Connect signals
	# ERROR FIX: AgentData does NOT define signal movement_action_used. Line removed for correct property access.
	# To track movement usage, define and emit a new 'movement_used_this_turn' signal in AgentData if needed.
	# agent_data.movement_action_used.connect(_on_agent_movement_action_used.bind(agent_data))
	agent_data.turn_started.connect(_on_agent_turn_started)
	agent_data.turn_ended.connect(_on_agent_turn_ended)

	# Setup agent controller with hex navigation if available
	if hex_grid and navigation_controller and agent_controller.has_method("set_hex_navigation"):
		var pathfinder = navigation_controller.get("hex_pathfinder")
		if pathfinder:
			agent_controller.set_hex_navigation(hex_grid, pathfinder)

	print("[AgentController] Spawned %s at %s" % [agent_data.agent_name, position])
	print("[AgentController] AgentData constructed: id=%s, creation_time=%s, controller=%s" % [str(agent_data.agent_id), str(agent_data.creation_time), str(agent_controller.get_path())])
	return agent_data


## Clear all existing agents
func _clear_agents() -> void:
	for agent_data in agents:
		if agent_data.agent_controller:
			agent_data.agent_controller.queue_free()

	agents.clear()
	active_agent_index = 0
	current_round = 0
	session_active = false


## Start the next agent's turn
func _start_next_agent_turn() -> void:
	if agents.is_empty():
		return

	# End current agent's turn if there is one active
	var had_active_agent = false
	if active_agent_index < agents.size():
		var current_agent = agents[active_agent_index]
		if current_agent.is_active_agent:
			had_active_agent = true
			# Disable controllability for ending agent
			if current_agent.agent_controller and current_agent.agent_controller.has_method("set_controllable"):
				current_agent.agent_controller.set_controllable(false)
			# Deactivate turn-based controller for ending agent
			if current_agent.agent_controller and current_agent.agent_controller.turn_based_controller:
				current_agent.agent_controller.turn_based_controller.deactivate()
			current_agent.end_turn()

	# Move to next agent only if we had an active agent
	# (on first call, we want to start at index 0, not 1)
	if had_active_agent:
		active_agent_index += 1

	# Check if we completed a full round
	if active_agent_index >= agents.size():
		active_agent_index = 0
		current_round += 1
		all_agents_completed_round.emit()
		print("[AgentController] Round %d completed" % current_round)

	# Set controllability: enable only for next_agent
	for i in range(agents.size()):
		var agent_data = agents[i]
		if agent_data.agent_controller and agent_data.agent_controller.has_method("set_controllable"):
			agent_data.agent_controller.set_controllable(i == active_agent_index)

	# Start next agent's turn
	var next_agent = agents[active_agent_index]
	next_agent.start_turn()

	# Activate turn-based controller for this agent (redundant now, but preserved for compatibility)
	if next_agent.agent_controller and next_agent.agent_controller.has_method("activate_turn_based_mode"):
		next_agent.agent_controller.activate_turn_based_mode()
		if next_agent.agent_controller.turn_based_controller:
			next_agent.agent_controller.turn_based_controller.start_new_turn()

	agent_turn_started.emit(next_agent)

	# Turn debug print
	print("[AgentController] ===== AGENT TURN =====")
	print("[AgentController] Active agent: %s (Index: %d, Round: %d)" % [
		next_agent.agent_name,
		active_agent_index,
		current_round
	])
	print("[AgentController] =======================")


## Get the currently active agent
func get_active_agent() -> AgentData:
	if active_agent_index < agents.size():
		return agents[active_agent_index]
	return null


## Get all agents
func get_all_agents() -> Array[AgentData]:
	# Enforce agent array validity
	if agents.size() != agent_count:
		push_error("[AgentController] get_all_agents(): agents.size (%d) != expected agent_count (%d)" % [agents.size(), agent_count])
		return []
	for a in agents:
		if a == null:
			push_error("[AgentController] get_all_agents(): Null agent detected in agents array.")
			return []
	return agents


## Record a movement action for the active agent
## distance_meters: number of hex cells traveled (each cell = 1 meter)
func record_movement_action(distance_meters: int = 0) -> bool:
	var active_agent = get_active_agent()
	if active_agent == null:
		return false

	if not active_agent.use_movement_action(distance_meters):
		print("[AgentController] %s has no distance remaining (%d / %d meters used)" % [
			active_agent.agent_name,
			active_agent.distance_traveled_this_turn,
			active_agent.max_distance_per_turn
		])
		return false

	print("[AgentController] %s moved %d meters (%d / %d meters used)" % [
		active_agent.agent_name,
		distance_meters,
		active_agent.distance_traveled_this_turn,
		active_agent.max_distance_per_turn
	])

	movement_action_completed.emit(active_agent, active_agent.get_distance_remaining())

	# Auto-advance turn if distance exhausted
	if not active_agent.can_move():
		print("[AgentController] %s exhausted distance budget (%d / %d meters), ending turn" % [
			active_agent.agent_name,
			active_agent.distance_traveled_this_turn,
			active_agent.max_distance_per_turn
		])
		_start_next_agent_turn()

	return true


## Manually end the current agent's turn
func end_current_agent_turn() -> void:
	var active_agent = get_active_agent()
	if active_agent:
		print("[AgentController] Manually ending %s turn" % active_agent.agent_name)
		_start_next_agent_turn()


## Update agent position after movement
func update_agent_position(agent_data: AgentData, new_position: Vector2) -> void:
	if agent_data:
		agent_data.update_position(new_position)


## Signal handlers
func _on_agent_movement_action_used(_movements_remaining: int, _agent_data: AgentData) -> void:
	# This is called from AgentData signal
	pass


func _on_agent_turn_started(agent_id: String) -> void:
	print("[AgentController] Agent turn started: %s" % agent_id)


func _on_agent_turn_ended(agent_id: String, total_movements: int) -> void:
	print("[AgentController] Agent turn ended: %s (used %d movements)" % [agent_id, total_movements])

	# Find the agent and re-emit the signal for external listeners
	for agent_data in agents:
		if agent_data.agent_id == agent_id:
			agent_turn_ended.emit(agent_data)
			break


## Get session state for debugging
func get_state() -> Dictionary:
	return {
		"is_initialized": is_initialized,
		"session_active": session_active,
		"agent_count": agents.size(),
		"active_agent_index": active_agent_index,
		"current_round": current_round,
		"active_agent": get_active_agent().agent_name if get_active_agent() else "None"
	}


## Print debug information
func print_state() -> void:
	print("=== AgentController State ===")
	var state = get_state()
	for key in state:
		print("  %s: %s" % [key, state[key]])

	print("\n=== All Agents ===")
	for i in range(agents.size()):
		var agent = agents[i]
		var active_marker = " [ACTIVE]" if i == active_agent_index else ""
		print("  %d. %s%s - Movements: %d/%d" % [
			i,
			agent.agent_name,
			active_marker,
			agent.movements_used_this_turn,
			agent.max_movements_per_turn
		])
