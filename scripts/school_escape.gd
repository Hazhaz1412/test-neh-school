extends Node3D

# The end of the guard's chase. The player has sneaked out of the building into the yard. Near
# the main gate the guard shouts down from a third-floor window and pins them in his torch beam:
# "stand still". The gate is chained, so the way on is the technical room in the gate booth, with
# the service stairs down to the tunnels. Against one clock, while he comes down the stairs and
# runs across the yard: take the screwdriver from the toolbox, back out the four screws of the
# door's lock plate (door_breaker.gd), then kick the door in. Run out of time and he has the
# player; that restarts this part only, with a few seconds more each time.
enum Segment { NONE, CALL, BREAK_IN }
const Guard := preload("res://scripts/security_guard.gd")
const F1 := 0.05
const F3 := 7.85
const GATE_STOP := Vector3(0, F1, 76.2)
# The guard booth inside the gate. Its back half is the head of the service stairs; the steel
# door on the yard side is the technical room's.
const BOOTH := Vector3(6.8, F1, 74.5)
const BOOTH_DOOR := Vector3(5.45, F1, 74.5)
const DOOR_STAND := Vector3(4.65, F1, 74.5)
const TOOLBOX := Vector3(5.05, F1, 72.75)
const RETRY_SPOT := Vector3(2.0, F1, 68.5)
# Where he leans out: the third-floor window of block A's hall, facing the yard.
const WINDOW_Z := 8.45
const WINDOW_HALF := 16.0
const CALL_SECONDS := 4.8
const TIME_LIMIT := 24.0
const TIME_PER_RETRY := 4.0
const TIME_BONUS_MAX := 8.0
# He keeps his torch on the player from the window until he needs STAIRS_SECONDS to get down,
# and comes out of the main entrance when YARD_SECONDS are left.
const STAIRS_SECONDS := 5.0
const YARD_SECONDS := 10.0
const YARD_ROUTE: Array[Vector3] = [Vector3(0, F1, 9.6), Vector3(5.7, F1, 16), Vector3(5.7, F1, 46), Vector3(2.6, F1, 62), DOOR_STAND + Vector3(-0.9, 0, -0.6)]
const HINT := "Cổng bị xích! · Lấy tua vít trong thùng đồ nghề cạnh phòng kỹ thuật rồi phá cửa"

class Prop extends Node3D:
	var escape: Node3D
	var kind := ""
	func interaction_text() -> String:
		if kind == "toolbox": return "E · Lấy tua vít"
		return "E · Tháo ổ khóa" if escape.has_tool else "E · Cửa khóa bằng ổ bắt vít · Cần tua vít"
	func interact(actor: CharacterBody3D) -> bool:
		if actor != escape.world.player or actor.get_interaction_target() != self: return false
		return escape.take_tool() if kind == "toolbox" else escape.use_door()

var story: Node3D
var world: Node3D
var guard: Node3D
var active := false
var segment := Segment.NONE
var step := ""
var attempts := 0
var clock := 0.0
var time_limit := TIME_LIMIT
var time_left := TIME_LIMIT
var fade_clock := 0.0
var restarted := false
var has_tool := false
var guard_phase := ""
var said_second := false
var report := {}
var music: AudioStreamPlayer
var breathing: AudioStreamPlayer
var kick_sound: AudioStreamPlayer
var tick_sound: AudioStreamPlayer
var shout: AudioStreamPlayer3D
var hint: Label
var timer_panel: Control
var timer_label: Label
var timer_bar: ProgressBar
var breaker: Control
var booth: Node3D
var booth_door: Node3D
var door_block: StaticBody3D
var lock_plate: Node3D
var plate_screws: Array[Node3D] = []
var toolbox: Prop
var screwdriver: Node3D
var door_prop: Prop
var beam: SpotLight3D
var beam_glare: MeshInstance3D
var beat_clock := 0.0

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	name = "SchoolEscape"
	music = AudioStreamPlayer.new()
	music.stream = story.loop_wav("res://assets/audio/corridor_chase.wav")
	add_child(music)
	breathing = AudioStreamPlayer.new()
	breathing.stream = story.loop_wav("res://assets/audio/player_breath.wav")
	add_child(breathing)
	kick_sound = AudioStreamPlayer.new()
	kick_sound.stream = load("res://assets/audio/door_bang.wav")
	add_child(kick_sound)
	tick_sound = AudioStreamPlayer.new()
	tick_sound.stream = load("res://assets/audio/lock.wav")
	add_child(tick_sound)
	shout = AudioStreamPlayer3D.new()
	shout.stream = load("res://assets/audio/guard_whistle.wav")
	shout.unit_size = 30
	shout.max_distance = 140
	add_child(shout)
	_build_booth()
	_build_beam()
	_build_ui()
	reset()

