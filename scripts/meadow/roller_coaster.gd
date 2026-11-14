extends Node3D
# The roller coaster at the fair on the wall of the box (land_fold.gd), out past the east edge of
# the plaza. A steel track laid along a Curve3D (rails, spine and ties made here, so the track can
# go anywhere later): out of the station, a launch, a top hat 64 m high, a vertical loop, a
# banked helix, three airtime hills back, and a long turn into the station again. Kenney's Coaster
# Kit gives the train (four cars) and the station's floor, fences and gate (CC0,
# assets/meadow/coaster/sources.json); the supports, canopy and track are built here.
# Riding it: stand by the train at the station and press E. The train launches to 40 m/s, runs
# on gravity (and a little drag), the view widening with speed, then brakes back into the station.
# Partway up the top hat the track runs through a ring of light: the train is out on the dream's
# endless track (coaster_dream.gd), over the sea, under it, through the clouds, out into space,
# catching memory shards, until a keyhole of light brings it back onto the last turn into the
# station. Sounds: wind and rumble with speed, a launch, the warp, swishes past things, splashes,
# the deep's hum, chimes for shards, and its own music (assets/audio/coaster/sources.json).
# Built in the fair's frame (local y is the wall's up).
signal ride_over
# A white flash (going into or out of the dream), a shard caught, the dream starting or ending.
signal flash(strength: float)
signal shard_taken(count: int, total: int)
signal dream_changed(on: bool)
const Dream := preload("res://scripts/meadow/coaster_dream.gd")
const SOUND := "res://assets/audio/coaster/%s.ogg"
const MUSIC := "res://assets/music/coaster_gumdrop_plains.ogg"
const GATE_HEIGHT := 30.0
const RETURN_BEFORE := 170.0
const DREAM_SPEED := 58.0
const MODEL := "res://assets/meadow/coaster/%s.glb"
const KIT := 2.4
const CARS := 4
const CAR_GAP := 3.4
const GAUGE := 0.62
# The rails' height off the meadow at the station (and on the flat): low, so the platform is a step up.
const RIDE_HEIGHT := 0.6
const LAUNCH := 40.0
const LAUNCH_PUSH := 14.0
const GRAVITY := 9.8
const DRAG := 0.0008
const CRAWL := 4.0
const BRAKE_FROM := 60.0
const SEAT := Vector3(0, 1.8, -0.3)
const REACH := 2.6
# Where the train waits: the front car this far along the track.
const HOME := 20.0

var curve := Curve3D.new()
var length := 0.0
var cars: Array[Node3D] = []
var at := HOME
var speed := 0.0
var rider: CharacterBody3D
var riding := false
var ride_time := 0.0
var travelled := 0.0
var top_speed := 0.0
var inverted := false
var launch_end := 0.0
var base_fov := 72.0
var phase := "track"
var dream: Node3D
var dream_d := 0.0
var gate_at := 0.0
var return_at := 0.0
var dreamed := false
# Shards caught on the last ride.
var caught := 0
var was_under := false
var swish_wait := 0.0
var wind: AudioStreamPlayer
var rumble: AudioStreamPlayer
var deep: AudioStreamPlayer
var music: AudioStreamPlayer
var one_shots := {}
var sparks: GPUParticles3D
var splash: GPUParticles3D

func build() -> void:
	_layout()
	_track()
	_supports()
	_station()
	_train()
	var mark := Marker3D.new()
	mark.name = "GameCoaster"
	mark.position = boarding()
	add_child(mark)
	_place_train()
	_gateway()
	_sounds()
	_sparks()
	dream = Dream.new()
	dream.name = "DreamFlight"
	add_child(dream)
	dream.shard_taken.connect(_on_shard)

# --- The track's shape ---------------------------------------------------------------------------

func _add(points: Array, tilts: Array, p: Vector3, tilt := 0.0) -> void:
	if not points.is_empty() and (points[-1] as Vector3).distance_to(p) < 0.5:
		return
	points.append(p)
	tilts.append(tilt)

