extends Node3D
# The Ferris wheel at the fair on the wall of the box (land_fold.gd), built here so it can turn
# and be ridden. Two white rims on dark blue legs, spokes, a hub, twelve red and white cabins that
# hang level as the wheel turns, bulbs round both rims. It turns slowly all the time.
# Riding it: step up to the boarding platform and press E. The wheel eases round until a cabin is
# at the platform, the player sits in it, and it climbs very slowly to the top. On the way up a
# night sky opens over the fair (star_dome.gdshader: stars, the Milky Way, a moon), the box's far
# faces hidden behind it; the cabin drifts over the top for about twenty-five seconds, then comes
# back down and the player steps out where they got in. Looking round works the whole time.
# Local frame: the wheel's axle is local X; local Y is the wall's up; the platform is on +Z.
signal ride_over
const DOME := preload("res://assets/materials/star_dome.gdshader")
const RADIUS := 16.5
const HUB := 19.6
const CABINS := 12
const RIM_GAP := 1.0
# The cabins hang outside the rims, every other one on each side, so the view from a cabin is
# open on its outer side and overhead: nothing of the wheel between the rider and the sky.
const CABIN_X := 3.3
const LEG_X := 5.4
const HANG := 2.6
const IDLE := 0.035
# The ride: up, over the top, down (seconds); phase is the cabin's angle from the bottom.
const BOARD := 2.4
const UP := 15.0
const OVER := 25.0
const DOWN := 15.0
const OVER_FROM := 0.93
const OVER_TO := 1.07
const SEAT_EYE := 1.15
const PLATFORM := Vector3(CABIN_X, 0, 3.6)
const REACH := 2.4

var spin: Node3D
var cabins: Array[Node3D] = []
var bases: Array[Vector3] = []
var turn := 0.0
var dome: MeshInstance3D
var dome_paint: ShaderMaterial
var rider: CharacterBody3D
var riding := -1
var ride_time := 0.0
var board_from := 0.0
var board_to := 0.0
var seat_from: Transform3D
var clock := 0.0

