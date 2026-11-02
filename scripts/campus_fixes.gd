extends RefCounted
# Corrections laid over the baked school, which is not rebuilt for them. Regenerate the list with
# tools/place_hiding.gd and the navigation with tools/bake_night_navigation.gd.
const Spot := preload("res://scripts/hiding_spot.gd")
const NAVIGATION := "res://scenes/night_navigation.tres"
const FOUNTAIN := Vector3(0, 1.42, 32)
const FOUNTAIN_ROUNDING := 0.96
# Position, yaw, kind: a second cover in each room, cots in the sick bays, lockers along the halls.
const SPOTS := [
	[Vector3(-36.0, 0.0, -9.5), 1.5708, 0], # 101
	[Vector3(-21.0, 0.0, -11.0), 0.0000, 0], # 102
	[Vector3(23.0, 0.0, -10.5), 1.5708, 2], # 104
	[Vector3(32.0, 0.0, -11.0), 0.0000, 2], # 104
	[Vector3(36.0, 0.0, -4.0), -1.5708, 2], # 104
	[Vector3(-37.0, 0.0, 9.0), 0.0000, 0], # 105
	[Vector3(-37.0, 0.0, 49.0), 1.5708, 0], # 106
	[Vector3(27.5, 0.0, 31.0), 3.1416, 0], # 107
	[Vector3(26.0, 0.0, 40.5), 1.5708, 0], # 108
	[Vector3(-31.0, 0.0, -61.0), 0.0000, 0], # 1101
	[Vector3(-9.0, 0.0, -61.0), 0.0000, 0], # 1102
	[Vector3(11.0, 0.0, -59.5), 0.0000, 0], # 1103
	[Vector3(-31.0, 0.0, -38.0), 0.0000, 0], # 1104
	[Vector3(11.0, 0.0, -35.0), 1.5708, 2], # 1105
	[Vector3(11.5, 0.0, -25.0), 3.1416, 2], # 1105
	[Vector3(20.5, 0.0, -24.0), 3.1416, 2], # 1105
	[Vector3(-28.0, 3.9, -11.0), 0.0000, 0], # 201
	[Vector3(-12.0, 3.9, -11.0), 0.0000, 0], # 202
	[Vector3(16.0, 3.9, -11.0), 0.0000, 0], # 203
	[Vector3(23.0, 3.9, -3.0), 1.5708, 0], # 204
	[Vector3(-26.0, 3.9, 10.5), -1.5708, 0], # 205
	[Vector3(-26.0, 3.9, 41.5), -1.5708, 0], # 206
	[Vector3(37.0, 3.9, 22.0), -1.5708, 0], # 207
	[Vector3(37.0, 3.9, 47.5), -1.5708, 0], # 208
	[Vector3(-31.0, 3.9, -52.0), 1.5708, 0], # 1201
	[Vector3(1.5, 3.9, -61.0), 0.0000, 0], # 1202
	[Vector3(22.5, 3.9, -61.0), 0.0000, 0], # 1203
	[Vector3(-31.0, 3.9, -28.5), 1.5708, 0], # 1204
	[Vector3(29.5, 3.9, -24.0), 3.1416, 0], # 1205
	[Vector3(-36.0, 7.8, 0.0), 1.5708, 0], # 301
	[Vector3(-16.0, 7.8, -11.0), 0.0000, 0], # 302
	[Vector3(8.0, 7.8, 5.0), 1.5708, 0], # 303
	[Vector3(23.0, 7.8, 1.0), 1.5708, 0], # 304
	[Vector3(-37.0, 7.8, 20.5), 1.5708, 0], # 305
	[Vector3(-33.5, 7.8, 55.0), 3.1416, 0], # 306
	[Vector3(31.5, 7.8, 55.0), 3.1416, 0], # 308
	[Vector3(-19.5, 7.8, -61.0), 0.0000, 0], # 1301
	[Vector3(-9.0, 7.8, -52.0), 1.5708, 0], # 1302
	[Vector3(31.0, 7.8, -58.0), -1.5708, 0], # 1303
	[Vector3(-23.0, 7.8, -24.0), 3.1416, 0], # 1304
	[Vector3(28.5, 7.8, -30.5), -1.5708, 0], # 1305
	[Vector3(-19.0, 0.0, 6.75), 0.0, 0], # hall
	[Vector3(-9.0, 0.0, 6.75), 0.0, 0], # hall
	[Vector3(9.0, 0.0, 6.75), 0.0, 0], # hall
	[Vector3(6.0, 0.0, -41.25), 0.0, 0], # hall
	[Vector3(-15.0, 0.0, -41.25), 0.0, 0], # hall
	[Vector3(15.0, 0.0, -41.25), 0.0, 0], # hall
	[Vector3(-19.0, 3.9, 6.75), 0.0, 0], # hall
	[Vector3(-9.0, 3.9, 6.75), 0.0, 0], # hall
	[Vector3(9.0, 3.9, 6.75), 0.0, 0], # hall
	[Vector3(6.0, 3.9, -41.25), 0.0, 0], # hall
	[Vector3(-15.0, 3.9, -41.25), 0.0, 0], # hall
	[Vector3(15.0, 3.9, -41.25), 0.0, 0], # hall
	[Vector3(-19.0, 7.8, 6.75), 0.0, 0], # hall
	[Vector3(-9.0, 7.8, 6.75), 0.0, 0], # hall
	[Vector3(9.0, 7.8, 6.75), 0.0, 0], # hall
	[Vector3(6.0, 7.8, -41.25), 0.0, 0], # hall
	[Vector3(-15.0, 7.8, -41.25), 0.0, 0], # hall
	[Vector3(15.0, 7.8, -41.25), 0.0, 0], # hall
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
