extends Node3D

# The guard's part of the prologue, after the hand mirror:
#  1. HIDE    He calls out from the ground floor, climbs to floor 2 and checks the rooms one by
#             one. The player shuts themselves in a restroom stall.
#  2. STEALTH Just before the restroom, something falls on floor 3. He goes up to 306 and the
#             player tails him: every footstep makes noise, his torch is his eyes, and he stops
#             to look back at set points along the long corridors.
#  3. PHOTO   In 306 he clears papers and a photograph off the teacher's desk, back to the door.
#             A photo of it is the third clue; the flash gives the player away and starts the escape.
# Being caught fades out and restarts the current part from its checkpoint.
const Guard := preload("res://scripts/security_guard.gd")
const F1 := 0.05
const F2 := 3.95
const F3 := 7.85
# He is already coming up the stairs when the player takes the mirror: top of the flight on floor 2.
const CALL_SPOT := Vector3(-4.8, F2, -2.0)
const RUSH_PATH: Array[Vector3] = [Vector3(-3.6, F2, -3.0), Vector3(-1.2, F2, -3.0), Vector3(-0.2, F2, -1.9), Vector3(-0.2, F2, 6.5), Vector3(1.0, F2, 7.5), Vector3(14.5, F2, 7.5)]
const RESTROOM_DOOR := Vector3(14.5, F2, 7.5)
const NEAR_RESTROOM := Vector3(18.5, F2, 7.5)
const DESK := Vector3(-31.5, F3, 33.6)
const DESK_STAND := Vector3(-31.5, F3, 34.75)
const EVIDENCE := Vector3(-31.5, F3 + 0.84, 33.55)
const RESTROOM_ENTRY := Vector3(14.5, F2, 4.2)
# The breath-holding beat inside the stall.
const BREATH_NEAR := 3.2
const BREATH_DRAIN := 12.0
const BREATH_RECOVER := 30.0
const BREATH_NOISE := 3.5
const GASP_NOISE := 9.0
const PHOTO_RANGE := 13.0
const PHOTO_ANGLE := 24.0
const UP_F1_F2: Array[Vector3] = [Vector3(-3.8, F1, 7.5), Vector3(-4.8, F1, 6.8), Vector3(-4.8, F1, 6.0), Vector3(-4.8, F2, -2.0), Vector3(-3.6, F2, -3.0),
	Vector3(-1.2, F2, -3.0), Vector3(-0.2, F2, -1.9), Vector3(-0.2, F2, 6.5), Vector3(-1.2, F2, 7.5)]
const UP_F2_F3: Array[Vector3] = [Vector3(-3.8, F2, 7.5), Vector3(-4.8, F2, 6.8), Vector3(-4.8, F2, 6.0), Vector3(-4.8, F3, -2.0), Vector3(-3.6, F3, -3.0),
	Vector3(-1.2, F3, -3.0), Vector3(-0.2, F3, -1.9), Vector3(-0.2, F3, 6.5), Vector3(-1.2, F3, 7.5)]
enum Part { NONE, HIDE, STEALTH, PHOTO, DONE }
var world: Node3D
var story: Node3D
var guard: Node3D
var part := Part.NONE
var checkpoint := Part.HIDE
var fail_clock := -1.0
var thud: AudioStreamPlayer
var evidence: Node3D
var hud: Control
var noise_bar: ProgressBar
var alert_bar: ProgressBar
var alert_label: Label
var hint: Label
var hint_clock := 0.0
var photo_framed := false
var breath := 100.0
var breath_close := false
var breath_clock := 0.0
var beat_clock := 0.0
var test_hold := false
var breath_panel: Control
var breath_bar: ProgressBar
var breath_label: Label
var gasp: AudioStreamPlayer

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "GuardPrologue"
	guard = Guard.new()
	add_child(guard)
	guard.setup(world, story)
	guard.concealed = func() -> bool: return story.restroom.player_in_closed_stall()
	guard.caught.connect(_on_caught)
	guard.task_done.connect(_on_mark)
	thud = AudioStreamPlayer.new()
	thud.stream = load("res://assets/audio/floor_thud.wav")
	thud.volume_db = -9
	add_child(thud)
	gasp = AudioStreamPlayer.new()
	gasp.stream = load("res://assets/audio/player_breath.wav")
	gasp.volume_db = -6
	add_child(gasp)
	_build_evidence()
	_build_hud()
	reset()

