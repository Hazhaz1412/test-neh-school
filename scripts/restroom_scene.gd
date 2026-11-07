extends Node3D

# Everything the prologue changes in the second-floor restroom (A-203), directly above the lit
# classroom 103. The wall mirror over the third basin falls and smashes the tap, so water
# sprays, spreads across the tiles, seeps out under the door into the corridor and drips
# through the ceiling into 103. Those are the trail: the player hears the crash overhead,
# sees water dripping from the ceiling, follows the stairs up and finds the wet floor spreading
# from the restroom door. Inside, something keeps glinting through the crack of the cleaning
# cabinet; opening it lets out the insects and leaves the broken hand mirror on the shelf.
const FLOOR := 3.9
const ROOM := Vector3(14.5, FLOOR, -3.0)
const ROOM_SIZE := Vector2(15.0, 18.0)
const WALL_X := 7.125
const BASINS: Array[float] = [-4.05, -2.55, -1.05, 0.45]
const BROKEN_BASIN := 2
const CABINET := Vector3(7.42, FLOOR, -8.6)
const DRIP := Vector3(12.4, 3.585, 2.3)
# Wet floor path from the broken basin to the door gap and into the corridor.
# It runs on along the corridor towards the main stairs, so the player meets it at the top.
const PUDDLE_PATH: Array[Vector3] = [Vector3(7.85, FLOOR, -1.05), Vector3(9.4, FLOOR, 0.4), Vector3(11.4, FLOOR, 2.2), Vector3(13.4, FLOOR, 4.1), Vector3(14.4, FLOOR, 5.5), Vector3(14.5, FLOOR, 6.4), Vector3(13.9, FLOOR, 7.4), Vector3(12.2, FLOOR, 7.7), Vector3(10.3, FLOOR, 7.5), Vector3(8.4, FLOOR, 7.7), Vector3(6.5, FLOOR, 7.4), Vector3(4.8, FLOOR, 7.6)]
const INSIDE_PUDDLES := 5
const SPREAD_SECONDS := 20.0
# Matches furnish_restroom in tools/build_map.gd: six stalls along the east wall.
const STALL_FRONT_X := 20.3
const STALL_BACK_X := 22.0
const STALL_FIRST_Z := -10.1
const STALL_WIDTH := 1.55
const STALL_COUNT := 6
const STALL_OPEN := [1.2, 1.1, 0.25, 0.9, 1.4, 1.0]
var story: Node3D
var world: Node3D
var mirrors: Array[MeshInstance3D] = []
var broken_glass: ShaderMaterial
var shards: Node3D
var spray: CPUParticles3D
var leak: AudioStreamPlayer3D
var drip_sound: AudioStreamPlayer3D
var drips: CPUParticles3D
var dust: CPUParticles3D
var puddles: Array[MeshInstance3D] = []
var drip_pool: MeshInstance3D
var ceiling_stain: MeshInstance3D
var cabinet: Node3D
var cabinet_door: Node3D
var cabinet_area: Area3D
var cabinet_glint: MeshInstance3D
var glint_material: ShaderMaterial
var swarm: Node3D
var hand_mirror: Node3D
var broken := false
var cabinet_open := false
var door_swing := 0.0
var since_crash := 0.0
var drip_clock := 0.0
# Once the player is in the restroom the leak has done its job as a beacon; it dies away so
# the hiding and the guard's footsteps can be heard.
var leak_fading := false
const LEAK_FADE_SECONDS := 3.0
const LEAK_VOLUME := -4.0
var stall_doors: Array[Node3D] = []

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "RestroomScene"
	_build_mirrors()
	_build_shards()
	_build_leak()
	_build_cabinet()
	_build_stall_doors()
	swarm = preload("res://scripts/insect_swarm.gd").new()
	add_child(swarm)
	swarm.setup(world)
	hand_mirror = story.make_interactable("mirror", CABINET + Vector3(0.02, 1.02, 0.08))
	hand_mirror.rotation.y = 0.5
	reset()

func _mat(color: Color, metallic := 0.0, roughness := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, label := "") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if label != "": node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func _solid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, label := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	if label != "": body.name = label
	body.position = pos
	parent.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(body, mesh, Vector3.ZERO, mat)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body

