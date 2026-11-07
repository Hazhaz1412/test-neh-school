extends Node3D
# The floor gives way twice into a storm-drain slide under the school. The keys do nothing; the
# rider drifts towards wherever the camera leans. Rusted rebar and live cables torn out of the
# tunnel lining close all but one lane, right out to the wall, so hugging a side is never safe.
const RADIUS := 2.4
const RING_STEP := 3.0
const RING_SIDES := 28
const SPEED := 14.5
const SPEED_GAIN := 5.0
const SPEED_HURT := 7.0
const HURT_SECONDS := 0.8
const HIT_DAMAGE := 10.0
const DRIFT := 8.0
const ARC_LIMIT := 2.7
const LEAN_LIMIT := 1.05
const LEAN_DECAY := 0.25
const PITCH_LIMIT := 0.6
const LANES := [-1.7, 0.0, 1.7]
const LANE_HALF := 0.85
const HAND_SEEN := 40.0
const HAND_RISEN := 22.0
const RODS_PER_LANE := 6
const ROD_LENGTH := 1.75
# A gate that changes its mind: what it closes swaps this far ahead of the rider.
const SWITCH_LEAD := 11.0
const BEHIND := 9.0
const EXIT_GAP := 12.0
const GAP_PER_HIT := 3.0
const EXIT_GAP_MIN := 4.0
const HOLE_REACH := 2.0
# Gates are generated: one open lane each, closer together the further down, and every few
# a switch. The second slide is longer, faster and tighter. "spacing" runs from first to last.
const RUNS := [
	{"start": 384.0, "exit": 408.0, "length": 200.0, "origin": Vector3(0, -60, 0), "swarms": [[78.0, 4], [150.0, 5]],
		"first": 26.0, "spacing": [14.0, 10.0], "switch_every": 4, "seed": 3841},
	{"start": 636.0, "exit": 656.0, "length": 270.0, "origin": Vector3(0, -170, 0), "swarms": [[62.0, 5], [130.0, 6], [204.0, 7]],
		"first": 22.0, "spacing": [11.0, 8.5], "switch_every": 3, "seed": 6362},
]
static var rod_mesh: CylinderMesh
static var rust: StandardMaterial3D
static var copper: StandardMaterial3D
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
		for gate in plan_gates(index):
			gates[index].append(_build_gate(tube, index, gate))

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

# One open lane per gate. Next to each other gates move the gap at most one lane, so a quick
# lean always makes it; a switch gate first shows one gap, then slams it and opens the next.
static func plan_gates(index: int) -> Array[Dictionary]:
	var run_plan: Dictionary = RUNS[index]
	var dice := RandomNumberGenerator.new()
	dice.seed = run_plan.seed
	var plan: Array[Dictionary] = []
	var along: float = run_plan.first
	var open := 1
	var count := 0
	while along < run_plan.length - 14.0:
		var choices := [open - 1, open + 1] if count % 2 == 0 else [open - 1, open, open + 1]
		choices = choices.filter(func(lane): return lane >= 0 and lane <= 2)
		open = choices[dice.randi() % choices.size()]
		var gate := {"at": along, "closed": [0, 1, 2].filter(func(lane): return lane != open), "then": []}
		if count > 1 and count % int(run_plan.switch_every) == 0:
			var moved: int = open + (1 if open == 0 else (-1 if open == 2 else (1 if dice.randf() < 0.5 else -1)))
			gate.then = [0, 1, 2].filter(func(lane): return lane != moved)
			open = moved
		plan.append(gate)
		count += 1
		var progress: float = along / run_plan.length
		along += lerpf(run_plan.spacing[0], run_plan.spacing[1], progress)
	return plan

static func _materials() -> void:
	if rod_mesh != null: return
	rod_mesh = CylinderMesh.new()
	# Thicker than real rebar, so a cluster reads at sliding speed in the dark.
	rod_mesh.top_radius = 0.045
	rod_mesh.bottom_radius = 0.085
	rod_mesh.height = 1.0
	rod_mesh.radial_segments = 6
	rod_mesh.rings = 1
	rust = StandardMaterial3D.new()
	rust.albedo_texture = load("res://assets/polyhaven_horror/rubble_diff_1k.jpg")
	rust.albedo_color = Color(0.78, 0.42, 0.2)
	rust.metallic = 0.5
	rust.roughness = 0.6
	rust.emission_enabled = true
	rust.emission = Color(0.35, 0.12, 0.04)
	rust.emission_energy_multiplier = 0.8
	rust.uv1_scale = Vector3(0.2, 2.0, 0.2)
	copper = StandardMaterial3D.new()
	copper.albedo_color = Color(0.9, 0.45, 0.2)
	copper.metallic = 0.9
	copper.roughness = 0.3
	copper.emission_enabled = true
	copper.emission = Color(1.0, 0.6, 0.25)
	copper.emission_energy_multiplier = 0.6

