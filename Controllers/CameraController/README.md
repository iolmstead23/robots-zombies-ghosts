# CameraController

Manages camera behavior in a turn-based hex grid game with smooth transitions, automatic viewport calculation, and debug free roam mode.

## Overview

The CameraController provides three core features:

1. **Smooth Transitions**: Automatically moves camera to agents when their turn starts using Tween-based animations
2. **Viewport Management**: Calculates optimal zoom to show agent's full movement range on any screen size
3. **Debug Free Roam**: Allows manual camera control with arrow keys/WASD when debug mode is active

All camera operations route through SessionController following the signal-based architecture.

## Architecture

```
SessionController
    ↓ (initializes)
CameraController (Node)
    ├── CameraTransitionHandler (calculates target position/zoom)
    ├── CameraBoundsCalculator (viewport math)
    └── CameraFreeRoamHandler (arrow key input)
```

**Signal Flow:**
- Agent turn starts → SessionController → CameraController → Smooth transition
- Debug toggled → SessionController → CameraController → Enable/disable free roam
- Zoom requested → CameraInputHandler → CameraController → Apply zoom

## Files

- `Core/camera_controller.gd` - Main controller and API
- `Core/camera_state.gd` - State tracking data class
- `Types/camera_types.gd` - Enums and constants
- `Packages/Transition/camera_transition_handler.gd` - Target calculation
- `Packages/Transition/camera_bounds_calculator.gd` - Zoom/viewport math
- `Packages/Input/camera_free_roam_handler.gd` - Manual camera control

## Public API

### Exports (Configurable in Inspector)

**Transition Settings:**
- `transition_enabled: bool = true` - Enable/disable smooth transitions
- `transition_duration: float = 0.8` - Animation duration in seconds
- `transition_easing: Tween.EaseType = EASE_IN_OUT` - Easing curve
- `transition_trans: Tween.TransitionType = TRANS_CUBIC` - Interpolation type

**Viewport Settings:**
- `movement_range_buffer: float = 1.5` - Show 150% of agent's movement range
- `min_zoom: float = 0.3` - Minimum camera zoom
- `max_zoom: float = 2.0` - Maximum camera zoom
- `auto_zoom_to_fit: bool = true` - Auto-calculate zoom for agent range

**Free Roam Settings:**
- `free_roam_pan_speed: float = 500.0` - Pan speed in pixels/second
- `free_roam_zoom_speed: float = 0.1` - Zoom step for mouse wheel
- `free_roam_enabled_in_debug: bool = true` - Enable free roam in debug mode

**Camera Bounds:**
- `enable_camera_bounds: bool = true` - Constrain camera to grid edges
- `bounds_padding: float = 200.0` - Extra pixels around grid boundaries

### Signals (Emitted)

```gdscript
# Status signals
signal camera_transition_started(agent_data: AgentData)
signal camera_transition_completed(agent_data: AgentData)
signal camera_transition_cancelled()
signal camera_mode_changed(mode: CameraTypes.CameraMode)

# State change signals
signal camera_moved(new_position: Vector2)
signal camera_zoomed(new_zoom: Vector2)
signal camera_bounds_updated(bounds: Rect2)
```

### Methods (Public API)

**Initialization:**
```gdscript
func initialize(session_ctrl: SessionController, cam: Camera2D) -> void
func set_hex_grid_controller(controller) -> void
```

**Camera Control:**
```gdscript
func move_camera_to_agent(agent_data: AgentData) -> void
func enable_free_roam() -> void
func disable_free_roam() -> void
func zoom_in() -> void
func zoom_out() -> void
func set_zoom_level(zoom: float) -> void
```

**State Queries:**
```gdscript
func get_current_mode() -> CameraTypes.CameraMode
func is_transitioning() -> bool
func get_camera_state() -> CameraState
func get_zoom_level() -> float
func get_follow_mode_zoom() -> float
func get_free_roam_zoom() -> float
func get_zoom_range() -> Vector2
```

## Usage Examples

### From SessionController

The SessionController automatically handles camera integration. Signal handlers route events to camera:

```gdscript
# Initialize during session setup
camera_controller.initialize(self, camera_node)
camera_controller.set_hex_grid_controller(hex_grid_controller)

# Signal handlers (automatically connected)
func _on_agent_turn_started_camera(agent_data: AgentData):
    camera_controller.move_camera_to_agent(agent_data)

func _on_debug_visibility_changed_camera(visible: bool):
    if visible:
        camera_controller.enable_free_roam()
    else:
        camera_controller.disable_free_roam()
```

### From Other Systems

To manually control camera (rare, usually use SessionController):

```gdscript
# Get reference
var camera_controller = session_controller.camera_controller

# Move to specific agent
camera_controller.move_camera_to_agent(some_agent_data)

# Check if transitioning
if camera_controller.is_transitioning():
    print("Camera is moving")

# Get current mode
var mode = camera_controller.get_current_mode()
if mode == CameraTypes.CameraMode.FREE_ROAM:
    print("Free roam active")
```

### Listening to Camera Events

