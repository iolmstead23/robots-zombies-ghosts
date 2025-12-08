class_name HexEdgeChain
extends RefCounted

## Represents a continuous chain of connected edge segments forming a boundary
## Can be either a closed loop (e.g., isolated hex island) or an open path

# The edge segments that make up this chain
var edges: Array[HexEdgeSegment] = []

# Ordered sequence of corner vertices forming a polyline
var polyline: PackedVector2Array = PackedVector2Array()

# Whether this chain forms a closed loop
var is_closed: bool = false


func _init(p_is_closed: bool = false) -> void:
	is_closed = p_is_closed


func add_edge(edge: HexEdgeSegment) -> void:
	# Add an edge segment to this chain
	edges.append(edge)


func build_polyline() -> void:
	# Constructs the polyline from the edge segments
	# Must be called after all edges are added and properly ordered
	polyline.clear()

	if edges.is_empty():
		return

	# Add first edge's both corners
	polyline.append(edges[0].corner_a)
	polyline.append(edges[0].corner_b)

	# Add subsequent corners (skip duplicates at connections)
	for i in range(1, edges.size()):
		var edge := edges[i]
		var prev_corner := polyline[polyline.size() - 1]

		# Determine which corner to add based on connectivity
		# Add the corner that's not the same as the previous one
		if edge.corner_a.is_equal_approx(prev_corner):
			polyline.append(edge.corner_b)
		elif edge.corner_b.is_equal_approx(prev_corner):
			polyline.append(edge.corner_a)
		else:
			# Not connected - this shouldn't happen in a properly built chain
			# but handle it gracefully by adding both corners
			polyline.append(edge.corner_a)
			polyline.append(edge.corner_b)

	# For closed chains, ensure first and last points connect
	if is_closed and polyline.size() > 2:
		var first_point := polyline[0]
		var last_point := polyline[polyline.size() - 1]

		# If they're not close enough, add the first point again to close the loop
		if not first_point.is_equal_approx(last_point):
			polyline.append(first_point)


func get_edge_count() -> int:
	# Returns the number of edges in this chain
	return edges.size()


func get_point_count() -> int:
	# Returns the number of points in the polyline
	return polyline.size()


func is_empty() -> bool:
	# Returns true if this chain has no edges
	return edges.is_empty()


func _to_string() -> String:
	# Returns a string representation for debugging
	return "EdgeChain(edges=%d, points=%d, closed=%s)" % [
		edges.size(), polyline.size(), is_closed
	]
