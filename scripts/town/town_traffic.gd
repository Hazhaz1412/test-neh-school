extends Node3D
# Bikes and vans on fixed loops, pedestrians on the pavements. Loops are written as stretches
# of named roads, so they follow the map when the map changes.
const Person := preload("res://scripts/town/town_person.gd")
const LOOPS := [
	[["Đường Cổ Đằng", Vector2(-204, -2), Vector2(-81, 3)], ["Phố Chợ", Vector2(-81, 3), Vector2(-79, -92)], ["Phố Lò Than", Vector2(-79, -92), Vector2(-226, -92)], ["Đường Gò Sậy", Vector2(-226, -92), Vector2(-204, -2)]],
	[["Đường Cổ Đằng", Vector2(-81, 3), Vector2(62, -2)], ["Đường Bến Trầu", Vector2(62, -2), Vector2(67, 88)], ["Phố Hàng Cau", Vector2(67, 88), Vector2(-90, 86)], ["Phố Chợ", Vector2(-90, 86), Vector2(-81, 3)]],
	[["Đường Cổ Đằng", Vector2(62, -2), Vector2(-81, 3)], ["Phố Chợ", Vector2(-81, 3), Vector2(-79, -92)], ["Phố Lò Than", Vector2(-79, -92), Vector2(66, -94)], ["Đường Bến Trầu", Vector2(66, -94), Vector2(62, -2)]],
	[["Đường Cổ Đằng", Vector2(-81, 3), Vector2(-204, -2)], ["Đường Gò Sậy", Vector2(-204, -2), Vector2(-232, 86)], ["Phố Hàng Cau", Vector2(-232, 86), Vector2(-90, 86)], ["Phố Chợ", Vector2(-90, 86), Vector2(-81, 3)]],
]
const LOOKS := ["Male_Adult_01", "Female_Adult_05", "Male_Adult_06", "Female_Adult_12", "Male_Adult_08", "Female_Adult_02", "Female_Adult_07", "Male_Adult_14"]
const BIKES_PER_PATH := 3
const SIGHT := 150.0
const WALKERS := 16
const NEAR_PERSON := 48.0
var plan: RefCounted
var player: Node3D
var paths: Array = []
var riders: Array = []
var walkers: Array = []
var bikes: MultiMesh
var vans: Array = []
var density := 1.0
var rng := RandomNumberGenerator.new()

func setup(town_plan: RefCounted, peter: Node3D, scooter: Mesh) -> void:
	plan = town_plan
	player = peter
	rng.seed = 2402
	for loop in LOOPS:
		paths.append(_path(loop, false))
		paths.append(_path(loop, true))
	var holder := MultiMeshInstance3D.new()
	bikes = MultiMesh.new()
	bikes.transform_format = MultiMesh.TRANSFORM_3D
	bikes.use_colors = true
	bikes.mesh = scooter
	bikes.instance_count = paths.size() * BIKES_PER_PATH
	holder.multimesh = bikes
	holder.custom_aabb = AABB(Vector3(-400, -10, -300), Vector3(800, 60, 600))
	add_child(holder)
	for p in range(paths.size()):
		for n in range(BIKES_PER_PATH):
			var person: Node3D = Person.new()
			person.look = LOOKS[rng.randi() % LOOKS.size()]
			person.motion = "sit"
			add_child(person)
			var index := riders.size()
			bikes.set_instance_color(index, Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.55), rng.randf_range(0.3, 0.95)))
			riders.append({"path": p, "at": paths[p].length * (n + rng.randf() * 0.6) / BIKES_PER_PATH, "pace": rng.randf_range(8.5, 12.5), "speed": 0.0, "person": person, "honk": 0.0})
	_spawn_vans()
	_spawn_walkers()

func _path(loop: Array, backwards: bool) -> Dictionary:
	var centre := PackedVector2Array()
	var widths := PackedFloat32Array()
	var stretches: Array = loop.duplicate()
	if backwards:
		stretches.reverse()
	for part in stretches:
		var road: Dictionary = plan.road_named(part[0])
		var first: int = plan._closest_index(road, part[2] if backwards else part[1])
		var last: int = plan._closest_index(road, part[1] if backwards else part[2])
		var step := 1 if last >= first else -1
		var i := first
		while i != last:
			centre.append(road.path[i])
			widths.append(road.width * 0.25)
			i += step
	var points := PackedVector2Array()
	for i in range(centre.size()):
		var tangent := (centre[(i + 3) % centre.size()] - centre[posmod(i - 3, centre.size())]).normalized()
		# Traffic keeps right: right of travel in this Z-south frame is (-tangent.y, tangent.x).
		points.append(centre[i] + Vector2(-tangent.y, tangent.x) * widths[i])
	var along := PackedFloat32Array([0.0])
	var length := 0.0
	for i in range(1, points.size() + 1):
		length += points[i - 1].distance_to(points[i % points.size()])
		along.append(length)
	return {"points": points, "along": along, "length": length, "cursor": 0}

func _spawn_vans() -> void:
	var scene: PackedScene = load("res://assets/kenney_car/van.glb")
	for p in [0, 3, 5]:
		var van: Node3D = scene.instantiate()
		van.scale = Vector3.ONE * 1.25
		add_child(van)
		vans.append({"path": p, "at": rng.randf() * paths[p].length, "pace": 8.0, "speed": 0.0, "node": van})

