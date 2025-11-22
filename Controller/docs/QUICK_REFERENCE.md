# Hexagonal Grid System - Quick Reference

## 🚀 Common Operations

### Setup & Initialization

```gdscript
# Option 1: Use SessionController (Recommended)
var session = SessionController.new()
session.grid_width = 20
session.grid_height = 15
session.hex_size = 32.0
session.debug_mode = true
add_child(session)

await session.terrain_initialized
var grid = session.get_terrain()

# Option 2: Direct HexGrid usage
var grid = HexGrid.new()
grid.grid_width = 20
grid.grid_height = 15
grid.hex_size = 32.0
add_child(grid)
grid.initialize_grid()
```

---

## 📍 Cell Access

```gdscript
# Get cell at world position (mouse, player, etc.)
var cell = grid.get_cell_at_world_position(mouse_position)

# Get cell at axial coordinates
var cell = grid.get_cell_at_coords(Vector2i(5, 7))

# Get cell at array index
var cell = grid.get_cell_at_index(42)

# Check if coordinates are valid
if grid.is_valid_coords(Vector2i(10, 20)):
    # Do something
```

---

## 🎯 Distance & Range

```gdscript
# Distance between cells (in meters/cells)
var distance = cell_a.distance_to(cell_b)

# Distance between world positions
var distance = grid.get_distance_world(pos_a, pos_b)

# Get all cells in range
var cells = grid.get_cells_in_range(center_cell, 5)

# Get only enabled cells in range
var enabled = grid.get_enabled_cells_in_range(center_cell, 5)

# Check if in range
func is_in_range(from: Vector2, to: Vector2, range: int) -> bool:
    var distance = grid.get_distance_world(from, to)
    return distance >= 0 and distance <= range
```

---

## 🧭 Neighbors

```gdscript
# Get all 6 neighboring cells
var neighbors = grid.get_neighbors(cell)

# Get only enabled neighbors
var walkable = grid.get_enabled_neighbors(cell)

# Get neighbor coordinates
var coords = cell.get_neighbors_coords()
```

---

## 🚧 Obstacle Management

```gdscript
# Disable a single cell
grid.set_cell_enabled(cell, false)

# Disable area (obstacle placement)
grid.disable_cells_in_area(obstacle_position, radius_cells)

# Enable area (obstacle removal)
grid.enable_cells_in_area(position, radius_cells)

# Using SessionController helpers
session_controller.disable_terrain_at_position(pos, radius)
session_controller.is_position_navigable(pos)

# Automatic obstacle detection
var obstacle_mgr = HexGridObstacleManager.new()
obstacle_mgr.hex_grid = grid
obstacle_mgr.collision_mask = 1  # Your obstacle layer
add_child(obstacle_mgr)
obstacle_mgr.scan_all_cells()

# Register specific obstacle
obstacle_mgr.register_static_obstacle(barrel_node, 1)
```

---

## 🗺️ Pathfinding

```gdscript
# Find path between cells
var pathfinder = HexPathfinder.new()
pathfinder.hex_grid = grid
add_child(pathfinder)

var path = pathfinder.find_path(start_cell, goal_cell)

# Find path from world positions
var path = pathfinder.find_path_world(start_pos, goal_pos)

# Find path to range (e.g., attack range)
var path = pathfinder.find_path_to_range(start_cell, target_cell, attack_range)

# Check if path exists
if pathfinder.is_path_clear(start, goal):
    print("Can reach target!")

# Get movement range (turn-based)
var reachable = pathfinder.get_cells_in_movement_range(start_cell, movement_points)
```

---

## 🎨 Debug & Visualization

```gdscript
# Toggle debug mode
session_controller.toggle_debug_mode()
session_controller.set_debug_mode(true)

# Or directly with debug component
hex_grid_debug.set_debug_enabled(true)
hex_grid_debug.toggle_debug()

# Customize debug appearance
hex_grid_debug.enabled_outline_color = Color.CYAN
hex_grid_debug.disabled_outline_color = Color.RED
hex_grid_debug.outline_width = 3.0
hex_grid_debug.show_indices = true
hex_grid_debug.show_coordinates = false

# Manual highlighting (custom logic needed)
# You'll need to implement this based on your needs
```

---

## 💾 Cell Metadata

```gdscript
# Store custom data on cells
cell.set_metadata("terrain_type", "grass")
cell.set_metadata("movement_cost", 1.5)
cell.set_metadata("cover_value", 0.5)

# Retrieve metadata
var terrain = cell.get_metadata("terrain_type", "default")
var cost = cell.get_metadata("movement_cost", 1.0)

# Use in pathfinding (modify HexPathfinder._movement_cost)
func _movement_cost(from: HexCell, to: HexCell) -> float:
    var base = 1.0
    var terrain_cost = to.get_metadata("movement_cost", 1.0)
    return base * terrain_cost
```

