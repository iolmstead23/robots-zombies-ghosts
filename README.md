# Zombies & Ghosts & Robots

**An Interactive AI Training Arena for Decision Modeling and Reinforcement Learning**

## Overview

Zombies & Ghosts & Robots is an interactive 2D isometric arena environment designed to serve as a playground for autonomous AI agent development, training, and testing. The project combines game engine capabilities with machine learning infrastructure to create a structured environment where intelligent agents can learn, evolve, and generate valuable behavioral data through iterative training cycles.

The arena acts as both a testing ground for novel decision-making models and a data collection pipeline. Agents interact with the environment autonomously while their performance metrics, movement patterns, combat decisions, and strategic choices are recorded for analysis and model refinement. This creates a feedback loop where each iteration of training produces increasingly sophisticated agent behaviors.

# Hexagonal Grid Navigation System

## Developer Branch Overview

This feature branch implements a robust hexagonal grid-based navigation system for a 2D isometric robot shooter built in Godot 4.5. The primary objective is to replace the existing linear pathfinding system with a comprehensive hex-grid solution that provides improved spatial navigation and clearer movement mechanics for robotic units.

## Core Architecture

The navigation system is built around three primary controllers that work in concert to manage the grid, pathfinding, and game state synchronization.

### Session Controller

The Session Controller serves as the orchestrator for the global navigation session. It maintains synchronization between the overall game state and the navigation requirements, ensuring that all systems remain coordinated as the game progresses.

### Navigation Controller

The Navigation Controller handles the creation and management of the hexagonal grid overlay. This includes initializing the grid at game start, performing runtime updates when necessary, and coordinating with the pathfinding system to facilitate unit movement across the game world.

### Terrain Controller

The Terrain Controller takes responsibility for grid initialization and state management. It monitors the environment continuously, tracking static obstacle placement and removal to keep the grid representation accurate. The controller ensures that the hexagonal grid remains synchronized with the actual terrain and obstacles present in the level.

## Hexagonal Grid Design

The navigation system uses a regular hexagonal grid overlaid on top of the existing navigation and collision meshes. Each hexagonal cell measures 2 meters across, aligning perfectly with in-game spatial units to provide consistent movement calculations.

### Cell State Management

Every cell in the grid maintains a simple enabled or disabled state. Enabled cells represent navigable, clear areas free from static obstacles, while disabled cells indicate positions occupied by walls, barrels, or other impassable objects. This binary state system was chosen deliberately for performance optimization and code clarity, avoiding the complexity of multi-attribute cell systems.

### Grid Enablement Logic

The system determines cell states based on their position relative to the navigation mesh and static obstacles. Cells are marked as enabled only when they fall within clear, traversable areas of the navigation mesh. Any cell overlapping with static, non-traversable obstacles is automatically disabled. All pathfinding operations respect these cell states, restricting movement exclusively to enabled cells.

## Visual Rendering

The grid visualization system renders thin, clearly-visible outlines around enabled cells only. Disabled cells remain invisible, creating a clean visual representation that highlights available movement paths without cluttering the screen with blocked areas. This rendering approach supports both debugging during development and gameplay readability for players.

## Pathfinding Implementation

The pathfinding system leverages Godot's built-in AStarGrid and AStarNode classes exclusively. This approach takes full advantage of the engine's highly optimized, well-tested navigation features rather than introducing custom algorithms. The hex grid serves as the primary navigation structure, completely replacing the previous linear or segmented pathfinding approach.

Robot units are constrained to move only through enabled hexagonal cells. Obstacle avoidance is handled inherently through the grid's enabled/disabled state system, eliminating the need for additional runtime collision checks during pathfinding operations.

## Development Philosophy

This branch emphasizes using Godot's native navigation capabilities to their fullest extent. The architecture deliberately avoids redundant or custom pathfinding code for core navigation functionality, relying instead on the engine's robust built-in systems for maximum performance and reliability.

The system is designed with extensibility in mind. While the current implementation focuses on static obstacle navigation, the architecture readily supports future enhancements such as dynamic obstacle detection, real-time grid updates, and specialized UI overlays for player feedback.

## Getting Started

Begin by pulling this feature branch and familiarizing yourself with the SessionController, NavigationController, and TerrainController scripts. Ensure that all obstacles in your test levels are properly marked as static objects, as this designation is critical for accurate grid generation and cell state determination.

Test the navigation system by observing the grid overlay during gameplay. The visual representation should clearly show enabled cells forming paths through the environment, with disabled cells remaining invisible around obstacles. Validate that pathfinding operates correctly across all enabled cells and that units respect the hexagonal movement constraints.

*Zombies & Ghosts & Robots is part of Third Eye Consulting's ongoing research into autonomous decision-making systems and practical applications of reinforcement learning in complex environments.*