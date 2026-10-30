extends Node3D

# Part 3 of Night 1: a four-part flight from the top floor to the main gate.
# Every segment feeds one value, the pursuer's gap in metres. Rubber-banding in
# _update_pursuer keeps it close whatever the player does, and being caught only
# restarts the current segment. attempts/report are the data for that tuning.
enum Segment { NONE, CORRIDOR, STAIRS, COURTYARD, GATE }
const F1 := 0.05
const F2 := 3.95
const F3 := 7.85
const CORRIDOR_RAIL: Array[Vector3] = [Vector3(-23.5,F3,47.5),Vector3(-23.5,F3,8.4),Vector3(-22.6,F3,7.5),Vector3(-1.2,F3,7.5)]
const ROOM_EXIT: Array[Vector3] = [Vector3(-25.4,F3,49),Vector3(-24.0,F3,48.7)]
const GHOST_START: Array[Vector3] = [Vector3(-23.5,F3,53.5),Vector3(-23.5,F3,47.5)]
const STAIR_RAIL: Array[Vector3] = [Vector3(-1.2,F3,7.5),Vector3(-.2,F3,6.5),Vector3(-.2,F3,-1.9),Vector3(-1.2,F3,-3),Vector3(-3.6,F3,-3),Vector3(-4.8,F3,-2),
	Vector3(-4.8,F2,6),Vector3(-4.8,F2,6.8),Vector3(-3.8,F2,7.5),Vector3(-1.2,F2,7.5),Vector3(-.2,F2,6.5),Vector3(-.2,F2,-1.9),Vector3(-1.2,F2,-3),Vector3(-3.6,F2,-3),Vector3(-4.8,F2,-2),
	Vector3(-4.8,F1,6),Vector3(-4.8,F1,6.8),Vector3(-3.8,F1,7.5),Vector3(-.8,F1,7.5),Vector3(0,F1,8.3),Vector3(0,F1,10)]
