# Hexagonal Navigation - Visual Guide

This guide uses visual examples to explain how the hexagonal navigation system works.

---

## Navigation Mesh Integration

![NavMesh Integration](screenshot-navigation.png)

The first screenshot shows the **NavigationRegion2D integration** in action:

### What You're Seeing:
- **Teal/Cyan overlay**: The NavigationRegion2D mesh
- **Blue path lines**: Pathfinding visualization showing a calculated path
- **Character sprite**: Unit navigating along the path
- **3D isometric environment**: Your game world with obstacles (walls, barrels)

### How It Works:
1. The `HexNavmeshIntegration` samples the NavigationRegion2D
2. Each hex cell is tested to see if it overlaps with the navmesh
3. Cells OFF the navmesh are automatically disabled
4. Pathfinding only considers enabled cells
5. Result: Characters navigate around obstacles seamlessly

### Key Features Shown:
- Navmesh-aware pathfinding
- Obstacle avoidance (walls block navigation)
- Smooth integration with Godot's navigation system
- Visual feedback of valid navigation area

---

## Hexagonal Grid Overlay

![Hexagonal Grid](screenshot-hexgrid.png)

The second screenshot shows the **debug visualization** of the hex grid:

### What You're Seeing:
- **Green hexagonal outlines**: Individual hex cells
- **White numbers**: Cell indices (top) and coordinates (bottom)
- **Coordinate format**: "Index" above "(q,r)" axial coordinates
- **Blue highlighted path**: A pathfinding result visualized on the grid

### Understanding the Grid:

#### Cell Numbering
Each cell has two identification systems:
1. **Index** (top number): Sequential array index (0, 1, 2, 3...)
2. **Coordinates** (bottom): Axial coordinates in (q, r) format

Example from screenshot:
- Cell **260** is at position **(5,6)**
- Cell **406** is at position **(6,11)**
- Cell **456** is at position **(7,12)**

#### Coordinate System (Flat-Top Layout)
The grid uses **axial coordinates**:
- **q**: Column (increases to the right)
- **r**: Row (increases downward-right)

#### Path Visualization
The blue highlighted cells show a calculated path:
- Start: Character position (cell 405)
- Goal: Target position (cell 260)
- Path: Shortest route through enabled cells
- Each step: One adjacent hex cell

### Debug Features Shown:
- Cell indices for quick reference
- Axial coordinates for calculations
- Path highlighting
- Grid structure visualization

---

## Triangulated Navigation Mesh

![Triangulated Mesh](screenshot-triangulated.png)

The third screenshot shows the **triangulated navigation mesh** structure:

### What You're Seeing:
- **Blue triangles**: Godot's NavigationPolygon mesh
- **Orange/red areas**: Areas outside the navigation mesh (non-walkable)
- **Character and barrels**: Game objects

### Integration Process:

```gdscript
# 1. Godot generates the triangulated navmesh
NavigationRegion2D → NavigationPolygon

# 2. HexNavmeshIntegration samples each hex cell
for each hex_cell in grid:
    if cell_center on navmesh:
        enable(hex_cell)
    else:
        disable(hex_cell)

# 3. Result: Hex grid matches navigable area
```

### Why This Matters:
- **Blue areas**: Cells are enabled for navigation
- **Orange areas**: Cells are disabled (obstacles, out of bounds)
- **Hex pathfinding**: Respects the same boundaries as Godot's navmesh
- **Best of both**: Use navmesh for navigation, hex grid for game logic

---

## Practical Examples

### Example 1: Click-to-Move

![Click to Move](screenshot-navigation.png)

When the player clicks on the game world:

```gdscript
func _on_click(world_pos: Vector2):
    # 1. Get current position
    var start_cell = hex_grid.get_cell_at_world_position(player.position)

    # 2. Get clicked position
    var goal_cell = hex_grid.get_cell_at_world_position(world_pos)

    # 3. Find path
    var path = pathfinder.find_path(start_cell, goal_cell)

    # 4. Visualize (shown as blue line in screenshot)
    debug.highlight_cells(path, Color.BLUE)

    # 5. Move along path
    move_along_path(path)
```

