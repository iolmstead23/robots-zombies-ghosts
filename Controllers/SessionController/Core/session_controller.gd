class_name SessionController
extends Node

## Central state manager for the game session
## Routes signals between feature controllers and maintains session state
## Uses signal-based architecture to prevent tight coupling between features

# Preload controller classes to avoid circular dependency issues
const HexGridControllerScript = preload("res://Controllers/HexGridController/Core/hex_grid_controller.gd")
const NavigationControllerScript = preload("res://Controllers/NavigationController/Core/navigation_controller.gd")
const DebugControllerScript = preload("res://Controllers/DebugController/Core/debug_controller.gd")
const UIControllerScript = preload("res://Controllers/UIController/Core/ui_controller.gd")
const SelectionControllerScript = preload("res://Controllers/SelectionController/Core/selection_controller.gd")
const AgentManagerScript = preload("res://Controllers/AgentManager/Core/agent_manager.gd")
const IOControllerScript = preload("res://Controllers/IOController/Core/io_controller.gd")
const MouseInputHandlerScript = preload("res://Controllers/IOController/Input/MouseInputHandler.gd")
const KeyboardInputHandlerScript = preload("res://Controllers/IOController/Input/KeyboardInputHandler.gd")
const CameraInputHandlerScript = preload("res://Controllers/IOController/Input/CameraInputHandler.gd")

# ============================================================================
# SIGNALS - Session Lifecycle
# ============================================================================

signal session_initialized()
signal session_started()
signal session_ended()
signal terrain_initialized()
# Emitted when the current agent's turn changes (mirrors AgentManager's agent_turn_started).
signal turn_changed(agent_data)

# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("Grid Configuration")
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var auto_initialize: bool = true

@export_group("Navigation Integration")
@export var navigation_region: NavigationRegion2D
@export var integrate_with_navmesh: bool = true
@export var navmesh_sample_points: int = 5

@export_group("Input Dependencies")
@export var camera: Camera2D
@export var viewport: Viewport

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true


@export_group("Agent Management")
## Max allowed agents per session
const MAX_AGENTS: int = 4
## Number of agents - set by main menu at runtime, or defaults to 1
var number_of_agents: int = 4 # Temporarily set to 4 for testing
@export var max_movements_per_turn: int = 10
@export var spawn_agents_on_init: bool = true

## Ordered list of session's agents for turn cycling (always 1–MAX_AGENTS elements)
var agents: Array = []
## Current agent turn index
var current_agent_index: int = 0

# ============================================================================
# FEATURE CONTROLLERS
# ============================================================================

var hex_grid_controller # HexGridController instance
var navigation_controller # NavigationController instance
var debug_controller # DebugController instance
var ui_controller # UIController instance
var selection_controller # SelectionController instance
var agent_manager # AgentManager instance
var io_controller # IOController instance

# ============================================================================
# SESSION STATE
# ============================================================================

var session_active: bool = false
var session_start_time: float = 0.0

# State cache for selectors
var _session_state: Dictionary = {}
var _grid_state: Dictionary = {}
var _navigation_state: Dictionary = {}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("\n" + "━".repeat(70))
	print("SESSIONCONTROLLER _ready() CALLED")
	print("━".repeat(70))

	print("Step 1: Initializing controllers...")
	_init_controllers()

	print("Step 2: Connecting controller signals...")
	_connect_controller_signals()

	if auto_initialize:
		print("Step 3: Auto-initialize is enabled, waiting for process frame...")
		await get_tree().process_frame
		print("Step 4: Calling initialize_session()...")
		initialize_session()
	else:
		print("Auto-initialize is disabled, waiting for manual initialization")

# ============================================================================
# CONTROLLER INITIALIZATION
# ============================================================================