const LAMP_ROUTE: Array[Vector3] = [Vector3(5.7,0,16),Vector3(-5.7,0,46),Vector3(20,0,53),Vector3(5.7,0,62),Vector3(-5.7,0,75)]
const GATE_STOP := Vector3(0,F1,76.2)
const START_GAP := 6.5
const GATE_START_GAP := 8.0
const GAP_HIGH := 7.5
const GAP_LOW := 3.0
const CATCH_UP := 1.4
const EASE_OFF := 1.1
const CORRIDOR_SPEED := 5.6
const STRAFE_SPEED := 3.6
const HALF_WIDTH := 1.1
const PLAYER_RADIUS := 0.27
const SIDE_HALF := 0.75
const SIDE_CENTER := 0.6
const MIN_SPACING := 6.6
const MIN_REACTION := 0.9
const SLIDE_SECONDS := 0.75
const CLEAR_JUMP := 0.45
const HIT_PENALTY := 3.2
const LAUNCH_LEAD := 13.0
const LAUNCH_SECONDS := 0.45
const STAIR_SPEED := 4.4
const BEAT_START := 0.66
const BEAT_FASTEST := 0.52
const BEAT_WINDOW := 0.15
const GRACE_BEATS := 3
const MISS_PENALTY := 1.5
const COURTYARD_SPEED := 6.1
const LAMP_REACHED := 4.2
const OFF_COURSE_CLOSING := 2.2
const OFF_COURSE_PENALTY := 2.4
const BEAM_PUSH := 2.8
const BEAM_DRAIN := 14.0
const BEAM_DEGREES := 28.0
const GATE_DRAIN := 0.62
const SLIP_PENALTY := 1.2
const HINTS := {Segment.CORRIDOR:"A / D né  ·  SPACE nhảy  ·  CTRL cúi",Segment.STAIRS:"SPACE đúng nhịp tim",Segment.COURTYARD:"Chuột / A D: chạy về phía đèn còn sáng  ·  Giữ chuột phải: soi đèn pin ra sau",Segment.GATE:"Giữ chuột trái, vẽ lại ký hiệu trong cuốn vở"}
var story: Node3D
var world: Node3D
var active := false
var segment := Segment.NONE
var attempts := {}
var report := {}
var assist := 0
var clock := 0.0
var gap := START_GAP
var travel := 0.0
var trail: Array[Dictionary] = []
var last_feet := Vector3.ZERO
var checkpoint := {}
var fade_clock := 0.0
var restarted := false
var held_keys := {}
var looking_back := false
var look_yaw := 0.0
var rail: Array[Vector3] = []
var rail_lengths := PackedFloat32Array()
var rail_s := 0.0
var lead_length := 0.0
var speed := 0.0
var lateral := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
var slide_remaining := 0.0
var slide_cooldown := 0.0
var stumble := 0.0
var hazards: Array[Dictionary] = []
var pool := {}
var beat_clock := 0.0
var last_beat := 0.0
var next_beat := 0.0
var beat_interval := BEAT_START
var beats_heard := 0
var beat_answered := true
var next_answered := false
var breath := 100.0
var lamp_index := 0
var lamp_lights: Array[OmniLight3D] = []
var previous_target_distance := 0.0
var off_course := false
var beam_on_ghost := false
var approaching := false
var hint_time := 0.0
var ghost: Node3D
var music: AudioStreamPlayer
var breathing: AudioStreamPlayer
var steps: AudioStreamPlayer3D
var pop: AudioStreamPlayer3D
var trace: Control
var hint: Label
var seal: Node3D

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	name = "SchoolEscape"
	ghost = preload("res://scripts/chase_apparition.gd").new()
	add_child(ghost)
	music = AudioStreamPlayer.new()
	music.stream = story.loop_wav("res://assets/audio/corridor_chase.wav")
	add_child(music)
	breathing = AudioStreamPlayer.new()
	breathing.stream = story.loop_wav("res://assets/audio/player_breath.wav")
	add_child(breathing)
	steps = AudioStreamPlayer3D.new()
	steps.stream = story.loop_wav("res://assets/audio/ghost_step.wav")
	steps.unit_size = 10
	steps.max_distance = 40
	add_child(steps)
	pop = AudioStreamPlayer3D.new()
	pop.stream = load("res://assets/audio/lamp_pop.wav")
	pop.unit_size = 14
	pop.max_distance = 50
	add_child(pop)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color(1,.86,.6)
	for i in range(2):
		var light := OmniLight3D.new()
		light.light_color = Color(1,.8,.52)
		light.omni_range = 17
		light.light_energy = 3.4
		light.shadow_enabled = false
		add_child(light)
		lamp_lights.append(light)
		# The stock lantern frame hides its own glass, so the lit lamp needs this.
		var lantern := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(.42,.46,.42)
		lantern.mesh = box
		lantern.material_override = lit
		lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		light.add_child(lantern)
	_build_pool()
	_build_seal()
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	trace = preload("res://scripts/seal_trace.gd").new()
	trace.world = world
	layer.add_child(trace)
	trace.completed.connect(_finish)
	trace.slipped.connect(func(): gap -= SLIP_PENALTY)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -420
	hint.offset_right = 420
	hint.offset_top = -128
	hint.offset_bottom = -92
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",19)
	hint.add_theme_color_override("font_color",Color(.92,.84,.68))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	reset()

func _build_pool() -> void:
	var runner: Node3D = story.runner
	var plan := {"side":["desk",Vector3(1.5,.85,.8),4],"low":["bench",Vector3(2.9,.55,.6),3],"high":["bookcaseClosedWide",Vector3(2.9,1.7,.7),3]}
	for kind in plan:
		pool[kind] = []
		for i in range(plan[kind][2]):
			var holder := Node3D.new()
			add_child(holder)
			runner.prop(holder,plan[kind][0],Vector3.ZERO,plan[kind][1])
			holder.hide()
			pool[kind].append(holder)

