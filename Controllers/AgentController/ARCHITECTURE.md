# Agent Controller Architecture

Isometric point-and-click agent. Concerns are split into atomized packages that
communicate **only** through `AgentRegistry` — no package holds a direct
reference to another package's data. There is exactly one animation authority
(`AgentAnimationController`) and exactly one state authority
(`AgentStateManager`).

## Scene tree

```
AgentController (CharacterBody2D)   Core — orchestration & signal wiring only
├── AnimatedSprite2D
├── NavigationAgent2D
├── AgentRegistry                   Registry — central published state, pub/sub
├── AgentMotionPackage              Motion — jump physics, velocity, speed
├── AgentActionPackage              Action — aim/shoot, fire cooldown, combat
├── AgentStateManager               State — resolves the single animation state
├── AgentAnimationController        Animation — maps resolved state → sprite clip
├── AgentNavigation                 Motion — pathfinding, facing, locomotion
└── AgentInputHandler               Input — mouse/key polling, emits move_requested
```

## Packages

| Package    | Owns (writes)                                              | Reads (via registry)                             |
|------------|------------------------------------------------------------|--------------------------------------------------|
| Motion (Navigation) | `motion.facing_direction`, `motion.is_moving`, `motion.is_running` | `action.demands_walk`, `motion.is_jumping`, `motion.was_running_on_jump` |
| Motion (Physics)    | `motion.is_jumping`, `motion.jump_height`, `motion.is_airborne`, `motion.is_falling`, `motion.was_running_on_jump`, `motion.blocks_input` | `action.is_aiming`, `action.is_shooting`, `motion.is_running` |
| Action     | `action.is_aiming`, `action.is_shooting`, `action.demands_walk`, `action.shoot_anim_speed` | `motion.is_jumping`, `motion.is_running`, `motion.facing_direction` |
| State      | `state.animation`                                          | all `motion.*` / `action.*` inputs below         |
| Animation  | *(nothing — read-only consumer)*                           | `state.animation`, `motion.facing_direction`, `motion.jump_height`, `motion.is_falling`, `action.shoot_anim_speed`, `action.is_aiming` |
| Input      | *(nothing — no registry writes)*                           | `motion.blocks_input`                            |
| Core       | `core.is_active`                                           | snapshot (debug)                                 |

**Single-writer rule:** every registry key has exactly one writing package
(left column). Everyone else is read-only. This is the auditable invariant —
if two packages ever write the same key, the ownership is broken.

## Registry keys

| Key                          | Type    | Owner            | Meaning                                            |
|------------------------------|---------|------------------|----------------------------------------------------|
| `motion.facing_direction`    | String  | Navigation       | 8-way facing name (e.g. `down_left`)               |
| `motion.is_moving`           | bool    | Navigation       | Actively traversing a nav path                     |
| `motion.is_running`          | bool    | Navigation       | Moving at run speed (long path & combat permits)   |
| `motion.is_jumping`          | bool    | Motion physics   | A jump arc is in progress                          |
| `motion.jump_height`         | float   | Motion physics   | Current vertical offset (px) for sprite lift       |
| `motion.is_airborne`         | bool    | Motion physics   | `jump_height > 0` — off the ground                 |
| `motion.is_falling`          | bool    | Motion physics   | Descending phase of a jump (for anim freeze)       |
| `motion.was_running_on_jump` | bool    | Motion physics   | Whether the jump launched from a run               |
| `motion.blocks_input`        | bool    | Motion physics   | Jump arc in progress — blocks aim/fire/click input |
| `action.is_aiming`           | bool    | Action           | Aim input held                                     |
| `action.is_shooting`         | bool    | Action           | Weapon firing this cooldown window                 |
| `action.demands_walk`        | bool    | Action           | Combat requests a forced run→walk downshift        |
| `action.shoot_anim_speed`    | float   | Action           | Base playback speed for shoot clips (aimed/hip)    |
| `state.animation`            | String  | State            | The single resolved high-level animation state     |
| `core.is_active`             | bool    | Core             | Controller initialized and running                 |

## Valid agent states

`state.animation` is always exactly one of:

`idle` · `walk` · `run` · `jump` · `run_jump` · `idle_aim` · `standing_shoot` ·
`walk_shoot`

Each maps to an 8-directional clip set in `AgentAnimationController.animations`.
(`fall` is not a distinct state: the descending phase reuses the `jump`/`run_jump`
clip, frozen on its last frame — see jump phase machine below.)

## Priority resolution (the auditable contract)

`AgentStateManager` resolves `state.animation` every physics frame by walking an
**ordered** rule table (`_build_priority_rules`) and returning the first match.
**The order of the table is the precedence — nothing else.** To change priority,
reorder the rules; never encode precedence in scattered imperative branches.

