# Hexagonal Navigation System Documentation

Complete documentation for the hexagonal grid-based navigation system for Godot 4.x.

---

## Overview

This system provides a **complete hexagonal grid navigation solution** with:
- ✅ Hexagonal grid management (flat-top and pointy-top)
- ✅ A* pathfinding optimized for hex grids
- ✅ Integration with Godot's NavigationRegion2D
- ✅ Physics-based obstacle detection
- ✅ Visual debugging tools
- ✅ Turn-based and real-time movement support
- ✅ Range and area-of-effect calculations
- ✅ Session management and orchestration

**Perfect for:**
- Turn-based strategy games
- Tactical RPGs
- Board game adaptations
- Tile-based action games
- Any game requiring hex-based movement/combat

---

## Quick Start

**1. Add SessionController to your scene:**
```gdscript
# Attach session_controller.gd to a Node in your scene
@onready var session = $SessionController

func _ready():
    await session.session_started
    print("Hex navigation ready!")
```

**2. Configure in Inspector:**
- Grid Width: 20
- Grid Height: 15
- Hex Size: 32.0
- Debug Mode: true (for development)

**3. Press F3 to toggle debug overlay**

**That's it!** See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for details.

---

## Documentation Structure

### 📘 [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
**Start here if you're new to the system**
- Step-by-step setup instructions
- Scene templates
- Common integration scenarios
- Troubleshooting guide
- Performance optimization tips

### 📗 [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)
**Complete API reference and feature documentation**
- All classes and methods
- Configuration options
- Code examples for every feature
- Signals reference
- Common workflows
- Performance tips

### 📕 [VISUAL_GUIDE.md](VISUAL_GUIDE.md)
**Visual examples and patterns**
- Screenshot analysis
- Debug visualization explained
- Visual debugging tips
- Common visual patterns
- NavMesh integration visuals

---

## System Components

### Core Classes

| Class | File | Purpose |
|-------|------|---------|
| **HexCell** | [hex_cell.gd](../hex_cell.gd) | Individual hex cell data structure |
| **HexGrid** | [hex_grid.gd](../hex_grid.gd) | Grid management and coordinate conversion |
| **HexPathfinder** | [hex_pathfinder.gd](../hex_pathfinder.gd) | A* pathfinding for hex grids |
| **HexGridDebug** | [hex_grid_debug.gd](../hex_grid_debug.gd) | Visual debugging overlay |
| **HexGridObstacleManager** | [hex_grid_obstacle_manager.gd](../hex_grid_obstacle_manager.gd) | Physics-based obstacle detection |
| **HexNavmeshIntegration** | [HexGridNavmeshIntegration.gd](../HexGridNavmeshIntegration.gd) | NavMesh synchronization |
| **SessionController** | [session_controller.gd](../session_controller.gd) | High-level orchestration |

### Class Relationships

```
SessionController (orchestrates everything)
├── HexGrid (manages cells)
│   └── HexCell (individual cells)
├── HexPathfinder (uses grid for pathfinding)
├── HexGridDebug (visualizes grid)
├── HexNavmeshIntegration (syncs with Godot's navigation)
└── HexGridObstacleManager (optional - physics detection)
```

---

## Key Features

### Pathfinding
```gdscript
# Find shortest path
var path = pathfinder.find_path(start_cell, goal_cell)

# Path to range (get within N cells)
var path = pathfinder.find_path_to_range(start_cell, goal_cell, 3)

# Movement range
var reachable = pathfinder.get_cells_in_movement_range(start_cell, 5)
```

### Grid Queries
```gdscript
# Get cell from world position
var cell = hex_grid.get_cell_at_world_position(mouse_pos)

# Get distance
var distance = hex_grid.get_distance(cell_a, cell_b)

# Get cells in range
var cells = hex_grid.get_cells_in_range(center_cell, 3)

# Get neighbors
var neighbors = hex_grid.get_neighbors(cell)
```

### Cell Management
```gdscript
# Enable/disable cells
hex_grid.set_cell_enabled(cell, false)

# Area operations
hex_grid.disable_cells_in_area(world_pos, 2)
hex_grid.enable_cells_in_area(world_pos, 3)
```