func _init_controllers() -> void:
	var failed = false

	print("  Creating HexGridController...")
	hex_grid_controller = null
	hex_grid_controller = HexGridControllerScript.new() if typeof(HexGridControllerScript) == TYPE_OBJECT else null
	if hex_grid_controller == null:
		push_error("Failed to create HexGridController!")
		failed = true
	else:
		hex_grid_controller.name = "HexGridController"
		add_child(hex_grid_controller)
		print("    ✓ HexGridController created")

	print("  Creating NavigationController...")
	navigation_controller = null
	navigation_controller = NavigationControllerScript.new() if typeof(NavigationControllerScript) == TYPE_OBJECT else null
	if navigation_controller == null:
		push_error("Failed to create NavigationController!")
		failed = true
	else:
		navigation_controller.name = "NavigationController"
		add_child(navigation_controller)
		print("    ✓ NavigationController created")

	print("  Creating DebugController...")
	debug_controller = null
	debug_controller = DebugControllerScript.new() if typeof(DebugControllerScript) == TYPE_OBJECT else null
	if debug_controller == null:
		push_error("Failed to create DebugController!")
		failed = true
	else:
		debug_controller.name = "DebugController"
		add_child(debug_controller)
		print("    ✓ DebugController created")

	print("  Creating UIController...")
	ui_controller = null
	ui_controller = UIControllerScript.new() if typeof(UIControllerScript) == TYPE_OBJECT else null
	if ui_controller == null:
		push_error("Failed to create UIController!")
		failed = true
	else:
		ui_controller.name = "UIController"
		add_child(ui_controller)
		print("    ✓ UIController created")

	print("  Creating SelectionController...")
	selection_controller = null
	selection_controller = SelectionControllerScript.new() if typeof(SelectionControllerScript) == TYPE_OBJECT else null
	if selection_controller == null:
		push_error("Failed to create SelectionController!")
		failed = true
	else:
		selection_controller.name = "SelectionController"
		add_child(selection_controller)
		print("    ✓ SelectionController created")

	print("  Creating AgentManager...")
	agent_manager = null
	agent_manager = AgentManagerScript.new() if typeof(AgentManagerScript) == TYPE_OBJECT else null
	if agent_manager == null:
		push_error("Failed to create AgentManager!")
		failed = true
	else:
		agent_manager.name = "AgentManager"
		agent_manager.agent_count = number_of_agents
		agent_manager.max_movements_per_turn = max_movements_per_turn
		add_child(agent_manager)
		print("    ✓ AgentManager created")

	print("  Creating IOController...")
	io_controller = null
	io_controller = IOControllerScript.new() if typeof(IOControllerScript) == TYPE_OBJECT else null
	if io_controller == null:
		push_error("Failed to create IOController!")
		failed = true
	else:
		io_controller.name = "IOController"
		add_child(io_controller)

		# Create and add input handler components
		var mouse_handler = MouseInputHandlerScript.new()
		mouse_handler.name = "MouseInputHandler"
		io_controller.add_child(mouse_handler)

		var keyboard_handler = KeyboardInputHandlerScript.new()
		keyboard_handler.name = "KeyboardInputHandler"
		io_controller.add_child(keyboard_handler)

		var camera_handler = CameraInputHandlerScript.new()
		camera_handler.name = "CameraInputHandler"
		io_controller.add_child(camera_handler)

		print("    ✓ IOController created with input handlers")

	if failed:
		push_warning("One or more controllers failed to initialize. See errors above.")

# Put this helper at the top or in a utility script.
func try_connect(signal_ref, target_method: Callable, signal_name: String, controller_name: String) -> void:
	var result = signal_ref.connect(target_method)
	if result != OK:
		push_error("Error connecting '"
			+ signal_name
			+"' from "
			+ controller_name
			+": "
			+ error_string(result)
		)

