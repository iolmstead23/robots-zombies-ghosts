# NavigationController

A modular, signal-based navigation system for hexagonal grid-based games in Godot. Supports both turn-based and real-time navigation with A* pathfinding, smooth movement execution, and comprehensive state management.

## Summary

The NavigationController provides a complete navigation solution built on a layered architecture:

- **Turn-Based Navigation** (Currently Active): Player-controlled movement with path preview, confirmation, and smooth execution
- **Real-Time Navigation** (Disabled, code preserved): Continuous pathfinding and navigation using NavigationAgent2D
- **Signal-Based Communication**: Fully decoupled from other controllers using Godot signals
- **Modular Core Components**: Reusable pathfinding, movement, and state management utilities
- **Hexagonal Grid Support**: Native support for hexagonal grids with A* pathfinding

**Current Configuration**: Turn-based mode with 20-foot (640 pixel) maximum movement per turn.

## Quick Start

```gdscript
# Initialize
var navigation_controller = NavigationController.new()
navigation_controller.initialize(hex_grid, player)

# Connect signals
navigation_controller.path_found.connect(_on_path_found)
navigation_controller.navigation_completed.connect(_on_nav_completed)

# Request movement
navigation_controller.navigate_to_position_requested.emit(target_position)

# Cancel navigation
navigation_controller.cancel_navigation_requested.emit()
```

## Architecture

### Directory Structure

```
NavigationController/
├── Core/                          # Reusable components
│   ├── Algorithms/               # A* pathfinding implementation
│   ├── Movement/                 # Movement execution & tracking
│   ├── State/                    # State management
│   ├── Types/                    # Type definitions & constants
│   ├── Utilities/                # Static utility functions
│   └── navigation_controller.gd  # Main orchestrator
└── Packages/                      # High-level implementations
    ├── Pathfinding/              # HexPathfinder
    ├── TurnBasedNavigation/      # Turn-based system (ACTIVE)
    └── RealTimeNavigation/       # Real-time system (DISABLED)
```

### Core + Packages Pattern

```
┌─────────────────────────────────────┐
│   NavigationController (Main)      │
│   Orchestrates navigation           │
└─────────────────────────────────────┘
              │
    ┌─────────┴──────────────┐
    │                        │
┌───▼───────────┐  ┌─────────▼────────┐
│   Packages    │  │  Core Components │
│  (High-level) │  │   (Reusable)     │
├───────────────┤  ├──────────────────┤
│ HexPathfinder │  │ AStarPathfinder  │
│ TurnBased*    │  │ NavigationState  │
│ RealTime*     │  │ Movement*        │
└───────────────┘  │ Utilities        │
                   └──────────────────┘
```

## Base Scripts

### Main Controller

**`navigation_controller.gd`** - Primary navigation orchestrator
- Coordinates pathfinding and navigation requests
- Signal-based communication (no direct dependencies)
- Manages async request/response patterns
- Integrates with HexGrid via signals

### Core Components

#### Pathfinding

**`Core/Algorithms/astar_pathfinder.gd`** - Pure A* implementation
- Stateless pathfinding algorithm
- Works with hexagonal grids
- Configurable heuristics and movement costs
- Used by: HexPathfinder

**`Core/Algorithms/heuristics.gd`** - Distance calculation strategies
- Hex distance, Euclidean, Manhattan, Diagonal
- Weighted and tie-breaking heuristics
- All static functions
- Used by: AStarPathfinder

**`Core/Algorithms/path_reconstructor.gd`** - Path reconstruction
- Rebuilds paths from A* results
- Path validation and transformations
- Path smoothing and waypoint extraction
- Used by: AStarPathfinder

#### State Management

**`Core/State/navigation_state.gd`** - Navigation state tracker
- Tracks current target, path, and progress
- Waypoint management
- Emits: `state_changed`, `progress_updated`
- Used by: NavigationController

**`Core/State/request_manager.gd`** - Async request handler
- Manages path and navigation requests
- Request timeout handling (5s default)
- Thread-safe request ID generation
- Used by: NavigationController

**`Core/State/turn_state_machine.gd`** - Turn-based state machine
- States: IDLE, PLANNING, PREVIEW, AWAITING_CONFIRMATION, EXECUTING, COMPLETED
- Validates state transitions
- Emits: `state_changed`, `turn_started`, `turn_ended`
- Used by: TurnBasedMovementController

