# Hexagonal Navigation Grid - Quick Reference

## Overview

The Hexagonal Navigation Grid system provides a complete hexagonal grid-based navigation solution for Godot 4.x, featuring pathfinding, obstacle detection, and seamless integration with Godot's NavigationRegion2D.

![Navigation Example](screenshot-navigation.png)
![Hexagonal Grid](screenshot-hexgrid.png)

## Core Components

### HexCell
Individual hexagonal cell data structure.
- **Location**: [hex_cell.gd](../hex_cell.gd)
- Stores axial coordinates (q, r) and world position
- Manages enabled/disabled state for navigation
- Provides distance calculations and neighbor queries
- Supports custom metadata storage

### HexGrid
Main grid controller managing the hexagonal grid.
- **Location**: [hex_grid.gd](../hex_grid.gd)
- Creates and manages grid of HexCell instances
- Handles coordinate conversions (world ↔ axial)
- Supports flat-top and pointy-top layouts
- Optional isometric rendering support

### HexPathfinder
A* pathfinding implementation for hexagonal grids.
- **Location**: [hex_pathfinder.gd](../hex_pathfinder.gd)
- Find shortest path between cells
- Path-to-range calculations (approach within N cells)
- Movement range queries
- Pathfinding statistics for debugging

### HexGridDebug
Visual debugging overlay for the hex grid.
- **Location**: [hex_grid_debug.gd](../hex_grid_debug.gd)
- Toggle with F3 key
- Shows cell indices and coordinates
- Color-coded enabled/disabled cells
- Customizable colors and font size

### HexGridObstacleManager
Physics-based obstacle detection system.
- **Location**: [hex_grid_obstacle_manager.gd](../hex_grid_obstacle_manager.gd)
- Automatically detects physics bodies
- Disables cells blocked by obstacles
- Area scanning and real-time updates
- Static obstacle registration

### HexNavmeshIntegration
Integrates with Godot's NavigationRegion2D.
- **Location**: [HexGridNavmeshIntegration.gd](../HexGridNavmeshIntegration.gd)
- Syncs hex cells with navigation mesh
- Multi-point sampling per cell
- Automatic cell enable/disable based on navmesh
- Real-time navmesh updates

### SessionController
High-level orchestration and session management.
- **Location**: [session_controller.gd](../session_controller.gd)
- One-stop setup for complete hex navigation
- Manages grid lifecycle
- Coordinates all subsystems
- Provides unified API for gameplay

---

## Key Features

### 1. Grid Initialization

```gdscript
# Via SessionController (Recommended)
var session = SessionController.new()
session.grid_width = 20
session.grid_height = 15
session.hex_size = 32.0
session.initialize_session()

# Direct HexGrid setup
var grid = HexGrid.new()
grid.initialize_grid(20, 15)
```

### 2. Coordinate Systems

The system uses **axial coordinates** (q, r) for hex cells:

```gdscript
# World position to hex cell
var cell = hex_grid.get_cell_at_world_position(mouse_position)

# Hex coordinates to world position
var world_pos = hex_grid._axial_to_world(q, r)

# Get cell by coordinates
var cell = hex_grid.get_cell_at_coords(Vector2i(5, 3))
```

**Coordinate Directions (Flat-Top Layout):**
- East: (1, 0)
- Northeast: (1, -1)
- Northwest: (0, -1)
- West: (-1, 0)
- Southwest: (-1, 1)
- Southeast: (0, 1)

### 3. Pathfinding

```gdscript
# Basic pathfinding
var pathfinder = HexPathfinder.new()
pathfinder.hex_grid = hex_grid
var path = pathfinder.find_path(start_cell, goal_cell)

# Using world positions
var path = pathfinder.find_path_world(start_pos, goal_pos)

# Path to range (approach target)
var path = pathfinder.find_path_to_range(start_cell, goal_cell, 3)

# Check if path exists
var reachable = pathfinder.is_path_clear(start_cell, goal_cell)

# Get movement range
var reachable_cells = pathfinder.get_cells_in_movement_range(start_cell, 5)
```

