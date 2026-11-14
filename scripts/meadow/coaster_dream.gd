extends Node3D
# The roller coaster's dream flight (roller_coaster.gd): past the ring of light on the climb, the
# train is out on a track that never stops, laid down ahead of it as it goes and taken away
# behind, far from the box (DREAM_AT). It runs through four places in turn, each melting into the
# next: a night sea (rolling glowing water, rock stacks, lights bobbing on the waves), down under
# the surface (blue-green deep, jellyfish, kelp, a whale and mantas from the meadow's fish), up
# through sunset clouds (puffs to fly through, sky lanterns rising), and out into space (asteroids,
# ringed planets, nebula). At the end a giant keyhole of light takes the train home.
# Memory shards (the ride's game): twelve crystals placed along the way, beside, above, below the
# track, some best seen looking back. Looking straight at one for a moment, or passing through
# it, catches it.
# Everything here is on render layer LAYER, lit by its own light; the sky is a sphere round the
# eye (dream_flight_sky.gdshader), the sea a sheet that follows the eye (dream_sea.gdshader).
signal shard_taken(count: int, total: int)
const DREAM_AT := Vector3(0, 15000, 0)
const LAYER := 128
const STEP := 0.5
# The track's mesh is laid in metre steps (the path itself is sampled finer).
const MESH_STEP := 1.0
const CONTROL := 12.0
const CHUNK := 120.0
const AHEAD := 1000.0
const BEHIND := 220.0
const GAUGE := 0.62
const BLEND := 260.0
# Where each place ends, along the track (metres).
const SEA_END := 1100.0
const DEEP_END := 2200.0
const CLOUDS_END := 3300.0
const END := 4500.0
const SEA_LEVEL := 0.0
const FLOOR := -78.0
# The box's night haze (dream_meadow.gd make_night), for the seams with the fair.
const HAZE_COLOR := Color(0.2, 0.25, 0.4)
const LOOK_ANGLE := 0.16
const LOOK_RANGE := 95.0
const DWELL := 0.18
const FISH := "res://assets/meadow/fish/%s.glb"
const SKY := preload("res://assets/materials/dream_flight_sky.gdshader")
const SEA := preload("res://assets/materials/dream_sea.gdshader")
const SHARD := preload("res://assets/materials/memory_shard.gdshader")
const CLOUD := preload("res://assets/materials/dream_cloud.gdshader")
# The shards: distance along the track, where from it (right, up, back), and their colour.
const SHARDS := [
	[300.0, Vector3(7, 3, 0)], [620.0, Vector3(-10, 1.2, 0)], [900.0, Vector3(0, 13, 0)],
	[1400.0, Vector3(-6, -3, 0)], [1650.0, Vector3(0, -10, 0)], [1950.0, Vector3(12, 5, 0)],
	[2500.0, Vector3(0, 9, 0)], [2750.0, Vector3(-15, 4, 0)], [3050.0, Vector3(11, -7, 0)],
	[3600.0, Vector3(0, 2.5, 0)], [3900.0, Vector3(18, 12, 0)], [4200.0, Vector3(-8, -14, 0)]]
const TINTS := [Color(0.5, 0.9, 1.0), Color(0.5, 1.0, 0.8), Color(1.0, 0.7, 0.55), Color(0.85, 0.6, 1.0)]

var points := PackedVector3Array()
var dists := PackedFloat32Array()
var banks := PackedFloat32Array()
var controls: Array[Vector3] = []
var control_turn: Array[float] = []
var heading := Vector3.FORWARD
var control_at := 0.0
var built_to := 0.0
var chunks: Array[Dictionary] = []
var shards: Array[Dictionary] = []
var passers: Array[Dictionary] = []
var swimmers: Array[Dictionary] = []
var spinners: Array[Dictionary] = []
# Planets only show once the train is nearly out of the clouds.
var planets: Array = []
var taken := 0
var taken_ids: Array[int] = []
var rng := RandomNumberGenerator.new()
var environment: Environment
var sky_paint: ShaderMaterial
var sky: MeshInstance3D
var sea: MeshInstance3D
var seabed: MeshInstance3D
var light: DirectionalLight3D
var steel: StandardMaterial3D
var red: StandardMaterial3D
var dark: StandardMaterial3D
var rock: StandardMaterial3D
var bulb_mesh: SphereMesh
var cloud_paint: ShaderMaterial
var underwater := 0.0
var preparing := false
# How deep in cloud the train is at either end of the dream (0 clear, 1 white-out).
var hazed := 1.0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, DREAM_AT)
	visible = false
	steel = _paint(Color(0.85, 0.86, 0.9), 0.25, 0.8)
	red = _paint(Color(0.85, 0.12, 0.2), 0.4, 0.3)
	dark = _paint(Color(0.2, 0.2, 0.24), 0.5, 0.5)
	rock = _paint(Color(0.09, 0.09, 0.11), 0.95, 0.0)
	bulb_mesh = SphereMesh.new()
	bulb_mesh.radius = 0.5
	bulb_mesh.height = 1.0
	bulb_mesh.radial_segments = 6
	bulb_mesh.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	bulb_mesh.material = glow
	cloud_paint = ShaderMaterial.new()
	cloud_paint.shader = CLOUD
	cloud_paint.set_shader_parameter("noise", _noise())
	cloud_paint.set_shader_parameter("opacity", 0.55)
	cloud_paint.set_shader_parameter("lit", Color(1.0, 0.82, 0.78))
	cloud_paint.set_shader_parameter("shade", Color(0.62, 0.48, 0.66))
	_environment()
	_sky_and_sea()