func _build_mirrors() -> void:
	var frame := _mat(Color(0.62, 0.64, 0.66), 0.85, 0.3)
	var intact := _mat(Color(0.42, 0.44, 0.45), 1.0, 0.06)
	broken_glass = ShaderMaterial.new()
	broken_glass.shader = preload("res://assets/materials/cracked_glass.gdshader")
	broken_glass.set_shader_parameter("impact", Vector2(0.46, 0.6))
	broken_glass.set_shader_parameter("hole", 0.22)
	broken_glass.set_shader_parameter("aspect", 1.25)
	broken_glass.set_shader_parameter("glass", Color(0.42, 0.44, 0.45))
	# Lets the mirrors show the room rather than the sky.
	var probe := ReflectionProbe.new()
	probe.name = "RestroomReflections"
	probe.position = ROOM + Vector3(0, 1.6, 0)
	probe.size = Vector3(ROOM_SIZE.x, 3.4, ROOM_SIZE.y)
	probe.interior = true
	probe.box_projection = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)
	for i in range(BASINS.size()):
		var panel := BoxMesh.new()
		panel.size = Vector3(0.012, 0.9, 1.12)
		var glass := _mesh(self, panel, Vector3(WALL_X + 0.03, FLOOR + 1.62, BASINS[i]), intact, "WallMirror%d" % i)
		glass.set_meta("intact", intact)
		mirrors.append(glass)
		var trim := BoxMesh.new()
		trim.size = Vector3(0.02, 0.96, 1.18)
		_mesh(self, trim, Vector3(WALL_X + 0.02, FLOOR + 1.62, BASINS[i]), frame)

func _build_shards() -> void:
	shards = Node3D.new()
	shards.name = "MirrorShards"
	add_child(shards)
	var glass := _mat(Color(0.72, 0.76, 0.78), 1.0, 0.04)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2031
	for i in range(38):
		var shard := PrismMesh.new()
		var s := rng.randf_range(0.03, 0.16)
		shard.size = Vector3(s, s * rng.randf_range(0.8, 1.8), 0.004)
		var on_counter := i < 12
		var pos := Vector3(rng.randf_range(7.25, 7.7), FLOOR + 0.87, BASINS[BROKEN_BASIN] + rng.randf_range(-0.6, 0.6)) if on_counter else Vector3(rng.randf_range(7.8, 9.6), FLOOR + 0.022, BASINS[BROKEN_BASIN] + rng.randf_range(-1.3, 1.3))
		var piece := _mesh(shards, shard, pos, glass)
		piece.rotation = Vector3(-PI / 2 + rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf() * TAU)
	# The bigger glints, so the mess reads in torchlight from the door.
	for i in range(5):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.18, 0.18)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/materials/glint.gdshader")
		mat.set_shader_parameter("phase", i * 1.7)
		mat.set_shader_parameter("intensity", 0.5)
		mat.set_shader_parameter("rays", 0.5)
		var glint := _mesh(shards, quad, Vector3(8.0 + i * 0.35, FLOOR + 0.06, BASINS[BROKEN_BASIN] - 0.8 + i * 0.4), mat)
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_leak() -> void:
	spray = CPUParticles3D.new()
	spray.name = "TapSpray"
	spray.position = Vector3(WALL_X + 0.2, FLOOR + 1.08, BASINS[BROKEN_BASIN])
	spray.amount = 90
	spray.lifetime = 0.55
	spray.direction = Vector3(1, 0.35, 0)
	spray.spread = 22
	spray.initial_velocity_min = 1.0
	spray.initial_velocity_max = 1.8
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.6
	spray.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.006
	drop.height = 0.016
	drop.radial_segments = 6
	drop.rings = 3
	var water := _mat(Color(0.78, 0.86, 0.92, 0.55), 0.0, 0.02)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = water
	spray.mesh = drop
	add_child(spray)
	leak = AudioStreamPlayer3D.new()
	leak.stream = story.loop_wav("res://assets/audio/water_leak.wav")
	leak.position = spray.position
	leak.unit_size = 4.5
	leak.max_distance = 42
	leak.volume_db = -4
	add_child(leak)
	# Standing water: darker than dry tile and mirror-smooth, so the torch flares off it.
	var wet := _mat(Color(0.03, 0.04, 0.05, 0.62), 0.6, 0.0)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.specular = 1.0
	for i in range(PUDDLE_PATH.size()):
		var disc := CylinderMesh.new()
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 0.002
		disc.radial_segments = 20
		var spot := _mesh(self, disc, PUDDLE_PATH[i] + Vector3(0, 0.03 + i * 0.0004, 0), wet, "Puddle%d" % i)
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddles.append(spot)
	# Through the slab: a stain spreading on 103's ceiling and drops falling under it.
	var stain_mesh := CylinderMesh.new()
	stain_mesh.top_radius = 0.5
	stain_mesh.bottom_radius = 0.5
	stain_mesh.height = 0.002
	stain_mesh.radial_segments = 20
	var stain := _mat(Color(0.20, 0.19, 0.15, 0.7), 0.0, 0.2)
	stain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ceiling_stain = _mesh(self, stain_mesh, DRIP + Vector3(0, -0.005, 0), stain, "CeilingStain")
	drip_pool = _mesh(self, stain_mesh, Vector3(DRIP.x, 0.03, DRIP.z), wet, "DripPool")
	drips = CPUParticles3D.new()
	drips.name = "CeilingDrips"
	drips.position = DRIP
	drips.amount = 4
	drips.lifetime = 0.9
	drips.direction = Vector3.DOWN
	drips.spread = 1
	drips.initial_velocity_min = 0.2
	drips.initial_velocity_max = 0.3
	drips.gravity = Vector3(0, -9.8, 0)
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drips.emission_sphere_radius = 0.08
	var bead := SphereMesh.new()
	bead.radius = 0.008
	bead.height = 0.022
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = water
	drips.mesh = bead
	add_child(drips)
	drip_sound = AudioStreamPlayer3D.new()
	drip_sound.stream = load("res://assets/audio/water_drip.wav")
	drip_sound.position = Vector3(DRIP.x, 0.1, DRIP.z)
	drip_sound.unit_size = 3
	drip_sound.max_distance = 20
	drip_sound.volume_db = -6
	add_child(drip_sound)
	dust = CPUParticles3D.new()
	dust.name = "CeilingDust"
	dust.position = Vector3(13.5, 3.6, 0.5)
	dust.amount = 160
	dust.lifetime = 3.2
	dust.one_shot = true
	dust.explosiveness = 0.85
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(3.5, 0.02, 3.5)
	dust.direction = Vector3.DOWN
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.3
	dust.gravity = Vector3(0, -0.35, 0)
	var mote := QuadMesh.new()
	mote.size = Vector2(0.012, 0.012)
	var mote_mat := _mat(Color(0.85, 0.78, 0.62, 0.7))
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.material = mote_mat
	dust.mesh = mote
	dust.emitting = false
	add_child(dust)

