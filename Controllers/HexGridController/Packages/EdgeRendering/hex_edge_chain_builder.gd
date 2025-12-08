class_name HexEdgeChainBuilder
extends RefCounted

## Builds edge chains from navigable hex cells
## Detects boundary edges, groups them into continuous chains, and orders them into polylines

# Direction constants now provided by HexDirections utility
# References maintained for backwards compatibility during refactoring
const FLAT_TOP_DIRECTIONS: Array[Vector2i] = HexDirections.FLAT_TOP_DIRECTIONS
const DIRECTION_TO_EDGE_EVEN: Array[Vector2i] = HexDirections.DIRECTION_TO_EDGE_EVEN
const DIRECTION_TO_EDGE_ODD: Array[Vector2i] = HexDirections.DIRECTION_TO_EDGE_ODD


func build_chains(navigable_cells: Array[HexCell],
				  navigable_set: Dictionary,
				  hex_corners: PackedVector2Array) -> Array[HexEdgeChain]:
	# Step 1: Detect all boundary edges
	var edges := _detect_edges(navigable_cells, navigable_set, hex_corners)

	if edges.is_empty():
		return []

	# Step 2: Build adjacency graph
	var adjacency := _build_adjacency_graph(edges)

	# Step 3: Extract connected components (chains)
	var chains := _extract_chains(edges, adjacency)

	return chains


func _detect_edges(navigable_cells: Array[HexCell],
				   navigable_set: Dictionary,
				   hex_corners: PackedVector2Array) -> Array[HexEdgeSegment]:

	var edges: Array[HexEdgeSegment] = []

	for cell in navigable_cells:
		var cell_coords := Vector2i(cell.q, cell.r)
		var center := cell.world_position

		# Select edge mapping based on column parity (odd-q offset system)
		var edge_mapping: Array[Vector2i] = DIRECTION_TO_EDGE_EVEN if (cell.q % 2 == 0) else DIRECTION_TO_EDGE_ODD

		# Check each of the 6 directions
		for dir_index in range(6):
			var neighbor_coords := cell_coords + FLAT_TOP_DIRECTIONS[dir_index]

			# If neighbor is NOT navigable, this edge is on the boundary
			if not navigable_set.has(neighbor_coords):
				var edge_corners := edge_mapping[dir_index]
				var corner_a := center + hex_corners[edge_corners.x]
				var corner_b := center + hex_corners[edge_corners.y]

				var edge := HexEdgeSegment.new(cell, dir_index, corner_a, corner_b)
				edges.append(edge)

	return edges


func _build_adjacency_graph(edges: Array[HexEdgeSegment]) -> Dictionary:

	# Build corner-to-edges mapping
	var corner_to_edges: Dictionary = {}  # Vector2 -> Array[int] (edge indices)

	for i in range(edges.size()):
		var edge := edges[i]

		# Round corner positions to avoid floating-point precision issues
		var corner_a_key := _vector_to_key(edge.corner_a)
		var corner_b_key := _vector_to_key(edge.corner_b)

		# Add this edge to both corners' lists
		if not corner_to_edges.has(corner_a_key):
			corner_to_edges[corner_a_key] = []
		corner_to_edges[corner_a_key].append(i)

		if not corner_to_edges.has(corner_b_key):
			corner_to_edges[corner_b_key] = []
		corner_to_edges[corner_b_key].append(i)

	# Build adjacency list from corner-to-edges mapping
	var adjacency: Dictionary = {}  # int -> Array[int]

	for i in range(edges.size()):
		adjacency[i] = []

	for i in range(edges.size()):
		var edge := edges[i]
		var corner_a_key := _vector_to_key(edge.corner_a)
		var corner_b_key := _vector_to_key(edge.corner_b)

		# Get all edges sharing corners with this edge
		var adjacent_edges: Array[int] = []

		for edge_idx in corner_to_edges[corner_a_key]:
			if edge_idx != i and not adjacent_edges.has(edge_idx):
				adjacent_edges.append(edge_idx)

		for edge_idx in corner_to_edges[corner_b_key]:
			if edge_idx != i and not adjacent_edges.has(edge_idx):
				adjacent_edges.append(edge_idx)

		adjacency[i] = adjacent_edges

	return adjacency


func _extract_chains(edges: Array[HexEdgeSegment], adjacency: Dictionary) -> Array[HexEdgeChain]:

	var chains: Array[HexEdgeChain] = []
	var visited: Dictionary = {}  # int -> bool

	# Continue until all edges are visited
	while visited.size() < edges.size():
		# Find an unvisited edge to start a new boundary trace
		var start_idx := -1
		for i in range(edges.size()):
			if not visited.has(i):
				start_idx = i
				break

		if start_idx == -1:
			break

		# Trace this boundary loop
		var boundary_edges := _trace_boundary_loop(edges, adjacency, start_idx, visited)

		if not boundary_edges.is_empty():
			var chain := _create_chain_from_indices(edges, boundary_edges)
			chains.append(chain)

	return chains


