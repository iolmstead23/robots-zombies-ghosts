# Battle Arena: Zombies & Ghosts & Robots

**An Interactive AI Training Arena for Decision Modeling and Reinforcement Learning**

## Overview

Battle Arena: Zombies & Ghosts & Robots is an interactive 2D isometric arena environment designed to serve as a playground for autonomous AI agent development, training, and testing. The project combines game engine capabilities with machine learning infrastructure to create a structured environment where intelligent agents can learn, evolve, and generate valuable behavioral data through iterative training cycles.

The arena acts as both a testing ground for novel decision-making models and a data collection pipeline. Agents interact with the environment autonomously while their performance metrics, movement patterns, combat decisions, and strategic choices are recorded for analysis and model refinement. This creates a feedback loop where each iteration of training produces increasingly sophisticated agent behaviors.

# Branch Overview

This branch focuses on robust hexagonal grid-based pathfinding and navigation systems for autonomous agents. The code is modular, designed for flexibility, debugging, and extensibility. Here’s a detailed breakdown to help anyone jumping into the developer workflow:

🧩 Controllers Overview
1. HexGrid.gd
Role: The mathematical engine of hex-grid navigation.
Key Features:
Converts between world/cube/axial/offset/grid coordinates.
Supports flat-top hex grids.
Neighbor queries, hex rings, and ranges.
Manhattan/cube distance.
Pixel-perfect vertex generation for hex rendering.
Highlights:
All spatial math you need for grid-based logic in one place.
APIs for both visualization and logic.
2. NavigationController.gd
Role: Main pathfinding and grid-management hub.
Key Features:
Generates the walkable hex grid based on scene geometry and obstacles.
Integrates Godot’s NavigationRegion2D and NavigationPolygon for mesh queries.
Uses obstacle detection (collision layers + player exclusion).
Custom A* pathfinding on the enabled grid cells.
Exposes signals for pathfinding (GRID_READY, PATH_CALCULATED etc.)
Grid regeneration and visualization (inc. disabled cells).
Highlights:
Efficiently computes enabled/disabled grid cells using physics and navmesh checks.
All state/statistics exposed for monitoring and debugging.
Easily extensible for different grid/obstacle dynamics.
3. SessionController.gd
Role: State manager for navigation sessions.
Key Features:
Manages navigation requests/responses and player-agent control.
Switches between navigation modes: HEXGRID, DIRECT, DISABLED.
Supports waypoint navigation, stuck detection/repathing.
Signals for UI or automated logic hooks (navigation started/completed/cancelled/stuck/grid_ready).
Highlights:
Decoupled state logic makes it easy to test, swap, or debug modes.
Full progress tracking and info retrieval (good for agent logging).
4. PathSmoother.gd
Role: Utility for sub-hex smoothing/simplification.
Key Features:
Line-of-sight based path reduction on hex grids.
Option for naive angle-based reduction (cheaper, simpler).
Highlights:
Plug-and-play – can use in real-time or as a post-processing step in agent movement.
🐞 Debugging/Testing Scripts
5. NavigationDiagnostic.gd
Role: Deep diagnostic on the navmesh/region setup.
Features:
Checks if NavigationRegion2D and NavigationPolygon are properly configured/baked.
Verifies key data (outlines, polygons, vertices) and prints actionable errors.
Suggests fixes and even attempts auto-baking in code.
Dev Power:
Save hours on “navmesh won’t generate” headaches.
First stop if grid generation is failing!
6. NavigationTest.gd
Role: User-facing and automated testing tool.
Features:
Provides an interactive/systematic way to stress-test navigation.
Visualizes player, waypoints, paths, and test status via in-game UI.
Diagnostics panel with live state info.
Click-to-navigate, auto-test, and custom diagnostics run.
Dev Power:
“Test the whole thing” in <1 minute.
Ready-made test suite to validate changes/refactors.
✨ Feature Summary
Hex Grid Pathfinding: Fast A* search on flat-topped hexes, with obstacle and navmesh awareness.
Grid Visualization: Real-time drawing of enabled/disabled cells, paths, and waypoints.
Dynamic Player Navigation: Agent can navigate grid, handle stuck situations, and update waypoints fluidly.
Automatic Diagnostics: One-click detection and reporting of navmesh errors, and live debug feedback during play.
Advanced Path Smoothing: Optional route simplification with line-of-sight or geometric heuristics.
🛠 Implementation Details
HexGrid Math: Clean separation between all coordinate systems; ideal if you want to port for turn-based, real-time, or even simulation logic.
A Pathfinding:* Simple, easily replaceable if you want to experiment.
Obstacle Integration: Layer masks and clearance settings—swap logic or tweak as needed.
Session Management: Decoupled; swap NavigationControllers or integrate with other systems.
Signals: Everything triggers signals for event-driven/game loop or UI/agent scripting.
Debug UI: Diagnostic info visible in-game—no need for outside logging.
📝 Developer Commit Summary
Main contributions in this branch:

Modularized all navigation/pathfinding logic into dedicated Controller classes.
Added line-of-sight and obstacle-aware path smoothing.
Built reusable and detailed diagnostic/testing scripts for grid/pathfinding debugging.
Refined signals, settings, and API for easy agent and navigation integration.
Improved error messages and guidance for setup, especially around NavigationPolygon baking.
Docs-in-code: All scripts heavily commented for fast ramp-up and collaborative development.

*Zombies & Ghosts & Robots is part of Third Eye Consulting's ongoing research into autonomous decision-making systems and practical applications of reinforcement learning in complex environments.*