func _paint(colour: Color, rough: float, metal: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = rough
	paint.metallic = metal
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	return paint

func _noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	return texture

func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 1.2
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_aerial_perspective = 0.0
	environment.adjustment_enabled = true
	preload("res://scripts/game_settings.gd").track(environment)
	light = DirectionalLight3D.new()
	light.light_cull_mask = LAYER
	light.shadow_enabled = false
	add_child(light)

func _sky_and_sea() -> void:
	var ball := SphereMesh.new()
	ball.radius = 2500.0
	ball.height = 5000.0
	ball.radial_segments = 48
	ball.rings = 24
	sky_paint = ShaderMaterial.new()
	sky_paint.shader = SKY
	sky_paint.render_priority = -100
	sky = MeshInstance3D.new()
	sky.mesh = ball
	sky.material_override = sky_paint
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.layers = LAYER
	add_child(sky)
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(3000, 3000)
	sheet.subdivide_width = 220
	sheet.subdivide_depth = 220
	var water := ShaderMaterial.new()
	water.shader = SEA
	sea = MeshInstance3D.new()
	sea.mesh = sheet
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.layers = LAYER
	add_child(sea)
	var bed := PlaneMesh.new()
	bed.size = Vector2(3000, 3000)
	var sand := _paint(Color(0.12, 0.16, 0.16), 1.0, 0.0)
	seabed = MeshInstance3D.new()
	seabed.mesh = bed
	seabed.material_override = sand
	seabed.layers = LAYER
	add_child(seabed)

# --- Laying the track ----------------------------------------------------------------------------

# Height of the track over the sea at distance c along it: each place has its own, the next one's
# taken up over BLEND metres before the border.
func height_at(c: float) -> float:
	# Level and straight for the last stretch, so the way home is met on the level.
	if c > END - 320.0:
		return lerpf(_height(c), _height(END - 320.0), smoothstep(END - 320.0, END - 140.0, c))
	return _height(c)

func _height(c: float) -> float:
	var levels := [8.0 + 3.0 * sin(c / 55.0), -34.0 + 7.0 * sin(c / 40.0), 175.0 + 22.0 * sin(c / 80.0), 520.0 + 45.0 * sin(c / 110.0)]
	var ends := [SEA_END, DEEP_END, CLOUDS_END, INF]
	for i in range(4):
		if c < ends[i]:
			if i < 3 and c > ends[i] - BLEND:
				return lerpf(levels[i], levels[i + 1], smoothstep(ends[i] - BLEND, ends[i], c))
			return levels[i] if c > 90.0 or i > 0 else 8.0
	return levels[3]

func zone_at(c: float) -> int:
	if c < SEA_END:
		return 0
	if c < DEEP_END:
		return 1
	if c < CLOUDS_END:
		return 2
	return 3

func reset() -> void:
	for chunk in chunks:
		(chunk.node as Node).queue_free()
	for shard in shards:
		if is_instance_valid(shard.node):
			(shard.node as Node).queue_free()
	chunks.clear()
	shards.clear()
	passers.clear()
	swimmers.clear()
	spinners.clear()
	planets.clear()
	points = PackedVector3Array()
	dists = PackedFloat32Array()
	banks = PackedFloat32Array()
	controls.clear()
	control_turn.clear()
	heading = Vector3.FORWARD
	control_at = 0.0
	built_to = 0.0
	taken = 0
	taken_ids.clear()
	rng.seed = 4711
	# Two control points behind the start, so the first stretch is straight.
	for i in range(-2, 1):
		controls.append(Vector3(0, 8.0, -i * CONTROL))
		control_turn.append(0.0)

func _add_control() -> void:
	var c := control_at
	var turn := 0.0048 * sin(c / 170.0 + 1.0) + 0.0032 * sin(c / 63.0)
	turn *= smoothstep(60.0, 200.0, c) * (1.0 - smoothstep(END - 340.0, END - 160.0, c))
	heading = heading.rotated(Vector3.UP, turn * CONTROL)
	var last: Vector3 = controls[-1]
	var next := last + heading * CONTROL
	control_at += CONTROL
	next.y = height_at(control_at)
	controls.append(next)
	control_turn.append(turn)

func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

# Lay track (as dense samples) until it reaches `to` metres.
func _extend(to: float) -> void:
	while dists.is_empty() or dists[dists.size() - 1] < to:
		_add_control()
		var k := controls.size() - 3
		var p0 := controls[k - 1]
		var p1 := controls[k]
		var p2 := controls[k + 1]
		var p3 := controls[k + 2]
		var n := int(ceil(p1.distance_to(p2) / STEP))
		for j in range(n):
			var t := j / float(n)
			var p := _catmull(p0, p1, p2, p3, t)
			var d := 0.0 if points.is_empty() else dists[dists.size() - 1] + points[points.size() - 1].distance_to(p)
			points.append(p)
			dists.append(d)
			banks.append(clampf(-lerpf(control_turn[k], control_turn[k + 1], t) * 110.0, -0.65, 0.65))

func _index(d: float) -> int:
	return clampi(dists.bsearch(d), 1, points.size() - 2)

# The track's frame at distance d, in the dream's own coordinates: -Z ahead, Y the track's up.
func local_frame(d: float) -> Transform3D:
	var i := _index(d)
	var a := dists[i - 1]
	var b := dists[i]
	var t := clampf((d - a) / maxf(b - a, 0.0001), 0.0, 1.0)
	var at := points[i - 1].lerp(points[i], t)
	var ahead := (points[mini(i + 1, points.size() - 1)] - points[i - 1]).normalized()
	var flat := (Vector3.UP - ahead * ahead.y).normalized()
	var up := flat.rotated(ahead, lerpf(banks[i - 1], banks[i], t))
	return Transform3D(Basis.looking_at(ahead, up), at)

func frame_at(d: float) -> Transform3D:
	return global_transform * local_frame(d)

# --- Chunks of track and what is round them -------------------------------------------------

# A stretch of track, written straight into vertex arrays (rails, spine, ties) with their normals,
# so laying a chunk costs a couple of milliseconds, not a stall.
func _build_chunk(from: float, to: float) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var parts := [[PackedVector3Array(), PackedVector3Array()], [PackedVector3Array(), PackedVector3Array()], [PackedVector3Array(), PackedVector3Array()]]
	var lights_at: Array[Transform3D] = []
	var colours: Array[Color] = []
	var palette := [Color(1.0, 0.35, 0.45), Color(1.0, 0.8, 0.4), Color(0.45, 0.75, 1.0), Color(0.7, 1.0, 0.6)]
	var tubes := [[Vector3(-GAUGE, 0, 0), 0.07, 0], [Vector3(GAUGE, 0, 0), 0.07, 0], [Vector3(0, -0.42, 0), 0.16, 1]]
	var sides := 6
	var circle: Array[Vector3] = []
	for k in range(sides):
		var a := TAU * k / sides
		circle.append(Vector3(cos(a), sin(a), 0))
	# Each ring is worked out once and joined to the one before it.
	var last_rings: Array = []
	var d := from
	var k := 0
	while d <= to + 0.01:
		var f := local_frame(d)
		var rings: Array = []
		for tube: Array in tubes:
			var centre: Vector3 = tube[0]
			var radius: float = tube[1]
			var at := PackedVector3Array()
			var normal := PackedVector3Array()
			at.resize(sides)
			normal.resize(sides)
			for j in range(sides):
				var n := f.basis * circle[j]
				normal[j] = n
				at[j] = f.origin + f.basis * centre + n * radius
			rings.append([at, normal])
		if not last_rings.is_empty():
			for t in range(tubes.size()):
				var verts: PackedVector3Array = parts[tubes[t][2]][0]
				var norms: PackedVector3Array = parts[tubes[t][2]][1]
				var a0s: PackedVector3Array = last_rings[t][0]
				var an: PackedVector3Array = last_rings[t][1]
				var b0s: PackedVector3Array = rings[t][0]
				var bn: PackedVector3Array = rings[t][1]
				for j in range(sides):
					var j1 := (j + 1) % sides
					verts.append_array([a0s[j], b0s[j], b0s[j1], a0s[j], b0s[j1], a0s[j1]])
					norms.append_array([an[j], bn[j], bn[j1], an[j], bn[j1], an[j1]])
		last_rings = rings
		if k % 2 == 0:
			var ties: PackedVector3Array = parts[2][0]
			var tie_n: PackedVector3Array = parts[2][1]
			_fast_bar(ties, tie_n, f * Vector3(-GAUGE, -0.05, 0), f * Vector3(GAUGE, -0.05, 0), 0.06, f.basis)
			_fast_bar(ties, tie_n, f * Vector3(-GAUGE, -0.05, 0), f * Vector3(0, -0.42, 0), 0.05, f.basis)
			_fast_bar(ties, tie_n, f * Vector3(GAUGE, -0.05, 0), f * Vector3(0, -0.42, 0), 0.05, f.basis)
		if k % 3 == 0:
			for side in range(2):
				lights_at.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.15), f * Vector3((side * 2 - 1) * (GAUGE + 0.16), -0.08, 0)))
				colours.append(palette[int(d / 7.5) % palette.size()] * 3.0)
		d += MESH_STEP
		k += 1
	var paints := [steel, red, dark]
	for i in range(3):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = parts[i][0]
		arrays[Mesh.ARRAY_NORMAL] = parts[i][1]
		var shape := ArrayMesh.new()
		shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mesh := MeshInstance3D.new()
		mesh.mesh = shape
		mesh.material_override = paints[i]
		mesh.layers = LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mesh)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = bulb_mesh
	multi.instance_count = lights_at.size()
	for i in range(lights_at.size()):
		multi.set_instance_transform(i, lights_at[i])
		multi.set_instance_color(i, colours[i])
	var bulbs := MultiMeshInstance3D.new()
	bulbs.multimesh = multi
	bulbs.layers = LAYER
	holder.add_child(bulbs)
	_scenery(holder, from, to)
	for i in range(SHARDS.size()):
		var at: float = SHARDS[i][0]
		if at >= from and at < to:
			_shard(i)
	chunks.append({"from": from, "to": to, "node": holder})