### 4. Cell State Management

```gdscript
# Enable/disable individual cells
hex_grid.set_cell_enabled(cell, false)
hex_grid.set_cell_enabled_at_coords(Vector2i(5, 3), true)

# Area operations
hex_grid.disable_cells_in_area(world_pos, 2)  # radius of 2 cells
hex_grid.enable_cells_in_area(world_pos, 3)

# Query neighbors
var neighbors = hex_grid.get_neighbors(cell)
var enabled_neighbors = hex_grid.get_enabled_neighbors(cell)
```

### 5. Distance and Range Queries

```gdscript
# Distance between cells (in cell units / meters)
var distance = hex_grid.get_distance(cell_a, cell_b)
var distance = cell_a.distance_to(cell_b)  # Same result

# Distance from world positions
var distance = hex_grid.get_distance_world(pos_a, pos_b)

# Get cells in range
var cells = hex_grid.get_cells_in_range(center_cell, 5)
var enabled_cells = hex_grid.get_enabled_cells_in_range(center_cell, 5)
```

### 6. NavMesh Integration

```gdscript
# Setup (automatic via SessionController)
var integration = HexNavmeshIntegration.new()
integration.hex_grid = hex_grid
integration.navigation_region = navigation_region_2d
integration.sample_points_per_cell = 5  # Multi-point sampling
await integration.integrate_with_navmesh()

# Manual refresh
integration.refresh_integration()

# Update specific areas
integration.update_cells_in_area(center_pos, 5)
```

The integration:
- Samples each cell center against the navmesh
- Optionally samples multiple points per cell (default: 5)
- Disables cells not on the navmesh
- Updates in real-time as navmesh changes

### 7. Obstacle Detection

```gdscript
# Setup
var obstacle_mgr = HexGridObstacleManager.new()
obstacle_mgr.hex_grid = hex_grid
obstacle_mgr.collision_mask = 1  # Physics layer to check

# Scan all cells
obstacle_mgr.scan_all_cells()

# Scan specific area
obstacle_mgr.scan_area(center_pos, 5)

# Register static obstacles
obstacle_mgr.register_static_obstacle(obstacle_node, 2)
obstacle_mgr.unregister_static_obstacle(obstacle_node, 2)

# Check individual cell
var has_obstacle = obstacle_mgr.check_cell_for_obstacle(cell)
```

### 8. Visual Debugging

```gdscript
# Setup
var debug = HexGridDebug.new()
debug.hex_grid = hex_grid
debug.debug_enabled = true
debug.show_indices = true
debug.show_coordinates = true

# Toggle at runtime (F3 key by default)
debug.toggle_debug()

# Highlight specific cells
debug.highlight_cell(cell, Color.YELLOW)
debug.highlight_cells(path, Color.BLUE)
```

**Debug Display Options:**
- Cell indices
- Axial coordinates (q, r)
- Enabled/disabled cell outlines
- Custom colors for states
- Adjustable font size

### 9. Session Management

```gdscript
# Complete setup with SessionController
@export var session: SessionController

func _ready():
    # SessionController auto-initializes by default
    await session.session_started
    print("Hex grid ready!")

# Access subsystems
var hex_grid = session.get_terrain()
var cell = session.get_cell_at_position(world_pos)

# Utility methods
session.disable_terrain_at_position(pos, 2)
session.enable_terrain_at_position(pos, 2)
var navigable = session.is_position_navigable(pos)
var distance = session.get_distance_between_positions(pos_a, pos_b)
var cells = session.get_navigable_cells_in_range(center_pos, 5)

# Session lifecycle
session.end_session()
session.reset_session()

# Debug control
session.toggle_debug_mode()
```

---

## Configuration Reference

### HexGrid Configuration

