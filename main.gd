extends Node2D

@onready var robot: AgentController = $Characters/Robot
@onready var camera: Camera2D = $Camera2D
@onready var navigation_region: NavigationRegion2D = $Environment/NavigationRegion2D

func _ready() -> void:
	robot.set_camera(camera)
	_setup_navigation()

func _setup_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Outer boundary defines the maximum traversable extent.
	# Walls are carved out of this automatically.
	var boundary := PackedVector2Array([
		Vector2(-4096, -4096),
		Vector2( 4096, -4096),
		Vector2( 4096,  4096),
		Vector2(-4096,  4096),
	])
	nav_poly.add_outline(boundary)
	navigation_region.navigation_polygon = nav_poly
	navigation_region.bake_navigation_polygon()
