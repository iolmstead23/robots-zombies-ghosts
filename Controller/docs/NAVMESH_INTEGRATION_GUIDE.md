# Hexagonal Grid + NavigationRegion2D Integration Guide

This guide shows how to integrate the hexagonal grid system with your existing NavigationRegion2D setup.

## 🎯 What This Does

The integration automatically:
- ✅ Disables hex cells outside the navigation mesh
- ✅ Disables hex cells blocked by baked obstacles
- ✅ Only shows enabled (navigable) cells in debug mode
- ✅ Syncs with NavigationRegion2D after baking

## 🚀 Quick Setup

### Step 1: Your Existing Scene Structure

```
YourGameScene (Node2D)
├── NavigationRegion2D  ← Your existing navigation setup
│   ├── NavigationPolygon (with baked obstacles)
│   └── (Your static obstacles: walls, barrels, etc.)
├── Player (CharacterBody2D)
└── (Other game elements)
```

### Step 2: Add SessionController

```gdscript
# In your main scene script or as a node
extends Node2D

@onready var nav_region: NavigationRegion2D = $NavigationRegion2D

func _ready():
    # Create session controller
    var session = SessionController.new()
    session.name = "SessionController"
    
    # Configure grid size to cover your navigation area
    session.grid_width = 30
    session.grid_height = 20
    session.hex_size = 32.0  # Adjust based on your tile size
    
    # IMPORTANT: Link to your NavigationRegion2D
    session.navigation_region = nav_region
    session.integrate_with_navmesh = true
    session.navmesh_sample_points = 5  # Higher = more accurate
    
    # Enable debug mode to visualize
    session.debug_mode = true
    
    add_child(session)
    
    # Wait for initialization
    await session.terrain_initialized
    
    print("Hex grid ready and synced with navmesh!")
```

### Step 3: Scene Setup in Godot Editor

**Option A: Via Code (shown above)**

**Option B: Via Godot Editor**

1. Add `SessionController` as a child node (Node type)
2. Attach `session_controller.gd` script
3. In Inspector, configure:
   - Grid Width: 30
   - Grid Height: 20
   - Hex Size: 32.0
   - **Navigation Region: (drag your NavigationRegion2D node here)**
   - Integrate With Navmesh: ✓ ON
   - Navmesh Sample Points: 5
   - Debug Mode: ✓ ON (for testing)
   - Auto Initialize: ✓ ON

## 📐 Adjusting Grid Size

### Calculate Grid Dimensions

```gdscript
# Get your NavigationRegion2D bounds
var nav_polygon = navigation_region.navigation_polygon
var bounds = nav_polygon.get_bounds()

# Calculate required grid size
var grid_width_needed = int(bounds.size.x / hex_size) + 2
var grid_height_needed = int(bounds.size.y / hex_size) + 2

session.grid_width = grid_width_needed
session.grid_height = grid_height_needed
```

### Hex Size Calculation

```gdscript
# For square tiles (64x64 pixels):
hex_size = 32.0  # Half the tile width

# For isometric tiles (64x32 pixels):
hex_size = 32.0  # Half the horizontal width

# For larger tiles (96x48 pixels):
hex_size = 48.0
```

## 🔄 After Baking New Obstacles

When you add/remove obstacles and re-bake your NavigationPolygon:

```gdscript
# After baking
func _on_navigation_baked():
    session_controller.refresh_navmesh_integration()
```

## 🎮 Using the Grid in Your Game

### Example: Agent Movement

```gdscript
extends CharacterBody2D

@onready var hex_grid: HexGrid
@onready var pathfinder: HexPathfinder

func _ready():
    var session = get_node("/root/Game/SessionController")
    hex_grid = session.get_terrain()
    
    # Create pathfinder
    pathfinder = HexPathfinder.new()
    pathfinder.hex_grid = hex_grid
    add_child(pathfinder)

func move_to_mouse():
    var mouse_pos = get_global_mouse_position()
    
    # Get target cell
    var target_cell = hex_grid.get_cell_at_world_position(mouse_pos)
    
    # Check if navigable
    if not target_cell or not target_cell.enabled:
        print("Can't move there - blocked or outside navmesh")
        return
    
    # Get current cell
    var current_cell = hex_grid.get_cell_at_world_position(global_position)
    
    # Find path
    var path = pathfinder.find_path(current_cell, target_cell)
    
    if path.is_empty():
        print("No path found")
        return
    
    # Move along path
    follow_path(path)

func follow_path(path: Array[HexCell]):
    for cell in path:
        # Your movement logic here
        await move_to_position(cell.world_position)

func move_to_position(target: Vector2):
    # Smooth movement implementation
    var tween = create_tween()
    tween.tween_property(self, "global_position", target, 0.3)
    await tween.finished
```

### Example: Show Attack Range

```gdscript
func show_attack_range(weapon_range: int):
    var current_cell = hex_grid.get_cell_at_world_position(global_position)
    var cells_in_range = hex_grid.get_enabled_cells_in_range(current_cell, weapon_range)
    
    # Highlight these cells in your UI
    for cell in cells_in_range:
        highlight_cell(cell)
```

## 🎨 Debug Visualization

### What You'll See

When debug mode is ON:
- **Green hexagons** = Navigable cells (enabled)
- **No hexagons** = Blocked by obstacles or outside navmesh
- **White text** = Cell indices and coordinates