func _build_seal() -> void:
	seal = Node3D.new()
	seal.name = "GateSeal"
	seal.position = Vector3(0,1.5,77.82)
	add_child(seal)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(.9,.12,.08)
	var stroke: Array[Vector2] = preload("res://scripts/seal_trace.gd").STROKE
	for i in range(stroke.size()-1):
		var from := Vector2(stroke[i].x,-stroke[i].y)*.62
		var to := Vector2(stroke[i+1].x,-stroke[i+1].y)*.62
		_bar(seal,(from+to)/2,Vector2(from.distance_to(to)+.03,.045),(to-from).angle(),glow)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(.1,.1,.11)
	iron.metallic = .7
	iron.roughness = .45
	for i in range(16):
		var along := -2.1+i*.28
		_bar(seal,Vector2(along,along*.42),Vector2(.24,.09),.4,iron)
		_bar(seal,Vector2(along,-along*.42),Vector2(.24,.09),-.4,iron)

func _bar(parent: Node3D, at: Vector2, dimensions: Vector2, angle: float, mat: Material) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(dimensions.x,dimensions.y,.03)
	part.mesh = box
	part.material_override = mat
	part.position = Vector3(at.x,at.y,0)
	part.rotation.z = angle
	parent.add_child(part)

func reset() -> void:
	active = false
	segment = Segment.NONE
	attempts.clear()
	report.clear()
	assist = 0
	fade_clock = 0
	held_keys.clear()
	looking_back = false
	trail.clear()
	travel = 0
	hint_time = 0
	hint.hide()
	trace.hide()
	seal.hide()
	ghost.vanish()
	_clear_hazards()
	_set_lamps_active(false)
	for audio in [music,breathing,steps,pop]: audio.stop()

func start() -> void:
	var p: CharacterBody3D = world.player
	reset()
	active = true
	seal.show()
	p.flashlight.show()
	p.velocity = Vector3.ZERO
	p.camera.rotation = Vector3(p.camera.rotation.x,0,0)
	p.camera.fov = 80
	music.play()
	breathing.play()
	steps.play()
	story.fear.clear()
	for at in GHOST_START: trail.append({"distance":travel,"position":at})
	travel = GHOST_START[0].distance_to(GHOST_START[1])
	trail[1].distance = travel
	last_feet = GHOST_START[1]
	ghost.appear(GHOST_START[0],p.global_position)
	begin_segment(Segment.CORRIDOR)

func begin_segment(next: int) -> void:
	var p: CharacterBody3D = world.player
	var retrying: bool = next == segment
	segment = next
	attempts[segment] = int(attempts.get(segment,0))+1 if retrying else int(attempts.get(segment,0))
	assist = mini(2,int(attempts[segment]))
	if not report.has(segment): report[segment] = {"mistakes":0,"lowest_gap":99.0,"seconds":0.0}
	if retrying:
		travel = checkpoint.travel
		trail.resize(checkpoint.trail_size)
		last_feet = checkpoint.feet
		p.battery = checkpoint.battery
	else:
		checkpoint = {"travel":travel,"trail_size":trail.size(),"feet":last_feet,"battery":p.battery}
	gap = GATE_START_GAP if segment == Segment.GATE else START_GAP
	clock = 0
	speed = 0
	lateral = 0
	jump_height = 0
	jump_velocity = 0
	slide_remaining = 0
	stumble = 0
	look_yaw = 0
	off_course = false
	beam_on_ghost = false
	approaching = false
	_clear_hazards()
	_set_lamps_active(false)
	story.fear.ring = -1
	story.fear.darkness = 0
	if segment != Segment.GATE: trace.hide()
	if int(attempts[segment]) == 0:
		hint.text = HINTS[segment]
		hint_time = 3.5
	match segment:
		Segment.CORRIDOR:
			# The very first run leaves the room; a retry resumes in the hall.
			var line: Array[Vector3] = []
			if not retrying:
				line.append(p.global_position)
				line.append_array(ROOM_EXIT)
			line.append_array(CORRIDOR_RAIL)
			_set_rail(line)
			lead_length = 0.0 if retrying else rail_lengths[3]
			hazards = generate_pattern(randi(),assist,lead_length+5.0,rail_lengths[-1]-3.0)
			_assign_props()
			music.volume_db = -13
		Segment.STAIRS:
			var line: Array[Vector3] = []
			line.assign(STAIR_RAIL)
			_set_rail(line)
			beat_clock = 0
			last_beat = -10
			next_beat = 0.5
			beat_interval = BEAT_START
			beats_heard = 0
			beat_answered = true
			next_answered = false
			breath = 100
			music.volume_db = -36
		Segment.COURTYARD:
			p.global_position = Vector3(0,F1,10)
			p.rotation = Vector3(0,PI,0)
			p.camera.rotation = Vector3.ZERO
			p.velocity = Vector3.ZERO
			lamp_index = 0
			_set_lamps_active(true)
			previous_target_distance = _target_distance()
			story.laugh.play()
			story.laughter_echo.play(2.0)
			music.volume_db = -13
		Segment.GATE:
			story.laugh.stop()
			story.laughter_echo.stop()
			music.volume_db = -22
			var line: Array[Vector3] = [p.global_position,GATE_STOP]
			_set_rail(line)
			beat_clock = 0
			approaching = true