func _build_evidence() -> void:
	evidence = Node3D.new()
	evidence.name = "DeskEvidence"
	evidence.position = EVIDENCE
	add_child(evidence)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.86, 0.84, 0.76)
	paper.roughness = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 306
	for i in range(7):
		var sheet := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.21, 0.002, 0.297)
		sheet.mesh = box
		sheet.material_override = paper
		sheet.position = Vector3(rng.randf_range(-0.35, 0.35), i * 0.003, rng.randf_range(-0.12, 0.12))
		sheet.rotation.y = rng.randf_range(-0.6, 0.6)
		evidence.add_child(sheet)
	# A printed class photo, faded, among the papers.
	var photo := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(0.15, 0.002, 0.1)
	photo.mesh = quad
	var print_mat := StandardMaterial3D.new()
	print_mat.albedo_texture = load("res://docs/annex-classroom-preview.png")
	print_mat.albedo_color = Color(0.95, 0.85, 0.7)
	photo.material_override = print_mat
	photo.position = Vector3(0.12, 0.025, 0.04)
	photo.rotation.y = 0.3
	evidence.add_child(photo)
	var folder := MeshInstance3D.new()
	var cover := BoxMesh.new()
	cover.size = Vector3(0.24, 0.02, 0.32)
	folder.mesh = cover
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.15, 0.25, 0.45)
	folder.material_override = blue
	folder.position = Vector3(-0.42, 0.0, 0.05)
	evidence.add_child(folder)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	hud = VBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 28
	hud.offset_top = -170
	hud.offset_right = 248
	hud.offset_bottom = -96
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	alert_label = _caption("ĐANG LẨN TRÁNH")
	hud.add_child(alert_label)
	alert_bar = _bar(Color(0.95, 0.55, 0.2))
	hud.add_child(alert_bar)
	hud.add_child(_caption("TIẾNG ĐỘNG"))
	noise_bar = _bar(Color(0.7, 0.8, 0.85))
	hud.add_child(noise_bar)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -460
	hint.offset_right = 460
	hint.offset_top = 70
	hint.offset_bottom = 110
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	breath_panel = VBoxContainer.new()
	breath_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	breath_panel.offset_left = -200
	breath_panel.offset_right = 200
	breath_panel.offset_top = -250
	breath_panel.offset_bottom = -196
	breath_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(breath_panel)
	breath_label = Label.new()
	breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breath_label.add_theme_font_size_override("font_size", 17)
	breath_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	breath_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	breath_label.add_theme_constant_override("outline_size", 5)
	breath_panel.add_child(breath_label)
	breath_bar = _bar(Color(0.55, 0.78, 0.95))
	breath_bar.custom_minimum_size = Vector2(400, 9)
	breath_panel.add_child(breath_bar)

func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.85))
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 7)
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.45)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar

func reset() -> void:
	part = Part.NONE
	checkpoint = Part.HIDE
	fail_clock = -1.0
	photo_framed = false
	guard.stop()
	thud.stop()
	evidence.show()
	hud.hide()
	hint.hide()
	_reset_breath()
	for number in [102, 201, 202, 204, 306]:
		var leaf: Node3D = world.get_node_or_null("Architecture/ClassroomDoor%d" % number)
		if leaf != null: leaf.set_open(false)

func active() -> bool:
	return part in [Part.HIDE, Part.STEALTH, Part.PHOTO]

func show_hint(text: String, seconds := 6.0) -> void:
	hint.text = text
	hint.show()
	hint_clock = seconds

# --- Routes ---

static func check_room(x: float, floor_y: float, number: int) -> Array[Dictionary]:
	var outside := Vector3(x, floor_y, 7.5)
	return [Guard.walk([outside]), Guard.face(Vector3(x, floor_y, 6.0)), Guard.door(number, true), Guard.wait(0.6),
		Guard.walk([Vector3(x, floor_y, 4.6)]), Guard.wait(2.0, "look_around", true), Guard.walk([outside]), Guard.door(number, false)]

