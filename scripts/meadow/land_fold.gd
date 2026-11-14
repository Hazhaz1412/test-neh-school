extends Node3D
# At night the meadow turns out to be the floor of a box, seen along x a square with rounded
# corners and no end either way. A few steps past the bed the ground bends up a quarter circle
# into a wall of the same meadow, the fairground on it; over the top it bends again into the
# ceiling, a meadow hanging over the first one, where a path leads to an ordinary little house;
# and on round the far wall back down to the bed. Looking straight up from anywhere is looking at
# the face opposite. Gravity always points at the nearest face (up_at(), handed to
# dream_player.gd as its gravity_field) and turns a little with every step, so walking round the
# corners feels like walking on: no seam to see, no slope underfoot.
# Every face reaches HALF_X either way along x, far into the haze, so each one is a meadow to the
# horizon. The faces' ground and grass are the meadow's own shaders (meadow_ground and
# meadow_grass in box mode), laid out in box space: u along x, s round the box from the floor's
# near edge, so their pattern carries straight on from the meadow.
# The fairground: a Ferris wheel, a carousel built here round Quaternius's horse, a circus tent
# built here too, stalls, a popcorn cart, a high striker, lamps and hot-air balloons; the games
# come later (Marker3D "Game*"). The house is built here too, from Poly Haven textures; its
# inside comes later, for now its door is the way on.
# Every model and texture and its licence: assets/meadow/fair/sources.json, ASSETS.md.
signal reached_fair
signal reached_house
const FAIR := "res://assets/meadow/fair/%s.glb"
const PAVING := "res://assets/polyhaven_meadow/herringbone_pavement_%s_1k.jpg"
const BRICK := "res://assets/polyhaven_meadow/red_bricks_04_%s_1k.jpg"
const SLATE := "res://assets/polyhaven_meadow/roof_slates_03_%s_1k.jpg"
const TRACK := "res://assets/polyhaven_meadow/grass_path_2_%s_1k.jpg"
const SHRUB := "res://assets/polyhaven_meadow/shrub_01/shrub_01_1k.gltf"
const DANDELION := "res://assets/polyhaven_meadow/dandelion_01/dandelion_01_1k.gltf"
const GROUND := preload("res://assets/materials/meadow_ground.gdshader")
const GRASS := preload("res://assets/materials/meadow_grass.gdshader")
const MUSIC := "res://assets/music/fair_rollup.ogg"
# The box, as in the box_* defaults of meadow_grass.gdshader (set from here anyway).
# Big enough to be lost in: the faces are 220 m apart, the corners as wide as low hills, and the
# night haze (dream_meadow.gd make_night) turns the far faces to mist.
const R := 36.0
const Y0 := 0.0
const Z0 := -44.0
const SIZE := 220.0
# The floor's two edges in z: the meadow is kept, and flattened, between them.
const BEND_Z := Z0 + R
const FAR_Z := Z0 + SIZE - R
const HALF_X := 2400.0
const GRASS_HALF := 64.0
# Walkers are kept this close to x = 0 (the floor's collider ends at 200).
const WALK_X := 170.0
# Along the wall, where the fair's middle is; along the ceiling, where the house is.
const FAIR_AT := 24.0
const HOUSE_AT := 18.0
const PLAZA := 20.0
const PATH_HALF := 1.2
const DOOR_REACH := 2.0

var arc := R * PI / 2
var wall := SIZE - 2.0 * R
var around := 4.0 * arc + 3.0 * wall
var fair_s := 0.0
var house_s := 0.0
var fair: Node3D
var house: Node3D
var door_hinge: Node3D
var door_open := 0.0
var opening := false
var bulbs: Array[Transform3D] = []
var bulb_colours: Array[Color] = []
var paving: StandardMaterial3D
var carousel: Node3D
var horses: Array[Node3D] = []
var balloons: Array[Dictionary] = []
var clock := 0.0
var shown := false
var told_fair := false
var told_house := false
var tent_door: Node3D
var music: AudioStreamPlayer3D
var grass_materials: Array[ShaderMaterial] = []

# The box at distance s round it: [ground (y, z), up (y, z)]. Must match tube() in the shader.
func tube(s: float) -> Array:
	var y1 := Y0 + SIZE
	var z1 := Z0 + SIZE
	if s < arc:
		var t := s / R
		return [Vector2(Y0 + R - R * cos(t), Z0 + R - R * sin(t)), Vector2(cos(t), sin(t))]
	s -= arc
	if s < wall:
		return [Vector2(Y0 + R + s, Z0), Vector2(0, 1)]
	s -= wall
	if s < arc:
		var t := s / R
		return [Vector2(y1 - R + R * sin(t), Z0 + R - R * cos(t)), Vector2(-sin(t), cos(t))]
	s -= arc
	if s < wall:
		return [Vector2(y1, Z0 + R + s), Vector2(-1, 0)]
	s -= wall
	if s < arc:
		var t := s / R
		return [Vector2(y1 - R + R * cos(t), z1 - R + R * sin(t)), Vector2(-cos(t), -sin(t))]
	s -= arc
	if s < wall:
		return [Vector2(y1 - R - s, z1), Vector2(0, -1)]
	s -= wall
	var t := clampf(s / R, 0.0, PI / 2)
	return [Vector2(Y0 + R - R * sin(t), z1 - R + R * cos(t)), Vector2(sin(t), -cos(t))]