### NavMesh Integration
```gdscript
# Automatic (via SessionController)
session.integrate_with_navmesh = true
session.navigation_region = $NavigationRegion2D

# Cells automatically sync with navmesh
# Disabled cells = off navmesh
# Enabled cells = on navmesh
```

### Debugging
```gdscript
# Toggle debug overlay (F3 key)
session.toggle_debug_mode()

# Shows:
# - Cell indices
# - Axial coordinates
# - Enabled/disabled state
# - Grid structure
```

---

## Visual Examples

![Navigation Mesh Integration](screenshot-navigation.png)
*NavMesh integration with pathfinding visualization*

![Hexagonal Grid Overlay](screenshot-hexgrid.png)
*Debug overlay showing cell indices and coordinates*

![Triangulated Navigation Mesh](screenshot-triangulated.png)
*Underlying navigation polygon structure*

See [VISUAL_GUIDE.md](VISUAL_GUIDE.md) for detailed analysis of these screenshots.

---

## Common Use Cases

### Turn-Based Strategy
```gdscript
# Show movement range
var reachable = pathfinder.get_cells_in_movement_range(unit_cell, movement_points)
for cell in reachable:
    highlight_cell(cell)

# Move unit
var path = pathfinder.find_path(unit_cell, target_cell)
var cost = pathfinder.get_path_length(path)
if cost <= movement_points:
    execute_movement(path)
```

### Real-Time Navigation
```gdscript
# Enemy AI pathfinding
func _physics_process(delta):
    if should_update_path:
        current_path = pathfinder.find_path_world(global_position, target.position)
    follow_path(delta)
```

### Ability Range
```gdscript
# Show spell range
var caster_cell = hex_grid.get_cell_at_world_position(caster.position)
var targets = hex_grid.get_enabled_cells_in_range(caster_cell, spell_range)
for cell in targets:
    highlight_cell(cell, Color.RED)
```

### Area of Effect
```gdscript
# Apply damage in radius
func apply_explosion(center_pos: Vector2, radius: int):
    var center_cell = hex_grid.get_cell_at_world_position(center_pos)
    var affected = hex_grid.get_cells_in_range(center_cell, radius)
    for cell in affected:
        apply_damage_at(cell.world_position)
```

---

## Architecture Overview

### Data Flow

```
User Input (mouse click)
    ↓
SessionController
    ↓
HexGrid.get_cell_at_world_position()
    ↓
HexPathfinder.find_path()
    ↓
Path (Array[HexCell])
    ↓
Character Movement
```

### Coordinate Systems

The system uses **axial coordinates** internally:
- **Axial (q, r)**: Primary coordinate system
- **Cube (x, y, z)**: Used for distance calculations
- **World (pixels)**: For rendering and input

**Conversions:**
```gdscript
# World → Axial
var coords = hex_grid.world_position_to_axial(mouse_pos)

# Axial → World
var world_pos = hex_grid._axial_to_world(q, r)

# Axial → Cube (internal)
var cube = cell.get_cube_coords()
```

### Navigation Integration

```
Godot NavigationRegion2D
    ↓
HexNavmeshIntegration samples each cell
    ↓
Cells ON navmesh = enabled
Cells OFF navmesh = disabled
    ↓
Pathfinding respects enabled/disabled state
    ↓
Result: Hex pathfinding matches Godot navigation
```

---

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Grid Creation | O(w × h) | One-time at initialization |
| Get Cell by World Pos | O(1) | Fast hash lookup |
| Get Neighbors | O(1) | 6 neighbors max |
| Distance Calculation | O(1) | Simple formula |
| A* Pathfinding | O(n log n) | Typical for A* |
| Range Query | O(total cells) | Brute force scan |
| NavMesh Integration | O(cells × samples) | One-time or on demand |

**Recommendations:**
- Keep grids under 30×30 (900 cells) for real-time pathfinding
- Cache frequently-used paths
- Use range queries sparingly or cache results
- Disable debug mode in production

---

## Configuration Presets

### Small Tactical Game
```gdscript
grid_width = 15
grid_height = 12
hex_size = 48.0
integrate_with_navmesh = false
```

### Large Strategy Map
```gdscript
grid_width = 40
grid_height = 30
hex_size = 24.0
navmesh_sample_points = 3  # Reduced for performance
```