func _connect_controller_signals() -> void:
	# HexGridController Signals
	try_connect(hex_grid_controller.grid_initialized, _on_grid_initialized, "grid_initialized", "hex_grid_controller")
	try_connect(hex_grid_controller.cell_state_changed, _on_cell_state_changed, "cell_state_changed", "hex_grid_controller")
	try_connect(hex_grid_controller.grid_stats_changed, _on_grid_stats_changed, "grid_stats_changed", "hex_grid_controller")

	try_connect(hex_grid_controller.cell_at_position_response, _route_to_navigation_controller, "cell_at_position_response", "hex_grid_controller")
	try_connect(hex_grid_controller.distance_calculated, _route_distance_to_navigation, "distance_calculated", "hex_grid_controller")
	try_connect(hex_grid_controller.cells_in_range_response, _route_cells_to_navigation, "cells_in_range_response", "hex_grid_controller")

	# NavigationController Signals
	try_connect(navigation_controller.path_found, _on_path_found, "path_found", "navigation_controller")
	try_connect(navigation_controller.path_not_found, _on_path_not_found, "path_not_found", "navigation_controller")
	try_connect(navigation_controller.navigation_started, _on_navigation_started, "navigation_started", "navigation_controller")
	try_connect(navigation_controller.navigation_completed, _on_navigation_completed, "navigation_completed", "navigation_controller")
	try_connect(navigation_controller.navigation_failed, _on_navigation_failed, "navigation_failed", "navigation_controller")
	try_connect(navigation_controller.waypoint_reached, _on_waypoint_reached, "waypoint_reached", "navigation_controller")
	try_connect(navigation_controller.navigation_state_changed, _on_navigation_state_changed, "navigation_state_changed", "navigation_controller")
	try_connect(navigation_controller.query_cell_at_position, _route_to_hex_grid_controller, "query_cell_at_position", "navigation_controller")

	# DebugController Signals
	try_connect(debug_controller.debug_visibility_changed, _on_debug_visibility_changed, "debug_visibility_changed", "debug_controller")
	try_connect(debug_controller.debug_info_updated, _on_debug_info_updated, "debug_info_updated", "debug_controller")

	# UIController Signals
	try_connect(ui_controller.ui_visibility_changed, _on_ui_visibility_changed, "ui_visibility_changed", "ui_controller")
	try_connect(ui_controller.selected_item_changed, _on_selected_item_changed, "selected_item_changed", "ui_controller")
	# Connect SessionController's turn_changed to UIController's handler
	try_connect(turn_changed, ui_controller._on_turn_changed, "turn_changed", "self->ui_controller")

	# SelectionController Signals
	try_connect(selection_controller.object_selected, _on_object_selected, "object_selected", "selection_controller")
	try_connect(selection_controller.selection_cleared, _on_selection_cleared, "selection_cleared", "selection_controller")

	# AgentManager Signals
	try_connect(agent_manager.agents_spawned, _on_agents_spawned, "agents_spawned", "agent_manager")
	try_connect(agent_manager.agent_turn_started, _on_agent_turn_started, "agent_turn_started", "agent_manager")
	try_connect(agent_manager.agent_turn_ended, _on_agent_turn_ended, "agent_turn_ended", "agent_manager")
	try_connect(agent_manager.all_agents_completed_round, _on_all_agents_completed_round, "all_agents_completed_round", "agent_manager")
	try_connect(agent_manager.movement_action_completed, _on_movement_action_completed, "movement_action_completed", "agent_manager")

	# IOController Signals
	try_connect(io_controller.hex_cell_left_clicked, _on_io_hex_cell_left_clicked, "hex_cell_left_clicked", "io_controller")
	try_connect(io_controller.hex_cell_right_clicked, _on_io_hex_cell_right_clicked, "hex_cell_right_clicked", "io_controller")
	try_connect(io_controller.hex_cell_hovered, _on_io_hex_cell_hovered, "hex_cell_hovered", "io_controller")
	try_connect(io_controller.hex_cell_hover_ended, _on_io_hex_cell_hover_ended, "hex_cell_hover_ended", "io_controller")
	try_connect(io_controller.camera_zoom_in_requested, _on_io_camera_zoom_in, "camera_zoom_in_requested", "io_controller")
	try_connect(io_controller.camera_zoom_out_requested, _on_io_camera_zoom_out, "camera_zoom_out_requested", "io_controller")
	try_connect(io_controller.debug_report_requested, _on_io_debug_report_requested, "debug_report_requested", "io_controller")
	try_connect(io_controller.clear_history_requested, _on_io_clear_history_requested, "clear_history_requested", "io_controller")
	try_connect(io_controller.export_data_requested, _on_io_export_data_requested, "export_data_requested", "io_controller")
	try_connect(io_controller.end_turn_requested, _on_io_end_turn_requested, "end_turn_requested", "io_controller")


# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

## Set the number of agents from main menu before session initialization
## Should be called before initialize_session() is run
func set_party_size(count: int) -> void:
	# Cap party size at MAX_AGENTS
	number_of_agents = clamp(count, 1, MAX_AGENTS)
	print("[SessionController] Party size set to %d agents" % number_of_agents)

	# Update agent manager if it already exists
	if agent_manager:
		agent_manager.agent_count = number_of_agents

