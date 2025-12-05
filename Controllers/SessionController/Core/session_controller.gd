class_name SessionController
extends Node

# Central manager for session & state; routes signals among feature controllers

# Preloads to avoid circular dependencies
const HexGridControllerScript = preload("res://Controllers/HexGridController/Core/hex_grid_controller.gd")
const NavigationControllerScript = preload("res://Controllers/NavigationController/Core/navigation_controller.gd")
const DebugControllerScript = preload("res://Controllers/DebugController/Core/debug_controller.gd")
const UIControllerScript = preload("res://Controllers/UIController/Controller/UIController.gd")
const SelectionControllerScript = preload("res://Controllers/SelectionController/Core/selection_controller.gd")
const AgentControllerScript = preload("res://Controllers/AgentController/Core/agent_controller.gd")

# ========== SIGNALS ==========
signal session_initialized()
signal session_started()
signal session_ended()
signal terrain_initialized()
signal turn_changed(agent_data)
signal navigable_cells_updated(cells: Array[HexCell])

# Selection signals (mediated from SelectionController)
signal selection_changed(selection_data: Dictionary)
signal selection_cleared()

# IO signals (mediated from IOController)
signal cell_clicked(cell: HexCell)
signal cell_right_clicked(cell: HexCell)
signal cell_hovered(cell: HexCell)
signal cell_hover_ended()

# ========== CONFIGURATION / EXPORTS ==========
@export_group("Grid")
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var auto_initialize: bool = true

@export_group("Navigation")
@export var navigation_region: NavigationRegion2D
@export var integrate_with_navmesh: bool = true
@export var navmesh_sample_points: int = 5

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true

@export_group("Agents")
const MAX_AGENTS: int = 4
var number_of_agents: int = 4 # Testing default
@export var max_movements_per_turn: int = 10
@export var spawn_agents_on_init: bool = true

# ========== STATE ==========
var agents: Array = []
var current_agent_index: int = 0
var session_active: bool = false
var session_start_time: float = 0.0

var _session_state := {}
var _grid_state := {}
var _navigation_state := {}
var navigable_cells: Array[HexCell] = []
var current_agent_cell: HexCell = null

# Planned movement state (for path preview before execution)
var planned_target_cell: HexCell = null
var planned_path: Array = []
var planned_agent = null

# ========== CONTROLLER INSTANCES ==========
var hex_grid_controller
var navigation_controller
var debug_controller
var ui_controller
var selection_controller
var agent_manager
var io_controller

# ========== LIFECYCLE ==========
func _ready() -> void:
	_print_header("SessionController READY")
	_init_all_controllers()
	connect_signals_all()
	if auto_initialize:
		await get_tree().process_frame
		initialize_session()

# Note: Input handling moved to _input() method to intercept SPACE before KeyboardInputHandler
# This ensures SessionController sees key presses first and can consume them if needed

func _init_all_controllers() -> void:
	hex_grid_controller = _try_new(HexGridControllerScript, "HexGridController")
	navigation_controller = _try_new(NavigationControllerScript, "NavigationController")
	debug_controller = _try_new(DebugControllerScript, "DebugController", {"session_controller": self})
	ui_controller = _try_new(UIControllerScript, "UIController")
	selection_controller = _try_new(SelectionControllerScript, "SelectionController")
	agent_manager = _try_new(AgentControllerScript, "AgentController", {
		"agent_count": number_of_agents,
		"max_movements_per_turn": max_movements_per_turn
	})

	# Note: IOController is managed by main.gd and will be connected later
	# via connect_io_controller() after it's created

func _try_new(script: Resource, item_name: String, props := {}) -> Node:
	if typeof(script) == TYPE_OBJECT:
		var node = script.new()
		node.name = item_name
		for k in props: node.set(k, props[k])
		add_child(node)
		return node
	push_error("Failed to create %s!" % name)
	return null

func connect_io_controller(io_ctrl) -> void:
	"""Connect IOController signals (called by main.gd after IOController is created)"""
	io_controller = io_ctrl
	if io_controller:
		io_controller.hex_cell_left_clicked.connect(_on_cell_left_clicked)
		io_controller.hex_cell_right_clicked.connect(_on_cell_right_clicked)
		io_controller.hex_cell_hovered.connect(_on_cell_hovered)
		io_controller.hex_cell_hover_ended.connect(_on_cell_hover_ended)
		_print_debug("IOController connected to SessionController")