### Toggle Debug Mode

```gdscript
# Via code
session_controller.toggle_debug_mode()

# Or press F3 (default hotkey)
```

### Customize Debug Appearance

```gdscript
# In SessionController's _setup_debug_system()
hex_grid_debug.enabled_outline_color = Color.CYAN
hex_grid_debug.outline_width = 2.0
hex_grid_debug.font_size = 10
hex_grid_debug.show_indices = true
hex_grid_debug.show_coordinates = true
hex_grid_debug.show_disabled_outlines = false  # Don't show blocked cells
```

## 🔧 Integration Settings

### Navmesh Sample Points

Controls accuracy of obstacle detection:

```gdscript
session.navmesh_sample_points = 1   # Fast, less accurate
session.navmesh_sample_points = 5   # Balanced (recommended)
session.navmesh_sample_points = 9   # Slow, very accurate
```

**How it works:**
- Tests multiple points within each hexagon
- If majority of points are on navmesh → cell enabled
- Higher values = better detection but slower initialization

### Manual Cell Updates

Update specific cells after runtime changes:

```gdscript
# Update single cell
navmesh_integration.update_cell_at_position(obstacle_position)

# Update area around point
navmesh_integration.update_cells_in_area(explosion_center, radius_cells)

# Refresh entire grid
session_controller.refresh_navmesh_integration()
```

## 📊 Common Scenarios

### Scenario 1: Dynamic Obstacles

```gdscript
func place_barrel(position: Vector2):
    # Spawn barrel
    var barrel = barrel_scene.instantiate()
    barrel.global_position = position
    add_child(barrel)
    
    # Re-bake navigation
    navigation_region.bake_navigation_polygon()
    
    # Refresh hex grid
    await get_tree().physics_frame
    session_controller.refresh_navmesh_integration()
```

### Scenario 2: Multiple Navigation Regions

```gdscript
# If you have multiple NavigationRegion2D nodes
var regions = [nav_region_1, nav_region_2]

for region in regions:
    var session = SessionController.new()
    session.navigation_region = region
    session.integrate_with_navmesh = true
    # ... configure and add
```

### Scenario 3: Grid Offset/Position

```gdscript
# If your grid needs to be offset
func _setup_hex_grid():
    hex_grid.global_position = navigation_region.global_position
    # Grid will align with navmesh
```

## ⚠️ Troubleshooting

### Issue: No hexagons appear

**Solution:**
```gdscript
# Check if NavigationRegion2D is assigned
if not session.navigation_region:
    print("ERROR: NavigationRegion2D not assigned!")

# Check if navmesh is baked
if not navigation_region.navigation_polygon:
    print("ERROR: NavigationPolygon not baked!")

# Enable debug mode to see what's happening
session.debug_mode = true
```

### Issue: Wrong cells are disabled

**Solution:**
```gdscript
# Increase sample points for better accuracy
session.navmesh_sample_points = 9

# Or adjust hex size to better match your tiles
session.hex_size = 48.0  # Make larger/smaller
```

### Issue: Cells near obstacles still enabled

**Solution:**
```gdscript
# Make sure obstacles are in NavigationPolygon
navigation_region.bake_navigation_polygon()

# Increase sample points
session.navmesh_sample_points = 9

# Manually disable cells near obstacle
var obstacle_cell = hex_grid.get_cell_at_world_position(obstacle_pos)
hex_grid.disable_cells_in_area(obstacle_pos, 1)
```

### Issue: Performance is slow

**Solution:**
```gdscript
# Reduce sample points
session.navmesh_sample_points = 1  # Fastest

# Or reduce grid size
session.grid_width = 20  # Smaller grid
session.grid_height = 15
```

## 📈 Performance

### Integration Time

- 10×10 grid (100 cells): ~10ms
- 30×20 grid (600 cells): ~50ms
- 50×50 grid (2500 cells): ~200ms

**Tip:** Run integration once at level load, not every frame!

## 🎯 Complete Example Scene

```gdscript
extends Node2D

@onready var nav_region: NavigationRegion2D = $NavigationRegion2D
@onready var player: CharacterBody2D = $Player

var session_controller: SessionController
var hex_grid: HexGrid

func _ready():
    _setup_hex_grid()
    _setup_player()

func _setup_hex_grid():
    # Create session controller
    session_controller = SessionController.new()
    session_controller.name = "SessionController"
    
    # Configure
    session_controller.grid_width = 30
    session_controller.grid_height = 20
    session_controller.hex_size = 32.0
    session_controller.navigation_region = nav_region
    session_controller.integrate_with_navmesh = true
    session_controller.debug_mode = true
    
    add_child(session_controller)
    
    # Wait for initialization
    await session_controller.terrain_initialized
    
    hex_grid = session_controller.get_terrain()
    print("Hex grid ready with %d navigable cells" % hex_grid.enabled_cells.size())

func _setup_player():
    # Give player reference to grid
    player.hex_grid = hex_grid

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            player.move_to_mouse()
```

---

## 🎊 You're All Set!

Your hexagonal grid is now fully integrated with Godot's NavigationRegion2D system. The grid will automatically respect:
- Navigation mesh boundaries
- Baked obstacles
- Dynamic obstacle changes (with refresh)

**Press F3 to toggle debug and see your hex grid overlay!**