func _set_rail(points: Array[Vector3]) -> void:
	rail = points
	lead_length = 0
	rail_lengths = PackedFloat32Array([0.0])
	for i in range(1,rail.size()): rail_lengths.append(rail_lengths[-1]+rail[i-1].distance_to(rail[i]))
	rail_s = 0

func _rail_position(s: float) -> Vector3:
	for i in range(1,rail.size()):
		if s <= rail_lengths[i]:
			return rail[i-1].lerp(rail[i],(s-rail_lengths[i-1])/maxf(.001,rail_lengths[i]-rail_lengths[i-1]))
	return rail[-1]

func _rail_direction(s: float) -> Vector3:
	var ahead: Vector3 = _rail_position(s+.5)-_rail_position(s-.5)
	ahead.y = 0
	return ahead.normalized() if ahead.length_squared()>.0001 else Vector3.FORWARD

# --- Corridor: a pattern of thrown furniture that is proven clearable ---

static func free_lateral(hazard: Dictionary) -> Vector2:
	if hazard.kind != "side": return Vector2(-HALF_WIDTH,HALF_WIDTH)
	if hazard.center > 0: return Vector2(-HALF_WIDTH,hazard.center-SIDE_HALF-PLAYER_RADIUS)
	return Vector2(hazard.center+SIDE_HALF+PLAYER_RADIUS,HALF_WIDTH)

static func pattern_clearable(pattern: Array[Dictionary], from_s: float) -> bool:
	var reach := Vector2.ZERO
	var at := from_s
	for hazard in pattern:
		var seconds: float = (hazard.s-at)/CORRIDOR_SPEED
		if seconds < MIN_REACTION: return false
		var free := free_lateral(hazard)
		reach = Vector2(maxf(reach.x-STRAFE_SPEED*seconds,free.x),minf(reach.y+STRAFE_SPEED*seconds,free.y))
		if reach.x > reach.y: return false
		at = hazard.s
	return true

func _near_corner(s: float) -> bool:
	for i in range(1,rail.size()-1):
		if absf(rail_lengths[i]-s) < 3.5: return true
	return false

func generate_pattern(seed_value: int, assist_level: int, from_s: float, to_s: float) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pattern: Array[Dictionary] = []
	var at := from_s
	while at < to_s:
		if not _near_corner(at):
			var options := ["side","side","low","high"]
			for i in range(options.size()-1,0,-1):
				var other := rng.randi_range(0,i)
				var held: String = options[i]
				options[i] = options[other]
				options[other] = held
			for kind in options:
				if pattern.size() >= 2 and pattern[-1].kind == kind and pattern[-2].kind == kind: continue
				var candidate := {"kind":kind,"s":at,"center":0.0}
				if kind == "side": candidate.center = SIDE_CENTER*(1 if rng.randf()<.5 else -1)
				var trial: Array[Dictionary] = pattern.duplicate()
				trial.append(candidate)
				if pattern_clearable(trial,from_s-MIN_SPACING):
					pattern.append(candidate)
					break
		at += MIN_SPACING*(1+.25*assist_level)+rng.randf_range(0,2.2)
	return pattern