# A small concrete guard booth inside the gate.
func _build_booth() -> void:
	booth = Node3D.new()
	booth.name = "GuardBooth"
	booth.position = BOOTH
	add_child(booth)
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(.55,.54,.5)
	concrete.roughness = .95
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(.22,.27,.25)
	steel.metallic = .6
	steel.roughness = .5
	for spec in [[Vector3(0,1.3,-1.2),Vector3(2.6,2.6,.2)],[Vector3(0,1.3,1.2),Vector3(2.6,2.6,.2)],[Vector3(1.2,1.3,0),Vector3(.2,2.6,2.6)],
			[Vector3(-1.2,1.3,-.8),Vector3(.2,2.6,1.0)],[Vector3(-1.2,1.3,.8),Vector3(.2,2.6,1.0)],[Vector3(-1.2,2.35,0),Vector3(.2,.5,.6)],[Vector3(0,2.7,0),Vector3(2.9,.2,2.9)]]:
		var wall := StaticBody3D.new()
		wall.position = spec[0]
		booth.add_child(wall)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		mesh.mesh = box
		mesh.material_override = concrete
		wall.add_child(mesh)
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = spec[1]
		shape.shape = bounds
		wall.add_child(shape)
	booth_door = Node3D.new()
	booth_door.name = "TechnicalRoomDoor"
	booth_door.position = Vector3(-1.2,0,.3)
	booth.add_child(booth_door)
	var leaf := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(.06,2.1,.6)
	leaf.mesh = plate
	leaf.material_override = steel
	leaf.position = Vector3(0,1.05,-.3)
	booth_door.add_child(leaf)
	door_block = StaticBody3D.new()
	door_block.position = leaf.position
	booth_door.add_child(door_block)
	var block_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(.1,2.1,.62)
	block_shape.shape = slab
	door_block.add_child(block_shape)
	# The lock plate the player unscrews: on the yard face, beside the handle.
	lock_plate = Node3D.new()
	lock_plate.position = Vector3(-.04,1.05,-.48)
	booth_door.add_child(lock_plate)
	var brushed := StandardMaterial3D.new()
	brushed.albedo_color = Color(.55,.56,.55)
	brushed.metallic = .8
	brushed.roughness = .35
	_box(lock_plate, Vector3.ZERO, Vector3(.012,.2,.2), brushed)
	_box(lock_plate, Vector3(-.03,0,.04), Vector3(.05,.03,.1), brushed)
	for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
		var head := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = .011
		disc.bottom_radius = .011
		disc.height = .008
		head.mesh = disc
		head.material_override = brushed
		head.rotation.z = PI/2
		head.position = Vector3(-.008, corner.y*.075, corner.x*.075)
		lock_plate.add_child(head)
		plate_screws.append(head)
	door_prop = _prop("door", Vector3(-1.34,1.05,0), Vector3(.25,1.9,.75))
	booth.add_child(door_prop)
	var sign := Label3D.new()
	sign.text = "PHÒNG KỸ THUẬT\nCẤM VÀO"
	sign.font_size = 34
	sign.pixel_size = .0032
	sign.modulate = Color(.9,.75,.3)
	sign.position = Vector3(-1.32,2.35,0)
	sign.rotation.y = -PI/2
	booth.add_child(sign)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1,.25,.15)
	lamp.light_energy = .8
	lamp.omni_range = 3.5
	lamp.position = Vector3(-1.6,2.3,0)
	booth.add_child(lamp)
	# The toolbox against the booth wall, the screwdriver lying on top where the torch catches it.
	toolbox = _prop("toolbox", TOOLBOX - BOOTH + Vector3(0,.2,0), Vector3(.6,.5,.4))
	booth.add_child(toolbox)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(.62,.1,.07)
	red.roughness = .5
	red.metallic = .3
	_box(toolbox, Vector3(0,-.07,0), Vector3(.5,.26,.24), red)
	_box(toolbox, Vector3(0,.09,0), Vector3(.18,.03,.03), steel)
	screwdriver = Node3D.new()
	screwdriver.position = Vector3(.02,.085,.0)
	screwdriver.rotation.y = .5
	toolbox.add_child(screwdriver)
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(.95,.72,.1)
	grip.emission_enabled = true
	grip.emission = Color(.95,.6,.05)
	grip.emission_energy_multiplier = .6
	_box(screwdriver, Vector3(-.07,0,0), Vector3(.1,.03,.03), grip)
	var shaft := StandardMaterial3D.new()
	shaft.albedo_color = Color(.85,.86,.88)
	shaft.metallic = 1
	shaft.roughness = .2
	_box(screwdriver, Vector3(.05,0,0), Vector3(.14,.008,.008), shaft)
	var glint := OmniLight3D.new()
	glint.light_color = Color(1,.85,.55)
	glint.light_energy = .35
	glint.omni_range = 1.4
	glint.position = Vector3(0,.25,0)
	screwdriver.add_child(glint)

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func _prop(kind: String, at: Vector3, extent: Vector3) -> Prop:
	var item := Prop.new()
	item.escape = self
	item.kind = kind
	item.position = at
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 0
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collider.shape = shape
	area.add_child(collider)
	item.add_child(area)
	return item