```gdscript
@export var grid_width: int = 20              # Grid width in cells
@export var grid_height: int = 15             # Grid height in cells
@export var hex_size: float = 32.0            # Hex radius in pixels
@export var layout_flat_top: bool = true      # Flat-top vs pointy-top
@export var grid_offset: Vector2 = Vector2.ZERO

# Isometric settings
@export var use_isometric: bool = false
@export var iso_angle: float = 30.0
@export var sprite_vertical_offset: float = 0.0
```

### HexPathfinder Configuration

```gdscript
@export var hex_grid: HexGrid
@export var diagonal_cost: float = 1.0  # Cost per hex move
```

### HexGridDebug Configuration

```gdscript
@export var hex_grid: HexGrid
@export var debug_enabled: bool = false
@export var show_indices: bool = true
@export var show_coordinates: bool = true
@export var show_disabled_outlines: bool = false

@export var enabled_outline_color: Color = Color.GREEN
@export var disabled_outline_color: Color = Color.RED.darkened(0.3)
@export var outline_width: float = 2.0
@export var text_color: Color = Color.WHITE
@export var font_size: int = 12
```

### SessionController Configuration

```gdscript
# Grid Configuration
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var hex_size: float = 32.0
@export var auto_initialize: bool = true

# Navigation Integration
@export var navigation_region: NavigationRegion2D
@export var integrate_with_navmesh: bool = true
@export var navmesh_sample_points: int = 5

# Debug
@export var debug_mode: bool = false
@export var debug_hotkey_enabled: bool = true
```

---

## Common Workflows

### Workflow 1: Click-to-Move with Pathfinding

```gdscript
extends CharacterBody2D

@export var hex_grid: HexGrid
@export var pathfinder: HexPathfinder
var current_path: Array[HexCell] = []
var current_path_index: int = 0

func _input(event):
    if event is InputEventMouseButton and event.pressed:
        var start_cell = hex_grid.get_cell_at_world_position(global_position)
        var goal_cell = hex_grid.get_cell_at_world_position(event.position)

        current_path = pathfinder.find_path(start_cell, goal_cell)
        current_path_index = 0

func _physics_process(delta):
    if current_path_index < current_path.size():
        var target_cell = current_path[current_path_index]
        var direction = (target_cell.world_position - global_position).normalized()
        velocity = direction * 200.0
        move_and_slide()

        if global_position.distance_to(target_cell.world_position) < 5.0:
            current_path_index += 1
```

### Workflow 2: Dynamic Obstacle Updates

```gdscript
# When obstacle is added to scene
func _on_obstacle_spawned(obstacle: Node2D):
    obstacle_manager.register_static_obstacle(obstacle, 1)
    # Pathfinding will now avoid this area

# When obstacle is removed
func _on_obstacle_destroyed(obstacle: Node2D):
    obstacle_manager.unregister_static_obstacle(obstacle, 1)
    # Area becomes navigable again
```

### Workflow 3: Range-Based Abilities

```gdscript
# Show all cells in ability range
func show_ability_range(caster_pos: Vector2, ability_range: int):
    var caster_cell = hex_grid.get_cell_at_world_position(caster_pos)
    var cells_in_range = hex_grid.get_enabled_cells_in_range(caster_cell, ability_range)

    for cell in cells_in_range:
        highlight_cell(cell)

# Check if target is in range
func can_target(caster_pos: Vector2, target_pos: Vector2, max_range: int) -> bool:
    var distance = hex_grid.get_distance_world(caster_pos, target_pos)
    return distance <= max_range and distance > 0
```

### Workflow 4: Turn-Based Movement

```gdscript
var movement_points: int = 5

func show_movement_options(unit_pos: Vector2):
    var unit_cell = hex_grid.get_cell_at_world_position(unit_pos)
    var reachable = pathfinder.get_cells_in_movement_range(unit_cell, movement_points)

    for cell in reachable:
        highlight_cell(cell, Color.BLUE)

func move_unit(unit_pos: Vector2, target_pos: Vector2):
    var path = pathfinder.find_path_world(unit_pos, target_pos)
    var path_cost = pathfinder.get_path_length(path)

    if path_cost <= movement_points:
        execute_movement(path)
        movement_points -= path_cost
```

