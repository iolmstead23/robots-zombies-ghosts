# Robot Player Entity Overview

This document provides a high-level introduction to the Robot player entity’s architecture, purpose, and primary systems. It is intended for developers wishing to understand, customize, or extend the robot as a player-controlled or autonomous actor within Godot projects.

---

## Purpose and Overview

The Robot is a modular, extensible 2D player character built for flexible gameplay and easy customization. It supports both **direct player input** and **autonomous pathfinding-based movement**, enabling a wide range of behaviors from typical twin-stick control to AI-driven navigation. The robot’s architecture separates concerns between input, movement, combat, and state handling, making it straightforward to expand or adapt for varied interaction paradigms.

---

## Modular Architecture

The robot’s logic is designed around core components that interact through well-defined interfaces:

- **PlayerController.gd**: Central hub that wires together all robot systems and coordinates input handlers, movement, state, and combat logic.
- **Input Handlers**: Isolated modules for processing different types of control (direct/manual or pathfinding/autonomous).
- **MovementComponent.gd**: Handles raw character motion, physics responses, and applies velocity.
- **JumpComponent.gd**: Encapsulates jump/airborne movement behavior and collision logic.
- **CombatComponent.gd**: Encapsulates attack mechanics, projectile firing, weapon stats, etc.
- **AnimationController.gd**: Coordinates animation states, transitions, and integration with gameplay events.
- **StateManager.gd**: Tracks and transitions robot states (idle, walking, jumping, attacking, etc.).

All components communicate via signals and function calls, allowing for targeted extension or replacement of each subsystem.

---

## Control Modes

The Robot supports two primary control paradigms, each implemented via specialized input handlers. Switching between control modes is handled in the PlayerController and can be triggered by code or gameplay events.

### 1. Direct Player Control

- Handled by **InputHandler.gd**
- Processes direct manual inputs (keyboard/controller or touchscreen), translating player commands into movement vectors, jump/shoot actions, and context-sensitive abilities.
- Designed for responsive, real-time control typical in player-centric games.
- Input abstraction enables quick remapping or support for multiple control schemes.

### 2. Pathfinding Control

- Handled by **PathfindingInputHandler.gd**
- Receives target positions (manual or programmatically set) and autonomously calculates paths using Godot's navigation systems.
- Generates movement and action inputs to follow dynamic paths, avoiding obstacles and adapting to the world.
- Continually updated to improve animation synchronization and advanced path-following behaviors.

#### Switching and Input Handling Design

- **PlayerController.gd** references and swaps input handlers at runtime based on game context (e.g., player toggling to auto-move mode, AI taking control, scripted cutscenes).
- Input handlers are modular: to add a new control paradigm, implement a new handler inheriting from **BaseInputHandler.gd** and connect it in PlayerController.gd.
- Each handler provides a standardized interface, ensuring seamless integration and feature consistency.

---

## Core Components: Summary

- **PlayerController.gd**: Entry point, manages component communication and mode switching.
- **MovementComponent.gd & JumpComponent.gd**: Physics-based motion, jump arcs, and collision.
- **CombatComponent.gd**: Weapon firing, abilities, hit processing.
- **AnimationController.gd**: Animation triggers and blending.
- **StateManager.gd**: Encapsulates robot state machine; each action/transition as a state.
- **InputHandler.gd**: Standard player/manual input logic.
- **PathfindingInputHandler.gd**: Target-directed, autonomous input logic.
- **BaseInputHandler.gd**: Interface base—extend this to support new input types or AI.

This modularity ensures each gameplay concern can be updated, replaced, or tested in isolation.

---

## Customization and Tuning

Major gameplay properties are easily tuned by designers and programmers alike:

- **Movement and Physics**: 
  - Configure speed, acceleration, friction, jump height, and gravity in `MovementComponent.gd` and `JumpComponent.gd`.
- **Combat & Weapons**: 
  - Adjust fire rate, projectile spread, damage, and add new weapon types/abilities via `CombatComponent.gd`.
- **Animation**: 
  - Swap out spritesheets, expand directional support, or script advanced transitions in `AnimationController.gd`.
- **Input Behaviors**: 
  - Add/remap inputs via `InputHandler.gd`, or introduce new input logic by creating a handler from `BaseInputHandler.gd`.
- **Pathfinding**: 
  - Refine target acquisition, replanning, and special movement states in `PathfindingInputHandler.gd`.

**Examples of Customization:**

```gd
# Adjusting movement speed (MovementComponent.gd)
export var walk_speed := 200.0
export var jump_force := 350.0

# Tuning weapon stats (CombatComponent.gd)
export var projectile_speed := 800.0
export var fire_cooldown := 0.15
```

---

## Signals and Extensibility

The robot leverages Godot signals for event-driven extension:

- **State and action changes**: e.g. `state_changed`, `jump_started`, `weapon_fired`
- **Animation events**: e.g. `animation_played`, `frame_triggered`
- **Custom hooks**: Easily add new signals to respond to new states or features (abilities, items, visual effects)

To add new capabilities:
- Subclass or extend any component (e.g. new ability system in CombatComponent, new movement style in MovementComponent).
- Connect to robot or component signals in scenes/scripts to respond to game events.
- Implement and assign new input handlers to enable advanced AI, online sync, or novel user controls.

---

## Main Areas for Tuning & Expansion

- Movement speed, acceleration, jump arc, and gravity
- Custom inputs and control schemes (manual, AI, pathfinding)
- Weapon and projectile logic (damage, speed, behavior)
- Animation assets, transitions, and logic hooks
- New abilities or state-driven powers

---

## Quick Start & Advanced Usage

- Use **PlayerController.gd** as your central extension point.
- Assign, replace, or add new input handlers by subclassing **BaseInputHandler.gd**.
- Route new signals for game events or cutscenes.
- Modular system allows quick prototyping and enables complex AI/player hybrid control.

---

## Final Notes

The robot’s modular design empowers rapid prototyping, stress-free tuning, and ambitious expansion into new control paradigms, AI routines, or animation systems. Explore **PlayerController.gd** to begin customizing behaviors, adding features, or integrating your own gameplay systems!
