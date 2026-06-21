extends Node
class_name AgentCombatComponent

## Manages combat functionality including shooting and aiming

var weapon_stats := {
	"aimed_fire_rate": 0.05,
	"hip_fire_rate": 0.0667,
	"aimed_anim_speed": 20.0,
	"hip_anim_speed": 15.0
}

var state_manager: AgentState
var input_handler: AgentInputHandler

var is_aiming := false
var is_shooting := false
var can_fire := true
var fire_cooldown_timer := 0.0
var current_fire_rate := 0.0
var shoot_animation_playing := false

signal weapon_fired(direction: String)

func initialize(state_ref: AgentState, input_ref: AgentInputHandler) -> void:
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
	if not input_handler:
		return

	is_aiming = input_handler.is_aim_pressed()

func _handle_shooting() -> void:
	if not input_handler:
		return

	var fire_pressed: bool = input_handler.is_fire_pressed()
	var is_jumping: bool = state_manager.get_state_value("is_jumping")

	if fire_pressed and can_fire and not is_jumping:
		_fire_weapon()

func _fire_weapon() -> void:
	can_fire = false
	is_shooting = true
	shoot_animation_playing = true

	current_fire_rate = weapon_stats.aimed_fire_rate if is_aiming else weapon_stats.hip_fire_rate
	fire_cooldown_timer = current_fire_rate

	var direction: String = str(state_manager.get_state_value("facing_direction"))
	if OS.is_debug_build():
		print_debug("FIRE: %s (%.3fs cooldown)" % [direction, current_fire_rate])
	weapon_fired.emit(direction)

func _update_combat_state() -> void:
	state_manager.set_state_value("is_aiming", is_aiming)
	state_manager.set_state_value("is_shooting", shoot_animation_playing)

func on_shoot_animation_finished() -> void:
	is_shooting = false
	shoot_animation_playing = false

## Immediately sync internal combat flags to shared state (called when animation finishes).
func sync_state_immediately(state_ref: AgentState) -> void:
	state_ref.set_state_value("is_aiming", is_aiming)
	state_ref.set_state_value("is_shooting", shoot_animation_playing)

func get_current_fire_rate() -> float:
	return current_fire_rate

func get_shoot_animation_speed() -> float:
	return weapon_stats.aimed_anim_speed if is_aiming else weapon_stats.hip_anim_speed

func print_combat_state() -> void:
	if not OS.is_debug_build():
		return

	print("=== AgentCombatComponent ===")
	print("Aiming: %s | Shooting: %s | Can Fire: %s" % [is_aiming, is_shooting, can_fire])
	print("Cooldown: %.3fs | Fire Rate: %.3fs" % [fire_cooldown_timer, current_fire_rate])
