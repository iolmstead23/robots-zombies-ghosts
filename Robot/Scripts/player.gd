extends CharacterBody2D

# Movement constants
const SPEED = 275.0
const RUN_SPEED_MULTIPLIER = 1.75
const AIM_SPEED_MULTIPLIER = 0.8  # 20% speed reduction while aiming
const ANIM_SPEED = 4.5
const MOVEMENT_THRESHOLD = 1.0

# Jump constants
const GRAVITY = 980.0
const JUMP_STRENGTH = 175.0
const MAX_FALL_SPEED = 600.0

# Weapon stats
var weapon_stats := {
	"aimed_fire_rate": 0.05,      # 20 fps (1/20 = 0.05s per frame)
	"hip_fire_rate": 0.0667,      # 15 fps (1/15 = 0.0667s per frame)
	"aimed_anim_speed": 20.0,
	"hip_anim_speed": 15.0
}

@onready var animated_sprite = $AnimatedSprite2D

# Position tracking
var previous_position: Vector2 = Vector2.ZERO

# Jump physics
var y_offset: float = 0.0
var vertical_velocity: float = 0.0
var jump_momentum: Vector2 = Vector2.ZERO
var base_y_position: float = 0.0
var was_running_when_jumped: bool = false
var jump_key_released: bool = true

# Shooting mechanics
var is_aiming: bool = false
var is_shooting: bool = false
var can_fire: bool = true
var fire_cooldown_timer: float = 0.0
var current_fire_rate: float = 0.0
var shoot_animation_playing: bool = false

# Current state
var state := {
	"facing_direction": "down",
	"is_moving": false,
	"has_input": false,
	"is_running": false,
	"is_jumping": false,
	"is_aiming": false,
	"is_shooting": false,
	"animation_type": "idle"
}

var prev_state := {}

# Animation mappings
var animations := {
	"idle": {
		"up": "Idle_Up", "up_left": "Idle_UpLeft", "left": "Idle_Left",
		"down_left": "Idle_DownLeft", "down": "Idle_Down", "down_right": "Idle_DownRight",
		"right": "Idle_Right", "up_right": "Idle_UpRight"
	},
	"walk": {
		"up": "Walk_Up", "up_left": "Walk_UpLeft", "left": "Walk_Left",
		"down_left": "Walk_DownLeft", "down": "Walk_Down", "down_right": "Walk_DownRight",
		"right": "Walk_Right", "up_right": "Walk_UpRight"
	},
	"run": {
		"up": "Run_Up", "up_left": "Run_UpLeft", "left": "Run_Left",
		"down_left": "Run_DownLeft", "down": "Run_Down", "down_right": "Run_DownRight",
		"right": "Run_Right", "up_right": "Run_UpRight"
	},
	"jump": {
		"up": "Jump_Up", "up_left": "Jump_UpLeft", "left": "Jump_Left",
		"down_left": "Jump_DownLeft", "down": "Jump_Down", "down_right": "Jump_DownRight",
		"right": "Jump_Right", "up_right": "Jump_UpRight"
	},
	"run_jump": {
		"up": "RunJump_Up", "up_left": "RunJump_UpLeft", "left": "RunJump_Left",
		"down_left": "RunJump_DownLeft", "down": "RunJump_Down", "down_right": "RunJump_DownRight",
		"right": "RunJump_Right", "up_right": "RunJump_UpRight"
	},
	"idle_aim": {
		"up": "IdleAim_Up", "up_left": "IdleAim_UpLeft", "left": "IdleAim_Left",
		"down_left": "IdleAim_DownLeft", "down": "IdleAim_Down", "down_right": "IdleAim_DownRight",
		"right": "IdleAim_Right", "up_right": "IdleAim_UpRight"
	},
	"standing_shoot": {
		"up": "StandingShoot_Up", "up_left": "StandingShoot_UpLeft", "left": "StandingShoot_Left",
		"down_left": "StandingShoot_DownLeft", "down": "StandingShoot_Down", "down_right": "StandingShoot_DownRight",
		"right": "StandingShoot_Right", "up_right": "StandingShoot_UpRight"
	},
	"walk_shoot": {
		"up": "WalkShoot_Up", "up_left": "WalkShoot_UpLeft", "left": "WalkShoot_Left",
		"down_left": "WalkShoot_DownLeft", "down": "WalkShoot_Down", "down_right": "WalkShoot_DownRight",
		"right": "WalkShoot_Right", "up_right": "WalkShoot_UpRight"
	}
}