func _layout() -> void:
	var points: Array = []
	var tilts: Array = []
	var z := -30.0
	var h := RIDE_HEIGHT
	# The station and the launch straight.
	for x in range(70, 125, 4):
		_add(points, tilts, Vector3(x, h, z))
	launch_end = 50.0
	# Top hat: up nearly vertical, over, and down.
	for i in range(1, 31):
		var t := i / 30.0
		_add(points, tilts, Vector3(125.0 + t * 90.0, h + 62.6 * pow(sin(PI * t), 1.6), z))
	for x in range(219, 232, 4):
		_add(points, tilts, Vector3(x, h + 0.6, z))
	# A vertical loop, sliding 5 m sideways as it goes round so the track clears itself.
	var loop := Vector3(246, h + 15.0, z)
	for i in range(0, 41):
		var a := TAU * i / 40.0
		_add(points, tilts, Vector3(loop.x + 14.0 * sin(a), loop.y - 14.0 * cos(a) + 0.6, z + 5.0 * smoothstep(0.0, 1.0, a / TAU)))
	z += 5.0
	for x in range(262, 275, 4):
		_add(points, tilts, Vector3(x, h + 0.6, z))
	# A banked helix: half a turn, rising and falling, to come back the other way.
	var middle := Vector3(276, 0, 0)
	for i in range(1, 31):
		var t := i / 30.0
		var a := -PI / 2 + PI * t
		_add(points, tilts, Vector3(middle.x + 25.0 * cos(a), h + 0.6 + 18.0 * sin(PI * t), middle.z + 25.0 * sin(a)), -0.7 * sin(PI * t))
	# Three airtime hills, back along the other side.
	z = 25.0
	for i in range(1, 46):
		var t := i / 45.0
		var x := 276.0 - t * 186.0
		_add(points, tilts, Vector3(x, h + 0.6 + 11.0 * pow(sin(PI * 3.0 * t), 2.0) * (1.0 - t * 0.35), z))
	for x in range(86, 69, -4):
		_add(points, tilts, Vector3(x, h, z))
	# The long turn back into the station.
	var turn := Vector3(70, 0, -2.5)
	for i in range(1, 25):
		var a := PI / 2 + PI * i / 24.0
		_add(points, tilts, Vector3(turn.x + 27.5 * cos(a), h, turn.z + 27.5 * sin(a)), -0.35 * sin(PI * i / 24.0))
	curve.closed = true
	curve.bake_interval = 0.4
	curve.up_vector_enabled = true
	var count := points.size()
	for i in range(count):
		var p: Vector3 = points[i]
		var before: Vector3 = points[(i - 1 + count) % count]
		var after: Vector3 = points[(i + 1) % count]
		var hand := (after - before) / 6.0
		curve.add_point(p, -hand, hand)
		curve.set_point_tilt(i, tilts[i])
	length = curve.get_baked_length()

# The track's frame at distance d along it: origin on the rails, -Z ahead, Y the track's up.
func frame_at(d: float) -> Transform3D:
	d = fposmod(d, length)
	var here := curve.sample_baked(d, true)
	var ahead := (curve.sample_baked(fposmod(d + 0.3, length), true) - curve.sample_baked(fposmod(d - 0.3, length), true)).normalized()
	var up := curve.sample_baked_up_vector(d, true)
	up = (up - ahead * up.dot(ahead)).normalized()
	return Transform3D(Basis.looking_at(ahead, up), here)

# --- The track itself --------------------------------------------------------------------------

