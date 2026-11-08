extends Node3D

# The school's night guard in the prologue. He works through a queue of small jobs (walk a
# route, open a door and shine the torch round a room, stop and look back, listen, clear the
# papers in 306) and he notices the player only through his own senses:
# - sight: what his torch beam lights, a torch pointed at him from far off, anything close;
# - hearing: the noise each footstep makes (running loud, walking, crouching barely),
#   muffled by every floor in between.
# What he notices fills `awareness`. A sound turns him towards it; at 1.0 he has seen enough.
# After the photo he hunts: he walks a patrol over floors 2 and 3 on the navmesh, and a noise
# makes him go and look where it came from before he carries on.
signal caught
# Instead of `caught`, when catch_on_sight is off: he has seen the player and gives chase.
signal spotted
signal task_done(tag: String)

const WALK := 2.1
# Ground speed of the fast-walk clip at speed_scale 1, so the feet do not slide.
const CLIP_PACE := 1.8
const RUN := 6.5
const RUN_PACE := 5.0
const EYE := 1.6
const BEAM_RANGE := 14.0
const BEAM_RANGE_CROUCHED := 8.0
const BEAM_HALF_ANGLE := 30.0
const TORCH_SEEN_RANGE := 30.0
const TORCH_SEEN_ANGLE := 70.0
const NEAR := 2.0
const PERIPHERAL := 4.5
const PERIPHERAL_ANGLE := 65.0
const FLOOR_MUFFLE := 0.3
const HEAR_GAIN := 0.5
const DECAY := 0.12
const TURN_RATE := 5.0
# Metres per footfall: a brisk walk, and the long strides of an old man running flat out.
const STRIDE := 0.78
const RUN_STRIDE := 1.55
const HUNT_WALK := 2.4
const HUNT_RUSH := 3.2
# Navmesh points float this far above the floor.
const NAV_LIFT := 0.6
const INVESTIGATE_REACH := 32.0
var world: Node3D
var story: Node3D
var model: Node3D
var torch: SpotLight3D
var step_sound: AudioStreamPlayer3D
var keys: AudioStreamPlayer3D
var whistle: AudioStreamPlayer3D
var tasks: Array[Dictionary] = []
var task: Dictionary = {}
var clock := 0.0
var sensing := false
var awareness := 0.0
var sees_player := false
var heard_clock := 0.0
var stride := 0.0
var sweep := 0.0
var yaw_goal := 0.0
var concealed: Callable = func() -> bool: return false
var patrol: Array = []
var patrol_index := 0
var hunting := false
var catch_on_sight := true
# While he is running someone down, a noise does not turn him aside.
var deaf := false

# Recorded hard-soled steps on stone (assets/audio/guard_steps, CC0), never the same twice running.
static func shoe_steps() -> AudioStreamRandomizer:
	var steps := AudioStreamRandomizer.new()
	steps.random_pitch = 1.06
	steps.random_volume_offset_db = 1.5
	steps.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for side in ["L", "R"]:
		for i in range(1, 4):
			steps.add_stream(-1, load("res://assets/audio/guard_steps/stone_%s%d.ogg" % [side, i]))
	return steps

static func torch_mesh() -> Node3D:
	var body := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.028
	tube.bottom_radius = 0.022
	tube.height = 0.24
	tube.radial_segments = 10
	body.mesh = tube
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.06, 0.06, 0.065)
	black.metallic = 0.5
	black.roughness = 0.4
	body.material_override = black
	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.03
	disc.bottom_radius = 0.03
	disc.height = 0.01
	lens.mesh = disc
	lens.position.y = 0.125
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(1, 0.94, 0.8)
	glow.emission_energy_multiplier = 3.0
	lens.material_override = glow
	body.add_child(lens)
	return body

