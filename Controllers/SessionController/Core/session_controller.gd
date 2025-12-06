"""
SessionController.gd

Core manager for the entire game session. Handles initialization, controller setup, game turn management,
signal routing, and main session lifecycle functions (start, end, reset, etc.). Binds together grid,
navigation, debug, UI, selection, and agent management.

Provides the main interface for other systems to interact with the session's state.

Signals are emitted for session and turn events, cell interactions, and selection changes.
"""

class_name SessionController
extends Node2D

# --- Preloads for controllers ---
const HexGridControllerScript = preload("res://Controllers/HexGridController/Core/hex_grid_controller.gd")
const NavigationControllerScript = preload("res://Controllers/NavigationController/Core/navigation_controller.gd")
const DebugControllerScript = preload("res://Controllers/DebugController/Core/debug_controller.gd")
const UIControllerScript = preload("res://Controllers/UIController/Controller/UIController.gd")
const SelectionControllerScript = preload("res://Controllers/SelectionController/Core/selection_controller.gd")
const AgentControllerScript = preload("res://Controllers/AgentController/Core/agent_controller.gd")

# --- Signals for session and UI events ---
signal session_initialized()
signal session_ended()
signal turn_changed(agent_data)
signal navigable_cells_updated(cells: Array[HexCell])
signal selection_changed(selection_data: Dictionary)
signal selection_cleared()
signal cell_clicked(cell: HexCell)
signal cell_right_clicked(cell: HexCell)
signal cell_hovered(cell: HexCell)
signal cell_hover_ended()

# --- Exported properties grouped by category for editing in Godot editor ---
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
var number_of_agents: int = 4
@export var max_movements_per_turn: int = 10
@export var spawn_agents_on_init: bool = true

# --- Core session state ---
var agents: Array = []
var current_agent_index: int = 0
var session_active: bool = false
var session_start_time: float = 0.0
var navigable_cells: Array[HexCell] = []

# --- Controller references ---
var hex_grid_controller = null
var navigation_controller = null
var debug_controller = null
var ui_controller = null
var selection_controller = null
var agent_manager = null
var io_controller = null

# --- Core helper instances ---
var _initializer: SessionInitializer = SessionInitializer.new()
var _movement_planner: MovementPlanner = MovementPlanner.new()
var _input_handler: SessionInputHandler = SessionInputHandler.new()
var _event_router: EventRouter = EventRouter.new()
var _nav_calculator: NavigableCellsCalculator = NavigableCellsCalculator.new()

## Called when the node is added to the scene.
func _ready() -> void:
	y_sort_enabled = true
	_init_all_controllers()
	_init_packages()
	_connect_signals()
	if auto_initialize:
		await get_tree().process_frame
		initialize_session()

## Instantiate and add all necessary controller nodes as children.
func _init_all_controllers() -> void:
	hex_grid_controller = _try_new(HexGridControllerScript, "HexGridController")
	navigation_controller = _try_new(NavigationControllerScript, "NavigationController")
	debug_controller = _try_new(DebugControllerScript, "DebugController", {"session_controller": self})
	ui_controller = _try_new(UIControllerScript, "UIController")
	selection_controller = _try_new(SelectionControllerScript, "SelectionController")
	agent_manager = _try_new(AgentControllerScript, "AgentController", {
		"agent_count": number_of_agents,
		"max_movements_per_turn": max_movements_per_turn,
		"y_sort_enabled": true
	})

## Configure helper instances with appropriate controllers.
func _init_packages() -> void:
	_initializer.configure(hex_grid_controller, navigation_controller, agent_manager, debug_controller)
	_movement_planner.configure(navigation_controller, hex_grid_controller, agent_manager)
	_input_handler.configure(_movement_planner, debug_hotkey_enabled)

## Instantiate a node from a script and add to scene tree, optionally set properties.
func _try_new(script: Resource, item_name: String, props := {}) -> Node:
	if typeof(script) != TYPE_OBJECT:
		push_error("Failed to create %s!" % item_name)
		return null
	var node = script.new()
	if node == null:
		push_error("Failed to instantiate %s: script.new() returned null" % item_name)
		return null
	node.name = item_name
	for k in props:
		node.set(k, props[k])
	add_child(node)
	return node

