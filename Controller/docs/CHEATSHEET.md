# Hexagonal Navigation - Cheat Sheet

Quick reference for common operations. For full documentation, see [README.md](README.md).

---

## Quick Setup

```gdscript
# Add SessionController to scene
@onready var session = $SessionController

func _ready():
    await session.session_started
    # Grid is ready!
```

**Press F3** to toggle debug overlay.

---

## Getting Cells

```gdscript
# From world position (mouse click, etc.)
var cell = hex_grid.get_cell_at_world_position(position)

# From coordinates
var cell = hex_grid.get_cell_at_coords(Vector2i(q, r))

# From index
var cell = hex_grid.get_cell_at_index(42)
```

---

## Pathfinding

```gdscript
# Basic pathfinding
var path = pathfinder.find_path(start_cell, goal_cell)

# Using world positions
var path = pathfinder.find_path_world(start_pos, goal_pos)

# Path to range (approach within N cells)
var path = pathfinder.find_path_to_range(start, goal, 3)

# Check if path exists
var reachable = pathfinder.is_path_clear(start, goal)
```

---

## Distance & Range

```gdscript
# Distance between cells
var dist = hex_grid.get_distance(cell_a, cell_b)
var dist = cell_a.distance_to(cell_b)  # Same thing

# Distance from positions
var dist = hex_grid.get_distance_world(pos_a, pos_b)

# All cells in range
var cells = hex_grid.get_cells_in_range(center, radius)

# Only enabled cells
var cells = hex_grid.get_enabled_cells_in_range(center, radius)

# Movement range (considers costs)
var reachable = pathfinder.get_cells_in_movement_range(start, 5)
```

---

## Neighbors

```gdscript
# All neighbors
var neighbors = hex_grid.get_neighbors(cell)

# Only enabled neighbors
var neighbors = hex_grid.get_enabled_neighbors(cell)

# Neighbor directions (flat-top)
# East: (1, 0)
# Northeast: (1, -1)
# Northwest: (0, -1)
# West: (-1, 0)
# Southwest: (-1, 1)
# Southeast: (0, 1)
```

---

## Cell State

```gdscript
# Enable/disable individual cell
hex_grid.set_cell_enabled(cell, false)
hex_grid.set_cell_enabled_at_coords(Vector2i(5, 3), true)

# Area operations
hex_grid.disable_cells_in_area(world_pos, 2)  # radius
hex_grid.enable_cells_in_area(world_pos, 3)

# Check if enabled
if cell.enabled:
    # Can navigate here
```

---

## Coordinates

```gdscript
# Cell to world
var world_pos = cell.world_position

# World to cell
var cell = hex_grid.get_cell_at_world_position(world_pos)

# Cell coordinates
var coords = cell.get_axial_coords()  # Vector2i(q, r)
var q = cell.q
var r = cell.r
```

---

## SessionController Helpers

```gdscript
# Quick accessors
var grid = session.get_terrain()
var cell = session.get_cell_at_position(world_pos)

# Utilities
session.disable_terrain_at_position(pos, 2)
session.enable_terrain_at_position(pos, 2)
var navigable = session.is_position_navigable(pos)
var distance = session.get_distance_between_positions(pos_a, pos_b)
var cells = session.get_navigable_cells_in_range(center, 5)

# Lifecycle
session.end_session()
session.reset_session()

# Debug
session.toggle_debug_mode()
```

---

## Metadata (Custom Data)

```gdscript
# Store custom data on cells
cell.set_metadata("terrain", "forest")
cell.set_metadata("building", building_node)
cell.set_metadata("cost", 2.5)

# Retrieve data
var terrain = cell.get_metadata("terrain", "normal")
var building = cell.get_metadata("building")
```

---

## Obstacle Detection

```gdscript
# Setup
var obstacle_mgr = HexGridObstacleManager.new()
obstacle_mgr.hex_grid = hex_grid
obstacle_mgr.collision_mask = 1

# Scan all
obstacle_mgr.scan_all_cells()

# Scan area
obstacle_mgr.scan_area(center_pos, 5)

# Register static obstacle
obstacle_mgr.register_static_obstacle(obstacle_node, 1)
obstacle_mgr.unregister_static_obstacle(obstacle_node, 1)
```