# His torch from the window: a long narrow beam on the player, and a glare where it starts.
func _build_beam() -> void:
	beam = SpotLight3D.new()
	beam.light_color = Color(1.0, 0.93, 0.78)
	beam.light_energy = 2.6
	beam.spot_range = 120.0
	beam.spot_angle = 3.2
	beam.spot_attenuation = 0.0
	beam.shadow_enabled = false
	add_child(beam)
	# Seen from the yard the torch is a glaring point in the dark window.
	beam_glare = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	beam_glare.mesh = quad
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	glow.gradient = Gradient.new()
	glow.gradient.set_color(0, Color(1, 0.97, 0.88, 1))
	glow.gradient.set_color(1, Color(1, 0.85, 0.6, 0))
	glow.gradient.add_point(0.18, Color(1, 0.93, 0.78, 0.75))
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	haze.albedo_texture = glow
	beam_glare.material_override = haze
	beam_glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam_glare)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	add_child(layer)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -460
	hint.offset_right = 460
	hint.offset_top = -128
	hint.offset_bottom = -92
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",19)
	hint.add_theme_color_override("font_color",Color(.92,.84,.68))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	timer_panel = VBoxContainer.new()
	timer_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer_panel.offset_left = -220
	timer_panel.offset_right = 220
	timer_panel.offset_top = 18
	timer_panel.offset_bottom = 110
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(timer_panel)
	var caption := Label.new()
	caption.text = "BÁC BẢO VỆ ĐANG XUỐNG"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.95, 0.85, 0.7, 0.9))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("outline_size", 4)
	timer_panel.add_child(caption)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_override("font", preload("res://scripts/horror_type.gd").TITLE)
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_color_override("font_outline_color", Color(0.1, 0, 0))
	timer_label.add_theme_constant_override("outline_size", 9)
	timer_panel.add_child(timer_label)
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.max_value = 1.0
	timer_bar.custom_minimum_size = Vector2(440, 9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.55, 0.2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	timer_bar.add_theme_stylebox_override("fill", fill)
	timer_bar.add_theme_stylebox_override("background", back)
	timer_panel.add_child(timer_bar)
	breaker = preload("res://scripts/door_breaker.gd").new()
	layer.add_child(breaker)
	breaker.ticked.connect(func(_i):
		tick_sound.pitch_scale = randf_range(1.6, 1.9)
		tick_sound.volume_db = -20
		tick_sound.play())
	breaker.screw_out.connect(_on_screw_out)
	breaker.screws_done.connect(_on_screws_done)
	breaker.kicked.connect(_on_kick)
	breaker.burst_open.connect(_finish)

func reset() -> void:
	active = false
	segment = Segment.NONE
	step = ""
	attempts = 0
	report.clear()
	fade_clock = 0
	clock = 0
	time_limit = TIME_LIMIT
	time_left = TIME_LIMIT
	has_tool = false
	guard_phase = ""
	hint.hide()
	timer_panel.hide()
	breaker.close()
	_reset_props()
	_beam_off()
	for audio in [music,breathing]: audio.stop()

func _reset_props() -> void:
	booth_door.rotation.y = 0
	door_block.get_child(0).disabled = false
	lock_plate.show()
	for head in plate_screws: head.show()
	screwdriver.show()
	_set_live(false)

func _set_live(value: bool) -> void:
	for item in [toolbox, door_prop]:
		item.get_node("Interaction").collision_layer = 16 if value else 0

func _beam_off() -> void:
	beam.hide()
	beam_glare.hide()

func locks_player() -> bool:
	return active and (segment == Segment.CALL or step in ["screws", "kick", "open"] or fade_clock > 0)

# The player came out into the yard near the gate.
func start() -> void:
	var p: CharacterBody3D = world.player
	reset()
	active = true
	guard = story.guard_part.guard
	p.velocity = Vector3.ZERO
	story.fear.clear()
	music.volume_db = -20
	music.play()
	breathing.volume_db = -20
	breathing.play()
	_begin_call()

func _window_spot() -> Vector3:
	return Vector3(clampf(world.player.global_position.x, -WINDOW_HALF, WINDOW_HALF), F3, WINDOW_Z)

func _place_at_window() -> void:
	var at := _window_spot()
	guard.stop()
	guard.place(at, Vector3(world.player.global_position.x, F3, world.player.global_position.z))
	guard.run([Guard.wait(60.0, "idle")])
	guard_phase = "window"
	beam.show()
	beam_glare.show()

func _begin_call() -> void:
	segment = Segment.CALL
	step = ""
	clock = 0
	said_second = false
	_place_at_window()
	shout.global_position = guard.global_position + Vector3.UP * 1.6
	shout.play()
	story.subtitle("Bác bảo vệ", "Đứng yên đó!", 2.2)
	world.player.startle = 0.8

func _begin_break_in(retry: bool) -> void:
	segment = Segment.BREAK_IN
	step = "tool"
	clock = 0
	has_tool = false
	time_limit = TIME_LIMIT + minf(TIME_BONUS_MAX, TIME_PER_RETRY * attempts)
	time_left = time_limit
	breaker.close()
	_reset_props()
	_set_live(true)
	if retry:
		_place_at_window()
		story.subtitle("Bác bảo vệ", "Còn định chạy à?! Đứng yên đó!", 2.0)
	timer_panel.show()
	hint.text = HINT
	hint.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not report.has(attempts): report[attempts] = {"tool": -1.0, "screws": -1.0, "open": -1.0}

func take_tool() -> bool:
	if segment != Segment.BREAK_IN or step != "tool" or fade_clock > 0: return false
	has_tool = true
	screwdriver.hide()
	world.soundscape.cue("pickup", -12)
	report[attempts].tool = time_limit - time_left
	return use_door()

func use_door() -> bool:
	if segment != Segment.BREAK_IN or step != "tool" or fade_clock > 0: return false
	if not has_tool:
		world.notify("Ổ khóa bắt bốn con vít · Cần tua vít")
		return false
	step = "screws"
	_set_live(false)
	hint.hide()
	var p: CharacterBody3D = world.player
	p.velocity = Vector3.ZERO
	p.global_position = DOOR_STAND
	p.rotation.y = -PI / 2
	p.camera.rotation = Vector3(-0.05, 0, 0)
	breaker.begin()
	return true

func _on_screw_out(index: int) -> void:
	plate_screws[index].hide()
	tick_sound.pitch_scale = 1.0
	tick_sound.volume_db = -10
	tick_sound.play()

func _on_screws_done() -> void:
	step = "kick"
	lock_plate.hide()
	report[attempts].screws = time_limit - time_left
	world.soundscape.at("chair_impact", BOOTH_DOOR + Vector3(-.3, .2, 0), -10)

func _on_kick(power: float) -> void:
	kick_sound.pitch_scale = randf_range(0.85, 1.1)
	kick_sound.volume_db = -6
	kick_sound.play()
	booth_door.rotation.y = -0.03 - power * 0.12
	world.player.startle = maxf(world.player.startle, 0.35)
	world.player.camera.position.z = -0.12

func _finish() -> void:
	var p: CharacterBody3D = world.player
	report[attempts].open = time_limit - time_left
	active = false
	segment = Segment.NONE
	step = ""
	for audio in [music,breathing]: audio.stop()
	guard.stop()
	_beam_off()
	breaker.close()
	hint.hide()
	timer_panel.hide()
	_set_live(false)
	story.fear.clear()
	booth_door.rotation.y = -1.6
	door_block.get_child(0).disabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.soundscape.at("door_bang", BOOTH_DOOR + Vector3.UP, -2)
	p.camera.rotation = Vector3.ZERO
	p.camera.position = Vector3(0, 1.62, 0)
	story.subtitle("Bác bảo vệ", "Đứng lại!", 1.4)
	story.enter_basement()

func _caught() -> void:
	fade_clock = 0.9
	restarted = false
	step = "caught"
	breaker.close()
	_set_live(false)
	hint.hide()
	world.player.startle = 1
	world.hit_flash = 0.6
	guard.whistle_now()
	story.subtitle("Bác bảo vệ", "Bắt được rồi nhé!", 1.4)

# --- Clock and the guard coming ---

func _physics_process(delta: float) -> void:
	if not active or not world.simulation_active(): return
	breaker.tick(delta)
	clock += delta
	if fade_clock > 0:
		fade_clock = maxf(0, fade_clock - delta)
		story.fear.fade = clampf(1 - absf(fade_clock - .45) / .45, 0, 1)
		if fade_clock < .45 and not restarted:
			restarted = true
			attempts += 1
			var p: CharacterBody3D = world.player
			p.global_position = RETRY_SPOT
			p.rotation.y = atan2(-(BOOTH_DOOR.x - RETRY_SPOT.x), -(BOOTH_DOOR.z - RETRY_SPOT.z))
			p.camera.rotation = Vector3.ZERO
			p.camera.position = Vector3(0, 1.62, 0)
			_begin_break_in(true)
		if fade_clock <= 0: story.fear.fade = 0
		return
	match segment:
		Segment.CALL:
			if clock >= 2.3 and not said_second:
				said_second = true
				story.subtitle("Bác bảo vệ", "Đứng yên đó cho tao! Tao xuống ngay đây!", 2.4)
			if clock >= CALL_SECONDS: _begin_break_in(false)
		Segment.BREAK_IN:
			if step == "open": return
			time_left = maxf(0.0, time_left - delta)
			_tick_guard()
			timer_label.text = "%.1f" % time_left
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25) if time_left < 6.0 else Color(1.0, 0.86, 0.62))
			timer_bar.value = time_left / time_limit
			var calm := clampf(time_left / time_limit, 0, 1)
			breathing.volume_db = lerpf(-8, -20, calm)
			beat_clock -= delta
			if beat_clock <= 0:
				story.fear.beat(lerpf(-3, -16, calm))
				beat_clock = lerpf(.4, 1.1, calm)
			if time_left <= 0.0: _caught()
	if guard_phase == "window": _aim_beam()

