class_name AgentController
extends Node

## Signals for session/agent events
signal agents_spawned(count: int)
signal agent_turn_started(agent_data: AgentData)
signal agent_turn_ended(agent_data: AgentData)
signal all_agents_completed_round()
signal movement_action_completed(agent_data: AgentData, movements_remaining: int)

## Exported/Configurable vars
@export var agent_scene: PackedScene
@export_range(1, 4) var agent_count: int = 1
@export var max_movements_per_turn: int = 10

## Context references
var session_controller: Node

## Agent tracking
var agents: Array[AgentData] = []
var active_agent_index := 0
var current_round := 0

## State
var is_initialized := false
var session_active := false

func _ready():
	_load_agent_scene()

func _load_agent_scene() -> void:
	if not agent_scene:
		agent_scene = load("res://Agents/agent.tscn")
		if not agent_scene:
			push_error("[AgentController] Failed to load agent scene.")

func initialize(session_ctrl: Node) -> void:
	session_controller = session_ctrl
	_load_agent_scene()
	is_initialized = true
	_debug("Initialized with SessionController reference.")

# ------------------------------------
# SPAWN LOGIC
# ------------------------------------
func spawn_agents(count: int = -1) -> void:
	if not is_initialized:
		push_error("[AgentController] Not initialized.")
		return
	agent_count = clamp(count if count > 0 else agent_count, 1, 4)
	_clear_agents()
	var spawn_cells = _random_spawn_cells(agent_count)
	if spawn_cells.size() < agent_count:
		push_error("[AgentController] Not enough spawn cells.")
		return
	for i in agent_count:
		agents.append(_spawn_agent(i, spawn_cells[i]))
	if agents.any(func(a): return a == null):
		push_error("[AgentController] Invalid agent in agents array.")
		_clear_agents()
		return
	agents_spawned.emit(agents.size())
	if agents.size() > 0:
		session_active = true
		_next_agent_turn()

func _random_spawn_cells(count: int) -> Array[HexCell]:
	"""Get random spawn cells with minimum distance separation"""
	var spawn_cells: Array[HexCell] = []
	const MIN_SPAWN_DISTANCE := 3
	const MAX_ATTEMPTS := 100

	var attempts := 0
	while spawn_cells.size() < count and attempts < MAX_ATTEMPTS:
		var cell := _get_random_enabled_cell()
		if cell == null:
			break

		if _is_valid_spawn_location(cell, spawn_cells, MIN_SPAWN_DISTANCE):
			spawn_cells.append(cell)

		attempts += 1

	return spawn_cells

func _get_random_enabled_cell() -> HexCell:
	"""Get single random enabled hex cell"""
	if not session_controller:
		return null

	return session_controller.get_random_enabled_cell()

func _is_valid_spawn_location(cell: HexCell, existing_cells: Array[HexCell], min_distance: int) -> bool:
	"""Check if cell is far enough from existing spawn points"""
	if not session_controller:
		return true

	for existing in existing_cells:
		if session_controller.get_hex_distance(cell, existing) < min_distance:
			return false
	return true

func _spawn_agent(index: int, cell: HexCell) -> AgentData:
	if not agent_scene:
		push_error("[AgentController] Agent scene not loaded!")
		return null
	var ac = agent_scene.instantiate()
	add_child(ac)
	var pos = cell.world_position
	ac.global_position = pos
	var agent_id = "agent_%d" % index
	var ad = AgentData.new(agent_id, ac)
	ad.agent_name = "Agent %d" % (index + 1)
	ad.max_movements_per_turn = max_movements_per_turn
	ad.current_position = pos
	ad.set_current_cell(cell)  # Set the current hex cell
	ad.turn_started.connect(_on_agent_turn_started)
	ad.turn_ended.connect(_on_agent_turn_ended)
	_configure_agent_controller(ac)
	return ad

func _configure_agent_controller(ac):
	if OS.is_debug_build():
		print("[AgentController] Configuring agent via SessionController")

	if session_controller:
		session_controller.configure_agent_navigation(ac)
	else:
		push_warning("[AgentController] SessionController is null - cannot configure agent navigation")

# ------------------------------------
# AGENT TURN LOGIC
# ------------------------------------
func start_agent_turn(agent_data: AgentData) -> void:
	if agents.is_empty(): return
	var idx = agents.find(agent_data)
	if idx == -1:
		push_error("[AgentController] Agent not found.")
		return
	_cleanup_agent_turn()
	active_agent_index = idx
	_set_agents_controllable(active_agent_index)
	agents[active_agent_index].start_turn()
	_activate_agent_turn_mode(agents[active_agent_index])
	agent_turn_started.emit(agents[active_agent_index])
	_debug("Turn Start: %s" % agents[active_agent_index].agent_name)

