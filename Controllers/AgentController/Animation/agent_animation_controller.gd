extends Node
class_name AgentAnimationController

## Maps the resolved agent state to a directional sprite clip and drives playback.
## Consults "state.animation" (owned by AgentStateManager) for WHAT to play;
## it never decides animation priority itself. All other inputs (facing, jump
## height, fall phase, shoot speed) are read from the registry.
## No direct node references to Motion, Action, or State packages.

const ANIM_SPEED := 4.5
const AIM_SPEED_REDUCTION := 0.6

enum JumpPhase { NONE, ASCENT, AIRBORNE }

var animated_sprite: AnimatedSprite2D
var registry: AgentRegistry

var current_animation := ""
var current_animation_speed := ANIM_SPEED
var _jump_phase := JumpPhase.NONE

# Peak frame for each jump animation where the sprite freezes during fall.
var _jump_peak_frame := 0

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

signal animation_changed(old_animation: String, new_animation: String)
signal animation_speed_changed(speed: float)

func initialize(sprite_ref: AnimatedSprite2D, registry_ref: AgentRegistry) -> void:
	animated_sprite = sprite_ref
	registry = registry_ref
	registry.subscribe("motion.is_jumping", _on_is_jumping_changed)

func update_animation() -> void:
	var anim_type: String = str(registry.query("state.animation"))
	var direction: String = str(registry.query("motion.facing_direction"))
	var anim_name := _get_animation_name(anim_type, direction)

	if anim_name == "":
		return

	_apply_jump_height_to_sprite()

	if anim_type in ["jump", "run_jump"]:
		_update_jump_animation_phase(anim_name)
		return

	# Resuming from a jump: if same animation as before jump, resume playing instead of restarting.
	if _jump_phase == JumpPhase.NONE and animated_sprite.animation == anim_name and not animated_sprite.is_playing():
		var anim_speed := _calculate_animation_speed(anim_type)
		animated_sprite.play(anim_name, anim_speed)
		if OS.is_debug_build():
			print_debug("ANIM: resumed %s @ %.1fx (after jump)" % [anim_name, anim_speed])
		return

	# Always interrupt and play when state changes; don't let old loops finish.
	if animated_sprite.animation != anim_name:
		var anim_speed := _calculate_animation_speed(anim_type)
		_play_animation(anim_name, anim_speed)
	elif not animated_sprite.is_playing() and not _is_one_shot_animation(anim_type):
		var anim_speed := _calculate_animation_speed(anim_type)
		_play_animation(anim_name, anim_speed)

func _get_animation_name(anim_type: String, direction: String) -> String:
	if anim_type in animations and direction in animations[anim_type]:
		return animations[anim_type][direction]
	return ""

func _calculate_animation_speed(anim_type: String) -> float:
	var speed := ANIM_SPEED
	var is_aiming: bool = bool(registry.query("action.is_aiming"))

	if anim_type == "standing_shoot" or anim_type == "walk_shoot":
		# Base shoot speed (aimed vs hip) is owned and published by AgentActionPackage.
		speed = float(registry.query("action.shoot_anim_speed"))
		if anim_type == "walk_shoot":
			speed *= AIM_SPEED_REDUCTION
	elif (anim_type == "walk" or anim_type == "idle_aim") and is_aiming:
		speed = ANIM_SPEED * AIM_SPEED_REDUCTION

	return speed

func _apply_jump_height_to_sprite() -> void:
	var jump_height: float = registry.query("motion.jump_height")
	animated_sprite.position.y = -jump_height

func _play_animation(anim_name: String, speed: float) -> void:
	if OS.is_debug_build() and current_animation != anim_name:
		print_debug("ANIM: %s → %s @ %.1fx" % [current_animation, anim_name, speed])

	# Always stop current animation before playing new one to ensure immediate interruption.
	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play(anim_name, speed)

	if current_animation != anim_name:
		var old_animation = current_animation
		current_animation = anim_name
		animation_changed.emit(old_animation, anim_name)

	if current_animation_speed != speed:
		current_animation_speed = speed
		animation_speed_changed.emit(speed)

func _is_one_shot_animation(anim_type: String) -> bool:
	return anim_type in ["jump", "run_jump", "standing_shoot"]

func _update_jump_animation_phase(anim_name: String) -> void:
	var is_falling: bool = bool(registry.query("motion.is_falling"))

	if _jump_phase == JumpPhase.NONE:
		_jump_phase = JumpPhase.ASCENT
		_play_animation(anim_name, ANIM_SPEED)
		if OS.is_debug_build():
			var frame_count := animated_sprite.sprite_frames.get_frame_count(anim_name)
			print_debug("JUMP_PHASE: NONE → ASCENT | anim=%s | total_frames=%d" % [anim_name, frame_count])
		return

	if animated_sprite.animation != anim_name:
		# When switching jump animations (e.g., WalkShoot→Jump during combat+jump),
		# start from frame 0 instead of preserving the old animation's frame,
		# since peak frames differ (Jump=3, RunJump=4, etc).
		animated_sprite.play(anim_name, ANIM_SPEED)
		if OS.is_debug_build():
			print_debug("JUMP_ANIM: switched to %s (frame reset to 0)" % anim_name)

	match _jump_phase:
		JumpPhase.ASCENT:
			if not animated_sprite.is_playing() or is_falling:
				_jump_phase = JumpPhase.AIRBORNE
				# Capture the peak frame for this jump animation.
				_jump_peak_frame = 3 if anim_name.begins_with("Jump_") else 4
				if animated_sprite.is_playing():
					animated_sprite.pause()
				animated_sprite.frame = _jump_peak_frame
				if OS.is_debug_build():
					var frame_count := animated_sprite.sprite_frames.get_frame_count(anim_name)
					print_debug("JUMP_PHASE: ASCENT → AIRBORNE | anim=%s | peak_frame=%d | total_frames=%d | falling=%s" % [anim_name, _jump_peak_frame, frame_count, is_falling])
		JumpPhase.AIRBORNE:
			pass

func _on_is_jumping_changed(is_jumping: bool) -> void:
	if not is_jumping:
		_jump_phase = JumpPhase.NONE
		if OS.is_debug_build():
			var current_anim := current_animation
			var next_state := str(registry.query("state.animation"))
			print_debug("JUMP_PHASE: LANDED → NONE | will resume state='%s' anim='%s'" % [next_state, current_anim])

func get_current_animation() -> String:
	return current_animation

func get_current_animation_speed() -> float:
	return current_animation_speed

func is_animation_playing() -> bool:
	return animated_sprite.is_playing()

func print_animation_state() -> void:
	if OS.is_debug_build():
		print("AgentAnimationController: %s @ %.1fx (playing: %s)" % [current_animation, current_animation_speed, is_animation_playing()])