## Wire up signals between controllers and orchestrator logic.
func _connect_signals() -> void:
	hex_grid_controller.grid_initialized.connect(_event_router.on_grid_initialized)
	hex_grid_controller.cell_state_changed.connect(_event_router.on_cell_state_changed)
	hex_grid_controller.grid_stats_changed.connect(_event_router.on_grid_stats_changed)
	hex_grid_controller.cell_at_position_response.connect(_route_to_navigation_controller)
	hex_grid_controller.distance_calculated.connect(func(_r, _d): pass )
	hex_grid_controller.cells_in_range_response.connect(func(_r, _c): pass )

	navigation_controller.path_found.connect(_event_router.on_path_found)
	navigation_controller.path_not_found.connect(_event_router.on_path_not_found)
	navigation_controller.navigation_failed.connect(_event_router.on_navigation_failed)
	navigation_controller.navigation_state_changed.connect(_event_router.on_navigation_state_changed)
	navigation_controller.query_cell_at_position.connect(_route_to_hex_grid_controller)

	debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
	debug_controller.debug_info_updated.connect(_event_router.on_debug_info_updated)

	ui_controller.ui_visibility_changed.connect(_event_router.on_ui_visibility_changed)
	ui_controller.selected_item_changed.connect(_event_router.on_selected_item_changed)
	turn_changed.connect(ui_controller._on_turn_changed)

	selection_controller.object_selected.connect(_on_object_selected)
	selection_controller.selection_cleared.connect(_on_selection_cleared)

	_event_router.grid_state_changed.connect(debug_controller.on_grid_state_changed.emit)
	_event_router.navigation_state_changed.connect(debug_controller.on_navigation_state_changed.emit)
	_event_router.selection_update_requested.connect(func(d): ui_controller.update_selected_item_requested.emit(d))
	_event_router.selection_clear_requested.connect(func(): ui_controller.clear_selected_item_requested.emit())

	_input_handler.execute_movement_requested.connect(func(): _movement_planner.execute_movement(get_tree()))
	_input_handler.cancel_movement_requested.connect(_movement_planner.cancel_movement)
	_input_handler.toggle_debug_requested.connect(func(): debug_controller.toggle_debug_requested.emit())

	_initializer.agents_ready.connect(_on_agents_ready)

## Set the IO controller and connect UI gestures to logic.
func connect_io_controller(io_ctrl) -> void:
	io_controller = io_ctrl
	if not io_controller:
		return
	io_controller.hex_cell_left_clicked.connect(_on_cell_left_clicked)
	io_controller.hex_cell_right_clicked.connect(_on_cell_right_clicked)
	io_controller.hex_cell_hovered.connect(_on_cell_hovered)
	io_controller.hex_cell_hover_ended.connect(_on_cell_hover_ended)

## Begins the session and sets up agents.
func initialize_session() -> void:
	number_of_agents = SessionData.get_total_agent_count()
	agent_manager.initialize(self)

	agent_manager.agents_spawned.connect(_on_agents_spawned)
	agent_manager.agent_turn_started.connect(_on_agent_turn_started)
	agent_manager.agent_turn_ended.connect(_on_agent_turn_ended)
	agent_manager.all_agents_completed_round.connect(_on_all_agents_completed_round)
	agent_manager.movement_action_completed.connect(_on_movement_action_completed)

	var config := _build_init_config()
	var result := await _initializer.initialize(config, get_tree())

	if result != SessionTypes.InitResult.SUCCESS:
		_abort_session("Initialization failed")
		return

	debug_controller.set_debug_visibility_requested.emit(debug_mode)
	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0

	session_initialized.emit()

## Compose the initialization dictionary for the session.
func _build_init_config() -> Dictionary:
	return {
		"grid_width": grid_width,
		"grid_height": grid_height,
		"hex_size": hex_size,
		"navigation_region": navigation_region,
		"integrate_with_navmesh": integrate_with_navmesh,
		"navmesh_sample_points": navmesh_sample_points,
		"debug_mode": debug_mode,
		"spawn_agents_on_init": spawn_agents_on_init,
		"number_of_agents": number_of_agents,
		"max_agents": MAX_AGENTS,
		"session_controller": self
	}

## Stop and clean up the current session.
func _abort_session(msg: String) -> void:
	push_error(msg)
	agents.clear()
	current_agent_index = 0
	session_active = false