func initialize_session() -> void:
	print("\n┏" + "━".repeat(68) + "┓")
	print("┃ SESSIONCONTROLLER: initialize_session() STARTED" + " ".repeat(19) + "┃")
	print("┗" + "━".repeat(68) + "┛")

	# Initialize hex grid
	print("\n  [1/8] Initializing hex grid...")

	# Calculate grid offset to align with navigation region if available
	var grid_offset = Vector2.ZERO
	if integrate_with_navmesh and navigation_region and navigation_region.navigation_polygon:
		var nav_poly := navigation_region.navigation_polygon
		var bounds := _calculate_navmesh_bounds(nav_poly)
		if bounds.size.x > 0 and bounds.size.y > 0:
			grid_offset = navigation_region.global_position + bounds.position
			print("    Calculated grid_offset from navmesh: %s" % grid_offset)

	print("    Config: %dx%d, hex_size=%.1f, offset=%s" % [grid_width, grid_height, hex_size, grid_offset])

	# Set up one-shot signal connection to wait for initialization
	var init_state = {"complete": false}
	var on_grid_init = func(_grid_data):
		init_state.complete = true

	hex_grid_controller.grid_initialized.connect(on_grid_init, CONNECT_ONE_SHOT)

	hex_grid_controller.initialize_grid_requested.emit(
		grid_width,
		grid_height,
		hex_size,
		grid_offset
	)

	# Wait for grid initialization if not already complete
	print("    Waiting for grid initialization...")
	while not init_state.complete:
		await get_tree().process_frame

	print("    ✓ Grid initialized")

	# Initialize navigation controller (multi-agent mode)
	print("\n  [2/8] Initializing navigation...")
	var grid = hex_grid_controller.get_hex_grid()
	if grid:
		print("    Grid reference obtained")
		navigation_controller.initialize(grid, null)
		print("    ✓ Navigation controller initialized for agents (multi-agent mode always enabled)")
	else:
		push_error("    ✗ ERROR: Grid reference is null!")

	# Configure IOController dependencies
	print("\n  [3/8] Configuring IOController...")
	if io_controller:
		if camera:
			io_controller.set_camera(camera)
			print("    Camera reference set")
		else:
			push_warning("    Camera reference not set (camera is null)")

		if viewport:
			io_controller.set_viewport(viewport)
			print("    Viewport reference set")
		else:
			# Use default viewport if not explicitly set
			viewport = get_viewport()
			if viewport:
				io_controller.set_viewport(viewport)
				print("    Viewport reference set (using default)")
			else:
				push_warning("    Viewport reference not set")

		if grid:
			io_controller.set_hex_grid(grid)
			print("    HexGrid reference set")

		print("    ✓ IOController configured")
	else:
		push_error("    ✗ ERROR: IOController is null!")

	# Integrate with navmesh if configured
	print("\n  [4/8] Navmesh integration...")
	if integrate_with_navmesh and navigation_region:
		print("    Starting navmesh integration...")

		# The integrate_navmesh_requested is async, so we need to wait
		hex_grid_controller.integrate_navmesh_requested.emit(
			navigation_region,
			navmesh_sample_points
		)

		# Wait for navmesh integration to complete
		# This will enable/disable cells based on polygon containment
		await get_tree().create_timer(0.5).timeout

		print("    ✓ Navmesh integration completed")
	else:
		print("    Skipped (disabled or no nav region)")

	# Initialize and spawn agents
	print("\n  [5/9] Initializing agents...")

	# --- PATCH: Respect SessionData agent count exactly ---
	number_of_agents = SessionData.get_total_agent_count()
	print("[SessionController] Updated number_of_agents from SessionData: %d" % number_of_agents)
	# ------------------------------------------------------

	var agent_grid = hex_grid_controller.get_hex_grid()
	if agent_grid:
		agent_manager.initialize(agent_grid, navigation_controller)
		if spawn_agents_on_init:
			agent_manager.spawn_agents(number_of_agents)
			print("    ✓ %d agents spawned" % number_of_agents)
			# Immediately update central agent collection (must match turn order semantics)
			agents = agent_manager.get_all_agents()
			# Strict validation: No partial or broken agent arrays allowed
			var null_agent_found := false
			for a in agents:
				if a == null:
					null_agent_found = true
					break
			if agents.size() != number_of_agents or null_agent_found:
				push_error("[SessionController] ERROR: agents array invalid after registration! Expected %d, Got %d, Nulls: %s" % [
					number_of_agents, agents.size(), str(null_agent_found)
				])
				agents = []
				current_agent_index = 0
				push_error("[SessionController] Aborting session initialization due to agent registration failure.")
				return
			if agents.size() > MAX_AGENTS:
				agents = agents.slice(0, MAX_AGENTS)
			current_agent_index = 0
		else:
			print("    Agent spawning disabled (spawn_agents_on_init=false)")
			agents = []
			current_agent_index = 0
	else:
		push_error("    ✗ ERROR: Cannot initialize agents - grid reference is null!")
		agents = []
		current_agent_index = 0

	# Set up debug visualizations
	print("\n  [6/9] Setting up debug visualizations...")
	_setup_debug_visualizations()
	print("    ✓ Debug visualizations configured")

	# Set debug mode
	print("\n  [7/9] Configuring debug mode...")
	debug_controller.set_debug_visibility_requested.emit(debug_mode)
	print("    ✓ Debug mode: %s" % ("enabled" if debug_mode else "disabled"))

	# Mark session as active
	print("\n  [8/9] Activating session...")
	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	_update_session_state()
	print("    ✓ Session marked as active")

	# Emit signals
	print("\n  [9/9] Emitting session signals...")
	terrain_initialized.emit()
	print("    ✓ terrain_initialized emitted")
	session_started.emit()
	print("    ✓ session_started emitted")
	session_initialized.emit()
	print("    ✓ session_initialized emitted")

	_print_stats()

	print("\n┏" + "━".repeat(68) + "┓")
	print("┃ SESSIONCONTROLLER: INITIALIZATION COMPLETE" + " ".repeat(25) + "┃")
	print("┗" + "━".repeat(68) + "┛\n")

func _setup_debug_visualizations() -> void:
	# Get visualization components from navigation controller
	var path_visualizer = navigation_controller.get_path_visualizer()
	if path_visualizer:
		debug_controller.set_hex_path_visualizer(path_visualizer)

	# Create HexGridDebug if needed
	var grid = hex_grid_controller.get_hex_grid()
	if grid:
		var hex_grid_debug = HexGridDebug.new()
		hex_grid_debug.name = "HexGridDebug"
		hex_grid_debug.hex_grid = grid
		hex_grid_debug.debug_enabled = debug_mode
		hex_grid_controller.add_child(hex_grid_debug)
		debug_controller.set_hex_grid_debug(hex_grid_debug)

func end_session() -> void:
	if not session_active:
		return

	session_active = false
	hex_grid_controller.clear_grid_requested.emit()
	navigation_controller.cancel_navigation_requested.emit()
	_update_session_state()
	session_ended.emit()

