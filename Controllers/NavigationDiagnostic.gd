# NavigationDiagnostic.gd
# Attach this to any Node in your scene to diagnose navigation setup issues
# Run the game and check the console output

extends Node

func _ready() -> void:
	print("\n========================================")
	print("NAVIGATION SYSTEM DIAGNOSTIC")
	print("========================================\n")
	
	# Wait a frame for everything to initialize
	await get_tree().process_frame
	
	diagnose_navigation_system()

func diagnose_navigation_system() -> void:
	var issues_found := 0
	
	# 1. Check for NavigationRegion2D
	print("1. Checking NavigationRegion2D...")
	var nav_region = find_navigation_region()
	
	if not nav_region:
		print("   ❌ ERROR: No NavigationRegion2D found in scene!")
		print("   → Add a NavigationRegion2D node to your scene")
		issues_found += 1
	else:
		print("   ✓ NavigationRegion2D found: ", nav_region.name)
		print("   Path: ", nav_region.get_path())
		
		# 2. Check NavigationPolygon
		print("\n2. Checking NavigationPolygon...")
		var nav_poly = nav_region.navigation_polygon
		
		if not nav_poly:
			print("   ❌ ERROR: NavigationRegion2D has no NavigationPolygon!")
			print("   → Select the NavigationRegion2D in the scene tree")
			print("   → In Inspector, create a new NavigationPolygon resource")
			issues_found += 1
		else:
			print("   ✓ NavigationPolygon exists")
			
			# 3. Check outlines
			print("\n3. Checking NavigationPolygon outlines...")
			var outline_count = nav_poly.get_outline_count()
			
			if outline_count == 0:
				print("   ❌ ERROR: NavigationPolygon has no outlines!")
				print("   → Select the NavigationRegion2D")
				print("   → Click 'Edit Polygon' in the toolbar")
				print("   → Draw an outline around your navigable area")
				print("   → Make sure the outline is closed")
				issues_found += 1
			else:
				print("   ✓ Found %d outline(s)" % outline_count)
				
				# 4. Check outline vertices
				print("\n4. Checking outline details...")
				for i in range(outline_count):
					var outline = nav_poly.get_outline(i)
					print("   Outline %d: %d vertices" % [i, outline.size()])
					
					if outline.size() < 3:
						print("   ❌ ERROR: Outline %d has too few vertices!" % i)
						issues_found += 1
					else:
						# Calculate bounds
						var min_pos := Vector2(INF, INF)
						var max_pos := Vector2(-INF, -INF)
						
						for vertex in outline:
							var world_pos = nav_region.to_global(vertex)
							min_pos.x = min(min_pos.x, world_pos.x)
							min_pos.y = min(min_pos.y, world_pos.y)
							max_pos.x = max(max_pos.x, world_pos.x)
							max_pos.y = max(max_pos.y, world_pos.y)
						
						var size = max_pos - min_pos
						print("      Position: (%.1f, %.1f) to (%.1f, %.1f)" % [min_pos.x, min_pos.y, max_pos.x, max_pos.y])
						print("      Size: %.1f x %.1f" % [size.x, size.y])
						
						# Show first few vertices
						print("      First vertices (local):")
						for j in range(min(3, outline.size())):
							print("        [%d]: %v" % [j, outline[j]])
	
	# 5. Check NavigationController
	print("\n5. Checking NavigationController...")
	var nav_controller = find_navigation_controller()
	
	if not nav_controller:
		print("   ❌ ERROR: NavigationController not found!")
		print("   → Add NavigationController node to your scene")
		print("   → Attach the NavigationController.gd script")
		issues_found += 1
	else:
		print("   ✓ NavigationController found: ", nav_controller.name)
		print("   Path: ", nav_controller.get_path())
		
		# Check if it has the script
		var script = nav_controller.get_script()
		if script:
			print("   ✓ Script attached: ", script.resource_path)
		else:
			print("   ❌ ERROR: No script attached to NavigationController!")
			issues_found += 1
		
		# Check grid stats
		if nav_controller.has_method("get_grid_stats"):
			var stats = nav_controller.get_grid_stats()
			print("\n   Grid Statistics:")
			print("      Total cells: ", stats.total_cells)
			print("      Enabled cells: ", stats.enabled_cells)
			print("      Disabled cells: ", stats.disabled_cells)
			print("      Grid bounds: ", stats.grid_bounds)
			
			if stats.total_cells == 0:
				print("\n   ⚠️  WARNING: Grid has 0 cells!")
				print("   This usually means:")
				print("      - NavigationPolygon has no outlines")
				print("      - NavigationRegion2D reference is wrong")
				print("      - Grid bounds are invalid")
		
		# Check settings
		print("\n   NavigationController Settings:")
		print("      hex_size: ", nav_controller.hex_size if "hex_size" in nav_controller else "NOT SET")
		print("      obstacle_collision_layer: ", nav_controller.obstacle_collision_layer if "obstacle_collision_layer" in nav_controller else "NOT SET")
		print("      grid_visible: ", nav_controller.grid_visible if "grid_visible" in nav_controller else "NOT SET")
	
	# 6. Check SessionController
	print("\n6. Checking SessionController...")
	var session_controller = find_session_controller()
	
	if not session_controller:
		print("   ❌ ERROR: SessionController not found!")
		print("   → Add SessionController node to your scene")
		print("   → Attach the SessionController.gd script")
		issues_found += 1
	else:
		print("   ✓ SessionController found: ", session_controller.name)
		print("   Path: ", session_controller.get_path())
		
		var script = session_controller.get_script()
		if script:
			print("   ✓ Script attached: ", script.resource_path)
		else:
			print("   ❌ ERROR: No script attached to SessionController!")
			issues_found += 1
	
	# Summary
	print("\n========================================")
	if issues_found == 0:
		print("✓ DIAGNOSTIC COMPLETE - No issues found!")
		print("  Grid should be working.")
		print("  If you still see 0 cells, check:")
		print("    - NavigationPolygon is visible in editor")
		print("    - Outline is properly closed")
		print("    - Try clicking 'Bake NavigationPolygon'")
	else:
		print("❌ FOUND %d ISSUE(S)" % issues_found)
		print("  Fix the issues above and run again")
	print("========================================\n")

func find_navigation_region() -> NavigationRegion2D:
	return find_node_by_type(get_tree().root, NavigationRegion2D)

func find_navigation_controller() -> Node:
	return find_node_by_class_name(get_tree().root, "NavigationController")

func find_session_controller() -> Node:
	return find_node_by_class_name(get_tree().root, "SessionController")

func find_node_by_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = find_node_by_type(child, type)
		if result:
			return result
	
	return null

# FIXED: Properly detect class_name using get_global_name()
func find_node_by_class_name(node: Node, node_class_name: String) -> Node:
	# Check if the node's class matches
	if node.get_class() == node_class_name:
		return node
	
	# Check script's class_name using get_global_name()
	var script = node.get_script()
	if script:
		# This is the correct way to get a script's class_name
		var script_class_name = script.get_global_name()
		if script_class_name == node_class_name:
			return node
	
	# Recursively search children
	for child in node.get_children():
		var result = find_node_by_class_name(child, node_class_name)
		if result:
			return result
	
	return null