func _assign_props() -> void:
	var used := {"side":0,"low":0,"high":0}
	for hazard in hazards:
		hazard.node = pool[hazard.kind][used[hazard.kind]%pool[hazard.kind].size()]
		used[hazard.kind] += 1
		hazard.launched = false
		hazard.resolved = false
		hazard.flight = 0.0
		hazard.rest = Vector3.ZERO
		hazard.from = Vector3.ZERO

func _clear_hazards() -> void:
	hazards.clear()
	for kind in pool:
		for holder in pool[kind]: holder.hide()

func _tick_hazards(delta: float) -> void:
	for hazard in hazards:
		var lead: float = hazard.s-rail_s
		if not hazard.launched and lead < LAUNCH_LEAD:
			hazard.launched = true
			var direction := _rail_direction(hazard.s)
			var right := direction.cross(Vector3.UP)
			hazard.rest = _rail_position(hazard.s)+right*float(hazard.center)+Vector3.UP*(1.02 if hazard.kind=="high" else 0.0)
			hazard.from = hazard.rest+direction*6+Vector3.UP*1.3+right*(-.7 if hazard.center>0 else .7)
			hazard.node.rotation.y = atan2(-direction.x,-direction.z)
			hazard.node.show()
		if hazard.launched and hazard.flight < 1:
			hazard.flight = minf(1,hazard.flight+delta/LAUNCH_SECONDS)
			var eased := smoothstep(0.0,1.0,float(hazard.flight))
			hazard.node.global_position = hazard.from.lerp(hazard.rest,eased)+Vector3.UP*sin(eased*PI)*.5
			hazard.node.rotation.x = (1-eased)*2.4
			if hazard.flight >= 1: world.soundscape.at("chair_impact",hazard.rest,-13)
		if not hazard.resolved and lead < .3:
			hazard.resolved = true
			var hit := false
			match hazard.kind:
				"side":
					var free := free_lateral(hazard)
					hit = lateral < free.x or lateral > free.y
				"low": hit = jump_height < CLEAR_JUMP
				"high": hit = slide_remaining <= 0
			if hit: _hazard_hit(hazard)
		elif hazard.resolved and lead < -5: hazard.node.hide()

func _hazard_hit(hazard: Dictionary) -> void:
	hazard.node.hide()
	stumble = .5
	world.soundscape.cue("chair_impact",-9)
	_mistake(HIT_PENALTY)

func _mistake(penalty: float) -> void:
	gap -= penalty*(1-.18*assist)
	report[segment].mistakes += 1
	world.player.startle = .8
	world.hit_flash = maxf(world.hit_flash,.3)

func _tick_corridor(delta: float) -> void:
	var p: CharacterBody3D = world.player
	speed = move_toward(speed,CORRIDOR_SPEED*(.35 if stumble>0 else 1.0),delta*14)
	rail_s += speed*delta
	slide_remaining = maxf(0,slide_remaining-delta)
	slide_cooldown = maxf(0,slide_cooldown-delta)
	lateral = clampf(lateral+(float(held(KEY_D))-float(held(KEY_A)))*STRAFE_SPEED*delta,-HALF_WIDTH,HALF_WIDTH)
	if jump_height > 0 or jump_velocity > 0:
		jump_velocity -= 22*delta
		jump_height += jump_velocity*delta
		if jump_height <= 0:
			jump_height = 0
			jump_velocity = 0
	_tick_hazards(delta)
	_place_on_rail(delta,lateral)
	p.camera.position.y = .62 if slide_remaining>0 else 1.62+sin(clock*16)*.03
	if rail_s >= rail_lengths[-1]: begin_segment(Segment.STAIRS)

func _place_on_rail(delta: float, offset: float) -> void:
	var p: CharacterBody3D = world.player
	var feet := _rail_position(rail_s)
	var direction := _rail_direction(rail_s)
	# Inside the room the player is on their way out; the pursuer stays in the hall.
	var in_room := rail_s < lead_length
	p.global_position = feet+direction.cross(Vector3.UP)*(0.0 if in_room else offset)+Vector3.UP*jump_height
	p.velocity = Vector3.ZERO
	p.rotation.y = lerp_angle(p.rotation.y,atan2(-direction.x,-direction.z)+look_yaw,clampf(delta*9,0,1))
	if not in_room: _record_trail(feet)