# About five seconds from the shout to the restroom door: he heard the crash and runs
# straight for it, then starts on the stalls.
func _rush_restroom() -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	jobs.append(Guard.say("Ai đó?! Đứa nào trên đó?!", 2.4))
	jobs.append(Guard.sprint(RUSH_PATH))
	jobs.append(Guard.face(Vector3(14.5, F2, 6.0)))
	jobs.append(Guard.door(203, true))
	jobs.append(Guard.sprint([RESTROOM_ENTRY], 4.5))
	jobs.append(Guard.say("Đứa nào vừa đập vỡ gương?!", 2.2))
	jobs.append(Guard.wait(0.9, "look_around", true))
	jobs.append(Guard.mark("restroom"))
	return jobs

# Stall by stall, starting furthest from wherever the player is and ending at their door.
func _stall_sweep() -> Array[Dictionary]:
	var restroom: Node3D = story.restroom
	var target: int = restroom.player_stall()
	var order: Array = range(restroom.STALL_COUNT)
	order.erase(target)
	var anchor: int = target if target >= 0 else restroom.STALL_COUNT - 1
	order.sort_custom(func(a, b): return absi(a - anchor) > absi(b - anchor))
	var jobs: Array[Dictionary] = []
	for i in order:
		jobs.append(Guard.walk([restroom.stall_front(i)]))
		jobs.append(Guard.face(restroom.stall_center(i)))
		jobs.append(Guard.act(restroom.guard_open_stall.bind(i)))
		jobs.append(Guard.wait(1.1, "look_around", true))
	if target >= 0:
		jobs.append(Guard.walk([restroom.stall_front(target)]))
		jobs.append(Guard.face(restroom.stall_center(target)))
		jobs.append(Guard.say("Cửa này... sao lại đóng?", 1.8))
		jobs.append(Guard.wait(1.0, "listen"))
		jobs.append(Guard.act(_rattle.bind(target)))
		jobs.append(Guard.say("Có ai trong đó không?", 2.0))
		jobs.append(Guard.wait(2.4, "listen"))
	jobs.append(Guard.mark("near_restroom"))
	return jobs

func _rattle(index: int) -> void:
	var door: Node3D = story.restroom.stall_doors[index]
	world.soundscape.at("door", door.global_position + Vector3(0, 1, 0.7), -4)
	world.soundscape.at("lock", door.global_position + Vector3(0, 1, 0.7), -6)
	story.fear.beat(-2.0)

func _route_to_306(start: Vector3) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	jobs.append(Guard.wait(1.4, "listen"))
	jobs.append(Guard.say("Tiếng gì trên tầng ba thế nhỉ...?", 2.6))
	jobs.append(Guard.mark("leaving"))
	if start.z < 6.0:
		# Out of the restroom first.
		jobs.append(Guard.walk([RESTROOM_ENTRY, Vector3(14.5, F2, 7.5), Vector3(-1.2, F2, 7.5)]))
	else:
		jobs.append(Guard.walk([start + Vector3(-2.0, 0, 0), Vector3(-1.2, F2, 7.5)]))
	jobs.append(Guard.walk(UP_F2_F3))
	jobs.append(Guard.mark("floor3"))
	# The long north corridor: one look back once he is clear of the stairs.
	jobs.append(Guard.walk([Vector3(-11.0, F3, 7.5)]))
	jobs.append_array(Guard.look_back(Vector3(-20, F3, 7.5), Vector3(0, F3, 7.5)))
	jobs.append(Guard.walk([Vector3(-22.6, F3, 7.5), Vector3(-23.5, F3, 8.6), Vector3(-23.5, F3, 26.0)]))
	jobs.append_array(Guard.look_back(Vector3(-23.5, F3, 40), Vector3(-23.5, F3, 10)))
	jobs.append(Guard.walk([Vector3(-23.5, F3, 44.0)]))
	jobs.append_array(Guard.look_back(Vector3(-23.5, F3, 50), Vector3(-23.5, F3, 30), 1.8))
	jobs.append(Guard.walk([Vector3(-23.5, F3, 49.0)]))
	jobs.append(Guard.face(Vector3(-25, F3, 49)))
	jobs.append(Guard.door(306, true))
	jobs.append(Guard.walk([Vector3(-26.6, F3, 49.0), Vector3(-31.5, F3, 47.4), DESK_STAND]))
	jobs.append(Guard.face(DESK))
	jobs.append(Guard.mark("working"))
	jobs.append(Guard.say("Lại là mấy thứ này...", 2.4))
	jobs.append(Guard.work())
	return jobs

