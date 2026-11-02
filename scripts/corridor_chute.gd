extends Node3D
# The floor gives way twice. Below is a long slide: the keys do nothing, the rider drifts towards
# wherever the camera leans, and the hands growing out of the walls leave only one lane open.
const RADIUS := 2.4
const RING_STEP := 3.0
const RING_SIDES := 28
const SPEED := 13.0
const SPEED_GAIN := 3.0
const SPEED_HURT := 6.5
const HURT_SECONDS := 0.8
const DRIFT := 6.5
const ARC_LIMIT := 2.7
const LEAN_LIMIT := 1.05
const LEAN_DECAY := 0.25
const PITCH_LIMIT := 0.6
const LANES := [-1.7, 0.0, 1.7]
const LANE_HALF := 0.85
const HAND_SEEN := 44.0
const HAND_RISEN := 27.0
const ARMS_PER_LANE := 4
const ARM_LENGTH := 1.9
const ARM_GIRTH := 1.3
const BEHIND := 9.0
const EXIT_GAP := 12.0
const GAP_PER_HIT := 2.0
const EXIT_GAP_MIN := 4.0
const HOLE_REACH := 2.0
# Each gate names the lanes the hands close. The second slide is longer and leaves less room.
const RUNS := [
	{"start": 384.0, "exit": 408.0, "length": 200.0, "origin": Vector3(0, -60, 0), "swarms": [[78.0, 4], [150.0, 5]],
		"gates": [[40.0, [1]], [62.0, [0]], [84.0, [2]], [106.0, [0, 1]], [130.0, [1, 2]], [156.0, [0, 2]], [180.0, [0, 1]]]},
	{"start": 636.0, "exit": 656.0, "length": 270.0, "origin": Vector3(0, -170, 0), "swarms": [[62.0, 5], [130.0, 6], [204.0, 7]],
		"gates": [[34.0, [0, 1]], [54.0, [1, 2]], [74.0, [0, 2]], [94.0, [0, 1]], [112.0, [1, 2]], [130.0, [0, 1]], [148.0, [0, 2]], [166.0, [1, 2]], [184.0, [0, 1]], [202.0, [0, 2]], [220.0, [1, 2]], [240.0, [0, 1]]]},
]
static var arm_mesh: ArrayMesh
var run: Node3D
var spiders: Node3D
var active := false
var used := {}
var tubes: Array[Node3D] = []
var gates: Array = [[], []]
var lamps: Array[OmniLight3D] = []
var slide_sound: AudioStreamPlayer
var current := -1
var metres := 0.0
var arc := 0.0
var lean := 0.0
var pitch := 0.0
var speed := 0.0
var hurt_left := 0.0
var hits := 0
var next_swarm := 0
var hint: Label

func setup(runner: Node3D) -> void:
	run = runner
	spiders = preload("res://scripts/corridor_spiders.gd").new()
	add_child(spiders)
	slide_sound = AudioStreamPlayer.new()
	slide_sound.stream = run.story.loop_wav("res://assets/audio/chair_scrape.wav")
	slide_sound.pitch_scale = 0.55
	slide_sound.volume_db = -10
	add_child(slide_sound)
	for i in range(2):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.16, 0.08)
		lamp.omni_range = 18
		lamp.hide()
		add_child(lamp)
		lamps.append(lamp)
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 90
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_font_override("font", preload("res://scripts/horror_type.gd").TITLE)
	hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.7))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	layer.add_child(hint)

func build() -> void:
	spiders.setup(run)
	for index in range(RUNS.size()):
		var tube := Node3D.new()
		tube.hide()
		add_child(tube)
		tubes.append(tube)
		_build_tube(tube, index)
		for gate in RUNS[index].gates:
			gates[index].append(_build_gate(tube, index, gate[0], gate[1]))

func centre(index: int, along: float) -> Vector3:
	var origin: Vector3 = RUNS[index].origin
	return origin + Vector3(14.0 * sin(along * 0.021) + 6.0 * sin(along * 0.053), -along * 0.2, -along)

func frame(index: int, along: float) -> Transform3D:
	var heading := (centre(index, along + 1.0) - centre(index, along - 1.0)).normalized()
	var right := heading.cross(Vector3.UP).normalized()
	return Transform3D(Basis(right, right.cross(heading), -heading), centre(index, along))