func jump() -> bool:
	if segment != Segment.CORRIDOR or jump_height > 0 or jump_velocity > 0 or slide_remaining > 0: return false
	jump_velocity = 6.4
	jump_height = .001
	return true

func duck() -> bool:
	if segment != Segment.CORRIDOR or slide_remaining > 0 or slide_cooldown > 0 or jump_height > 0: return false
	slide_remaining = SLIDE_SECONDS
	slide_cooldown = SLIDE_SECONDS+.1
	world.soundscape.cue("paper",-18)
	return true

# --- Stairs: the jumpscare's heartbeat becomes the input ---

func press_beat() -> void:
	var window := BEAT_WINDOW+.05*assist
	if not beat_answered and beat_clock-last_beat <= window:
		beat_answered = true
		breath = minf(100,breath+7)
	elif next_beat-beat_clock <= window and not next_answered:
		next_answered = true
		breath = minf(100,breath+7)
	else: _lose_footing()

func _lose_footing() -> void:
	if beats_heard <= GRACE_BEATS: return
	breath = maxf(0,breath-16)
	stumble = .45
	world.soundscape.cue("chair_impact",-20)
	_mistake(MISS_PENALTY)

func _tick_stairs(delta: float) -> void:
	var p: CharacterBody3D = world.player
	beat_clock += delta
	if beat_clock >= next_beat:
		story.fear.beat(-1)
		beats_heard += 1
		last_beat = next_beat
		beat_answered = next_answered
		next_answered = false
		next_beat += beat_interval
		beat_interval = maxf(BEAT_FASTEST,beat_interval-.006)
	if not beat_answered and beat_clock-last_beat > BEAT_WINDOW+.05*assist:
		beat_answered = true
		_lose_footing()
	story.fear.ring = clampf((next_beat-beat_clock)/beat_interval,0,1)
	speed = move_toward(speed,STAIR_SPEED*(.3 if stumble>0 else 1.0),delta*12)
	rail_s += speed*delta
	# The further down, and the worse the breathing, the darker it gets.
	var descent: float = rail_s/rail_lengths[-1]
	story.fear.darkness = clampf(.25+descent*.25+(1-breath/100)*.45,0,.92)
	_place_on_rail(delta,0)
	p.camera.position.y = 1.62+sin(clock*12)*.04-stumble*.5
	if rail_s >= rail_lengths[-1]: begin_segment(Segment.COURTYARD)

# --- Courtyard: the lamps left lit are the way out ---

func current_lamp() -> Vector3:
	return LAMP_ROUTE[mini(lamp_index,LAMP_ROUTE.size()-1)]

func _target_distance() -> float:
	var at: Vector3 = world.player.global_position
	return Vector2(at.x-current_lamp().x,at.z-current_lamp().z).length()

func _lamp_head(at: Vector3) -> Vector3:
	return at+Vector3.UP*3.1 if absf(at.x) < 10 else at+Vector3.UP

func _set_lamps_active(on: bool) -> void:
	for i in range(lamp_lights.size()):
		var index := lamp_index+i
		lamp_lights[i].visible = on and index < LAMP_ROUTE.size()
		if not lamp_lights[i].visible: continue
		lamp_lights[i].position = _lamp_head(LAMP_ROUTE[index])
		lamp_lights[i].light_energy = 3.4 if i==0 else 2.2

