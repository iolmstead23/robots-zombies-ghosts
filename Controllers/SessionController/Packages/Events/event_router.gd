class_name EventRouter
extends RefCounted

signal grid_state_changed(data: Dictionary)
signal navigation_state_changed(data: Dictionary)
signal debug_visibility_changed(visible: bool)
signal selection_update_requested(data: Dictionary)
signal selection_clear_requested()

var _grid_state: Dictionary = {}
var _navigation_state: Dictionary = {}
var _debug_mode: bool = false


func get_grid_state() -> Dictionary:
	return _grid_state.duplicate()


func get_navigation_state() -> Dictionary:
	return _navigation_state.duplicate()


func is_debug_mode() -> bool:
	return _debug_mode


func on_grid_initialized(data: Dictionary) -> void:
	_grid_state = data
	grid_state_changed.emit(data)


func on_cell_state_changed(_coords: Vector2i, _enabled: bool) -> void:
	pass


func on_grid_stats_changed(stats: Dictionary) -> void:
	_grid_state.merge(stats, true)
	grid_state_changed.emit(_grid_state)


func on_path_found(_start: HexCell, _goal: HexCell, path: Array[HexCell], duration: float) -> void:
	if OS.is_debug_build():
		print("[EventRouter] Path found: %d cells in %.2f ms" % [path.size(), duration])


func on_path_not_found(_start_pos: Vector2, _goal_pos: Vector2, reason: String) -> void:
	if OS.is_debug_build():
		print("[EventRouter] Path not found: %s" % reason)


func on_navigation_started(target: HexCell) -> void:
	if OS.is_debug_build():
		print("[EventRouter] Navigation started to %s" % target)


func on_navigation_completed() -> void:
	if OS.is_debug_build():
		print("[EventRouter] Navigation completed")


func on_navigation_failed(reason: String) -> void:
	if OS.is_debug_build():
		print("[EventRouter] Navigation failed: %s" % reason)


func on_waypoint_reached(_cell: HexCell, _index: int, _remaining: int) -> void:
	pass


func on_navigation_state_changed(active: bool, path_length: int, remaining: int) -> void:
	_navigation_state = {
		"active": active,
		"path_length": path_length,
		"remaining_distance": remaining
	}
	navigation_state_changed.emit(_navigation_state)


func on_debug_visibility_changed(visible: bool) -> void:
	_debug_mode = visible
	debug_visibility_changed.emit(visible)
	if OS.is_debug_build():
		print("[EventRouter] Debug %s" % ("ON" if visible else "OFF"))


func on_debug_info_updated(_key: String, _value: Variant) -> void:
	pass


func on_ui_visibility_changed(visible: bool) -> void:
	if OS.is_debug_build():
		print("[EventRouter] UI overlay %s" % ("shown" if visible else "hidden"))


func on_selected_item_changed(data: Dictionary) -> void:
	if data.get("has_selection", false) and OS.is_debug_build():
		print("[EventRouter] Selected: %s [%s]" % [
			data.get("item_name", "Unknown"),
			data.get("item_type", "Unknown")
		])


func on_object_selected(selection: Dictionary) -> void:
	if OS.is_debug_build():
		print("[EventRouter] Object selected: %s" % selection.get("item_name"))
	selection_update_requested.emit(selection)


func on_selection_cleared() -> void:
	if OS.is_debug_build():
		print("[EventRouter] Selection cleared")
	selection_clear_requested.emit()