| # | Resolved state   | Condition (over registry inputs)            |
|---|------------------|---------------------------------------------|
| 1 | `run_jump`       | airborne AND was_running_on_jump            |
| 2 | `jump`           | airborne                                    |
| 3 | `walk_shoot`     | (shooting OR aiming) AND moving             |
| 4 | `standing_shoot` | shooting AND not moving                     |
| 5 | `idle_aim`       | aiming AND not moving                       |
| 6 | `run`            | moving AND running                          |
| 7 | `walk`           | moving AND not running                      |
| 8 | `idle`           | (always — fallback)                         |

This directly encodes the spec's precedence:

- **Airborne > everything** (rules 1–2). Combat fire is additionally gated off
  mid-jump by Motion, so no shoot state can win while airborne.
- **Combat > grounded locomotion** (rules 3–5 before 6–7).
- **Locomotion is the grounded default** (rules 6–8).

### Composite / blend cases

| Combination     | Result        | How it is enforced                                                                 |
|-----------------|---------------|------------------------------------------------------------------------------------|
| Walk + Shoot    | `walk_shoot`  | Rule 3 (blended upper/lower-body clip).                                             |
| Run + Shoot     | *suppressed*  | Action publishes `action.demands_walk`; Navigation drops `is_running`, so the agent is `walk`, then rule 3 → `walk_shoot`. Run+shoot never co-exist. |
| Run + Jump      | `run_jump`    | Rule 1 via `was_running_on_jump` (carries momentum). Navigation keeps steering toward target. |
| Walk + Jump     | `jump`        | Rule 2 (`was_running_on_jump` is false). Navigation cancels its path (via `motion.is_jumping` subscription guard). |

## Transitions

Transitions are not hand-authored edges — they are an **emergent consequence** of
re-resolving the priority table each frame as inputs change. Representative flows:

- `idle → walk/run`: click destination → Navigation sets `is_moving` (+ `is_running`
  if path is long and combat permits).
- `walk/run → idle`: arrival → Navigation clears `is_moving`/`is_running`.
- `walk → walk_shoot`: aim/fire pressed while moving (rule 3).
- `run → walk_shoot`: aim/fire pressed while running → `demands_walk` downshifts to
  walk first, then rule 3.
- `* → jump/run_jump`: jump pressed (gated off while aiming/shooting) → airborne
  (rules 1–2 dominate until landing).
- `jump/run_jump → previous locomotion`: land → `is_airborne` clears, table
  re-resolves to the grounded state implied by current inputs.

## Per-frame order (Core `_physics_process`)

```
navigation.process(delta)          # publish facing / is_moving / is_running
motion.update(delta)               # publish jump_* / is_airborne / is_falling / blocks_input
action.update(delta)               # publish aiming / shooting / demands_walk / shoot_anim_speed
state_manager.update()             # READ all of the above → publish state.animation
animation_controller.update_animation()  # READ state.animation → play clip
```

State resolution runs after every input has published for the frame, and the
animation controller consumes the resolved state last. The animation controller
owns only *playback* concerns (clip selection by direction, speed, the jump-phase
freeze machine, sprite vertical lift) — never priority.

## Input blocking during jump arc

`motion.blocks_input` is published by Motion Physics and subscribed to by Input Handler.
When a jump starts, Motion publishes `motion.blocks_input = true`, which reactively
updates `is_input_blocked` in InputHandler. This prevents new aim/fire/click inputs
during the jump arc. Motion publishes `motion.blocks_input = false` on landing.
Note: `motion.was_running_on_jump` is published **before** `motion.is_jumping` in
`_start_jump()` to ensure Navigation's jump subscription sees the correct momentum value.

## Jump animation phase machine (Animation-local)

`jump`/`run_jump` clips are one-shot with a held airborne pose. The animation
controller tracks `JumpPhase { NONE, ASCENT, AIRBORNE }`:

**ASCENT** — Jump starts, animation plays from frame 0.

**AIRBORNE** — Triggered when clip finishes or `motion.is_falling` becomes true.
Animation freezes on the peak frame:
- `Jump_*` animations (Walk+Jump, Idle+Jump): freeze at **frame 3** (mid-air pose)
- `RunJump_*` animations (Run+Jump): freeze at **frame 4** (mid-air pose)

**Landing** — When `motion.is_jumping` goes false, phase resets to NONE.
The grounded state (walk, run, walk_shoot, standing_shoot, or idle) takes over
and resumes/restarts as appropriate for that looping animation.

**Combat interruption during jump** — If the agent jumps while aiming or shooting
(e.g., Walk+Shoot → Jump), the jump animation transitions immediately to the
correct jump state (Jump_* or RunJump_*), plays from frame 0, then freezes at
its peak frame until landing. Upon landing, the original combat animation
(walk_shoot or standing_shoot) resumes from frame 0 with the correct playback
speed.

This is purely a playback detail and does not affect `state.animation`.
