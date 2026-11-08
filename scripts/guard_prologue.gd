extends Node3D

# The guard's part of the prologue, after the hand mirror:
#  1. HIDE    He calls out from the stairs, runs up to the restroom and shoves the stalls open one
#             by one. The player shuts themselves in a stall and holds their breath.
#  2. STEALTH Something falls on floor 3. He goes up and across to B-302, and the player tails him:
#             every footstep makes noise, his torch is his eyes, he stops to look back at set points,
#             and falling too far behind loses him. The camera stays off: a flash would give it away.
#  3. PHOTO   In B-302 he clears papers off the teacher's desk, back to the door. A photo of them is
#             the third clue.
#  4. DUCK    The flash gives the player away. He turns and runs for the door: four seconds to get
#             inside a locker.
#  5. SEARCH  He stops in front of the lockers and listens. Breathing gives the player away.
#  6. SNEAK   He hunts the player through the building. Every few seconds he gets a feel for
#             where they are (a creak, a shadow) and goes to search that spot, lockers included;
#             the hints come faster as time goes on. If he sees them he runs them down; out of
#             sight for a moment, he searches where they vanished and opens the nearest hiding
#             places. The player has to get out to the main gate, where school_escape.gd takes over.
# Being caught fades out and restarts the current part from its checkpoint.
const Guard := preload("res://scripts/security_guard.gd")
const Spot := preload("res://scripts/hiding_spot.gd")
const F1 := 0.05
const F2 := 3.95
const F3 := 7.85
# He is already coming up the stairs when the player takes the mirror: top of the flight on floor 2.
const CALL_SPOT := Vector3(-4.8, F2, -2.0)
const RUSH_PATH: Array[Vector3] = [Vector3(-3.6, F2, -3.0), Vector3(-1.2, F2, -3.0), Vector3(-0.2, F2, -1.9), Vector3(-0.2, F2, 6.5), Vector3(1.0, F2, 7.5), Vector3(14.5, F2, 7.5)]
const RESTROOM_DOOR := Vector3(14.5, F2, 7.5)
const NEAR_RESTROOM := Vector3(18.5, F2, 7.5)
const RESTROOM_ENTRY := Vector3(14.5, F2, 4.2)
# B-302, the classroom in the middle of block B's top floor. Its door opens off B's hall.
const ROOM := 1302
const DESK := Vector3(0.0, F3, -60.4)
const DESK_STAND := Vector3(0.0, F3, -59.25)
const EVIDENCE := Vector3(0.0, F3 + 0.84, -60.45)
const ROOM_MOUTH := Vector3(0.0, F3, -43.2)
const HALL_OUTSIDE := Vector3(0.0, F3, -40.4)
# The breath-holding beats, in the stall and in the locker.
const BREATH_NEAR := 3.2
# At the lockers he only hears it with his ear to the door.
const LOCKER_NEAR := 2.2
const BREATH_DRAIN := 12.0
const BREATH_RECOVER := 30.0
const BREATH_NOISE := 3.5
const GASP_NOISE := 9.0
const PHOTO_RANGE := 15.0
const PHOTO_ANGLE := 24.0
# Tailing: further than this for longer than that and he is gone.
const LOSE_RANGE := 22.0
const LOSE_SECONDS := 4.0
const DUCK_SECONDS := 4.0
# Reaching the yard in front of the main gate ends the sneak.
const GATE_Z := 60.0
const GATE_HALF := 18.0
const SNEAK_START := Vector3(-6.5, F3, -40.0)
# Once the player has made it down to the ground floor, being caught restarts them there.
const SNEAK_LOW_START := Vector3(-3.0, F1, 7.4)
# Where he stands after a catch: the same floor, far enough to get a head start.
const RETURN_HIGH := Vector3(1.5, F3, -16.0)
const RETURN_LOW := Vector3(18.0, F1, 7.5)
const FIRST_HINT := 7.0
const HINT_EVERY := 13.0
const HINT_FASTEST := 6.5
const HINT_SPREAD := 6.0
const CHASE_SPEED := 4.7
const CHASE_REPATH := 0.3
const LOSE_SIGHT := 2.4
const WITNESS := 0.8
const SEARCH_REACH := 7.0
const UP_F2_F3: Array[Vector3] = [Vector3(-3.8, F2, 7.5), Vector3(-4.8, F2, 6.8), Vector3(-4.8, F2, 6.0), Vector3(-4.8, F3, -2.0), Vector3(-3.6, F3, -3.0), Vector3(-1.2, F3, -3.0)]
# His hunt after the photo: floors 3 and 2, the middle stairs, both halls and block B's east stairs.
# The ground floor is the way out, so he leaves it to the player.
const PATROL := [
	{"at": Vector3(-1.2, F3, -3.0), "look": 2.0},
	{"at": Vector3(-14.0, F3, 7.5), "look": 1.8},
	{"at": Vector3(14.0, F3, 7.5), "look": 1.8},
	{"at": Vector3(-1.2, F2, -3.0), "look": 2.0},
	{"at": Vector3(-14.0, F2, 7.5), "look": 1.6},
	{"at": Vector3(1.5, F2, -40.5), "look": 2.0},
	{"at": Vector3(30.0, F2, -40.5), "look": 2.0},
	{"at": Vector3(30.0, F3, -40.5), "look": 2.0},
	{"at": Vector3(-26.0, F3, -40.5), "look": 2.0},
	{"at": Vector3(1.5, F3, -40.5), "look": 1.5},
]
enum Part { NONE, HIDE, STEALTH, PHOTO, DUCK, SEARCH, SNEAK, DONE }
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
var lost_clock := 0.0
var follow_grace := 0.0
var warn: Label
var duck_clock := 0.0
var duck_panel: Control
var duck_label: Label
var duck_bar: ProgressBar
var search_spot: Node3D
var fail_restarted := false
var hunt_mode := ""
var hunch_clock := 0.0
var hint_every := HINT_EVERY
var repath_clock := 0.0
var unseen := 0.0
var last_seen := Vector3.ZERO
var reached_ground := false

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "GuardPrologue"
	guard = Guard.new()
	add_child(guard)
	guard.setup(world, story)
	guard.concealed = func() -> bool: return story.restroom.player_in_closed_stall()
	guard.caught.connect(_on_caught)
	guard.spotted.connect(_on_spotted)
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
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	warn = Label.new()
	warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	warn.offset_left = -360
	warn.offset_right = 360
	warn.offset_top = -300
	warn.offset_bottom = -264
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 20)
	warn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	warn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	warn.add_theme_constant_override("outline_size", 6)
	warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(warn)
	# The four-second dash for a locker.
	duck_panel = VBoxContainer.new()
	duck_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	duck_panel.offset_left = -260
	duck_panel.offset_right = 260
	duck_panel.offset_top = -170
	duck_panel.offset_bottom = -90
	duck_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	duck_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(duck_panel)
	duck_label = Label.new()
	duck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	duck_label.add_theme_font_override("font", preload("res://scripts/horror_type.gd").TITLE)
	duck_label.add_theme_font_size_override("font_size", 40)
	duck_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.62))
	duck_label.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.0))
	duck_label.add_theme_constant_override("outline_size", 10)
	duck_panel.add_child(duck_label)
	duck_bar = _bar(Color(0.95, 0.3, 0.18))
	duck_bar.custom_minimum_size = Vector2(520, 10)
	duck_panel.add_child(duck_bar)

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
	lost_clock = 0.0
	search_spot = null
	hunt_mode = ""
	reached_ground = false
	guard.stop()
	guard.concealed = func() -> bool: return story.restroom.player_in_closed_stall()
	thud.stop()
	evidence.show()
	hud.hide()
	hint.hide()
	warn.hide()
	duck_panel.hide()
	_reset_breath()
	for number in [102, 201, 202, 204, ROOM]:
		var leaf: Node3D = world.get_node_or_null("Architecture/ClassroomDoor%d" % number)
		if leaf != null: leaf.set_open(false)