func connect_signals_all() -> void:
		# --- HexGridController
		hex_grid_controller.grid_initialized.connect(_on_grid_initialized)
		hex_grid_controller.cell_state_changed.connect(_on_cell_state_changed)
		hex_grid_controller.grid_stats_changed.connect(_on_grid_stats_changed)
		hex_grid_controller.cell_at_position_response.connect(_route_to_navigation_controller)
		hex_grid_controller.distance_calculated.connect(_route_distance_to_navigation)
		hex_grid_controller.cells_in_range_response.connect(_route_cells_to_navigation)
		# --- NavigationController
		navigation_controller.path_found.connect(_on_path_found)
		navigation_controller.path_not_found.connect(_on_path_not_found)
		navigation_controller.navigation_started.connect(_on_navigation_started)
		navigation_controller.navigation_completed.connect(_on_navigation_completed)
		navigation_controller.navigation_failed.connect(_on_navigation_failed)
		navigation_controller.waypoint_reached.connect(_on_waypoint_reached)
		navigation_controller.navigation_state_changed.connect(_on_navigation_state_changed)
		navigation_controller.query_cell_at_position.connect(_route_to_hex_grid_controller)
		# --- DebugController
		debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
		debug_controller.debug_info_updated.connect(_on_debug_info_updated)
		# --- UIController
		ui_controller.ui_visibility_changed.connect(_on_ui_visibility_changed)
		ui_controller.selected_item_changed.connect(_on_selected_item_changed)
		turn_changed.connect(ui_controller._on_turn_changed)
		# --- SelectionController
		selection_controller.object_selected.connect(_on_object_selected)
		selection_controller.selection_cleared.connect(_on_selection_cleared)
		# --- IOController: Connected later via connect_io_controller() called by main.gd
		# --- AgentController signals are connected in _init_and_spawn_agents()


# ========== SESSION MANAGEMENT ==========
func set_party_size(count: int) -> void:
	number_of_agents = clamp(count, 1, MAX_AGENTS)
	if agent_manager:
		agent_manager.agent_count = number_of_agents
	_print_debug("Party size set: %d" % number_of_agents)

func initialize_session() -> void:
	_print_header("SessionController: INITIALIZATION")

	var grid_offset = _align_grid_with_navmesh()
	await _wait_for_grid_init(grid_offset)

	var grid = hex_grid_controller.get_hex_grid()
	if grid:
		navigation_controller.initialize(grid, null)
	else:
		abort_session("[ERROR] Grid is null during navigation init")

	await _integrate_navmesh_if_needed()
	_init_and_spawn_agents()
	_setup_debug_visuals()
	
	debug_controller.set_debug_visibility_requested.emit(debug_mode)
	# Note: SelectionController no longer needs direct UIController reference
	# All communication now routed through SessionController signals

	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	_update_session_state()

	terrain_initialized.emit()
	session_started.emit()
	session_initialized.emit()
	_print_stats()

func abort_session(msg: String) -> void:
	push_error(msg)
	_reset_agents()
	session_active = false

func _wait_for_grid_init(grid_offset: Vector2) -> void:
	var state = {"done": false}
	var signal_handler = func(_data): state.done = true
	hex_grid_controller.grid_initialized.connect(signal_handler, CONNECT_ONE_SHOT)

	var start_time = Time.get_ticks_msec()
	const TIMEOUT_MS = 5000  # 5 second timeout

	hex_grid_controller.initialize_grid_requested.emit(grid_width, grid_height, hex_size, grid_offset)

	while not state.done:
		var elapsed = Time.get_ticks_msec() - start_time
		if elapsed > TIMEOUT_MS:
			# Timeout occurred - disconnect signal handler and abort
			if hex_grid_controller.grid_initialized.is_connected(signal_handler):
				hex_grid_controller.grid_initialized.disconnect(signal_handler)
			abort_session("[ERROR] Grid initialization timeout after %.1f seconds" % (TIMEOUT_MS / 1000.0))
			return
		await get_tree().process_frame

func _align_grid_with_navmesh() -> Vector2:
	if integrate_with_navmesh and navigation_region and navigation_region.navigation_polygon:
		var bounds := _calculate_navmesh_bounds(navigation_region.navigation_polygon)
		return navigation_region.global_position + bounds.position if bounds.size.x > 0 else Vector2.ZERO
	return Vector2.ZERO

