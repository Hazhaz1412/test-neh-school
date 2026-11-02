extends RefCounted

const Spot = preload("res://scripts/hiding_spot.gd")
const WALL_GAP := 0.42

static func build(school: Node3D) -> void:
	var container := Node3D.new()
	container.name = "HidingSpots"
	school.add_child(container)
	container.owner = school
	# One cover a room, of the sort that room would really have. Back corners keep entrances,
	# teaching desks and the central aisles free; a cabinet stands flat against the wall.
	for room in school.get_meta("room_catalog", []):
		var center: Vector3 = room.center
		var size: Vector2 = room.size
		var table := table_room(room)
		var along := 1.65 if table else 0.7
		var depth := 1.65 if table else WALL_GAP
		var pos := center + Vector3(size.x * 0.5 - along, 0, size.y * 0.5 - depth)
		# South-facing B rooms have their teaching wall on the opposite end.
		if room.block == "B" and center.z > -39:
			pos.z = center.z - size.y * 0.5 + depth
		if (room.kind == "storage" or room.kind == "archive") and not (room.block == "B" and center.z > -39):
			pos.x = center.x - size.x * 0.5 + along
		if room.block == "SERVICE":
			pos = Vector3(-39.125 - WALL_GAP, 0, -53.5)
		add_spot(container, school, "Hide_%d" % room.number, pos, (-PI / 2 if room.block == "SERVICE" else 0.0 if room.block == "B" and center.z > -39 else PI), Spot.Kind.TABLE if table else Spot.Kind.LOCKER)
	# Lockers stand in pairs, the way a school buys them, at the few long stretches with no door.
	# All of these can be reached BEFORE the master key is found.
	for floor_index in range(3):
		var y := floor_index * 3.9
		add_pair(container, school, "HallA_%d" % floor_index, Vector3(19, y, 6.125 + WALL_GAP), 0, Vector3.RIGHT)
		add_pair(container, school, "HallB_%d" % floor_index, Vector3(-7, y, -41.875 + WALL_GAP), 0, Vector3.RIGHT)
		var side := -1.0 if floor_index % 2 == 0 else 1.0
		add_pair(container, school, "HallLink_%d" % floor_index, Vector3(side * (38.125 + WALL_GAP), y, -3), side * PI / 2, Vector3.FORWARD)
	add_spot(container, school, "WarehouseTable", Vector3(-43.3, 0, -57.4), 0, Spot.Kind.TABLE)

static func table_room(room: Dictionary) -> bool:
	if room.block == "SERVICE" or room.kind in ["staff", "storage", "archive"]:
		return false
	return room.kind != "classroom" or int(room.number) % 2 == 0

static func add_pair(container: Node3D, school: Node3D, label: String, pos: Vector3, yaw: float, along: Vector3) -> void:
	add_spot(container, school, label, pos, yaw, Spot.Kind.LOCKER)
	add_spot(container, school, label + "b", pos + along * 0.96, yaw, Spot.Kind.LOCKER)

static func add_spot(container: Node3D, school: Node3D, label: String, pos: Vector3, yaw: float, kind: int) -> void:
	var spot := Spot.new()
	spot.name = label
	spot.kind = kind
	spot.position = pos
	spot.rotation.y = yaw
	container.add_child(spot) # Builds the cover once, before the navigation bake.
	spot.owner = school
	for child in spot.find_children("*", "", true, false):
		child.owner = school