func surface_point(place: Transform3D, offset: float, inset := 0.0) -> Vector3:
	var angle := offset / RADIUS
	return place.origin + (place.basis.x * sin(angle) - place.basis.y * cos(angle)) * (RADIUS - inset)

func _build_tube(tube: Node3D, index: int) -> void:
	var length: float = RUNS[index].length
	var maker := SurfaceTool.new()
	maker.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := int((length + 12.0) / RING_STEP)
	for ring in range(rings):
		var near := frame(index, -6.0 + ring * RING_STEP)
		var far := frame(index, -6.0 + (ring + 1) * RING_STEP)
		for side in range(RING_SIDES):
			var a := TAU * side / RING_SIDES
			var b := TAU * (side + 1) / RING_SIDES
			var quad := [[near, a], [far, a], [far, b], [near, b]]
			for corner in [0, 1, 2, 0, 2, 3]:
				var point := _on_ring(quad[corner][0], quad[corner][1])
				maker.set_normal((quad[corner][0].origin - point).normalized())
				maker.add_vertex(point)
	var shell := MeshInstance3D.new()
	shell.mesh = maker.commit()
	var wall: StandardMaterial3D = run.material(Color(0.5, 0.16, 0.13) if index == 0 else Color(0.34, 0.2, 0.3))
	wall.albedo_texture = load("res://assets/polyhaven_horror/rubble_diff_1k.jpg")
	wall.uv1_triplanar = true
	wall.uv1_world_triplanar = true
	wall.uv1_scale = Vector3.ONE * 0.4
	wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = wall
	tube.add_child(shell)
	var lamp_paint: StandardMaterial3D = run.material(Color(0.95, 0.08, 0.025), true)
	var along := 8.0
	while along < length:
		var place := frame(index, along)
		var strip := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(1.4, 0.06, 0.24)
		strip.mesh = bar
		strip.material_override = lamp_paint
		tube.add_child(strip)
		strip.transform = Transform3D(place.basis, place.origin + place.basis.y * (RADIUS - 0.08))
		along += 12.0

func _on_ring(place: Transform3D, angle: float) -> Vector3:
	return place.origin + (place.basis.x * sin(angle) - place.basis.y * cos(angle)) * RADIUS

func _build_gate(tube: Node3D, index: int, along: float, closed: Array) -> Dictionary:
	var place := frame(index, along)
	var arms: Array[Dictionary] = []
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = load("res://assets/rocketbox/textures/student_b_body.jpg")
	skin.albedo_color = Color(0.86, 0.88, 0.8)
	skin.emission_enabled = true
	skin.emission = Color(0.16, 0.14, 0.13)
	skin.roughness = 0.75
	for lane in closed:
		for i in range(ARMS_PER_LANE):
			var offset: float = LANES[lane] + (i - 1.5) * 0.46
			var root := surface_point(place, offset)
			var inward := (place.origin - root).normalized()
			var lean_back := (inward + place.basis.z * 0.45 + place.basis.x * (i - 1.5) * 0.14).normalized()
			var arm := MeshInstance3D.new()
			arm.mesh = _arm()
			arm.material_override = skin
			tube.add_child(arm)
			var axis := Vector3.UP.cross(lean_back)
			var turn := Basis.IDENTITY if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(lean_back))
			arms.append({"node": arm, "root": root, "turn": turn, "phase": along + i * 1.7})
			arm.hide()
	return {"at": along, "closed": closed, "arms": arms, "done": false}