func _integrate_navmesh_if_needed() -> void:
	if not integrate_with_navmesh or not navigation_region:
		return

	# Use signal-based blocking to wait for integration to complete
	# navmesh_integration_complete is emitted ONLY after navmesh integration finishes
	var state = {"done": false}
	var signal_handler = func(_stats): state.done = true
	hex_grid_controller.navmesh_integration_complete.connect(signal_handler, CONNECT_ONE_SHOT)

	var start_time = Time.get_ticks_msec()
	const TIMEOUT_MS = 10000  # 10 second timeout (navmesh integration can be slower)

	hex_grid_controller.integrate_navmesh_requested.emit(navigation_region, navmesh_sample_points)

	# Block until navmesh integration actually completes or timeout
	while not state.done:
		var elapsed = Time.get_ticks_msec() - start_time
		if elapsed > TIMEOUT_MS:
			# Timeout occurred - disconnect signal handler and abort
			if hex_grid_controller.navmesh_integration_complete.is_connected(signal_handler):
				hex_grid_controller.navmesh_integration_complete.disconnect(signal_handler)
			abort_session("[ERROR] Navmesh integration timeout after %.1f seconds" % (TIMEOUT_MS / 1000.0))
			return
		await get_tree().process_frame

func _init_and_spawn_agents() -> void:
	number_of_agents = SessionData.get_total_agent_count()
	var agent_grid = hex_grid_controller.get_hex_grid()
	if not agent_grid:
		abort_session("No grid for agent initialization")
		return

	agent_manager.initialize(self)

	# Connect agent_manager signals to SessionController handlers
	agent_manager.agents_spawned.connect(_on_agents_spawned)
	agent_manager.agent_turn_started.connect(_on_agent_turn_started)
	agent_manager.agent_turn_ended.connect(_on_agent_turn_ended)
	agent_manager.all_agents_completed_round.connect(_on_all_agents_completed_round)
	agent_manager.movement_action_completed.connect(_on_movement_action_completed)

	if spawn_agents_on_init:
		agent_manager.spawn_agents(number_of_agents)
		agents = agent_manager.get_all_agents()
		if agents.size() != number_of_agents or not _validate_agents_array("after spawn"):
			abort_session("[ERROR] Agent init failed")
		if agents.size() > MAX_AGENTS:
			agents = agents.slice(0, MAX_AGENTS)
		current_agent_index = 0
	else:
		_reset_agents()

func _setup_debug_visuals() -> void:
	var grid = hex_grid_controller.get_hex_grid()
	if not grid: return
	var d = HexGridDebug.new()
	d.name = "HexGridDebug"
	d.hex_grid = grid
	d.session_controller = self
	d.debug_enabled = debug_mode
	hex_grid_controller.add_child(d)
	debug_controller.set_hex_grid_debug(d)
	var hover = HexCellHoverVisualizer.new()
	hover.name = "HexCellHoverVisualizer"
	hover.hex_grid = grid
	hover.session_controller = self
	hover.hover_enabled = not debug_mode
	hex_grid_controller.add_child(hover)
	debug_controller.set_hex_cell_hover_visualizer(hover)
	var path_visualizer = navigation_controller.get_path_visualizer()
	if path_visualizer:
		debug_controller.set_hex_path_visualizer(path_visualizer)

# ========== GRID SERVICE METHODS (for AgentController) ==========
## Get random enabled hex cell
func get_random_enabled_cell() -> HexCell:
	var agent_grid = hex_grid_controller.get_hex_grid()
	if not agent_grid:
		return null

	var enabled_cells: Array = agent_grid.enabled_cells
	if enabled_cells.is_empty():
		return null

	var random_index: int = randi() % enabled_cells.size()
	return enabled_cells[random_index]

## Get distance between two hex cells
func get_hex_distance(cell_a: HexCell, cell_b: HexCell) -> int:
	var agent_grid = hex_grid_controller.get_hex_grid()
	if agent_grid:
		return agent_grid.get_distance(cell_a, cell_b)
	return 0

## Get hex cell at world position
func get_cell_at_world_position(world_pos: Vector2) -> HexCell:
	var agent_grid = hex_grid_controller.get_hex_grid()
	if agent_grid:
		return agent_grid.get_cell_at_world_position(world_pos)
	return null

## Configure agent's hex navigation
func configure_agent_navigation(agent_node: Node) -> void:
	var agent_grid = hex_grid_controller.get_hex_grid()
	if not agent_grid or not navigation_controller:
		push_warning("[SessionController] Cannot configure agent navigation - missing grid or nav controller")
		return

	var pathfinder = navigation_controller.get_pathfinder()
	if not pathfinder:
		push_warning("[SessionController] Cannot configure agent navigation - missing pathfinder")
		return

	if agent_node.has_method("set_hex_navigation"):
		agent_node.set_hex_navigation(agent_grid, pathfinder)
		if OS.is_debug_build():
			print("[SessionController] Configured hex navigation for agent")
	else:
		push_warning("[SessionController] Agent does not have set_hex_navigation method")

func _reset_agents():
	agents = []
	current_agent_index = 0