# A peaked guard's cap, sized for the Rocketbox head bone frame (metres, model frame).
static func guard_cap() -> Node3D:
	var cap := Node3D.new()
	cap.name = "GuardCap"
	var navy := StandardMaterial3D.new()
	navy.albedo_color = Color(0.08, 0.11, 0.2)
	navy.roughness = 0.7
	var crown := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.118
	cylinder.bottom_radius = 0.104
	cylinder.height = 0.075
	crown.mesh = cylinder
	crown.material_override = navy
	crown.position = Vector3(0, 0.17, 0.015)
	cap.add_child(crown)
	var peak := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.17, 0.012, 0.08)
	peak.mesh = slab
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.025)
	black.roughness = 0.3
	peak.material_override = black
	peak.position = Vector3(0, 0.14, 0.12)
	peak.rotation.x = 0.2
	cap.add_child(peak)
	var badge := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.03, 0.025, 0.005)
	badge.mesh = plate
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.65, 0.25)
	brass.metallic = 0.9
	brass.roughness = 0.3
	badge.material_override = brass
	badge.position = Vector3(0, 0.175, 0.12)
	cap.add_child(badge)
	return cap

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "SecurityGuard"
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "guard"
	model.target_height = 1.7
	model.rotation.y = PI
	add_child(model)
	model.bone_frame("Head", "GuardHead").add_child(guard_cap())
	model.bone_frame("Fist.R", "GuardTorch").add_child(torch_mesh())
	torch = SpotLight3D.new()
	torch.name = "GuardTorch"
	torch.light_color = Color(1.0, 0.92, 0.75)
	torch.light_energy = 3.4
	torch.spot_range = BEAM_RANGE + 4.0
	torch.spot_angle = BEAM_HALF_ANGLE
	torch.spot_attenuation = 0.8
	torch.shadow_enabled = true
	torch.position = Vector3(0.22, 1.38, -0.42)
	add_child(torch)
	step_sound = _audio("res://assets/audio/footstep.wav", 6, 34, -6)
	step_sound.stream = shoe_steps()
	keys = _audio("res://assets/audio/guard_keys.wav", 4, 26, -12, true)
	whistle = _audio("res://assets/audio/guard_whistle.wav", 20, 90, 0)
	stop()

func _audio(path: String, unit: float, reach: float, volume: float, loop := false) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = story.loop_wav(path) if loop else load(path)
	player.unit_size = unit
	player.max_distance = reach
	player.volume_db = volume
	player.position.y = 1.0
	add_child(player)
	return player

func stop() -> void:
	tasks.clear()
	task = {}
	patrol = []
	patrol_index = 0
	hunting = false
	catch_on_sight = true
	deaf = false
	sensing = false
	awareness = 0.0
	sees_player = false
	sweep = 0.0
	hide()
	set_process(false)
	if keys != null: keys.stop()
	if model != null and model.animation != null:
		model.animation.speed_scale = 0
		model.set_process(false)

func place(at: Vector3, facing: Vector3) -> void:
	global_position = at
	yaw_goal = atan2(-(facing - at).x, -(facing - at).z)
	rotation.y = yaw_goal
	show()
	set_process(true)
	model.set_process(true)
	model.animation.speed_scale = 1.0
	model.animation.play("idle")

func run(jobs: Array) -> void:
	tasks.assign(jobs)
	task = {}
	_next()

# --- Job helpers, so callers can write a route as a list ---

static func walk(points: Array, speed := WALK) -> Dictionary:
	return {"do": "walk", "path": points, "i": 0, "speed": speed, "anim": "walk"}

static func sprint(points: Array, speed := RUN) -> Dictionary:
	return {"do": "walk", "path": points, "i": 0, "speed": speed, "anim": "sprint"}

# Walk to a point by the navmesh; the route is worked out when the job starts.
static func goto(at: Vector3, speed := WALK, running := false) -> Dictionary:
	return {"do": "goto", "to": at, "speed": speed, "anim": "sprint" if running else "walk"}

static func wait(seconds: float, anim := "idle", sweeping := false) -> Dictionary:
	return {"do": "wait", "seconds": seconds, "anim": anim, "sweep": sweeping}

static func face(at: Vector3) -> Dictionary:
	return {"do": "face", "at": at}

static func say(text: String, seconds := 2.6) -> Dictionary:
	return {"do": "say", "text": text, "seconds": seconds}

static func door(number: int, open: bool) -> Dictionary:
	return {"do": "door", "number": number, "open": open}

static func mark(tag: String) -> Dictionary:
	return {"do": "mark", "tag": tag}

static func act(callable: Callable) -> Dictionary:
	return {"do": "act", "fn": callable}

static func work() -> Dictionary:
	return {"do": "work"}

# Stops, turns round and sweeps the torch down the way he came, then carries on.
static func look_back(from: Vector3, toward: Vector3, seconds := 2.6) -> Array[Dictionary]:
	return [{"do": "face", "at": toward}, wait(seconds, "look_around", true), {"do": "face", "at": from}]