func _build_cabinet() -> void:
	cabinet = Node3D.new()
	cabinet.name = "CleaningCabinet"
	cabinet.position = CABINET
	# Local -Z faces out of the wall into the room.
	cabinet.rotation.y = -PI / 2
	add_child(cabinet)
	var paint := _mat(Color(0.42, 0.47, 0.44), 0.55, 0.55)
	var inner := _mat(Color(0.12, 0.12, 0.11), 0.2, 0.9)
	var w := 0.9
	var h := 1.9
	var d := 0.5
	_solid(cabinet, Vector3(0, h * 0.5, d * 0.5 - 0.01), Vector3(w, h, 0.02), inner, "Back")
	for side in [-1, 1]:
		_solid(cabinet, Vector3(side * (w * 0.5 - 0.01), h * 0.5, 0), Vector3(0.02, h, d), paint, "Side")
	_solid(cabinet, Vector3(0, h - 0.01, 0), Vector3(w, 0.02, d), paint, "Top")
	_solid(cabinet, Vector3(0, 0.06, 0), Vector3(w, 0.12, d), paint, "Plinth")
	for y in [0.55, 1.0, 1.45]:
		_solid(cabinet, Vector3(0, y, 0.02), Vector3(w - 0.04, 0.02, d - 0.06), inner, "Shelf")
	# Mess on the lower shelves: a bucket, a few bottles, a folded rag.
	var bucket := CylinderMesh.new()
	bucket.top_radius = 0.13
	bucket.bottom_radius = 0.1
	bucket.height = 0.26
	_mesh(cabinet, bucket, Vector3(-0.2, 0.25, 0.05), _mat(Color(0.2, 0.32, 0.55)))
	for i in range(3):
		var bottle := CylinderMesh.new()
		bottle.top_radius = 0.035
		bottle.bottom_radius = 0.04
		bottle.height = 0.24
		_mesh(cabinet, bottle, Vector3(0.12 + i * 0.1, 0.68, 0.06), _mat([Color(0.85, 0.85, 0.8), Color(0.3, 0.6, 0.35), Color(0.7, 0.25, 0.2)][i]))
	cabinet_door = Node3D.new()
	cabinet_door.name = "DoorHinge"
	cabinet_door.position = Vector3(-w * 0.5, 0, -d * 0.5)
	cabinet.add_child(cabinet_door)
	var leaf := _solid(cabinet_door, Vector3(w * 0.5, h * 0.5, -0.01), Vector3(w, h - 0.02, 0.02), paint, "Leaf")
	leaf.collision_layer = 1
	for row in range(5):
		var vent := BoxMesh.new()
		vent.size = Vector3(0.36, 0.012, 0.005)
		_mesh(cabinet_door, vent, Vector3(w * 0.5, 1.55 + row * 0.04, -0.023), inner)
	var handle := BoxMesh.new()
	handle.size = Vector3(0.02, 0.14, 0.03)
	_mesh(cabinet_door, handle, Vector3(w - 0.08, 1.0, -0.04), _mat(Color(0.7, 0.7, 0.68), 0.9, 0.3))
	cabinet_area = Area3D.new()
	cabinet_area.name = "Interaction"
	cabinet_area.collision_mask = 0
	var touch := CollisionShape3D.new()
	var touch_shape := BoxShape3D.new()
	touch_shape.size = Vector3(w, h - 0.2, 0.08)
	touch.shape = touch_shape
	touch.position = Vector3(0, h * 0.5, -d * 0.5 - 0.06)
	cabinet_area.add_child(touch)
	var proxy := Node3D.new()
	proxy.name = "CabinetHandle"
	proxy.set_script(preload("res://scripts/restroom_cabinet.gd"))
	proxy.set("scene", self)
	cabinet.add_child(proxy)
	proxy.add_child(cabinet_area)
	# Whatever is inside catches the light through the crack of the door.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	glint_material = ShaderMaterial.new()
	glint_material.shader = preload("res://assets/materials/glint.gdshader")
	glint_material.set_shader_parameter("twinkle_speed", 1.7)
	cabinet_glint = _mesh(cabinet, quad, Vector3(w * 0.5 - 0.12, 1.06, -0.12), glint_material, "CrackGlint")
	cabinet_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_stall_doors() -> void:
	var panel := _mat(Color(0.36, 0.47, 0.50), 0.0, 0.55)
	var latch := _mat(Color(0.7, 0.7, 0.68), 0.9, 0.3)
	for i in range(STALL_COUNT):
		var hinge := Node3D.new()
		hinge.name = "StallDoor%d" % (i + 1)
		hinge.position = Vector3(STALL_FRONT_X, FLOOR, STALL_FIRST_Z + i * STALL_WIDTH + 0.04)
		add_child(hinge)
		var width := STALL_WIDTH - 0.1
		var leaf := _solid(hinge, Vector3(0, 1.05, width * 0.5), Vector3(0.04, 1.75, width), panel, "Leaf")
		leaf.collision_layer = 1
		var knob := BoxMesh.new()
		knob.size = Vector3(0.06, 0.04, 0.08)
		_mesh(hinge, knob, Vector3(-0.03, 1.0, width - 0.12), latch)
		var handle := Node3D.new()
		handle.name = "StallHandle"
		handle.set_script(preload("res://scripts/restroom_stall.gd"))
		handle.set("scene", self)
		handle.set("index", i)
		hinge.add_child(handle)
		var area := Area3D.new()
		area.name = "Interaction"
		area.collision_layer = 16
		area.collision_mask = 0
		var touch := CollisionShape3D.new()
		var touch_shape := BoxShape3D.new()
		# Thick enough to reach from inside the stall as well as from the room.
		touch_shape.size = Vector3(0.5, 1.6, width)
		touch.shape = touch_shape
		touch.position = Vector3(0, 1.0, width * 0.5)
		area.add_child(touch)
		handle.add_child(area)
		hinge.set_meta("open", true)
		hinge.set_meta("swing", float(STALL_OPEN[i]))
		stall_doors.append(hinge)

