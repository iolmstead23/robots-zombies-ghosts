extends Node
class_name Heuristics

"""
Heuristic functions for pathfinding algorithms.

Design notes:
- Pure static utility functions
- No state, no dependencies
- Various heuristic strategies for different use cases
"""

# ----------------------
# Hex Grid Heuristics
# ----------------------

## Standard hex distance heuristic (Manhattan-like for hex grids)
static func hex_distance(from: HexCell, to: HexCell) -> float:
	return float(from.distance_to(to))

## Euclidean distance heuristic for hex grids
static func hex_euclidean(from: HexCell, to: HexCell) -> float:
	var from_world := from.world_position
	var to_world := to.world_position
	return from_world.distance_to(to_world)

## Axial hex distance heuristic with weighted costs
static func diagonal_distance(from: HexCell, to: HexCell, straight_cost: float = 1.0) -> float:
	var dq: int = abs(from.q - to.q)
	var dr: int = abs(from.r - to.r)
	var hex_steps: int = (dq + dr + abs(dq + dr)) / 2
	return float(hex_steps) * straight_cost

# ----------------------
# Vector2 Heuristics
# ----------------------

## Manhattan distance (grid-based movement)
static func manhattan_distance(from: Vector2, to: Vector2) -> float:
	return abs(from.x - to.x) + abs(from.y - to.y)

## Euclidean distance (straight-line distance)
static func euclidean_distance(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to)

## Chebyshev distance (8-directional movement)
static func chebyshev_distance(from: Vector2, to: Vector2) -> float:
	return max(abs(from.x - to.x), abs(from.y - to.y))

# ----------------------
# Weighted Heuristics
# ----------------------

## Apply weight to heuristic (for weighted A*)
static func weighted_heuristic(heuristic_value: float, weight: float = 1.0) -> float:
	return heuristic_value * weight

## Admissible heuristic (never overestimates)
static func admissible_heuristic(from: HexCell, to: HexCell) -> float:
	# Uses standard hex distance which is admissible
	return hex_distance(from, to)

## Consistent heuristic (monotonic)
static func consistent_heuristic(from: HexCell, to: HexCell) -> float:
	# Uses standard hex distance which is consistent
	return hex_distance(from, to)

# ----------------------
# Special Heuristics
# ----------------------

## Zero heuristic (turns A* into Dijkstra's algorithm)
static func zero_heuristic(_from: HexCell, _to: HexCell) -> float:
	return 0.0

## Tie-breaking heuristic (prefers paths in specific direction)
static func tie_breaking_heuristic(from: HexCell, to: HexCell, tie_break_factor: float = 0.001) -> float:
	var h := hex_distance(from, to)
	# Add small penalty based on cross product to prefer straighter paths
	var dx1 := from.q - to.q
	var dy1 := from.r - to.r
	var cross: int = abs(dx1 + dy1)
	return h * (1.0 + tie_break_factor * cross)