func _track() -> void:
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := SurfaceTool.new()
	spine.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ties := SurfaceTool.new()
	ties.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.5
	var rings := int(length / step)
	var previous: Array = []
	for i in range(rings + 1):
		var f := frame_at(i * step)
		var current: Array = [
			_ring(f, Vector3(-GAUGE, 0, 0), 0.07),
			_ring(f, Vector3(GAUGE, 0, 0), 0.07),
			_ring(f, Vector3(0, -0.42, 0), 0.16)]
		if not previous.is_empty():
			_tube(rails, previous[0], current[0], f.basis)
			_tube(rails, previous[1], current[1], f.basis)
			_tube(spine, previous[2], current[2], f.basis)
		previous = current
		if i % 3 == 0:
			_tie(ties, f)
	var steel := StandardMaterial3D.new()
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	steel.albedo_color = Color(0.85, 0.86, 0.9)
	steel.metallic = 0.8
	steel.roughness = 0.25
	var red := StandardMaterial3D.new()
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	red.albedo_color = Color(0.75, 0.1, 0.12)
	red.metallic = 0.3
	red.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.albedo_color = Color(0.2, 0.2, 0.24)
	dark.metallic = 0.5
	_lights()
	for part: Array in [[rails, steel, "Rails"], [spine, red, "Spine"], [ties, dark, "Ties"]]:
		var tool: SurfaceTool = part[0]
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = part[2]
		mesh.mesh = tool.commit()
		mesh.material_override = part[1]
		add_child(mesh)

# Coloured bulbs all along both sides of the track, so the whole ride is drawn in light at night.
func _lights() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	sphere.material = glow
	var colours := [Color(1.0, 0.35, 0.45), Color(1.0, 0.8, 0.4), Color(0.45, 0.75, 1.0), Color(0.7, 1.0, 0.6)]
	var step := 2.5
	var count := int(length / step)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = sphere
	multi.instance_count = count * 2
	for i in range(count):
		var f := frame_at(i * step)
		for side in range(2):
			var at := f * Vector3((side * 2 - 1) * (GAUGE + 0.16), -0.08, 0)
			multi.set_instance_transform(i * 2 + side, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.14), at))
			multi.set_instance_color(i * 2 + side, colours[(i / 3) % colours.size()] * 3.0)
	var bulbs := MultiMeshInstance3D.new()
	bulbs.name = "TrackLights"
	bulbs.multimesh = multi
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulbs)

func _ring(f: Transform3D, offset: Vector3, radius: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for k in range(6):
		var a := TAU * k / 6.0
		ring.append(f * (offset + Vector3(cos(a), sin(a), 0) * radius))
	return ring

func _tube(tool: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, _basis: Basis) -> void:
	for k in range(6):
		var k1 := (k + 1) % 6
		for v: Vector3 in [a[k], b[k], b[k1], a[k], b[k1], a[k1]]:
			tool.add_vertex(v)

# A tie across the rails and a strut down to the spine.
func _tie(tool: SurfaceTool, f: Transform3D) -> void:
	_bar(tool, f * Vector3(-GAUGE, -0.05, 0), f * Vector3(GAUGE, -0.05, 0), 0.06, f.basis)
	_bar(tool, f * Vector3(-GAUGE, -0.05, 0), f * Vector3(0, -0.42, 0), 0.05, f.basis)
	_bar(tool, f * Vector3(GAUGE, -0.05, 0), f * Vector3(0, -0.42, 0), 0.05, f.basis)

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

# Columns from the meadow up to the spine wherever the track runs upright and off the ground.
func _supports() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := 0.0
	while d < length:
		var f := frame_at(d)
		var foot := f * Vector3(0, -0.42, 0)
		if f.basis.y.y > 0.6 and foot.y > 0.4:
			_bar(tool, Vector3(foot.x, 0, foot.z), foot, 0.22, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP))
			if foot.y > 14.0:
				var out := f.basis.x * 3.0
				_bar(tool, Vector3(foot.x, 0, foot.z) + Vector3(out.x, 0, out.z), foot, 0.14, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP))
				_bar(tool, Vector3(foot.x, 0, foot.z) - Vector3(out.x, 0, out.z), foot, 0.14, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP))
		d += 7.0
	tool.generate_normals()
	var paint := StandardMaterial3D.new()
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = Color(0.92, 0.9, 0.85)
	paint.roughness = 0.5
	var mesh := MeshInstance3D.new()
	mesh.name = "Supports"
	mesh.mesh = tool.commit()
	mesh.material_override = paint
	add_child(mesh)