### Turn-Based RPG Battle
```gdscript
grid_width = 10
grid_height = 8
hex_size = 64.0
integrate_with_navmesh = true
debug_mode = true  # Show grid during combat
```

### Real-Time Action Game
```gdscript
grid_width = 25
grid_height = 20
hex_size = 32.0
integrate_with_navmesh = true
navmesh_sample_points = 5
debug_mode = false  # Hide grid in production
```

---

## API Quick Lookup

### Most Used Methods

| Method | Class | Returns |
|--------|-------|---------|
| `get_cell_at_world_position(pos)` | HexGrid | HexCell |
| `find_path(start, goal)` | HexPathfinder | Array[HexCell] |
| `get_distance(a, b)` | HexGrid | int |
| `get_cells_in_range(center, radius)` | HexGrid | Array |
| `set_cell_enabled(cell, enabled)` | HexGrid | void |
| `get_neighbors(cell)` | HexGrid | Array |
| `get_cells_in_movement_range(start, mp)` | HexPathfinder | Array[HexCell] |

### Most Used Signals

| Signal | Emitter | Parameters |
|--------|---------|------------|
| `session_started` | SessionController | none |
| `grid_initialized` | HexGrid | none |
| `path_found` | HexPathfinder | Array[HexCell] |
| `cell_enabled_changed` | HexGrid | HexCell, bool |
| `integration_complete` | NavmeshIntegration | none |

---

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| Grid not visible | Press F3, check `debug_enabled = true` |
| Cells wrong size | Adjust `hex_size` to match your art |
| Pathfinding fails | Check cells are enabled (F3 overlay) |
| NavMesh mismatch | Increase `navmesh_sample_points` |
| Click offset | Adjust `grid_offset` or `sprite_vertical_offset` |
| Performance issues | Reduce grid size, disable debug, cache paths |

See [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for detailed troubleshooting.

---

## Advanced Topics

### Custom Terrain Costs
```gdscript
# Extend HexCell with terrain type
cell.set_metadata("terrain", "forest")

# Modify pathfinder movement cost
func _movement_cost(from: HexCell, to: HexCell) -> float:
    var terrain = to.get_metadata("terrain", "normal")
    match terrain:
        "forest": return 2.0
        "water": return 3.0
        _: return 1.0
```

### Line of Sight
```gdscript
func has_line_of_sight(from: HexCell, to: HexCell) -> bool:
    var path = pathfinder.find_path(from, to)
    for cell in path:
        if cell.get_metadata("blocks_los", false):
            return false
    return true
```

### Fog of War
```gdscript
func update_visibility(viewer_pos: Vector2, vision_range: int):
    # Reset all cells to hidden
    for cell in hex_grid.cells:
        cell.set_metadata("visible", false)

    # Mark visible cells
    var viewer_cell = hex_grid.get_cell_at_world_position(viewer_pos)
    var visible_cells = hex_grid.get_cells_in_range(viewer_cell, vision_range)
    for cell in visible_cells:
        if has_line_of_sight(viewer_cell, cell):
            cell.set_metadata("visible", true)
```

---

## Version Information

- **Godot Version**: 4.x (tested on 4.2+)
- **Language**: GDScript
- **Dependencies**: None (pure GDScript)
- **Optional**: NavigationRegion2D for navmesh integration
- **License**: Project-specific

---

## Documentation Index

- **[README.md](README.md)** ← You are here
- **[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)** - Setup and integration
- **[HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)** - Complete API reference
- **[VISUAL_GUIDE.md](VISUAL_GUIDE.md)** - Visual examples and patterns

---

## Getting Help

1. **Read the docs**: Start with [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
2. **Check examples**: See [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)
3. **Enable debug**: Press F3 to visualize the grid
4. **Check stats**: Use `get_grid_stats()` to inspect state

---

## Contributing

When extending this system:
1. Follow the existing code style
2. Add doc comments to new methods
3. Update this documentation
4. Test with debug mode enabled
5. Consider performance implications

---

**Ready to get started?** → [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)

**Need API details?** → [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)

**Want visual examples?** → [VISUAL_GUIDE.md](VISUAL_GUIDE.md)