func active() -> bool:
	return part in [Part.HIDE, Part.STEALTH, Part.PHOTO, Part.DUCK, Part.SEARCH, Part.SNEAK]

func escaping() -> bool:
	return part in [Part.DUCK, Part.SEARCH, Part.SNEAK]

func show_hint(text: String, seconds := 6.0) -> void:
	hint.text = text
	hint.show()
	hint_clock = seconds

# --- Routes ---

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

# Up the middle stairs to floor 3, down the long corridor to block B and into B-302. He looks
# back at the top of the stairs and twice along the corridor, where there is nowhere to duck.
func _route_to_room(start: Vector3) -> Array[Dictionary]:
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
	jobs.append_array(Guard.look_back(Vector3(1.5, F3, -12.0), Vector3(-4.8, F3, 2.0), 2.2))
	jobs.append(Guard.goto(Vector3(1.5, F3, -21.0)))
	jobs.append_array(Guard.look_back(Vector3(1.5, F3, -40.0), Vector3(1.5, F3, -5.0), 2.6))
	jobs.append(Guard.goto(Vector3(1.5, F3, -33.0)))
	jobs.append_array(Guard.look_back(Vector3(1.5, F3, -40.0), Vector3(1.5, F3, -15.0), 1.8))
	jobs.append(Guard.goto(Vector3(0.4, F3, -40.6)))
	jobs.append(Guard.face(Vector3(0.0, F3, -44.0)))
	jobs.append(Guard.door(ROOM, true))
	jobs.append(Guard.goto(DESK_STAND))
	jobs.append(Guard.face(DESK))
	jobs.append(Guard.mark("working"))
	jobs.append(Guard.say("Lại là mấy thứ này...", 2.4))
	jobs.append(Guard.work())
	return jobs

