extends RefCounted

const Spot = preload("res://scripts/hiding_spot.gd")

static func build(school: Node3D) -> void:
	var container := Node3D.new()
	container.name = "HidingSpots"
	school.add_child(container)
	container.owner = school
	# Back corners keep entrances, teaching desks and the central aisles free.
	for room in school.get_meta("room_catalog", []):
		var center: Vector3 = room.center
		var size: Vector2 = room.size
		var table: bool = int(room.number) % 2 == 0 and room.block != "SERVICE"
		var pos := center + Vector3(size.x * 0.5 - (1.65 if table else 1.35), 0, size.y * 0.5 - 1.65)
		# South-facing B rooms have their teaching wall on the opposite end.
		if room.block == "B" and center.z > -39:
			pos.z = center.z - size.y * 0.5 + 1.65
		if (room.kind == "storage" or room.kind == "archive") and not (room.block == "B" and center.z > -39):
			pos.x = center.x - size.x * 0.5 + 1.65
		if room.block == "SERVICE":
			pos = Vector3(-43.4, 0, -53.5)
		add_spot(container, school, "Hide_%d" % room.number, pos, 0.0 if room.block == "SERVICE" or (room.block == "B" and center.z > -39) else PI, Spot.Kind.TABLE if table else Spot.Kind.LOCKER)
	# These cabinets can be reached BEFORE the master key is found.
	for floor_index in range(3):
		add_spot(container, school, "HallA_%d" % floor_index, Vector3(19, floor_index * 3.9, 6.75), 0, Spot.Kind.LOCKER)
		add_spot(container, school, "HallB_%d" % floor_index, Vector3(-7, floor_index * 3.9, -41.25), 0, Spot.Kind.LOCKER)
	add_spot(container, school, "WarehouseTable", Vector3(-43.3, 0, -57.4), 0, Spot.Kind.TABLE)

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