func build() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.16, 0.22, 0.42)
	steel.metallic = 0.5
	steel.roughness = 0.45
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.9, 0.9, 0.92)
	white.metallic = 0.3
	white.roughness = 0.35
	# Legs: an A-frame either side of the wheel, from the ground to the axle.
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			var foot := Vector3(side * (LEG_X + 0.4), 0, lean * 10.5)
			var top := Vector3(side * LEG_X, HUB, 0)
			_beam(self, foot, top, 0.5, steel)
		_beam(self, Vector3(side * (LEG_X + 0.3), 6.0, -7.4), Vector3(side * (LEG_X + 0.3), 6.0, 7.4), 0.3, steel)
	_beam(self, Vector3(-LEG_X - 0.3, HUB, 0), Vector3(LEG_X + 0.3, HUB, 0), 0.7, steel)
	# A base under each A-frame, and the boarding platform with a step.
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.3, 0.32, 0.36)
	concrete.roughness = 0.9
	for side: float in [-1.0, 1.0]:
		_box(self, AABB(Vector3(side * (LEG_X + 0.4) - 0.9, 0, -12.0), Vector3(1.8, 0.6, 24.0)), concrete, true)
	_box(self, AABB(Vector3(CABIN_X - 1.4, 0, 1.2), Vector3(2.8, 0.4, 3.4)), concrete, true)
	_box(self, AABB(Vector3(CABIN_X - 1.4, 0, 4.6), Vector3(2.8, 0.2, 0.7)), concrete, true)
	for side: float in [-1.0, 1.0]:
		_box(self, AABB(Vector3(CABIN_X + side * 1.4 - 0.04, 0.4, 1.2), Vector3(0.08, 1.0, 3.4)), white, false)
	# The turning part.
	spin = Node3D.new()
	spin.name = "Spin"
	spin.position = Vector3(0, HUB, 0)
	add_child(spin)
	for side: float in [-1.0, 1.0]:
		var rim := TorusMesh.new()
		rim.inner_radius = RADIUS - 0.18
		rim.outer_radius = RADIUS + 0.18
		rim.rings = 96
		rim.ring_segments = 8
		var ring := MeshInstance3D.new()
		ring.mesh = rim
		ring.material_override = white
		ring.position = Vector3(side * RIM_GAP, 0, 0)
		ring.rotation.z = PI / 2
		spin.add_child(ring)
		var inner := TorusMesh.new()
		inner.inner_radius = RADIUS * 0.55 - 0.12
		inner.outer_radius = RADIUS * 0.55 + 0.12
		inner.rings = 64
		inner.ring_segments = 6
		var ring2 := MeshInstance3D.new()
		ring2.mesh = inner
		ring2.material_override = white
		ring2.position = Vector3(side * RIM_GAP, 0, 0)
		ring2.rotation.z = PI / 2
		spin.add_child(ring2)
		for i in range(CABINS * 2):
			var a := TAU * i / float(CABINS * 2)
			_beam(spin, Vector3(side * RIM_GAP * 0.4, 0, 0), Vector3(side * RIM_GAP, -cos(a) * RADIUS, sin(a) * RADIUS), 0.12, white)
	var hub := CylinderMesh.new()
	hub.top_radius = 1.0
	hub.bottom_radius = 1.0
	hub.height = RIM_GAP * 2.0 + 0.6
	var hub_mesh := MeshInstance3D.new()
	hub_mesh.mesh = hub
	hub_mesh.material_override = white
	hub_mesh.rotation.z = PI / 2
	spin.add_child(hub_mesh)
	_bulbs()
	for i in range(CABINS):
		var a := TAU * i / float(CABINS)
		var side := 1.0 if i % 2 == 0 else -1.0
		var base := Vector3(side * CABIN_X, -cos(a) * RADIUS, sin(a) * RADIUS)
		bases.append(base)
		_beam(spin, Vector3(-side * RIM_GAP, base.y, base.z), base + Vector3(side * 0.1, 0, 0), 0.14, steel)
		var cabin := _cabin(i)
		cabins.append(cabin)
		add_child(cabin)
	var light := OmniLight3D.new()
	light.position = Vector3(0, HUB, 3.0)
	light.light_color = Color(0.9, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 30.0
	add_child(light)
	# The night sky that opens up over the top of the ride.
	var sphere := SphereMesh.new()
	sphere.radius = 140.0
	sphere.height = 280.0
	sphere.radial_segments = 64
	sphere.rings = 32
	dome_paint = ShaderMaterial.new()
	dome_paint.shader = DOME
	dome_paint.set_shader_parameter("appear", 0.0)
	# Drawn before everything else see-through, so the fireworks burst in front of it.
	dome_paint.render_priority = -100
	dome = MeshInstance3D.new()
	dome.name = "StarDome"
	dome.mesh = sphere
	dome.material_override = dome_paint
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position = Vector3(0, HUB, 0)
	dome.visible = false
	add_child(dome)
	_place()

func _beam(parent: Node3D, from: Vector3, to: Vector3, thick: float, paint: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(thick, thick, from.distance_to(to))
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = paint
	var along := (to - from).normalized()
	var side := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	node.transform = Transform3D(Basis.looking_at(along, side), (from + to) / 2)
	parent.add_child(node)

func _box(parent: Node3D, part: AABB, paint: Material, solid: bool) -> void:
	var box := BoxMesh.new()
	box.size = part.size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.material_override = paint
	node.position = part.get_center()
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = part.size
		shape.shape = cube
		shape.position = part.get_center()
		body.add_child(shape)
		parent.add_child(body)

# Bulbs all round both rims, warm and pink and blue in turn, turning with the wheel.
func _bulbs() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	sphere.material = glow
	var count := 72
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = sphere
	multi.instance_count = count * 2
	var colours := [Color(1.0, 0.8, 0.45), Color(1.0, 0.5, 0.65), Color(0.6, 0.8, 1.0)]
	for side in range(2):
		for i in range(count):
			var a := TAU * i / float(count)
			var at := Vector3((side * 2 - 1) * RIM_GAP, -cos(a) * (RADIUS + 0.25), sin(a) * (RADIUS + 0.25))
			multi.set_instance_transform(side * count + i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.2), at))
			multi.set_instance_color(side * count + i, colours[i % 3] * 3.0)
	var bulbs := MultiMeshInstance3D.new()
	bulbs.multimesh = multi
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin.add_child(bulbs)

# A cabin: a round floor and bench, a low wall, four posts, a striped roof, a bar up to the rim.
# Its origin is the pivot it hangs from; its floor is HANG below.
func _cabin(i: int) -> Node3D:
	var cabin := Node3D.new()
	cabin.name = "Cabin%d" % i
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.72, 0.08, 0.16) if i % 2 == 0 else Color(0.92, 0.9, 0.88)
	red.roughness = 0.4
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.92, 0.9, 0.85)
	cream.roughness = 0.5
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 1.15
	floor_mesh.bottom_radius = 1.0
	floor_mesh.height = 0.2
	_mesh(cabin, floor_mesh, Vector3(0, -HANG - 0.1, 0), red)
	var wall := CylinderMesh.new()
	wall.top_radius = 1.15
	wall.bottom_radius = 1.15
	wall.height = 0.55
	wall.cap_top = false
	wall.cap_bottom = false
	_mesh(cabin, wall, Vector3(0, -HANG + 0.27, 0), red)
	var bench := CylinderMesh.new()
	bench.top_radius = 0.95
	bench.bottom_radius = 0.95
	bench.height = 0.1
	_mesh(cabin, bench, Vector3(0, -HANG + 0.45, 0), cream)
	for k in range(4):
		var a := TAU * k / 4.0 + PI / 4
		var post := CylinderMesh.new()
		post.top_radius = 0.04
		post.bottom_radius = 0.04
		post.height = 1.95
		_mesh(cabin, post, Vector3(cos(a) * 0.55, -HANG + 1.55, sin(a) * 0.55), cream)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.12
	roof.bottom_radius = 0.8
	roof.height = 0.4
	var stripes := ShaderMaterial.new()
	stripes.shader = load("res://assets/materials/carousel_roof.gdshader")
	stripes.set_shader_parameter("stripes", 12.0)
	_mesh(cabin, roof, Vector3(0, -HANG + 2.7, 0), stripes)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.06
	bar.bottom_radius = 0.06
	bar.height = 0.35
	_mesh(cabin, bar, Vector3(0, -0.18, 0), cream)
	var lamp := MeshInstance3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.08
	bead.height = 0.16
	lamp.mesh = bead
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.6, 1.3, 0.8)
	lamp.material_override = glow
	lamp.position = Vector3(0, -HANG + 2.45, 0)
	cabin.add_child(lamp)
	return cabin

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, paint: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = paint
	node.position = at
	parent.add_child(node)