func reset_session() -> void:
	end_session()
	await get_tree().process_frame
	initialize_session()

# ============================================================================
# SIGNAL ROUTING - HexGridController to NavigationController
# ============================================================================

func _route_to_navigation_controller(request_id: String, cell: HexCell) -> void:
	navigation_controller.on_cell_at_position_response.emit(request_id, cell)

func _route_distance_to_navigation(_request_id: String, _distance: int) -> void:
	# Future: add distance response to navigation controller if needed
	pass

func _route_cells_to_navigation(_request_id: String, _cells: Array[HexCell]) -> void:
	# Future: add cells response to navigation controller if needed
	pass

# ============================================================================
# SIGNAL ROUTING - NavigationController to HexGridController
# ============================================================================

func _route_to_hex_grid_controller(request_id: String, world_pos: Vector2) -> void:
	hex_grid_controller.request_cell_at_position.emit(request_id, world_pos)

# ============================================================================
# EVENT HANDLERS - HexGridController
# ============================================================================

func _on_grid_initialized(grid_data: Dictionary) -> void:
	_grid_state = grid_data
	debug_controller.on_grid_state_changed.emit(grid_data)
	print("SessionController: Grid initialized - %dx%d (%d cells)" % [
		grid_data.width,
		grid_data.height,
		grid_data.total_cells
	])

func _on_cell_state_changed(_coords: Vector2i, _enabled: bool) -> void:
	# Update grid stats
	pass

func _on_grid_stats_changed(stats: Dictionary) -> void:
	_grid_state.merge(stats, true)
	debug_controller.on_grid_state_changed.emit(_grid_state)

# ============================================================================
# EVENT HANDLERS - NavigationController
# ============================================================================

func _on_path_found(_start: HexCell, _goal: HexCell, path: Array[HexCell], duration_ms: float) -> void:
	if OS.is_debug_build():
		print("SessionController: Path found - %d cells in %.2f ms" % [path.size(), duration_ms])

func _on_path_not_found(_start_pos: Vector2, _goal_pos: Vector2, reason: String) -> void:
	if OS.is_debug_build():
		print("SessionController: Path not found - %s" % reason)

func _on_navigation_started(target: HexCell) -> void:
	if OS.is_debug_build():
		print("SessionController: Navigation started to (%d, %d)" % [target.q, target.r])

func _on_navigation_completed() -> void:
	if OS.is_debug_build():
		print("SessionController: Navigation completed")

func _on_navigation_failed(reason: String) -> void:
	if OS.is_debug_build():
		print("SessionController: Navigation failed - %s" % reason)

func _on_waypoint_reached(_cell: HexCell, _index: int, _remaining: int) -> void:
	pass

func _on_navigation_state_changed(active: bool, path_length: int, remaining_distance: int) -> void:
	_navigation_state = {
		"active": active,
		"path_length": path_length,
		"remaining_distance": remaining_distance
	}
	debug_controller.on_navigation_state_changed.emit(_navigation_state)

# ============================================================================
# EVENT HANDLERS - DebugController
# ============================================================================

func _on_debug_visibility_changed(visible: bool) -> void:
	debug_mode = visible
	if OS.is_debug_build():
		print("SessionController: Debug mode %s" % ("ON" if visible else "OFF"))

func _on_debug_info_updated(_key: String, _value: Variant) -> void:
	# Debug info updated
	pass

# ============================================================================
# EVENT HANDLERS - UIController
# ============================================================================

func _on_ui_visibility_changed(visible: bool) -> void:
	if OS.is_debug_build():
		print("SessionController: UI overlay %s" % ("shown" if visible else "hidden"))

func _on_selected_item_changed(item_data: Dictionary) -> void:
	if OS.is_debug_build() and item_data.get("has_selection", false):
		print("SessionController: Selected item changed - %s (%s)" % [
			item_data.get("item_name", "Unknown"),
			item_data.get("item_type", "Unknown")
		])

# ============================================================================
# EVENT HANDLERS - SelectionController
# ============================================================================

func _on_object_selected(selection_data: Dictionary) -> void:
	if OS.is_debug_build():
		print("SessionController: Object selected - %s" % selection_data.get("item_name"))

	# Route selection to UIController
	if ui_controller:
		ui_controller.update_selected_item_requested.emit(selection_data)

func _on_selection_cleared() -> void:
	if OS.is_debug_build():
		print("SessionController: Selection cleared")

	# Route selection clear to UIController
	if ui_controller:
		ui_controller.clear_selected_item_requested.emit()

# ============================================================================
# EVENT HANDLERS - AgentManager
# ============================================================================

func _on_agents_spawned(agent_count: int) -> void:
	print("SessionController: %d agents spawned" % agent_count)