# Rebar torn out of the lining, spread across the whole lane right up to the wall, pointing at the
# rider. Every gate also has a live cable sparking across one of its closed lanes.
func _build_gate(tube: Node3D, index: int, plan: Dictionary) -> Dictionary:
	_materials()
	var along: float = plan.at
	var place := frame(index, along)
	var sets := {}
	for key in ["closed", "then"]:
		var rods: Array[Dictionary] = []
		for lane in plan[key]:
			var from: float = -ARC_LIMIT - 0.3 if lane == 0 else LANES[lane] - LANE_HALF
			var to: float = ARC_LIMIT + 0.3 if lane == 2 else LANES[lane] + LANE_HALF
			for i in range(RODS_PER_LANE):
				var offset := lerpf(from, to, (i + 0.5) / RODS_PER_LANE)
				var root := surface_point(place, offset)
				var inward := (place.origin - root).normalized()
				var aim := (inward + place.basis.z * 0.55 + place.basis.x * sin(along + i * 2.1) * 0.25).normalized()
				var rod := MeshInstance3D.new()
				rod.mesh = rod_mesh
				rod.material_override = rust
				rod.hide()
				tube.add_child(rod)
				var axis := Vector3.UP.cross(aim)
				var turn := Basis.IDENTITY if axis.length() < 0.001 else Basis(axis.normalized(), Vector3.UP.angle_to(aim))
				rods.append({"node": rod, "root": root, "turn": turn, "length": ROD_LENGTH * (0.75 + 0.5 * absf(sin(along * 1.7 + i))), "phase": along + i})
		sets[key] = rods
	var lane: int = plan.closed[0]
	var spark := CPUParticles3D.new()
	spark.amount = 40
	spark.lifetime = 0.45
	spark.explosiveness = 0.3
	spark.direction = Vector3.DOWN
	spark.spread = 70
	spark.initial_velocity_min = 2.0
	spark.initial_velocity_max = 5.0
	spark.gravity = Vector3(0, -9.8, 0)
	var bead := SphereMesh.new()
	bead.radius = 0.012
	bead.height = 0.024
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.35)
	bead.material = hot
	spark.mesh = bead
	spark.emitting = false
	spark.position = surface_point(place, LANES[lane], 1.1)
	tube.add_child(spark)
	var cable := MeshInstance3D.new()
	var wire := CylinderMesh.new()
	wire.top_radius = 0.03
	wire.bottom_radius = 0.03
	wire.height = 1.0
	cable.mesh = wire
	cable.material_override = copper
	cable.hide()
	tube.add_child(cable)
	var wall_end := surface_point(place, LANES[lane] - LANE_HALF * 0.8, 0.0)
	var hang := surface_point(place, LANES[lane] + LANE_HALF * 0.4, 1.0)
	var span := hang - wall_end
	var cable_axis := Vector3.UP.cross(span.normalized())
	var cable_turn := Basis.IDENTITY if cable_axis.length() < 0.001 else Basis(cable_axis.normalized(), Vector3.UP.angle_to(span.normalized()))
	cable.transform = Transform3D(cable_turn.scaled(Vector3(1, span.length(), 1)), (wall_end + hang) * 0.5)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.55, 0.25)
	flash.omni_range = 7.0
	flash.light_energy = 0.0
	flash.position = hang
	tube.add_child(flash)
	return {"at": along, "closed": plan.closed, "then": plan.then, "switched": false, "sets": sets, "done": false, "spark": spark, "cable": cable, "flash": flash}

func _lane_of(at_arc: float) -> int:
	if at_arc < -LANE_HALF: return 0
	return 2 if at_arc > LANE_HALF else 1

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
			gate.switched = false
			gate.spark.emitting = false
			gate.cable.hide()
			gate.flash.light_energy = 0.0
			for key in gate.sets:
				for rod in gate.sets[key]: rod.node.hide()

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
	run.world.notify("Sàn sập! Nghiêng camera để lách qua khe hở, sát tường cũng không an toàn.")
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
		if not gate.then.is_empty() and not gate.switched and lead < SWITCH_LEAD:
			# The lining gives way right in front: the open gap slams shut and another opens.
			gate.switched = true
			run.scares.impact(run.to_global(frame(current, gate.at).origin), "topple")
			run.scares.shake = maxf(run.scares.shake, 0.35)
		var live: String = "then" if gate.switched else "closed"
		for key in gate.sets:
			var shown: bool = near and key == live
			var grow := rise if key == "closed" else clampf((SWITCH_LEAD - lead) / 3.0, 0.02, 1.0)
			for rod in gate.sets[key]:
				rod.node.visible = shown
				if shown:
					var quiver: float = sin(run.clock * 23.0 + rod.phase) * 0.02
					rod.node.transform = Transform3D(rod.turn * Basis(Vector3.RIGHT, quiver) * Basis.from_scale(Vector3(1.0, maxf(grow, 0.02) * rod.length, 1.0)), rod.root + rod.turn.y * maxf(grow, 0.02) * rod.length * 0.5)
		gate.cable.visible = near and not gate.switched
		gate.spark.emitting = near and not gate.switched and lead > -2.0
		# A dull glow off the live cable picks out every gate, and the arcing flares it white.
		var arc_flash := 1.0 if fmod(run.clock * 7.0 + gate.at, 1.0) < 0.18 else 0.0
		gate.flash.light_energy = (1.2 + arc_flash * 2.2) if near else 0.0
		gate.flash.light_color = Color(0.8, 0.9, 1.0) if arc_flash > 0.0 and gate.spark.emitting else Color(1.0, 0.55, 0.25)
		if not gate.done and before < gate.at and metres >= gate.at:
			gate.done = true
			var closed: Array = gate.then if gate.switched else gate.closed
			if _lane_of(arc) in closed:
				_grabbed()

func _grabbed() -> void:
	hits += 1
	hurt_left = HURT_SECONDS
	run.obstacle_hit()
	var p: CharacterBody3D = run.world.player
	p.invulnerable_time = 0.0
	p.take_damage(HIT_DAMAGE)
	run.scares._flash(Color(0.7, 0.02, 0.0, 0.45))
	run.scares.shake = maxf(run.scares.shake, 0.8)

func safe_arc(from: float) -> float:
	for gate in gates[current]:
		if gate.at > from:
			var closed: Array = gate.closed if gate.then.is_empty() or (gate.at - from > SWITCH_LEAD and not gate.switched) else gate.then
			for lane in range(LANES.size()):
				if lane not in closed:
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