### Workflow 5: NavMesh + HexGrid Hybrid

```gdscript
# Best of both worlds: Use Godot's navmesh for pathfinding,
# hex grid for game logic (range, abilities, turn-based movement)

# Setup
var session = SessionController.new()
session.integrate_with_navmesh = true
session.navigation_region = $NavigationRegion2D
await session.session_started

# Pathfinding uses Godot's NavigationServer2D
# Game logic uses hex grid queries
var range_cells = session.get_navigable_cells_in_range(unit_pos, 5)
```

---

## Performance Tips

1. **Grid Size**: Keep grids under 30x30 for real-time pathfinding (900 cells)
2. **Obstacle Scanning**: Use `scan_area()` instead of `scan_all_cells()` when possible
3. **Pathfinding**: Cache paths and recalculate only when needed
4. **Debug Mode**: Disable in production (`debug_enabled = false`)
5. **NavMesh Sampling**: Reduce `sample_points_per_cell` for larger grids (1-3 points)
6. **Cell Updates**: Batch cell state changes before refreshing visuals

---

## Signals Reference

### HexGrid Signals
```gdscript
signal cell_enabled_changed(cell: HexCell, enabled: bool)
signal grid_initialized()
```

### HexPathfinder Signals
```gdscript
signal path_found(path: Array[HexCell])
signal path_failed(start: HexCell, goal: HexCell)
```

### HexGridObstacleManager Signals
```gdscript
signal obstacle_detected(world_pos: Vector2, cell: HexCell)
signal obstacle_removed(world_pos: Vector2, cell: HexCell)
```

### HexNavmeshIntegration Signals
```gdscript
signal integration_complete()
```

### SessionController Signals
```gdscript
signal session_started()
signal session_ended()
signal terrain_initialized()
```

---

## Troubleshooting

### Pathfinding returns empty array
- Check that start and goal cells are enabled
- Verify hex_grid is assigned to pathfinder
- Ensure there's a valid path (no obstacles blocking)

### Cells not aligning with navmesh
- Increase `sample_points_per_cell` (default: 5)
- Verify `grid_offset` matches NavigationRegion2D position
- Check that navmesh is fully baked

### Debug overlay not showing
- Press F3 to toggle
- Set `debug_enabled = true`
- Ensure HexGridDebug is child of a Node2D in scene tree

### Click detection offset in isometric view
- Set `sprite_vertical_offset` to compensate for sprite height
- Enable `click_isometric_correction` if needed
- Adjust `grid_offset` to match your art

### Obstacle detection not working
- Verify `collision_mask` matches your physics layers
- Check that obstacles have CollisionShape2D
- Ensure space_state is initialized (wait 1 frame after ready)

---

## API Quick Lookup

### Most Used Methods

| Method | Class | Description |
|--------|-------|-------------|
| `get_cell_at_world_position(pos)` | HexGrid | World pos → HexCell |
| `find_path(start, goal)` | HexPathfinder | A* pathfinding |
| `get_distance(cell_a, cell_b)` | HexGrid | Distance in cells |
| `get_cells_in_range(center, radius)` | HexGrid | All cells in radius |
| `set_cell_enabled(cell, enabled)` | HexGrid | Enable/disable cell |
| `get_neighbors(cell)` | HexGrid | Adjacent cells |
| `scan_all_cells()` | ObstacleManager | Detect obstacles |
| `integrate_with_navmesh()` | NavmeshIntegration | Sync with navmesh |
| `toggle_debug_mode()` | SessionController | Show/hide debug |

---

## Version & Compatibility

- **Godot Version**: 4.x
- **Language**: GDScript
- **Architecture**: Node-based, modular
- **Dependencies**: None (pure GDScript)
- **Optional**: NavigationRegion2D for navmesh integration

---

## Credits & License

This hexagonal navigation system is built for the Robots-Zombies-Ghosts project.

For more details, see the individual script files in the [Controller](../) directory.
