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

func set_navigation_agent(a: NavigationAgent2D) -> void:
	agent = a

func set_destination(point: Vector2) -> void:
	destination = point
	if agent:
		agent.set_target_position(destination)

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

## --- API: match InputHandler for walking movement only ---

func get_movement_vector() -> Vector2:
	return movement_vector

func is_run_pressed() -> bool:
	return false

## Placeholder for interface match (not supported)
func update_input() -> void:
	pass