# --- Station and train ---------------------------------------------------------------------------

# The station: a concrete platform beside the track with a step up, Kenney's floor tiles and
# fences on it (the gate by the front car), a striped canopy on posts over platform and train.
func _station() -> void:
	var holder := Node3D.new()
	holder.name = "Station"
	add_child(holder)
	var mid := frame_at(HOME - 4.0)
	var top := RIDE_HEIGHT - 0.12
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.42, 0.42, 0.45)
	concrete.roughness = 0.9
	# Platform: lateral 1.1 to 4.7 from the rails, 28 m along; then a step.
	for part: Array in [[Vector3(2.9, -RIDE_HEIGHT + top / 2.0, 0), Vector3(3.6, top, 28.0)], [Vector3(5.1, -RIDE_HEIGHT + top / 4.0, 0), Vector3(0.8, top / 2.0, 28.0)]]:
		var box := BoxMesh.new()
		box.size = part[1]
		var slab := MeshInstance3D.new()
		slab.mesh = box
		slab.material_override = concrete
		slab.transform = Transform3D(mid.basis, mid * (part[0] as Vector3))
		holder.add_child(slab)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = part[1]
		shape.shape = cube
		body.add_child(shape)
		body.transform = slab.transform
		holder.add_child(body)
	for i in range(11):
		var along := -12.0 + i * 2.4
		var f := Transform3D(mid.basis, mid * Vector3(2.9, -RIDE_HEIGHT + top, along))
		var floor_tile: Node3D = load(MODEL % "station").instantiate()
		floor_tile.transform = f.scaled_local(Vector3.ONE * KIT * Vector3(1.0, 0.1, 1.0))
		holder.add_child(floor_tile)
		if i != 7:
			var fence: Node3D = load(MODEL % "station-fence").instantiate()
			fence.transform = f.scaled_local(Vector3.ONE * KIT)
			holder.add_child(fence)
	var stripes := ShaderMaterial.new()
	stripes.shader = load("res://assets/materials/carousel_roof.gdshader")
	stripes.set_shader_parameter("stripes", 10.0)
	var roof := BoxMesh.new()
	roof.size = Vector3(7.0, 0.2, 30.0)
	var canopy := MeshInstance3D.new()
	canopy.mesh = roof
	canopy.material_override = stripes
	canopy.transform = Transform3D(mid.basis, mid * Vector3(1.4, 4.6, 0))
	holder.add_child(canopy)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.9, 0.85)
	for along: float in [-14.0, -4.7, 4.7, 14.0]:
		var post := CylinderMesh.new()
		post.top_radius = 0.12
		post.bottom_radius = 0.12
		post.height = 4.6 + RIDE_HEIGHT
		var pole := MeshInstance3D.new()
		pole.mesh = post
		pole.material_override = white
		pole.transform = Transform3D(mid.basis, mid * Vector3(4.5, (4.6 - RIDE_HEIGHT) / 2.0, along))
		holder.add_child(pole)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 2.0
	light.omni_range = 18.0
	light.position = mid * Vector3(1.5, 3.0, 0)
	holder.add_child(light)

func _train() -> void:
	for i in range(CARS):
		var car: Node3D = load(MODEL % ("coaster-train-front" if i == 0 else "coaster-train")).instantiate()
		var holder := Node3D.new()
		holder.name = "Car%d" % i
		car.scale = Vector3.ONE * KIT
		holder.add_child(car)
		add_child(holder)
		cars.append(holder)

