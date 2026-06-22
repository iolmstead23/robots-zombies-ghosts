# Animation Synchronization Test Cases

This document describes the test cases needed to verify that jump animation frames are correctly synchronized across all jump scenarios.

## Frame Freeze Timing

- **Walk+Jump (`Jump_*`)**: Freeze at frame **3** during airborne phase
- **Run+Jump (`RunJump_*`)**: Freeze at frame **4** during airborne phase
- **Walk+Shoot+Jump → Jump**: Should freeze at frame **3**
- **Run+Shoot+Jump → RunJump**: Should freeze at frame **4** (if run was active before combat started)

## Test Scenarios

### 1. Idle Jump (In-Place)
**Setup**: Agent is idle.
**Action**: Press J (jump).
**Expected**:
- State: `idle` → `jump`
- Animation: `Idle_Down` → `Jump_Down` @ 4.5x
- ASCENT phase: plays frames 0-2
- AIRBORNE phase: freezes at frame 3
- Landing: `jump` → `idle`, resumes `Idle_Down` @ 4.5x

**Log signature**:
```
ANIM: Idle_Down → Jump_Down @ 4.5x
JUMP_PHASE: NONE → ASCENT | anim=Jump_Down | total_frames=10
JUMP_PHASE: ASCENT → AIRBORNE | anim=Jump_Down | peak_frame=3 | total_frames=10 | falling=true
JUMP_PHASE: LANDED → NONE | will resume state='idle' anim='Idle_Down'
ANIM: resumed Idle_Down @ 4.5x (after jump)
```

---

### 2. Walk Jump (Interrupted)
**Setup**: Click to walk, agent is walking.
**Action**: Press J (jump during walk).
**Expected**:
- State: `walk` → `jump`
- Animation: `Walk_Down` → `Jump_Down` @ 4.5x
- Path cancelled (Navigation's `motion.is_jumping` subscriber stops pathfinding)
- ASCENT: plays frames 0-2
- AIRBORNE: freezes at frame 3
- Landing: `jump` → `walk`, resumes `Walk_Down` @ 4.5x (but no path, so idle)

**Log signature**:
```
NAV: move to X,Y (from A,B)
ANIM: Walk_Down → Jump_Down @ 4.5x
JUMP_PHASE: ASCENT → AIRBORNE | anim=Jump_Down | peak_frame=3
JUMP_PHASE: LANDED → NONE | will resume state='walk' anim='Walk_Down'
NAV: arrived at ... (cancellation triggered by _on_is_jumping_changed)
```

---

### 3. Run Jump (Momentum Carry)
**Setup**: Click far away (>400px), agent is running.
**Action**: Press J (jump during run).
**Expected**:
- State: `run` → `run_jump`
- Animation: `Run_Down` → `RunJump_Down` @ 4.5x
- Path **NOT cancelled** (Navigation keeps target)
- ASCENT: plays frames 0-3
- AIRBORNE: freezes at frame 4
- Landing: resumes running toward target

**Log signature**:
```
NAV: move to X,Y (from A,B)
ANIM: Run_Down → RunJump_Down @ 4.5x
JUMP_PHASE: ASCENT → AIRBORNE | anim=RunJump_Down | peak_frame=4
JUMP_PHASE: LANDED → NONE
ANIM: RunJump_Down → Run_Down @ 4.5x
(continues navigation)
```

---

### 4. Walk + Combat Jump
**Setup**: Agent walking, fires weapon (becomes `walk_shoot`).
**Action**: Press J (jump while aiming/shooting).
**Expected**:
- State transitions: `walk_shoot` → `jump` (combat blocks jump from starting, so this shouldn't happen)
  - OR if combat allows: `walk_shoot` → `jump` (combat is gated off mid-jump)
- Animation: `WalkShoot_Down` → `Jump_Down` @ 4.5x (fires during walk, then jumps)
- ASCENT: plays frames 0-2
- AIRBORNE: freezes at frame 3
- Landing: resumes `walk_shoot` OR back to `walk` (depends on if combat is still active)

**Log signature**:
```
ANIM: WalkShoot_Down → Jump_Down @ 4.5x
JUMP_PHASE: ASCENT → AIRBORNE | anim=Jump_Down | peak_frame=3
JUMP_PHASE: LANDED → NONE | will resume state='walk' anim='WalkShoot_Down'
ANIM: resumed WalkShoot_Down @ 9.0x (after jump)
```

---

### 5. Run + Combat Jump
**Setup**: Agent running and aiming/shooting (`walk_shoot` after run→walk downshift).
**Action**: Press J (jump while in `walk_shoot` from prior run+combat).
**Expected**:
- State: `walk_shoot` → `jump` (not `run_jump` because `demands_walk` suppressed it)
- Animation: `WalkShoot_Down` → `Jump_Down` @ 4.5x
- ASCENT: plays frames 0-2
- AIRBORNE: freezes at frame 3
- Landing: resumes combat

**Log signature**:
```
FIRE: down (0.067s cooldown)
ANIM: WalkShoot_Down → Jump_Down @ 4.5x
JUMP_PHASE: ASCENT → AIRBORNE | anim=Jump_Down | peak_frame=3
JUMP_PHASE: LANDED → NONE | will resume state='walk_shoot' anim='WalkShoot_Down'
ANIM: resumed WalkShoot_Down @ 9.0x (after jump)
```

---

### 6. Standing Shoot Jump
**Setup**: Agent idle, fires weapon (`standing_shoot` state).
**Action**: Press J (jump while shooting).
**Expected**:
- Motion blocks jump input (aiming/shooting gates jump)
- Jump should **not** occur

**Log signature**:
```
(No jump allowed — motion.is_jumping should remain false)
```

---

### 7. Direction Change During Jump
**Setup**: Agent runs up, jumps (becomes `run_jump`).
**Action**: Agent continues jumping while changing direction.
**Expected**:
- Animation changes to `RunJump_*` matching new direction mid-jump
- Frame count may differ for different directions, but peak frame should be 4
- Preserves AIRBORNE state across direction change

**Log signature**:
```
ANIM: RunJump_Down → RunJump_Right @ 4.5x
JUMP_ANIM: switched to RunJump_Right (frame reset to 0)
(still in AIRBORNE phase, freezes at frame 4)
```

---

## Verification Checklist

- [ ] **Frame 3 for Jump_\***: Verify all Walk/Idle jumps freeze at frame 3
- [ ] **Frame 4 for RunJump_\***: Verify all Run jumps freeze at frame 4
- [ ] **Path cancellation**: Walk+Jump should cancel navigation (in-place)
- [ ] **Path continuation**: Run+Jump should keep navigation active (momentum)
- [ ] **Combat interruption**: Jump during combat correctly transitions to jump state
- [ ] **Landing resume**: Animation resumes correctly based on grounded state
- [ ] **Input blocking**: No new aim/fire/click inputs accepted during jump
- [ ] **Direction changes**: Jump animations update direction without losing phase

## Debug Output Format

Enable debug logging in Godot to see jump phase transitions:

```
JUMP_PHASE: ASCENT → AIRBORNE | anim=<name> | peak_frame=<3|4> | total_frames=<N> | falling=<true|false>
JUMP_PHASE: LANDED → NONE | will resume state='<state>' anim='<anim>'
ANIM: <old> → <new> @ <speed>x
ANIM: resumed <anim> @ <speed>x (after jump)
```