# The flash: he spins round and runs for the door.
func _rush_out() -> Array[Dictionary]:
	return [Guard.face(world.player.global_position), Guard.wait(0.55, "idle"),
		Guard.sprint([DESK_STAND + Vector3(0, 0, 2.0), ROOM_MOUTH, HALL_OUTSIDE]), Guard.wait(0.3, "look_around", true)]

# Out in the hall he goes straight for the lockers and listens at the one the player is in.
func _search_lockers(spot: Node3D) -> Array[Dictionary]:
	var front := Vector3(spot.global_position.x, F3, spot.approach_position().z - 0.1)
	var jobs: Array[Dictionary] = []
	jobs.append(Guard.say("Chạy đâu rồi...?", 2.0))
	jobs.append(Guard.wait(1.4, "look_around", true))
	jobs.append(Guard.walk([front]))
	jobs.append(Guard.face(spot.global_position))
	jobs.append(Guard.say("Mày trốn trong này phải không...?", 2.4))
	jobs.append(Guard.wait(3.6, "listen"))
	jobs.append(Guard.act(_rattle_locker.bind(spot)))
	jobs.append(Guard.wait(1.2, "listen"))
	jobs.append(Guard.say("Không có... Chắc nó chạy xuống cầu thang rồi. Mày không thoát được đâu!", 3.2))
	jobs.append(Guard.mark("hunt"))
	return jobs

# He bangs the locker next to the player's, the one he thinks is empty.
func _rattle_locker(spot: Node3D) -> void:
	var other: Node3D = null
	for candidate in spot.get_parent().get_children():
		if candidate != spot and candidate.global_position.distance_to(spot.global_position) < 1.2: other = candidate
	var at: Vector3 = (other if other != null else spot).global_position + Vector3.UP
	world.soundscape.at("door_bang", at, -6)
	world.soundscape.at("lock", at, -8)
	world.player.startle = 0.6
	story.fear.beat(-1.0)

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
	lost_clock = 0.0
	guard.place(NEAR_RESTROOM, NEAR_RESTROOM + Vector3(-1, 0, 0))
	guard.sensing = true
	guard.awareness = 0.0
	if replay_thud: thud.play()
	guard.run(_route_to_room(NEAR_RESTROOM))

func _start_room() -> void:
	part = Part.PHOTO
	checkpoint = Part.PHOTO
	guard.place(DESK_STAND, DESK)
	guard.sensing = true
	guard.awareness = 0.0
	var door: Node3D = world.get_node_or_null("Architecture/ClassroomDoor%d" % ROOM)
	if door != null: door.set_open(true, true)
	guard.run([Guard.work()])

