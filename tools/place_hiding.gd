extends SceneTree
# Finds a clear stretch of wall in every room and prints the list kept in campus_fixes.gd.
# godot --headless --path . --script tools/place_hiding.gd
const Spot := preload("res://scripts/hiding_spot.gd")
const YAWS := [0.0, PI * 0.5, PI, -PI * 0.5]
const FOOT := {0: Vector3(1.3, 2.1, 1.3), 2: Vector3(2.3, 1.0, 1.15)}
var space: PhysicsDirectSpaceState3D
var school: Node3D

func _initialize() -> void:
	call_deferred("run")

func clear(centre: Vector3, size: Vector3, yaw: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = size
	query.shape = box
	query.collision_mask = 1
	query.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	return space.intersect_shape(query, 1).is_empty()

func backed(at: Vector3, yaw: float, depth: float) -> bool:
	var back := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	var from := at + Vector3.UP * 1.2
	var ray := PhysicsRayQueryParameters3D.create(from, from + back * (depth * 0.5 + 0.5), 1)
	return not space.intersect_ray(ray).is_empty()

func find_place(room: Dictionary, kind: int, taken: Array, doors: Array) -> Array:
	var best := []
	var score := -INF
	var half: Vector2 = room.size * 0.5 - Vector2(1.0, 1.0)
	var x := -half.x
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			var at: Vector3 = room.center + Vector3(x, 0, z)
			z += 0.5
			var near := INF
			for other in taken:
				near = minf(near, Vector2(at.x - other.x, at.z - other.z).length())
			var door_gap := INF
			for door in doors:
				if absf(door.y - at.y) < 1.0:
					door_gap = minf(door_gap, Vector2(at.x - door.x, at.z - door.z).length())
			if near < 3.5 or door_gap < 3.0:
				continue
			for yaw in YAWS:
				var size: Vector3 = FOOT[kind]
				var turn := Basis(Vector3.UP, yaw)
				if not clear(at + Vector3.UP * (size.y * 0.5 + 0.1), size, yaw):
					continue
				if not clear(at + turn * Vector3(0, 1.0, 1.5), Vector3(1.0, 1.7, 1.0), yaw):
					continue
				if not backed(at, yaw, size.z):
					continue
				var value := minf(near, 9.0) + minf(door_gap, 8.0) * 0.5
				if value > score:
					score = value
					best = [at, yaw]
		x += 0.5
	return best

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20):
		await physics_frame
	space = school.get_world_3d().direct_space_state
	var doors := []
	for door in get_nodes_in_group("classroom_doors"):
		doors.append(door.global_position)
	var taken := []
	for spot in get_nodes_in_group("hiding_spots"):
		taken.append(spot.global_position)
	for room in school.get_meta("room_catalog", []):
		if room.block == "SERVICE":
			continue
		var kind := 2 if room.kind == "infirmary" else 0
		for i in range(3 if kind == 2 else 1):
			var place := find_place(room, kind, taken, doors)
			if place.is_empty():
				print("# nothing fits in ", room.number)
				continue
			taken.append(place[0])
			print('\t[Vector3(%.1f, %.1f, %.1f), %.4f, %d], # %s' % [place[0].x, place[0].y, place[0].z, place[1], kind, room.number])
	for floor_index in range(3):
		var y := floor_index * 3.9
		for at in [Vector3(-19, y, 6.75), Vector3(-9, y, 6.75), Vector3(9, y, 6.75), Vector3(6, y, -41.25), Vector3(-15, y, -41.25), Vector3(15, y, -41.25)]:
			if clear(at + Vector3(0, 1.15, 0.1), Vector3(1.2, 2.0, 0.9), 0.0) and clear(at + Vector3(0, 1.0, 1.5), Vector3(1.0, 1.7, 1.0), 0.0):
				print('\t[Vector3(%.1f, %.1f, %.2f), 0.0, 0], # hall' % [at.x, at.y, at.z])
			else:
				print("# hall blocked ", at)
	quit()