func _on_agent_turn_started(agent_data: AgentData) -> void:
	if OS.is_debug_build():
		print("SessionController: %s turn started" % agent_data.agent_name)
	# Build and emit turn status dictionary for UI integration
	var turn_info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": agent_data.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": agent_data.get_movements_remaining() if agent_data.has_method("get_movements_remaining") else agent_data.max_movements_per_turn,
		"actions_left": agent_data.get_actions_remaining() if agent_data.has_method("get_actions_remaining") else "-"
	}
	if OS.is_debug_build():
		print("[SessionController] Emitting turn_changed: %s" % str(turn_info))
	turn_changed.emit(turn_info)

func _on_agent_turn_ended(agent_data: AgentData) -> void:
	if OS.is_debug_build():
		print("SessionController: %s turn ended (used %d movements)" % [
			agent_data.agent_name,
			agent_data.movements_used_this_turn
		])

func _on_all_agents_completed_round() -> void:
	if OS.is_debug_build():
		print("SessionController: All agents completed round")

func _on_movement_action_completed(agent_data: AgentData, movements_remaining: int) -> void:
	if OS.is_debug_build():
		print("SessionController: %s movement action (%d remaining)" % [
			agent_data.agent_name,
			movements_remaining
		])

	# Emit turn_changed to update UI with new distance remaining
	var turn_info = {
		"turn_number": agent_manager.current_round + 1,
		"agent_name": agent_data.agent_name,
		"agent_index": agent_manager.active_agent_index,
		"total_agents": agent_manager.get_all_agents().size(),
		"movements_left": movements_remaining,
		"actions_left": agent_data.get_actions_remaining() if agent_data.has_method("get_actions_remaining") else "-"
	}
	turn_changed.emit(turn_info)
	if OS.is_debug_build():
		print("[SessionController] Emitted turn_changed after movement: distance_left=%d" % movements_remaining)

# ============================================================================
# EVENT HANDLERS - IOController
# ============================================================================

func _on_io_hex_cell_left_clicked(cell: HexCell) -> void:
	"""Handle left click on hex cell from IOController"""
	_handle_cell_click(cell)

func _on_io_hex_cell_right_clicked(cell: HexCell) -> void:
	"""Handle right click on hex cell from IOController"""
	_toggle_cell(cell)

func _on_io_hex_cell_hovered(cell: HexCell) -> void:
	"""Handle hover on hex cell from IOController"""
	if debug_controller:
		debug_controller.set_hovered_cell(cell)

func _on_io_hex_cell_hover_ended() -> void:
	"""Handle hover end from IOController"""
	if debug_controller:
		debug_controller.set_hovered_cell(null)

func _on_io_camera_zoom_in() -> void:
	"""Handle zoom in request from IOController"""
	if camera:
		camera.zoom *= 1.1

func _on_io_camera_zoom_out() -> void:
	"""Handle zoom out request from IOController"""
	if camera:
		camera.zoom *= 0.9

func _on_io_debug_report_requested() -> void:
	"""Handle debug report request from IOController"""
	if navigation_controller:
		var tracker = navigation_controller.get_path_tracker()
		if tracker:
			tracker.print_report()

func _on_io_clear_history_requested() -> void:
	"""Handle clear history request from IOController"""
	if navigation_controller:
		var tracker = navigation_controller.get_path_tracker()
		if tracker:
			tracker.clear_history()
			print("Path history cleared")

func _on_io_export_data_requested() -> void:
	"""Handle export data request from IOController"""
	if navigation_controller:
		var tracker = navigation_controller.get_path_tracker()
		if tracker:
			var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
			var filename = "user://pathfinding_data_%s.json" % timestamp
			tracker.export_to_json(filename)

func _on_io_end_turn_requested() -> void:
	"""Handle end turn request from IOController"""
	var active_agent_data = agent_manager.get_active_agent() if agent_manager else null
	if agent_manager and active_agent_data:
		print("\n" + "⏭".repeat(30))
		print("⏭ MANUALLY ENDING TURN FOR %s" % active_agent_data.agent_name.to_upper())
		print("⏭".repeat(30))
		print("Movements Used: %d/%d" % [
			active_agent_data.movements_used_this_turn,
			active_agent_data.max_movements_per_turn
		])
		print("⏭".repeat(30) + "\n")
		agent_manager.end_current_agent_turn()
	else:
		print("Cannot end turn - no active agent")

