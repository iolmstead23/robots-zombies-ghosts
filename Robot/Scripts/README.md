# Player Component System - Integration Guide

## Overview
Your player script has been refactored into 8 atomic components, each handling a specific responsibility. This modular architecture makes your code more maintainable, testable, and reusable.

## Component Files

1. **PlayerController.gd** - Main orchestrator that coordinates all components
2. **MovementComponent.gd** - Handles horizontal movement (walk/run)
3. **JumpComponent.gd** - Manages jump physics and gravity
4. **CombatComponent.gd** - Controls shooting, aiming, and weapon mechanics
5. **InputHandler.gd** - Centralizes all input detection
6. **StateManager.gd** - Manages and tracks player state
7. **AnimationController.gd** - Handles all animation logic
8. **DirectionHelper.gd** - Static utility for direction conversions

## Integration Steps

### 1. Scene Setup
1. Replace your current `player.gd` script with `PlayerController.gd` on your CharacterBody2D node
2. Ensure your player scene has an AnimatedSprite2D child node named exactly `AnimatedSprite2D`

### 2. Project Settings - Input Map
Make sure these actions are defined in Project Settings > Input Map:
- `ui_left` - Move left
- `ui_right` - Move right  
- `ui_up` - Move up
- `ui_down` - Move down
- `ui_accept` - Jump
- `ui_run` - Run/Sprint (e.g., Shift key)
- `ui_aim` - Aim weapon (e.g., Right mouse button)
- `ui_fire` - Shoot weapon (e.g., Left mouse button)

### 3. Class Registration
Add these scripts to your project's autoload or ensure they're accessible:
- Place `DirectionHelper.gd` in a location where it can be accessed globally (it's a static utility class)
- All other components will be instantiated by the PlayerController

### 4. Animation Names
Your AnimatedSprite2D resource should have animations with these exact names:
```
# Idle animations
Idle_Up, Idle_UpRight, Idle_Right, Idle_DownRight
Idle_Down, Idle_DownLeft, Idle_Left, Idle_UpLeft

# Walk animations  
Walk_Up, Walk_UpRight, Walk_Right, Walk_DownRight
Walk_Down, Walk_DownLeft, Walk_Left, Walk_UpLeft

# Run animations
Run_Up, Run_UpRight, Run_Right, Run_DownRight
Run_Down, Run_DownLeft, Run_Left, Run_UpLeft

# Jump animations
Jump_Up, Jump_UpRight, Jump_Right, Jump_DownRight
Jump_Down, Jump_DownLeft, Jump_Left, Jump_UpLeft

# Run-Jump animations
RunJump_Up, RunJump_UpRight, RunJump_Right, RunJump_DownRight
RunJump_Down, RunJump_DownLeft, RunJump_Left, RunJump_UpLeft

# Aim animations
IdleAim_Up, IdleAim_UpRight, IdleAim_Right, IdleAim_DownRight
IdleAim_Down, IdleAim_DownLeft, IdleAim_Left, IdleAim_UpLeft

# Shooting animations
StandingShoot_Up, StandingShoot_UpRight, StandingShoot_Right, StandingShoot_DownRight
StandingShoot_Down, StandingShoot_DownLeft, StandingShoot_Left, StandingShoot_UpLeft

WalkShoot_Up, WalkShoot_UpRight, WalkShoot_Right, WalkShoot_DownRight
WalkShoot_Down, WalkShoot_DownLeft, WalkShoot_Left, WalkShoot_UpLeft
```

## Customization Points

### Adding Projectiles
In `CombatComponent.gd`, find the `_spawn_projectile()` function and add your projectile instantiation:
```gdscript
func _spawn_projectile(direction: String) -> void:
    var projectile = preload("res://Projectile.tscn").instantiate()
    projectile.global_position = player.global_position
    projectile.direction = DirectionHelper.direction_name_to_vector(direction)
    projectile.is_aimed_shot = is_aiming
    player.get_parent().add_child(projectile)
```

### Modifying Movement Speed
Edit constants in `MovementComponent.gd`:
```gdscript
const SPEED := 275.0
const RUN_SPEED_MULTIPLIER := 1.75
const AIM_SPEED_MULTIPLIER := 0.8
```

### Adjusting Jump Physics
Edit constants in `JumpComponent.gd`:
```gdscript
const GRAVITY := 980.0
const JUMP_STRENGTH := 175.0
const MAX_FALL_SPEED := 600.0
```

### Changing Weapon Stats
Modify the dictionary in `CombatComponent.gd`:
```gdscript
var weapon_stats := {
    "aimed_fire_rate": 0.05,
    "hip_fire_rate": 0.0667,
    "aimed_anim_speed": 20.0,
    "hip_anim_speed": 15.0
}
```

## Using the Signal System

The components emit signals you can connect to for game events:

```gdscript
# In your game manager or UI controller:
player.player_jumped.connect(_on_player_jumped)
player.player_shot.connect(_on_player_shot)
player.state_changed.connect(_on_player_state_changed)
```

## Benefits of This Architecture

1. **Single Responsibility** - Each component has one clear purpose
2. **Easy Testing** - Test jump physics without movement code
3. **Reusability** - Use MovementComponent for NPCs or enemies
4. **Clean Debugging** - Issues are isolated to specific components
5. **Easy Feature Addition** - Add new components without touching existing code
6. **Performance** - Only update components that need updating

## Extending the System

To add new features (like inventory, health, etc.):

1. Create a new component extending Node
2. Add initialization in PlayerController's `_setup_components()`
3. Connect any necessary signals
4. Update in `_physics_process()` if needed

Example new component structure:
```gdscript
extends Node
class_name HealthComponent

var max_health := 100
var current_health := 100

signal health_changed(new_health: int)
signal player_died()

func initialize(player_ref: CharacterBody2D) -> void:
    # Setup code here
    pass

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health)
    if current_health == 0:
        player_died.emit()
```

## Debug Features

Use `player.print_state()` to debug the current player state at any time.

## Migration Notes

- All functionality from your original script is preserved
- The refactored code maintains the same behavior
- Performance should be identical or slightly better
- Save files/scenes using the old script will need the script reference updated

## Questions?

The modular design makes it easy to understand each piece in isolation. Start by looking at PlayerController.gd to see how everything connects, then dive into individual components as needed.