func end_session() -> void:
	if session_active:
		session_active = false
		hex_grid_controller.clear_grid_requested.emit()
		navigation_controller.cancel_navigation_requested.emit()
		_update_session_state()
		session_ended.emit()

func reset_session() -> void:
	end_session()
	await get_tree().process_frame
	initialize_session()

# ========== VALIDATION ==========
func _validate_agent_ref(agent, idx := -1, ctx := "") -> bool:
	# Agents array contains AgentData objects, not CharacterBody2D
	if !agent or !is_instance_valid(agent):
		printerr("[SessionController] Invalid agent ref at %d (%s)" % [idx, ctx])
		return false

	# Check if it's AgentData with a valid controller
	if agent is AgentData:
		var controller = agent.agent_controller
		if !controller or !is_instance_valid(controller) or not controller is CharacterBody2D:
			printerr("[SessionController] Invalid agent controller at %d (%s)" % [idx, ctx])
			return false
		return true

	# Legacy support: Direct CharacterBody2D reference
	if agent is CharacterBody2D:
		return true

	printerr("[SessionController] Unknown agent type at %d (%s): %s" % [idx, ctx, typeof(agent)])
	return false

func _validate_agents_array(ctx := "agents array assignment") -> bool:
	for i in agents.size():
		if not _validate_agent_ref(agents[i], i, ctx): return false
	return agents.size() > 0

# ========== SIGNAL ROUTING ==========
func _route_to_navigation_controller(request_id: String, cell: HexCell): navigation_controller.on_cell_at_position_response.emit(request_id, cell)
func _route_distance_to_navigation(_req: String, _dist: int): pass
func _route_cells_to_navigation(_req: String, _cells: Array[HexCell]): pass
func _route_to_hex_grid_controller(request_id: String, world_pos: Vector2): hex_grid_controller.request_cell_at_position.emit(request_id, world_pos)

# ========== EVENT HANDLERS ==========
func _on_grid_initialized(data: Dictionary): _grid_state = data; debug_controller.on_grid_state_changed.emit(data)
func _on_cell_state_changed(_coords: Vector2i, _en: bool): pass
func _on_grid_stats_changed(stats: Dictionary): _grid_state.merge(stats, true); debug_controller.on_grid_state_changed.emit(_grid_state)
func _on_path_found(_st: HexCell, _go: HexCell, path: Array[HexCell], dur: float): _print_debug("Path found: %d cells in %.2f ms" % [path.size(), dur])
func _on_path_not_found(_sp: Vector2, _gp: Vector2, reason: String): _print_debug("Path not found %s" % reason)
func _on_navigation_started(tgt: HexCell): _print_debug("Navigation started %s" % tgt)
func _on_navigation_completed(): _print_debug("Navigation completed")
func _on_navigation_failed(reason: String): _print_debug("Navigation failed: %s" % reason)
func _on_waypoint_reached(_cell: HexCell, _idx: int, _rem: int): pass
func _on_navigation_state_changed(active: bool, plen: int, remain: int):
	_navigation_state = {"active": active, "path_length": plen, "remaining_distance": remain}
	debug_controller.on_navigation_state_changed.emit(_navigation_state)
func _on_debug_visibility_changed(vis: bool): debug_mode = vis; _print_debug("Debug %s" % ("ON" if vis else "OFF"))
func _on_debug_info_updated(_k: String, _v: Variant): pass
func _on_ui_visibility_changed(vis: bool): _print_debug("UI overlay %s" % ("shown" if vis else "hidden"))
func _on_selected_item_changed(d: Dictionary): if d.get("has_selection", false): _print_debug("Selected: %s [%s]" % [d.get("item_name", "Unknown"), d.get("item_type", "Unknown")])
func _on_object_selected(sel: Dictionary):
	_print_debug("Object selected: %s" % sel.get("item_name"))
	# Relay to UIController through signal
	if ui_controller:
		ui_controller.update_selected_item_requested.emit(sel)
	# Emit for other features to listen
	selection_changed.emit(sel)

func _on_selection_cleared():
	_print_debug("Selection cleared")
	# Relay to UIController through signal
	if ui_controller:
		ui_controller.clear_selected_item_requested.emit()
	# Emit for other features to listen
	selection_cleared.emit()

# IOController signal handlers
func _on_cell_left_clicked(cell: HexCell):
	_print_debug("Cell clicked: %s" % cell.get_coords())

	# Select the hex cell (shows in UI)
	if selection_controller and cell:
		selection_controller.select_object(cell)

	# Plan movement and preview path (DON'T execute yet)
	if navigation_controller and cell and agent_manager:
		var agent = agent_manager.get_active_agent()
		if agent:
			_plan_movement_to_cell(agent, cell)

	# Emit for other features to listen
	cell_clicked.emit(cell)

