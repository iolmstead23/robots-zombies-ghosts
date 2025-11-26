class_name SessionController
extends Node

## Central state manager for the game session
## Routes signals between feature controllers and maintains session state
## Uses signal-based architecture to prevent tight coupling between features

# Preload controller classes to avoid circular dependency issues
const HexGridControllerScript = preload("res://Controllers/HexGridController/Core/hex_grid_controller.gd")
const NavigationControllerScript = preload("res://Controllers/NavigationController/Core/navigation_controller.gd")
const DebugControllerScript = preload("res://Controllers/DebugController/Core/debug_controller.gd")

# ============================================================================
# SIGNALS - Session Lifecycle
# ============================================================================

signal session_initialized()
signal session_started()
signal session_ended()
signal terrain_initialized()

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

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true

@export_group("Robot")
@export var robot: CharacterBody2D

# ============================================================================
# FEATURE CONTROLLERS
# ============================================================================

var hex_grid_controller  # HexGridController instance
var navigation_controller  # NavigationController instance
var debug_controller  # DebugController instance

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
	print("  Creating HexGridController...")
	hex_grid_controller = HexGridControllerScript.new()
	hex_grid_controller.name = "HexGridController"
	add_child(hex_grid_controller)
	print("    ✓ HexGridController created")

	print("  Creating NavigationController...")
	navigation_controller = NavigationControllerScript.new()
	navigation_controller.name = "NavigationController"
	add_child(navigation_controller)
	print("    ✓ NavigationController created")

	print("  Creating DebugController...")
	debug_controller = DebugControllerScript.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	print("    ✓ DebugController created")

func _connect_controller_signals() -> void:
	# ========================================================================
	# HexGridController Signals
	# ========================================================================
	hex_grid_controller.grid_initialized.connect(_on_grid_initialized)
	hex_grid_controller.cell_state_changed.connect(_on_cell_state_changed)
	hex_grid_controller.grid_stats_changed.connect(_on_grid_stats_changed)

	# Route HexGridController query responses to NavigationController
	hex_grid_controller.cell_at_position_response.connect(_route_to_navigation_controller)
	hex_grid_controller.distance_calculated.connect(_route_distance_to_navigation)
	hex_grid_controller.cells_in_range_response.connect(_route_cells_to_navigation)

	# ========================================================================
	# NavigationController Signals
	# ========================================================================
	navigation_controller.path_found.connect(_on_path_found)
	navigation_controller.path_not_found.connect(_on_path_not_found)
	navigation_controller.navigation_started.connect(_on_navigation_started)
	navigation_controller.navigation_completed.connect(_on_navigation_completed)
	navigation_controller.navigation_failed.connect(_on_navigation_failed)
	navigation_controller.waypoint_reached.connect(_on_waypoint_reached)
	navigation_controller.navigation_state_changed.connect(_on_navigation_state_changed)

	# Route NavigationController queries to HexGridController
	navigation_controller.query_cell_at_position.connect(_route_to_hex_grid_controller)

	# ========================================================================
	# DebugController Signals
	# ========================================================================
	debug_controller.debug_visibility_changed.connect(_on_debug_visibility_changed)
	debug_controller.debug_info_updated.connect(_on_debug_info_updated)

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

func initialize_session() -> void:
	print("\n┏" + "━".repeat(68) + "┓")
	print("┃ SESSIONCONTROLLER: initialize_session() STARTED" + " ".repeat(19) + "┃")
	print("┗" + "━".repeat(68) + "┛")

	# Initialize hex grid
	print("\n  [1/7] Initializing hex grid...")

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

	# Initialize navigation with robot
	print("\n  [2/7] Initializing navigation...")
	if robot:
		print("    Robot found: %s" % robot.name)
		var grid = hex_grid_controller.get_hex_grid()
		if grid:
			print("    Grid reference obtained")
			navigation_controller.initialize(grid, robot)
			print("    ✓ Navigation controller initialized")
		else:
			push_error("    ✗ ERROR: Grid reference is null!")
	else:
		push_warning("    ⚠ No robot configured")

	# Integrate with navmesh if configured
	print("\n  [3/7] Navmesh integration...")
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

	# Set up debug visualizations
	print("\n  [4/7] Setting up debug visualizations...")
	_setup_debug_visualizations()
	print("    ✓ Debug visualizations configured")

	# Set debug mode
	print("\n  [5/7] Configuring debug mode...")
	debug_controller.set_debug_visibility_requested.emit(debug_mode)
	print("    ✓ Debug mode: %s" % ("enabled" if debug_mode else "disabled"))

	# Mark session as active
	print("\n  [6/7] Activating session...")
	session_active = true
	session_start_time = Time.get_ticks_msec() / 1000.0
	_update_session_state()
	print("    ✓ Session marked as active")

	# Emit signals
	print("\n  [7/7] Emitting session signals...")
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
# INPUT HANDLING
# ============================================================================

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
# PUBLIC API - Direct Accessors (for backward compatibility)
# ============================================================================

func get_terrain():  # Returns HexGrid or null
	return hex_grid_controller.get_hex_grid() if hex_grid_controller else null

func get_hex_grid_controller():  # Returns HexGridController
	return hex_grid_controller

func get_navigation_controller():  # Returns NavigationController
	return navigation_controller

func get_debug_controller():  # Returns DebugController
	return debug_controller

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
