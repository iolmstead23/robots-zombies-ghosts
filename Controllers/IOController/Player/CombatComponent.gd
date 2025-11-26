extends Node
class_name CombatComponent

## Manages combat functionality including shooting and aiming

# Weapon stats
var weapon_stats := {
	"aimed_fire_rate": 0.05,
	"hip_fire_rate": 0.0667,
	"aimed_anim_speed": 20.0,
	"hip_anim_speed": 15.0
}

# Component references
var player: CharacterBody2D
var state_manager: StateManager
var input_handler

# Combat state
var is_aiming := false
var is_shooting := false
var can_fire := true
var fire_cooldown_timer := 0.0
var current_fire_rate := 0.0
var shoot_animation_playing := false

signal weapon_fired(direction: String)
signal aim_started()
signal aim_ended()

func initialize(player_ref: CharacterBody2D, state_ref: StateManager, input_ref) -> void:
	player = player_ref
	state_manager = state_ref
	input_handler = input_ref

	if not input_handler and OS.is_debug_build():
		print("CombatComponent: No input handler - combat disabled")

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
	if not input_handler:
		return

	var was_aiming := is_aiming
	is_aiming = input_handler.is_aim_pressed()

	if is_aiming and not was_aiming:
		aim_started.emit()
	elif not is_aiming and was_aiming:
		aim_ended.emit()

func _handle_shooting() -> void:
	if not input_handler:
		return

	var fire_pressed := false # This needs to add a trigger
	var is_jumping: bool = state_manager.get_state_value("is_jumping")

	if fire_pressed and can_fire and not is_jumping:
		_fire_weapon()

func _fire_weapon() -> void:
	can_fire = false
	is_shooting = true
	shoot_animation_playing = true

	current_fire_rate = weapon_stats.aimed_fire_rate if is_aiming else weapon_stats.hip_fire_rate
	fire_cooldown_timer = current_fire_rate

	var direction: String = state_manager.get_state_value("facing_direction")
	_spawn_projectile(direction)
	weapon_fired.emit(direction)

func _spawn_projectile(direction: String) -> void:
	if OS.is_debug_build():
		print("CombatComponent: Firing %s in direction %s" % ["aimed shot" if is_aiming else "hip shot", direction])

func _update_combat_state() -> void:
	state_manager.set_state_value("is_aiming", is_aiming)
	state_manager.set_state_value("is_shooting", shoot_animation_playing)

func on_shoot_animation_finished() -> void:
	is_shooting = false
	shoot_animation_playing = false

func get_current_fire_rate() -> float:
	return current_fire_rate

func get_shoot_animation_speed() -> float:
	return weapon_stats.aimed_anim_speed if is_aiming else weapon_stats.hip_anim_speed

func is_in_combat_mode() -> bool:
	return is_aiming or is_shooting

func set_weapon_stats(new_stats: Dictionary) -> void:
	weapon_stats = new_stats

func print_combat_state() -> void:
	if not OS.is_debug_build():
		return

	print("=== CombatComponent ===")
	print("Aiming: %s | Shooting: %s | Can Fire: %s" % [is_aiming, is_shooting, can_fire])
	print("Cooldown: %.3fs | Fire Rate: %.3fs" % [fire_cooldown_timer, current_fire_rate])