func _fast_bar(verts: PackedVector3Array, norms: PackedVector3Array, from: Vector3, to: Vector3, thick: float, basis: Basis) -> void:
	var along := (to - from).normalized()
	var across := basis.z if absf(basis.z.dot(along)) < 0.9 else basis.x
	var side := across.cross(along).normalized()
	var lift := along.cross(side).normalized()
	var corners := [side + lift, -side + lift, -side - lift, side - lift]
	var faces := [lift, -side, -lift, side]
	for k in range(4):
		var c0: Vector3 = corners[k] * thick
		var c1: Vector3 = corners[(k + 1) % 4] * thick
		var n: Vector3 = faces[k]
		verts.append_array([from + c0, to + c0, to + c1, from + c0, to + c1, from + c1])
		norms.append_array([n, n, n, n, n, n])

func _ring(f: Transform3D, offset: Vector3, radius: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for k in range(6):
		var a := TAU * k / 6.0
		ring.append(f * (offset + Vector3(cos(a), sin(a), 0) * radius))
	return ring

func _tube(tool: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array) -> void:
	for k in range(6):
		var k1 := (k + 1) % 6
		for v: Vector3 in [a[k], b[k], b[k1], a[k], b[k1], a[k1]]:
			tool.add_vertex(v)

func _bar(tool: SurfaceTool, from: Vector3, to: Vector3, thick: float, basis: Basis) -> void:
	var along := (to - from).normalized()
	var across := basis.z if absf(basis.z.dot(along)) < 0.9 else basis.x
	var side := across.cross(along).normalized() * thick
	var lift := along.cross(side).normalized() * thick
	var corners := [side + lift, -side + lift, -side - lift, side - lift]
	for k in range(4):
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		for v: Vector3 in [from + c0, to + c0, to + c1, from + c0, to + c1, from + c1]:
			tool.add_vertex(v)

func _mesh(parent: Node3D, mesh: Mesh, paint: Material, at: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = paint
	node.transform = at
	node.layers = LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _glow_paint(colour: Color, energy: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(colour.r * energy, colour.g * energy, colour.b * energy)
	return paint

# A spot `side` metres to the side of the track at distance d (side may be negative).
func _beside(d: float, side: float) -> Vector3:
	var f := local_frame(d)
	var right := f.basis.x
	right.y = 0.0
	return f.origin + right.normalized() * side

func _scenery(holder: Node3D, from: float, to: float) -> void:
	var mid := (from + to) / 2.0
	match zone_at(mid):
		0: _sea_scenery(holder, from, to)
		1: _deep_scenery(holder, from, to)
		2: _cloud_scenery(holder, from, to)
		3: _space_scenery(holder, from, to)
	if from <= END - 320.0 and to > END - 320.0:
		_keyhole(holder, END - 320.0)

func _sea_scenery(holder: Node3D, from: float, to: float) -> void:
	for i in range(3):
		var d := rng.randf_range(from, to)
		var side := rng.randf_range(16.0, 70.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var foot := _beside(d, side)
		var tall := rng.randf_range(18.0, 60.0)
		var stack := CylinderMesh.new()
		stack.top_radius = rng.randf_range(1.5, 4.0)
		stack.bottom_radius = rng.randf_range(6.0, 11.0)
		stack.height = tall + 12.0
		stack.radial_segments = 7
		var node := _mesh(holder, stack, rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(foot.x, SEA_LEVEL + tall / 2.0 - 6.0, foot.z)))
		passers.append({"node": node, "passed": false})
		if rng.randf() < 0.5:
			_mesh(holder, bulb_mesh, _glow_paint(Color(1.0, 0.75, 0.4), 4.0), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), node.position + Vector3(0, tall / 2.0 + 6.4, 0)))
	for i in range(5):
		var d := rng.randf_range(from, to)
		var side := rng.randf_range(6.0, 40.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var at := _beside(d, side)
		var colour := Color(0.3, 1.0, 0.9) if rng.randf() > 0.4 else Color(1.0, 0.7, 0.35)
		var buoy := _mesh(holder, bulb_mesh, _glow_paint(colour, 3.0), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.9), Vector3(at.x, SEA_LEVEL + 0.4, at.z)))
		spinners.append({"node": buoy, "bob": rng.randf() * TAU, "base": buoy.position.y, "amp": 0.4, "spin": 0.0})

