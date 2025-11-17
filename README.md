<img width="720" height="436" alt="Battle-Arena-11-17-2025" src="https://github.com/user-attachments/assets/43195463-2305-407b-84b3-4f56fd1a9ff1" />

Battle Arena: Robots & Zombies & Ghosts is an interactive 2D isometric arena environment designed to serve as a playground for autonomous AI agent development, training, and testing. The project combines game engine capabilities with machine learning infrastructure to create a structured environment where intelligent agents can learn, evolve, and generate valuable behavioral data through iterative training cycles.

The arena acts as both a testing ground for novel decision-making models and a data collection pipeline. Agents interact with the environment autonomously while their performance metrics, movement patterns, combat decisions, and strategic choices are recorded for analysis and model refinement. This creates a feedback loop where each iteration of training produces increasingly sophisticated agent behaviors.

## Purpose & Goals

**Core Objectives:**

The primary goal is to create a decision modeling laboratory where different AI architectures and training methodologies can be tested in a dynamic, adversarial environment. By simulating repeated combat scenarios and agent interactions, the system generates high-quality, structured datasets that feed back into supervised and reinforcement learning pipelines. This enables rapid experimentation with novel agent designs while collecting empirical evidence about what makes effective autonomous decision-making systems.

**Key Use Cases:**

The arena supports multiple learning workflows. Reinforcement learning agents can be trained through self-play and environmental interaction, learning optimal policies without explicit direction. Simultaneously, human players can take direct control to generate supervised learning datasets—recording decision sequences, agent state information, and outcomes to train behavior cloning or imitation learning models. This hybrid approach allows both automated learning and human-guided data generation to coexist within the same environment.

**Vision:**

The end state is an endless, continuously-learning arena where agents progressively improve through cumulative training experiences. As models improve, they generate better training data, which in turn produces stronger agents in subsequent training runs—creating a virtuous cycle of iterative development and model refinement.

## Features

**Dynamic Arena Environment** — A procedurally-varied terrain where autonomous agents spawn, navigate, and engage in strategic combat. The environment records all agent actions, state transitions, and outcomes to create rich behavioral datasets.

**Reinforcement Learning Pipeline** — Agents learn through environmental interaction using RL algorithms. The baseline training system rewards agents for successful combat outcomes, resource efficiency, and strategic positioning, creating incentives for increasingly sophisticated behavior.

**Manual Control System** — Players can assume direct control of agents to generate structured supervised learning data. This allows collection of human-guided decision sequences that can be used for behavior cloning or policy distillation.

**Comprehensive Data Logging** — Real-time collection of agent statistics including health, position, action sequences, engagement metrics, and combat outcomes. All data is timestamped and structured for downstream analysis and model training.

**Iterative Training Architecture** — The system is designed for repeated training cycles where each generation of agents learns from the experiences of previous generations, enabling continuous improvement and emergent behavior development.

**Multi-Agent Interactions** — Support for diverse agent types (robots, ghosts, zombies) with different capabilities, creating varied scenarios for testing decision-making robustness across different contexts and agent architectures.

## How It Works

**Gameplay Loop:**

Agents are spawned into the arena with initial parameters and begin autonomous decision-making. They navigate the terrain, encounter other agents, and engage in combat according to their learned policies or programmed behaviors. All meaningful events—movement, engagement, resource usage, state changes—are logged with metadata for later analysis.

**Data Generation:**

Each session generates structured datasets containing agent telemetry. For autonomous agents, this data includes state observations, actions taken, and outcomes—the perfect format for reinforcement learning or imitation learning. When players take manual control, their decision sequences become high-quality supervised learning examples.

**Training Integration:**

Collected data feeds into model training pipelines. Reinforcement learning updates improve agent policies based on reward signals from the arena. Supervised learning models capture human expertise or previously-successful agent behaviors. These improved models then generate the next generation of agents, creating a continuous improvement cycle.

**Progressive Enhancement:**

As training progresses, agents should demonstrate increasingly sophisticated behaviors. Early generations may exhibit simple heuristics; later generations develop nuanced strategies, adaptive responses, and emergent behaviors that arise from cumulative learning experiences.

## Technical Stack

Built in **Godot Engine** using **GDScript** for game logic and agent systems. The architecture emphasizes modularity and extensibility, with separated concerns for agent controllers, physics and collision systems, animation state management, and data logging pipelines. This design allows for rapid iteration on agent designs and easy integration of different decision-making systems.

## Getting Started

### Prerequisites

- Godot Engine (version 4.5+)

### Installation

1. Clone the repository: `git clone https://github.com/iolmstead23/robots-zombies-ghosts.git`
2. Open the project in Godot Engine

## Contributing & Experimentation

This project is designed as an experimental platform. You are encouraged to:

- Implement new agent decision architectures and test their performance
- Design novel reward structures to shape agent behavior
- Collect data under different arena configurations and analyze patterns
- Integrate different machine learning frameworks for training
- Experiment with multi-agent dynamics and emergent behaviors

*Zombies & Ghosts & Robots is part of Third Eye Consulting's ongoing research into autonomous decision-making systems and practical applications of reinforcement learning in complex environments.*
