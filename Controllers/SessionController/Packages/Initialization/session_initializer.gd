class_name SessionInitializer
extends RefCounted

signal initialization_completed()
signal initialization_failed(reason: String)
signal agents_ready(agents: Array)

const GRID_TIMEOUT_MS := 5000
const NAVMESH_TIMEOUT_MS := 10000

var _hex_grid_controller = null
var _navigation_controller = null
var _agent_manager = null
var _debug_controller = null
var _validator: AgentValidator = AgentValidator.new()


func configure(hex_grid_ctrl, nav_ctrl, agent_mgr, debug_ctrl) -> void:
	_hex_grid_controller = hex_grid_ctrl
	_navigation_controller = nav_ctrl
	_agent_manager = agent_mgr
	_debug_controller = debug_ctrl


func initialize(config: Dictionary, scene_tree: SceneTree) -> SessionTypes.InitResult:
	var grid_offset := _align_grid_with_navmesh(config)

	var grid_result := await _wait_for_grid_init(config, grid_offset, scene_tree)
	if grid_result != SessionTypes.InitResult.SUCCESS:
		initialization_failed.emit("Grid initialization failed")
		return grid_result

	var nav_result := _init_navigation()
	if nav_result != SessionTypes.InitResult.SUCCESS:
		initialization_failed.emit("Navigation initialization failed")
		return nav_result

	if config.get("integrate_with_navmesh", false):
		var navmesh_result := await _integrate_navmesh(config, scene_tree)
		if navmesh_result != SessionTypes.InitResult.SUCCESS:
			initialization_failed.emit("Navmesh integration failed")
			return navmesh_result

	if config.get("spawn_agents_on_init", true):
		var agents_result := _spawn_agents(config)
		if agents_result != SessionTypes.InitResult.SUCCESS:
			initialization_failed.emit("Agent spawn failed")
			return agents_result

	_setup_debug_visuals(config)
	initialization_completed.emit()
	return SessionTypes.InitResult.SUCCESS


func _align_grid_with_navmesh(config: Dictionary) -> Vector2:
	var nav_region: NavigationRegion2D = config.get("navigation_region")
	if not config.get("integrate_with_navmesh", false):
		return Vector2.ZERO
	if not nav_region or not nav_region.navigation_polygon:
		return Vector2.ZERO

	var bounds := _calculate_navmesh_bounds(nav_region.navigation_polygon)
	if bounds.size.x <= 0:
		return Vector2.ZERO

	return nav_region.global_position + bounds.position


func _wait_for_grid_init(config: Dictionary, offset: Vector2, scene_tree: SceneTree) -> SessionTypes.InitResult:
	var state := {"done": false}
	var handler := func(_data): state.done = true

	_hex_grid_controller.grid_initialized.connect(handler, CONNECT_ONE_SHOT)
	_hex_grid_controller.initialize_grid_requested.emit(
		config.get("grid_width", 20),
		config.get("grid_height", 15),
		config.get("hex_size", 32.0),
		offset
	)

	var start_time := Time.get_ticks_msec()
	while not state.done:
		if Time.get_ticks_msec() - start_time > GRID_TIMEOUT_MS:
			if _hex_grid_controller.grid_initialized.is_connected(handler):
				_hex_grid_controller.grid_initialized.disconnect(handler)
			return SessionTypes.InitResult.TIMEOUT
		await scene_tree.process_frame

	return SessionTypes.InitResult.SUCCESS


func _init_navigation() -> SessionTypes.InitResult:
	var grid = _hex_grid_controller.get_hex_grid()
	if not grid:
		return SessionTypes.InitResult.FAILED
	_navigation_controller.initialize(grid, null)
	return SessionTypes.InitResult.SUCCESS


func _integrate_navmesh(config: Dictionary, scene_tree: SceneTree) -> SessionTypes.InitResult:
	var nav_region: NavigationRegion2D = config.get("navigation_region")
	if not nav_region:
		return SessionTypes.InitResult.SUCCESS

	var state := {"done": false}
	var handler := func(_stats): state.done = true

	_hex_grid_controller.navmesh_integration_complete.connect(handler, CONNECT_ONE_SHOT)
	_hex_grid_controller.integrate_navmesh_requested.emit(
		nav_region,
		config.get("navmesh_sample_points", 5)
	)

	var start_time := Time.get_ticks_msec()
	while not state.done:
		if Time.get_ticks_msec() - start_time > NAVMESH_TIMEOUT_MS:
			if _hex_grid_controller.navmesh_integration_complete.is_connected(handler):
				_hex_grid_controller.navmesh_integration_complete.disconnect(handler)
			return SessionTypes.InitResult.TIMEOUT
		await scene_tree.process_frame

	return SessionTypes.InitResult.SUCCESS


func _spawn_agents(config: Dictionary) -> SessionTypes.InitResult:
	var count: int = config.get("number_of_agents", 4)
	var max_agents: int = config.get("max_agents", 4)

	_agent_manager.spawn_agents(count)
	var agents: Array = _agent_manager.get_all_agents()

	var validation := _validator.validate_agents_array(agents, "after spawn")
	if not validation.success:
		return SessionTypes.InitResult.FAILED

	if agents.size() > max_agents:
		agents = agents.slice(0, max_agents)

	agents_ready.emit(agents)
	return SessionTypes.InitResult.SUCCESS


func _setup_debug_visuals(config: Dictionary) -> void:
	var grid = _hex_grid_controller.get_hex_grid()
	if not grid:
		return

	var debug_enabled: bool = config.get("debug_mode", false)

	var hex_debug := HexGridDebug.new()
	hex_debug.name = "HexGridDebug"
	hex_debug.hex_grid = grid
	hex_debug.session_controller = config.get("session_controller")
	hex_debug.debug_enabled = debug_enabled
	_hex_grid_controller.add_child(hex_debug)
	_debug_controller.set_hex_grid_debug(hex_debug)

	var hover := HexCellHoverVisualizer.new()
	hover.name = "HexCellHoverVisualizer"
	hover.hex_grid = grid
	hover.session_controller = config.get("session_controller")
	hover.hover_enabled = not debug_enabled
	_hex_grid_controller.add_child(hover)
	_debug_controller.set_hex_cell_hover_visualizer(hover)

	var path_visualizer = _navigation_controller.get_path_visualizer()
	if path_visualizer:
		_debug_controller.set_hex_path_visualizer(path_visualizer)


func _calculate_navmesh_bounds(nav_poly: NavigationPolygon) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)

	for i in nav_poly.get_outline_count():
		var outline := nav_poly.get_outline(i)
		for v in outline:
			min_pos = min_pos.min(v)
			max_pos = max_pos.max(v)

	if min_pos.x == INF:
		return Rect2()

	return Rect2(min_pos, max_pos - min_pos)