func _ready() -> void:
	animated_sprite.stop()
	animated_sprite.frame = 0
	previous_position = global_position
	base_y_position = global_position.y
	y_sort_enabled = true
	animated_sprite.animation_finished.connect(_on_animation_finished)
	prev_state = state.duplicate()

func _physics_process(delta: float) -> void:
	prev_state = state.duplicate()
	var start_position = global_position
	
	# Update fire cooldown
	if fire_cooldown_timer > 0:
		fire_cooldown_timer -= delta
		if fire_cooldown_timer <= 0:
			can_fire = true
			shoot_animation_playing = false
	
	# Handle aiming input (right mouse button or custom action)
	is_aiming = Input.is_action_pressed("ui_aim")  # Map this to right-click in Input Map
	
	# Handle shooting input (left mouse button or custom action)
	var fire_pressed = Input.is_action_pressed("ui_fire")  # Map this to left-click
	
	# Shooting logic
	if fire_pressed and can_fire and not state.is_jumping:
		_fire_weapon()
	
	# Handle jump input (disabled while aiming or shooting)
	if not Input.is_action_pressed("ui_accept"):
		jump_key_released = true
	
	if Input.is_action_pressed("ui_accept") and not state.is_jumping and jump_key_released and not is_aiming and not is_shooting:
		_start_jump()
		jump_key_released = false
	
	# Update jump physics
	if state.is_jumping:
		_process_jump_physics(delta)
	
	# Process horizontal movement (always allowed)
	_process_movement(delta)
	
	# Determine if player actually moved
	var distance_moved = global_position.distance_to(start_position)
	state.is_moving = distance_moved >= MOVEMENT_THRESHOLD
	
	# Update sprite vertical offset for jump
	animated_sprite.position.y = -y_offset
	
	# Update state and animation
	_update_state()
	_update_animation()

func _process_movement(delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_shift_pressed = Input.is_action_pressed("ui_run")
	
	state.has_input = input_dir.length() > 0.1
	
	# Update direction whenever there's input (even while aiming/shooting)
	if state.has_input:
		var new_direction = _get_direction_name(input_dir.normalized())
		if new_direction != "":
			state.facing_direction = new_direction
	
	if state.is_jumping:
		velocity = jump_momentum
	else:
		# Calculate speed based on state
		var speed = SPEED
		
		# If aiming or shooting, always use reduced walk speed regardless of shift
		if is_aiming or is_shooting:
			speed = SPEED * AIM_SPEED_MULTIPLIER
		# If not aiming/shooting and shift is pressed, use run speed
		elif is_shift_pressed:
			speed = SPEED * RUN_SPEED_MULTIPLIER
		# Otherwise normal walk speed
		
		velocity = input_dir.normalized() * speed if state.has_input else Vector2.ZERO
	
	move_and_collide(velocity * delta)

func _process_jump_physics(delta: float) -> void:
	vertical_velocity -= GRAVITY * delta
	vertical_velocity = max(vertical_velocity, -MAX_FALL_SPEED)
	y_offset += vertical_velocity * delta
	
	if y_offset <= 0.0:
		_land_from_jump()

func _start_jump() -> void:
	was_running_when_jumped = state.is_running
	jump_momentum = velocity
	vertical_velocity = JUMP_STRENGTH
	state.is_jumping = true

func _land_from_jump() -> void:
	y_offset = 0.0
	vertical_velocity = 0.0
	state.is_jumping = false
	jump_momentum = Vector2.ZERO
	was_running_when_jumped = false

func _fire_weapon() -> void:
	can_fire = false
	is_shooting = true
	shoot_animation_playing = true
	
	# Set fire rate based on whether we're aiming
	if is_aiming:
		current_fire_rate = weapon_stats.aimed_fire_rate
		fire_cooldown_timer = current_fire_rate
	else:
		current_fire_rate = weapon_stats.hip_fire_rate
		fire_cooldown_timer = current_fire_rate
	
	# Here you would spawn projectiles, apply damage, etc.
	_spawn_projectile()

func _spawn_projectile() -> void:
	# Placeholder for your projectile spawning logic
	print("Firing projectile in direction: ", state.facing_direction)
	# Example: var projectile = projectile_scene.instantiate()
	# projectile.global_position = global_position
	# projectile.direction = _get_direction_vector(state.facing_direction)
	# get_parent().add_child(projectile)

func _update_state() -> void:
	state.is_aiming = is_aiming
	state.is_shooting = shoot_animation_playing
	
	# Priority: Shooting > Jumping > Aiming/Walking > Movement > Idle
	if state.is_shooting:
		# Use WalkShoot if moving, StandingShoot if stationary
		if state.is_moving:
			state.animation_type = "walk_shoot"
		else:
			state.animation_type = "standing_shoot"
		state.is_running = false
	elif state.is_jumping:
		state.animation_type = "run_jump" if was_running_when_jumped else "jump"
		state.is_running = false
	elif state.is_aiming:
		# While aiming, use WalkShoot if moving, IdleAim if stationary
		if state.is_moving:
			state.animation_type = "walk_shoot"
		else:
			state.animation_type = "idle_aim"
		state.is_running = false
	elif state.is_moving:
		# Normal movement (not aiming/shooting)
		if state.has_input and Input.is_action_pressed("ui_run") and not is_aiming and not is_shooting:
			state.animation_type = "run"
			state.is_running = true
		elif state.has_input:
			state.animation_type = "walk"
			state.is_running = false
		else:
			state.animation_type = "idle"
			state.is_running = false
	else:
		state.animation_type = "idle"
		state.is_running = false

func _update_animation() -> void:
	if not _state_changed():
		return
	
	var anim_type = state.animation_type
	var direction = state.facing_direction
	
	if anim_type in animations and direction in animations[anim_type]:
		var anim_name = animations[anim_type][direction]
		
		# Determine animation speed based on type
		var anim_speed = ANIM_SPEED
		
		# Shooting animations use weapon fire rate speeds
		if anim_type == "standing_shoot":
			anim_speed = weapon_stats.aimed_anim_speed if is_aiming else weapon_stats.hip_anim_speed
		elif anim_type == "walk_shoot":
			# WalkShoot uses same fire rate speeds, but also slowed by movement
			var base_shoot_speed = weapon_stats.aimed_anim_speed if is_aiming else weapon_stats.hip_anim_speed
			# Apply the same speed reduction as movement (80% speed = 0.8x animation speed)
			anim_speed = base_shoot_speed * (AIM_SPEED_MULTIPLIER - .2)
		elif anim_type == "walk" and (is_aiming or is_shooting):
			# Regular walk animation slowed down while aiming/shooting
			anim_speed = ANIM_SPEED * (AIM_SPEED_MULTIPLIER - .2)
		
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name, anim_speed)
			animated_sprite.frame = 0
		elif not animated_sprite.is_playing():
			if not state.is_jumping and not state.is_shooting:
				animated_sprite.play(anim_name, anim_speed)