# The hands are the left-over arm of the MIT Rocketbox student, baked straight and pointing up.
static func _arm() -> ArrayMesh:
	if arm_mesh != null:
		return arm_mesh
	var source: Node3D = load("res://assets/rocketbox/Male_Child_01.fbx").instantiate()
	var body: MeshInstance3D = source.find_children("*", "MeshInstance3D", true, false)[0]
	var skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var wanted := []
	for bind in range(body.skin.get_bind_count()):
		var title := String(body.skin.get_bind_name(bind))
		if " R " in title and ("Forearm" in title or "Hand" in title or "Finger" in title):
			wanted.append(bind)
	var stride := bones.size() / points.size()
	var kept := []
	for v in range(points.size()):
		var share := 0.0
		for slot in range(stride):
			if bones[v * stride + slot] in wanted:
				share += weights[v * stride + slot]
		kept.append(share > 0.5)
	var lowest := INF
	var highest := -INF
	var along := _arm_axis(points, kept)
	for v in range(points.size()):
		if kept[v]:
			lowest = minf(lowest, points[v].dot(along))
			highest = maxf(highest, points[v].dot(along))
	var middle := Vector3.ZERO
	var count := 0
	for v in range(points.size()):
		if kept[v]:
			middle += points[v]
			count += 1
	middle /= count
	var turn := Basis(along.cross(Vector3.UP).normalized(), along.angle_to(Vector3.UP))
	var factor := ARM_LENGTH / (highest - lowest)
	var maker := SurfaceTool.new()
	maker.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in range(0, indices.size(), 3):
		if not (kept[indices[tri]] and kept[indices[tri + 1]] and kept[indices[tri + 2]]):
			continue
		for v in indices.slice(tri, tri + 3):
			maker.set_normal((turn * normals[v]).normalized())
			maker.set_uv(uvs[v])
			var relative := points[v] - middle
			var across := relative - along * relative.dot(along)
			maker.add_vertex(turn * (across + along * (points[v].dot(along) - lowest)) * factor)
	arm_mesh = maker.commit()
	source.free()
	return arm_mesh

# The vertices furthest from the middle are the sleeve's cut end, so the fingers lie the other way.
static func _arm_axis(points: PackedVector3Array, kept: Array) -> Vector3:
	var first := Vector3.ZERO
	var count := 0
	for v in range(points.size()):
		if kept[v]:
			first += points[v]
			count += 1
	first /= count
	var far := first
	for v in range(points.size()):
		if kept[v] and points[v].distance_squared_to(first) > far.distance_squared_to(first):
			far = points[v]
	return (first - far).normalized()

func reset() -> void:
	active = false
	used.clear()
	current = -1
	hint.text = ""
	spiders.clear()
	slide_sound.stop()
	for lamp in lamps:
		lamp.hide()
	for tube in tubes:
		tube.hide()
	for group in gates:
		for gate in group:
			gate.done = false
			for arm in gate.arms:
				arm.node.hide()

func opening_at(meters: float) -> int:
	for index in range(RUNS.size()):
		if not used.has(index) and meters >= RUNS[index].start - HOLE_REACH:
			return index
	return -1

func enter(index: int) -> void:
	var p: CharacterBody3D = run.world.player
	used[index] = true
	active = true
	current = index
	metres = 0.0
	arc = clampf(run.lane_x, -ARC_LIMIT, ARC_LIMIT)
	lean = 0.0
	pitch = -0.08
	speed = maxf(run.speed, 8.0)
	hurt_left = 0.0
	hits = 0
	next_swarm = 0
	tubes[index].show()
	for lamp in lamps:
		lamp.show()
	p.velocity = Vector3.ZERO
	p.get_node("Collision").shape.height = 0.68
	p.get_node("Collision").position.y = 0.36
	p.camera.position = Vector3(0, 0.52, 0)
	run.looking_back = false
	run.slide_remaining = 0.0
	run.scares.flash.color = Color(0, 0, 0, 1)
	run.scares.impact(p.global_position, "topple")
	run.world.notify("Sàn sập! Nghiêng camera để lách khỏi bàn tay.")
	slide_sound.play()
	_place()

