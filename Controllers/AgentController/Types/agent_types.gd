class_name AgentTypes
extends RefCounted

## Agent type definitions for the game
## Defines available agent species and their sprite resources

enum Type {
	ROBOT,
	GHOST,
	ZOMBIE
}

## Sprite resource paths for each agent type
const SPRITE_PATHS = {
	Type.ROBOT: "res://Agents/RobotAgent.tres",
	Type.GHOST: "res://Agents/GhostAgent.tres",
	Type.ZOMBIE: "res://Agents/ZombieAgent.tres"
}

## Display names for each agent type
const DISPLAY_NAMES = {
	Type.ROBOT: "Robot",
	Type.GHOST: "Ghost",
	Type.ZOMBIE: "Zombie"
}

## Get display name for a type
static func get_display_name(type: Type) -> String:
	return DISPLAY_NAMES.get(type, "Unknown")

## Get sprite path for a type
static func get_sprite_path(type: Type) -> String:
	return SPRITE_PATHS.get(type, "res://Agents/RobotAgent.tres")

## Convert string to Type enum (for loading from session data)
static func type_from_string(type_str: String) -> Type:
	match type_str.to_lower():
		"robot": return Type.ROBOT
		"ghost": return Type.GHOST
		"zombie": return Type.ZOMBIE
		_: return Type.ROBOT # Default fallback

## Convert Type enum to string (for saving to session data)
static func type_to_string(type: Type) -> String:
	match type:
		Type.ROBOT: return "robot"
		Type.GHOST: return "ghost"
		Type.ZOMBIE: return "zombie"
		_: return "robot"