**Result**: Character moves from their current cell to the clicked cell, avoiding obstacles.

### Example 2: Range Indicator

![Range Visualization](screenshot-hexgrid.png)

Show all cells within ability range:

```gdscript
func show_ability_range(caster_pos: Vector2, range: int):
    var center = hex_grid.get_cell_at_world_position(caster_pos)
    var cells = hex_grid.get_enabled_cells_in_range(center, range)

    for cell in cells:
        # Highlight cells in green
        debug.highlight_cell(cell, Color.GREEN)
```

**Visualization**: All cells within `range` hexes are highlighted, showing valid targets.

### Example 3: Turn-Based Movement

Show where a unit can move with limited movement points:

```gdscript
func show_movement_options(unit_pos: Vector2, movement_points: int):
    var unit_cell = hex_grid.get_cell_at_world_position(unit_pos)

    # Get all cells reachable within movement budget
    var reachable = pathfinder.get_cells_in_movement_range(unit_cell, movement_points)

    # Highlight each cell with movement cost
    for cell in reachable:
        var path = pathfinder.find_path(unit_cell, cell)
        var cost = pathfinder.get_path_length(path)

        # Color by cost: blue=close, red=far
        var color = Color.BLUE.lerp(Color.RED, cost / float(movement_points))
        debug.highlight_cell(cell, color)
```

**Result**: Visual indicator of where the unit can move this turn.

---

## Understanding Cell States

### Enabled Cells (Green Outlines)

![Enabled Cells](screenshot-hexgrid.png)

**Enabled** cells are navigable:
- Characters can move through them
- Pathfinding includes them
- Shown with green outlines in debug mode

### Disabled Cells (Red Outlines)

When `show_disabled_outlines = true`, disabled cells show in red:
- Obstacles blocking the cell
- Outside the navigation mesh
- Manually disabled by game logic
- Pathfinding ignores them

### Cell State Management

```gdscript
# Disable cells (obstacles)
hex_grid.set_cell_enabled(cell, false)

# Enable cells (clear area)
hex_grid.set_cell_enabled(cell, true)

# Disable area (explosion, etc.)
hex_grid.disable_cells_in_area(explosion_pos, 3)

# Enable area (obstacle removed)
hex_grid.enable_cells_in_area(position, 2)
```

---

## Pathfinding Visualization

### Understanding Path Display

In the screenshots, paths are shown as:
1. **Blue lines**: Connecting cell centers
2. **Highlighted cells**: Cells along the path
3. **Start → Goal**: Follows enabled cells only

### Path Properties

```gdscript
var path = pathfinder.find_path(start, goal)

# Path is Array[HexCell]
print(path.size())  # Number of cells in path

# Path includes start and goal
path[0] == start_cell  # true
path[-1] == goal_cell  # true

# Each cell is adjacent to the next
for i in range(path.size() - 1):
    var current = path[i]
    var next = path[i + 1]
    var distance = current.distance_to(next)
    assert(distance == 1)  # Always 1 (adjacent)
```

### Path Cost Calculation

Each hex move has a cost (default: 1.0):

```gdscript
# Path length (not counting start)
var moves = pathfinder.get_path_length(path)

# Example: 8-cell path = 7 moves
# [start, cell1, cell2, cell3, cell4, cell5, cell6, goal]
#   ^                                               ^
#  start                                          goal
#  └─────────────── 7 moves ────────────────────┘
```

---

## Debug Mode Controls

### Toggling Debug Display

**Default Hotkey**: F3

Press F3 to toggle the hex grid overlay shown in the screenshots.

### What Debug Mode Shows