func point(u: float, s: float) -> Vector3:
	var g: Vector2 = tube(s)[0]
	return Vector3(u, g.x, g.y)

func up_of(s: float) -> Vector3:
	var n: Vector2 = tube(s)[1]
	return Vector3(0, n.x, n.y)

# The way round the box at s (increasing s), on the ground.
func along_of(s: float) -> Vector3:
	return (point(0, s + 0.05) - point(0, s - 0.05)).normalized()

# Up for a walker at `at` (feet): towards the middle of the box from the nearest face. The faces
# are the points R from the inner rectangle; up is from the walker to that rectangle.
func up_at(at: Vector3) -> Vector3:
	if not shown:
		return Vector3.UP
	if at.z < Z0 - 6.0 or at.z > Z0 + SIZE + 6.0 or at.y < Y0 - 12.0 or at.y > Y0 + SIZE + 6.0:
		return Vector3.UP
	var core := Vector2(clampf(at.y, Y0 + R, Y0 + SIZE - R), clampf(at.z, Z0 + R, Z0 + SIZE - R))
	var to := core - Vector2(at.y, at.z)
	if to.length() > 0.01:
		to = to.normalized()
		return Vector3(0, to.x, to.y)
	# Out in the middle of the box (a long float): towards the middle from the nearest face.
	var gaps := [at.y - Y0, Y0 + SIZE - at.y, at.z - Z0, Z0 + SIZE - at.z]
	var ups := [Vector3.UP, Vector3.DOWN, Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var best := 0
	for i in range(4):
		if gaps[i] < gaps[best]:
			best = i
	return ups[best]

# `blade` makes a grass blade mesh with that many segments; `share` is the graphics setting's
# share of grass. Both come from dream_meadow.gd so the box's grass is the meadow's.
func build(blade: Callable, share: float, near_end: float) -> void:
	fair_s = arc + FAIR_AT
	house_s = 2.0 * arc + wall + HOUSE_AT
	paving = _textured(PAVING, 1.0)
	paving.albedo_color = Color(0.95, 0.88, 0.8)
	_ground()
	_grass(blade, share, near_end)
	_fair()
	_path()
	_house()
	_bulb_strings()
	music = AudioStreamPlayer3D.new()
	var loop: AudioStreamOggVorbis = load(MUSIC)
	loop.loop = true
	music.stream = loop
	music.unit_size = 28.0
	music.max_db = 2.0
	music.volume_db = -80.0
	music.attenuation_filter_cutoff_hz = 9000.0
	fair.add_child(music)
	music.position = Vector3(12, 4, 6)
	visible = false
	set_collision(false)

func _textured(path: String, tint := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path % "diff")
	material.normal_enabled = true
	material.normal_texture = load(path % "nor_gl")
	material.roughness_texture = load(path % "rough")
	material.albedo_color = Color(tint, tint, tint)
	return material

# Across the box: fine near the middle, wider and wider out towards HALF_X.
func _columns() -> Array[float]:
	var half: Array[float] = [0.0]
	var step := 2.0
	while half[-1] < HALF_X:
		half.append(minf(half[-1] + step, HALF_X))
		if half[-1] > 40.0:
			step *= 1.12
	var all: Array[float] = []
	for i in range(half.size() - 1, 0, -1):
		all.append(-half[i])
	all.append_array(half)
	return all

func _steps() -> Array[float]:
	var steps: Array[float] = []
	var s := 0.0
	while s < around:
		steps.append(s)
		var on_arc := fmod(s, arc + wall) < arc
		s += 0.6 if on_arc else 4.0
	steps.append(around)
	return steps

# The box's earth: the meadow's own ground shader on a sheet running round three faces and the
# corners, out to HALF_X both ways, and the same sheet (near the middle) as its collider.
func _ground() -> void:
	var columns := _columns()
	var steps := _steps()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_tool := SurfaceTool.new()
	near_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(steps.size() - 1):
		var s0: float = steps[i]
		var s1: float = steps[i + 1]
		for c in range(columns.size() - 1):
			var u0: float = columns[c]
			var u1: float = columns[c + 1]
			var a := point(u0, s0)
			var b := point(u1, s0)
			var d := point(u1, s1)
			var e := point(u0, s1)
			for target: SurfaceTool in ([tool, near_tool] if absf(u0) < 260.0 and absf(u1) < 260.0 else [tool]):
				_tri(target, a, Vector2(u0, s0), e, Vector2(u0, s1), d, Vector2(u1, s1))
				_tri(target, a, Vector2(u0, s0), d, Vector2(u1, s1), b, Vector2(u1, s0))
	tool.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = GROUND
	material.set_shader_parameter("albedo_tex", load("res://assets/polyhaven_meadow/leafy_grass_diff_1k.jpg"))
	material.set_shader_parameter("normal_tex", load("res://assets/polyhaven_meadow/leafy_grass_nor_gl_1k.jpg"))
	material.set_shader_parameter("fold_uv", true)
	material.set_shader_parameter("fold_bend_z", BEND_Z)
	var surface := MeshInstance3D.new()
	surface.name = "BoxGround"
	surface.mesh = tool.commit()
	surface.material_override = material
	surface.extra_cull_margin = 50.0
	add_child(surface)
	var body := StaticBody3D.new()
	body.name = "FoldBody"
	var shape := CollisionShape3D.new()
	shape.shape = near_tool.commit().create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

func _tri(tool: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	tool.set_uv(ua)
	tool.add_vertex(a)
	tool.set_uv(ub)
	tool.add_vertex(b)
	tool.set_uv(uc)
	tool.add_vertex(c)

# The meadow's three grass layers again, chunked in box space near x = 0; each chunk tells the
# shader where it is (instance uniform fold_chunk) and the shader stands its blades on the box.
func _grass(blade: Callable, share: float, near_end: float) -> void:
	var layers := [[8.0, int(4800 * share), 0.42, 0.032, 4, 0.0, near_end, GRASS_HALF],
		[16.0, int(5600 * share), 0.48, 0.06 / sqrt(share), 2, near_end - 4.0, 75.0, GRASS_HALF + 32.0],
		[32.0, int(3600 * share), 0.62, 0.15 / sqrt(share), 1, 66.0, 235.0, 224.0]]
	var holder := Node3D.new()
	holder.name = "BoxGrass"
	add_child(holder)
	for plan: Array in layers:
		var chunk: float = plan[0]
		var half: float = plan[7]
		var material := ShaderMaterial.new()
		material.shader = GRASS
		material.set_shader_parameter("chunk", chunk)
		material.set_shader_parameter("blade_height", plan[2])
		material.set_shader_parameter("blade_width", plan[3])
		material.set_shader_parameter("on_fold", true)
		material.set_shader_parameter("fold_half", half)
		_box_uniforms(material)
		material.set_shader_parameter("fold_clear", Vector3(0, fair_s, PLAZA + 0.5))
		material.set_shader_parameter("fold_clear2", Vector3(0, house_s, 5.5))
		material.set_shader_parameter("fold_path", Vector3(PATH_HALF + 0.2, fair_s + PLAZA - 1.0, house_s))
		grass_materials.append(material)
		var mesh: Mesh = blade.call(plan[4])
		mesh.surface_set_material(0, material)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = plan[1]
		var identity := PackedFloat32Array()
		identity.resize(multi.instance_count * 12)
		for i in range(multi.instance_count):
			identity[i * 12] = 1.0
			identity[i * 12 + 5] = 1.0
			identity[i * 12 + 10] = 1.0
		multi.buffer = identity
		var cu := int(ceil(2.0 * half / chunk))
		var cs := int(ceil(around / chunk))
		for i in range(cu):
			for j in range(cs):
				var us := Vector2(-half + (i + 0.5) * chunk, (j + 0.5) * chunk)
				var centre := point(us.x, us.y)
				var patch := MultiMeshInstance3D.new()
				patch.multimesh = multi
				patch.position = centre
				patch.set_instance_shader_parameter("fold_chunk", us)
				var box := AABB(point(us.x - chunk / 2, us.y - chunk / 2) - centre, Vector3.ZERO)
				for k in range(5):
					var ss := us.y - chunk / 2 + chunk * k / 4.0
					box = box.expand(point(us.x - chunk / 2, ss) - centre).expand(point(us.x + chunk / 2, ss) - centre)
				patch.custom_aabb = box.grow(1.5)
				patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				patch.visibility_range_begin = plan[5]
				patch.visibility_range_begin_margin = 4.0 if plan[5] > 0.0 else 0.0
				patch.visibility_range_end = plan[6]
				patch.visibility_range_end_margin = 4.0
				patch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				holder.add_child(patch)

# The box's measurements, for any material using meadow_grass.gdshader (the meadow's too).
static func _box_uniforms(material: ShaderMaterial) -> void:
	material.set_shader_parameter("box_radius", R)
	material.set_shader_parameter("box_y0", Y0)
	material.set_shader_parameter("box_z0", Z0)
	material.set_shader_parameter("box_size", SIZE)

static func box_uniforms(material: ShaderMaterial) -> void:
	_box_uniforms(material)

# A model from the fairground set scaled to `height` (along its own up), its base on the origin.
func _fit(name: String, height: float, along := "y") -> Node3D:
	var model: Node3D = load(FAIR % name).instantiate()
	var holder := Node3D.new()
	holder.add_child(model)
	var box := _bounds(holder)
	var size: float = box.size.y if along == "y" else maxf(box.size.x, box.size.z)
	var k := height / maxf(size, 0.0001)
	model.scale = Vector3.ONE * k
	box = _bounds(holder)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return holder

func _bounds(holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: VisualInstance3D in holder.find_children("*", "VisualInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var node: Node = mesh
		while node != holder:
			t = (node as Node3D).transform * t
			node = node.get_parent()
		var b := t * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

# A warm point of light at a lamp: a bright bead, and a real light on every other one.
func _glow(parent: Node3D, at: Vector3, colour: Color, with_light: bool) -> void:
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = colour
		light.light_energy = 1.6
		light.omni_range = 7.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		add_child(light)
		light.global_position = at
	bulbs.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.22), at))
	bulb_colours.append(colour)

func _bulb_mesh() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	# Unshaded and HDR-bright through the instance colour (x3), so the glow picks them up.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	sphere.material = glow
	return sphere

func _bulb_strings() -> void:
	var sphere := _bulb_mesh()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = sphere
	multi.instance_count = bulbs.size()
	for i in range(bulbs.size()):
		multi.set_instance_transform(i, bulbs[i])
		multi.set_instance_color(i, bulb_colours[i] * 3.0)
	var holder := MultiMeshInstance3D.new()
	holder.name = "Bulbs"
	holder.multimesh = multi
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)