func stall_open(index: int) -> bool:
	return bool(stall_doors[index].get_meta("open"))

func toggle_stall(index: int) -> void:
	var hinge := stall_doors[index]
	var open := not stall_open(index)
	# Swinging shut onto someone standing in the doorway would trap them in the leaf.
	if not open and _in_doorway(index, world.player.global_position): return
	hinge.set_meta("open", open)
	world.soundscape.at("door", hinge.global_position + Vector3(0, 1, 0.7), -20)
	world.emit_noise(hinge.global_position, 5.0, "door")

# The guard shoves a stall door open to look inside.
func guard_open_stall(index: int) -> void:
	if stall_open(index): return
	stall_doors[index].set_meta("open", true)
	world.soundscape.at("door_bang", stall_doors[index].global_position + Vector3(0, 1, 0.7), -8)

func stall_front(index: int) -> Vector3:
	return Vector3(STALL_FRONT_X - 1.05, FLOOR, STALL_FIRST_Z + (index + 0.5) * STALL_WIDTH)

func stall_center(index: int) -> Vector3:
	return Vector3((STALL_FRONT_X + STALL_BACK_X) * 0.5, FLOOR, STALL_FIRST_Z + (index + 0.5) * STALL_WIDTH)

# Which stall the player is standing in, shut or not; -1 when outside them all.
func player_stall() -> int:
	var at: Vector3 = world.player.global_position
	if absf(at.y - FLOOR) > 1.0 or at.x < STALL_FRONT_X or at.x > STALL_BACK_X: return -1
	var index := int(floor((at.z - STALL_FIRST_Z) / STALL_WIDTH))
	return index if index >= 0 and index < STALL_COUNT else -1

