# Testing/NavigationTest.gd
extends Node2D
class_name NavigationTest

## Comprehensive testing and debugging script for hex grid navigation
## Attach this to your scene to test the navigation system

@onready var navigation_controller = $"../NavigationController"
@onready var session_controller = $"../SessionController"
@onready var player = null  # Will find dynamically

var test_targets: Array[Vector2] = []
var current_test_index := 0
var test_running := false

@export var auto_test := false
@export var test_delay := 3.0
@export var draw_test_targets := true
@export var show_diagnostics := true

var test_timer := 0.0
var diagnostics_label: Label

func _ready() -> void:
	# Find player
	var player_names := ["Robot Player", "Player", "RobotPlayer", "robot_player"]
	for player_name in player_names:
		player = get_tree().root.find_child(player_name, true, false)
		if player:
			print("NavigationTest: Found player: ", player.name)
			break
	
	if not player:
		push_error("NavigationTest: Could not find player!")
		return
	
	# Wait for grid to be ready
	if session_controller and not session_controller.is_grid_ready():
		print("NavigationTest: Waiting for grid...")
		await session_controller.grid_ready
	
	# Create diagnostics label
	if show_diagnostics:
		_create_diagnostics_ui()
	
	# Setup test targets based on your navigation area
	_setup_test_targets()
	
	# Connect to navigation events
	if session_controller:
		session_controller.navigation_completed.connect(_on_navigation_completed)
		session_controller.navigation_cancelled.connect(_on_navigation_cancelled)
		session_controller.stuck_detected.connect(_on_stuck_detected)
	
	if auto_test:
		call_deferred("start_test_sequence")

func _setup_test_targets() -> void:
	# Add test waypoints covering your map
	# Adjust these based on your actual navigable area
	test_targets = [
		Vector2(100, 0),      # Right
		Vector2(200, -100),   # Upper right
		Vector2(200, 100),    # Lower right
		Vector2(0, 200),      # Down
		Vector2(-100, 100),   # Lower left
		Vector2(-100, -100),  # Upper left
		Vector2(0, -200),     # Up
		Vector2(300, 0),      # Far right
		Vector2(5, 5),        # Return to start
	]
	
	print("NavigationTest: Setup %d test targets" % test_targets.size())

func _create_diagnostics_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	var panel = Panel.new()
	panel.position = Vector2(10, 10)
	panel.size = Vector2(400, 250)
	panel.modulate.a = 0.9
	canvas_layer.add_child(panel)
	
	diagnostics_label = Label.new()
	diagnostics_label.position = Vector2(10, 10)
	diagnostics_label.size = Vector2(380, 230)
	diagnostics_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(diagnostics_label)

func _process(delta: float) -> void:
	if test_running:
		test_timer += delta
	
	if show_diagnostics and diagnostics_label:
		_update_diagnostics()

func _update_diagnostics() -> void:
	var text = "=== NAVIGATION DIAGNOSTICS ===\n"
	
	# Player info
	if player:
		text += "\nPLAYER:\n"
		text += "  Position: %v\n" % player.global_position
		text += "  Velocity: %v (%.1f)\n" % [player.velocity, player.velocity.length()]
		if player.has_method("is_navigating"):
			text += "  Navigating: %s\n" % player.is_navigating()
	
	# Navigation info
	if session_controller:
		var nav_info = session_controller.get_navigation_info()
		text += "\nNAVIGATION:\n"
		text += "  Active: %s\n" % nav_info.is_navigating
		text += "  Mode: %s\n" % nav_info.mode
		text += "  Progress: %.1f%%\n" % (nav_info.progress * 100)
		text += "  Waypoints: %d / %d\n" % [nav_info.waypoints_remaining, nav_info.waypoints_total]
		text += "  Distance to waypoint: %.1f\n" % nav_info.distance_to_waypoint
		text += "  Stuck count: %d\n" % nav_info.stuck_count
	
	# Grid info
	if navigation_controller:
		var stats = navigation_controller.get_grid_stats()
		text += "\nGRID:\n"
		text += "  Total cells: %d\n" % stats.total_cells
		text += "  Enabled: %d (%.1f%%)\n" % [stats.enabled_cells, 
			(float(stats.enabled_cells) / float(stats.total_cells) * 100.0)]
		text += "  Grid ready: %s\n" % stats.grid_ready
	
	# Test info
	if test_running:
		text += "\nTEST:\n"
		text += "  Target %d / %d\n" % [current_test_index + 1, test_targets.size()]
		text += "  Time: %.1fs\n" % test_timer
		text += "  Target: %v\n" % test_targets[current_test_index]
	
	diagnostics_label.text = text

