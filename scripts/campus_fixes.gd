extends RefCounted
# Corrections laid over the baked school, which is not rebuilt for them. Regenerate the navigation
# with tools/bake_night_navigation.gd.
const Spot := preload("res://scripts/hiding_spot.gd")
const NAVIGATION := "res://scenes/night_navigation.tres"
const FOUNTAIN := Vector3(0, 1.42, 32)
const FOUNTAIN_ROUNDING := 0.96
# Position, yaw, kind: the cots in the two sick bays.
const SPOTS := [
	[Vector3(23.0, 0.0, -10.5), 1.5708, 2],
	[Vector3(32.0, 0.0, -11.0), 0.0000, 2],
	[Vector3(36.0, 0.0, -4.0), -1.5708, 2],
	[Vector3(11.0, 0.0, -35.0), 1.5708, 2],
	[Vector3(11.5, 0.0, -25.0), 3.1416, 2],
	[Vector3(20.5, 0.0, -24.0), 3.1416, 2],
]

static func apply(world: Node3D) -> void:
	_round_fountain(world)
	var container: Node3D = world.get_node("HidingSpots")
	for entry in SPOTS:
		var spot := Spot.new()
		spot.kind = entry[2]
		spot.position = entry[0]
		spot.rotation.y = entry[1]
		container.add_child(spot)
	if ResourceLoader.exists(NAVIGATION):
		world.get_node("Navigation").navigation_mesh = load(NAVIGATION)

# The fountain is round but its collider was a square: four invisible corners nothing could pass.
static func _round_fountain(world: Node3D) -> void:
	for body in world.get_node("Architecture").get_children():
		if not body is StaticBody3D:
			continue
		for shape in body.get_children():
			if shape is CollisionShape3D and shape.shape is BoxShape3D and shape.global_position.distance_to(FOUNTAIN) < 0.1:
				var size: Vector3 = shape.shape.size
				var round_shape := CylinderShape3D.new()
				round_shape.radius = size.x * 0.5 * FOUNTAIN_ROUNDING
				round_shape.height = size.y
				shape.shape = round_shape
				return
