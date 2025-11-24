# Hexagonal Navigation - Integration Guide

This guide walks you through integrating the hexagonal navigation system into your Godot 4.x project.

---

## Quick Start (5 Minutes)

### Option 1: Using SessionController (Recommended)

The fastest way to get started:

```gdscript
# 1. Add SessionController to your scene
# In your main scene (e.g., GameLevel.tscn):
#   - Right-click scene root
#   - Add Child Node → Node
#   - Attach script: SessionController.gd

# 2. Configure in Inspector
extends Node2D

@onready var session = $SessionController

func _ready():
    # SessionController auto-initializes
    await session.session_started
    print("Hex navigation ready!")

    # Access the grid
    var grid = session.get_terrain()
    print("Grid size: ", grid.get_grid_stats())
```

**That's it!** You now have a working hex grid.

---

## Step-by-Step Integration

### Step 1: Add Required Scripts

Copy these scripts to your project:
- [hex_cell.gd](../hex_cell.gd) - Cell data structure
- [hex_grid.gd](../hex_grid.gd) - Grid controller
- [hex_pathfinder.gd](../hex_pathfinder.gd) - Pathfinding
- [hex_grid_debug.gd](../hex_grid_debug.gd) - Visual debugging
- [session_controller.gd](../session_controller.gd) - Session manager

Optional (advanced features):
- [hex_grid_obstacle_manager.gd](../hex_grid_obstacle_manager.gd) - Physics obstacles
- [HexGridNavmeshIntegration.gd](../HexGridNavmeshIntegration.gd) - NavMesh sync

### Step 2: Scene Setup

**Scene Structure:**
```
GameLevel (Node2D)
├── SessionController (Node)
├── NavigationRegion2D (optional)
└── YourGameObjects
```

**In Godot Editor:**
1. Open your main game scene
2. Add a `Node` as child of root
3. Attach `session_controller.gd` script
4. Configure exports in Inspector

### Step 3: Configure SessionController

**In the Inspector:**

```gdscript
# Grid Configuration
Grid Width: 20              # Adjust to your level size
Grid Height: 15             # Adjust to your level size
Hex Size: 32.0              # Match your tile/sprite size
Auto Initialize: true       # Start automatically

# Navigation Integration (optional)
Navigation Region: null     # Drag NavigationRegion2D here if using
Integrate With Navmesh: false  # Enable if using NavigationRegion2D
Navmesh Sample Points: 5    # Accuracy of navmesh integration

# Debug
Debug Mode: true            # Enable for development
Debug Hotkey Enabled: true  # F3 to toggle
```

### Step 4: Test the Setup

Create a test script:

```gdscript
extends Node2D

@onready var session = $SessionController

func _ready():
    await session.session_started

    # Test: Get grid stats
    var grid = session.get_terrain()
    var stats = grid.get_grid_stats()
    print("Total cells: ", stats.total_cells)
    print("Enabled cells: ", stats.enabled_cells)

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        # Test: Click to get cell info
        var cell = session.get_cell_at_position(event.position)
        if cell:
            print("Clicked cell: ", cell.get_axial_coords())
            print("World position: ", cell.world_position)
```

**Run the scene** and press F3 to see the grid overlay!

---

## Adding Pathfinding

### Step 1: Add HexPathfinder to Scene

```gdscript
# Option A: In SessionController's child nodes (manual)
var pathfinder = HexPathfinder.new()
pathfinder.name = "Pathfinder"
pathfinder.hex_grid = session.get_terrain()
session.add_child(pathfinder)

# Option B: As scene node (recommended)
# Add Node → HexPathfinder
# Link hex_grid export to SessionController/HexGrid
```

### Step 2: Implement Click-to-Move

```gdscript
extends CharacterBody2D

@export var session: SessionController
@export var speed: float = 200.0

var pathfinder: HexPathfinder
var current_path: Array[HexCell] = []
var path_index: int = 0

func _ready():
    # Get or create pathfinder
    pathfinder = HexPathfinder.new()
    pathfinder.hex_grid = session.get_terrain()
    add_child(pathfinder)

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var grid = session.get_terrain()
        var start = grid.get_cell_at_world_position(global_position)
        var goal = grid.get_cell_at_world_position(event.position)

        if start and goal:
            current_path = pathfinder.find_path(start, goal)
            path_index = 0

func _physics_process(delta):
    if path_index < current_path.size():
        var target = current_path[path_index]
        var direction = (target.world_position - global_position).normalized()

        velocity = direction * speed
        move_and_slide()

        # Move to next waypoint when close
        if global_position.distance_to(target.world_position) < 5.0:
            path_index += 1
    else:
        velocity = Vector2.ZERO
```

