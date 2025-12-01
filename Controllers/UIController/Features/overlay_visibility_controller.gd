class_name OverlayVisibilityController
extends RefCounted

## Atomized Feature: Overlay Visibility Management
## Manages visibility state for UI overlays with support for multiple named overlays
## Pure logic component - no UI dependencies

# ============================================================================
# SIGNALS
# ============================================================================

signal visibility_changed(overlay_name: String, is_visible: bool)
signal all_hidden()
signal all_shown()

# ============================================================================
# STATE
# ============================================================================

var _overlay_states: Dictionary = {} # {overlay_name: bool}
var _global_visibility: bool = true

# ============================================================================
# PUBLIC API - Individual Overlay Control
# ============================================================================

func register_overlay(overlay_name: String, initial_visibility: bool = true) -> void:
	"""Register an overlay for visibility management"""
	if not _overlay_states.has(overlay_name):
		_overlay_states[overlay_name] = initial_visibility

func unregister_overlay(overlay_name: String) -> void:
	"""Remove an overlay from management"""
	_overlay_states.erase(overlay_name)

func set_overlay_visible(overlay_name: String, is_visible: bool) -> void:
	"""Set visibility for a specific overlay"""
	if not _overlay_states.has(overlay_name):
		push_warning("OverlayVisibilityController: Overlay '%s' not registered" % overlay_name)
		register_overlay(overlay_name, is_visible)
		return

	if _overlay_states[overlay_name] != is_visible:
		_overlay_states[overlay_name] = is_visible
		visibility_changed.emit(overlay_name, _get_effective_visibility(overlay_name))

func toggle_overlay(overlay_name: String) -> void:
	"""Toggle visibility for a specific overlay"""
	if not _overlay_states.has(overlay_name):
		push_warning("OverlayVisibilityController: Overlay '%s' not registered" % overlay_name)
		return

	set_overlay_visible(overlay_name, not _overlay_states[overlay_name])

func is_overlay_visible(overlay_name: String) -> bool:
	"""Check if an overlay is visible (considering global visibility)"""
	return _get_effective_visibility(overlay_name)

func get_overlay_state(overlay_name: String) -> bool:
	"""Get the stored visibility state (ignoring global visibility)"""
	return _overlay_states.get(overlay_name, false)

# ============================================================================
# PUBLIC API - Global Control
# ============================================================================

func set_global_visibility(is_visible: bool) -> void:
	"""Set global visibility (affects all overlays)"""
	if _global_visibility != is_visible:
		_global_visibility = is_visible

		# Emit visibility changed for all overlays
		for overlay_name in _overlay_states:
			visibility_changed.emit(overlay_name, _get_effective_visibility(overlay_name))

		if is_visible:
			all_shown.emit()
		else:
			all_hidden.emit()

func hide_all() -> void:
	"""Hide all overlays"""
	set_global_visibility(false)

func show_all() -> void:
	"""Show all overlays (that have individual visibility enabled)"""
	set_global_visibility(true)

func toggle_all() -> void:
	"""Toggle global visibility"""
	set_global_visibility(not _global_visibility)

func is_globally_visible() -> bool:
	"""Check if overlays are globally visible"""
	return _global_visibility

# ============================================================================
# PUBLIC API - Batch Operations
# ============================================================================

func hide_overlays(overlay_names: Array[String]) -> void:
	"""Hide multiple overlays"""
	for name in overlay_names:
		set_overlay_visible(name, false)

func show_overlays(overlay_names: Array[String]) -> void:
	"""Show multiple overlays"""
	for name in overlay_names:
		set_overlay_visible(name, true)

func get_visible_overlays() -> Array[String]:
	"""Get list of currently visible overlays"""
	var visible: Array[String] = []
	for overlay_name in _overlay_states:
		if _get_effective_visibility(overlay_name):
			visible.append(overlay_name)
	return visible

func get_hidden_overlays() -> Array[String]:
	"""Get list of currently hidden overlays"""
	var hidden: Array[String] = []
	for overlay_name in _overlay_states:
		if not _get_effective_visibility(overlay_name):
			hidden.append(overlay_name)
	return hidden

func get_all_overlay_names() -> Array[String]:
	"""Get list of all registered overlays"""
	var names: Array[String] = []
	for key in _overlay_states.keys():
		names.append(key)
	return names

# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _get_effective_visibility(overlay_name: String) -> bool:
	"""Get the effective visibility considering both individual and global state"""
	var individual_state = _overlay_states.get(overlay_name, false)
	return individual_state and _global_visibility