# The fairground on the wall, built in its own frame: local y is the wall's up (+Z in the world),
# local -Z carries on round the box (+Y in the world). Its middle is FAIR_AT up the wall.
func _fair() -> void:
	fair = Node3D.new()
	fair.name = "Fair"
	var centre := point(0.0, fair_s)
	fair.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), centre)
	add_child(fair)
	# A paved circle laid flat on the grass (drawn only: the ground under it is what is walked on,
	# so there is no rim to catch a foot).
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = PLAZA
	floor_mesh.bottom_radius = PLAZA
	floor_mesh.height = 0.06
	floor_mesh.radial_segments = 96
	var plaza := MeshInstance3D.new()
	plaza.mesh = floor_mesh
	var tiles := paving.duplicate()
	tiles.uv1_triplanar = true
	tiles.uv1_scale = Vector3.ONE * 0.5
	plaza.material_override = tiles
	plaza.position.y = 0.0
	fair.add_child(plaza)
	_fair_lamps()
	var wheel := _fit("ferris_wheel", 30.0)
	wheel.position = Vector3(-22, 0, -12)
	wheel.rotation.y = deg_to_rad(65)
	fair.add_child(wheel)
	_solid(fair, Vector3(-22, 0, -12), Vector3(10, 30, 6), deg_to_rad(65))
	_carousel(Vector3(12, 0, 2))
	# Off to the side of the way through, so the path up from the fair runs clear of it.
	_big_top(Vector3(22, 0, -28))
	var stalls := [[Vector3(-14, 0, 16), 40.0], [Vector3(-26, 0, 6), 75.0], [Vector3(24, 0, 14), -45.0]]
	for i in range(stalls.size()):
		var booth := _fit("carnival_booth", 3.2)
		booth.position = stalls[i][0]
		booth.rotation.y = deg_to_rad(stalls[i][1])
		fair.add_child(booth)
		_solid(fair, stalls[i][0], Vector3(3.4, 3.2, 2.0), deg_to_rad(stalls[i][1]))
		var bunch := _fit("balloons", 2.6)
		bunch.position = stalls[i][0] + Vector3(1.8, 1.6, 0.8).rotated(Vector3.UP, deg_to_rad(stalls[i][1]))
		fair.add_child(bunch)
		var mark := Marker3D.new()
		mark.name = "GameStall%d" % (i + 1)
		mark.position = stalls[i][0]
		fair.add_child(mark)
	var cart := _fit("popcorn_cart", 2.2)
	cart.position = Vector3(-4, 0, 14)
	cart.rotation.y = deg_to_rad(-20)
	fair.add_child(cart)
	_solid(fair, Vector3(-4, 0, 14), Vector3(1.8, 2.2, 1.2), deg_to_rad(-20))
	var striker := _fit("high_striker", 6.0)
	striker.position = Vector3(-8, 0, -6)
	striker.rotation.y = deg_to_rad(20)
	fair.add_child(striker)
	_solid(fair, Vector3(-8, 0, -6), Vector3(1.6, 6.0, 1.4), deg_to_rad(20))
	for plan: Array in [[Vector3(-14, 9, -8), Color(1.0, 0.72, 0.5), 26.0, 2.2], [Vector3(12, 7, 2), Color(1.0, 0.6, 0.65), 20.0, 1.8],
			[Vector3(0, 12, 6), Color(0.95, 0.85, 0.75), 34.0, 1.6], [Vector3(-12, 6, 16), Color(0.7, 0.8, 1.0), 18.0, 1.2]]:
		var lamp := OmniLight3D.new()
		lamp.position = plan[0]
		lamp.light_color = plan[1]
		lamp.omni_range = plan[2]
		lamp.light_energy = plan[3]
		lamp.omni_attenuation = 0.8
		fair.add_child(lamp)
	var game := Marker3D.new()
	game.name = "GameStriker"
	game.position = Vector3(-8, 0, -4)
	fair.add_child(game)
	for plan: Array in [["hot_air_balloon_red", Vector3(-30, 26, -40), 14.0], ["hot_air_balloon_blue", Vector3(34, 34, -20), 12.0], ["hot_air_balloon_red", Vector3(10, 40, 12), 10.0]]:
		var balloon := _fit(plan[0], plan[2])
		balloon.position = plan[1]
		fair.add_child(balloon)
		balloons.append({"node": balloon, "home": plan[1], "phase": balloons.size() * 2.1})

