extends Node
class_name AgentInputHandler

## Handles all player input for the agent.
## Left-click emits move_requested. aim/fire/jump are polled each physics frame
## by their respective components using is_aim_pressed(), is_fire_pressed(), is_jump_pressed().
##
## Required Input Map actions (project.godot):
##   jump  — J
##   aim   — RMB
##   fire  — Space

var camera: Camera2D
var is_input_blocked := false
var registry: AgentRegistry

signal move_requested(world_pos: Vector2)

func initialize(registry_ref: AgentRegistry) -> void:
	registry = registry_ref
	registry.subscribe("motion.blocks_input", _on_blocks_input_changed)

func set_camera(cam: Camera2D) -> void:
	camera = cam

func _unhandled_input(event: InputEvent) -> void:
	if is_input_blocked:
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		var world_pos := _get_world_mouse_position(mouse_event.position)
		move_requested.emit(world_pos)

## Polled every physics frame by AgentActionPackage to update aiming state.
func is_aim_pressed() -> bool:
	if is_input_blocked:
		return false
	return Input.is_action_pressed("aim")

## Polled every physics frame by AgentActionPackage to trigger weapon fire.
func is_fire_pressed() -> bool:
	if is_input_blocked:
		return false
	return Input.is_action_pressed("fire")

## Polled every physics frame by AgentMotionPackage.
func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")

func _get_world_mouse_position(screen_pos: Vector2) -> Vector2:
	if camera:
		return camera.get_global_transform_with_canvas().affine_inverse() * screen_pos
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _on_blocks_input_changed(blocks: bool) -> void:
	is_input_blocked = blocks