# --- Parts ---

func begin() -> void:
	_start_hide()

func _start_hide() -> void:
	part = Part.HIDE
	checkpoint = Part.HIDE
	guard.place(CALL_SPOT, Vector3(-3.6, F2, -3.0))
	guard.sensing = true
	guard.awareness = 0.0
	guard.run(_rush_restroom())
	hud.hide()
	show_hint("Có người chạy lên! · Chui ngay vào một buồng có bồn cầu, đóng cửa (E)", 5.0)

func _start_follow(replay_thud: bool) -> void:
	part = Part.STEALTH
	checkpoint = Part.STEALTH
	guard.place(NEAR_RESTROOM, NEAR_RESTROOM + Vector3(-1, 0, 0))
	guard.sensing = true
	guard.awareness = 0.0
	if replay_thud: thud.play()
	guard.run(_route_to_306(NEAR_RESTROOM))

func _start_room() -> void:
	part = Part.PHOTO
	checkpoint = Part.PHOTO
	guard.place(DESK_STAND, DESK)
	guard.sensing = true
	guard.awareness = 0.0
	var door: Node3D = world.get_node_or_null("Architecture/ClassroomDoor306")
	if door != null: door.set_open(true, true)
	guard.run([Guard.work()])

func _on_mark(tag: String) -> void:
	match tag:
		"restroom":
			guard.run(_stall_sweep())
		"near_restroom":
			# Right at the player's door, the third floor saves them.
			thud.play()
			checkpoint = Part.STEALTH
			guard.run(_route_to_306(guard.global_position))
		"leaving":
			part = Part.STEALTH
			_reset_breath()
			hud.show()
			show_hint("Đợi tiếng chân xa dần rồi bám theo · C: bò, êm · SHIFT: chạy, ồn · F: tắt đèn pin cho khó bị thấy", 9.0)
		"working":
			part = Part.PHOTO
			checkpoint = Part.PHOTO
			show_hint("Chụp lại thứ ông ấy đang dọn · 2: máy ảnh · Chuột trái: chụp", 8.0)

func _reset_breath() -> void:
	breath = 100.0
	breath_close = false
	breath_clock = 0.0
	beat_clock = 0.0
	if breath_panel != null: breath_panel.hide()
	if story != null and story.fear != null: story.fear.darkness = 0.0

func breath_held() -> bool:
	return breath_close and (test_hold or Input.is_physical_key_pressed(KEY_SPACE))

# While he searches the stalls: the closer he is, the louder the heart. Next to the player's
# stall every breath can be heard, so it has to be held, but only for so long.
func _tick_breath(delta: float) -> void:
	var restroom: Node3D = story.restroom
	var p: CharacterBody3D = world.player
	var guard_inside: bool = absf(guard.global_position.y - F2) < 0.5 and guard.global_position.z < 6.0 and guard.global_position.x > 7.0 and guard.global_position.x < 22.0
	var distance: float = guard.global_position.distance_to(p.global_position)
	breath_close = guard_inside and restroom.player_in_closed_stall() and distance < BREATH_NEAR
	breath_panel.visible = guard_inside and restroom.player_stall() >= 0
	if not breath_panel.visible:
		breath = minf(100.0, breath + BREATH_RECOVER * delta)
		story.fear.darkness = move_toward(story.fear.darkness, 0.0, delta)
		return
	var held := breath_held()
	if held:
		breath = maxf(0.0, breath - BREATH_DRAIN * delta)
		if breath <= 0.0:
			# Lungs give out: a ragged gasp anyone outside the door would hear.
			gasp.play()
			world.emit_noise(p.global_position, GASP_NOISE, "breath")
			breath = 35.0
	else:
		breath = minf(100.0, breath + BREATH_RECOVER * delta)
		if breath_close:
			breath_clock -= delta
			if breath_clock <= 0.0:
				breath_clock = 0.75
				world.emit_noise(p.global_position, BREATH_NOISE, "breath")
	breath_bar.value = breath / 100.0
	if breath_close:
		breath_label.text = ("ĐANG NÍN THỞ · ĐỪNG BUÔNG" if held else "BÁC ẤY NGAY NGOÀI CỬA · GIỮ SPACE ĐỂ NÍN THỞ")
	else:
		breath_label.text = "Thở khẽ thôi... bác ấy đang tới gần"
	story.fear.darkness = move_toward(story.fear.darkness, (1.0 - breath / 100.0) * 0.55 if held else 0.0, delta * 2.0)
	# The heartbeat quickens as he works his way along the stalls.
	var closeness := clampf(1.0 - distance / 9.0, 0.0, 1.0)
	beat_clock -= delta
	if beat_clock <= 0.0:
		beat_clock = lerpf(1.1, 0.4, closeness)
		story.fear.beat(lerpf(-18.0, -3.0, closeness))