# Lamps round the paved circle, and strings of bulbs across it from a mast in the middle.
func _fair_lamps() -> void:
	var down := -fair.global_basis.y.normalized()
	var mast := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.18
	pole.height = 11.0
	mast.mesh = pole
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.82, 0.78)
	mast.material_override = paint
	mast.position = Vector3(0, 5.5, 0)
	fair.add_child(mast)
	_solid(fair, Vector3(0, 0, 0), Vector3(0.5, 11, 0.5), 0.0)
	var mast_top := fair.to_global(Vector3(0, 11, 0))
	for i in range(12):
		var a := TAU * i / 12.0
		var at := Vector3(cos(a), 0, sin(a)) * (PLAZA - 1.0)
		var post := _fit("post_lantern", 3.2)
		post.position = at
		post.rotation.y = -a - PI / 2
		fair.add_child(post)
		var lamp := fair.to_global(at + Vector3(0, 2.7, 0) - Vector3(cos(a), 0, sin(a)) * 0.45)
		_glow(fair, lamp, Color(1.0, 0.8, 0.5), i % 3 == 0)
		_string(mast_top, fair.to_global(at + Vector3(0, 3.1, 0)), 1.2, 22, down)

# A sagging string of little coloured bulbs between two points.
func _string(from: Vector3, to: Vector3, sag: float, count: int, down: Vector3) -> void:
	var colours := [Color(1.0, 0.75, 0.4), Color(1.0, 0.45, 0.55), Color(0.55, 0.8, 1.0), Color(0.75, 1.0, 0.6), Color(1.0, 0.9, 0.55)]
	for i in range(1, count):
		var t := i / float(count)
		var at := from.lerp(to, t) + down * sag * 4.0 * t * (1.0 - t)
		bulbs.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.09), at))
		bulb_colours.append(colours[(i + bulbs.size()) % colours.size()])

