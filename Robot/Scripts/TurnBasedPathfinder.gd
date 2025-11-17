extends Node
class_name TurnBasedPathfinder

# -----------------------------
# Constants
# -----------------------------
const MAX_MOVEMENT_DISTANCE: float = 20.0 * 32.0  # 20 ft -> pixels (32 px = 1 ft)
const OBSTACLE_BUFFER: float = 16.0
const MAX_SEGMENTS: int = 3
const SEGMENT_ANGLE_THRESHOLD: float = 45.0  # degrees
const STEPS_PER_SMOOTH_SEGMENT: int = 5
const SIMPLE_PATH_STEP_SIZE: float = 50.0
const PLAYER_COLLISION_RADIUS: float = 8.0
const RAY_LONG_DISTANCE: float = 100.0
const OBSTACLE_COLLISION_MASK: int = 1

# -----------------------------
# Signals
# -----------------------------
signal path_calculated(segments: Array, total_distance: float)
signal path_confirmed()
signal path_cancelled()

# -----------------------------
# Path data (state)
# -----------------------------
var current_path: Array[Vector2] = []
var path_segments: Array[Array] = []  # array of segments
var total_path_distance: float = 0.0
var is_path_valid: bool = false

# -----------------------------
# Visualization config (mutable)
# -----------------------------
var preview_path: Array[Vector2] = []
var preview_color: Color = Color.CYAN
var confirmed_color: Color = Color.GREEN

# -----------------------------
# References (set in initialize)
# -----------------------------
var player: CharacterBody2D
var navigation_region: NavigationRegion2D
var physics_space: PhysicsDirectSpaceState2D

# -----------------------------
# Public API (alphabetized)
# -----------------------------
func calculate_path_to(destination: Vector2) -> bool:
	"""Calculate a multi-segment path from the player's position to destination.
	Returns true if a path exists (even if trimmed), false otherwise."""
	var start_pos: Vector2 = player.global_position

	# reset path data
	current_path.clear()
	path_segments.clear()
	total_path_distance = 0.0
	is_path_valid = false

	print("TurnBasedPathfinder: Calculating path from ", start_pos, " to ", destination)

	var nav_path: PackedVector2Array

	if navigation_region:
		nav_path = NavigationServer2D.map_get_path(
			navigation_region.get_navigation_map(),
			start_pos,
			destination,
			true
		)
	else:
		nav_path = _create_simple_path(start_pos, destination)

	if nav_path.is_empty():
		print("TurnBasedPathfinder: No path found")
		return false

	print("TurnBasedPathfinder: Raw path has ", nav_path.size(), " points")

	_generate_segments(nav_path)

	# Trim if too long
	if total_path_distance > MAX_MOVEMENT_DISTANCE:
		_trim_path_to_max_distance()

	# Validate obstacle-free
	is_path_valid = _validate_path()
	if not is_path_valid:
		print("TurnBasedPathfinder: Path invalid due to obstacles")

	path_calculated.emit(path_segments, total_path_distance)
	return is_path_valid


func cancel_path() -> void:
	"""Cancel current path planning and clear state."""
	current_path.clear()
	path_segments.clear()
	total_path_distance = 0.0
	is_path_valid = false
	preview_path.clear()
	path_cancelled.emit()


func confirm_path() -> void:
	"""Confirm and lock in the current path for movement execution."""
	if is_path_valid:
		print("TurnBasedPathfinder: Path confirmed with ", current_path.size(), " points")
		path_confirmed.emit()
	else:
		print("TurnBasedPathfinder: Cannot confirm - path invalid.")