func start_test_sequence() -> void:
	if test_targets.is_empty():
		push_error("NavigationTest: No test targets defined!")
		return
	
	print("NavigationTest: Starting test sequence...")
	test_running = true
	current_test_index = 0
	test_timer = 0.0
	_navigate_to_next_target()

func _navigate_to_next_target() -> void:
	if current_test_index >= test_targets.size():
		print("NavigationTest: Test sequence completed!")
		test_running = false
		return
	
	var target = test_targets[current_test_index]
	print("NavigationTest: Navigating to target %d: %v" % [current_test_index + 1, target])
	
	if session_controller:
		var success = session_controller.request_navigation(target)
		if not success:
			print("NavigationTest: Failed to start navigation to ", target)
			# Try next target after delay
			await get_tree().create_timer(1.0).timeout
			current_test_index += 1
			_navigate_to_next_target()

func _on_navigation_completed() -> void:
	print("NavigationTest: Navigation completed to target %d in %.1fs" % 
		[current_test_index + 1, test_timer])
	
	if test_running:
		test_timer = 0.0
		current_test_index += 1
		
		# Wait before next target
		await get_tree().create_timer(test_delay).timeout
		_navigate_to_next_target()

func _on_navigation_cancelled() -> void:
	print("NavigationTest: Navigation cancelled at target %d" % [current_test_index + 1])

func _on_stuck_detected() -> void:
	print("NavigationTest: Stuck detected at target %d after %.1fs" % 
		[current_test_index + 1, test_timer])

func _draw() -> void:
	if not draw_test_targets:
		return
	
	# Draw test targets
	for i in range(test_targets.size()):
		var target = test_targets[i]
		var color = Color.CYAN if i == current_test_index else Color.BLUE.darkened(0.3)
		draw_circle(target, 8, color)
		draw_circle(target, 4, Color.WHITE)
		
		# Draw path between targets
		if i > 0:
			draw_line(test_targets[i-1], target, Color.BLUE.darkened(0.5), 1)
	
	# Draw current navigation path from session controller
	if session_controller and session_controller.is_navigation_active():
		var waypoints = session_controller.get_remaining_waypoints()
		if waypoints.size() > 1:
			for i in range(waypoints.size() - 1):
				draw_line(waypoints[i], waypoints[i+1], Color.YELLOW, 2)

func stop_test() -> void:
	test_running = false
	if session_controller:
		session_controller.cancel_navigation()
	print("NavigationTest: Test stopped")

## Manual navigation test - click to navigate
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not Input.is_key_pressed(KEY_SHIFT):  # Shift+click for other interactions
			var world_pos = get_global_mouse_position()
			print("NavigationTest: Manual navigation to ", world_pos)
			
			if session_controller:
				session_controller.request_navigation(world_pos)
			else:
				print("NavigationTest: No SessionController found!")

## Debug commands
func run_diagnostics() -> void:
	print("\n=== FULL SYSTEM DIAGNOSTIC ===")
	
	# Check NavigationRegion2D
	var nav_region = get_tree().root.find_child("NavigationRegion2D", true, false)
	if nav_region:
		print("✓ NavigationRegion2D found")
		print("  Enabled: ", nav_region.enabled)
		print("  Has polygon: ", nav_region.navigation_polygon != null)
		if nav_region.navigation_polygon:
			print("  Polygon count: ", nav_region.navigation_polygon.get_polygon_count())
			print("  Outline count: ", nav_region.navigation_polygon.get_outline_count())
	else:
		print("✗ NavigationRegion2D not found")
	
	# Check NavigationController
	if navigation_controller:
		print("✓ NavigationController found")
		var stats = navigation_controller.get_grid_stats()
		print("  Grid ready: ", stats.grid_ready)
		print("  Total cells: ", stats.total_cells)
		print("  Enabled cells: ", stats.enabled_cells)
	else:
		print("✗ NavigationController not found")
	
	# Check SessionController
	if session_controller:
		print("✓ SessionController found")
		print("  Grid ready: ", session_controller.is_grid_ready())
		print("  Navigation active: ", session_controller.is_navigation_active())
	else:
		print("✗ SessionController not found")
	
	# Check Player
	if player:
		print("✓ Player found: ", player.name)
		print("  Position: ", player.global_position)
		print("  Has NavigationAgent2D: ", player.has_node("NavigationAgent2D"))
		
		var nav_agent = player.get_node_or_null("NavigationAgent2D")
		if nav_agent:
			print("  NavigationAgent2D enabled: ", nav_agent.avoidance_enabled)
			print("  Target position: ", nav_agent.target_position)
			print("  Navigation layers: ", nav_agent.navigation_layers)
	else:
		print("✗ Player not found")
	
	print("=== END DIAGNOSTIC ===\n")