func _place_train() -> void:
	for i in range(cars.size()):
		cars[i].transform = frame_at(at - i * CAR_GAP)

# Where to stand to get in: on the platform beside the front car.
func boarding() -> Vector3:
	return frame_at(HOME) * Vector3(2.2, 0.0, 0.0)

func near_board(at_point: Vector3) -> bool:
	return not riding and to_local(at_point).distance_to(boarding()) < REACH

# --- The ride ----------------------------------------------------------------------------------

# The ring of light on the climb: going through it is going into the dream.
func _gateway() -> void:
	var d := HOME
	while d < HOME + length and frame_at(d).origin.y < GATE_HEIGHT:
		d += 1.0
	gate_at = fposmod(d, length)
	return_at = fposmod(HOME - RETURN_BEFORE, length)
	var f := frame_at(gate_at)
	var ring := TorusMesh.new()
	ring.inner_radius = 4.6
	ring.outer_radius = 5.4
	ring.rings = 64
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(2.2, 1.6, 3.2)
	var halo := MeshInstance3D.new()
	halo.name = "Gateway"
	halo.mesh = ring
	halo.material_override = glow
	halo.transform = Transform3D(f.basis * Basis(Vector3.RIGHT, PI / 2), f * Vector3(0, 1.2, 0))
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.6, 1.0)
	light.light_energy = 3.0
	light.omni_range = 20.0
	light.position = f * Vector3(0, 1.2, 0)
	add_child(light)