```gdscript
# Configure what's displayed
debug.show_indices = true       # Cell array index (260, 405, etc.)
debug.show_coordinates = true   # Axial coords (5,6), (7,12), etc.
debug.show_disabled_outlines = false  # Hide disabled cells (cleaner)

# Visual styling
debug.enabled_outline_color = Color.GREEN  # Active cells
debug.disabled_outline_color = Color.RED   # Blocked cells
debug.outline_width = 2.0                  # Line thickness
debug.text_color = Color.WHITE             # Number color
debug.font_size = 12                       # Text size
```

### Production vs Debug

**Development** (screenshot 2):
- Debug enabled
- Shows all cell info
- Useful for level design
- Performance impact minimal

**Production** (screenshot 1):
- Debug disabled
- Clean visual
- Best performance
- Only show path when needed

---

## Integration Workflow

### Step 1: Setup Navigation Mesh
![Step 1](screenshot-triangulated.png)

1. Create a `NavigationRegion2D` node
2. Draw navigation polygon around walkable area
3. Bake the navigation mesh

### Step 2: Add Hex Grid
![Step 2](screenshot-hexgrid.png)

1. Add `SessionController` to scene
2. Link `navigation_region` export
3. Configure grid size and hex size
4. Enable debug mode for visualization

### Step 3: Test Navigation
![Step 3](screenshot-navigation.png)

1. Run the scene
2. Grid automatically integrates with navmesh
3. Test pathfinding
4. Adjust cell size or sampling if needed

---

## Visual Debugging Checklist

### Grid Alignment Issues

If cells don't align with your art:
- Adjust `hex_size` to match tile size
- Set `grid_offset` to match world origin
- For isometric: configure `sprite_vertical_offset`

### Navmesh Integration Issues

If cells are enabled/disabled incorrectly:
- Increase `sample_points_per_cell` (default: 5)
- Check `grid_offset` matches NavigationRegion2D position
- Verify navmesh is fully baked
- Enable debug mode to visualize cell states

### Pathfinding Issues

If paths are incorrect:
- Enable debug mode (F3)
- Verify start/goal cells are enabled (green outline)
- Check for unexpected disabled cells blocking the path
- Use `is_path_clear()` to test connectivity

---

## Common Visual Patterns

### Pattern 1: Radius Circle

Cells in range form a "hex circle":
```
     *
   * * *
  * * O * *
   * * *
     *
```
- O = center
- * = cells in range

### Pattern 2: Pathfinding

Paths follow hex adjacency:
```
S→→→→↘
    ↓
    ↓
    G
```
- S = start
- G = goal
- Arrows = path direction

### Pattern 3: Line of Sight

Diagonal lines through hex centers:
```
  A
   ╲
    ╲
     ╲
      B
```
- Check each hex along the line
- Stop if disabled cell encountered

---

## Screenshot Reference

### Screenshot 1: Navigation in Action
![Navigation](screenshot-navigation.png)
- Shows runtime pathfinding
- NavMesh integration active
- 3D isometric view

### Screenshot 2: Debug Overlay
![Debug](screenshot-hexgrid.png)
- Shows hex grid structure
- Cell numbering visible
- Path highlighted

### Screenshot 3: NavMesh Structure
![NavMesh](screenshot-triangulated.png)
- Shows underlying navigation polygon
- Illustrates walkable area
- Foundation for hex integration

---

## Tips for Best Results

1. **Match Grid to Art**: Set `hex_size` to match your tile dimensions
2. **Center Alignment**: Adjust `grid_offset` so cells align with tiles
3. **Visual Feedback**: Use debug mode during development
4. **Performance**: Disable debug in production builds
5. **Testing**: Use screenshots to document your grid layout
6. **Integration**: Let navmesh define walkable area, use hex for game logic

---

For detailed API documentation, see [HEXGRID_QUICK_REFERENCE.md](HEXGRID_QUICK_REFERENCE.md)