func get_next_position(progress: float) -> Vector2:
	"""Return a position along the current_path given a normalized progress [0.0, 1.0]."""
	if current_path.is_empty():
		push_warning("get_next_position called with empty path; returning player position")
		return player.global_position

	progress = clamp(progress, 0.0, 1.0)

	if progress == 0.0:
		return current_path[0]
	elif progress >= 1.0:
		return current_path[-1]

	var target_distance: float = total_path_distance * progress
	var accumulated: float = 0.0

	for i in range(1, current_path.size()):
		var a: Vector2 = current_path[i - 1]
		var b: Vector2 = current_path[i]
		var seg_dist: float = a.distance_to(b)

		if accumulated + seg_dist >= target_distance:
			var remaining_in_seg: float = target_distance - accumulated
			var t: float = remaining_in_seg / seg_dist if seg_dist > 0.0 else 0.0
			t = clamp(t, 0.0, 1.0)
			return a.lerp(b, t)

		accumulated += seg_dist

	return current_path[-1]


func initialize(player_ref: CharacterBody2D) -> void:
	"""Initialize references. Must be called before using the pathfinder."""
	player = player_ref
	# find navigation region (group-based search allows flexibility)
	var nav_regions := player.get_tree().get_nodes_in_group("navigation_region")
	if nav_regions.size() > 0:
		navigation_region = nav_regions[0]
		print("TurnBasedPathfinder: Found navigation region")
	else:
		print("TurnBasedPathfinder: No navigation region found, using fallback pathing")

	# initialize physics space for raycasts / shape queries
	var world_2d = get_viewport().get_world_2d()
	
	if world_2d:
		physics_space = world_2d.direct_space_state
	else:
		push_warning("TurnBasedPathfinder: World2D not available; physics queries will fail")

# -----------------------------
# Private helpers (alphabetized, extracted duplicates)
# -----------------------------
func _adjust_point_for_obstacles(point: Vector2, _index: int = 0, _path: PackedVector2Array = PackedVector2Array()) -> Vector2:
	"""Adjust a point outward from nearby obstacles by OBSTACLE_BUFFER using raycasts."""
	var adjusted: Vector2 = point
	var ray_dirs: Array = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()
	]

	var push_vector: Vector2 = Vector2.ZERO
	var obstacle_detected: bool = false

	for dir in ray_dirs:
		var from: Vector2 = point
		var to: Vector2 = point + dir * OBSTACLE_BUFFER
		var result := _intersect_ray(from, to, OBSTACLE_COLLISION_MASK)
		if result:
			var distance: float = point.distance_to(result.position)
			if distance < OBSTACLE_BUFFER:
				var strength: float = (OBSTACLE_BUFFER - distance) / OBSTACLE_BUFFER
				push_vector += -dir * strength * OBSTACLE_BUFFER * 0.5
				obstacle_detected = true

	if obstacle_detected:
		adjusted = point + push_vector
		adjusted = _validate_adjusted_point(adjusted, point)

	return adjusted


func _calculate_segment_length(segment: Array) -> float:
	"""Return the linear length of a segment (sum of pairwise distances)."""
	var length: float = 0.0
	for i in range(1, segment.size()):
		length += segment[i - 1].distance_to(segment[i])
	return length


func _catmull_rom_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	"""Return the point on a Catmull-Rom spline for parameter t in [0,1]."""
	var t2: float = t * t
	var t3: float = t2 * t

	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _create_circle_query(pos: Vector2, radius: float = PLAYER_COLLISION_RADIUS, mask: int = OBSTACLE_COLLISION_MASK) -> PhysicsShapeQueryParameters2D:
	"""Create and return a reusable circle shape query for 'pos'."""
	var shape_query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_query.shape = circle
	shape_query.transform = Transform2D(0, pos)
	shape_query.collision_mask = mask
	return shape_query


func _create_simple_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	"""Fallback straight-line path with intermediate evenly spaced points."""
	var path: PackedVector2Array = PackedVector2Array()
	var distance: float = from.distance_to(to)
	var dir: Vector2 = (to - from).normalized()

	path.append(from)

	var steps: int = int(distance / SIMPLE_PATH_STEP_SIZE)
	for i in range(1, steps):
		var p: Vector2 = from + dir * (SIMPLE_PATH_STEP_SIZE * i)
		path.append(p)

	if distance > SIMPLE_PATH_STEP_SIZE:
		path.append(to)

	return path