func _in_doorway(index: int, at: Vector3) -> bool:
	var z0 := STALL_FIRST_Z + index * STALL_WIDTH
	return at.x > STALL_FRONT_X - 0.35 and at.x < STALL_FRONT_X + 0.3 and at.z > z0 and at.z < z0 + STALL_WIDTH and absf(at.y - FLOOR) < 1.0

func player_inside() -> bool:
	var at: Vector3 = world.player.global_position
	return absf(at.y - FLOOR) < 1.0 and at.x > ROOM.x - ROOM_SIZE.x * 0.5 and at.x < ROOM.x + ROOM_SIZE.x * 0.5 and at.z > ROOM.z - ROOM_SIZE.y * 0.5 and at.z < ROOM.z + ROOM_SIZE.y * 0.5 - 0.15

# The player is shut inside a stall: nobody passing the restroom can see them.
func player_in_closed_stall() -> bool:
	var at: Vector3 = world.player.global_position
	if absf(at.y - FLOOR) > 1.0 or at.x < STALL_FRONT_X or at.x > STALL_BACK_X: return false
	var index := int(floor((at.z - STALL_FIRST_Z) / STALL_WIDTH))
	return index >= 0 and index < STALL_COUNT and not stall_open(index)

func reset() -> void:
	broken = false
	for hinge in stall_doors:
		hinge.set_meta("open", true)
		hinge.rotation.y = -float(hinge.get_meta("swing"))
	cabinet_open = false
	since_crash = 0.0
	drip_clock = 0.0
	leak_fading = false
	leak.volume_db = LEAK_VOLUME
	spray.initial_velocity_min = 1.0
	spray.initial_velocity_max = 1.8
	door_swing = deg_to_rad(9.0)
	cabinet_door.rotation.y = door_swing
	cabinet_area.collision_layer = 0
	for glass in mirrors: glass.material_override = glass.get_meta("intact")
	shards.hide()
	spray.emitting = false
	spray.hide()
	drips.emitting = false
	dust.emitting = false
	leak.stop()
	drip_sound.stop()
	for spot in puddles: spot.hide()
	drip_pool.hide()
	ceiling_stain.hide()
	cabinet_glint.hide()
	hand_mirror.set_available(false)
	swarm.stop()

# The mirror comes off the wall. Called right after the player picks up the hair clip.
func shatter() -> void:
	broken = true
	since_crash = 0.0
	mirrors[BROKEN_BASIN].material_override = broken_glass
	shards.show()
	spray.show()
	spray.emitting = true
	dust.restart()
	dust.emitting = true
	cabinet_glint.show()
	cabinet_area.collision_layer = 16

