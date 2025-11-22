# Visual Guide: Expected Hex Grid Behavior

## What You Should See

### ✅ CORRECT Behavior (After Integration)

```
Your Scene with NavigationRegion2D and Obstacles:

    ╔════════════════════════════════════╗
    ║  Navigation Region Boundary        ║
    ║                                    ║
    ║    ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡          ║
    ║   ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡         ║
    ║  ⬡ ⬡ ⬡ [BARREL]   ⬡ ⬡ ⬡        ║  ← No hexagons near barrel!
    ║   ⬡ ⬡ ⬡   ⬡   ⬡ ⬡ ⬡ ⬡ ⬡        ║
    ║  ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡        ║
    ║   ⬡ ⬡ ⬡ ⬡ [WALL] ⬡ ⬡ ⬡         ║  ← No hexagons near wall!
    ║  ⬡ ⬡ ⬡ ⬡    ⬡ ⬡ ⬡ ⬡ ⬡          ║
    ║   ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡           ║
    ║                                    ║
    ╚════════════════════════════════════╝

Legend:
⬡ = Green hexagon (enabled, navigable)
[BARREL] = Static obstacle (hexagons disabled around it)
[WALL] = Static obstacle (hexagons disabled around it)
```

**Key Points:**
1. ✅ Hexagons ONLY appear in navigable space
2. ✅ NO hexagons near obstacles (barrels, walls)
3. ✅ NO hexagons outside NavigationRegion2D
4. ✅ Green outlines for enabled cells
5. ✅ Cell indices and coordinates shown

---

### ❌ INCORRECT Behavior (Without Integration)

```
Scene WITHOUT Navmesh Integration:

    ╔════════════════════════════════════╗
    ║  Navigation Region Boundary        ║
    ║                                    ║
    ║    ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡          ║
    ║   ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡         ║
    ║  ⬡ ⬡ ⬡ [BARREL] ⬡ ⬡ ⬡ ⬡        ║  ← ❌ Hexagons overlap barrel!
    ║   ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡         ║
    ║  ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡        ║
    ║   ⬡ ⬡ ⬡ ⬡ [WALL] ⬡ ⬡ ⬡ ⬡       ║  ← ❌ Hexagons overlap wall!
    ║  ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡        ║
    ║   ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡         ║
    ║                                    ║
    ╚════════════════════════════════════╝
  ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡         ← ❌ Hexagons outside navmesh!

Problems:
1. ❌ Hexagons everywhere (ignores obstacles)
2. ❌ Hexagons outside navigation region
3. ❌ Agents could pathfind through walls
```

---

## Debug Mode Visualization

### When Debug Mode is ON (F3)

You should see:

```
Debug View:

    ⬡ (10,5)     ⬡ (11,5)     ⬡ (12,5)
      [145]        [146]        [147]
    
    ⬡ (10,6)                   ⬡ (12,6)
      [160]      [BARREL]       [162]
                 (no hex)
    
    ⬡ (10,7)     ⬡ (11,7)     ⬡ (12,7)
      [175]        [176]        [177]
```

**Each enabled hexagon shows:**
- Green outline
- Index number (e.g., [145])
- Coordinates (e.g., (10,5))

**Disabled cells (obstacles):**
- NO outline
- NO text
- Invisible in debug mode (unless show_disabled_outlines = true)

---

## Step-by-Step Setup Checklist

### ✓ Before Integration
```
Your Scene:
├── NavigationRegion2D  ← Has baked NavigationPolygon
├── StaticBody2D (Barrel)
├── StaticBody2D (Wall)
└── Player
```

### ✓ After Adding SessionController
```
Your Scene:
├── NavigationRegion2D  ← Linked to SessionController
├── StaticBody2D (Barrel)
├── StaticBody2D (Wall)
├── Player
└── SessionController  ← NEW!
    ├── navigation_region = NavigationRegion2D  ← IMPORTANT!
    ├── integrate_with_navmesh = true
    └── debug_mode = true
```

### ✓ Expected Console Output
```
SessionController: Initializing session...
HexGrid initialized: 30 x 20 = 600 cells
HexGridNavmeshIntegration: Starting integration with navmesh...
HexGridNavmeshIntegration: Integration complete!
  Enabled: 0 cells
  Disabled: 127 cells
  Total navigable: 473 cells
SessionController: Navmesh integration complete
SessionController: Session initialized successfully
Grid Stats:
  Dimensions: 30x20
  Total Cells: 600
  Enabled: 473
  Disabled: 127
  Hex Size: 32.0 pixels
```