func _start_duck() -> void:
	part = Part.DUCK
	checkpoint = Part.DUCK
	duck_clock = DUCK_SECONDS
	guard.sensing = false
	guard.awareness = 0.0
	guard.run(_rush_out())
	hud.hide()
	duck_panel.show()
	show_hint("Bác ấy lao ra cửa! · Chui vào một cái tủ ngoài hành lang (E)", DUCK_SECONDS)

func _start_search(spot: Node3D) -> void:
	part = Part.SEARCH
	checkpoint = Part.SEARCH
	search_spot = spot
	duck_panel.hide()
	guard.sensing = true
	guard.awareness = 0.0
	guard.concealed = func() -> bool: return false
	guard.run(_search_lockers(spot))

# `return_from`: after a catch he does not wander off; he starts from there, on the player's
# floor, and comes straight for them.
func _start_sneak(first_stop := 0, return_from := Vector3.INF) -> void:
	part = Part.SNEAK
	checkpoint = Part.SNEAK
	_reset_breath()
	guard.concealed = func() -> bool: return false
	guard.sensing = true
	guard.awareness = 0.0
	guard.hunting = true
	guard.catch_on_sight = false
	guard.deaf = false
	guard.patrol = []
	hunt_mode = "hunt"
	hint_every = HINT_EVERY
	if return_from != Vector3.INF:
		hunch_clock = 0.4
		hint_every = HINT_EVERY - 4.0
		guard.run([Guard.say("Lần này thì đừng hòng!", 1.8), Guard.wait(0.4, "look_around")])
	else:
		hunch_clock = FIRST_HINT
		# He starts where the player is least likely to be, then comes looking.
		guard.run([Guard.goto(PATROL[first_stop].at, Guard.HUNT_WALK), Guard.wait(PATROL[first_stop].look, "look_around", true)])
	hud.show()
	show_hint("Ra tới cổng chính · Bác ấy sẽ lần ra chỗ bạn đứng: đừng đứng yên một chỗ · Bị thấy thì chạy và cắt đuôi · Z / X: lấp ló ở góc tường", 9.0)

# --- The hunt after the photo ---