func cabinet_text() -> String:
	return "E · Mở tủ đồ"

func open_cabinet() -> void:
	if cabinet_open or not broken: return
	cabinet_open = true
	cabinet_area.collision_layer = 0
	cabinet_glint.hide()
	var nest: Transform3D = cabinet.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0.0))
	var room := AABB(Vector3(ROOM.x - ROOM_SIZE.x * 0.5, FLOOR, ROOM.z - ROOM_SIZE.y * 0.5), Vector3(ROOM_SIZE.x, 2.5, ROOM_SIZE.y))
	swarm.start(nest, room)
	world.player.velocity = Vector3.ZERO
	story.fear.beat(-8.0)

func locks_player() -> bool:
	return swarm.locks_player()

func _process(delta: float) -> void:
	if world == null or not world.simulation_active():
		for audio in [leak, drip_sound]: audio.stream_paused = true
		return
	for audio in [leak, drip_sound]: audio.stream_paused = false
	# The door flies open on the swarm, then settles.
	var target := deg_to_rad(112.0) if cabinet_open else deg_to_rad(9.0)
	door_swing = move_toward(door_swing, target, delta * (14.0 if cabinet_open else 3.0))
	cabinet_door.rotation.y = door_swing
	for hinge in stall_doors:
		var target_swing: float = float(hinge.get_meta("swing")) if hinge.get_meta("open") else 0.0
		hinge.rotation.y = move_toward(hinge.rotation.y, -target_swing, delta * 4.0)
	if cabinet_open and not swarm.locks_player() and not hand_mirror.visible and not story.evidence.has("mirror"):
		hand_mirror.set_available(true)
	if not broken: return
	since_crash += delta
	if since_crash > 0.6 and not leak.playing and not leak_fading: leak.play()
	if not leak_fading and player_inside(): leak_fading = true
	if leak_fading and leak.playing:
		# The pipe empties: the spray sputters out and the sound fades.
		leak.volume_db = move_toward(leak.volume_db, -60.0, delta * (56.0 / LEAK_FADE_SECONDS))
		var pressure := clampf((leak.volume_db + 60.0) / (60.0 + LEAK_VOLUME), 0.0, 1.0)
		spray.initial_velocity_min = 1.0 * pressure
		spray.initial_velocity_max = 1.8 * pressure
		if leak.volume_db <= -59.0:
			leak.stop()
			spray.emitting = false
	# Water spreads from the basin to the door, then out under it.
	var spread := clampf(since_crash / SPREAD_SECONDS, 0, 1)
	for i in range(puddles.size()):
		var reach := clampf(spread * puddles.size() - i, 0, 1)
		puddles[i].visible = reach > 0.02
		var radius := lerpf(0.15, 0.85 if i < INSIDE_PUDDLES else 0.62, reach)
		puddles[i].scale = Vector3(radius * 1.8, 1, radius * 1.3)
	# Through the slab after a few seconds: a growing stain and a slow drip into 103.
	var seep := clampf((since_crash - 4.0) / 12.0, 0, 1)
	ceiling_stain.visible = seep > 0
	ceiling_stain.scale = Vector3.ONE * lerpf(0.2, 1.4, seep)
	drip_pool.visible = seep > 0.2
	drip_pool.scale = Vector3(lerpf(0.1, 0.9, seep), 1, lerpf(0.1, 0.7, seep))
	drips.emitting = seep > 0.05
	if seep > 0.05:
		drip_clock -= delta
		if drip_clock <= 0.0:
			drip_clock = randf_range(0.7, 1.4)
			drip_sound.pitch_scale = randf_range(0.9, 1.15)
			drip_sound.play()
	if cabinet_glint.visible:
		# A slow shimmer that flares when the torch sweeps across the crack.
		var camera: Camera3D = world.player.camera
		var to_glint := (cabinet_glint.global_position - camera.global_position)
		var aim := maxf(0.0, (-camera.global_basis.z).dot(to_glint.normalized()))
		var lit: bool = world.player.flashlight.visible
		glint_material.set_shader_parameter("intensity", 0.55 + (pow(aim, 10.0) * 1.8 if lit else 0.0))

func stop_audio() -> void:
	for audio in [leak, drip_sound]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
