# PathSmoother.gd
class_name PathSmoother

## Smooths hexagonal grid paths by removing unnecessary intermediate waypoints
## Uses line-of-sight checking to skip waypoints when possible

## Smooth a path by removing unnecessary waypoints
static func smooth_path(path: Array[Vector2], navigation_map_rid: RID, clearance_radius: float = 16.0) -> Array[Vector2]:
	if path.size() <= 2:
		return path
	
	var smoothed: Array[Vector2] = [path[0]]
	var current_index = 0
	
	while current_index < path.size() - 1:
		var farthest_visible = current_index + 1
		
		# Try to find the farthest visible waypoint
		for i in range(current_index + 2, path.size()):
			if has_line_of_sight(path[current_index], path[i], navigation_map_rid, clearance_radius):
				farthest_visible = i
			else:
				break
		
		smoothed.append(path[farthest_visible])
		current_index = farthest_visible
	
	return smoothed

## Check if there's a clear line of sight between two points on the navigation mesh
static func has_line_of_sight(from: Vector2, to: Vector2, navigation_map_rid: RID, clearance_radius: float = 16.0) -> bool:
	var direction = to - from
	var distance = direction.length()
	
	if distance < 1.0:
		return true
	
	# Sample points along the line
	var num_samples = max(3, int(distance / clearance_radius))
	
	for i in range(1, num_samples):
		var t = float(i) / float(num_samples)
		var sample_point = from.lerp(to, t)
		
		# Check if sample point is on navmesh
		var closest_point = NavigationServer2D.map_get_closest_point(navigation_map_rid, sample_point)
		var dist_to_navmesh = sample_point.distance_to(closest_point)
		
		# If too far from navmesh, no line of sight
		if dist_to_navmesh > clearance_radius * 0.5:
			return false
	
	return true

## Simplified smoothing using only collinearity check
static func smooth_path_simple(path: Array[Vector2], angle_threshold: float = 5.0) -> Array[Vector2]:
	if path.size() <= 2:
		return path
	
	var smoothed: Array[Vector2] = [path[0]]
	
	for i in range(1, path.size() - 1):
		var prev = smoothed[smoothed.size() - 1]
		var current = path[i]
		var next = path[i + 1]
		
		# Check if current waypoint is needed
		if not is_collinear(prev, current, next, angle_threshold):
			smoothed.append(current)
	
	smoothed.append(path[path.size() - 1])
	return smoothed

## Check if three points are roughly collinear (within angle threshold)
static func is_collinear(p1: Vector2, p2: Vector2, p3: Vector2, angle_threshold_deg: float) -> bool:
	var v1 = (p2 - p1).normalized()
	var v2 = (p3 - p2).normalized()
	
	var dot_product = v1.dot(v2)
	var angle = rad_to_deg(acos(clamp(dot_product, -1.0, 1.0)))
	
	return angle < angle_threshold_deg

## Reduce path resolution by skipping every N waypoints (aggressive simplification)
static func decimate_path(path: Array[Vector2], keep_every_n: int = 2) -> Array[Vector2]:
	if path.size() <= 2:
		return path
	
	var decimated: Array[Vector2] = [path[0]]
	
	for i in range(keep_every_n, path.size() - 1, keep_every_n):
		decimated.append(path[i])
	
	# Always include the final waypoint
	if decimated[decimated.size() - 1] != path[path.size() - 1]:
		decimated.append(path[path.size() - 1])
	
	return decimated
