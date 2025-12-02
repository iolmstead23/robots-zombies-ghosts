# Agent Controller

Manages multiple agents in a turn-based system with automatic turn cycling and movement tracking.

## Overview

The Agent Controller handles spawning agents, managing turn order, tracking movement actions, and coordinating agent state. It operates through a signal-based architecture where agents are wrapped in `AgentData` objects and controlled via method calls and signals.

## Key Features

- **Multi-agent support**: Manages 1-4 agents with automatic turn cycling
- **Movement tracking**: Tracks distance traveled per turn with configurable limits
- **Turn-based control**: Enables/disables agent controllability based on active turn
- **Spawn management**: Random positioning with collision avoidance
- **Signal-based coordination**: Emits events for turn changes and movement completion

## Signal API

### Outbound Signals

```gdscript
signal agents_spawned(agent_count: int)
signal agent_turn_started(agent_data: AgentData)
signal agent_turn_ended(agent_data: AgentData)
signal all_agents_completed_round()
signal movement_action_completed(agent_data: AgentData, movements_remaining: int)
```

### Public Methods

```gdscript
# Initialize with required dependencies
func initialize(grid: HexGrid, nav_controller: Node) -> void

# Spawn agents at random positions
func spawn_agents(count: int = -1) -> void

# Track movement and auto-advance turns when exhausted
func record_movement_action(distance_meters: int = 0) -> bool

# Manually end the current agent's turn
func end_current_agent_turn() -> void

# Get active agent data
func get_active_agent() -> AgentData

# Get all spawned agents
func get_all_agents() -> Array[AgentData]
```

## Implementation Example

```gdscript
# In SessionController or main scene
var agent_controller = AgentController.new()
add_child(agent_controller)

# Initialize with dependencies
agent_controller.initialize(hex_grid, navigation_controller)
agent_controller.agent_count = 2
agent_controller.max_movements_per_turn = 10

# Connect to signals
agent_controller.agent_turn_started.connect(_on_turn_started)
agent_controller.movement_action_completed.connect(_on_movement_completed)

# Spawn agents
agent_controller.spawn_agents()

# Record movement (in movement handler)
agent_controller.record_movement_action(distance_in_meters)
```

## Architecture

The Agent Controller does not directly puppet agents through signals. Instead:

1. **AgentController** controls which agent can act via `set_controllable()`
2. **TurnBasedMovementController** executes movement and emits completion signals
3. **Agent** listens to component signals and re-emits to the world
4. **SessionController** routes AgentController signals to other feature controllers

This multi-tiered approach maintains loose coupling and allows independent testing of each layer.
