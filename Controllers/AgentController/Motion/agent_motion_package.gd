extends Node
class_name AgentMotionPackage

## Unified motion package: jump physics, vertical velocity, and scripted falls.
## Publishes: motion.is_jumping, motion.jump_height, motion.is_airborne,
##            motion.is_falling, motion.is_grounded, motion.vertical_state,
##            motion.was_running_on_jump, motion.blocks_input
## Reads from registry: action.is_aiming, action.is_shooting (to gate jump)
##
## motion.vertical_state is the single authoritative vertical phase, one of:
##   "grounded" | "jump_ascent" | "jump_descent" | "falling"
## "falling" is a scripted/external fall (no auto-detection); the flat world has
## no ledges, so hazards call begin_environmental_fall()/end_environmental_fall().

const GRAVITY := 980.0
const JUMP_STRENGTH := 600.0
const MAX_FALL_SPEED := 600.0

var player: CharacterBody2D
var registry: AgentRegistry

var y_offset := 0.0
var vertical_velocity := 0.0
var was_running_when_jumped := false
var jump_key_released := true
var _environmental_falling := false

signal jump_started()
signal jump_landed()
signal fall_started()
signal fall_recovered()

func initialize(player_ref: CharacterBody2D, registry_ref: AgentRegistry) -> void:
	player = player_ref
	registry = registry_ref

func update(delta: float) -> void:
	_handle_jump_input()

	if registry.query("motion.is_jumping"):
		_process_jump_physics(delta)

	var vstate := _resolve_vertical_state()
	registry.publish("motion.vertical_state", vstate)
	registry.publish("motion.is_grounded", vstate == "grounded")
	registry.publish("motion.jump_height", y_offset)
	registry.publish("motion.is_airborne", y_offset > 0.0)
	registry.publish("motion.is_falling", vstate == "jump_descent" or vstate == "falling")
	registry.publish("motion.was_running_on_jump", was_running_when_jumped)

## Single authoritative vertical phase. A scripted environmental fall outranks
## jump physics; otherwise the jump's vertical velocity decides ascent vs descent.
func _resolve_vertical_state() -> String:
	if _environmental_falling:
		return "falling"
	if registry.query("motion.is_jumping"):
		return "jump_descent" if vertical_velocity < 0.0 else "jump_ascent"
	return "grounded"

## Public hook for hazards/scripts to force the agent into a fall. Reuses the
## existing motion.blocks_input plumbing so input is disabled for the duration.
func begin_environmental_fall() -> void:
	if _environmental_falling:
		return
	_environmental_falling = true
	registry.publish("motion.blocks_input", true)
	fall_started.emit()

func end_environmental_fall() -> void:
	if not _environmental_falling:
		return
	_environmental_falling = false
	# Only keep input blocked if a jump is still in progress.
	registry.publish("motion.blocks_input", registry.query("motion.is_jumping"))
	fall_recovered.emit()

func _handle_jump_input() -> void:
	var controller := get_parent() as AgentController
	if not controller or not controller.input_handler:
		return

	if not controller.input_handler.is_jump_pressed():
		jump_key_released = true

	if _check_can_jump():
		_start_jump()
		jump_key_released = false

func _check_can_jump() -> bool:
	var controller := get_parent() as AgentController
	if not controller or not controller.input_handler or not controller.input_handler.is_jump_pressed():
		return false

	if not jump_key_released:
		return false

	if registry.query("motion.is_jumping"):
		return false

	if registry.query("action.is_aiming"):
		return false

	if registry.query("action.is_shooting"):
		return false

	return true

func _start_jump() -> void:
	was_running_when_jumped = registry.query("motion.is_running")
	vertical_velocity = JUMP_STRENGTH
	registry.publish("motion.was_running_on_jump", was_running_when_jumped)
	registry.publish("motion.is_jumping", true)
	registry.publish("motion.blocks_input", true)
	jump_started.emit()

func _process_jump_physics(delta: float) -> void:
	vertical_velocity -= GRAVITY * delta
	vertical_velocity = max(vertical_velocity, -MAX_FALL_SPEED)

	y_offset += vertical_velocity * delta

	if y_offset <= 0.0:
		_land_from_jump()

func _land_from_jump() -> void:
	y_offset = 0.0
	vertical_velocity = 0.0
	was_running_when_jumped = false
	registry.publish("motion.blocks_input", false)
	registry.publish("motion.is_jumping", false)
	jump_landed.emit()

func get_current_height() -> float:
	return y_offset

func is_at_peak() -> bool:
	return registry.query("motion.is_jumping") and abs(vertical_velocity) < 10.0

func is_falling() -> bool:
	return registry.query("motion.is_jumping") and vertical_velocity < 0

func was_running_on_jump_start() -> bool:
	return was_running_when_jumped

func print_jump_state() -> void:
	if not OS.is_debug_build():
		return

	print("AgentMotionPackage: Height %.1f | Velocity %.1f | Peak: %s" % [
		y_offset, vertical_velocity, is_at_peak()
	])
