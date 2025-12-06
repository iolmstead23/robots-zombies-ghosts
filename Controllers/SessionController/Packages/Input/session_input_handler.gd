class_name SessionInputHandler
extends RefCounted

signal execute_movement_requested()
signal cancel_movement_requested()

var _movement_planner: MovementPlanner = null


func configure(movement_planner: MovementPlanner) -> void:
	_movement_planner = movement_planner


func handle_input(event: InputEvent, viewport: Viewport) -> bool:
	if not _is_key_press(event):
		return false

	if not _movement_planner:
		return false

	var key_event := event as InputEventKey

	if key_event.keycode == KEY_SPACE:
		return _handle_space_key(viewport)

	if key_event.keycode == KEY_ESCAPE:
		return _handle_escape_key(viewport)

	return false


func _is_key_press(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and not key_event.echo


func _handle_space_key(viewport: Viewport) -> bool:
	if not _movement_planner or not _movement_planner.has_planned_movement():
		return false

	execute_movement_requested.emit()
	viewport.set_input_as_handled()
	return true


func _handle_escape_key(viewport: Viewport) -> bool:
	if not _movement_planner or not _movement_planner.has_planned_movement():
		return false
	cancel_movement_requested.emit()
	viewport.set_input_as_handled()
	return true