func _on_cell_right_clicked(cell: HexCell):
	_print_debug("Cell right-clicked: %s" % cell.get_coords())
	# Emit for features to listen
	cell_right_clicked.emit(cell)

func _on_cell_hovered(cell: HexCell):
	# Route to debug for hover display (existing behavior from main.gd)
	if debug_controller and cell:
		debug_controller.set_hovered_cell(cell)
	# Emit for other features to listen
	cell_hovered.emit(cell)

func _on_cell_hover_ended():
	# Route to debug controller
	if debug_controller:
		debug_controller.set_hovered_cell(null)
	# Emit for features to listen
	cell_hover_ended.emit()

# Method for selectable objects to call
func report_object_selected(selected_object):
	"""Called by selectable objects to report selection through SessionController"""
	if selection_controller:
		selection_controller.select_object(selected_object)

# ============================================================================
# MOVEMENT PLANNING & EXECUTION
# ============================================================================

func _plan_movement_to_cell(agent: AgentData, target_cell: HexCell):
	"""Plan movement and show path preview (doesn't execute movement)"""
	if not agent or not target_cell:
		return

	_print_debug("Planning movement to cell (%d, %d)" % [target_cell.q, target_cell.r])

	# Check if cell is enabled/navigable
	if not target_cell.enabled:
		_print_debug("Cannot plan movement: target cell is disabled")
		planned_target_cell = null
		planned_path = []
		planned_agent = null
		return

	# Check if agent can move
	if not agent.can_move():
		_print_debug("Cannot plan movement: agent has no movements remaining")
		planned_target_cell = null
		planned_path = []
		planned_agent = null
		return

	# Store planned movement
	planned_target_cell = target_cell
	planned_agent = agent

	# Calculate and visualize path preview
	if navigation_controller and hex_grid_controller:
		# Get agent's current cell using agent_controller's position
		var agent_controller = agent.agent_controller
		if not agent_controller:
			_print_debug("Cannot plan movement: agent controller not found")
			return

		# Use SessionController's helper method to get cell from world position
		var agent_cell = get_cell_at_world_position(agent_controller.global_position)
		if agent_cell:
			var distance = agent_cell.distance_to(target_cell)
			var max_distance = agent.get_distance_remaining() if agent.has_method("get_distance_remaining") else agent.max_movements_per_turn

			_print_debug("Path preview: %d cells, agent can move %d cells" % [distance, max_distance])

			# Calculate path using pathfinder
			var pathfinder = navigation_controller.get_pathfinder()
			if pathfinder:
				planned_path = pathfinder.find_path(agent_cell, target_cell)

				if planned_path.size() > 0:
					# Check if path exceeds agent's movement budget
					# Path includes starting cell, so distance is size - 1
					var path_distance = planned_path.size() - 1

					if path_distance > max_distance:
						_print_debug("Path too long (%d cells), truncating to %d cells" % [path_distance, max_distance])
						# Truncate path to fit within budget (keep starting cell + max_distance cells)
						planned_path = planned_path.slice(0, max_distance + 1)
						# Update target cell to the truncated end point
						planned_target_cell = planned_path[planned_path.size() - 1]
						_print_debug("Truncated path to cell (%d, %d)" % [planned_target_cell.q, planned_target_cell.r])

					# Visualize the (possibly truncated) path
					var path_visualizer = navigation_controller.get_path_visualizer()
					if path_visualizer:
						path_visualizer.set_path(planned_path)

					_print_debug("Movement planned! Press SPACE to execute or click another cell to re-plan")
				else:
					_print_debug("No path found to target cell")
					planned_target_cell = null
					planned_path = []
					planned_agent = null

