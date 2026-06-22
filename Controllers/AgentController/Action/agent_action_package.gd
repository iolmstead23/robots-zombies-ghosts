extends Node
class_name AgentActionPackage

## Manages aiming and shooting state, fire cooldowns, and run+combat resolution.
## Publishes: action.is_aiming, action.is_shooting, action.demands_walk, action.shoot_anim_speed
## Reads from registry: motion.is_jumping, motion.is_running, motion.facing_direction

var weapon_stats := {
	"aimed_fire_rate": 0.05,
	"hip_fire_rate": 0.0667,
	"aimed_anim_speed": 20.0,
	"hip_anim_speed": 15.0
}

var registry: AgentRegistry
var input_handler: AgentInputHandler

var is_aiming := false
var is_shooting := false
var can_fire := true
var fire_cooldown_timer := 0.0
var current_fire_rate := 0.0

signal weapon_fired(direction: String)

func initialize(registry_ref: AgentRegistry, input_ref: AgentInputHandler) -> void:
	registry = registry_ref
	input_handler = input_ref

func update(delta: float) -> void:
	_update_fire_cooldown(delta)
	_handle_aiming()
	_handle_shooting()
	_update_combat_state()
	_resolve_run_shoot_conflict()

func _update_fire_cooldown(delta: float) -> void:
	if fire_cooldown_timer > 0:
		fire_cooldown_timer -= delta
		if fire_cooldown_timer <= 0:
			can_fire = true
			is_shooting = false

func _handle_aiming() -> void:
	if not input_handler:
		return

	is_aiming = input_handler.is_aim_pressed()

func _handle_shooting() -> void:
	if not input_handler:
		return

	var fire_pressed: bool = input_handler.is_fire_pressed()
	var is_jumping: bool = registry.query("motion.is_jumping")

	if fire_pressed and can_fire and not is_jumping:
		_fire_weapon()

func _fire_weapon() -> void:
	can_fire = false
	is_shooting = true

	current_fire_rate = weapon_stats.aimed_fire_rate if is_aiming else weapon_stats.hip_fire_rate
	fire_cooldown_timer = current_fire_rate

	var direction: String = str(registry.query("motion.facing_direction"))
	if OS.is_debug_build():
		print_debug("FIRE: %s (%.3fs cooldown)" % [direction, current_fire_rate])
	weapon_fired.emit(direction)

func _update_combat_state() -> void:
	registry.publish("action.is_aiming", is_aiming)
	registry.publish("action.is_shooting", is_shooting)
	registry.publish("action.shoot_anim_speed", get_shoot_animation_speed())

func _resolve_run_shoot_conflict() -> void:
	var is_running: bool = bool(registry.query("motion.is_running"))
	var trying_to_fire: bool = input_handler.is_fire_pressed() or input_handler.is_aim_pressed()
	var demands_walk: bool = trying_to_fire and is_running
	registry.publish("action.demands_walk", demands_walk)

func get_current_fire_rate() -> float:
	return current_fire_rate

func get_shoot_animation_speed() -> float:
	return weapon_stats.aimed_anim_speed if is_aiming else weapon_stats.hip_anim_speed

func print_combat_state() -> void:
	if not OS.is_debug_build():
		return

	print("=== AgentActionPackage ===")
	print("Aiming: %s | Shooting: %s | Can Fire: %s" % [is_aiming, is_shooting, can_fire])
	print("Cooldown: %.3fs | Fire Rate: %.3fs" % [fire_cooldown_timer, current_fire_rate])
