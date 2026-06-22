# Animation Synchronization Fixes

This document summarizes the improvements made to ensure jump animations are properly synchronized across all scenarios.

## Issues Fixed

### 1. **Frame Preservation During Jump Transitions**
**Problem**: When switching from one animation to another during a jump (e.g., Walk+Shoot → Jump), the old animation's frame position was being copied to the new jump animation. This caused misalignment since jump animations have different frame counts and peak frames.

**Solution**: Removed frame preservation during jump animation switches. Now when the jump animation changes (e.g., direction change or state transition), it resets to frame 0 and plays through to the peak frame correctly.

**Code**: `_update_jump_animation_phase()` lines 150-156 now resets frames on animation switch.

### 2. **Combat Animation Resume After Landing**
**Problem**: When landing from a jump while in a looping animation like `walk_shoot`, the animation would restart from frame 0, losing any flow of the underlying animation.

**Solution**: Added explicit resume logic (lines 90-96) that detects when we're landing back into the same animation we were in before the jump. Instead of calling `_play_animation()` (which restarts), it calls `animated_sprite.play()` to resume from frame 0 with the correct speed.

**Code**:
```gdscript
# Resuming from a jump: if same animation as before jump, resume playing instead of restarting.
if _jump_phase == JumpPhase.NONE and animated_sprite.animation == anim_name and not animated_sprite.is_playing():
    var anim_speed := _calculate_animation_speed(anim_type)
    animated_sprite.play(anim_name, anim_speed)
    if OS.is_debug_build():
        print_debug("ANIM: resumed %s @ %.1fx (after jump)" % [anim_name, anim_speed])
    return
```

### 3. **Improved Landing Debug Logging**
**Problem**: It was unclear what animation state would be resumed after landing.

**Solution**: Enhanced the landing callback to log both the current animation and what state will be resumed next.

**Code**: `_on_is_jumping_changed()` now logs:
```
JUMP_PHASE: LANDED → NONE | will resume state='<state>' anim='<anim>'
```

### 4. **ASCENT Phase Logging**
**Problem**: No visibility into when a jump started.

**Solution**: Added logging when entering ASCENT phase to track jump initiation.

**Code**: Added debug output in `_update_jump_animation_phase()` when `_jump_phase == JumpPhase.NONE`.

## Animation Frame Freeze Points

**Verified Behavior:**

| Scenario | State | Animation | Peak Frame | Notes |
|----------|-------|-----------|-----------|-------|
| Idle Jump | `jump` | `Jump_*` | 3 | In-place, 10 total frames |
| Walk Jump | `jump` | `Jump_*` | 3 | In-place, 10 total frames |
| Run Jump | `run_jump` | `RunJump_*` | 4 | Carries momentum, 10 total frames |
| Walk+Shoot Jump | `jump` | `Jump_*` | 3 | Combat interrupted, animation resets |
| Direction Change Mid-Jump | `jump`/`run_jump` | Directional variant | 3 or 4 | Switches animation, maintains phase |

## Test Coverage

See `ANIMATION_TEST_CASES.md` for comprehensive test scenarios covering:
1. Idle jump (in-place)
2. Walk jump (path cancellation)
3. Run jump (momentum carry)
4. Walk + combat jump
5. Run + combat jump
6. Standing shoot jump (blocked)
7. Direction changes during jump

## Implementation Details

### Jump Phase State Machine

```
NONE
  └─ _start_jump() publishes motion.is_jumping=true
  └─ next frame enters ASCENT

ASCENT
  └─ animation plays from frame 0
  └─ when animation finishes OR motion.is_falling=true
  └─ transition to AIRBORNE

AIRBORNE
  └─ animation frozen at peak frame (3 or 4)
  └─ holds until motion.is_jumping=false

Landing
  └─ motion.is_jumping→false via registry
  └─ _on_is_jumping_changed() resets phase to NONE
  └─ next frame: state manager re-resolves to grounded state
  └─ update_animation() resumes appropriate animation
```

### Publication Order Matters

In `MotionPackage._start_jump()`:
```gdscript
registry.publish("motion.was_running_on_jump", was_running_when_jumped)
registry.publish("motion.is_jumping", true)
registry.publish("motion.blocks_input", true)
```

**Why this order?**
- `motion.was_running_on_jump` is published first
- When `motion.is_jumping` fires, Navigation's subscription handler can query `motion.was_running_on_jump` and get the correct value
- This determines whether to cancel the path (walk jump) or keep it (run jump)

## Verification Commands (in Godot Console)

```gdscript
# Check jump frame configuration
var peak_idle = 3 if "Jump_Down".begins_with("Jump_") else 4  # Should be 3
var peak_run = 3 if "RunJump_Down".begins_with("Jump_") else 4  # Should be 4

# Verify animation existence
var sprite_frames = $AnimatedSprite2D.sprite_frames
print(sprite_frames.get_frame_count("Jump_Down"))  # Should be 10
print(sprite_frames.get_frame_count("RunJump_Down"))  # Should be 10
```

## Future Enhancements

- [ ] Support for "air strafe" (change direction during jump without resetting animation)
- [ ] Partial jump interruption (jumping from combat = short jump vs full jump)
- [ ] Custom peak frame per direction (if sprites differ)
- [ ] Jump animation blending based on velocity (smoother transitions)