func execute_planned_movement():
	"""Execute the planned movement (call this from hotkey)"""
	if not planned_target_cell or not planned_agent or planned_path.is_empty():
		_print_debug("No planned movement to execute")
		return

	_print_debug("Executing planned movement to (%d, %d)" % [planned_target_cell.q, planned_target_cell.r])

	# Calculate the distance of the planned path (in meters/hex cells)
	# Path includes starting cell, so distance is size - 1
	var path_distance = planned_path.size() - 1
	_print_debug("Planned path distance: %d meters" % path_distance)

	# Record the movement action with AgentController BEFORE executing
	# This deducts the distance from the agent's remaining movement
	if agent_manager:
		if not agent_manager.record_movement_action(path_distance):
			_print_debug("Cannot execute movement: insufficient movement remaining or record failed")
			cancel_planned_movement()
			return
	else:
		_print_debug("Cannot execute movement: agent_manager not found")
		cancel_planned_movement()
		return

	# Get the actual agent controller (CharacterBody2D) from AgentData
	var agent_controller = planned_agent.agent_controller
	if not agent_controller:
		_print_debug("Cannot execute movement: agent controller not found")
		cancel_planned_movement()
		return

	# Get the agent's turn-based controller
	var turn_based_controller = agent_controller.turn_based_controller
	if not turn_based_controller:
		_print_debug("Cannot execute movement: turn_based_controller not found on agent")
		cancel_planned_movement()
		return

	# Ensure turn-based controller is fully activated before requesting movement
	# This prevents race condition where request_movement_to() is called before
	# activate() has settled and set is_active = true
	if not turn_based_controller.is_active:
		_print_debug("Waiting for turn_based_controller activation...")
		await get_tree().process_frame

	# Connect to movement_completed signal to notify AgentController when done
	# Use a one-shot connection that captures the agent data
	var agent_data = planned_agent
	var completion_handler = func(distance_moved: int):
		_print_debug("Movement completed: %d meters" % distance_moved)
		if agent_manager:
			agent_manager.update_agent_position_after_movement(agent_data)

	if not turn_based_controller.movement_completed.is_connected(completion_handler):
		turn_based_controller.movement_completed.connect(completion_handler, CONNECT_ONE_SHOT)

	# Request movement to the target cell's world position
	# Use path_distance (how far we want to move) not remaining_distance (what's left after recording)
	turn_based_controller.request_movement_to(planned_target_cell.world_position, path_distance)

	# Wait one frame to allow state transition, then confirm
	await get_tree().process_frame

	# Confirm the movement (starts execution)
	turn_based_controller.confirm_movement()

	_print_debug("Movement execution started!")

	# Clear planned movement
	planned_target_cell = null
	planned_path = []
	planned_agent = null

func cancel_planned_movement():
	"""Cancel the planned movement"""
	if planned_target_cell:
		_print_debug("Planned movement cancelled")

	planned_target_cell = null
	planned_path = []
	planned_agent = null

	# Clear path visualization
	if navigation_controller:
		var path_visualizer = navigation_controller.get_path_visualizer()
		if path_visualizer:
			path_visualizer.clear_path()

func _on_agents_spawned(count: int): _print_debug("%d agents spawned" % count)
func _on_agent_turn_started(data: AgentData):
	_print_debug("%s turn started" % data.agent_name)

	# Clear any planned movement from previous agent's turn
	if planned_target_cell or planned_agent or not planned_path.is_empty():
		_print_debug("Clearing planned movement from previous turn")
		cancel_planned_movement()

	update_navigable_cells(data)
	var turn_info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": data.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": data.get_movements_remaining() if data.has_method("get_movements_remaining") else data.max_movements_per_turn,
		"actions_left": data.get_actions_remaining() if data.has_method("get_actions_remaining") else "-"
	}
	turn_changed.emit(turn_info)
	if OS.is_debug_build():
		print("[SessionController] Emitting turn_changed: %s" % str(turn_info))

func _on_agent_turn_ended(data: AgentData):
	_print_debug("%s turn ended (used %d)" % [data.agent_name, data.movements_used_this_turn])

	# Clear planned movement when turn ends
	if planned_target_cell or planned_agent or not planned_path.is_empty():
		_print_debug("Clearing planned movement at turn end")
		cancel_planned_movement()
func _on_all_agents_completed_round():
	_print_debug("All agents completed round")

	# Clear any lingering planned movement at round end
	if planned_target_cell or planned_agent or not planned_path.is_empty():
		_print_debug("Clearing planned movement at round end")
		cancel_planned_movement()
func _on_movement_action_completed(data: AgentData, moves: int):
	# Update navigable cells to reflect remaining distance
	update_navigable_cells(data)

	turn_changed.emit({
		"turn_number": agent_manager.current_round + 1,
		"agent_name": data.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": moves,
		"actions_left": data.get_actions_remaining() if data.has_method("get_actions_remaining") else "-"
	})
	_print_debug("%s moved (%d m left)" % [data.agent_name, moves])