func _spawn_walkers() -> void:
	var streets: Array = plan.roads.filter(func(road): return road.walk >= 2.0 and road.kind != "bridge")
	for i in range(WALKERS):
		var road: Dictionary = streets[i % streets.size()]
		var person: Node3D = Person.new()
		person.look = LOOKS[(i + 3) % LOOKS.size()]
		person.motion = "walk"
		add_child(person)
		var from := rng.randi_range(10, road.path.size() - 45)
		walkers.append({"road": road, "from": from, "to": from + rng.randi_range(20, 40), "at": float(from), "dir": 1.0, "side": 1.0 if i % 2 == 0 else -1.0, "person": person})

func _at(path: Dictionary, distance: float) -> Array:
	var along: PackedFloat32Array = path.along
	var count := path.points.size() as int
	var i: int = path.cursor
	if along[i] > distance or along[i + 1] < distance:
		i = clampi(along.bsearch(distance) - 1, 0, count - 1)
		path.cursor = i
	var a: Vector2 = path.points[i]
	var b: Vector2 = path.points[(i + 1) % count]
	var t := inverse_lerp(along[i], along[i + 1], distance)
	return [a.lerp(b, clampf(t, 0.0, 1.0)), (b - a).normalized()]

func _physics_process(delta: float) -> void:
	var peter := Vector2(player.global_position.x, player.global_position.z)
	for i in range(riders.size()):
		var entry: Dictionary = riders[i]
		var path: Dictionary = paths[entry.path]
		var placed: Array = _advance(entry, path, peter, delta, 1.9)
		var distance: float = placed[0].distance_to(peter)
		var seen: bool = distance < SIGHT and float(i) / riders.size() < density
		var yaw := atan2(placed[1].x, placed[1].y) + PI
		var where := Vector3(placed[0].x, 0.0, placed[0].y)
		if seen:
			where.y = plan.ground(placed[0])
			var bend := Transform3D(Basis(Vector3.UP, yaw), where)
			bikes.set_instance_transform(i, bend)
			# Riders sit on the scooter facing its nose, which points along -Z.
			entry.person.global_transform = bend.translated_local(Vector3(0, 0.46, 0.2)).rotated_local(Vector3.UP, PI)
		else:
			bikes.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -50, 0)))
		if entry.person.visible != seen:
			entry.person.visible = seen
		if entry.person.animation != null and entry.person.animation.active and seen:
			entry.person.hold_handlebars()
	for entry in vans:
		var placed: Array = _advance(entry, paths[entry.path], peter, delta, 4.5)
		var where := Vector3(placed[0].x, 0.0, placed[0].y)
		entry.node.global_transform = Transform3D(Basis(Vector3.UP, atan2(placed[1].x, placed[1].y)).scaled(Vector3.ONE * 1.25), where)
		entry.node.visible = placed[0].distance_to(peter) < SIGHT and density > 0.3
	for entry in walkers:
		_stroll(entry, peter, delta)

func _advance(entry: Dictionary, path: Dictionary, peter: Vector2, delta: float, reach: float) -> Array:
	var placed: Array = _at(path, entry.at)
	var to_peter: Vector2 = peter - placed[0]
	var ahead: float = to_peter.dot(placed[1])
	var blocked: bool = ahead > 0.0 and ahead < reach + 5.0 and absf(to_peter.cross(placed[1])) < reach * 0.6
	var bend: float = absf(placed[1].angle_to(_at(path, fposmod(entry.at + 8.0, path.length))[1]))
	var goal: float = 0.0 if blocked else entry.pace * lerpf(1.0, 0.55, clampf(bend, 0.0, 1.0))
	entry.speed = move_toward(entry.speed, goal, (14.0 if blocked else 3.5) * delta)
	entry.at = fposmod(entry.at + entry.speed * delta, path.length)
	return _at(path, entry.at)

func _stroll(entry: Dictionary, peter: Vector2, delta: float) -> void:
	var road: Dictionary = entry.road
	entry.at += entry.dir * delta * 1.25 / plan.STEP
	if entry.at >= entry.to or entry.at <= entry.from:
		entry.dir *= -1.0
	var i := clampi(int(entry.at), 0, road.path.size() - 2)
	var t: float = entry.at - i
	var tangent: Vector2 = road.tangents[i]
	var normal: Vector2 = Vector2(-tangent.y, tangent.x) * entry.side
	var spot: Vector2 = road.path[i].lerp(road.path[i + 1], t) + normal * (road.width * 0.5 + road.walk * 0.62)
	var person: Node3D = entry.person
	var near: bool = spot.distance_to(peter) < NEAR_PERSON * 2.0
	if person.visible != near:
		person.visible = near
		person.set_running(near)
	if near:
		person.global_position = Vector3(spot.x, plan.KERB, spot.y)
		person.rotation.y = atan2(tangent.x * entry.dir, tangent.y * entry.dir)

# Passing too close to traffic only costs a little speed.
func brush(peter: CharacterBody3D) -> void:
	var at := Vector2(peter.global_position.x, peter.global_position.z)
	for entry in riders:
		if entry.person.visible and Vector2(entry.person.global_position.x, entry.person.global_position.z).distance_squared_to(at) < 1.4:
			peter.speed *= 0.97