**Test it:** Click anywhere and watch your character navigate!

---

## Adding NavMesh Integration

If you're using Godot's built-in navigation system:

### Step 1: Create NavigationRegion2D

1. Add `NavigationRegion2D` to your scene
2. Create a new `NavigationPolygon` resource
3. Draw the walkable area outline
4. Bake the navigation mesh

### Step 2: Link to SessionController

In SessionController inspector:
```
Navigation Region: [NavigationRegion2D]  # Drag your NavigationRegion2D here
Integrate With Navmesh: true
Navmesh Sample Points: 5  # Higher = more accurate, slower
```

### Step 3: Test Integration

```gdscript
func _ready():
    await session.session_started

    # Grid now reflects navmesh
    var grid = session.get_terrain()
    var stats = grid.get_grid_stats()
    print("Enabled cells: ", stats.enabled_cells)
    print("Disabled cells: ", stats.disabled_cells)

    # Disabled cells are off the navmesh
    # Toggle debug (F3) to see the result
```

**Result:** Cells outside the navmesh are automatically disabled.

---

## Adding Obstacle Detection

For dynamic obstacle detection using physics:

### Step 1: Add ObstacleManager

```gdscript
var obstacle_mgr = HexGridObstacleManager.new()
obstacle_mgr.name = "ObstacleManager"
obstacle_mgr.hex_grid = session.get_terrain()
obstacle_mgr.collision_mask = 1  # Set to your obstacle layer
session.add_child(obstacle_mgr)
```

### Step 2: Setup Physics Layers

1. Configure your obstacles on a physics layer (e.g., Layer 1)
2. Set `collision_mask = 1` to detect Layer 1

### Step 3: Scan for Obstacles

```gdscript
func _ready():
    await session.session_started

    # Scan entire grid once
    obstacle_mgr.scan_all_cells()

    # Or scan specific area
    obstacle_mgr.scan_area(center_position, 5)
```

### Step 4: Register Static Obstacles

```gdscript
# When spawning obstacle
func spawn_obstacle(position: Vector2):
    var obstacle = preload("res://obstacle.tscn").instantiate()
    obstacle.global_position = position
    add_child(obstacle)

    # Disable surrounding cells
    obstacle_mgr.register_static_obstacle(obstacle, 1)

# When removing obstacle
func remove_obstacle(obstacle: Node2D):
    obstacle_mgr.unregister_static_obstacle(obstacle, 1)
    obstacle.queue_free()
```

---

## Scene Template

Here's a complete scene template:

```
GameLevel.tscn
├── GameLevel (Node2D)
│   └── Script: game_level.gd
├── SessionController (Node)
│   ├── Grid Width: 20
│   ├── Grid Height: 15
│   ├── Hex Size: 32.0
│   └── Debug Mode: true
├── NavigationRegion2D (NavigationRegion2D) [optional]
│   └── NavigationPolygon: [baked mesh]
├── Pathfinder (Node)
│   ├── Script: hex_pathfinder.gd
│   └── Hex Grid: → SessionController/HexGrid
├── Player (CharacterBody2D)
│   ├── Script: player.gd
│   └── Session: → SessionController
└── Environment (Node2D)
    ├── Walls
    ├── Obstacles
    └── Decorations
```

**game_level.gd:**
```gdscript
extends Node2D

@onready var session = $SessionController
@onready var pathfinder = $Pathfinder

func _ready():
    await session.session_started
    print("Level ready!")

    # Optional: Setup obstacles
    _setup_obstacles()

func _setup_obstacles():
    var obstacle_mgr = HexGridObstacleManager.new()
    obstacle_mgr.hex_grid = session.get_terrain()
    obstacle_mgr.collision_mask = 1
    session.add_child(obstacle_mgr)

    # Scan for physics obstacles
    await get_tree().process_frame
    obstacle_mgr.scan_all_cells()
```

---

## Common Integration Scenarios

### Scenario 1: Turn-Based Strategy Game

```gdscript
extends Node2D

@onready var session = $SessionController
var pathfinder: HexPathfinder
var selected_unit: Unit = null

func _ready():
    pathfinder = HexPathfinder.new()
    pathfinder.hex_grid = session.get_terrain()
    add_child(pathfinder)

func select_unit(unit: Unit):
    selected_unit = unit
    show_movement_range(unit)

func show_movement_range(unit: Unit):
    var grid = session.get_terrain()
    var unit_cell = grid.get_cell_at_world_position(unit.position)
    var reachable = pathfinder.get_cells_in_movement_range(unit_cell, unit.movement_points)

    # Highlight reachable cells
    for cell in reachable:
        highlight_cell(cell, Color.BLUE)

func _input(event):
    if event is InputEventMouseButton and event.pressed and selected_unit:
        var clicked_cell = session.get_cell_at_position(event.position)
        move_unit_to_cell(selected_unit, clicked_cell)
```