# Cabins hang level from wherever the wheel has carried their pivot, swaying a little.
func _place() -> void:
	spin.rotation.x = turn
	for i in range(CABINS):
		var pivot: Vector3 = spin.transform * bases[i]
		cabins[i].position = pivot
		cabins[i].rotation = Vector3(sin(clock * 0.7 + i) * 0.025, 0, sin(clock * 0.5 + i * 2.0) * 0.02)

# How far round from the bottom cabin i is, 0 to TAU, going the way the wheel turns.
func phase(i: int) -> float:
	var a := TAU * i / float(CABINS)
	return fposmod(a - turn, TAU)

func near_board(at: Vector3) -> bool:
	return riding < 0 and to_local(at).distance_to(PLATFORM + Vector3(0, 0.5, 0)) < REACH

func ride(walker: CharacterBody3D) -> void:
	rider = walker
	riding = 0
	var best := INF
	# Only the cabins on the platform's side of the wheel.
	for i in range(0, CABINS, 2):
		var p := phase(i)
		var off := minf(p, TAU - p)
		if off < best:
			best = off
			riding = i
	board_from = turn
	# The shortest way round until that cabin is at the bottom (a whole turn later the wheel
	# looks the same, so the ride can carry on from its own angle).
	var p := phase(riding)
	board_to = turn + p if p < PI else turn - (TAU - p)
	ride_time = 0.0
	seat_from = Transform3D(rider.global_basis, rider.global_position)
	rider.set_physics_process(false)
	rider.velocity = Vector3.ZERO

# The cabin's angle from the bottom over the ride.
func ride_phase(t: float) -> float:
	if t < UP:
		return PI * OVER_FROM * smoothstep(0.0, UP, t)
	if t < UP + OVER:
		return PI * lerpf(OVER_FROM, OVER_TO, (t - UP) / OVER)
	return PI * lerpf(OVER_TO, 2.0, smoothstep(UP + OVER, UP + OVER + DOWN, t))

func ride_length() -> float:
	return BOARD + UP + OVER + DOWN

# 0 at the bottom, 1 at the top.
func height_share() -> float:
	if riding < 0:
		return 0.0
	return 1.0 - absf(phase(riding) - PI) / PI

func _process(delta: float) -> void:
	clock += delta
	if riding < 0:
		turn -= IDLE * delta
		_place()
		return
	ride_time += delta
	var a := TAU * riding / float(CABINS)
	if ride_time < BOARD:
		turn = lerpf(board_from, board_to, smoothstep(0.0, BOARD, ride_time))
	else:
		turn = a - ride_phase(ride_time - BOARD)
	_place()
	var cabin := cabins[riding]
	var frame := global_basis.orthonormalized()
	# Sat by the rail on whichever side the eyes are turned to, so looking down sees the fair.
	var facing := Vector3(0, 0, -1).rotated(Vector3.UP, rider.yaw) * 0.6
	var floor_at := cabin.global_transform * Vector3(facing.x, -HANG, facing.z)
	rider.frame = frame
	rider.eye = SEAT_EYE
	if ride_time < BOARD:
		var k := smoothstep(BOARD * 0.4, BOARD, ride_time)
		rider.global_position = seat_from.origin.lerp(floor_at, k)
	else:
		rider.global_position = floor_at
	var sky := smoothstep(0.35, 0.8, height_share())
	dome_paint.set_shader_parameter("appear", sky)
	dome.visible = sky > 0.001
	if ride_time >= ride_length():
		_step_off()

func _step_off() -> void:
	var at := to_global(PLATFORM + Vector3(0, 0.45, 0.6))
	rider.global_position = at
	rider.eye = rider.EYE
	rider.velocity = Vector3.ZERO
	rider.set_physics_process(true)
	riding = -1
	rider = null
	dome.visible = false
	dome_paint.set_shader_parameter("appear", 0.0)
	ride_over.emit()