func _deep_scenery(holder: Node3D, from: float, to: float) -> void:
	for i in range(6):
		var d := rng.randf_range(from, to)
		var at := _beside(d, rng.randf_range(-35.0, 35.0)) + Vector3(0, rng.randf_range(-12.0, 14.0), 0)
		if absf(at.distance_to(local_frame(d).origin)) < 6.0:
			at += Vector3(0, 9, 0)
		_jelly(holder, at, rng.randf_range(1.2, 3.2))
	for i in range(10):
		var d := rng.randf_range(from, to)
		var side := rng.randf_range(5.0, 60.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var at := _beside(d, side)
		var tall := rng.randf_range(14.0, 42.0)
		var weed := BoxMesh.new()
		weed.size = Vector3(0.6, tall, 0.15)
		var node := _mesh(holder, weed, _paint(Color(0.1, 0.35, 0.18), 0.8, 0.0), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(at.x, FLOOR + tall / 2.0, at.z)))
		spinners.append({"node": node, "bob": rng.randf() * TAU, "base": node.position.y, "amp": 0.0, "spin": 0.0, "sway": 0.12})
	if int(from / CHUNK) % 3 == 0:
		_swimmer(holder, "whale", 30.0, from, rng.randf_range(35.0, 55.0), 6.0)
	else:
		_swimmer(holder, "manta_ray", 6.0, from, rng.randf_range(-25.0, -12.0), 8.0)
		_swimmer(holder, "barramundi_fish", 2.0, from, rng.randf_range(8.0, 14.0), 10.0)