### Scenario 2: Real-Time Action Game

```gdscript
extends Node2D

@onready var session = $SessionController
var pathfinder: HexPathfinder

func _ready():
    await session.session_started
    pathfinder = $Pathfinder

func spawn_enemy(spawn_pos: Vector2, target: Node2D):
    var enemy = preload("res://enemy.tscn").instantiate()
    enemy.position = spawn_pos
    enemy.setup(pathfinder, target)
    add_child(enemy)

# In enemy.gd:
func _physics_process(delta):
    # Recalculate path periodically
    if path_timer > 1.0:
        update_path_to_target()
        path_timer = 0.0
    path_timer += delta

    # Follow path
    follow_current_path(delta)
```

### Scenario 3: Ability Range Indicators

```gdscript
func show_ability_range(caster: Unit, ability: Ability):
    var grid = session.get_terrain()
    var caster_cell = grid.get_cell_at_world_position(caster.position)

    # Get cells in range
    var cells = grid.get_enabled_cells_in_range(caster_cell, ability.range)

    # Filter by line of sight if needed
    if ability.requires_los:
        cells = cells.filter(func(c): return has_line_of_sight(caster_cell, c))

    # Highlight
    for cell in cells:
        highlight_cell(cell, ability.range_color)

func cast_ability(caster: Unit, target_pos: Vector2, ability: Ability):
    var grid = session.get_terrain()
    var target_cell = grid.get_cell_at_world_position(target_pos)
    var caster_cell = grid.get_cell_at_world_position(caster.position)

    # Validate range
    var distance = caster_cell.distance_to(target_cell)
    if distance <= ability.range:
        apply_ability_effect(target_cell, ability)
```

---

## Troubleshooting

### Grid Not Showing
**Problem**: Debug overlay not visible
**Solution**:
- Press F3 to toggle debug
- Check `debug_enabled = true` in SessionController
- Verify HexGridDebug is in scene tree

### Cells Too Large/Small
**Problem**: Grid doesn't match art
**Solution**:
- Adjust `hex_size` in SessionController
- Common values: 16, 32, 64 pixels
- Should match your tile/sprite dimensions

### Pathfinding Not Working
**Problem**: `find_path()` returns empty array
**Solution**:
- Check both cells are enabled (press F3)
- Verify pathfinder.hex_grid is set
- Ensure start != goal
- Check for obstacles blocking path

### NavMesh Integration Issues
**Problem**: Cells enabled/disabled incorrectly
**Solution**:
- Increase `navmesh_sample_points` to 7-9
- Verify NavigationRegion2D is baked
- Check `grid_offset` matches NavRegion position
- Wait for `integration_complete` signal

### Click Detection Offset
**Problem**: Clicks don't match visual grid
**Solution**:
- Adjust `grid_offset` to center grid
- For isometric: set `sprite_vertical_offset`
- Check camera position/zoom
- Verify mouse position is in correct coordinate space

---

## Next Steps

After integration, explore:
1. **[HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)** - Complete API reference
2. **[VISUAL_GUIDE.md](VISUAL_GUIDE.md)** - Visual examples and patterns
3. Customize cell costs for terrain types
4. Add custom metadata to cells
5. Implement fog of war using cell visibility
6. Create range indicators for abilities
7. Build turn-based movement systems

---

## Performance Optimization

### For Large Grids (30x30+)

```gdscript
# Reduce navmesh sampling
navmesh_sample_points = 3  # Instead of 5

# Disable debug in production
debug_mode = false

# Cache pathfinding results
var path_cache: Dictionary = {}

func find_path_cached(start: HexCell, goal: HexCell):
    var key = "%d_%d" % [start.index, goal.index]
    if key not in path_cache:
        path_cache[key] = pathfinder.find_path(start, goal)
    return path_cache[key]

# Clear cache when grid changes
func _on_grid_changed():
    path_cache.clear()
```

### For Many Units

```gdscript
# Stagger pathfinding updates
var update_interval: float = 0.1
var units_per_frame: int = 5

func _process(delta):
    update_timer += delta
    if update_timer >= update_interval:
        update_timer = 0.0
        update_next_units_batch()
```

---

## Support & Resources

- **Script Files**: [Controller/](../)
- **Quick Reference**: [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)
- **Visual Guide**: [VISUAL_GUIDE.md](VISUAL_GUIDE.md)
- **Godot Docs**: [NavigationRegion2D](https://docs.godotengine.org/en/stable/classes/class_navigationregion2d.html)

---

**You're all set!** Start with SessionController, add pathfinding, and expand from there.
