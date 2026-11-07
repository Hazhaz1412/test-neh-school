extends Node3D

# The cabinet jumpscare. Cockroaches and spiders that have nested in the dark cabinet burst out
# when the door swings open: a handful leap straight at the camera and scramble across the
# lens, the rest pour onto the tiles and scatter under the stalls. Nothing here is supernatural
# and nothing does damage; the scare is the speed, the sound and how close they get.
const LEAPERS := 16
const RUNNERS := 26
const PLANE := -0.24
const SCREEN := Vector2(0.36, 0.21)
const LEAP_SECONDS := Vector2(0.16, 0.42)
const LOCK_SECONDS := 1.5
const ROACH := "res://assets/polypizza_insects/cockroach.glb"
const SPIDER := "res://assets/opengameart_spider/spider.glb"
var world: Node3D
var camera: Camera3D
var bugs: Array[Dictionary] = []
var burst: AudioStreamPlayer
var skitter: AudioStreamPlayer3D
var clock := -1.0
var origin := Transform3D.IDENTITY
var floor_y := 0.0
var bounds := AABB()
var shake := 0.0

func setup(school: Node3D) -> void:
	world = school
	camera = world.player.camera
	name = "InsectSwarm"
	burst = AudioStreamPlayer.new()
	burst.stream = load("res://assets/audio/insect_burst.wav")
	burst.volume_db = -1
	add_child(burst)
	skitter = AudioStreamPlayer3D.new()
	var loop: AudioStreamWAV = load("res://assets/audio/insect_skitter.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	skitter.stream = loop
	skitter.unit_size = 4
	skitter.max_distance = 18
	skitter.volume_db = -6
	add_child(skitter)
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.22, 0.11, 0.05)
	shell.roughness = 0.25
	shell.metallic = 0.15
	var close_shell := shell.duplicate() as StandardMaterial3D
	# This close the torch would burn them white.
	close_shell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	close_shell.albedo_color = Color(0.11, 0.055, 0.03)
	var hide := StandardMaterial3D.new()
	hide.albedo_texture = load("res://assets/opengameart_spider/spider.png")
	hide.roughness = 0.8
	var close_hide := hide.duplicate() as StandardMaterial3D
	close_hide.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(LEAPERS + RUNNERS):
		var spider := i % 3 == 2
		var model: Node3D = load(SPIDER if spider else ROACH).instantiate()
		add_child(model)
		var leaper := i < LEAPERS
		for part in model.find_children("*", "MeshInstance3D", true, false):
			part.material_override = (close_hide if leaper else hide) if spider else (close_shell if leaper else shell)
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if spider:
			var animation: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
			var clip: Animation = animation.get_animation("WALK")
			clip.loop_mode = Animation.LOOP_LINEAR
			animation.play("WALK")
			animation.speed_scale = 3.0
			animation.seek(i * 0.07)
		model.hide()
		# Spiders are a little smaller than the roaches, as they would be.
		var span := ((0.05 if spider else 0.065) if leaper else (0.07 if spider else 0.09)) * randf_range(0.8, 1.2)
		bugs.append({"model": model, "spider": spider, "leaper": leaper, "fit": span / _longest(model), "basis": _rest_basis(model, spider),
			"state": "off", "from": Vector3.ZERO, "to": Vector2.ZERO, "at": Vector2.ZERO, "pos": Vector3.ZERO, "dir": Vector3.ZERO,
			"speed": 0.0, "delay": 0.0, "t": 0.0, "length": 0.0, "wiggle": randf() * TAU})

func _longest(model: Node3D) -> float:
	var box := _bounds(model)
	return maxf(box.size.x, maxf(box.size.y, box.size.z))

func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (model.global_transform.affine_inverse() * part.global_transform) * part.get_aabb() if model.is_inside_tree() else part.transform * part.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box

# Turns the model so its head points along -Z and its back along +Y.
func _rest_basis(model: Node3D, spider: bool) -> Basis:
	if spider:
		return Basis.IDENTITY
	# The roach lies along its longest horizontal axis with its head towards +X.
	var box := _bounds(model)
	return Basis(Vector3.UP, PI / 2) if box.size.x >= box.size.z else Basis.IDENTITY

func active() -> bool:
	return clock >= 0.0

func locks_player() -> bool:
	return clock >= 0.0 and clock < LOCK_SECONDS

# `nest` sits inside the cabinet facing out of its door (-Z of the transform points into the room).
func start(nest: Transform3D, room: AABB) -> void:
	origin = nest
	bounds = room
	floor_y = room.position.y + 0.02
	clock = 0.0
	shake = 0.45
	burst.play()
	skitter.global_position = nest.origin
	skitter.play()
	for bug in bugs:
		var inside: Vector3 = nest * Vector3(randf_range(-0.3, 0.3), randf_range(-0.7, 0.7), randf_range(-0.1, 0.12))
		bug.t = 0.0
		bug.from = inside
		bug.pos = inside
		bug.delay = randf_range(0.0, 0.22) if bug.leaper else randf_range(0.05, 0.9)
		bug.state = "wait"
		if bug.leaper:
			bug.length = randf_range(LEAP_SECONDS.x, LEAP_SECONDS.y)
			bug.to = Vector2(randf_range(-SCREEN.x, SCREEN.x) * 0.6, randf_range(-SCREEN.y, SCREEN.y) * 0.7)
			bug.speed = randf_range(0.28, 0.5)
		else:
			var away: Vector3 = -nest.basis.z
			away.y = 0
			bug.dir = away.normalized().rotated(Vector3.UP, randf_range(-1.4, 1.4))
			bug.speed = randf_range(0.9, 1.9)
			bug.length = randf_range(2.0, 4.2)
		bug.model.hide()