func blocks_jump() -> bool:
	return breath_panel != null and breath_panel.visible

func _on_caught() -> void:
	if fail_clock >= 0.0: return
	story.subtitle("Bác bảo vệ", "Đứng lại! Ai đó?!", 2.0)
	_reset_breath()
	fail_clock = 1.8
	world.player.velocity = Vector3.ZERO

func locks_player() -> bool:
	return fail_clock >= 0.0

func _restart_checkpoint() -> void:
	var p: CharacterBody3D = world.player
	if p.is_hidden():
		p.hidden_spot.release()
		p.hidden_spot = null
	p.set_crouching(false, true)
	p.velocity = Vector3.ZERO
	match checkpoint:
		Part.HIDE:
			p.global_position = Vector3(13.0, F2, -1.0)
			p.rotation.y = -PI / 2
			for number in [102, 201, 202, 204]:
				var leaf: Node3D = world.get_node_or_null("Architecture/ClassroomDoor%d" % number)
				if leaf != null: leaf.set_open(number == 102, true)
			_start_hide()
		Part.STEALTH:
			p.global_position = Vector3(20.9, F2, -9.3)
			p.rotation.y = PI / 2
			_start_follow(true)
		Part.PHOTO:
			p.global_position = Vector3(-23.5, F3, 38.0)
			p.rotation.y = PI
			_start_room()
	p.camera.rotation = Vector3.ZERO

# The player's camera went off. Called by the player after a successful shot.
func photo_taken() -> void:
	if part != Part.PHOTO and part != Part.STEALTH: return
	photo_framed = evidence_in_frame()
	part = Part.DONE
	guard.sensing = false
	hud.hide()
	hint.hide()
	story.on_photo(photo_framed)

func evidence_in_frame() -> bool:
	var camera: Camera3D = world.player.camera
	var to := EVIDENCE - camera.global_position
	if to.length() > PHOTO_RANGE or rad_to_deg((-camera.global_basis.z).angle_to(to)) > PHOTO_ANGLE: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, EVIDENCE + Vector3.UP * 0.12, 1)
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func guard_position() -> Vector3:
	return guard.global_position

func stand_down() -> void:
	guard.stop()
	hud.hide()
	hint.hide()

func _process(delta: float) -> void:
	if world == null: return
	hint_clock -= delta
	if hint_clock <= 0.0: hint.hide()
	if not world.simulation_active(): return
	if part == Part.HIDE and fail_clock < 0.0: _tick_breath(delta)
	elif breath_panel.visible: _reset_breath()
	if fail_clock >= 0.0:
		fail_clock -= delta
		story.fear.fade = clampf(1.0 - absf(fail_clock - 0.6) / 0.6, 0, 1) if fail_clock < 1.2 else 0.0
		if fail_clock < 0.6 and fail_clock + delta >= 0.6: _restart_checkpoint()
		if fail_clock < 0.0: story.fear.fade = 0.0
	if hud.visible:
		alert_bar.value = guard.awareness
		alert_label.text = "BỊ PHÁT HIỆN" if guard.awareness >= 1.0 else ("BÁC ẤY ĐANG NHÌN THẤY BẠN" if guard.sees_player else ("BÁC ẤY NGHI NGỜ" if guard.awareness > 0.3 else "ĐANG LẨN TRÁNH"))
		var p: CharacterBody3D = world.player
		var moving := Vector2(p.velocity.x, p.velocity.z).length() > 0.2
		var level := 0.0
		if moving: level = (2.0 if p.crouching or Input.is_physical_key_pressed(KEY_CTRL) else (18.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 6.0)) / 18.0
		noise_bar.value = move_toward(noise_bar.value, level, delta * 3.0)
