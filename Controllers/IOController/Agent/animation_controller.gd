extends Node
class_name AnimationController

## Manages all animation logic, transitions, and playback speeds

# Animation constants
const ANIM_SPEED := 4.5
const AIM_SPEED_REDUCTION := 0.6

# Component references
var animated_sprite: AnimatedSprite2D
var state_manager: StateManager
var combat_component: CombatComponent
var jump_component: JumpComponent

# Animation state
var current_animation := ""
var current_animation_speed := ANIM_SPEED

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

signal animation_changed(animation_name: String)
signal animation_speed_changed(speed: float)

func initialize(sprite_ref: AnimatedSprite2D, state_ref: StateManager, combat_ref: CombatComponent) -> void:
	animated_sprite = sprite_ref
	state_manager = state_ref
	combat_component = combat_ref

func set_jump_component(jump_ref: JumpComponent) -> void:
	jump_component = jump_ref

func update_animation() -> void:
	state_manager.update_animation_type()

	if not state_manager.has_state_changed():
		return

	var anim_type := _get_animation_type()
	var direction: String = state_manager.get_state_value("facing_direction")
	var anim_name := _get_animation_name(anim_type, direction)

	if anim_name == "":
		return

	var anim_speed := _calculate_animation_speed(anim_type)

	if animated_sprite.animation != anim_name:
		_play_animation(anim_name, anim_speed)
	elif not animated_sprite.is_playing() and not _is_one_shot_animation(anim_type):
		_play_animation(anim_name, anim_speed)

	# Update previous state so next call can detect changes
	state_manager.save_state()

func _get_animation_type() -> String:
	var state := state_manager.get_state()

	if state.is_jumping and jump_component != null:
		return "run_jump" if jump_component.was_running_on_jump_start() else "jump"

	return state.animation_type

func _get_animation_name(anim_type: String, direction: String) -> String:
	if anim_type in animations and direction in animations[anim_type]:
		return animations[anim_type][direction]
	return ""

func _calculate_animation_speed(anim_type: String) -> float:
	var speed := ANIM_SPEED
	var is_aiming: bool = state_manager.get_state_value("is_aiming")
	var is_shooting: bool = state_manager.get_state_value("is_shooting")

	# Shooting animations use weapon fire rate
	if anim_type == "standing_shoot" or anim_type == "walk_shoot":
		speed = combat_component.get_shoot_animation_speed()
		if anim_type == "walk_shoot":
			speed *= AIM_SPEED_REDUCTION
	elif (anim_type == "walk" or anim_type == "idle_aim") and (is_aiming or is_shooting):
		speed = ANIM_SPEED * AIM_SPEED_REDUCTION

	return speed

func _play_animation(anim_name: String, speed: float) -> void:
	animated_sprite.play(anim_name, speed)
	animated_sprite.frame = 0

	if current_animation != anim_name:
		current_animation = anim_name
		animation_changed.emit(anim_name)

	if current_animation_speed != speed:
		current_animation_speed = speed
		animation_speed_changed.emit(speed)

func _is_one_shot_animation(anim_type: String) -> bool:
	return anim_type in ["jump", "run_jump", "standing_shoot"]

func _on_animation_finished() -> void:
	var is_shooting: bool = state_manager.get_state_value("is_shooting")

	if is_shooting:
		combat_component.on_shoot_animation_finished()
		state_manager.set_state_value("is_shooting", false)

func stop_animation() -> void:
	animated_sprite.stop()

func pause_animation() -> void:
	animated_sprite.pause()

func resume_animation() -> void:
	if animated_sprite.animation != "":
		animated_sprite.play()

func get_current_animation() -> String:
	return current_animation

func get_current_animation_speed() -> float:
	return current_animation_speed

func is_animation_playing() -> bool:
	return animated_sprite.is_playing()

func set_animation_mapping(type: String, direction: String, animation_name: String) -> void:
	if type not in animations:
		animations[type] = {}
	animations[type][direction] = animation_name

func load_animation_mappings(mappings: Dictionary) -> void:
	animations = mappings

# Debug
func print_animation_state() -> void:
	if OS.is_debug_build():
		print("AnimationController: %s @ %.1fx (playing: %s)" % [current_animation, current_animation_speed, is_animation_playing()])