func look(relative: Vector2) -> void:
	var p: CharacterBody3D = run.world.player
	lean = clampf(lean + relative.x * p.LOOK_SENSITIVITY, -LEAN_LIMIT, LEAN_LIMIT)
	pitch = clampf(pitch - relative.y * p.LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	spiders.shake(relative.x)

func tick(delta: float) -> void:
	var length: float = RUNS[current].length
	hurt_left = maxf(0.0, hurt_left - delta)
	var wanted: float = SPEED_HURT if hurt_left > 0.0 else SPEED + SPEED_GAIN * metres / length
	speed = move_toward(speed, wanted, delta * 12.0)
	var before := metres
	metres += speed * delta
	arc = clampf(arc + sin(lean) / sin(LEAN_LIMIT) * DRIFT * delta, -ARC_LIMIT, ARC_LIMIT)
	lean = move_toward(lean, 0.0, LEAN_DECAY * delta)
	_tick_gates(before)
	var swarms: Array = RUNS[current].swarms
	if next_swarm < swarms.size() and metres >= swarms[next_swarm][0]:
		spiders.swarm(swarms[next_swarm][1])
		next_swarm += 1
	spiders.tick(delta)
	hint.text = "Lắc chuột trái phải thật nhanh để hất lũ nhện!" if spiders.crawling() else ("Nghiêng camera sang đâu là trượt về đó" if metres < 30.0 else "")
	_place()
	if metres >= length:
		leave()

func _tick_gates(before: float) -> void:
	for gate in gates[current]:
		var lead: float = gate.at - metres
		var near: bool = lead > -6.0 and lead < HAND_SEEN
		var rise := smoothstep(HAND_SEEN, HAND_RISEN, lead)
		for arm in gate.arms:
			arm.node.visible = near
			if near:
				var grope: float = sin(run.clock * 7.0 + arm.phase) * 0.12
				arm.node.transform = Transform3D(arm.turn * Basis(Vector3.RIGHT, grope) * Basis.from_scale(Vector3(ARM_GIRTH, maxf(rise, 0.02), ARM_GIRTH)), arm.root)
		if not gate.done and before < gate.at and metres >= gate.at:
			gate.done = true
			for lane in gate.closed:
				if absf(arc - LANES[lane]) < LANE_HALF:
					_grabbed()
					break

func _grabbed() -> void:
	hits += 1
	hurt_left = HURT_SECONDS
	run.obstacle_hit()
	run.scares._flash(Color(0.7, 0.02, 0.0, 0.45))
	run.scares.shake = maxf(run.scares.shake, 0.8)

func safe_arc(from: float) -> float:
	for gate in gates[current]:
		if gate.at > from:
			for lane in range(LANES.size()):
				if lane not in gate.closed:
					return LANES[lane]
	return 0.0

func _place() -> void:
	var p: CharacterBody3D = run.world.player
	var place := frame(current, metres)
	var heading := -place.basis.z
	p.global_position = run.global_transform * surface_point(place, arc, 0.05)
	p.rotation = Vector3(0, atan2(-heading.x, -heading.z) - lean, 0)
	p.camera.rotation = Vector3(pitch + asin(heading.y), 0, arc / RADIUS * 0.8)
	for i in range(lamps.size()):
		var ahead := frame(current, metres + [10.0, 28.0][i])
		lamps[i].position = ahead.origin + ahead.basis.y * 1.2
		lamps[i].light_energy = 3.6 + sin(run.clock * 13.0 + i) * 0.5
	var behind: Vector3 = run.to_global(frame(current, maxf(0.0, metres - BEHIND)).origin)
	run.chase_steps.global_position = behind
	run.snarls.global_position = behind

func leave() -> void:
	var p: CharacterBody3D = run.world.player
	var outing: Dictionary = RUNS[current]
	active = false
	tubes[current].hide()
	for lamp in lamps:
		lamp.hide()
	spiders.clear()
	slide_sound.stop()
	hint.text = ""
	var landing: Transform3D = run.route_frame(outing.exit)
	var along: float = outing.start
	while along < outing.exit:
		run.travel_distance += 2.0
		run.trail.append({"distance": run.travel_distance, "position": run.route_frame(along).origin + Vector3.UP * 0.05})
		along += 2.0
	run.ghost_distance = run.travel_distance - maxf(EXIT_GAP_MIN, EXIT_GAP - hits * GAP_PER_HIT)
	p.global_position = run.ORIGIN + landing.origin + Vector3.UP * 1.1
	p.rotation = Vector3(0, landing.basis.get_euler().y, 0)
	p.camera.rotation = Vector3.ZERO
	p.camera.position = Vector3(0, 1.62, 0)
	p.get_node("Collision").shape.height = 1.75
	p.get_node("Collision").position.y = 0.9
	p.velocity = -landing.basis.z * run.RUN_SPEED
	run.previous_feet = p.position
	run.distance = outing.exit
	run.scares.flash.color = Color(0, 0, 0, 1)
	run.scares.impact(p.global_position, "topple")