---

## 📊 Grid Information

```gdscript
# Get grid statistics
var stats = grid.get_grid_stats()
print("Total cells: ", stats.total_cells)
print("Enabled: ", stats.enabled_cells)
print("Disabled: ", stats.disabled_cells)

# Grid dimensions
print("Grid size: %dx%d" % [grid.grid_width, grid.grid_height])

# Hex metrics
print("Hex size: ", grid.hex_size)
print("Width: ", grid.hex_width)
print("Height: ", grid.hex_height)
```

---

## 🎮 Common Patterns

### Pattern 1: Click to Move
```gdscript
func _input(event):
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var target_cell = grid.get_cell_at_world_position(get_global_mouse_position())
            if target_cell and target_cell.enabled:
                move_to_cell(target_cell)
```

### Pattern 2: Show Attack Range
```gdscript
func highlight_attack_range(unit_pos: Vector2, range: int):
    var unit_cell = grid.get_cell_at_world_position(unit_pos)
    var targets = grid.get_enabled_cells_in_range(unit_cell, range)
    
    for cell in targets:
        # Your highlight logic here
        draw_highlight(cell.world_position)
```

### Pattern 3: Line of Sight Check
```gdscript
func has_line_of_sight(from_pos: Vector2, to_pos: Vector2) -> bool:
    var path = pathfinder.find_path_world(from_pos, to_pos)
    
    if path.is_empty():
        return false
    
    # Check for blocking obstacles along path
    for cell in path:
        if cell.get_metadata("blocks_sight", false):
            return false
    
    return true
```

### Pattern 4: Spawn Unit on Grid
```gdscript
func spawn_unit(unit_scene: PackedScene, grid_coords: Vector2i) -> Node2D:
    var cell = grid.get_cell_at_coords(grid_coords)
    if not cell or not cell.enabled:
        return null
    
    var unit = unit_scene.instantiate()
    unit.global_position = cell.world_position
    add_child(unit)
    
    # Mark cell as occupied
    cell.set_metadata("occupied", true)
    cell.set_metadata("unit", unit)
    
    return unit
```

### Pattern 5: Turn-Based Movement
```gdscript
var movement_points: int = 5

func show_movement_range(unit_cell: HexCell):
    var reachable = pathfinder.get_cells_in_movement_range(unit_cell, movement_points)
    
    for cell in reachable:
        highlight_cell(cell, Color.BLUE)

func move_unit(unit: Node2D, target_cell: HexCell):
    var current_cell = grid.get_cell_at_world_position(unit.global_position)
    var path = pathfinder.find_path(current_cell, target_cell)
    
    var path_cost = pathfinder.get_path_length(path)
    if path_cost <= movement_points:
        # Move unit along path
        animate_along_path(unit, path)
        movement_points -= path_cost
```

---

## ⚡ Performance Tips

```gdscript
# Cache frequently accessed cells
var player_cell: HexCell = grid.get_cell_at_world_position(player.position)

# Use signals to react to changes
grid.cell_enabled_changed.connect(_on_cell_changed)

func _on_cell_changed(cell: HexCell, enabled: bool):
    if enabled:
        # Cell became navigable
    else:
        # Cell became blocked
```

---

## 🔧 Troubleshooting

**Cells at wrong positions?**
```gdscript
# Check hex_size matches your sprite
hex_grid.hex_size = your_sprite_width / 2.0
```

**Debug not visible?**
```gdscript
# Ensure debug is enabled and in scene tree
hex_grid_debug.debug_enabled = true
hex_grid_debug.queue_redraw()
```

**Distance seems wrong?**
```gdscript
# Use hex distance, not euclidean
var hex_dist = cell_a.distance_to(cell_b)  # ✓ Correct
var euclidean = cell_a.world_position.distance_to(cell_b.world_position)  # ✗ Wrong for hex
```

---

## 🎯 Keyboard Shortcuts (Default)

- **F3**: Toggle debug visualization

Configure in SessionController:
```gdscript
session_controller.debug_hotkey_enabled = true
```

---

## 📞 Quick Function Reference

| Need to... | Use... |
|------------|--------|
| Get cell under mouse | `grid.get_cell_at_world_position(mouse_pos)` |
| Check if walkable | `cell.enabled` or `session.is_position_navigable(pos)` |
| Get distance | `cell_a.distance_to(cell_b)` |
| Find path | `pathfinder.find_path(start, goal)` |
| Get neighbors | `grid.get_enabled_neighbors(cell)` |
| Disable cell | `grid.set_cell_enabled(cell, false)` |
| Toggle debug | `session.toggle_debug_mode()` |
| Get cells in range | `grid.get_cells_in_range(cell, radius)` |

---

**Ready to build your tactical shooter! 🎮**