## End and fully tear down a running session.
func end_session() -> void:
	if not session_active: return
	session_active = false
	hex_grid_controller.clear_grid_requested.emit()
	navigation_controller.cancel_navigation_requested.emit()
	session_ended.emit()

## Reset and start a new session instance after ending the current one.
func reset_session() -> void:
	end_session()
	await get_tree().process_frame
	initialize_session()

## Adjust the agent party size for the next session.
func set_party_size(count: int) -> void:
	number_of_agents = clamp(count, 1, MAX_AGENTS)
	if agent_manager:
		agent_manager.agent_count = number_of_agents

## Forward game input to the dedicated input handler.
func _input(event: InputEvent) -> void: _input_handler.handle_input(event, get_viewport())

## React to agents being ready after spawn/init.
func _on_agents_ready(spawned_agents: Array) -> void:
	agents = spawned_agents
	current_agent_index = 0

func _on_agents_spawned(_count: int) -> void: pass
func _on_agent_turn_ended(_data: AgentData) -> void: _movement_planner.cancel_movement()
func _on_all_agents_completed_round() -> void: _movement_planner.cancel_movement()
func _on_cell_right_clicked(cell: HexCell) -> void: cell_right_clicked.emit(cell)

## Start a new agent turn.
func _on_agent_turn_started(data: AgentData) -> void:
	_movement_planner.cancel_movement()
	update_navigable_cells(data)
	_emit_turn_changed(data)

## Called after an agent completes a movement action.
func _on_movement_action_completed(data: AgentData, moves: int) -> void:
	update_navigable_cells(data)
	_emit_turn_changed(data, moves)

## Compose and emit turn status updates for UI.
func _emit_turn_changed(data: AgentData, moves_override: int = -1) -> void:
	var moves: int
	if moves_override >= 0:
		moves = moves_override
	elif data.has_method("get_movements_remaining"):
		moves = data.get_movements_remaining()
	else:
		moves = data.max_movements_per_turn

	var actions_left = data.get_actions_remaining() if data.has_method("get_actions_remaining") else "-"

	turn_changed.emit({
		"turn_number": agent_manager.current_round + 1,
		"agent_name": data.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": moves,
		"actions_left": actions_left
	})

## Callback for when debug visibility changes.
func _on_debug_visibility_changed(visible: bool) -> void:
	debug_mode = visible
	_event_router.on_debug_visibility_changed(visible)

## Called when a selection is made.
func _on_object_selected(selection: Dictionary) -> void:
	_event_router.on_object_selected(selection)
	selection_changed.emit(selection)

## Called when selection is cleared.
func _on_selection_cleared() -> void:
	_event_router.on_selection_cleared()
	selection_cleared.emit()

## Left click on a cell triggers movement planning.
func _on_cell_left_clicked(cell: HexCell) -> void:
	if not cell:
		return
	if selection_controller: selection_controller.select_object(cell)
	var agent = agent_manager.get_active_agent() if agent_manager else null
	if agent: _movement_planner.plan_movement(agent, cell)
	cell_clicked.emit(cell)

## Hover and debug information helpers.
func _on_cell_hovered(cell: HexCell) -> void:
	if debug_controller and cell: debug_controller.set_hovered_cell(cell)
	cell_hovered.emit(cell)

func _on_cell_hover_ended() -> void:
	if debug_controller: debug_controller.set_hovered_cell(null)
	cell_hover_ended.emit()

## Refresh list of cells currently navigable by the specified or current agent.
func update_navigable_cells(agent: Variant = null) -> void:
	var cur_agent = agent if agent else get_current_turn_agent()
	if not cur_agent or not hex_grid_controller:
		navigable_cells.clear()
		navigable_cells_updated.emit(navigable_cells)
		return
	var grid = hex_grid_controller.get_hex_grid()
	var pathfinder = navigation_controller.get_pathfinder() if navigation_controller else null
	navigable_cells = _nav_calculator.calculate(cur_agent, grid, pathfinder)
	var agent_cell := _nav_calculator.get_last_agent_cell()
	navigable_cells_updated.emit(navigable_cells)
	debug_controller.update_debug_info_requested.emit("navigable_cells_count", navigable_cells.size())
	debug_controller.update_debug_info_requested.emit("current_agent_cell_q", agent_cell.q if agent_cell else -1)
	debug_controller.update_debug_info_requested.emit("current_agent_cell_r", agent_cell.r if agent_cell else -1)