func _find_best_alternative(original: Vector2, _blocked: Vector2) -> Vector2:
	"""Try positions around 'original' (circle sampling) and return the best free spot."""
	var best_pos: Vector2 = original
	var best_min_dist: float = -INF

	for angle in range(0, 360, 30):
		var offset: Vector2 = Vector2.from_angle(deg_to_rad(angle)) * OBSTACLE_BUFFER * 0.7
		var test_pos: Vector2 = original + offset

		var sq := _create_circle_query(test_pos, PLAYER_COLLISION_RADIUS, OBSTACLE_COLLISION_MASK)
		if physics_space.intersect_shape(sq).is_empty():
			var obstacle_dist: float = _get_min_obstacle_distance(test_pos)
			if obstacle_dist > best_min_dist:
				best_min_dist = obstacle_dist
				best_pos = test_pos

	return best_pos


func _generate_segments(raw_path: PackedVector2Array) -> void:
	"""Turn raw path points into segments, computing total distance and smoothing."""
	if raw_path.size() < 2:
		return

	var current_segment: Array = []
	var last_direction: Vector2 = Vector2.ZERO
	total_path_distance = 0.0
	current_path.clear()
	path_segments.clear()

	for i in range(raw_path.size()):
		var point: Vector2 = raw_path[i]

		if i == 0:
			current_segment.append(point)
			current_path.append(point)
		else:
			var prev_point: Vector2 = current_path[-1]
			var direction: Vector2 = (point - prev_point).normalized()

			if last_direction != Vector2.ZERO:
				var angle_change: float = rad_to_deg(last_direction.angle_to(direction))
				if abs(angle_change) > SEGMENT_ANGLE_THRESHOLD and current_segment.size() > 1:
					# finalize previous segment
					path_segments.append(_smooth_segment(current_segment))
					# start new segment, overlap last point
					current_segment = [current_segment[-1]]

			current_segment.append(point)
			current_path.append(point)
			last_direction = direction

			# update running distance
			total_path_distance += prev_point.distance_to(point)

	# finalize final segment
	if current_segment.size() > 1:
		path_segments.append(_smooth_segment(current_segment))

	# fallback single segment
	if path_segments.is_empty() and current_path.size() > 1:
		path_segments.append(_smooth_segment(current_path))

	print("TurnBasedPathfinder: Created %d segment(s), total distance: %f" % [path_segments.size(), total_path_distance])


func _get_min_obstacle_distance(pos: Vector2) -> float:
	"""Raycast in cardinal directions to find closest obstacle distance (returns INF if none)."""
	var min_dist: float = INF
	var dirs: Array = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]

	for dir in dirs:
		var from: Vector2 = pos
		var to: Vector2 = pos + dir * RAY_LONG_DISTANCE
		var result := _intersect_ray(from, to, OBSTACLE_COLLISION_MASK)
		if result:
			min_dist = min(min_dist, pos.distance_to(result.position))

	return min_dist


func _intersect_ray(from: Vector2, to: Vector2, mask: int = OBSTACLE_COLLISION_MASK) -> Dictionary:
	"""Helper wrapper for ray intersection. Returns result dictionary or empty dictionary."""
	if not physics_space:
		return {}
	var ray_query := PhysicsRayQueryParameters2D.create(from, to)
	ray_query.collision_mask = mask
	return physics_space.intersect_ray(ray_query)