func _next_agent_turn():
	if agents.is_empty(): return
	var had_active = agents[active_agent_index].is_active_agent if active_agent_index < agents.size() else false
	if had_active: _cleanup_agent_turn()
	if had_active: active_agent_index += 1
	if active_agent_index >= agents.size():
		active_agent_index = 0
		current_round += 1
		all_agents_completed_round.emit()
	_set_agents_controllable(active_agent_index)
	agents[active_agent_index].start_turn()
	_activate_agent_turn_mode(agents[active_agent_index])
	agent_turn_started.emit(agents[active_agent_index])
	_debug("Next Turn: %s" % agents[active_agent_index].agent_name)

func _cleanup_agent_turn():
	if active_agent_index < agents.size():
		var curr = agents[active_agent_index]
		if curr.is_active_agent:
			if curr.agent_controller and curr.agent_controller.has_method("set_controllable"):
				curr.agent_controller.set_controllable(false)
			if curr.agent_controller and curr.agent_controller.turn_based_controller:
				curr.agent_controller.turn_based_controller.deactivate()
			curr.end_turn()

func _set_agents_controllable(active_idx: int):
	for i in agents.size():
		var ctrl = agents[i].agent_controller
		if ctrl and ctrl.has_method("set_controllable"):
			ctrl.set_controllable(i == active_idx)

func _activate_agent_turn_mode(agent):
	if agent.agent_controller and agent.agent_controller.has_method("activate_turn_based_mode"):
		agent.agent_controller.activate_turn_based_mode()
		if agent.agent_controller.turn_based_controller:
			agent.agent_controller.turn_based_controller.start_new_turn()

func end_current_agent_turn() -> void:
	if get_active_agent():
		_debug("Manual turn end")
		_next_agent_turn()

# ------------------------------------
# AGENT MANAGEMENT
# ------------------------------------
func _clear_agents():
	for data in agents:
		if data.agent_controller:
			data.agent_controller.queue_free()
	agents.clear()
	active_agent_index = 0
	current_round = 0
	session_active = false

func get_active_agent() -> AgentData:
	return agents[active_agent_index] if active_agent_index < agents.size() else null

func get_all_agents() -> Array[AgentData]:
	if agents.size() != agent_count or agents.any(func(a): return a == null):
		push_error("[AgentController] Agent array invalid.")
		return []
	return agents

# ------------------------------------
# MOVEMENT LOGIC
# ------------------------------------
func record_movement_action(distance_meters: int = 0) -> bool:
	var aa = get_active_agent()
	if not aa: return false
	if not aa.use_movement_action(distance_meters):
		_debug("%s exhausted movement" % aa.agent_name)
		return false

	# Don't update cell position here - it will be updated after movement completes
	# Don't auto-advance turn here - wait until movement physically finishes

	return true

## Called after movement physically completes to update state
func update_agent_position_after_movement(agent_data: AgentData) -> void:
	_update_agent_current_cell(agent_data)
	movement_action_completed.emit(agent_data, agent_data.get_distance_remaining())

	# Auto-advance turn when movements are exhausted (AFTER movement completes)
	if not agent_data.can_move():
		_debug("%s has no movements remaining - ending turn automatically" % agent_data.agent_name)
		# Use call_deferred to allow signals to propagate before switching turns
		call_deferred("_next_agent_turn")

## Update agent's current_cell based on their world position
func _update_agent_current_cell(agent_data: AgentData) -> void:
	if not session_controller or not agent_data or not agent_data.agent_controller:
		return

	var controller_pos = agent_data.agent_controller.global_position
	var cell = session_controller.get_cell_at_world_position(controller_pos)
	if cell:
		agent_data.set_current_cell(cell)

# ------------------------------------
# SIGNAL HANDLERS
# ------------------------------------
func _on_agent_turn_started(agent_id: String) -> void:
	_debug("Agent turn started: %s" % agent_id)

func _on_agent_turn_ended(agent_id: String) -> void:
	for ad in agents:
		if ad.agent_id == agent_id:
			agent_turn_ended.emit(ad)
			break

# ------------------------------------
# DEBUGGING HELPERS
# ------------------------------------
func _debug(msg: String) -> void:
	# All debugging and print calls route through here
	print("[AgentController] %s" % msg)