func _solid(parent: Node3D, at: Vector3, size: Vector3, turn: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at + Vector3(0, size.y / 2, 0)
	body.rotation.y = turn
	parent.add_child(body)

# A carousel: a round deck turning under a striped cone of a roof, horses rising and falling on
# brass poles, a ring of bulbs under the eaves.
func _carousel(at: Vector3) -> void:
	carousel = Node3D.new()
	carousel.name = "Carousel"
	carousel.position = at
	fair.add_child(carousel)
	var spin := Node3D.new()
	spin.name = "Spin"
	carousel.add_child(spin)
	var deck := CylinderMesh.new()
	deck.top_radius = 5.5
	deck.bottom_radius = 5.6
	deck.height = 0.5
	deck.radial_segments = 48
	var deck_paint := StandardMaterial3D.new()
	deck_paint.albedo_color = Color(0.55, 0.3, 0.2)
	deck_paint.roughness = 0.5
	_mesh(spin, deck, Vector3(0, 0.25, 0), deck_paint)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.75, 0.35)
	gold.metallic = 0.85
	gold.roughness = 0.3
	var centre := CylinderMesh.new()
	centre.top_radius = 0.9
	centre.bottom_radius = 0.9
	centre.height = 4.6
	var centre_paint := StandardMaterial3D.new()
	centre_paint.albedo_color = Color(0.95, 0.85, 0.75)
	_mesh(spin, centre, Vector3(0, 2.8, 0), centre_paint)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 6.4
	roof.height = 2.6
	roof.radial_segments = 32
	var stripes := ShaderMaterial.new()
	stripes.shader = load("res://assets/materials/carousel_roof.gdshader")
	_mesh(spin, roof, Vector3(0, 6.3, 0), stripes)
	var horse_count := 8
	for i in range(horse_count):
		var a := TAU * i / horse_count
		var spot := Vector3(cos(a), 0, sin(a)) * 4.2
		var rod := CylinderMesh.new()
		rod.top_radius = 0.05
		rod.bottom_radius = 0.05
		rod.height = 4.6
		_mesh(spin, rod, spot + Vector3(0, 2.8, 0), gold)
		var horse := _fit("white_horse", 1.7)
		horse.position = spot + Vector3(0, 1.0, 0)
		# Facing round the ring.
		horse.rotation.y = -a
		spin.add_child(horse)
		horses.append(horse)
	# Its ring of bulbs under the eaves turns with it, so it is a MultiMesh of its own on the spinner.
	var ring := MultiMesh.new()
	ring.transform_format = MultiMesh.TRANSFORM_3D
	ring.use_colors = true
	ring.mesh = _bulb_mesh()
	ring.instance_count = 28
	for i in range(28):
		var a := TAU * i / 28.0
		ring.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.18), Vector3(cos(a) * 6.2, 5.0, sin(a) * 6.2)))
		ring.set_instance_color(i, [Color(1.0, 0.8, 0.45), Color(1.0, 0.5, 0.6)][i % 2] * 3.0)
	var ring_node := MultiMeshInstance3D.new()
	ring_node.multimesh = ring
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin.add_child(ring_node)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 3.0
	light.omni_range = 11.0
	light.position = Vector3(0, 4.5, 0)
	carousel.add_child(light)
	_solid(fair, at, Vector3(11, 7.6, 11), 0.0)
	var mark := Marker3D.new()
	mark.name = "GameCarousel"
	mark.position = at + Vector3(0, 0, 6.5)
	fair.add_child(mark)