func stop() -> void:
	clock = -1.0
	shake = 0.0
	if camera != null:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	if skitter != null: skitter.stop()
	if burst != null: burst.stop()
	for bug in bugs:
		bug.state = "off"
		bug.model.hide()

func _process(delta: float) -> void:
	if clock < 0.0 or world == null:
		return
	if not world.simulation_active():
		for audio in [burst, skitter]: audio.stream_paused = true
		return
	for audio in [burst, skitter]: audio.stream_paused = false
	clock += delta
	shake = maxf(0.0, shake - delta)
	camera.h_offset = randf_range(-1, 1) * shake * 0.03
	camera.v_offset = randf_range(-1, 1) * shake * 0.02
	var busy := false
	for bug in bugs:
		if bug.state == "off": continue
		busy = true
		bug.wiggle += delta * 40.0
		if bug.state == "wait":
			bug.delay -= delta
			if bug.delay <= 0.0:
				bug.state = "leap" if bug.leaper else "run"
				bug.model.show()
			continue
		if bug.state == "leap":
			bug.t += delta / bug.length
			var target := camera.global_transform * Vector3(bug.to.x, bug.to.y, PLANE)
			var arc := sin(clampf(bug.t, 0, 1) * PI) * 0.35
			var p: Vector3 = bug.from.lerp(target, ease(clampf(bug.t, 0, 1), 0.6)) + Vector3.UP * arc
			# Tumbling through the air, legs towards the player at the end.
			var tumble := Basis(Vector3(1, 0.3, 0).normalized(), bug.t * 9.0 + bug.wiggle * 0.05)
			var facing := camera.global_basis * Basis(Vector3.RIGHT, PI / 2)
			var turned := tumble.slerp(facing, clampf(bug.t * 1.4, 0, 1))
			bug.model.global_transform = Transform3D(turned.orthonormalized() * bug.basis.scaled(Vector3.ONE * bug.fit), p)
			if bug.t >= 1.0:
				bug.state = "crawl"
				bug.at = bug.to
				bug.t = 0.0
		elif bug.state == "crawl":
			# Scramble outward to the nearest edge of the screen and drop off it.
			var out: Vector2 = bug.at.normalized() if bug.at.length() > 0.01 else Vector2.RIGHT
			var heading := (out + Vector2(cos(bug.wiggle * 0.13), sin(bug.wiggle * 0.11)) * 0.35).normalized()
			bug.at += heading * bug.speed * delta
			_pose_on_lens(bug, heading)
			if absf(bug.at.x) > SCREEN.x + 0.05 or absf(bug.at.y) > SCREEN.y + 0.05:
				bug.state = "off"
				bug.model.hide()
		elif bug.state == "run":
			bug.t += delta
			if bug.pos.y > floor_y + 0.01:
				# Spill over the lip of the shelf and drop to the tiles.
				bug.pos += bug.dir * delta * 0.6
				bug.pos.y = maxf(floor_y, bug.pos.y - delta * 3.5)
			else:
				var swerve := sin(bug.wiggle * 0.07) * 0.9
				var step: Vector3 = bug.dir.rotated(Vector3.UP, swerve) * bug.speed * delta
				var next: Vector3 = bug.pos + step
				if next.x < bounds.position.x + 0.15 or next.x > bounds.end.x - 0.15:
					bug.dir.x = -bug.dir.x
				if next.z < bounds.position.z + 0.15 or next.z > bounds.end.z - 0.15:
					bug.dir.z = -bug.dir.z
				bug.pos += bug.dir.rotated(Vector3.UP, swerve) * bug.speed * delta
				bug.pos.y = floor_y
			var move: Vector3 = bug.dir.rotated(Vector3.UP, sin(bug.wiggle * 0.07) * 0.9)
			var look := Basis.looking_at(Vector3(move.x, 0, move.z).normalized() if Vector2(move.x, move.z).length() > 0.01 else Vector3.FORWARD, Vector3.UP)
			bug.model.global_transform = Transform3D(look * bug.basis.scaled(Vector3.ONE * bug.fit), bug.pos + Vector3.UP * absf(sin(bug.wiggle)) * 0.002)
			# They vanish into the dark: under a stall, into the drain, behind the pipes.
			if bug.t >= bug.length:
				bug.state = "off"
				bug.model.hide()
	skitter.volume_db = lerpf(-6.0, -30.0, clampf((clock - 2.0) / 4.0, 0, 1))
	if not busy or clock > 9.0:
		stop()

func _pose_on_lens(bug: Dictionary, heading: Vector2) -> void:
	var forward := Vector3(heading.x, heading.y, 0)
	var back := Vector3.BACK
	var side := back.cross(forward)
	var local := Transform3D(Basis(side, back, -forward) * bug.basis.scaled(Vector3.ONE * bug.fit * 1.4), Vector3(bug.at.x, bug.at.y, PLANE))
	bug.model.global_transform = camera.global_transform * local
