extends Node
class_name CombatComponent

## Manages all combat-related functionality including shooting and aiming

# Weapon stats - can be easily modified or loaded from resources
var weapon_stats := {
	"aimed_fire_rate": 0.05,      # 20 fps (1/20 = 0.05s per frame)
	"hip_fire_rate": 0.0667,      # 15 fps (1/15 = 0.0667s per frame)
	"aimed_anim_speed": 20.0,
	"hip_anim_speed": 15.0
}

# Component references
var player: CharacterBody2D
var state_manager: StateManager
var input_handler: InputHandler

# Combat state
var is_aiming := false
var is_shooting := false
var can_fire := true
var fire_cooldown_timer := 0.0
var current_fire_rate := 0.0
var shoot_animation_playing := false

# Signals
signal weapon_fired(direction: String)
signal aim_started()
signal aim_ended()
signal reload_started()
signal reload_finished()

func initialize(player_ref: CharacterBody2D, state_ref: StateManager, input_ref: InputHandler) -> void:
	player = player_ref
	state_manager = state_ref
	input_handler = input_ref

func update(delta: float) -> void:
	_update_fire_cooldown(delta)
	_handle_aiming()
	_handle_shooting()
	_update_combat_state()

func _update_fire_cooldown(delta: float) -> void:
	if fire_cooldown_timer > 0:
		fire_cooldown_timer -= delta
		if fire_cooldown_timer <= 0:
			can_fire = true
			shoot_animation_playing = false

func _handle_aiming() -> void:
	var was_aiming := is_aiming
	is_aiming = input_handler.is_aim_pressed()
	
	# Emit signals for aim state changes
	if is_aiming and not was_aiming:
		aim_started.emit()
	elif not is_aiming and was_aiming:
		aim_ended.emit()

func _handle_shooting() -> void:
	var fire_pressed := input_handler.is_fire_pressed()
	var is_jumping: bool = state_manager.get_state_value("is_jumping")
	
	# Check if we can and should fire
	if fire_pressed and can_fire and not is_jumping:
		_fire_weapon()

func _fire_weapon() -> void:
	can_fire = false
	is_shooting = true
	shoot_animation_playing = true
	
	# Set fire rate based on aiming state
	if is_aiming:
		current_fire_rate = weapon_stats.aimed_fire_rate
		fire_cooldown_timer = current_fire_rate
	else:
		current_fire_rate = weapon_stats.hip_fire_rate
		fire_cooldown_timer = current_fire_rate
	
	# Get current facing direction for projectile
	var direction: String = state_manager.get_state_value("facing_direction")
	
	# Spawn projectile
	_spawn_projectile(direction)
	
	# Emit signal for other systems
	weapon_fired.emit(direction)

func _spawn_projectile(direction: String) -> void:
	# This is where you'd instantiate your projectile scene
	# For now, just a debug print
	print("[Combat] Firing projectile in direction: ", direction)
	
	# Example implementation:
	# var projectile = projectile_scene.instantiate()
	# projectile.global_position = player.global_position
	# projectile.direction = DirectionHelper.direction_name_to_vector(direction)
	# projectile.is_aimed_shot = is_aiming
	# player.get_parent().add_child(projectile)

func _update_combat_state() -> void:
	state_manager.set_state_value("is_aiming", is_aiming)
	state_manager.set_state_value("is_shooting", shoot_animation_playing)

## Called when shooting animation finishes
func on_shoot_animation_finished() -> void:
	is_shooting = false
	shoot_animation_playing = false

## Get the current weapon's fire rate
func get_current_fire_rate() -> float:
	return current_fire_rate

## Get animation speed for shooting animations
func get_shoot_animation_speed() -> float:
	if is_aiming:
		return weapon_stats.aimed_anim_speed
	else:
		return weapon_stats.hip_anim_speed

## Check if currently in combat mode (aiming or shooting)
func is_in_combat_mode() -> bool:
	return is_aiming or is_shooting

## Update weapon stats (useful for weapon switching)
func set_weapon_stats(new_stats: Dictionary) -> void:
	weapon_stats = new_stats

## Debug function to print combat state
func print_combat_state() -> void:
	print("=== Combat State ===")
	print("Is Aiming: ", is_aiming)
	print("Is Shooting: ", is_shooting)
	print("Can Fire: ", can_fire)
	print("Fire Cooldown: ", fire_cooldown_timer)
	print("Current Fire Rate: ", current_fire_rate)