#### Movement Execution

**`Core/Movement/movement_executor.gd`** - Movement execution engine
- Executes movement along paths
- Progress tracking and distance calculations
- Works with both turn-based and real-time
- Emits: `movement_started`, `movement_progress_updated`, `movement_completed`, `movement_failed`
- Used by: TurnBasedMovementController

**`Core/Movement/movement_physics.gd`** - Physics-based movement
- Applies velocity to CharacterBody2D
- Handles `move_and_slide()` calls
- Slowdown near arrival support
- Used by: (Currently unused, for real-time navigation)

**`Core/Movement/progress_tracker.gd`** - Progress metrics
- Tracks distance traveled and remaining
- Milestone tracking (0.25, 0.5, 0.75, 1.0)
- Average speed calculations
- Emits: `progress_updated`, `milestone_reached`
- Used by: MovementExecutor

**`Core/Movement/waypoint_tracker.gd`** - Waypoint advancement
- Detects waypoint arrival
- Timeout detection (5s stuck threshold)
- Emits: `waypoint_reached`, `waypoint_timeout`, `all_waypoints_reached`
- Used by: MovementExecutor

#### Utilities (Static Functions)

**`Core/Utilities/direction_utils.gd`** - Direction vectors, angles, rotations, velocity calculations
**`Core/Utilities/distance_calculator.gd`** - Distance operations, unit conversions (feet ↔ pixels)
**`Core/Utilities/interpolation_utils.gd`** - Path interpolation, position at progress (0.0-1.0)
**`Core/Utilities/path_validator.gd`** - Path/cell validation, path trimming to max distance

#### Type Definitions

**`Core/Types/navigation_types.gd`** - Enums (`TurnState`, `NavigationStatus`, `PathValidation`) and data classes
**`Core/Types/movement_constants.gd`** - Distance conversions (32px = 1ft), max movement (640px), speeds, timeouts

### Package Components

**`Packages/Pathfinding/hex_pathfinder.gd`** - High-level A* pathfinding
- Delegates to Core AStarPathfinder
- Methods: `find_path()`, `find_path_world()`, `find_path_to_range()`
- Movement range calculations
- Emits: `path_found`, `path_failed`
- Used by: NavigationController, TurnBasedPathfinder

**`Packages/TurnBasedNavigation/turn_based_movement_controller.gd`** - PRIMARY ACTIVE SYSTEM
- Complete turn-based movement system
- Features: path preview, confirmation, smooth execution
- Integrates: TurnStateMachine, MovementExecutor, TurnBasedPathfinder
- Emits: `turn_started`, `turn_ended`, `movement_started`, `movement_completed`

**`Packages/TurnBasedNavigation/turn_based_pathfinder.gd`** - Turn-based pathfinding
- Calculates paths with max distance enforcement (20 feet)
- Path preview and confirmation support
- Delegates to HexPathfinder
- Emits: `path_calculated`, `path_confirmed`, `path_cancelled`

**`Packages/RealTimeNavigation/hex_agent_navigator.gd`** - Real-time navigation (DISABLED)
- Continuous pathfinding and navigation
- Uses NavigationAgent2D
- Code preserved for future use

**`Packages/RealTimeNavigation/nav_agent_2d_follower.gd`** - Agent following (DISABLED)
- Makes CharacterBody2D follow NavigationAgent2D
- Real-time movement component

## Component Interactions

### Turn-Based Movement Flow

```
User Click on Destination
         ↓
TurnBasedMovementController.request_movement_to()
         ↓
TurnStateMachine: IDLE → PLANNING
         ↓
TurnBasedPathfinder.calculate_path_to()
         ↓
HexPathfinder.find_path()
         ↓
AStarPathfinder.find_path() [Core Algorithm]
    ├─ Uses Heuristics for distance calculation
    └─ Uses PathReconstructor to build path
         ↓
TurnStateMachine: PLANNING → AWAITING_CONFIRMATION
    (Path preview shown to player)
         ↓
User Confirms (Space/Enter key)
         ↓
TurnStateMachine: AWAITING_CONFIRMATION → EXECUTING
         ↓
Movement Execution Loop (_physics_process):
    ├─ ProgressTracker.update_from_movement()
    ├─ TurnBasedPathfinder.get_next_position()
    ├─ DirectionUtils.direction_to_with_threshold()
    ├─ DistanceCalculator.distance_between()
    └─ CharacterBody2D.move_and_slide()
         ↓
TurnStateMachine: EXECUTING → COMPLETED → IDLE
```

