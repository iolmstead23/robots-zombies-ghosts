extends Node

## Test script to verify the signal-based controller architecture is working
## Run this from the command line or attach to a test scene

func _ready():
	print("\n" + "=".repeat(70))
	print("TESTING CONTROLLER ARCHITECTURE")
	print("=".repeat(70))

	# Test 1: Can we instantiate controllers?
	print("\n[Test 1] Instantiating Controllers...")

	var hex_grid_ctrl = load("res://Controller/hex_grid_controller.gd").new()
	if hex_grid_ctrl:
		print("  ✓ HexGridController instantiated")
	else:
		print("  ✗ HexGridController FAILED")

	var nav_ctrl = load("res://Controller/navigation_controller.gd").new()
	if nav_ctrl:
		print("  ✓ NavigationController instantiated")
	else:
		print("  ✗ NavigationController FAILED")

	var debug_ctrl = load("res://Controller/debug_controller.gd").new()
	if debug_ctrl:
		print("  ✓ DebugController instantiated")
	else:
		print("  ✗ DebugController FAILED")

	# Test 2: Can we instantiate SessionController?
	print("\n[Test 2] Instantiating SessionController...")

	var session_ctrl = load("res://Controller/session_controller.gd").new()
	if session_ctrl:
		print("  ✓ SessionController instantiated")
		print("  ✓ No autoload conflict detected")
	else:
		print("  ✗ SessionController FAILED")

	# Test 3: Check global script class registry
	print("\n[Test 3] Checking Global Script Classes...")

	var global_classes = ProjectSettings.get_setting("_global_script_classes")
	var found_classes = []

	for cls in global_classes:
		if cls["class"] in ["SessionController", "HexGridController", "NavigationController", "DebugController"]:
			found_classes.append(cls["class"])
			print("  ✓ %s registered at %s" % [cls["class"], cls["path"]])

	if found_classes.size() == 4:
		print("  ✓ All controllers registered in global class registry")
	else:
		print("  ⚠ Only %d/4 controllers found" % found_classes.size())

	# Test 4: Check for autoload conflicts
	print("\n[Test 4] Checking for Autoload Conflicts...")

	var autoloads = []
	for prop in ProjectSettings.get_property_list():
		if prop["name"].begins_with("autoload/"):
			var autoload_name = prop["name"].replace("autoload/", "")
			autoloads.append(autoload_name)
			print("  Autoload: %s" % autoload_name)

	if "SessionController" in autoloads:
		print("  ✗ ERROR: SessionController is registered as autoload!")
	else:
		print("  ✓ No SessionController autoload found")

	print("\n" + "=".repeat(70))
	print("TEST COMPLETE")
	print("=".repeat(70) + "\n")

	# Clean up
	hex_grid_ctrl.free()
	nav_ctrl.free()
	debug_ctrl.free()
	session_ctrl.free()
