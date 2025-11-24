extends Node
class_name NavAgent2DFollower

## Makes CharacterBody2D follow NavigationAgent2D target

@export var movement_speed: float = 200.0
@export var rotation_speed: float = 10.0
@export var arrival_distance: float = 5.0

var character_body: CharacterBody2D
var nav_agent: NavigationAgent2D
var is_active: bool = false

func _ready() -> void:
	if not get_parent() is CharacterBody2D:
		push_error("NavAgent2DFollower: Must be child of CharacterBody2D")
		return

	character_body = get_parent()
	nav_agent = character_body.get_node_or_null("NavigationAgent2D")

	if not nav_agent:
		push_error("NavAgent2DFollower: No NavigationAgent2D found")
		return

	_configure_nav_agent()

	if OS.is_debug_build():
		print("NavAgent2DFollower: Initialized on %s" % character_body.name)

func _configure_nav_agent() -> void:
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = arrival_distance

func activate() -> void:
	is_active = true
	set_physics_process(true)

	if OS.is_debug_build():
		print("NavAgent2DFollower: Activated")

func deactivate() -> void:
	is_active = false
	set_physics_process(false)

	if character_body:
		character_body.velocity = Vector2.ZERO

	if OS.is_debug_build():
		print("NavAgent2DFollower: Deactivated")

func _physics_process(_delta: float) -> void:
	if not is_active or not character_body or not nav_agent:
		return

	if nav_agent.is_navigation_finished():
		character_body.velocity = Vector2.ZERO
		return

	var next_pos := nav_agent.get_next_path_position()
	var current_pos := character_body.global_position
	var direction := (next_pos - current_pos).normalized()

	character_body.velocity = direction * movement_speed
	character_body.move_and_slide()

	_debug_print_status(current_pos)

func _debug_print_status(current_pos: Vector2) -> void:
	if not OS.is_debug_build() or Engine.get_physics_frames() % 60 != 0:
		return

	var distance := current_pos.distance_to(nav_agent.target_position)
	print("NavAgent2DFollower: Distance %.1fpx | Velocity %s" % [distance, character_body.velocity])

func set_target(target_position: Vector2) -> void:
	if nav_agent:
		nav_agent.target_position = target_position

		if OS.is_debug_build():
			print("NavAgent2DFollower: Target set to %s" % target_position)

func is_at_target() -> bool:
	return nav_agent.is_navigation_finished() if nav_agent else true

func get_distance_to_target() -> float:
	if not nav_agent or not character_body:
		return 0.0
	return character_body.global_position.distance_to(nav_agent.target_position)