extends BaseInputHandler
class_name PathfindingInputHandler

## Handles click-to-move pathfinding, producing movement vectors from NavigationAgent2D
## Only supports walking (no running/jumping/combat)

var agent: NavigationAgent2D = null      # Reference to NavigationAgent2D
var movement_vector := Vector2.ZERO      # Output movement vector (similar to InputHandler)
var destination: Vector2 = Vector2.ZERO                 # Target point, or null if none set

func _ready() -> void:
	# Find NavigationAgent2D if not assigned
	if agent == null:
		agent = get_parent().get_node_or_null("NavigationAgent2D")
	set_process(true)

	# Connect arrival signal if agent present
	if agent and agent.has_signal("navigation_finished"):
		agent.connect("navigation_finished", Callable(self, "_on_navigation_finished"))

func set_navigation_agent(a: NavigationAgent2D) -> void:
	agent = a

func set_destination(point: Vector2) -> void:
	var was_active = agent and not agent.is_navigation_finished()
	destination = point
	print("PathfindingInputHandler: Player set new target to (%.2f, %.2f)" % [point.x, point.y])
	if agent:
		agent.set_target_position(destination)
		print("PathfindingInputHandler: NavigationAgent2D target set to (%.2f, %.2f)" % [destination.x, destination.y])
		if was_active:
			print("PathfindingInputHandler: Path recalculated to (%.2f, %.2f)" % [destination.x, destination.y])

func _process(_delta: float) -> void:
	if agent and agent.is_navigation_finished() == false:
		var next_pos = agent.get_next_path_position()
		var curr_pos = agent.global_position
		var dir = next_pos - curr_pos
		if dir.length() > 0.1:
			movement_vector = dir.normalized()
		else:
			movement_vector = Vector2.ZERO
	else:
		movement_vector = Vector2.ZERO

## Called when NavigationAgent2D arrives at its target
func _on_navigation_finished() -> void:
	print("PathfindingInputHandler: Arrived at target (%.2f, %.2f)" % [destination.x, destination.y])

## Cancel pathfinding (if called from game logic)
func cancel_pathfinding() -> void:
	if agent:
		agent.set_target_position(agent.global_position)
		print("PathfindingInputHandler: Pathfinding cancelled by player")
	destination = agent.global_position if agent else Vector2.ZERO

## --- API: match InputHandler for walking movement only ---

func get_movement_vector() -> Vector2:
	return movement_vector

func is_run_pressed() -> bool:
	return false

## Placeholder for interface match (not supported)
func update_input() -> void:
	pass