func _trace_boundary_loop(edges: Array[HexEdgeSegment], adjacency: Dictionary,
						   start_idx: int, visited: Dictionary) -> Array[int]:

	var boundary: Array[int] = []
	var current_idx := start_idx
	var current_corner := edges[start_idx].corner_b  # Start at the "end" corner
	var iterations := 0
	var max_iterations := edges.size() * 2  # Safety limit

	# Trace until we return to start or hit iteration limit
	while iterations < max_iterations:
		# Mark current edge as visited
		visited[current_idx] = true
		boundary.append(current_idx)

		# Find next edge that starts from current_corner
		var next_idx := _find_next_edge_from_corner(edges, adjacency, current_idx, current_corner, boundary)

		# If we've returned to start, close the loop
		if next_idx == start_idx and boundary.size() > 2:
			break

		# If no next edge found, we've hit a dead end
		if next_idx == -1:
			break

		# Update current corner to the far end of the next edge
		var next_edge := edges[next_idx]
		if _corners_match(next_edge.corner_a, current_corner):
			current_corner = next_edge.corner_b
		else:
			current_corner = next_edge.corner_a

		# Move to next edge
		current_idx = next_idx
		iterations += 1

	return boundary


func _find_next_edge_from_corner(edges: Array[HexEdgeSegment], adjacency: Dictionary,
								  current_idx: int, from_corner: Vector2, boundary: Array[int]) -> int:
	var adjacent_indices: Array = adjacency.get(current_idx, [])

	if adjacent_indices.is_empty():
		return -1

	# Find edges that have from_corner as one of their corners
	var candidates: Array[int] = []
	for adj_idx in adjacent_indices:
		# Allow returning to first edge to close the loop
		if adj_idx == boundary[0] and boundary.size() > 2:
			var first_edge := edges[boundary[0]]
			if _corners_match(first_edge.corner_a, from_corner) or _corners_match(first_edge.corner_b, from_corner):
				return adj_idx

		# Skip if already in boundary
		if boundary.has(adj_idx):
			continue

		var adj_edge := edges[adj_idx]
		# Check if this edge has from_corner
		if _corners_match(adj_edge.corner_a, from_corner) or _corners_match(adj_edge.corner_b, from_corner):
			candidates.append(adj_idx)

	if candidates.is_empty():
		return -1

	# If multiple candidates, choose the first one
	# TODO: Could improve by choosing based on angle to maintain consistent direction
	return candidates[0]


func _create_chain_from_indices(all_edges: Array[HexEdgeSegment], edge_indices: Array[int]) -> HexEdgeChain:
	if edge_indices.is_empty():
		return HexEdgeChain.new(false)

	# Gather edge segments
	var edges: Array[HexEdgeSegment] = []
	for idx in edge_indices:
		edges.append(all_edges[idx])

	# Determine if this is a closed loop
	# A chain is closed if every edge has exactly 2 adjacent edges in the chain
	var is_closed := _is_chain_closed(edges)

	# Create chain
	var chain := HexEdgeChain.new(is_closed)

	# Order edges to form continuous path
	var ordered_edges := _order_edges(edges)

	for edge in ordered_edges:
		chain.add_edge(edge)

	# Build the polyline from ordered edges
	chain.build_polyline()

	return chain


func _is_chain_closed(edges: Array[HexEdgeSegment]) -> bool:
	# A chain is closed if all corners appear exactly twice (each corner shared by 2 edges)
	var corner_count: Dictionary = {}  # String -> int

	for edge in edges:
		var corner_a_key := _vector_to_key(edge.corner_a)
		var corner_b_key := _vector_to_key(edge.corner_b)

		corner_count[corner_a_key] = corner_count.get(corner_a_key, 0) + 1
		corner_count[corner_b_key] = corner_count.get(corner_b_key, 0) + 1

	# In a closed loop, every corner should appear exactly twice
	for count in corner_count.values():
		if count != 2:
			return false

	return true


func _order_edges(edges: Array[HexEdgeSegment]) -> Array[HexEdgeSegment]:
	# Edges are already ordered by the boundary tracing algorithm
	# Just return them as-is
	return edges


func _edges_share_corner(edge1: HexEdgeSegment, edge2: HexEdgeSegment) -> bool:
	# Check if two edges share at least one corner
	return (_corners_match(edge1.corner_a, edge2.corner_a) or
			_corners_match(edge1.corner_a, edge2.corner_b) or
			_corners_match(edge1.corner_b, edge2.corner_a) or
			_corners_match(edge1.corner_b, edge2.corner_b))


func _corners_match(corner_a: Vector2, corner_b: Vector2) -> bool:
	# Checks if two corners are at the same position (within floating-point tolerance)
	return corner_a.is_equal_approx(corner_b)


func _vector_to_key(vec: Vector2) -> String:
	# Converts a Vector2 to a string key for dictionary lookups (rounds to avoid FP issues)
	return "%d,%d" % [round(vec.x * 100), round(vec.y * 100)]