```gdscript
# Connect to camera signals
camera_controller.camera_transition_started.connect(_on_camera_started)
camera_controller.camera_mode_changed.connect(_on_mode_changed)

func _on_camera_started(agent_data: AgentData):
    print("Camera moving to: ", agent_data.agent_name)

func _on_mode_changed(mode: CameraTypes.CameraMode):
    match mode:
        CameraTypes.CameraMode.FOLLOW:
            print("Auto-follow enabled")
        CameraTypes.CameraMode.FREE_ROAM:
            print("Free roam enabled")
```

## Enums

### CameraTypes.CameraMode
- `FOLLOW` - Auto-follow active agent (default)
- `FREE_ROAM` - Manual camera control (debug mode)
- `LOCKED` - No camera movement

### CameraTypes.TransitionState
- `IDLE` - No transition in progress
- `TRANSITIONING` - Camera is moving
- `CANCELLED` - Transition was interrupted

## Integration Points

### Required Setup

1. **SessionController** must initialize CameraController with camera reference
2. **HexGridController** must be set for bounds calculation
3. **IOController's CameraInputHandler** provides zoom signals (auto-connected)

### Agent Turn Flow

```
AgentController.agent_turn_started
    ↓
SessionController._on_agent_turn_started_camera
    ↓
CameraController.move_camera_to_agent
    ↓
[0.8s smooth transition with zoom adjustment]
    ↓
CameraController.camera_transition_completed
```

### Debug Mode Flow

```
User presses F3
    ↓
DebugController.debug_visibility_changed(true)
    ↓
SessionController._on_debug_visibility_changed_camera
    ↓
CameraController.enable_free_roam()
    ↓
[Arrow keys/WASD control camera at 500 px/s]
    ↓
User presses F3 again
    ↓
CameraController.disable_free_roam()
    ↓
[Camera transitions back to active agent]
```

## Behavior Details

### Transition Behavior
- Uses Godot Tween with cubic easing for smooth acceleration/deceleration
- Position and zoom animate simultaneously over 0.8 seconds (configurable)
- Skips transition if already at target (within 10px and 0.05 zoom threshold)
- Cancels ongoing transition when new transition starts or user zooms

### Viewport Calculation
- Calculates zoom to fit agent's movement range (default: 10 meters = 320 pixels)
- Applies buffer multiplier (default: 1.5x = shows 150% of range)
- Accounts for screen resolution and aspect ratio
- Example: Agent with 10m range on 1920x1080 screen = zoom 1.125

### Free Roam Controls
- **Arrow Keys**: Up/Down/Left/Right pan camera
- **WASD**: Alternative control scheme (both work simultaneously)
- **Mouse Wheel**: Zoom in/out (works in all modes)
- **Bounds**: Camera stops at grid edges (respects `bounds_padding`)

### Zoom Tracking
- **Separate zoom levels**: FOLLOW and FREE_ROAM modes each maintain their own zoom level
- **Mode switching**: When entering debug mode (FREE_ROAM), current zoom is saved as FOLLOW zoom and previous FREE_ROAM zoom is restored
- **Zoom persistence**: Each mode remembers its last zoom level when switching between modes
- **Zoom limits**: All zoom operations respect `min_zoom` and `max_zoom` bounds (default: 0.3 to 2.0)
- **API access**: Use `get_zoom_level()`, `get_follow_mode_zoom()`, and `get_free_roam_zoom()` to query zoom state

### Edge Cases
- **Agent already in view**: Transition skipped for snappy gameplay
- **Rapid turn changes**: Previous transition cancelled, new one starts
- **Zoom during transition**: Transition cancelled, user zoom applied
- **Initial position**: Smooth transition from spawn to first agent
- **Viewport resize**: Zoom recalculates to maintain visibility

## Constants

Key values in `camera_types.gd`:

- `DEFAULT_ZOOM = 1.0` - Standard zoom level
- `SKIP_TRANSITION_DISTANCE_THRESHOLD = 10.0` - Skip if within 10 pixels
- `SKIP_TRANSITION_ZOOM_THRESHOLD = 0.05` - Skip if zoom difference < 0.05
- `HEX_SIZE = 32.0` - Pixels per hex cell
- `PIXELS_PER_METER = 32` - 1 meter = 1 hex = 32 pixels
- `MAX_MOVEMENT_DISTANCE = 10` - Default agent range

## Performance

- **Transition Cost**: Very low (single Tween, 3 floats)
- **Viewport Calc**: Low (~10 operations, once per turn start)
- **Free Roam**: Negligible (simple vector math per frame)
- **Bounds Check**: Low (4 clamp operations per frame when active)

## Troubleshooting

**Camera doesn't move:**
- Check camera reference was set in `initialize()`
- Verify SessionController signal connections
- Look for "[CameraController] Initialized" in console

**Free roam doesn't work:**
- Ensure debug mode is active (F3)
- Check `free_roam_enabled_in_debug = true`

**Camera shows void at edges:**
- Increase `bounds_padding` (default: 200.0)
- Ensure `enable_camera_bounds = true`

**Zoom not working:**
- Verify CameraInputHandler exists in IOController
- Check "[CameraController] Connected to CameraInputHandler" message