# A jellyfish: a glowing translucent bell and a few trailing threads, bobbing.
func _jelly(holder: Node3D, at: Vector3, size: float) -> void:
	var jelly := Node3D.new()
	jelly.position = at
	holder.add_child(jelly)
	var bell := SphereMesh.new()
	bell.radius = size
	bell.height = size * 1.3
	bell.is_hemisphere = true
	var colour := Color(1.0, 0.45, 0.85) if rng.randf() > 0.5 else Color(0.4, 0.9, 1.0)
	var skin := StandardMaterial3D.new()
	skin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.albedo_color = Color(colour.r * 1.6, colour.g * 1.6, colour.b * 1.6, 0.55)
	_mesh(jelly, bell, skin, Transform3D.IDENTITY)
	var thread := CylinderMesh.new()
	thread.top_radius = 0.05
	thread.bottom_radius = 0.02
	thread.height = size * 3.0
	thread.radial_segments = 4
	for k in range(5):
		var a := TAU * k / 5.0
		_mesh(jelly, thread, skin, Transform3D(Basis.IDENTITY, Vector3(cos(a) * size * 0.5, -size * 1.5, sin(a) * size * 0.5)))
	spinners.append({"node": jelly, "bob": rng.randf() * TAU, "base": at.y, "amp": 1.2, "spin": 0.2})
	passers.append({"node": jelly, "passed": false})

func _swimmer(holder: Node3D, kind: String, length: float, from: float, side: float, speed: float) -> void:
	var fish: Node3D = load(FISH % kind).instantiate()
	holder.add_child(fish)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in fish.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = LAYER
		var b := mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	fish.scale = Vector3.ONE * (length / maxf(box.get_longest_axis_size(), 0.01))
	for player: AnimationPlayer in fish.find_children("*", "AnimationPlayer", true, false):
		var names := player.get_animation_list()
		if not names.is_empty():
			var clip := player.get_animation(names[0])
			clip.loop_mode = Animation.LOOP_LINEAR
			player.play(names[0])
	var d := from + rng.randf_range(0.0, CHUNK)
	swimmers.append({"node": fish, "d": d, "side": side, "lift": rng.randf_range(-6.0, 6.0), "speed": speed})
	passers.append({"node": fish, "passed": false})

func _cloud_scenery(holder: Node3D, from: float, to: float) -> void:
	# A sea of cloud spread out below the track and a few puffs far off to the sides: the view
	# ahead and up stays open to the sunset.
	var count := 26
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.material = cloud_paint
	multi.mesh = quad
	multi.instance_count = count
	for i in range(count):
		var d := rng.randf_range(from, to)
		var below := rng.randf() < 0.7
		var side := rng.randf_range(0.0 if below else 45.0, 150.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var lift := rng.randf_range(-70.0, -32.0) if below else rng.randf_range(-20.0, 25.0)
		var at := _beside(d, side) + Vector3(0, lift, 0)
		var size := rng.randf_range(22.0, 48.0) if below else rng.randf_range(12.0, 26.0)
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.7, size)), at))
		multi.set_instance_custom_data(i, Color(rng.randf(), 0, 0, 0))
	var puffs := MultiMeshInstance3D.new()
	puffs.multimesh = multi
	puffs.layers = LAYER
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(puffs)
	var lantern := QuadMesh.new()
	lantern.size = Vector2(0.6, 0.8)
	var warm := _glow_paint(Color(1.0, 0.6, 0.25), 3.0)
	warm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	lantern.material = warm
	for i in range(22):
		var d := rng.randf_range(from, to)
		var at := _beside(d, rng.randf_range(-50.0, 50.0)) + Vector3(0, rng.randf_range(-30.0, 20.0), 0)
		var node := MeshInstance3D.new()
		node.mesh = lantern
		node.position = at
		node.layers = LAYER
		holder.add_child(node)
		spinners.append({"node": node, "bob": 0.0, "base": at.y, "amp": 0.0, "spin": 0.0, "rise": rng.randf_range(0.6, 1.6)})