### Pathfinding Request Flow

```
NavigationController receives navigate_to_position_requested
         ↓
RequestManager.create_nav_request()
         ↓
query_cell_at_position → HexGridController
         ↓
on_cell_at_position_response ← HexGridController
         ↓
PathValidator.is_cell_valid()
         ↓
HexPathfinder.find_path()
         ↓
AStarPathfinder.find_path()
         ↓
Emit: navigation_started / navigation_completed
```

## API Reference

### NavigationController

**Initialization:**
```gdscript
initialize(grid: HexGrid, agent_node: CharacterBody2D) -> void
set_active_agent(agent_node: CharacterBody2D) -> void
```

**State Queries:**
```gdscript
is_navigation_active() -> bool
get_current_path() -> Array[HexCell]
get_current_target() -> HexCell
get_path_tracker() -> HexPathTracker
get_path_visualizer() -> HexPathVisualizer
```

### TurnBasedMovementController (Primary System)

**Initialization:**
```gdscript
initialize(player_ref: CharacterBody2D, movement_ref: MovementComponent,
           state_ref: StateManager, hex_grid: HexGrid, hex_pathfinder: HexPathfinder) -> void
activate() -> void
deactivate() -> void
```

**Movement Control:**
```gdscript
request_movement_to(destination: Vector2) -> void
confirm_movement() -> void
cancel_movement() -> void
```

**Turn Management:**
```gdscript
start_new_turn() -> void
end_turn() -> void
```

**State Queries:**
```gdscript
get_current_state() -> NavigationTypes.TurnState
is_in_state(state: NavigationTypes.TurnState) -> bool
is_awaiting_confirmation() -> bool
```

### HexPathfinder

**Pathfinding:**
```gdscript
find_path(start: HexCell, goal: HexCell) -> Array[HexCell]
find_path_world(start_pos: Vector2, goal_pos: Vector2) -> Array[HexCell]
find_path_to_range(start: HexCell, goal: HexCell, range_cells: int) -> Array[HexCell]
```

**Utilities:**
```gdscript
is_path_clear(start: HexCell, goal: HexCell) -> bool
get_path_length(path: Array[HexCell]) -> int
get_cells_in_movement_range(start: HexCell, movement_points: int) -> Array[HexCell]
get_pathfinding_stats() -> Dictionary
```

### Core Component APIs

**AStarPathfinder:**
```gdscript
find_path(start: HexCell, goal: HexCell, hex_grid: HexGrid, movement_cost: float = 1.0) -> Array[HexCell]
get_stats() -> Dictionary
```

**NavigationState:**
```gdscript
start_navigation(target: HexCell, path: Array[HexCell]) -> void
clear_navigation() -> void
advance_waypoint() -> bool
is_at_final_waypoint() -> bool
get_current_waypoint() -> HexCell
get_remaining_waypoint_count() -> int
get_progress() -> float
```

**TurnStateMachine:**
```gdscript
change_state(new_state: NavigationTypes.TurnState) -> bool
start_turn() -> void
end_turn() -> void
reset() -> void
is_in_state(state: NavigationTypes.TurnState) -> bool
is_executing() -> bool
is_active() -> bool
```

**MovementExecutor:**
```gdscript
start_execution(path: Array[Vector2]) -> bool
update_progress(delta: float) -> float
complete_execution() -> void
cancel_execution() -> void
get_next_position(path: Array[Vector2]) -> Vector2
is_near_completion() -> bool
get_progress() -> float
get_distance_moved() -> int
```

## Signals Reference

### NavigationController

**Emitted:**
- `path_found(start: HexCell, goal: HexCell, path: Array[HexCell], duration_ms: float)`
- `path_not_found(start_pos: Vector2, goal_pos: Vector2, reason: String)`
- `navigation_started(target: HexCell)`, `navigation_completed()`, `navigation_failed(reason: String)`
- `waypoint_reached(cell: HexCell, index: int, remaining: int)`
- `navigation_state_changed(active: bool, path_length: int, remaining_distance: int)`
- `query_cell_at_position(request_id: String, world_pos: Vector2)` - to HexGridController

