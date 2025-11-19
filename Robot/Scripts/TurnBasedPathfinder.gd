extends Node
class_name TurnBasedPathfinder

# --- Constants ---
const PX_PER_FT := 16.0
const MAX_DIST := 20.0 * PX_PER_FT
const OBSTACLE_BUFFER := 16.0
const SEGMENT_ANGLE_DEG := 45.0
const MAX_SEGMENTS := 3
const SMOOTH_STEPS := 5
const SIMPLE_STEP := 50.0
const COLLISION_RADIUS := 8.0
const LONG_RAY := 100.0
const COLLISION_MASK := 1

# --- Signals ---
signal path_calculated(segments: Array, total_distance: float)
signal path_confirmed()
signal path_cancelled()

# --- State ---
var current_path: Array[Vector2] = []
var path_segments: Array[Array] = []
var total_distance: float = 0.0
var is_path_valid: bool = false

# --- Visual Config ---
var preview_path: Array[Vector2] = []
var preview_color: Color = Color.CYAN
var confirmed_color: Color = Color.GREEN

# --- External References ---
var player: CharacterBody2D
var navigation_region: NavigationRegion2D
var physics_space: PhysicsDirectSpaceState2D

# =================== PUBLIC API ====================

func initialize(player_ref: CharacterBody2D) -> void:
	player = player_ref
	var nav_regions := player.get_tree().get_nodes_in_group("navigation_region")
	navigation_region = nav_regions[0] if nav_regions.size() > 0 else null
	var world_2d = get_viewport().get_world_2d()
	physics_space = world_2d.direct_space_state if world_2d else null

func calculate_path_to(destination: Vector2) -> bool:
	_reset_path_state()
	var start: Vector2 = player.global_position
	var nav_path: PackedVector2Array = _get_navigation_path(start, destination)
	if nav_path.is_empty(): return false
	_generate_segments(nav_path)
	if total_distance > MAX_DIST: _trim_path()
	is_path_valid = _validate_path()
	path_calculated.emit(path_segments, total_distance)
	return is_path_valid

func cancel_path() -> void:
	_reset_path_state()
	preview_path.clear()
	path_cancelled.emit()

func confirm_path() -> void:
	if is_path_valid:
		path_confirmed.emit()

func get_next_position(progress: float) -> Vector2:
	if current_path.is_empty():
		return player.global_position
	progress = clamp(progress, 0.0, 1.0)
	if progress == 0.0: return current_path[0]
	if progress >= 1.0: return current_path[-1]
	var target_dist := total_distance * progress
	var accum := 0.0
	for i in range(1, current_path.size()):
		var seg_dist = current_path[i - 1].distance_to(current_path[i])
		if accum + seg_dist >= target_dist:
			var t: float = (target_dist - accum) / seg_dist if seg_dist > 0.0 else 0.0
			return current_path[i - 1].lerp(current_path[i], clamp(t, 0.0, 1.0))
		accum += seg_dist
	return current_path[-1]

# =================== PRIVATE HELPERS ===============

func _reset_path_state() -> void:
	current_path.clear()
	path_segments.clear()
	total_distance = 0.0
	is_path_valid = false

func _get_navigation_path(start: Vector2, destination: Vector2) -> PackedVector2Array:
	if navigation_region:
		return NavigationServer2D.map_get_path(
			navigation_region.get_navigation_map(),
			start, destination, true)
	return _straight_path(start, destination)

func _straight_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	var dist = from.distance_to(to)
	var dir = (to - from).normalized()
	path.append(from)
	for i in range(1, int(dist / SIMPLE_STEP)):
		path.append(from + dir * (SIMPLE_STEP * i))
	if dist > SIMPLE_STEP: path.append(to)
	return path

func _generate_segments(raw_path: PackedVector2Array) -> void:
	if raw_path.size() < 2: return
	var seg: Array = []
	var last_dir = Vector2.ZERO
	total_distance = 0.0
	current_path.clear()
	path_segments.clear()
	for i in raw_path.size():
		var pt: Vector2 = raw_path[i]
		if i == 0: seg.append(pt); current_path.append(pt)
		else:
			var prev = current_path[-1]
			var dir = (pt - prev).normalized()
			if last_dir != Vector2.ZERO and abs(rad_to_deg(last_dir.angle_to(dir))) > SEGMENT_ANGLE_DEG and seg.size() > 1:
				path_segments.append(_smooth_segment(seg)); seg = [seg[-1]]
			seg.append(pt); current_path.append(pt)
			last_dir = dir
			total_distance += prev.distance_to(pt)
	if seg.size() > 1: path_segments.append(_smooth_segment(seg))
	if path_segments.is_empty() and current_path.size() > 1:
		path_segments.append(_smooth_segment(current_path))