func _tick_courtyard(delta: float) -> void:
	var p: CharacterBody3D = world.player
	p.rotation.y -= (float(held(KEY_D))-float(held(KEY_A)))*1.9*delta
	var forward: Vector3 = -p.global_basis.z
	speed = move_toward(speed,COURTYARD_SPEED,delta*14)
	p.velocity = Vector3(forward.x*speed,-1,forward.z*speed)
	p.move_and_slide()
	p.camera.position.y = 1.62+sin(clock*17)*.035
	_record_trail(Vector3(p.global_position.x,F1,p.global_position.z))
	var distance := _target_distance()
	var closing := (previous_target_distance-distance)/maxf(delta,.001)
	previous_target_distance = distance
	off_course = closing < OFF_COURSE_CLOSING
	if off_course: gap -= OFF_COURSE_PENALTY*(1-.18*assist)*delta
	story.fear.darkness = move_toward(story.fear.darkness,.6 if off_course else .22,delta*1.6)
	_tick_beam(delta)
	if distance < LAMP_REACHED:
		pop.global_position = _lamp_head(current_lamp())
		pop.play()
		lamp_index += 1
		if lamp_index >= LAMP_ROUTE.size():
			begin_segment(Segment.GATE)
			return
		_set_lamps_active(true)
		previous_target_distance = _target_distance()

func _tick_beam(delta: float) -> void:
	var p: CharacterBody3D = world.player
	beam_on_ghost = false
	if not looking_back or p.battery <= 0: return
	var to: Vector3 = ghost.global_position+Vector3.UP*1.2-p.camera.global_position
	if rad_to_deg((-p.camera.global_basis.z).angle_to(to)) > BEAM_DEGREES or to.length() > 16: return
	beam_on_ghost = true
	gap = minf(GAP_HIGH+3,gap+BEAM_PUSH*delta)
	p.battery = maxf(0,p.battery-BEAM_DRAIN*delta)
	if p.battery <= 0: p.flashlight.hide()

# --- Gate: redraw the notebook's symbol before the ghost arrives ---