**Received:**
- `navigate_to_position_requested(target_pos: Vector2)`
- `navigate_to_cell_requested(target_cell: HexCell)`
- `cancel_navigation_requested()`
- `on_cell_at_position_response(request_id: String, cell: HexCell)` - from HexGridController

### TurnBasedMovementController

- `turn_started(turn_number: int)`, `turn_ended(turn_number: int)`
- `movement_started()`, `movement_completed(distance_moved: int)`

### HexPathfinder

- `path_found(path: Array[HexCell])`, `path_failed(start: HexCell, goal: HexCell)`

### Core Components

**NavigationState:** `state_changed(is_active: bool, target: HexCell)`, `progress_updated(waypoint_index: int, total_waypoints: int)`
**TurnStateMachine:** `state_changed(old_state, new_state)`, `turn_started(turn_number)`, `turn_ended(turn_number)`
**MovementExecutor:** `movement_started()`, `movement_progress_updated(progress, position)`, `movement_completed(distance)`, `movement_failed(reason)`
**ProgressTracker:** `progress_updated(progress, metrics)`, `milestone_reached(progress)`
**WaypointTracker:** `waypoint_reached(waypoint, index, remaining)`, `waypoint_timeout(waypoint, index)`, `all_waypoints_reached()`

## Configuration & Constants

### MovementConstants

```gdscript
PIXELS_PER_FOOT: int = 32
MAX_MOVEMENT_DISTANCE: int = 640  # 20 feet
ARRIVAL_DISTANCE_PIXELS: int = 5
DEFAULT_MOVEMENT_SPEED: int = 400  # pixels/second
WAYPOINT_TIMEOUT: int = 5000  # milliseconds
WAYPOINT_ADVANCEMENT_DISTANCE: int = 10  # pixels
```

### TurnState Enum

```gdscript
IDLE                  # No movement in progress
PLANNING              # Calculating path
PREVIEW               # Showing path preview
AWAITING_CONFIRMATION # Waiting for user to confirm/cancel
EXECUTING             # Moving along path
COMPLETED             # Movement finished
```

### NavigationStatus Enum

```gdscript
INACTIVE    # No navigation
ACTIVE      # Currently navigating
COMPLETED   # Successfully completed
FAILED      # Navigation failed
CANCELLED   # Cancelled by user
```

## Extending the System

### Enabling Real-Time Navigation

1. Open `navigation_controller.gd`
2. Uncomment the real-time package instantiation:
```gdscript
# var hex_agent_navigator = HexAgentNavigator.new()
# add_child(hex_agent_navigator)
```
3. Comment out or remove turn-based controller
4. Connect real-time signals as needed

### Adding Custom Heuristics

Add to `Core/Algorithms/heuristics.gd`:
```gdscript
static func custom_heuristic(from: HexCell, to: HexCell) -> float:
    # Your custom distance calculation
    return hex_distance(from, to) * custom_weight
```

Use in pathfinding:
```gdscript
# In AStarPathfinder, modify calculate_heuristic()
var h_cost = Heuristics.custom_heuristic(neighbor, goal)
```

### Creating New Navigation Modes

1. Create new package in `Packages/YourNavigationMode/`
2. Implement controller extending `Node`
3. Use Core components (AStarPathfinder, MovementExecutor, etc.)
4. Add to NavigationController initialization
5. Connect signals for communication

## Design Principles

- **Signal-Based**: No hard dependencies between controllers
- **Stateless Utilities**: All utilities are static, pure functions
- **Component Composition**: Complex behavior built from simple, reusable components
- **Type Safety**: Full type hints on all variables and returns
- **Debug Support**: All components provide `get_*_info()` methods for debugging
- **Progressive Enhancement**: Real-time code preserved for future activation

## Dependencies

**External (Godot):**
- CharacterBody2D (agent movement)
- NavigationAgent2D (real-time, currently unused)
- Node (base class)

**External (Project):**
- HexGrid (hexagonal grid system)
- HexCell (grid cell representation)
- MovementComponent (external movement system)
- StateManager (external state management)
- HexPathTracker, HexPathVisualizer, HexCellSelector (hex UI components)

---

For questions or issues with the NavigationController, see the individual script files for detailed implementation comments and debug methods.