## Advance to the next agent in the turn order.
func advance_turn() -> void:
	if agents.is_empty(): return
	var current_agent = agents[current_agent_index]
	navigation_controller.set_active_agent(current_agent)
	agent_manager.start_agent_turn(current_agent)
	current_agent_index = (current_agent_index + 1) % agents.size()

## Utility signal routers.
func _route_to_navigation_controller(id: String, cell: HexCell) -> void: navigation_controller.on_cell_at_position_response.emit(id, cell)
func _route_to_hex_grid_controller(id: String, pos: Vector2) -> void: hex_grid_controller.request_cell_at_position.emit(id, pos)

## Select an object via the selection controller.
func report_object_selected(obj) -> void: if selection_controller: selection_controller.select_object(obj)

## Utility getters and helpers.
func get_random_enabled_cell() -> HexCell:
	var grid = hex_grid_controller.get_hex_grid() if hex_grid_controller else null
	return grid.enabled_cells[randi() % grid.enabled_cells.size()] if grid and not grid.enabled_cells.is_empty() else null

func get_hex_distance(a: HexCell, b: HexCell) -> int:
	var g = hex_grid_controller.get_hex_grid() if hex_grid_controller else null
	return g.get_distance(a, b) if g else 0

func get_cell_at_world_position(pos: Vector2) -> HexCell:
	var g = hex_grid_controller.get_hex_grid() if hex_grid_controller else null
	return g.get_cell_at_world_position(pos) if g else null

## Configure a given agent node for grid navigation.
func configure_agent_navigation(agent_node: Node) -> void:
	var g = hex_grid_controller.get_hex_grid() if hex_grid_controller else null
	var p = navigation_controller.get_pathfinder() if navigation_controller else null
	if g and p and agent_node.has_method("set_hex_navigation"): agent_node.set_hex_navigation(g, p)

## Session and controller state accessors.
func get_session_state() -> Dictionary: 
	## Returns summary session state information.
	return {"active": session_active, "duration": get_session_duration(), "start_time": session_start_time}
func get_grid_state() -> Dictionary: return _event_router.get_grid_state()
func get_navigation_state() -> Dictionary: return _event_router.get_navigation_state()
func is_session_active() -> bool: return session_active
func get_session_duration() -> float: return (Time.get_ticks_msec() / 1000.0) - session_start_time if session_active else 0.0
func get_current_turn() -> int: return (current_agent_index + 1) if agents.size() > 0 else 0
func get_total_turns() -> int: return agents.size()
func get_current_turn_agent() -> Variant: return agents[current_agent_index] if agents.size() > 0 else null
func is_cell_navigable(cell: HexCell) -> bool: return navigable_cells.has(cell)
func get_navigable_cells() -> Array[HexCell]: return navigable_cells
func get_terrain(): return hex_grid_controller.get_hex_grid() if hex_grid_controller else null
func get_hex_grid_controller(): return hex_grid_controller
func get_navigation_controller(): return navigation_controller
func get_debug_controller(): return debug_controller
func get_ui_controller(): return ui_controller
func get_selection_controller(): return selection_controller
func get_agent_manager(): return agent_manager

## Enable/disable terrain at a position, update grid.
func disable_terrain_at_position(pos: Vector2, r: int = 1) -> void: hex_grid_controller.set_cells_in_area_requested.emit(pos, r, false)
func enable_terrain_at_position(pos: Vector2, r: int = 1) -> void: hex_grid_controller.set_cells_in_area_requested.emit(pos, r, true)

## Command navigation/pathfinding operators.
func navigate_to_position(pos: Vector2) -> void: navigation_controller.navigate_to_position_requested.emit(pos)
func calculate_path(start: Vector2, goal: Vector2) -> void: navigation_controller.calculate_path_requested.emit("path_" + str(Time.get_ticks_msec()), start, goal)

## Debug mode controls.
func set_debug_mode(enabled: bool) -> void: debug_controller.set_debug_visibility_requested.emit(enabled)
func toggle_debug_mode() -> void: debug_controller.toggle_debug_requested.emit()

## Refresh navmesh integration with the current grid setup.
func refresh_navmesh_integration() -> void: hex_grid_controller.refresh_navmesh_integration()