# The circus tent: striped round wall, striped cone roof, a pennant on top, and a dark doorway
# with a warm light inside, facing the plaza. Walking into it is the way on for now.
func _big_top(at: Vector3) -> void:
	var tent := Node3D.new()
	tent.name = "BigTop"
	tent.position = at
	fair.add_child(tent)
	var wall_paint := ShaderMaterial.new()
	wall_paint.shader = load("res://assets/materials/carousel_roof.gdshader")
	wall_paint.set_shader_parameter("stripes", 24.0)
	var wall := CylinderMesh.new()
	wall.top_radius = 8.0
	wall.bottom_radius = 8.0
	wall.height = 5.0
	wall.radial_segments = 48
	wall.cap_top = false
	_mesh(tent, wall, Vector3(0, 2.5, 0), wall_paint)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.2
	roof.bottom_radius = 8.8
	roof.height = 6.0
	roof.radial_segments = 48
	var roof_paint := ShaderMaterial.new()
	roof_paint.shader = load("res://assets/materials/carousel_roof.gdshader")
	roof_paint.set_shader_parameter("stripes", 20.0)
	_mesh(tent, roof, Vector3(0, 8.0, 0), roof_paint)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 3.0
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.93, 0.88)
	_mesh(tent, pole, Vector3(0, 12.4, 0), white)
	var flag := BoxMesh.new()
	flag.size = Vector3(1.4, 0.7, 0.03)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.15)
	_mesh(tent, flag, Vector3(0.75, 13.4, 0), red)
	# The doorway: a dark opening with lamplight in it, on the side towards the plaza (+Z).
	var door := BoxMesh.new()
	door.size = Vector3(3.0, 3.6, 0.1)
	var inside := StandardMaterial3D.new()
	inside.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inside.albedo_color = Color(0.55, 0.32, 0.12)
	_mesh(tent, door, Vector3(0, 1.8, 7.97), inside)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.4)
	glow.light_energy = 2.5
	glow.omni_range = 6.0
	glow.position = Vector3(0, 2.0, 9.0)
	tent.add_child(glow)
	for i in range(24):
		var a := TAU * i / 24.0
		bulbs.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.16), fair.to_global(at + Vector3(cos(a) * 8.9, 5.05, sin(a) * 8.9))))
		bulb_colours.append([Color(1.0, 0.8, 0.45), Color(1.0, 0.45, 0.55), Color(0.55, 0.8, 1.0)][i % 3])
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 8.0
	cylinder.height = 11.0
	shape.shape = cylinder
	shape.position.y = 5.5
	body.add_child(shape)
	tent.add_child(body)
	tent_door = Node3D.new()
	tent_door.name = "TentDoor"
	tent_door.position = at + Vector3(0, 0, 8.6)
	fair.add_child(tent_door)

func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

# A footpath of packed earth and stones from the top of the fair, up the wall, round the corner
# and along the ceiling to the house's door, lit by lanterns at its sides.
func _path() -> void:
	var from := fair_s + PLAZA - 1.0
	var to := house_s - 3.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := from
	while s < to:
		var s1 := minf(s + 0.5, to)
		var lift0 := up_of(s) * 0.05
		var lift1 := up_of(s1) * 0.05
		var a := point(-PATH_HALF, s) + lift0
		var b := point(PATH_HALF, s) + lift0
		var d := point(PATH_HALF, s1) + lift1
		var e := point(-PATH_HALF, s1) + lift1
		_tri(tool, a, Vector2(0, s / 2.4), e, Vector2(0, s1 / 2.4), d, Vector2(1, s1 / 2.4))
		_tri(tool, a, Vector2(0, s / 2.4), d, Vector2(1, s1 / 2.4), b, Vector2(1, s / 2.4))
		s = s1
	tool.generate_normals()
	tool.generate_tangents()
	var track := MeshInstance3D.new()
	track.name = "Path"
	track.mesh = tool.commit()
	track.material_override = _textured(TRACK, 0.9)
	add_child(track)
	var lamp_s := from + 4.0
	var k := 0
	while lamp_s < to - 2.0:
		var frame := Basis(Vector3.RIGHT, up_of(lamp_s), -along_of(lamp_s))
		for side: float in [-1.0, 1.0]:
			var post := _fit("post_lantern", 2.6)
			post.transform = Transform3D(frame * Basis(Vector3.UP, PI / 2 * side), point(side * (PATH_HALF + 0.5), lamp_s))
			add_child(post)
			_glow(self, point(side * (PATH_HALF + 0.1), lamp_s) + up_of(lamp_s) * 2.15, Color(1.0, 0.78, 0.45), k % 2 == 0)
			k += 1
		lamp_s += 9.0