---

## Common Visual Issues & Solutions

### Issue 1: Hexagons everywhere (including on obstacles)

**Cause:** Navigation integration not enabled

**Fix:**
```gdscript
session_controller.navigation_region = $NavigationRegion2D
session_controller.integrate_with_navmesh = true
```

---

### Issue 2: No hexagons at all

**Cause:** Debug mode disabled or grid not initialized

**Fix:**
```gdscript
session_controller.debug_mode = true
await session_controller.terrain_initialized
```

---

### Issue 3: Hexagons in wrong positions

**Cause:** Hex size doesn't match your tile size

**Fix:**
```gdscript
# For 64x32 isometric tiles:
session_controller.hex_size = 32.0

# For 96x48 isometric tiles:
session_controller.hex_size = 48.0
```

---

### Issue 4: Too many/too few hexagons disabled

**Cause:** Sample points too low/high

**Fix:**
```gdscript
# More aggressive obstacle detection:
session_controller.navmesh_sample_points = 9

# Less aggressive (faster):
session_controller.navmesh_sample_points = 3
```

---

## Real-World Example

### Your Scene (Based on Screenshots)

Looking at your screenshots, you have:
- Isometric warehouse/dungeon environment
- Walls (brick/stone)
- Barrels (wooden obstacles)
- Sand/dirt floor
- NavigationRegion2D covering floor area

**Recommended Settings:**

```gdscript
# In SessionController inspector:
Grid Width: 40          # Cover your entire floor area
Grid Height: 30
Hex Size: 32.0         # Adjust based on your tile size
Navigation Region: (drag NavigationRegion2D here)
Integrate With Navmesh: ✓ ON
Navmesh Sample Points: 5
Debug Mode: ✓ ON
```

**Expected Result:**
- Green hexagons covering the sand/dirt floor
- NO hexagons on walls
- NO hexagons on barrels
- NO hexagons outside the room

---

## Testing Your Integration

### Quick Test Procedure

1. **Enable Debug Mode**
   ```gdscript
   session_controller.debug_mode = true
   ```

2. **Run Your Scene**
   - Press F5 in Godot

3. **Check for Green Hexagons**
   - ✅ Should see hexagons on floor
   - ❌ Should NOT see hexagons on obstacles
   - ❌ Should NOT see hexagons outside navmesh

4. **Press F3**
   - Toggle debug on/off
   - Verify it works

5. **Check Console Output**
   - Look for "Integration complete"
   - Check "Total navigable: X cells"
   - Should be > 0

---

## Debug Colors Reference

```
GREEN hexagons  = Enabled (navigable) cells
RED hexagons    = Disabled cells (if show_disabled_outlines = true)
WHITE text      = Cell info (index, coordinates)
DARK GRAY text  = Disabled cell text (if shown)
```

**Default behavior:**
- Only green hexagons are visible
- Red/disabled hexagons are hidden

**To show disabled cells:**
```gdscript
hex_grid_debug.show_disabled_outlines = true
```

---

## What Your Final Scene Should Look Like

```
Isometric View:

    ╔═══════════════════════════════════════════╗
    ║         WALLS (no hexagons)               ║
    ║    ╔════════════════════════════╗        ║
    ║    ║  ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡    ║        ║
    ║    ║ ⬡ ⬡ ⬡ [BARREL] ⬡ ⬡ ⬡    ║        ║
    ║    ║  ⬡ ⬡ ⬡   ⬡  ⬡ ⬡ ⬡ ⬡     ║        ║
    ║    ║ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡   ║        ║
    ║    ║  ⬡ ⬡ ⬡ ⬡ [PLAYER] ⬡     ║        ║
    ║    ║ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡ ⬡   ║        ║
    ║    ║  ⬡ ⬡ ⬡ [BARREL] ⬡ ⬡     ║        ║
    ║    ║ ⬡ ⬡ ⬡   ⬡  ⬡ ⬡ ⬡ ⬡ ⬡   ║        ║
    ║    ╚════════════════════════════╝        ║
    ║                                           ║
    ╚═══════════════════════════════════════════╝

Features:
✓ Hexagons only in room (NavigationRegion2D bounds)
✓ Hexagons avoid barrels (baked obstacles)
✓ Hexagons avoid walls (baked obstacles)
✓ Player can pathfind using hex grid
✓ Clean, professional appearance
```

---

**If your debug view matches the CORRECT behavior above, you're all set!** 🎉