# A navmesh route, put back down on the floor so his feet are not in the air.
func route_to(to: Vector3) -> Array:
	var map := get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, global_position + Vector3.UP * 0.3)
	var goal := NavigationServer3D.map_get_closest_point(map, to + Vector3.UP * 0.3)
	var points: Array = []
	for point in NavigationServer3D.map_get_path(map, from, goal, true):
		points.append(_ground(point))
	if points.is_empty() or Vector2(points[-1].x - to.x, points[-1].z - to.z).length() < 1.0:
		points.append(to)
	return points

func _ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point - Vector3.UP * (NAV_LIFT + 0.8), 1)
	query.exclude = [world.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else point - Vector3.UP * 0.4

static func path_length(points: Array, from: Vector3) -> float:
	var length := 0.0
	var at := from
	for point in points:
		length += at.distance_to(point)
		at = point
	return length

func _next() -> void:
	clock = 0.0
	if tasks.is_empty() and not patrol.is_empty():
		var stop: Dictionary = patrol[patrol_index % patrol.size()]
		patrol_index += 1
		tasks.append(goto(stop.at, HUNT_WALK))
		tasks.append(wait(stop.look, "look_around", true))
	if tasks.is_empty():
		task = {}
		model.animation.play("idle")
		keys.stop()
		return
	task = tasks.pop_front()
	if task.do == "goto":
		task = {"do": "walk", "path": route_to(task.to), "i": 0, "speed": task.speed, "anim": task.anim}
	match task.do:
		"walk":
			var running: bool = task.get("anim", "walk") == "sprint"
			model.animation.play("sprint" if running else "walk")
			model.animation.speed_scale = float(task.speed) / (RUN_PACE if running else CLIP_PACE)
			if not keys.playing: keys.play()
		"wait":
			model.animation.play(task.anim)
			model.animation.speed_scale = 1.0
			keys.stop()
		"face":
			model.animation.play("idle")
			var to: Vector3 = task.at - global_position
			yaw_goal = atan2(-to.x, -to.z)
		"say":
			story.subtitle("Bác bảo vệ", task.text, task.seconds)
			_next()
		"door":
			var leaf: Node3D = world.get_node_or_null("Architecture/ClassroomDoor%d" % task.number)
			if leaf != null: leaf.set_open(task.open, true)
			_next()
		"mark":
			# A listener may hand him new jobs; only carry on if it did not.
			var tag: String = task.tag
			task = {}
			task_done.emit(tag)
			if task.is_empty(): _next()
		"act":
			task.fn.call()
			_next()
		"work":
			model.animation.play("documents")
			model.animation.speed_scale = 1.0
			keys.stop()

func busy_with(kind: String) -> bool:
	return task.get("do", "") == kind

# A noise or a glimpse: turn to it and listen, then go back to what he was doing.
func investigate(at: Vector3, line := "Hửm...?") -> void:
	if task.get("do", "") == "work":
		# Absorbed in the papers; he only half turns.
		yaw_goal = rotation.y
		return
	if hunting:
		# He goes to look. The patrol stop he was making for comes after.
		tasks.clear()
		tasks.append({"do": "face", "at": at})
		tasks.append(wait(0.8, "listen"))
		if absf(at.y - global_position.y) < 2.0:
			var route := route_to(at)
			if path_length(route, global_position) < INVESTIGATE_REACH:
				tasks.append({"do": "walk", "path": route, "i": 0, "speed": HUNT_RUSH, "anim": "walk"})
				tasks.append(wait(2.6, "look_around", true))
		if not patrol.is_empty(): patrol_index = maxi(0, patrol_index - 1)
		story.subtitle("Bác bảo vệ", line if line != "Hửm...?" else ["Ai đó?!", "Tiếng gì thế?", "Ra đây!"][randi() % 3], 1.8)
		_next()
		return
	if not task.is_empty():
		# A wait he was in the middle of carries on where it was, not from the start.
		if task.do == "wait": task.seconds = maxf(0.2, float(task.seconds) - clock)
		tasks.push_front(task)
	tasks.push_front(wait(2.4, "listen", true))
	tasks.push_front({"do": "face", "at": at})
	story.subtitle("Bác bảo vệ", line, 1.8)
	_next()

func hear(at: Vector3, radius: float, source: String) -> void:
	if not sensing or not visible: return
	var floors := roundi(absf(at.y - global_position.y) / 3.9)
	var reach := radius * pow(FLOOR_MUFFLE, floors)
	var distance := global_position.distance_to(at)
	if distance > reach: return
	var gain := (1.0 - distance / reach) * HEAR_GAIN * (1.6 if source == "glass" else 1.0)
	awareness = minf(1.0, awareness + gain)
	if heard_clock <= 0.0 and not deaf:
		heard_clock = 3.0
		investigate(at)
	_check_caught()

func can_see_player() -> bool:
	var p: CharacterBody3D = world.player
	if p.is_hidden() or concealed.call(): return false
	var eye := global_position + Vector3.UP * EYE
	var target: Vector3 = p.sight_point()
	var to := target - eye
	var distance := to.length()
	var forward := -global_basis.z.rotated(Vector3.UP, sweep)
	var angle := rad_to_deg(forward.angle_to(to))
	var flat_angle := rad_to_deg(Vector2(forward.x, forward.z).angle_to(Vector2(to.x, to.z)))
	var spotted := false
	if distance < NEAR: spotted = true
	elif distance < PERIPHERAL and absf(flat_angle) < PERIPHERAL_ANGLE: spotted = true
	elif angle < BEAM_HALF_ANGLE and distance < (BEAM_RANGE_CROUCHED if p.crouching else BEAM_RANGE): spotted = true
	elif p.flashlight.visible and absf(flat_angle) < TORCH_SEEN_ANGLE and distance < TORCH_SEEN_RANGE: spotted = true
	if not spotted: return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	query.exclude = [p.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _check_caught() -> void:
	if sensing and awareness >= 1.0 and not catch_on_sight:
		spotted.emit()
		return
	if sensing and awareness >= 1.0:
		sensing = false
		tasks.clear()
		task = {}
		var p: CharacterBody3D = world.player
		var to := p.global_position - global_position
		yaw_goal = atan2(-to.x, -to.z)
		model.animation.play("idle")
		keys.stop()
		whistle.play()
		caught.emit()

func _process(delta: float) -> void:
	if not world.simulation_active():
		model.animation.speed_scale = 0
		for audio in [step_sound, keys, whistle]: audio.stream_paused = true
		return
	for audio in [step_sound, keys, whistle]: audio.stream_paused = false
	if model.animation.speed_scale == 0: model.animation.speed_scale = 1.0
	clock += delta
	heard_clock = maxf(0.0, heard_clock - delta)
	match task.get("do", ""):
		"walk": _tick_walk(delta)
		"wait":
			if task.sweep: sweep = sin(clock * 1.6) * 0.6
			if clock >= task.seconds:
				sweep = 0.0
				_next()
		"face":
			if absf(angle_difference(rotation.y, yaw_goal)) < 0.08 or clock > 1.2: _next()
		"work":
			sweep = -0.35
	rotation.y = lerp_angle(rotation.y, yaw_goal, clampf(delta * TURN_RATE, 0, 1))
	sweep = move_toward(sweep, 0.0, delta * 0.4) if task.get("do", "") != "wait" and task.get("do", "") != "work" else sweep
	torch.rotation = Vector3(-0.22, sweep, 0)
	model.hand_target = global_position + Vector3.UP * 1.4 + (-global_basis.z.rotated(Vector3.UP, sweep)) * 0.8
	if sensing:
		sees_player = can_see_player()
		if sees_player:
			var distance: float = global_position.distance_to(world.player.global_position)
			awareness = minf(1.0, awareness + delta * lerpf(2.4, 0.7, clampf(distance / BEAM_RANGE, 0, 1)))
		else:
			awareness = maxf(0.0, awareness - delta * DECAY)
		_check_caught()

func _tick_walk(delta: float) -> void:
	var path: Array = task.path
	var left := float(task.speed) * delta
	while left > 0.0 and int(task.i) < path.size():
		var goal: Vector3 = path[task.i]
		var to := goal - global_position
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > 0.05: yaw_goal = atan2(-flat.x, -flat.z)
		if to.length() <= left:
			global_position = goal
			left -= to.length()
			task.i = int(task.i) + 1
		else:
			global_position += to.normalized() * left
			left = 0.0
	stride -= float(task.speed) * delta
	if stride <= 0.0:
		var running: bool = task.get("anim", "walk") == "sprint"
		stride = RUN_STRIDE if running else STRIDE
		step_sound.volume_db = -3.0 if running else -10.0
		step_sound.pitch_scale = 0.92 if running else 0.88
		step_sound.play()
	if int(task.i) >= path.size(): _next()

func whistle_now() -> void:
	whistle.play()