func _smooth_segment(segment: Array) -> Array:
	if segment.size() <= 2: return segment.duplicate()
	var smoothed: Array = []
	for i in range(segment.size() - 1):
		var p0 = segment[max(0, i - 1)]
		var p1 = segment[i]
		var p2 = segment[min(i + 1, segment.size() - 1)]
		var p3 = segment[min(i + 2, segment.size() - 1)]
		for t_i in range(SMOOTH_STEPS):
			var t = float(t_i) / float(SMOOTH_STEPS)
			var pt = _catmull_rom(p0, p1, p2, p3, t)
			pt = _validate_adjusted_point(pt, p1)
			smoothed.append(pt)
	smoothed.append(segment[-1])
	return smoothed

func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 = t * t
	var t3 = t2 * t
	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _trim_path() -> void:
	var accum = 0.0
	var trimmed_path: Array[Vector2] = []
	var trimmed_segments: Array[Array] = []
	for seg in path_segments:
		var new_seg: Array[Vector2] = []
		for i in range(seg.size()):
			if i > 0:
				var seg_dist = seg[i-1].distance_to(seg[i])
				if accum + seg_dist > MAX_DIST:
					var t = (MAX_DIST - accum) / seg_dist
					var final_pt = seg[i-1].lerp(seg[i], clamp(t,0,1))
					new_seg.append(final_pt)
					trimmed_path.append(final_pt)
					accum = MAX_DIST
					break
				accum += seg_dist
			new_seg.append(seg[i])
			trimmed_path.append(seg[i])
		if new_seg.size() > 1: trimmed_segments.append(new_seg)
		if accum >= MAX_DIST: break
	current_path = trimmed_path
	path_segments = trimmed_segments
	total_distance = min(accum, MAX_DIST)

func _validate_path() -> bool:
	for seg in path_segments:
		for i in range(1, seg.size()):
			if _ray_intersect(seg[i - 1], seg[i]):
				return false
	return true

# -------------- Adjustment/Collision Utilities --------------

func _validate_adjusted_point(adjusted: Vector2, original: Vector2) -> Vector2:
	var sq := _circle_query(adjusted)
	if physics_space and physics_space.intersect_shape(sq).is_empty():
		return adjusted
	return _find_alternative(original)

func _find_alternative(origin: Vector2) -> Vector2:
	var best = origin
	var best_dist = -INF
	for angle in range(0, 360, 30):
		var offset = Vector2.from_angle(deg_to_rad(angle)) * OBSTACLE_BUFFER * 0.7
		var pos = origin + offset
		var sq = _circle_query(pos)
		if physics_space and physics_space.intersect_shape(sq).is_empty():
			var dist = _min_obstacle_dist(pos)
			if dist > best_dist:
				best_dist = dist
				best = pos
	return best

func _adjust_for_obstacles(point: Vector2) -> Vector2:
	var dirs = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1,1).normalized(), Vector2(1,-1).normalized(),
		Vector2(-1,1).normalized(), Vector2(-1,-1).normalized()
	]
	var push = Vector2.ZERO
	var hit = false
	for dir in dirs:
		var to = point + dir * OBSTACLE_BUFFER
		if _ray_intersect(point, to):
			var dist = point.distance_to(_ray_intersect(point, to).position)
			if dist < OBSTACLE_BUFFER:
				push += -dir * ((OBSTACLE_BUFFER - dist) / OBSTACLE_BUFFER) * OBSTACLE_BUFFER * 0.5
				hit = true
	return _validate_adjusted_point(point + push, point) if hit else point

# -------------- Game-Physics Queries --------------

func _circle_query(pos: Vector2, radius: float = COLLISION_RADIUS) -> PhysicsShapeQueryParameters2D:
	var sq := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	sq.shape = circle
	sq.transform = Transform2D(0, pos)
	sq.collision_mask = COLLISION_MASK
	return sq

func _ray_intersect(from: Vector2, to: Vector2) -> Dictionary:
	if not physics_space: return {}
	var pq = PhysicsRayQueryParameters2D.create(from, to)
	pq.collision_mask = COLLISION_MASK
	return physics_space.intersect_ray(pq)

func _min_obstacle_dist(pos: Vector2) -> float:
	var min_dist = INF
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var to = pos + dir * LONG_RAY
		var res = _ray_intersect(pos, to)
		if res: min_dist = min(min_dist, pos.distance_to(res.position))
	return min_dist