# ========== TURN HANDLING ==========
func advance_turn() -> void:
	if agents.size() == 0:
		push_error("No agents available for turn cycling."); return
	var current_agent = agents[current_agent_index]
	navigation_controller.set_active_agent(current_agent)
	agent_manager.start_agent_turn(current_agent)
	_print_debug("advance_turn: Agent %s" % current_agent.name)
	current_agent_index = (current_agent_index + 1) % agents.size()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# Handle SPACE key in _input() to intercept BEFORE KeyboardInputHandler's _unhandled_input()
	if event.keycode == KEY_SPACE:
		# Only consume input if we have planned movement to execute
		if planned_target_cell and planned_agent and not planned_path.is_empty():
			execute_planned_movement()
			get_viewport().set_input_as_handled()
			return  # Input consumed - won't reach KeyboardInputHandler
		# else: let input propagate to KeyboardInputHandler for end turn

	# ESC key - Cancel planned movement
	elif event.keycode == KEY_ESCAPE:
		cancel_planned_movement()
		get_viewport().set_input_as_handled()

	# F3 debug toggle
	elif debug_hotkey_enabled and event.keycode == KEY_F3:
		debug_controller.toggle_debug_requested.emit()
		get_viewport().set_input_as_handled()

# ========== PUBLIC ACCESSORS ==========
func get_session_state() -> Dictionary: return _session_state.duplicate()
func get_grid_state() -> Dictionary: return _grid_state.duplicate()
func get_navigation_state() -> Dictionary: return _navigation_state.duplicate()
func is_session_active() -> bool: return session_active
func get_session_duration() -> float: return (Time.get_ticks_msec() / 1000.0) - session_start_time if session_active else 0.0
func get_current_turn() -> int: return (current_agent_index + 1) if agents.size() > 0 else 0
func get_total_turns() -> int: return agents.size()
func get_current_turn_agent() -> Variant: return agents[current_agent_index] if agents.size() > 0 else null

# ========== NAVIGABLE CELLS ==========
func update_navigable_cells(agent) -> void:
	navigable_cells.clear()
	var cur_agent = agent if agent else get_current_turn_agent()

	if not cur_agent:
		_print_debug("update_navigable_cells: No current agent")
		navigable_cells_updated.emit(navigable_cells)
		return

	if not hex_grid_controller:
		_print_debug("update_navigable_cells: No hex_grid_controller")
		navigable_cells_updated.emit(navigable_cells)
		return

	var grid = hex_grid_controller.get_hex_grid()
	if not grid:
		_print_debug("update_navigable_cells: No grid")
		navigable_cells_updated.emit(navigable_cells)
		return

	current_agent_cell = _resolve_agent_cell(cur_agent, grid)
	if not current_agent_cell:
		_print_debug("update_navigable_cells: Could not resolve agent cell for %s at %s" % [
			cur_agent.agent_name if cur_agent.get("agent_name") else "unknown",
			cur_agent.current_position if cur_agent.get("current_position") else "unknown position"
		])
		navigable_cells_updated.emit(navigable_cells)
		return

	# Get agent's remaining distance for this turn
	var remaining_distance = int(cur_agent.get_distance_remaining()) if cur_agent.has_method("get_distance_remaining") else MovementConstants.MAX_MOVEMENT_DISTANCE

	if remaining_distance <= 0:
		_print_debug("update_navigable_cells: Agent has no remaining distance")
		navigable_cells_updated.emit(navigable_cells)
		return

	# Three-layer system for navigable cells:
	# Layer 1: Cell must be enabled (within navmesh) - handled by get_enabled_cells_in_range
	# Layer 2: Cell must be within hex cell range (accounting for obstacles)
	#         Distance is measured in hex cells (each cell = 1 meter)
	#         Using conservative multiplier since actual paths around obstacles can be 1.5-2x longer
	#         Movement budget: Based on agent's REMAINING distance this turn
	#         Conservative filter: 2x remaining distance
	# Layer 3: Cell must have a valid A* path within the agent's remaining movement budget
	const HEX_DISTANCE_MULTIPLIER = 2.0 # Account for paths around obstacles
	var max_hex_range = int(remaining_distance * HEX_DISTANCE_MULTIPLIER)
	var candidates = grid.get_enabled_cells_in_range(current_agent_cell, max_hex_range)

	# Get pathfinder for Layer 3 validation
	var pathfinder = navigation_controller.get_pathfinder()
	if not pathfinder:
		_print_debug("update_navigable_cells: No pathfinder for Layer 3 validation")
		navigable_cells_updated.emit(navigable_cells)
		return

	# Layer 3: Validate that A* can find a path within remaining movement budget
	for cell in candidates:
		if cell == current_agent_cell:
			# Agent's current cell is always navigable
			navigable_cells.append(cell)
		else:
			# Check if pathfinding can reach this cell
			var path = pathfinder.find_path(current_agent_cell, cell)
			if path.size() > 0:
				# Distance is measured in hex cells (each cell = 1 meter)
				# Subtract 1 because the path includes the starting cell
				var path_distance_meters = path.size() - 1

				# Only mark as navigable if within REMAINING movement budget
				if path_distance_meters <= remaining_distance:
					navigable_cells.append(cell)

	navigable_cells_updated.emit(navigable_cells)
	debug_controller.update_debug_info_requested.emit("navigable_cells_count", navigable_cells.size())
	debug_controller.update_debug_info_requested.emit("current_agent_cell_q", current_agent_cell.q if current_agent_cell else -1)
	debug_controller.update_debug_info_requested.emit("current_agent_cell_r", current_agent_cell.r if current_agent_cell else -1)
	_print_debug("Navigable cells: %d candidates -> %d within %d m remaining budget" % [candidates.size(), navigable_cells.size(), remaining_distance])