func _tick_gate(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if approaching:
		speed = move_toward(speed,COURTYARD_SPEED,delta*14)
		rail_s += speed*delta
		_place_on_rail(delta,0)
		var bearing: float = p.rotation.y
		p.rotation.y = lerp_angle(bearing,PI,clampf(delta*7,0,1))
		if rail_s >= rail_lengths[-1]:
			approaching = false
			p.rotation.y = PI
			p.camera.rotation = Vector3(.05,0,0)
			looking_back = false
			trace.begin(assist)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gap -= GATE_DRAIN*(1-.18*assist)*delta
	story.fear.darkness = clampf(.72-gap/GATE_START_GAP*.6,.1,.8)
	beat_clock -= delta
	if beat_clock <= 0:
		var calm := clampf(gap/GATE_START_GAP,0,1)
		story.fear.beat(lerpf(-2,-14,calm))
		beat_clock = lerpf(.42,1.1,calm)

func _finish() -> void:
	var p: CharacterBody3D = world.player
	active = false
	segment = Segment.NONE
	for audio in [music,breathing,steps]: audio.stop()
	ghost.vanish()
	hint.hide()
	seal.hide()
	story.fear.clear()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.soundscape.cue("lock",-6)
	world.soundscape.at("chair_impact",seal.global_position,-8)
	p.camera.rotation = Vector3.ZERO
	story.runner.restore_pose()
	p.rotation.y = PI
	story.seal_broken()

# --- Shared pursuer ---

func _record_trail(feet: Vector3) -> void:
	travel += feet.distance_to(last_feet)
	last_feet = feet
	if trail.is_empty() or feet.distance_to(trail[-1].position) >= .3:
		trail.append({"distance":travel,"position":feet})

func trail_position(meters: float) -> Vector3:
	if trail.is_empty(): return last_feet
	if meters <= float(trail[0].distance): return trail[0].position
	var low := 0
	var high := trail.size()-1
	while low+1 < high:
		var middle := (low+high)/2
		if float(trail[middle].distance) <= meters: low = middle
		else: high = middle
	var weight := clampf((meters-float(trail[low].distance))/maxf(.001,float(trail[high].distance)-float(trail[low].distance)),0,1)
	return (trail[low].position as Vector3).lerp(trail[high].position,weight)

func _update_pursuer(delta: float) -> void:
	var p: CharacterBody3D = world.player
	# Rubber-banding: a clean run never shakes the ghost off, and a bad run is
	# not punished at once. Only mistakes in quick succession close the gap.
	if segment != Segment.GATE and not beam_on_ghost:
		if gap > GAP_HIGH: gap -= CATCH_UP*delta
		elif gap < GAP_LOW: gap += EASE_OFF*delta
	report[segment].lowest_gap = minf(report[segment].lowest_gap,gap)
	report[segment].seconds += delta
	if gap <= 0:
		_caught()
		return
	var at := trail_position(travel-gap)
	ghost.global_position = at
	var flat := Vector3(p.global_position.x,at.y,p.global_position.z)
	if at.distance_squared_to(flat) > .01: ghost.look_at(flat)
	var danger := clampf(1-gap/10,0,1)
	ghost.animate(delta,danger)
	steps.global_position = at+Vector3.UP
	steps.volume_db = lerpf(-14,-3,danger)
	steps.pitch_scale = 1.2+danger*.5
	breathing.volume_db = lerpf(-22,-10,danger)

func _caught() -> void:
	fade_clock = .8
	restarted = false
	world.player.startle = 1
	world.hit_flash = .7
	story.fear.ring = -1
	trace.hide()
	world.soundscape.cue("hurt",-8)
	if ghost.visible: ghost.global_position = trail_position(travel-.4)

func _tick_fade(delta: float) -> void:
	fade_clock = maxf(0,fade_clock-delta)
	story.fear.fade = clampf(1-absf(fade_clock-.4)/.4,0,1)
	if fade_clock < .4 and not restarted:
		restarted = true
		_restart_position()
		begin_segment(segment)
	if fade_clock <= 0: story.fear.fade = 0

func _restart_position() -> void:
	var p: CharacterBody3D = world.player
	match segment:
		Segment.CORRIDOR: p.global_position = CORRIDOR_RAIL[0]
		Segment.STAIRS: p.global_position = STAIR_RAIL[0]
		Segment.GATE: p.global_position = GATE_STOP
	p.camera.position = Vector3(0,1.62,0)

func tick(delta: float) -> void:
	if not active or not world.simulation_active(): return
	var p: CharacterBody3D = world.player
	p.startle = maxf(0,p.startle-delta*1.6)
	p.camera.position.x = sin(p.startle*51)*p.startle*.02
	stumble = maxf(0,stumble-delta)
	hint_time = maxf(0,hint_time-delta)
	hint.visible = hint_time > 0
	if fade_clock > 0:
		_tick_fade(delta)
		return
	clock += delta
	match segment:
		Segment.CORRIDOR: _tick_corridor(delta)
		Segment.STAIRS: _tick_stairs(delta)
		Segment.COURTYARD: _tick_courtyard(delta)
		Segment.GATE: _tick_gate(delta)
	if active: _update_pursuer(delta)

func held(code: int) -> bool:
	return held_keys.get(code,Input.is_physical_key_pressed(code))

func look(relative: Vector2) -> void:
	var p: CharacterBody3D = world.player
	if segment == Segment.COURTYARD: p.rotation.y -= relative.x*p.LOOK_SENSITIVITY
	else: look_yaw = clampf(look_yaw-relative.x*p.LOOK_SENSITIVITY,-1.2,1.2)
	p.camera.rotation.x = clampf(p.camera.rotation.x-relative.y*p.LOOK_SENSITIVITY,-1.1,1.1)

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and not event.pressed:
		var released: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		held_keys[released] = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		looking_back = false
		world.player.camera.rotation.y = 0
	if not world.simulation_active() or fade_clock > 0: return
	if trace.visible: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code in [KEY_A,KEY_D,KEY_SPACE,KEY_CTRL]:
			held_keys[code] = event.pressed
			if event.pressed and not event.echo:
				if code == KEY_SPACE:
					if segment == Segment.STAIRS: press_beat()
					else: jump()
				if code == KEY_CTRL: duck()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		looking_back = true
		world.player.camera.rotation.y = PI
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [music,breathing,steps,pop]: audio.stream_paused = paused
	if paused and ghost.visible: ghost.model.animation.speed_scale = 0

func _exit_tree() -> void:
	for audio in [music,breathing,steps,pop]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