func _player(name: String, loop: bool, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load(SOUND % name) if name != "music" else load(MUSIC)
	if loop:
		stream = stream.duplicate()
		stream.loop = true
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func _sounds() -> void:
	wind = _player("wind_loop", true, -80.0)
	rumble = _player("rumble", true, -80.0)
	deep = _player("underwater_pad", true, -80.0)
	music = _player("music", true, -80.0)
	for name in ["launch", "warp", "warp_boom", "memory_glass"]:
		one_shots[name] = _player(name, false, -6.0)
	var swishes := AudioStreamRandomizer.new()
	for i in [1, 3, 5, 8, 10]:
		swishes.add_stream(-1, load(SOUND % ("swish_%d" % i)))
	swishes.random_pitch = 1.15
	var swish := AudioStreamPlayer.new()
	swish.stream = swishes
	swish.volume_db = -4.0
	add_child(swish)
	one_shots["swish"] = swish
	var splashes := AudioStreamRandomizer.new()
	for i in ["01", "03", "05"]:
		splashes.add_stream(-1, load(SOUND % ("splash_" + i)))
	var wet := AudioStreamPlayer.new()
	wet.stream = splashes
	wet.volume_db = 2.0
	wet.pitch_scale = 0.55
	add_child(wet)
	one_shots["splash"] = wet
	var chime := AudioStreamPlayer.new()
	chime.stream = load("res://assets/audio/memory.wav")
	chime.volume_db = -8.0
	add_child(chime)
	one_shots["chime"] = chime

func _play(name: String, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = one_shots[name]
	player.pitch_scale = pitch if name != "splash" else 0.55
	player.play()

# Sparks streaming off the front wheels when the train is going fast, and a burst of spray for
# hitting the water.
func _sparks() -> void:
	sparks = GPUParticles3D.new()
	sparks.amount = 120
	sparks.lifetime = 0.5
	sparks.local_coords = false
	sparks.emitting = false
	sparks.layers = 1 | Dream.LAYER
	sparks.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.7, 0.05, 0.3)
	process.direction = Vector3(0, 0.4, 1)
	process.spread = 25.0
	process.initial_velocity_min = 4.0
	process.initial_velocity_max = 10.0
	process.gravity = Vector3(0, -6, 0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	sparks.process_material = process
	var dot := QuadMesh.new()
	dot.size = Vector2(0.08, 0.08)
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hot.albedo_color = Color(4.0, 2.2, 0.6)
	dot.material = hot
	sparks.draw_pass_1 = dot
	sparks.position = Vector3(0, 0.1, -1.4)
	cars[0].add_child(sparks)
	splash = GPUParticles3D.new()
	splash.amount = 260
	splash.lifetime = 1.4
	splash.one_shot = true
	splash.explosiveness = 0.9
	splash.emitting = false
	splash.local_coords = false
	splash.layers = Dream.LAYER
	splash.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var spray := ParticleProcessMaterial.new()
	spray.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 2.0
	spray.direction = Vector3(0, 1, 0)
	spray.spread = 55.0
	spray.initial_velocity_min = 6.0
	spray.initial_velocity_max = 16.0
	spray.gravity = Vector3(0, -14, 0)
	spray.scale_min = 0.5
	spray.scale_max = 1.6
	splash.process_material = spray
	var drop := QuadMesh.new()
	drop.size = Vector2(0.35, 0.35)
	var foam := StandardMaterial3D.new()
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.albedo_color = Color(1.6, 1.9, 2.0, 0.8)
	drop.material = foam
	splash.draw_pass_1 = drop
	add_child(splash)
	splash.top_level = true

func ride(walker: CharacterBody3D) -> void:
	rider = walker
	riding = true
	ride_time = 0.0
	travelled = 0.0
	top_speed = 0.0
	inverted = false
	dreamed = false
	speed = 0.0
	phase = "track"
	rider.set_physics_process(false)
	rider.velocity = Vector3.ZERO
	rider.yaw = 0.0
	rider.pitch = -0.05
	base_fov = rider.camera.fov
	_play("launch")
	music.volume_db = -30.0
	music.play()
	wind.play()
	rumble.play()

func _process(delta: float) -> void:
	if not riding:
		return
	ride_time += delta
	swish_wait = maxf(swish_wait - delta, 0.0)
	music.volume_db = move_toward(music.volume_db, -7.0 if phase != "home" or travelled < length - 80.0 else -40.0, delta * 12.0)
	if phase == "dream":
		_dream_step(delta)
	else:
		_track_step(delta)
	var seat := cars[0].global_transform
	rider.frame = seat.basis.orthonormalized()
	rider.global_position = seat * SEAT
	rider.eye = 0.0
	top_speed = maxf(top_speed, speed)
	# The faster, the wider the view, the harder the shake and the louder the wind.
	var rush := clampf((speed - 12.0) / 60.0, 0.0, 1.0)
	rider.camera.fov = base_fov + rush * 30.0
	var shake := clampf((speed - 30.0) / 50.0, 0.0, 1.0) * 0.035
	rider.camera.h_offset = randf_range(-shake, shake)
	rider.camera.v_offset = randf_range(-shake, shake)
	wind.volume_db = lerpf(-36.0, -4.0, rush)
	wind.pitch_scale = 0.8 + rush * 0.5
	rumble.volume_db = lerpf(-30.0, -10.0, rush) - (8.0 if phase == "dream" else 0.0)
	rumble.pitch_scale = 0.6 + rush * 0.6
	sparks.emitting = speed > 34.0
	if phase == "home" and travelled >= length - 0.01 and speed < 0.7:
		_step_off()

# On the fair's track: launch, climb to the ring, or back home and braking into the station.
func _track_step(delta: float) -> void:
	var f := frame_at(at)
	var climb := (-f.basis.z).y
	var left := length - travelled
	if travelled < launch_end:
		speed = minf(speed + LAUNCH_PUSH * delta, LAUNCH)
	elif left < BRAKE_FROM:
		var want := lerpf(0.0, CRAWL * 2.5, left / BRAKE_FROM)
		speed = move_toward(speed, maxf(want, 0.6 if left > 0.5 else 0.0), delta * 14.0)
	else:
		speed += (-GRAVITY * climb - DRAG * speed * speed) * delta
		speed = maxf(speed, CRAWL)
	var moved := speed * delta
	if travelled + moved >= length:
		moved = length - travelled
	at = fposmod(at + moved, length)
	travelled += moved
	_place_train()
	if f.basis.y.y < -0.9:
		inverted = true
	if phase == "track" and travelled >= fposmod(gate_at - HOME, length):
		_into_dream()

func _into_dream() -> void:
	phase = "dream"
	dreamed = true
	dream_d = 0.0
	speed = maxf(speed, 42.0)
	dream.begin()
	rider.camera.environment = dream.environment
	for car in cars:
		for mesh: VisualInstance3D in car.find_children("*", "VisualInstance3D", true, false):
			mesh.layers = 1 | Dream.LAYER
	_play("warp")
	_play("warp_boom", 0.8)
	flash.emit(1.0)
	dream_changed.emit(true)
	was_under = false

# Out on the dream's endless track: fast, faster going down, slower climbing.
func _dream_step(delta: float) -> void:
	var f: Transform3D = dream.frame_at(dream_d)
	var target := clampf(DREAM_SPEED - 32.0 * (-f.basis.z).y, 40.0, 88.0)
	speed = move_toward(speed, target, delta * 10.0)
	dream_d += speed * delta
	for i in range(cars.size()):
		cars[i].global_transform = dream.frame_at(maxf(dream_d - i * CAR_GAP, 0.0))
	var swept: int = dream.update(dream_d, rider.camera, delta)
	if swept > 0 and swish_wait <= 0.0:
		_play("swish", randf_range(0.9, 1.2))
		swish_wait = 0.25
	var height: float = dream.to_local(cars[0].global_position).y - Dream.SEA_LEVEL
	var under := height < 0.0
	if under != was_under and dream_d < Dream.DEEP_END + 400.0:
		_play("splash")
		splash.global_position = cars[0].global_position
		splash.restart()
		flash.emit(0.25)
	was_under = under
	deep.volume_db = move_toward(deep.volume_db, -4.0 if dream.underwater > 0.5 else -60.0, delta * 30.0)
	if not deep.playing:
		deep.play()
	if dream_d >= Dream.END - 55.0:
		_out_of_dream()

func _out_of_dream() -> void:
	caught = dream.taken
	_remember()
	phase = "home"
	dream.finish()
	deep.stop()
	rider.camera.environment = null
	for car in cars:
		for mesh: VisualInstance3D in car.find_children("*", "VisualInstance3D", true, false):
			mesh.layers = 1
	at = return_at
	travelled = length - fposmod(HOME - return_at, length)
	speed = 26.0
	_place_train()
	_play("warp")
	flash.emit(1.0)
	dream_changed.emit(false)

func _on_shard(count: int, total: int) -> void:
	_play("memory_glass", 1.0 + count * 0.03)
	_play("chime", 1.0 + count * 0.04)
	shard_taken.emit(count, total)

# The shards caught this ride, added to those caught before (kept with the game's progress).
func _remember() -> void:
	var progress := preload("res://scripts/game_progress.gd")
	if not progress.recording:
		return
	var file := ConfigFile.new()
	file.load(progress.path)
	var known: Array = file.get_value("meadow", "memory_shards", [])
	for id: int in dream.taken_ids:
		if not known.has(id):
			known.append(id)
	file.set_value("meadow", "memory_shards", known)
	file.save(progress.path)

func _step_off() -> void:
	at = HOME
	_place_train()
	riding = false
	phase = "track"
	wind.stop()
	rumble.stop()
	music.stop()
	sparks.emitting = false
	rider.camera.fov = base_fov
	rider.camera.h_offset = 0.0
	rider.camera.v_offset = 0.0
	rider.eye = rider.EYE
	rider.frame = global_basis.orthonormalized()
	rider.global_position = to_global(boarding() + Vector3(0, 0.05, 0))
	rider.velocity = Vector3.ZERO
	rider.set_physics_process(true)
	rider = null
	ride_over.emit()