func _resolve_agent_cell(agent, grid) -> HexCell:
	# First check if agent has current_cell directly
	if agent.get("current_cell") != null:
		return agent.current_cell

	# Try to get controller reference (AgentData uses 'agent_controller')
	var ctrl = agent.get("agent_controller")
	if ctrl:
		# Check if controller has current_cell
		if ctrl.get("current_cell") != null:
			return ctrl.current_cell
		# Fallback: get cell from controller's world position
		if ctrl.get("global_position") != null:
			return grid.get_cell_at_world_position(ctrl.global_position)

	return null

func is_cell_navigable(cell: HexCell) -> bool: return navigable_cells.has(cell)
func get_navigable_cells() -> Array[HexCell]: return navigable_cells

# ========== BACKWARD COMPAT ==========
func get_terrain(): return hex_grid_controller.get_hex_grid() if hex_grid_controller else null
func get_hex_grid_controller(): return hex_grid_controller
func get_navigation_controller(): return navigation_controller
func get_debug_controller(): return debug_controller
func get_ui_controller(): return ui_controller
func get_selection_controller(): return selection_controller
func get_agent_manager(): return agent_manager

# ========== PUBLIC SHORTCUTS ==========
func disable_terrain_at_position(world_pos: Vector2, radius: int = 1): hex_grid_controller.set_cells_in_area_requested.emit(world_pos, radius, false)
func enable_terrain_at_position(world_pos: Vector2, radius: int = 1): hex_grid_controller.set_cells_in_area_requested.emit(world_pos, radius, true)
func navigate_to_position(target_pos: Vector2): navigation_controller.navigate_to_position_requested.emit(target_pos)
func calculate_path(start_pos: Vector2, goal_pos: Vector2):
	var req = "path_" + str(Time.get_ticks_msec())
	navigation_controller.calculate_path_requested.emit(req, start_pos, goal_pos)
func set_debug_mode(enabled: bool): debug_controller.set_debug_visibility_requested.emit(enabled)
func toggle_debug_mode(): debug_controller.toggle_debug_requested.emit()
func refresh_navmesh_integration():
	hex_grid_controller.refresh_navmesh_integration()
	_print_debug("Navmesh integration refreshed")

# ========== HELPERS ==========
func _calculate_navmesh_bounds(nav_poly: NavigationPolygon) -> Rect2:
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	for i in nav_poly.get_outline_count():
		var outline = nav_poly.get_outline(i)
		for v in outline:
			min_pos = min_pos.min(v)
			max_pos = max_pos.max(v)
	if min_pos.x == INF: push_warning("NavigationPolygon has no vertices"); return Rect2()
	return Rect2(min_pos, max_pos - min_pos)

func _update_session_state() -> void:
	_session_state = {
		"active": session_active,
		"duration": get_session_duration(),
		"start_time": session_start_time
	}
	debug_controller.on_session_state_changed.emit(_session_state)

func _print_debug(msg): if OS.is_debug_build(): print("[SessionController] %s" % msg)

func _print_header(msg):
	if OS.is_debug_build():
		print("\n" + "━".repeat(60))
		print(msg)
		print("━".repeat(60))

func _print_stats() -> void:
	if not OS.is_debug_build(): return
	print("\n" + "=".repeat(60))
	print("SESSION CONTROLLER - Signal-Based Architecture")
	print("=".repeat(60))
	print("Controllers: HexGrid ✓, Navigation ✓, Debug ✓, UI ✓, Selection ✓")
	print("Grid: %dx%d, Hex Size: %.1f, Total: %d, Enabled: %d, Disabled: %d" % [
		grid_width, grid_height, hex_size, _grid_state.get("total_cells", 0),
		_grid_state.get("enabled_cells", 0), _grid_state.get("disabled_cells", 0)
	])
	print("Session: Active: %s, Debug: %s, Navmesh: %s" % [
		session_active, debug_mode, integrate_with_navmesh
	])
	print("=".repeat(60))