func _handle_cell_click(cell: HexCell) -> void:
	"""Handle clicking on a hex cell - request navigation for active agent"""
	print("\n" + "=".repeat(60))
	print("HEX CELL SELECTION & NAVIGATION REQUEST")
	print("=".repeat(60))

	print("\n--- Target Cell Info ---")
	print("Cell Coordinates: (%d, %d)" % [cell.q, cell.r])
	print("World Position: %s" % cell.world_position)
	print("Cell Enabled: %s" % cell.enabled)

	if not cell.enabled:
		print("\n❌ NAVIGATION BLOCKED: Cell is disabled")
		print("=".repeat(60) + "\n")
		return

	# Check if we have an active agent
	var active_agent_data = agent_manager.get_active_agent() if agent_manager else null
	if not active_agent_data:
		print("\n❌ NAVIGATION BLOCKED: No active agent")
		print("=".repeat(60) + "\n")
		return

	# Check if active agent can move
	if not active_agent_data.can_move():
		print("\n❌ NAVIGATION BLOCKED: %s has no movements remaining (%d/%d used)" % [
			active_agent_data.agent_name,
			active_agent_data.movements_used_this_turn,
			active_agent_data.max_movements_per_turn
		])
		print("=".repeat(60) + "\n")
		return

	print("\n--- Active Agent Info ---")
	print("Agent: %s" % active_agent_data.agent_name)
	print("Current Position: %s" % active_agent_data.current_position)
	print("Movements Remaining: %d/%d" % [
		active_agent_data.get_movements_remaining(),
		active_agent_data.max_movements_per_turn
	])

	# Get the active agent's controller
	var controller_node = active_agent_data.agent_controller
	var agent_controller: Agent = controller_node as Agent
	if not agent_controller:
		print("\n❌ ERROR: Active agent controller is not recognized as 'Agent'")
		print("=".repeat(60) + "\n")
		return

	# Navigate the active agent directly - pathfinding will calculate path
	if agent_controller.turn_based_controller:
		agent_controller.turn_based_controller.request_movement_to(cell.world_position)
		# Small delay for pathfinding to complete
		await get_tree().create_timer(0.1).timeout

		if agent_controller.turn_based_controller.current_state == agent_controller.turn_based_controller.TurnState.AWAITING_CONFIRMATION:
			# Get the number of hex cells in the path (each cell = 1 meter)
			var pathfinder = agent_controller.turn_based_controller.pathfinder
			if pathfinder and pathfinder.current_path and not pathfinder.current_path.is_empty():
				var full_path_length = pathfinder.current_path.size() # Number of hex cells in full path
				var distance_available = active_agent_data.get_distance_remaining()

				# Limit movement to available distance (max 10 meters per turn)
				var distance_to_move = min(full_path_length, distance_available)

				if distance_to_move <= 0:
					agent_controller.turn_based_controller.cancel_movement()
					print("\n❌ No distance remaining this turn")
					print("=".repeat(60) + "\n")
					return

				# Truncate path if it exceeds available distance
				if full_path_length > distance_to_move:
					print("\n⚠️ Path truncated: %d meters requested, %d meters available" % [full_path_length, distance_to_move])
					# Truncate the pathfinder's path to only the first distance_to_move cells
					pathfinder.current_path = pathfinder.current_path.slice(0, distance_to_move)
					print("   Path shortened from %d to %d cells" % [full_path_length, pathfinder.current_path.size()])

				# Record movement action with actual distance to move
				if agent_manager.record_movement_action(distance_to_move):
					agent_controller.turn_based_controller.confirm_movement()
					print("\n✅ Movement confirmed: %d meters (%d hex cells)" % [distance_to_move, distance_to_move])
					print("   Distance remaining: %d meters" % int(active_agent_data.get_distance_remaining()))
				else:
					agent_controller.turn_based_controller.cancel_movement()
					print("\n❌ Failed to record movement")
			else:
				print("\n❌ Pathfinding failed - no valid path")
	else:
		print("\n❌ ERROR: Agent has no turn_based_controller")

	print("=".repeat(60) + "\n")

func _toggle_cell(cell: HexCell) -> void:
	"""Toggle a cell between enabled and disabled via HexGridController"""
	if not hex_grid_controller:
		return

	var coords = Vector2i(cell.q, cell.r)
	hex_grid_controller.set_cell_enabled_requested.emit(coords, not cell.enabled)

	print("Cell (%d,%d) %s" % [cell.q, cell.r, "enabled" if not cell.enabled else "disabled"])

# ============================================================================
# GENERIC TURN & SESSION AGENT CYCLING
# ============================================================================

## Advance to next agent's turn in a round-robin fashion. Generic for 1–MAX_AGENTS.
# All valid turn changes are routed via advance_turn(), which invokes agent_manager.start_agent_turn.
# This produces agent_turn_started, which triggers _on_agent_turn_started, which then emits turn_changed.
# Thus, ALL code paths initiating a new turn always emit turn_changed.
func advance_turn() -> void:
	if agents.size() == 0:
		push_error("advance_turn: No agents available for turn cycling.")
		return

	var current_agent = agents[current_agent_index]
	# Assign this agent as the active one for navigation control
	navigation_controller.set_active_agent(current_agent)

	# Let agent_manager know; may trigger per-agent UI or enable input
	agent_manager.start_agent_turn(current_agent)

	print("advance_turn: Agent %s's turn" % String(current_agent.name) if "name" in current_agent else String(current_agent))

	# Move to next index (wraps to 0 via modulus)
	current_agent_index = (current_agent_index + 1) % agents.size()

func _input(event: InputEvent) -> void:
	if not debug_hotkey_enabled:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_controller.toggle_debug_requested.emit()
		get_viewport().set_input_as_handled()