func _space_scenery(holder: Node3D, from: float, to: float) -> void:
	var stone := SphereMesh.new()
	stone.radius = 1.0
	stone.height = 2.0
	stone.radial_segments = 7
	stone.rings = 4
	var grey := _paint(Color(0.35, 0.32, 0.3), 0.95, 0.1)
	for i in range(9):
		var d := rng.randf_range(from, to)
		var side := rng.randf_range(10.0, 90.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var at := _beside(d, side) + Vector3(0, rng.randf_range(-40.0, 40.0), 0)
		var s := rng.randf_range(2.0, 12.0)
		var node := _mesh(holder, stone, grey, Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.7, 1.2))), at))
		spinners.append({"node": node, "bob": 0.0, "base": at.y, "amp": 0.0, "spin": rng.randf_range(0.1, 0.5)})
		passers.append({"node": node, "passed": false})
	if int(from / CHUNK) % 4 == 1:
		var d := (from + to) / 2.0
		var side := rng.randf_range(500.0, 900.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var at := _beside(d + 600.0, side) + Vector3(0, rng.randf_range(80.0, 400.0), 0)
		var r := rng.randf_range(150.0, 320.0)
		var globe := SphereMesh.new()
		globe.radius = r
		globe.height = r * 2.0
		globe.radial_segments = 48
		globe.rings = 24
		var hues := [Color(0.8, 0.45, 0.3), Color(0.35, 0.55, 0.9), Color(0.75, 0.65, 0.45), Color(0.55, 0.85, 0.75)]
		var skin := _paint(hues[rng.randi() % hues.size()], 0.8, 0.0)
		skin.rim_enabled = true
		skin.rim = 0.6
		var planet := _mesh(holder, globe, skin, Transform3D(Basis.IDENTITY, at))
		planets.append(planet)
		var ring := TorusMesh.new()
		ring.inner_radius = r * 1.35
		ring.outer_radius = r * 2.1
		ring.rings = 96
		var band := StandardMaterial3D.new()
		band.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		band.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		band.cull_mode = BaseMaterial3D.CULL_DISABLED
		band.albedo_color = Color(0.55, 0.48, 0.4, 0.3)
		planets.append(_mesh(holder, ring, band, Transform3D(Basis.from_euler(Vector3(0.35, rng.randf() * TAU, 0.2)).scaled(Vector3(1, 0.02, 1)), at)))

# The way home: a keyhole of light standing over the track.
func _keyhole(holder: Node3D, d: float) -> void:
	var f := local_frame(d)
	var white := _glow_paint(Color(1.0, 0.95, 0.85), 4.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 8.0
	ring.outer_radius = 9.0
	ring.rings = 64
	var circle := Transform3D(f.basis * Basis(Vector3.RIGHT, PI / 2), f * Vector3(0, 6.0, 0))
	_mesh(holder, ring, white, circle)
	var bar := BoxMesh.new()
	bar.size = Vector3(1.0, 18.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var post := Transform3D(f.basis * Basis(Vector3.BACK, side * 0.22), f * Vector3(side * 5.5, -8.0, 0))
		_mesh(holder, bar, white, post)
	var core := QuadMesh.new()
	core.size = Vector2(15.0, 15.0)
	var veil := _glow_paint(Color(1.0, 0.97, 0.9), 2.5)
	veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil.albedo_color.a = 0.5
	veil.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(holder, core, veil, Transform3D(f.basis, f * Vector3(0, 6.0, 0)))

func _shard(i: int) -> void:
	var at: float = SHARDS[i][0]
	var offset: Vector3 = SHARDS[i][1]
	var f := local_frame(at)
	var holder := Node3D.new()
	holder.position = f * offset
	add_child(holder)
	var gem := SphereMesh.new()
	gem.radius = 0.8
	gem.height = 2.6
	gem.radial_segments = 4
	gem.rings = 2
	var paint := ShaderMaterial.new()
	paint.shader = SHARD
	var tint: Color = TINTS[zone_at(at)]
	paint.set_shader_parameter("tint", tint)
	var crystal := _mesh(holder, gem, paint, Transform3D.IDENTITY)
	var halo := QuadMesh.new()
	halo.size = Vector2(5.0, 5.0)
	var soft := StandardMaterial3D.new()
	soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soft.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	soft.albedo_texture = _halo_texture()
	soft.albedo_color = Color(tint.r, tint.g, tint.b, 0.8)
	_mesh(holder, halo, soft, Transform3D.IDENTITY)
	var sparks := GPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 1.6
	sparks.layers = LAYER
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.2
	process.gravity = Vector3(0, 0.6, 0)
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.8
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.scale_min = 0.5
	process.scale_max = 1.0
	sparks.process_material = process
	var dot := QuadMesh.new()
	dot.size = Vector2(0.15, 0.15)
	var dot_paint := soft.duplicate()
	dot_paint.albedo_color = Color(tint.r * 2.0, tint.g * 2.0, tint.b * 2.0, 1.0)
	dot.material = dot_paint
	sparks.draw_pass_1 = dot
	holder.add_child(sparks)
	shards.append({"id": i, "node": holder, "crystal": crystal, "paint": paint, "taken": false, "look": 0.0, "fly": -1.0, "from": Vector3.ZERO})

func _halo_texture() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 0.3))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# --- Every frame ---------------------------------------------------------------------------------

# Laid out ahead of time, while the train is still running out into the haze: one chunk a frame
# (prepare_step), so by the time it slips across, the first kilometre is there.
func prepare() -> void:
	reset()
	_extend(AHEAD + CHUNK)
	preparing = true

func prepare_step() -> void:
	if preparing and built_to < AHEAD:
		_build_chunk(built_to, built_to + CHUNK)
		built_to += CHUNK

func begin() -> void:
	if not preparing:
		prepare()
	preparing = false
	visible = true
	update(0.0, null, 0.0)

func finish() -> void:
	visible = false
	preparing = false
	reset()

# Keep the track laid ahead of `d` and cleared behind, the sea and sky with the eye, the air and
# light right for where the eye is; catch shards looked at. Returns how many things just swept past.
func update(d: float, eye: Camera3D, delta: float) -> int:
	_extend(d + AHEAD + CHUNK)
	# One chunk a frame at most, so laying track never stalls a frame.
	if built_to + CHUNK <= dists[dists.size() - 1] - 30.0 and built_to < d + AHEAD:
		_build_chunk(built_to, built_to + CHUNK)
		built_to += CHUNK
	for chunk in chunks.duplicate():
		if chunk.to < d - BEHIND:
			(chunk.node as Node).queue_free()
			chunks.erase(chunk)
	var eye_at := to_local(eye.global_position) if eye != null else local_frame(d).origin
	sky.position = eye_at
	sea.position = Vector3(snappedf(eye_at.x, 10.0), SEA_LEVEL, snappedf(eye_at.z, 10.0))
	seabed.position = Vector3(sea.position.x, FLOOR, sea.position.z)
	var near_water := d < DEEP_END + 400.0
	sea.visible = near_water
	seabed.visible = near_water
	underwater = smoothstep(0.6, -1.2, eye_at.y - SEA_LEVEL) if near_water else 0.0
	_air(d)
	var in_space := d > CLOUDS_END - 120.0
	for planet in planets:
		if is_instance_valid(planet):
			(planet as Node3D).visible = in_space
	var swept := 0
	var clock := Time.get_ticks_msec() / 1000.0
	for item in spinners:
		if not is_instance_valid(item.node):
			continue
		var node: Node3D = item.node
		if item.amp > 0.0:
			node.position.y = item.base + sin(clock * 0.8 + item.bob) * item.amp
		if item.spin > 0.0:
			node.rotate_y(item.spin * delta)
		if item.has("rise"):
			node.position.y += item.rise * delta
		if item.has("sway"):
			node.rotation.z = sin(clock * 0.9 + item.bob) * item.sway
	for fish in swimmers:
		if not is_instance_valid(fish.node):
			continue
		var node: Node3D = fish.node
		fish.d += fish.speed * delta
		var f := local_frame(fish.d)
		node.position = _beside(fish.d, fish.side) + Vector3(0, f.origin.y - _beside(fish.d, fish.side).y + fish.lift, 0)
		var swim := -f.basis.z
		swim.y = 0.0
		node.basis = Basis.looking_at(swim.normalized(), Vector3.UP) * Basis.from_scale(node.scale)
	if eye != null:
		for item in passers:
			if item.passed or not is_instance_valid(item.node):
				continue
			var node: Node3D = item.node
			if node.global_position.distance_to(eye.global_position) < 22.0:
				item.passed = true
				swept += 1
		_look(eye, delta)
	return swept

# The air, light and sky for where the train is: night sea, under the sea, sunset clouds, space.
func _air(d: float) -> void:
	var presets := [
		{"top": Color(0.02, 0.03, 0.09), "horizon": Color(0.12, 0.15, 0.3), "low": Color(0.03, 0.04, 0.08), "stars": 1.0, "nebula": 0.0, "sun": 0.0, "moon": 1.0, "fog": Color(0.08, 0.1, 0.2), "density": 0.0035, "ambient": Color(0.3, 0.33, 0.5), "light": Color(0.55, 0.65, 1.0), "energy": 0.7},
		{"top": Color(0.02, 0.06, 0.1), "horizon": Color(0.05, 0.15, 0.22), "low": Color(0.02, 0.06, 0.09), "stars": 0.4, "nebula": 0.0, "sun": 0.0, "moon": 0.6, "fog": Color(0.05, 0.12, 0.2), "density": 0.003, "ambient": Color(0.25, 0.4, 0.5), "light": Color(0.5, 0.8, 1.0), "energy": 0.6},
		{"top": Color(0.2, 0.18, 0.45), "horizon": Color(0.82, 0.42, 0.38), "low": Color(0.42, 0.28, 0.42), "stars": 0.0, "nebula": 0.0, "sun": 1.0, "moon": 0.0, "fog": Color(0.55, 0.38, 0.5), "density": 0.0009, "ambient": Color(0.8, 0.58, 0.55), "light": Color(1.0, 0.72, 0.5), "energy": 1.0},
		{"top": Color(0.0, 0.0, 0.01), "horizon": Color(0.02, 0.01, 0.05), "low": Color(0.0, 0.0, 0.02), "stars": 1.4, "nebula": 1.0, "sun": 0.0, "moon": 0.0, "fog": Color(0.03, 0.02, 0.06), "density": 0.0004, "ambient": Color(0.22, 0.22, 0.32), "light": Color(0.95, 0.92, 1.0), "energy": 1.0}]
	var ends := [SEA_END, DEEP_END, CLOUDS_END]
	var zone := zone_at(d)
	var next := mini(zone + 1, 3)
	var t := 0.0
	if zone < 3:
		t = smoothstep(ends[zone] - BLEND, ends[zone], d)
	var a: Dictionary = presets[zone]
	var b: Dictionary = presets[next]
	for key: String in ["top", "horizon", "low"]:
		sky_paint.set_shader_parameter(key, (a[key] as Color).lerp(b[key], t))
	for key: String in ["stars", "nebula", "sun", "moon"]:
		sky_paint.set_shader_parameter(key, lerpf(a[key], b[key], t))
	var fog: Color = (a.fog as Color).lerp(b.fog, t)
	var density := lerpf(a.density, b.density, t)
	var deep := Color(0.03, 0.16, 0.22)
	# Haze at both ends, the same as the box's out where the train slipped away: it thins as the
	# dream opens up, and closes in again before the way home.
	hazed = maxf(smoothstep(520.0, 14.0, d), smoothstep(END - 360.0, END - 55.0, d))
	environment.fog_light_color = fog.lerp(deep, underwater).lerp(HAZE_COLOR, hazed)
	environment.fog_density = lerpf(lerpf(density, 0.022, underwater), 0.5, hazed * hazed)
	# In the cloud, the same light as out over the fair (the box's moonlight), so the train looks
	# the same on both sides of the seam.
	environment.tonemap_exposure = 1.25
	environment.ambient_light_color = (a.ambient as Color).lerp(b.ambient, t).lerp(Color(0.2, 0.5, 0.55), underwater)
	environment.ambient_light_energy = 0.8
	sky_paint.set_shader_parameter("veil", maxf(underwater, hazed))
	sky_paint.set_shader_parameter("veil_color", deep.lerp(HAZE_COLOR, hazed))
	light.light_color = (a.light as Color).lerp(b.light, t).lerp(Color(0.62, 0.72, 1.0), hazed)
	light.light_energy = lerpf(lerpf(a.energy, b.energy, t), 0.0, hazed)
	environment.ambient_light_color = environment.ambient_light_color.lerp(Color(0.2, 0.24, 0.4), hazed)
	environment.ambient_light_energy = lerpf(0.8, 0.3, hazed)
	var sun_dir := Vector3(0.85, 0.18, -0.5).normalized()
	sky_paint.set_shader_parameter("sun_dir", sun_dir)
	# From above at night and in space, from the low sun over the clouds.
	var sunset := t if zone == 1 else (1.0 if zone == 2 else (1.0 - t if zone == 2 else 0.0))
	var towards := Vector3(0.3, 0.8, -0.4).normalized().lerp(sun_dir, sunset).normalized()
	light.basis = Basis.looking_at(-towards, Vector3.RIGHT)

# Looking at a shard for a moment (or flying through it) catches it: it flares and flies to the eye.
func _look(eye: Camera3D, delta: float) -> void:
	var at := eye.global_position
	var ahead := -eye.global_basis.z
	for shard in shards:
		if not is_instance_valid(shard.node):
			continue
		var node: Node3D = shard.node
		if shard.taken:
			shard.fly += delta / 0.45
			var k: float = smoothstep(0.0, 1.0, shard.fly)
			node.global_position = (shard.from as Vector3).lerp(at + ahead * 2.0, k)
			node.scale = Vector3.ONE * maxf(1.0 - k, 0.02)
			(shard.paint as ShaderMaterial).set_shader_parameter("taken", k)
			if shard.fly >= 1.0:
				node.queue_free()
			continue
		(shard.crystal as Node3D).rotate_y(delta * 1.4)
		var to := node.global_position - at
		var distance := to.length()
		if distance > LOOK_RANGE:
			continue
		var angle := ahead.angle_to(to / maxf(distance, 0.001))
		if distance < 4.5 or angle < LOOK_ANGLE * (1.0 + 10.0 / maxf(distance, 10.0)):
			shard.look += delta
		else:
			shard.look = maxf(shard.look - delta * 0.5, 0.0)
		if shard.look >= DWELL or distance < 3.0:
			shard.taken = true
			shard.fly = 0.0
			shard.from = node.global_position
			taken += 1
			taken_ids.append(shard.id)
			shard_taken.emit(taken, SHARDS.size())

func shard_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for shard in shards:
		if not shard.taken and is_instance_valid(shard.node):
			out.append((shard.node as Node3D).global_position)
	return out