func _tick_sneak(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if not reached_ground and p.global_position.y < F1 + 1.0 and p.global_position.z < 9.5 and p.global_position.z > -60.0:
		reached_ground = true
	match hunt_mode:
		"hunt":
			hunch_clock -= delta
			if hunch_clock <= 0.0:
				_follow_hint()
		"chase":
			_tick_chase(delta)

# He gets a feel for where the player is and goes to search there.
func _follow_hint() -> void:
	var p: CharacterBody3D = world.player
	hint_every = maxf(HINT_FASTEST, hint_every - 0.8)
	hunch_clock = hint_every
	if p.global_position.y < F1 + 1.0 and p.global_position.z > 9.5:
		return
	var map := world.get_world_3d().navigation_map
	var aim := p.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(2.0, HINT_SPREAD)
	var target := NavigationServer3D.map_get_closest_point(map, aim + Vector3.UP * 0.3) - Vector3.UP * 0.35
	if absf(target.y - p.global_position.y) > 2.0: target = p.global_position
	var jobs: Array[Dictionary] = [Guard.goto(target, Guard.HUNT_RUSH), Guard.wait(1.6, "look_around", true)]
	jobs.append_array(_spot_checks(target, 1))
	guard.run(jobs)
	if randf() < 0.4: story.subtitle("Bác bảo vệ", ["Tao nghe thấy rồi nhé...", "Ở quanh đây thôi.", "Ra đây đi, tao không làm gì đâu."][randi() % 3], 2.0)

# Walk to the hiding places nearest `at` and pull each one open.
func _spot_checks(at: Vector3, count: int) -> Array[Dictionary]:
	var spots: Array = []
	for spot in world.get_node("HidingSpots").get_children():
		if not spot.has_method("approach_position"): continue
		if absf(spot.global_position.y - at.y) < 1.5 and spot.global_position.distance_to(at) < SEARCH_REACH: spots.append(spot)
	spots.sort_custom(func(a, b): return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	var jobs: Array[Dictionary] = []
	for spot in spots.slice(0, count):
		jobs.append(Guard.goto(spot.approach_position(), Guard.HUNT_RUSH))
		jobs.append(Guard.face(spot.global_position))
		jobs.append(Guard.act(_open_spot.bind(spot)))
		jobs.append(Guard.wait(0.8, "look_around", true))
	return jobs

func _open_spot(spot: Node3D) -> void:
	world.soundscape.at("door_bang", spot.global_position + Vector3.UP, -6)
	if spot.get("occupant") == world.player:
		story.subtitle("Bác bảo vệ", "Ra đây! Tưởng trốn trong này là thoát à?", 2.0)
		_on_caught()

func _on_spotted() -> void:
	if part != Part.SNEAK or hunt_mode == "chase" or fail_clock >= 0.0: return
	hunt_mode = "chase"
	guard.deaf = true
	guard.hunting = false
	unseen = 0.0
	repath_clock = 0.0
	last_seen = world.player.global_position
	guard.whistle_now()
	story.subtitle("Bác bảo vệ", "Thấy mày rồi! Đứng lại!", 1.8)
	story.fear.beat(-2.0)

# Flat out after the player. Breaking his line of sight long enough makes him lose them; being
# seen climbing into a hiding place does not.
func _tick_chase(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if guard.sees_player:
		unseen = 0.0
		last_seen = p.global_position
	else:
		unseen += delta
	if p.is_hidden():
		if unseen < WITNESS:
			# He saw where they went.
			hunt_mode = "drag"
			var spot: Node3D = p.hidden_spot
			guard.run([Guard.goto(spot.approach_position(), CHASE_SPEED, true), Guard.face(spot.global_position), Guard.act(_open_spot.bind(spot)), Guard.mark("search_done")])
			return
	elif guard.global_position.distance_to(p.global_position) < 1.3 and absf(guard.global_position.y - p.global_position.y) < 1.0:
		_on_caught()
		return
	if unseen > LOSE_SIGHT:
		_search_lost()
		return
	repath_clock -= delta
	if repath_clock <= 0.0:
		repath_clock = CHASE_REPATH
		var route: Array = guard.route_to(last_seen)
		guard.run([{"do": "walk", "path": route, "i": 0, "speed": CHASE_SPEED, "anim": "sprint"}])

# Gone round a corner: he looks where they vanished and opens the nearest two hiding places.
func _search_lost() -> void:
	hunt_mode = "search"
	guard.awareness = 0.6
	var jobs: Array[Dictionary] = [Guard.goto(last_seen, Guard.HUNT_RUSH), Guard.say("Chạy đâu rồi...?", 1.6), Guard.wait(2.0, "look_around", true)]
	jobs.append_array(_spot_checks(last_seen, 2))
	jobs.append(Guard.mark("search_done"))
	guard.run(jobs)

func _on_mark(tag: String) -> void:
	match tag:
		"restroom":
			guard.run(_stall_sweep())
		"near_restroom":
			# Right at the player's door, the third floor saves them.
			thud.play()
			checkpoint = Part.STEALTH
			guard.run(_route_to_room(guard.global_position))
		"leaving":
			part = Part.STEALTH
			lost_clock = 0.0
			follow_grace = 8.0
			_reset_breath()
			hud.show()
			show_hint("Đợi tiếng chân xa dần rồi bám theo, đừng để mất dấu · Bác ấy quay lại thì nép sau trụ, cột hay góc tường · Z / X: nghiêng người lấp ló · C: bò, êm · F: tắt đèn pin", 10.0)
		"working":
			part = Part.PHOTO
			checkpoint = Part.PHOTO
			warn.hide()
			show_hint("Chụp lại thứ bác ấy đang dọn · 2: máy ảnh · Chuột trái: chụp", 8.0)
		"hunt":
			_start_sneak()
		"search_done":
			hunt_mode = "hunt"
			guard.deaf = false
			guard.hunting = true
			hunch_clock = 3.0

func _reset_breath() -> void:
	breath = 100.0
	breath_close = false
	breath_clock = 0.0
	beat_clock = 0.0
	if breath_panel != null: breath_panel.hide()
	if story != null and story.fear != null: story.fear.darkness = 0.0

func breath_held() -> bool:
	return breath_close and (test_hold or Input.is_physical_key_pressed(KEY_SPACE))

# Whether the breath beat is on, and whether he is close enough to hear it.
func _breath_scene(distance: float) -> Array[bool]:
	var p: CharacterBody3D = world.player
	if part == Part.HIDE:
		var restroom: Node3D = story.restroom
		var guard_inside: bool = absf(guard.global_position.y - F2) < 0.5 and guard.global_position.z < 6.0 and guard.global_position.x > 7.0 and guard.global_position.x < 22.0
		return [guard_inside and restroom.player_stall() >= 0, guard_inside and restroom.player_in_closed_stall() and distance < BREATH_NEAR]
	if part == Part.SEARCH:
		var near: bool = p.is_hidden() and distance < 7.0
		return [near, near and distance < LOCKER_NEAR]
	return [false, false]

# While he searches the stalls or stands at the lockers: the closer he is, the louder the heart.
# Next to the player every breath can be heard, so it has to be held, but only for so long.
func _tick_breath(delta: float) -> void:
	var p: CharacterBody3D = world.player
	var distance: float = guard.global_position.distance_to(p.global_position)
	var scene := _breath_scene(distance)
	if scene[1] and not breath_close:
		# A moment to react before the first breath can be heard.
		breath_clock = 0.9
	breath_close = scene[1]
	breath_panel.visible = scene[0]
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
	var closeness := clampf(1.0 - distance / 9.0, 0.0, 1.0)
	beat_clock -= delta
	if beat_clock <= 0.0:
		beat_clock = lerpf(1.1, 0.4, closeness)
		story.fear.beat(lerpf(-18.0, -3.0, closeness))

func blocks_jump() -> bool:
	return breath_panel != null and breath_panel.visible

# Tailing: too far behind for too long and he is gone round a corner for good.
func _tick_follow(delta: float) -> void:
	follow_grace = maxf(0.0, follow_grace - delta)
	var distance: float = guard.global_position.distance_to(world.player.global_position)
	if follow_grace > 0.0 or distance <= LOSE_RANGE:
		lost_clock = maxf(0.0, lost_clock - delta * 2.0)
	else:
		lost_clock += delta
	warn.visible = lost_clock > 0.0
	if warn.visible:
		warn.text = "Bác ấy đi xa quá · Bám theo kẻo mất dấu (%d)" % ceili(LOSE_SECONDS - lost_clock)
	if lost_clock >= LOSE_SECONDS:
		_fail("Mất dấu bác bảo vệ rồi...")

# Four seconds: inside a locker, or he has the player.
func _tick_duck(delta: float) -> void:
	var p: CharacterBody3D = world.player
	duck_clock -= delta
	duck_bar.value = clampf(duck_clock / DUCK_SECONDS, 0.0, 1.0)
	var in_locker: bool = p.is_hidden() and p.hidden_spot.kind == Spot.Kind.LOCKER
	duck_label.text = ("ĐÃ VÀO TỦ · NÍN THỞ" if in_locker else "TRỐN VÀO TỦ! %.1f" % maxf(0.0, duck_clock))
	if not p.is_hidden() and guard.global_position.distance_to(p.global_position) < 1.3:
		guard.whistle_now()
		_on_caught()
		return
	if duck_clock <= 0.0:
		if in_locker: _start_search(p.hidden_spot)
		else:
			guard.whistle_now()
			_on_caught()

func _fail(line: String) -> void:
	if fail_clock >= 0.0: return
	story.subtitle("", line, 2.0)
	_reset_breath()
	warn.hide()
	duck_panel.hide()
	fail_clock = 1.8
	fail_restarted = false
	guard.sensing = false
	world.player.velocity = Vector3.ZERO

func _on_caught() -> void:
	if fail_clock >= 0.0: return
	_fail("Bác bảo vệ: Đứng lại! Bắt được rồi nhé!")

func locks_player() -> bool:
	return fail_clock >= 0.0

func _restart_checkpoint() -> void:
	var p: CharacterBody3D = world.player
	if p.is_hidden():
		p.hidden_spot.release()
		p.hidden_spot = null
		p.get_node("Collision").shape.height = 1.75
		p.get_node("Collision").position.y = 0.9
		p.camera.fov = 73
	p.set_crouching(false, true)
	p.velocity = Vector3.ZERO
	p.camera.position = Vector3(0, 1.62, 0)
	guard.concealed = func() -> bool: return story.restroom.player_in_closed_stall()
	guard.stop()
	lost_clock = 0.0
	warn.hide()
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
			p.global_position = Vector3(1.5, F3, -36.0)
			p.rotation.y = 0.0
			_start_room()
		Part.DUCK:
			# Back inside B-302 by the door, the flash just gone off, out of his way to the door.
			p.global_position = Vector3(-3.0, F3, -45.2)
			p.rotation.y = PI
			guard.place(DESK_STAND, DESK)
			_start_duck()
		Part.SEARCH:
			var spot: Node3D = search_spot if is_instance_valid(search_spot) else world.get_node("HidingSpots/HallB_2")
			spot.release()
			spot.occupant = p
			spot.entry_position = spot.approach_position()
			p.begin_hide(spot)
			guard.place(HALL_OUTSIDE, spot.global_position)
			_start_search(spot)
		Part.SNEAK:
			if reached_ground:
				p.global_position = SNEAK_LOW_START
				p.rotation.y = 0.0
				guard.place(RETURN_LOW, SNEAK_LOW_START)
				_start_sneak(0, RETURN_LOW)
			else:
				p.global_position = SNEAK_START
				p.rotation.y = -PI / 2
				guard.place(RETURN_HIGH, SNEAK_START)
				_start_sneak(0, RETURN_HIGH)
	p.camera.rotation = Vector3.ZERO

# The player's camera went off. Called by the player after a successful shot.
func photo_taken() -> void:
	if part != Part.PHOTO: return
	photo_framed = evidence_in_frame()
	story.on_photo(photo_framed)
	_start_duck()

func evidence_in_frame() -> bool:
	var camera: Camera3D = world.player.camera
	var to := EVIDENCE - camera.global_position
	if to.length() > PHOTO_RANGE or rad_to_deg((-camera.global_basis.z).angle_to(to)) > PHOTO_ANGLE: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, EVIDENCE + Vector3.UP * 0.12, 1)
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func guard_position() -> Vector3:
	return guard.global_position

func in_gate_yard(feet: Vector3) -> bool:
	return feet.y < 1.5 and feet.z > GATE_Z and absf(feet.x) < GATE_HALF

func stand_down() -> void:
	part = Part.DONE
	guard.stop()
	hud.hide()
	hint.hide()
	warn.hide()
	duck_panel.hide()
	_reset_breath()

func _process(delta: float) -> void:
	if world == null: return
	hint_clock -= delta
	if hint_clock <= 0.0: hint.hide()
	if not world.simulation_active(): return
	if fail_clock < 0.0 and part in [Part.HIDE, Part.SEARCH]: _tick_breath(delta)
	elif breath_panel.visible: _reset_breath()
	if fail_clock < 0.0:
		match part:
			Part.STEALTH: _tick_follow(delta)
			Part.DUCK: _tick_duck(delta)
			Part.SNEAK:
				if in_gate_yard(world.player.global_position):
					stand_down()
					story.begin_escape()
				else:
					_tick_sneak(delta)
	if fail_clock >= 0.0:
		fail_clock -= delta
		story.fear.fade = clampf(1.0 - absf(fail_clock - 0.6) / 0.6, 0, 1) if fail_clock < 1.2 else 0.0
		if fail_clock < 0.6 and not fail_restarted:
			fail_restarted = true
			_restart_checkpoint()
		if fail_clock < 0.0: story.fear.fade = 0.0
	if hud.visible:
		alert_bar.value = guard.awareness
		alert_label.text = "BÁC ẤY ĐANG ĐUỔI THEO!" if hunt_mode == "chase" else "BỊ PHÁT HIỆN" if guard.awareness >= 1.0 else ("BÁC ẤY ĐANG NHÌN THẤY BẠN" if guard.sees_player else ("BÁC ẤY NGHI NGỜ" if guard.awareness > 0.3 else "ĐANG LẨN TRÁNH"))
		var p: CharacterBody3D = world.player
		var moving := Vector2(p.velocity.x, p.velocity.z).length() > 0.2
		var level := 0.0
		if moving: level = (2.0 if p.crouching or Input.is_physical_key_pressed(KEY_CTRL) else (18.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 6.0)) / 18.0
		noise_bar.value = move_toward(noise_bar.value, level, delta * 3.0)