func _tick_guard() -> void:
	if guard_phase == "window" and time_left <= YARD_SECONDS + STAIRS_SECONDS:
		# Gone from the window: on the stairs now.
		guard_phase = "stairs"
		guard.stop()
		_beam_off()
	elif guard_phase == "stairs" and time_left <= YARD_SECONDS:
		guard_phase = "yard"
		var route: Array = YARD_ROUTE.duplicate()
		guard.place(route[0], route[1])
		guard.run([Guard.sprint(route.slice(1), Guard.path_length(route.slice(1), route[0]) / maxf(0.5, time_left))])
		story.subtitle("Bác bảo vệ", "Đứng lại đó!", 1.6)

func _aim_beam() -> void:
	var p: CharacterBody3D = world.player
	var from: Vector3 = guard.global_position + Vector3(0.25, 1.45, 0.35)
	var target: Vector3 = p.global_position + Vector3.UP * 1.1
	beam.global_position = from
	if from.distance_squared_to(target) > 1.0: beam.look_at(target)
	beam_glare.global_position = from + (target - from).normalized() * 0.3
	guard.yaw_goal = atan2(-(target.x - guard.global_position.x), -(target.z - guard.global_position.z))

# --- Player pose while locked ---

func tick(delta: float) -> void:
	var p: CharacterBody3D = world.player
	p.velocity = Vector3.ZERO
	p.startle = maxf(0, p.startle - delta * 1.6)
	p.camera.position.x = sin(p.startle * 51) * p.startle * .03
	p.camera.position.z = move_toward(p.camera.position.z, 0.0, delta * 1.2)
	if segment == Segment.CALL:
		# Turned round by the shout, looking up at the torch in the window.
		var look: Vector3 = guard.global_position + Vector3.UP * 1.5 - p.camera.global_position
		var yaw := atan2(-look.x, -look.z)
		p.rotation.y = lerp_angle(p.rotation.y, yaw, clampf(delta * 3.0, 0, 1))
		var pitch := atan2(look.y, Vector2(look.x, look.z).length())
		p.camera.rotation.x = lerp_angle(p.camera.rotation.x, pitch, clampf(delta * 3.0, 0, 1))
	elif step in ["screws", "kick"]:
		p.global_position = DOOR_STAND
		p.rotation.y = lerp_angle(p.rotation.y, -PI / 2, clampf(delta * 8.0, 0, 1))
		p.camera.rotation.x = lerp_angle(p.camera.rotation.x, -0.12 if step == "screws" else -0.05, clampf(delta * 6.0, 0, 1))

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [music,breathing]: audio.stream_paused = paused
	# Back from the pause menu the mouse comes back captured; the screws need a free cursor.
	if active and step == "screws" and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN

func _exit_tree() -> void:
	for audio in [music,breathing]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