func _get_direction_name(direction: Vector2) -> String:
	if direction.length() < 0.1:
		return ""
	
	var angle = direction.angle()
	var degrees = rad_to_deg(angle)
	
	if degrees < 0:
		degrees += 360
	
	if degrees >= 337.5 or degrees < 22.5:
		return "right"
	elif degrees >= 22.5 and degrees < 67.5:
		return "down_right"
	elif degrees >= 67.5 and degrees < 112.5:
		return "down"
	elif degrees >= 112.5 and degrees < 157.5:
		return "down_left"
	elif degrees >= 157.5 and degrees < 202.5:
		return "left"
	elif degrees >= 202.5 and degrees < 247.5:
		return "up_left"
	elif degrees >= 247.5 and degrees < 292.5:
		return "up"
	else:
		return "up_right"

func _get_direction_vector(direction_name: String) -> Vector2:
	# Convert direction name back to Vector2 for projectile direction
	match direction_name:
		"right": return Vector2.RIGHT
		"down_right": return Vector2(1, 1).normalized()
		"down": return Vector2.DOWN
		"down_left": return Vector2(-1, 1).normalized()
		"left": return Vector2.LEFT
		"up_left": return Vector2(-1, -1).normalized()
		"up": return Vector2.UP
		"up_right": return Vector2(1, -1).normalized()
		_: return Vector2.DOWN

func _state_changed() -> bool:
	for key in state:
		if state[key] != prev_state.get(key):
			return true
	return false

func _on_animation_finished() -> void:
	# When shoot animation finishes, return to appropriate state
	if state.is_shooting:
		is_shooting = false
		shoot_animation_playing = false

func print_state() -> void:
	print("=== Player State ===")
	print("Position: ", global_position)
	print("Is Moving: ", state.is_moving)
	print("Has Input: ", state.has_input)
	print("Is Running: ", state.is_running)
	print("Is Jumping: ", state.is_jumping)
	print("Is Aiming: ", state.is_aiming)
	print("Is Shooting: ", state.is_shooting)
	print("Can Fire: ", can_fire)
	print("Direction: ", state.facing_direction)
	print("Animation: ", state.animation_type)
	print("Current Anim: ", animated_sprite.animation)
	print("Fire Rate: ", current_fire_rate)
	print("==================")