---

## NavMesh Integration

```gdscript
# Setup (via SessionController)
session.integrate_with_navmesh = true
session.navigation_region = $NavigationRegion2D
session.navmesh_sample_points = 5

# Manual refresh
navmesh_integration.refresh_integration()

# Update area
navmesh_integration.update_cells_in_area(center_pos, 5)
```

---

## Debug Visualization

```gdscript
# Toggle (F3 key by default)
debug.toggle_debug()

# Configure
debug.show_indices = true
debug.show_coordinates = true
debug.show_disabled_outlines = false

# Colors
debug.enabled_outline_color = Color.GREEN
debug.disabled_outline_color = Color.RED
debug.text_color = Color.WHITE

# Highlight cells
debug.highlight_cell(cell, Color.YELLOW)
debug.highlight_cells(path, Color.BLUE)
```

---

## Common Patterns

### Click-to-Move
```gdscript
func _input(event):
    if event is InputEventMouseButton and event.pressed:
        var start = hex_grid.get_cell_at_world_position(player.position)
        var goal = hex_grid.get_cell_at_world_position(event.position)
        current_path = pathfinder.find_path(start, goal)
```

### Show Movement Range
```gdscript
func show_range(unit_pos: Vector2, movement: int):
    var cell = hex_grid.get_cell_at_world_position(unit_pos)
    var reachable = pathfinder.get_cells_in_movement_range(cell, movement)
    for c in reachable:
        highlight_cell(c)
```

### Ability Range Check
```gdscript
func can_target(caster_pos: Vector2, target_pos: Vector2, max_range: int) -> bool:
    var dist = hex_grid.get_distance_world(caster_pos, target_pos)
    return dist <= max_range and dist > 0
```

### Area of Effect
```gdscript
func apply_aoe(center_pos: Vector2, radius: int):
    var center = hex_grid.get_cell_at_world_position(center_pos)
    var affected = hex_grid.get_cells_in_range(center, radius)
    for cell in affected:
        apply_damage(cell)
```

---

## Signals

```gdscript
# HexGrid
grid_initialized
cell_enabled_changed(cell, enabled)

# HexPathfinder
path_found(path)
path_failed(start, goal)

# SessionController
session_started
session_ended
terrain_initialized

# HexNavmeshIntegration
integration_complete

# HexGridObstacleManager
obstacle_detected(world_pos, cell)
obstacle_removed(world_pos, cell)
```

---

## Stats & Diagnostics

```gdscript
# Grid stats
var stats = hex_grid.get_grid_stats()
# Returns:
# {
#   total_cells: int,
#   enabled_cells: int,
#   disabled_cells: int,
#   grid_dimensions: Vector2i,
#   hex_size: float,
#   isometric: bool
# }

# Pathfinding stats
var pf_stats = pathfinder.get_pathfinding_stats()
# Returns:
# {
#   open_set_size: int,
#   closed_set_size: int,
#   nodes_evaluated: int,
#   path_stored: bool
# }
```

---

## Configuration

### HexGrid
```gdscript
grid_width: int = 20
grid_height: int = 15
hex_size: float = 32.0
layout_flat_top: bool = true
grid_offset: Vector2 = Vector2.ZERO
```

### SessionController
```gdscript
# Grid
grid_width: int = 20
grid_height: int = 15
hex_size: float = 32.0

# NavMesh
navigation_region: NavigationRegion2D
integrate_with_navmesh: bool = true
navmesh_sample_points: int = 5

# Debug
debug_mode: bool = false
debug_hotkey_enabled: bool = true
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Grid not showing | Press F3 |
| Pathfinding returns [] | Check cells are enabled |
| Cells wrong size | Adjust hex_size |
| NavMesh mismatch | Increase navmesh_sample_points |
| Click offset | Adjust grid_offset |

---

## Key Shortcuts

- **F3**: Toggle debug overlay
- **Ctrl+F**: Find in docs
- **Ctrl+Click**: Go to definition (IDE)

---

**Full docs**: [README.md](README.md) | **Setup**: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) | **API**: [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)
