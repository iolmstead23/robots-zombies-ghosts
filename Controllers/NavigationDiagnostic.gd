extends Node

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("DEEP NAVIGATION DIAGNOSTIC")
	print("=".repeat(60) + "\n")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	run_diagnostics()

func run_diagnostics() -> void:
	var nav_region = find_navigation_region()
	
	if not nav_region:
		print("❌ CRITICAL: No NavigationRegion2D found!")
		return
	
	print("✓ Found NavigationRegion2D: ", nav_region.get_path())
	print("  Enabled: ", nav_region.enabled)
	print("  Position: ", nav_region.global_position)
	
	var nav_poly = nav_region.navigation_polygon
	if not nav_poly:
		print("❌ CRITICAL: No NavigationPolygon assigned!")
		return
	
	print("\n" + "-".repeat(60))
	print("NAVIGATION POLYGON ANALYSIS")
	print("-".repeat(60))
	
	# Check outlines
	var outline_count = nav_poly.get_outline_count()
	print("\n1. Outlines: ", outline_count)
	
	if outline_count == 0:
		print("   ❌ ERROR: No outlines defined!")
		print("   → You must draw an outline in the editor")
		return
	
	for i in range(outline_count):
		var outline = nav_poly.get_outline(i)
		print("   Outline %d: %d vertices" % [i, outline.size()])
		
		if outline.size() >= 3:
			print("   First 3 vertices:")
			for j in range(min(3, outline.size())):
				var local_vertex = outline[j]
				var world_vertex = nav_region.to_global(local_vertex)
				print("      [%d] Local: %v → World: %v" % [j, local_vertex, world_vertex])
	
	# Check polygons (CRITICAL - this is what's missing!)
	var polygon_count = nav_poly.get_polygon_count()
	print("\n2. Baked Polygons: ", polygon_count)
	
	if polygon_count == 0:
		print("   ❌ CRITICAL ERROR: NavigationPolygon has NO BAKED POLYGONS!")
		print("   This is why you're getting 0 cells!")
		print("\n   SOLUTIONS:")
		print("   A) IN EDITOR:")
		print("      1. Select NavigationRegion2D")
		print("      2. Look for 'Bake NavigationPolygon' button in toolbar or inspector")
		print("      3. Click it to generate navigation mesh")
		print("\n   B) PROGRAMMATICALLY (trying now):")
		print("      Calling make_polygons_from_outlines()...")
		
		nav_poly.make_polygons_from_outlines()
		await get_tree().process_frame
		
		polygon_count = nav_poly.get_polygon_count()
		print("      After baking: ", polygon_count, " polygons")
		
		if polygon_count == 0:
			print("      ❌ Auto-baking failed!")
			print("      → You MUST manually bake in the editor")
			return
		else:
			print("      ✓ Auto-baking succeeded!")
	else:
		print("   ✓ Polygons exist")
	
	# Show polygon details
	for i in range(min(3, polygon_count)):
		var polygon = nav_poly.get_polygon(i)
		print("   Polygon %d: %d vertices" % [i, polygon.size()])
	
	# Check vertices
	var vertices = nav_poly.get_vertices()
	print("\n3. Vertices: ", vertices.size())
	if vertices.size() > 0:
		print("   First vertex (local): ", vertices[0])
		print("   First vertex (world): ", nav_region.to_global(vertices[0]))
	
	# Check NavigationServer
	print("\n" + "-".repeat(60))
	print("NAVIGATION SERVER ANALYSIS")
	print("-".repeat(60))
	
	var region_rid = nav_region.get_rid()
	var map_rid = nav_region.get_navigation_map()
	
	print("\nRegion RID: ", region_rid)
	print("Map RID: ", map_rid)
	print("Map is valid: ", map_rid.is_valid())
	
	if not map_rid.is_valid():
		print("❌ ERROR: Navigation map is invalid!")
		return
	
	# Test specific points
	print("\n" + "-".repeat(60))
	print("POINT TESTING")
	print("-".repeat(60))
	
	# Get center of first outline
	if outline_count > 0:
		var outline = nav_poly.get_outline(0)
		var center = Vector2.ZERO
		for vertex in outline:
			center += vertex
		center /= outline.size()
		
		var world_center = nav_region.to_global(center)
		
		print("\nTesting outline center:")
		print("  Local: ", center)
		print("  World: ", world_center)
		
		# Test with map_get_closest_point
		var closest = NavigationServer2D.map_get_closest_point(map_rid, world_center)
		var distance = world_center.distance_to(closest)
		
		print("  Closest navmesh point: ", closest)
		print("  Distance: ", distance)
		
		if distance < 50.0:
			print("  ✓ Point is close to navmesh!")
		else:
			print("  ❌ Point is FAR from navmesh - polygon might not be baked correctly")
		
		# Test multiple points in a grid
		print("\nTesting sample points across area:")
		var test_points = [
			world_center,
			world_center + Vector2(50, 0),
			world_center + Vector2(0, 50),
			world_center + Vector2(-50, 0),
			world_center + Vector2(0, -50)
		]
		
		var valid_points = 0
		for point in test_points:
			var closest_pt = NavigationServer2D.map_get_closest_point(map_rid, point)
			var dist = point.distance_to(closest_pt)
			if dist < 50.0:
				valid_points += 1
				print("  ✓ Point %v is navigable (dist: %.1f)" % [point, dist])
			else:
				print("  ✗ Point %v is NOT navigable (dist: %.1f)" % [point, dist])
		
		print("\n  Valid points: %d / %d" % [valid_points, test_points.size()])
		
		if valid_points == 0:
			print("\n  ❌ CRITICAL: No test points are navigable!")
			print("  → The NavigationPolygon is NOT properly baked")
			print("  → You MUST bake it in the editor")
	
	# Final recommendation
	print("\n" + "=".repeat(60))
	print("RECOMMENDATION")
	print("=".repeat(60))
	
	if polygon_count == 0:
		print("\n❌ YOUR NAVIGATION POLYGON IS NOT BAKED!")
		print("\nTO FIX:")
		print("1. Select 'NavigationRegion2D' in the Scene tree")
		print("2. In the toolbar at the top, look for polygon editing tools")
		print("3. Click the 'Bake NavigationPolygon' button")
		print("   (It might be in the Inspector under the NavigationPolygon resource)")
		print("4. You should see the area fill with a colored mesh")
		print("5. Save your scene and run again")
	elif vertices.size() == 0:
		print("\n❌ Navigation polygon has no vertices!")
		print("Try redrawing the outline and baking again")
	else:
		print("\n✓ Navigation polygon appears to be configured correctly")
		print("If grid still shows 0 cells, check:")
		print("  - hex_size setting (currently 8.0)")
		print("  - obstacle_collision_layer setting")
		print("  - Ensure no obstacles are blocking entire area")
	
	print("\n" + "=".repeat(60) + "\n")

func find_navigation_region() -> NavigationRegion2D:
	return find_node_by_type(get_tree().root, NavigationRegion2D)

func find_node_by_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result = find_node_by_type(child, type)
		if result:
			return result
	
	return null