# An ordinary little house on the ceiling: red brick, a slate roof with its gable to the path, a
# chimney, a white door between two steps and bushes, a window beside it with a box of flowers,
# a round attic window, warm light behind the glass. Built in its own frame: local y is the
# ceiling's up (down in the world), local +Z faces back along the path.
func _house() -> void:
	house = Node3D.new()
	house.name = "House"
	var up := up_of(house_s)
	var back := -along_of(house_s)
	house.transform = Transform3D(Basis(up.cross(back), up, back), point(0, house_s))
	add_child(house)
	var brick := _textured(BRICK)
	brick.uv1_triplanar = true
	brick.uv1_scale = Vector3.ONE * 0.45
	var slate := _textured(SLATE, 0.75)
	slate.uv1_triplanar = true
	slate.uv1_scale = Vector3.ONE * 0.35
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.94, 0.93, 0.9)
	white.roughness = 0.5
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.62, 0.6)
	stone.roughness = 0.9
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.25, 0.2, 0.12)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.78, 0.45)
	glass.emission_energy_multiplier = 0.7
	glass.roughness = 0.1
	const W := 6.4
	const D := 5.6
	const H := 3.6
	const RIDGE := 2.6
	_block(house, Vector3(W, H, D), Vector3(0, H / 2, 0), brick)
	_block(house, Vector3(W + 0.2, 0.25, D + 0.2), Vector3(0, 0.12, 0), stone)
	# Gables front and back, then the two slopes of the roof, with a white edge.
	for z: float in [D / 2, -D / 2]:
		_prism(house, W, RIDGE, 0.0, H, z, brick)
	var slope := Vector2(W / 2 + 0.45, RIDGE + 0.3).length()
	var tilt := atan2(RIDGE + 0.3, W / 2 + 0.45)
	for side: float in [-1.0, 1.0]:
		var roof := _block(house, Vector3(slope, 0.18, D + 0.8), Vector3(side * (W / 4 + 0.1), H + RIDGE / 2 + 0.05, 0), slate)
		roof.rotation.z = -side * tilt
		var trim := _block(house, Vector3(slope, 0.08, 0.14), Vector3(side * (W / 4 + 0.1), H + RIDGE / 2 - 0.03, D / 2 + 0.42), white)
		trim.rotation.z = -side * tilt
	_block(house, Vector3(0.9, 2.2, 0.9), Vector3(W / 2 - 1.1, H + RIDGE - 0.2, -D / 4), brick)
	_block(house, Vector3(1.05, 0.15, 1.05), Vector3(W / 2 - 1.1, H + RIDGE + 0.95, -D / 4), stone)
	# The door, on its hinge so it can swing in.
	var front := D / 2 + 0.02
	_block(house, Vector3(1.4, 2.5, 0.08), Vector3(-0.9, 1.45, front), white)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0, 0, 0)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_block(house, Vector3(1.1, 2.2, 0.02), Vector3(-0.9, 1.36, front + 0.03), dark)
	door_hinge = Node3D.new()
	door_hinge.position = Vector3(-1.45, 0.26, front + 0.06)
	house.add_child(door_hinge)
	var leaf := _block(door_hinge, Vector3(1.1, 2.2, 0.06), Vector3(0.55, 1.1, 0), white)
	for row in range(3):
		_block(leaf, Vector3(0.75, 0.48 if row > 0 else 0.3, 0.03), Vector3(0, 0.62 - row * 0.62, 0.04), white)
	var knob := _block(door_hinge, Vector3(0.07, 0.07, 0.08), Vector3(0.95, 1.05, 0.07), stone)
	knob.name = "Knob"
	# Window beside the door, with its flower box; a smaller one up in the gable.
	_window(house, Vector3(1.55, 1.7, front), Vector2(1.2, 1.1), white, glass)
	_block(house, Vector3(1.4, 0.25, 0.3), Vector3(1.55, 0.98, front + 0.15), Color(0.35, 0.22, 0.12))
	for i in range(4):
		var flower: Node3D = load(DANDELION).instantiate()
		flower.position = Vector3(1.05 + i * 0.33, 1.1, front + 0.15)
		flower.scale = Vector3.ONE * 1.3
		flower.rotation.y = i * 1.7
		house.add_child(flower)
	_window(house, Vector3(0, H + 0.9, front), Vector2(0.9, 0.8), white, glass)
	for x: float in [-W / 2 + 0.5, W / 2 - 0.5]:
		_window(house, Vector3(x * 0.55, 1.7, -front), Vector2(1.0, 1.0), white, glass, PI)
	# Two steps up to the door, and a bush either side of them.
	_block(house, Vector3(1.8, 0.18, 0.5), Vector3(-0.9, 0.09, front + 0.25), stone)
	_block(house, Vector3(1.5, 0.18, 0.35), Vector3(-0.9, 0.27, front + 0.15), stone)
	for x: float in [-2.4, 0.6]:
		var bush: Node3D = load(SHRUB).instantiate()
		bush.position = Vector3(x, 0, front + 0.6)
		bush.scale = Vector3.ONE * 0.55
		house.add_child(bush)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 0.7
	lamp.omni_range = 11.0
	lamp.omni_attenuation = 0.7
	lamp.position = Vector3(0.3, 4.2, front + 3.5)
	house.add_child(lamp)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H + RIDGE, D)
	shape.shape = box
	shape.position = Vector3(0, (H + RIDGE) / 2, 0)
	body.add_child(shape)
	house.add_child(body)
	var mark := Marker3D.new()
	mark.name = "Inside"
	house.add_child(mark)