func _merge_shortest_segments() -> void:
	"""Merge shortest adjacent segments until segment count <= MAX_SEGMENTS."""
	while path_segments.size() > MAX_SEGMENTS:
		var shortest_idx: int = -1
		var shortest_len: float = INF
		for i in range(path_segments.size()):
			var length: float = _calculate_segment_length(path_segments[i])
			if length < shortest_len:
				shortest_len = length
				shortest_idx = i

		if shortest_idx <= 0:
			# merge with next if first
			var merged := path_segments[shortest_idx] + path_segments[shortest_idx + 1].slice(1)
			path_segments[shortest_idx] = _smooth_segment(merged)
			path_segments.remove_at(shortest_idx + 1)
		else:
			# merge with previous
			var merged_prev := path_segments[shortest_idx - 1] + path_segments[shortest_idx].slice(1)
			path_segments[shortest_idx - 1] = _smooth_segment(merged_prev)
			path_segments.remove_at(shortest_idx)


func _smooth_segment(segment: Array) -> Array:
	"""Apply Catmull-Rom smoothing (with validation) to a segment and return new points."""
	if segment.size() <= 2:
		return segment.duplicate()

	var smoothed: Array = []
	for i in range(segment.size() - 1):
		var p0: Vector2 = segment[max(0, i - 1)]
		var p1: Vector2 = segment[i]
		var p2: Vector2 = segment[min(i + 1, segment.size() - 1)]
		var p3: Vector2 = segment[min(i + 2, segment.size() - 1)]

		for t_i in range(STEPS_PER_SMOOTH_SEGMENT):
			var t_norm: float = float(t_i) / float(STEPS_PER_SMOOTH_SEGMENT)
			var pt: Vector2 = _catmull_rom_point(p0, p1, p2, p3, t_norm)
			pt = _validate_adjusted_point(pt, p1)
			smoothed.append(pt)

	smoothed.append(segment[-1])
	return smoothed


func _trim_path_to_max_distance() -> void:
	"""Trim the path so that total_path_distance <= MAX_MOVEMENT_DISTANCE."""
	var accumulated: float = 0.0
	var trimmed_path: Array[Vector2] = []
	var trimmed_segments: Array[Array] = []

	for segment in path_segments:
		var trimmed_segment: Array[Vector2] = []
		for i in range(segment.size()):
			if i > 0:
				var seg_dist: float = segment[i - 1].distance_to(segment[i])
				if accumulated + seg_dist > MAX_MOVEMENT_DISTANCE:
					var remaining: float = MAX_MOVEMENT_DISTANCE - accumulated
					var t: float = remaining / seg_dist
					var final_point: Vector2 = segment[i - 1].lerp(segment[i], clamp(t, 0.0, 1.0))
					trimmed_segment.append(final_point)
					trimmed_path.append(final_point)
					accumulated = MAX_MOVEMENT_DISTANCE
					break
				accumulated += seg_dist

			trimmed_segment.append(segment[i])
			trimmed_path.append(segment[i])

		if trimmed_segment.size() > 1:
			trimmed_segments.append(trimmed_segment)

		if accumulated >= MAX_MOVEMENT_DISTANCE:
			break

	current_path = trimmed_path
	path_segments = trimmed_segments
	total_path_distance = min(accumulated, MAX_MOVEMENT_DISTANCE)

	print("TurnBasedPathfinder: Trimmed path to %f pixels" % total_path_distance)


func _validate_adjusted_point(adjusted: Vector2, original: Vector2) -> Vector2:
	"""Ensure an adjusted point is not colliding; otherwise find and return a nearby alternative."""
	var sq := _create_circle_query(adjusted, PLAYER_COLLISION_RADIUS, OBSTACLE_COLLISION_MASK)
	if physics_space.intersect_shape(sq).is_empty():
		return adjusted
	# blocked — search for an alternative
	return _find_best_alternative(original, adjusted)


func _validate_path() -> bool:
	"""Validate entire path (no ray intersections along each pair of points)."""
	for segment in path_segments:
		for i in range(1, segment.size()):
			var from: Vector2 = segment[i - 1]
			var to: Vector2 = segment[i]
			if _intersect_ray(from, to, OBSTACLE_COLLISION_MASK):
				return false
	return true