# ============================================================================
# PUBLIC API - Selectors (Read State)
# ============================================================================

func get_session_state() -> Dictionary:
	return _session_state.duplicate()

func get_grid_state() -> Dictionary:
	return _grid_state.duplicate()

func get_navigation_state() -> Dictionary:
	return _navigation_state.duplicate()

func is_session_active() -> bool:
	return session_active

func get_session_duration() -> float:
	if not session_active:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - session_start_time

# ============================================================================
# ========================================================================
# PUBLIC API - Turn/Session State Accessors
# ========================================================================

## Returns the current turn number within the agent cycle (1-based).
## This does NOT count completed rounds, only the current index.
## Returns 0 if no agents are present.
func get_current_turn() -> int:
	# 1-based turn number for external use; 0 if no agents loaded
	return (current_agent_index + 1) if agents.size() > 0 else 0

## Returns the total number of turns in the current session round.
## This equals the number of active agents in play.
func get_total_turns() -> int:
	return agents.size()

## Returns the agent object whose turn is active, or null if unavailable.
## The agent type is determined by your agent instantiation (e.g., AgentData, Node, or custom class).
func get_current_turn_agent() -> Variant:
	return agents[current_agent_index] if agents.size() > 0 else null
# PUBLIC API - Direct Accessors (for backward compatibility)
# ============================================================================

func get_terrain(): # Returns HexGrid or null
	return hex_grid_controller.get_hex_grid() if hex_grid_controller else null

func get_hex_grid_controller(): # Returns HexGridController
	return hex_grid_controller

func get_navigation_controller(): # Returns NavigationController
	return navigation_controller

func get_debug_controller(): # Returns DebugController
	return debug_controller

func get_ui_controller(): # Returns UIController
	return ui_controller

func get_selection_controller(): # Returns SelectionController
	return selection_controller

func get_agent_manager(): # Returns AgentManager
	return agent_manager

func get_io_controller(): # Returns IOController
	return io_controller

# ============================================================================
# PUBLIC API - Convenience Methods (emit signals to controllers)
# ============================================================================

func disable_terrain_at_position(world_pos: Vector2, radius: int = 1) -> void:
	hex_grid_controller.set_cells_in_area_requested.emit(world_pos, radius, false)

func enable_terrain_at_position(world_pos: Vector2, radius: int = 1) -> void:
	hex_grid_controller.set_cells_in_area_requested.emit(world_pos, radius, true)

func navigate_to_position(target_pos: Vector2) -> void:
	navigation_controller.navigate_to_position_requested.emit(target_pos)

func calculate_path(start_pos: Vector2, goal_pos: Vector2) -> void:
	var request_id = "path_" + str(Time.get_ticks_msec())
	navigation_controller.calculate_path_requested.emit(request_id, start_pos, goal_pos)

func set_debug_mode(enabled: bool) -> void:
	debug_controller.set_debug_visibility_requested.emit(enabled)

func toggle_debug_mode() -> void:
	debug_controller.toggle_debug_requested.emit()

func refresh_navmesh_integration() -> void:
	hex_grid_controller.refresh_navmesh_integration()
	if OS.is_debug_build():
		print("SessionController: Navmesh integration refreshed")

# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _update_session_state() -> void:
	_session_state = {
		"active": session_active,
		"duration": get_session_duration(),
		"start_time": session_start_time
	}
	debug_controller.on_session_state_changed.emit(_session_state)

func _calculate_navmesh_bounds(nav_poly: NavigationPolygon) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for i in nav_poly.get_outline_count():
		var outline := nav_poly.get_outline(i)
		for vertex in outline:
			min_pos = min_pos.min(vertex)
			max_pos = max_pos.max(vertex)

	if min_pos.x == INF:
		push_warning("NavigationPolygon has no vertices")
		return Rect2()

	return Rect2(min_pos, max_pos - min_pos)

func _print_stats() -> void:
	if not OS.is_debug_build():
		return

	print("\n" + "=".repeat(60))
	print("SESSION CONTROLLER - Signal-Based Architecture")
	print("=".repeat(60))
	print("Controllers Initialized:")
	print("  ✓ HexGridController")
	print("  ✓ NavigationController")
	print("  ✓ DebugController")
	print("  ✓ UIController")
	print("  ✓ SelectionController")
	print("  ✓ AgentManager")
	print("  ✓ IOController")
	print("\nGrid Configuration:")
	print("  Dimensions: %dx%d" % [grid_width, grid_height])
	print("  Hex Size: %.1f" % hex_size)
	print("  Total Cells: %d" % _grid_state.get("total_cells", 0))
	print("  Enabled: %d | Disabled: %d" % [
		_grid_state.get("enabled_cells", 0),
		_grid_state.get("disabled_cells", 0)
	])
	print("\nSession Status:")
	print("  Active: %s" % session_active)
	print("  Debug Mode: %s" % debug_mode)
	print("  Navmesh Integration: %s" % integrate_with_navmesh)
	print("=".repeat(60) + "\n")