func _block(parent: Node3D, size: Vector3, at: Vector3, material: Variant) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material is Color:
		var paint := StandardMaterial3D.new()
		paint.albedo_color = material
		node.material_override = paint
	else:
		node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

# A triangular gable end: base `width` at height `base`, peak `rise` above it, centred on z.
func _prism(parent: Node3D, width: float, rise: float, x: float, base: float, z: float, material: Material) -> void:
	var prism := PrismMesh.new()
	prism.left_to_right = 0.5
	prism.size = Vector3(width, rise, 0.3)
	var node := MeshInstance3D.new()
	node.mesh = prism
	node.material_override = material
	node.position = Vector3(x, base + rise / 2, z - signf(z) * 0.15)
	parent.add_child(node)

func _window(parent: Node3D, centre: Vector3, size: Vector2, frame: Material, glass: Material, turn := 0.0) -> void:
	var holder := Node3D.new()
	holder.position = centre
	holder.rotation.y = turn
	parent.add_child(holder)
	_block(holder, Vector3(size.x, size.y, 0.04), Vector3.ZERO, glass)
	var bar := 0.07
	for y: float in [-size.y / 2, size.y / 2]:
		_block(holder, Vector3(size.x + bar * 2, bar, 0.1), Vector3(0, y, 0.03), frame)
	for x: float in [-size.x / 2, size.x / 2]:
		_block(holder, Vector3(bar, size.y, 0.1), Vector3(x, 0, 0.03), frame)
	_block(holder, Vector3(size.x, 0.05, 0.08), Vector3(0, 0, 0.03), frame)
	_block(holder, Vector3(0.05, size.y, 0.08), Vector3(0, 0, 0.03), frame)

func show_fold() -> void:
	shown = true
	visible = true
	set_collision(true)
	music.play()

func set_collision(on: bool) -> void:
	for body: CollisionObject3D in find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 1 if on else 0

func _process(delta: float) -> void:
	clock += delta
	if not shown:
		return
	if carousel != null:
		var spin: Node3D = carousel.get_node("Spin")
		spin.rotation.y += delta * 0.35
		for i in range(horses.size()):
			horses[i].position.y = 1.0 + sin(clock * 1.6 + i * 1.3) * 0.35
	if opening:
		door_open = move_toward(door_open, 1.0, delta * 0.6)
		door_hinge.rotation.y = -smoothstep(0.0, 1.0, door_open) * deg_to_rad(100)
	for balloon in balloons:
		var node: Node3D = balloon.node
		node.position = balloon.home + Vector3(sin(clock * 0.05 + balloon.phase) * 6.0, sin(clock * 0.3 + balloon.phase) * 1.2, cos(clock * 0.04 + balloon.phase) * 6.0)
		node.rotation.y += delta * 0.03

# Where the walker is (for the scene's hints).
func check_walker(at: Vector3) -> void:
	if fair == null:
		return
	var local := fair.to_local(at)
	if not told_fair and Vector2(local.x, local.z).length() < PLAZA + 6.0 and absf(local.y) < 3.0:
		told_fair = true
		reached_fair.emit()
	if not told_house and house.to_local(at).length() < 14.0:
		told_house = true
		reached_house.emit()

func near_door(at: Vector3) -> bool:
	if house == null or opening:
		return false
	return house.to_local(at).distance_to(Vector3(-0.9, 0.5, 2.8 + 1.0)) < DOOR_REACH

func open_door() -> void:
	opening = true
