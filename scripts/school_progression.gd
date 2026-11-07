extends Node3D

enum Stage { ROOM_LURE, NOISE_UPSTAIRS, CABINET_SCARE, MIRROR_FOUND, HIDE, STEALTH, PHOTO_EVIDENCE, ESCAPE_RUN, BASEMENT_DESCENT, CORRIDOR_RUN, FOLLOW_LAN, ROOM_HIDE, LAN_DIALOGUE, TABLE_ESCAPE, UNDER_TABLE, INVESTIGATE_AN, COMFORT_AN, SURVIVE_DAWN, COMPLETE, LAN_FAREWELL }
const MIRROR_TO_CALL := 0.4
const DESCENT_SECONDS := 1.8
const CLIP_SPOT := Vector3(14.2, 0.05, 3.3)
const CRASH_DELAY := 1.3
const RESTROOM := 203
var world: Node3D
var stage := Stage.ROOM_LURE
var evidence := {}
var clip: Node3D
var restroom: Node3D
var crash_sound: AudioStreamPlayer3D
var lan: Node3D
var runner: Node3D
var lure_light: OmniLight3D
var window_lure: Node3D
var guard_part: Node3D
var subtitle_label: Label
var subtitle_clock := 0.0
var return_table: Node3D
var portal_arrived := false
var escape: Node3D
var fear: CanvasLayer
var uneasy_music: AudioStreamPlayer
var laughter_echo: AudioStreamPlayer3D
var stage_time := 0.0
var blink_time := 0.0
var blackout := false
var power_surge := false
var briefing_complete := false
var stairs_open := false
var lan_seen := {}
var lan_node := "hub"
var dialogue_data: Dictionary
var lan_view: Control
const FAREWELL := [
	["Lan", "Mới một giờ đêm thôi. Lúc này nó không với tới cậu được, nhưng đừng ở lại lâu."],
	["Bạn", "Còn cô thì sao? Cô ra khỏi đây được chứ?"],
	["Lan", "Đừng lo cho tôi. Đưa điện thoại đây, tôi lưu số. Có chuyện gì tôi sẽ nhắn.", "Đưa điện thoại"],
	["Lan", "Xong rồi. Về nhà đi, ngủ một chút. Đừng trả lời tin nhắn nào không phải của tôi."],
]
var panel: PanelContainer
var heading: Label
var body_text: Label
var options: VBoxContainer
var panel_kind := ""
var laugh: AudioStreamPlayer
var static_sound: AudioStreamPlayer
var interference: ColorRect
var interference_material: ShaderMaterial

func setup(school: Node3D) -> void:
	world = school
	dialogue_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/night1_dialogue.json"))
	world.player.damaged.connect(func(_amount):
		if panel_visible(): close())
	name = "NightOneStory"
	_clear_lure_room()
	clip = make_interactable("clip", CLIP_SPOT)
	clip.rotation.y = 0.4
	lan = make_interactable("lan", Vector3(212, -299.95, -910))
	lure_light = OmniLight3D.new()
	lure_light.position = Vector3(14.5, 2.6, 3.6)
	lure_light.light_color = Color(1.0, 0.79, 0.45)
	lure_light.light_energy = 2.2
	lure_light.omni_range = 7
	lure_light.shadow_enabled = true
	add_child(lure_light)
	window_lure = preload("res://scripts/classroom_lure.gd").new()
	add_child(window_lure)
	window_lure.setup(world, self)
	fear = preload("res://scripts/fear_overlay.gd").new()
	add_child(fear)
	restroom = preload("res://scripts/restroom_scene.gd").new()
	add_child(restroom)
	restroom.setup(world, self)
	crash_sound = AudioStreamPlayer3D.new()
	crash_sound.stream = load("res://assets/audio/mirror_crash_muffled.wav")
	# Where the mirror hits the basin, one floor straight above the lit classroom.
	crash_sound.position = Vector3(8.0, 5.0, -1.05)
	crash_sound.unit_size = 14
	crash_sound.max_distance = 70
	crash_sound.volume_db = 2
	add_child(crash_sound)
	return_table = preload("res://scripts/story_table.gd").new()
	return_table.world = world
	return_table.story = self
	return_table.returning = true
	return_table.kind = 1
	return_table.position = Vector3(12.8, 0.05, 1.5)
	world.get_node("HidingSpots").add_child(return_table)
	return_table.get_node("Cover/HideSign").hide()
	laugh = AudioStreamPlayer.new()
	laugh.stream = loop_wav("res://assets/audio/haunting_laughter.wav")
	laugh.volume_db = -13
	add_child(laugh)
	laughter_echo = AudioStreamPlayer3D.new()
	laughter_echo.stream = loop_wav("res://assets/audio/haunting_laughter.wav")
	laughter_echo.position = Vector3(-14.5, 2.3, 7.5)
	laughter_echo.unit_size = 20
	laughter_echo.max_distance = 90
	laughter_echo.pitch_scale = 0.86
	laughter_echo.volume_db = -10
	add_child(laughter_echo)
	uneasy_music = AudioStreamPlayer.new()
	uneasy_music.stream = loop_wav("res://assets/audio/eerie_lullaby.wav")
	add_child(uneasy_music)
	static_sound = AudioStreamPlayer.new()
	static_sound.stream = loop_wav("res://assets/audio/gate_static.wav")
	static_sound.volume_db = -12
	add_child(static_sound)
	interference = ColorRect.new()
	interference.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interference_material = ShaderMaterial.new()
	interference_material.shader = preload("res://assets/materials/gate_interference.gdshader")
	interference.material = interference_material
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	layer.add_child(interference)
	runner = preload("res://scripts/endless_corridor.gd").new()
	add_child(runner)
	runner.setup(self)
	escape = preload("res://scripts/school_escape.gd").new()
	add_child(escape)
	escape.setup(self)
	_build_ui()
	guard_part = preload("res://scripts/guard_prologue.gd").new()
	add_child(guard_part)
	guard_part.setup(world, self)
	world.player.died.connect(close)
	reset()

func in_lure_room(at: Vector3) -> bool:
	return at.x > 7.05 and at.x < 21.95 and at.z > -11.9 and at.z < 5.85 and at.y >= -0.1 and at.y < 3.75

func _clear_lure_room() -> void:
	# Empty the first classroom so the hair clip is its only object of interest.
	# Keep the room's walls, floor, windows and door, including their colliders.
	if world.has_node("RuntimeGeometry"):
		for batch in world.get_node("RuntimeGeometry").get_children():
			if batch.get_meta("realm_category", -1) != 2: continue
			var poses: Array[Transform3D] = batch.multimesh.placements.duplicate()
			var cursed: Array = batch.get_meta("realm_placements", []).duplicate()
			var changed := false
			for i in range(poses.size()):
				if not in_lure_room(batch.global_transform * poses[i].origin): continue
				poses[i].basis = Basis.from_scale(Vector3.ZERO)
				if not cursed.is_empty(): cursed[i] = poses[i]
				changed = true
			if changed:
				var clean := preload("res://scripts/static_multimesh.gd").new()
				clean.transform_format = MultiMesh.TRANSFORM_3D
				clean.mesh = batch.multimesh.mesh
				clean.custom_aabb = batch.multimesh.custom_aabb
				clean.placements = poses
				batch.multimesh = clean
				batch.set_meta("realm_placements", cursed)
				for entry in world.realm_scenery.visuals:
					if entry.node == batch: entry.placements = cursed
	else:
		for item in world.get_node("Furniture").get_children():
			if in_lure_room(item.global_position): item.hide()
	for shape in world.find_children("*", "CollisionShape3D", true, false):
		if shape.shape is BoxShape3D and in_lure_room(shape.global_position) and shape.shape.size.y < 2.4 and shape.shape.size.length() < 5:
			shape.set_deferred("disabled", true)
	for cover in world.get_node("HidingSpots").get_children():
		if not in_lure_room(cover.global_position): continue
		cover.hide()
		for area in cover.find_children("*", "Area3D", true, false): area.collision_layer = 0
		for shape in cover.find_children("*", "CollisionShape3D", true, false): shape.set_deferred("disabled", true)

func loop_wav(path: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load(path).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size()/2
	return stream

func make_interactable(kind: String, pos: Vector3) -> Node3D:
	var item := preload("res://scripts/night_story_interactable.gd").new()
	item.story = self
	item.kind = kind
	item.position = pos
	add_child(item)
	return item

func panel_visible() -> bool:
	return panel != null and panel.visible or lan_view!=null and lan_view.visible

func narrative_paused() -> bool:
	return false

func tutorial_active() -> bool:
	# The camera works while tailing the guard: the photo in 306 is the point.
	return world.survival.active and stage < Stage.INVESTIGATE_AN and not stage in [Stage.STEALTH, Stage.PHOTO_EVIDENCE]

func controls_player() -> bool:
	return runner.active or escape.active or restroom.locks_player() or guard_part.locks_player() or stage == Stage.BASEMENT_DESCENT or stage == Stage.UNDER_TABLE and not portal_arrived

func room_available(number: int) -> bool:
	# During the tail the side rooms on floor 3 are open, so there is somewhere to duck into.
	return number == 103 or number == RESTROOM and stage >= Stage.NOISE_UPSTAIRS or number in [302, 305, 306] and stage in [Stage.STEALTH, Stage.PHOTO_EVIDENCE]

func door_locked(_room_number: int) -> bool:
	return false

func sector_accessible(_feet: Vector3) -> bool:
	return true

func ready_for_rescue() -> bool:
	return briefing_complete

func can_cross_midnight() -> bool:
	return stage == Stage.BASEMENT_DESCENT and stage_time >= DESCENT_SECONDS or briefing_complete

func current_goal() -> String:
	match stage:
		Stage.ROOM_LURE: return "Khám phá ngôi trường"
		Stage.NOISE_UPSTAIRS: return "Tiếng kính vỡ ngay trên lầu · Nước đang rỉ xuống trần"
		Stage.CABINET_SCARE: return "..."
		Stage.MIRROR_FOUND: return "Ai đã cất chiếc gương vỡ trong tủ?"
		Stage.HIDE: return "Có người dưới lầu · Trốn đi"
		Stage.STEALTH: return "Bám theo bác bảo vệ · Đừng để bị nghe thấy"
		Stage.PHOTO_EVIDENCE: return "Chụp lại giấy tờ bác bảo vệ đang dọn"
		Stage.ESCAPE_RUN: return "BỊ PHÁT HIỆN · Chạy khỏi trường!"
		Stage.BASEMENT_DESCENT: return "Cổng khóa · Chạy xuống hầm kỹ thuật"
		Stage.CORRIDOR_RUN: return "CHẠY! · WASD di chuyển · SHIFT chạy · SPACE nhảy · CTRL trượt khi lấy đà"
		Stage.FOLLOW_LAN: return "LAN: CHẠY THEO TÔI!"
		Stage.ROOM_HIDE: return "Núp trong phòng · Đừng gây tiếng động"
		Stage.LAN_DIALOGUE: return "E · Hỏi Lan về lời nguyền"
		Stage.TABLE_ESCAPE: return "Lan chỉ một lối đi dưới gầm bàn"
		Stage.UNDER_TABLE: return "Chờ tiếng ngoài cửa im đi, rồi chui ra khỏi gầm bàn"
		Stage.INVESTIGATE_AN, Stage.COMFORT_AN: return "Tìm linh hồn mắc kẹt · Lắng nghe tiếng khóc trong trường"
		Stage.SURVIVE_DAWN: return "An đã được giải thoát · Oán niệm suy yếu · Sống tới bình minh"
	return "Bình minh · Đêm 1 kết thúc"

func journal_context() -> String:
	var text := ("ĐÊM 1 · GHEN TỊ\n" if world.get_tree().has_meta("night_one") else "ĐÊM 0 · MỞ ĐẦU\n") + current_goal()
	if evidence.has("clip"): text += "\n\nPhòng 103 sáng đèn dù trường đã cắt điện. Trên sàn chỉ có một chiếc cài tóc nhựa hồng bị gãy đôi, mất một cánh hoa."
	if restroom != null and restroom.broken: text += "\n\nVừa nhặt cài tóc thì có tiếng kính vỡ ở tầng 2, ngay phía trên. Gương trong nhà vệ sinh A-203 rơi xuống, làm bể vòi nước; nước tràn ra hành lang và thấm xuống trần phòng 103."
	if evidence.has("mirror"): text += "\n\nTrong tủ đồ của nhà vệ sinh, giữa đám gián và nhện, có một chiếc gương cầm tay bị vỡ. Ai đó đã cất nó ở đây."
	if stage >= Stage.HIDE: text += "\n\nBác bảo vệ trường nghe tiếng động, lên soát từng phòng tầng 2. Tiếng gì đó đổ trên tầng 3 kéo bác đi ngay trước cửa nhà vệ sinh."
	if evidence.has("photo"): text += "\n\nĐã chụp được tập giấy tờ và một tấm ảnh lớp học mà bác bảo vệ lén dọn khỏi bàn giáo viên phòng 306."
	elif stage >= Stage.ESCAPE_RUN: text += "\n\nTấm ảnh chụp vội không thấy rõ giấy tờ trên bàn phòng 306."
	if briefing_complete: text += "\n\nLan: Bình minh chỉ đưa nhóm ra ngoài tạm thời. Hãy giúp các linh hồn thoát khỏi oán niệm để phá lời nguyền. Danh tính của Lan vẫn là bí ẩn."
	return text

func reset() -> void:
	close()
	if runner != null:
		runner.reset()
		runner.restore_pose()
	stage = Stage.ROOM_LURE
	stage_time = 0
	blink_time = 0
	evidence.clear()
	briefing_complete = false
	# The prologue no longer locks the staircase; doors keep the order instead.
	stairs_open = true
	blackout = false
	power_surge = false
	portal_arrived = false
	return_table.set_available(false)
	escape.reset()
	guard_part.reset()
	fear.clear()
	subtitle_label.hide()
	lan_seen.clear()
	lan_node = "hub"
	clip.set_available(true)
	lan.set_available(false)
	lure_light.show()
	window_lure.reset()
	restroom.reset()
	crash_sound.stop()
	uneasy_music.stop()
	laugh.stop()
	laughter_echo.stop()
	static_sound.stop()
	static_sound.volume_db = -12
	interference.hide()
	interference_material.set_shader_parameter("strength", 0.0)

func record_evidence(index: int, silent := false) -> void:
	world.soul_quest.found[index] = true
	world.soul_quest.selected_page = index
	if not silent: world.soundscape.cue("memory")

func interact_with(item: Node3D) -> bool:
	if not world.survival.active or world.survival.finished:
		return false
	if item == clip and stage == Stage.ROOM_LURE:
		collect_clip()
		return true
	if item == restroom.hand_mirror and stage == Stage.CABINET_SCARE and not restroom.swarm.locks_player():
		collect_mirror()
		return true
	if item == lan and stage == Stage.LAN_DIALOGUE:
		show_lan_page()
		return true
	return false

# Clue 1. The crash upstairs follows a beat later, so the pickup and the noise read as cause
# and effect without the game saying so.
func collect_clip() -> void:
	evidence["clip"] = true
	record_evidence(0)
	clip.set_available(false)
	stage = Stage.NOISE_UPSTAIRS
	stage_time = 0

func mirror_falls() -> void:
	crash_sound.play()
	restroom.shatter()
	# The lamp shivers with the slab and dust sifts down through its light.
	window_lure.buzz = 0.6

func open_cabinet() -> bool:
	if stage != Stage.NOISE_UPSTAIRS or not restroom.broken: return false
	stage = Stage.CABINET_SCARE
	stage_time = 0
	restroom.open_cabinet()
	return true

# Clue 2. A moment later the guard calls out from downstairs.
func collect_mirror() -> void:
	evidence["mirror"] = true
	record_evidence(1)
	restroom.hand_mirror.set_available(false)
	stage = Stage.MIRROR_FOUND
	stage_time = 0

func begin_guard() -> void:
	stage = Stage.HIDE
	stage_time = 0
	guard_part.begin()

# Clue 3 is the photograph. The flash gives the player away either way.
func on_photo(framed: bool) -> void:
	if framed:
		evidence["photo"] = true
		record_evidence(2)
	else:
		world.notify("Ảnh bị nhòe, không thấy rõ giấy tờ")
	stage = Stage.PHOTO_EVIDENCE
	stage_time = 0
	subtitle("Bác bảo vệ", "Ai?! Đứng lại đó!", 1.6)
	guard_part.guard.whistle_now()

func hear_noise(at: Vector3, radius: float, source: String) -> void:
	if guard_part != null and guard_part.active(): guard_part.guard.hear(at, radius, source)

func photo_taken() -> void:
	guard_part.photo_taken()

func guard_position() -> Vector3:
	return guard_part.guard_position()

func begin_escape() -> void:
	stage = Stage.ESCAPE_RUN
	stage_time = 0
	guard_part.stand_down()
	escape.start()

# The gate is chained, so the escape ends at the service stairs down into the tunnels under
# the school. Their emergency lighting is red: that is the red corridor.
func enter_basement() -> void:
	stage = Stage.BASEMENT_DESCENT
	stage_time = 0
	world.player.velocity = Vector3.ZERO
	world.soundscape.cue("door", -6)

func subtitle(speaker: String, text: String, seconds := 2.6) -> void:
	subtitle_label.text = "%s: %s" % [speaker, text] if speaker != "" else text
	subtitle_label.show()
	subtitle_clock = seconds

func begin_first_chase() -> void:
	preload("res://scripts/game_progress.gd").mark("corridor")
	stage = Stage.CORRIDOR_RUN
	stage_time = 0
	laugh.stop()
	laughter_echo.stop()
	static_sound.stop()
	interference.hide()
	runner.start()

func enter_lan_room() -> void:
	stage = Stage.LAN_DIALOGUE
	stage_time = 0
	runner.lan.hide()
	lan.global_position = runner.refuge.to_global(Vector3(-8.5, 0.05, 1.8))
	lan.set_available(true)
	show_lan_page()

func show_lan_page() -> void:
	world.soul_quest.close()
	world.map_panel.hide()
	world.player.cancel_chalk_charge()
	panel.hide()
	panel_kind = "lan"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	lan_node = "hub"
	var choices: Array = []
	for question in dialogue_data.lan.questions:
		choices.append({"text":question.question,"action":choose_lan_question.bind(question.id)})
	var understood: bool = dialogue_data.lan.required.all(func(id):return lan_seen.has(id))
	if understood: choices.append({"text":"Tôi hiểu rồi. Tôi sẽ chui xuống gầm bàn.","action":advance_lan})
	lan_view.show_line("Lan",dialogue_data.lan.intro if lan_seen.is_empty() else "Bạn còn muốn hỏi điều gì?",choices)

func choose_lan_question(id: String) -> void:
	if stage!=Stage.LAN_DIALOGUE or not panel_visible(): return
	for question in dialogue_data.lan.questions:
		if question.id!=id: continue
		lan_node = "question"
		lan_view.show_line("Bạn",question.question,[{"text":"Nghe Lan trả lời","action":answer_lan_question.bind(id)}])
		return

func answer_lan_question(id: String) -> void:
	if stage!=Stage.LAN_DIALOGUE or not panel_visible(): return
	for question in dialogue_data.lan.questions:
		if question.id!=id: continue
		lan_node = "answer"
		lan_view.show_line("Lan",question.answer,[{"text":"Hỏi tiếp","action":finish_lan_question.bind(id)}])
		return

func finish_lan_question(id: String) -> void:
	if stage!=Stage.LAN_DIALOGUE or not panel_visible(): return
	lan_seen[id] = true
	show_lan_page()

func advance_lan() -> void:
	if stage != Stage.LAN_DIALOGUE or not panel_visible(): return
	if not dialogue_data.lan.required.all(func(id):return lan_seen.has(id)): return
	close()
	stage = Stage.TABLE_ESCAPE
	stage_time = 0
	runner.table.get_node("Interaction").collision_layer = 16
	lan.visual.get_child(0).reach = 0.7
	world.player.look_at(Vector3(runner.table.global_position.x, world.player.position.y, runner.table.global_position.z))

func begin_table_crossing() -> void:
	stage = Stage.UNDER_TABLE
	stage_time = 0
	portal_arrived = false

func arrive_under_table() -> void:
	var p: CharacterBody3D = world.player
	var torch_was_on: bool = p.saved_flashlight
	runner.table.release()
	p.hidden_spot = null
	runner.restore_pose()
	runner.reset()
	lan.set_available(false)
	blackout = false
	briefing_complete = true
	return_table.set_available(true)
	return_table.occupant = p
	return_table.entry_position = return_table.approach_position()
	p.begin_hide(return_table)
	p.saved_flashlight = torch_was_on
	# A cable trench under the table comes up through the floor of 103: the same school, no other world.
	world.set_spirit_world(false, true)
	portal_arrived = true
	world.collect_master_key()
	world.notice_time = 0
	world.encounters.give_break(15)
	fear.fade = 0.0

# Night 1 ends here: Lan waits by the table, they swap numbers and Peter goes home.
func finish_table_crossing() -> void:
	stage = Stage.LAN_FAREWELL
	stage_time = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: CharacterBody3D = world.player
	lan.global_position = p.global_position + p.global_basis.x * 1.3
	lan.show()
	_farewell(0)

func _farewell(index: int) -> void:
	if index >= FAREWELL.size():
		lan_view.hide()
		_go_home()
		return
	var line: Array = FAREWELL[index]
	var reply: String = line[2] if line.size() > 2 else "Tiếp"
	lan_view.show_line(line[0], line[1], [{"text": reply, "action": _farewell.bind(index + 1)}])

func _go_home() -> void:
	if world.get_tree().has_meta("story_stay_in_school"):
		return
	var tree := world.get_tree()
	if tree.has_meta("chapter_corridor"):
		tree.remove_meta("chapter_corridor")
	tree.change_scene_to_file.call_deferred("res://scenes/home.tscn")

func close() -> void:
	if panel != null: panel.hide()
	if lan_view!=null: lan_view.hide()
	panel_kind = ""
	if world != null and world.player.health > 0 and not world.paused_by_user and not world.map_panel.visible and not world.survival.finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func begin_night_one() -> void:
	bypass_for_test()
	world.player.global_position = Vector3(12, 0.05, 75.2)
	world.survival.begin_midnight()
	world.collect_master_key()
	world.notice_time = 0
	var quest: Node3D = world.soul_quest
	# The Intro's clues were carried out of the school; the rest are still inside.
	for i in range(quest.memories.size()):
		if quest.memories[i].get("source", "") == "opening":
			quest.found[i] = true

func bypass_for_test() -> void:
	close()
	if world.player.is_hidden():
		world.player.hidden_spot.release()
		world.player.hidden_spot = null
	if world.player.position.x > 100:
		world.player.global_position = Vector3(17, 0.05, 7.5)
	runner.reset()
	restroom.swarm.stop()
	guard_part.reset()
	escape.reset()
	fear.clear()
	briefing_complete = true
	stairs_open = true
	blackout = false
	power_surge = false
	stage = Stage.COMFORT_AN
	evidence["clip"] = true
	evidence["mirror"] = true
	evidence["photo"] = true
	clip.set_available(false)
	restroom.hand_mirror.set_available(false)
	lan.set_available(false)
	lure_light.hide()
	laugh.stop()
	laughter_echo.stop()
	crash_sound.stop()
	uneasy_music.stop()
	static_sound.stop()
	interference.hide()
	runner.restore_pose()

func tick_player(delta: float) -> void:
	if runner.active: runner.tick(delta)
	elif escape.active: escape.tick(delta)
	else: world.player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not world.simulation_active() or not world.survival.active: return
	stage_time += delta
	if stage == Stage.NOISE_UPSTAIRS and stage_time >= CRASH_DELAY and not restroom.broken:
		mirror_falls()
	elif stage == Stage.MIRROR_FOUND and stage_time >= MIRROR_TO_CALL:
		begin_guard()
	elif stage in [Stage.HIDE, Stage.STEALTH, Stage.PHOTO_EVIDENCE]:
		var parts := {1: Stage.HIDE, 2: Stage.STEALTH, 3: Stage.PHOTO_EVIDENCE}
		if parts.has(guard_part.part) and parts[guard_part.part] != stage:
			stage = parts[guard_part.part]
			stage_time = 0
		elif guard_part.part == guard_part.Part.DONE and stage_time >= 0.9:
			begin_escape()
	if stage == Stage.BASEMENT_DESCENT:
		# Down the service stairs in the dark; the tunnel's red lamps come up out of it.
		fear.fade = clampf(stage_time / (DESCENT_SECONDS * 0.6), 0, 1)
		if stage_time >= DESCENT_SECONDS:
			fear.fade = 0.0
			world.survival.begin_midnight()
	if stage == Stage.UNDER_TABLE and not portal_arrived:
		fear.fade = clampf(stage_time / 1.2, 0, 1)
		if stage_time >= 1.8: arrive_under_table()
	if world.survival.soul_rescued: stage = Stage.SURVIVE_DAWN

func _process(delta: float) -> void:
	var paused: bool = not world.simulation_active()
	if subtitle_clock > 0.0 and not paused:
		subtitle_clock -= delta
		if subtitle_clock <= 0.0: subtitle_label.hide()
	for audio in [crash_sound, laugh, laughter_echo, static_sound, uneasy_music]: audio.stream_paused = paused
	if laughter_echo.playing:
		laughter_echo.global_position = Vector3(-14.5+sin(stage_time*0.16)*9, 2.3, 30+absf(sin(stage_time*0.1))*30)
	if world.survival.finished: stage = Stage.COMPLETE

func _input(event: InputEvent) -> void:
	if panel_visible() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if restroom != null: restroom.stop_audio()
	for audio in [crash_sound, laugh, laughter_echo, static_sound, uneasy_music]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(270, 150)
	panel.custom_minimum_size = Vector2(740, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.05, 0.97)
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	world.get_node("HUD").get_child(0).add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 22)
	stack.add_child(heading)
	body_text = Label.new()
	body_text.custom_minimum_size = Vector2(680, 140)
	body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_text.add_theme_font_size_override("font_size", 19)
	stack.add_child(body_text)
	options = VBoxContainer.new()
	stack.add_child(options)
	panel.hide()
	subtitle_label = Label.new()
	subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_label.offset_left = -480
	subtitle_label.offset_right = 480
	subtitle_label.offset_top = -170
	subtitle_label.offset_bottom = -134
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.8))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	subtitle_label.add_theme_constant_override("outline_size", 6)
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.hide()
	world.get_node("HUD").get_child(0).add_child(subtitle_label)
	lan_view = preload("res://scripts/visual_novel_dialogue.gd").new()
	lan_view.setup(world.get_node("HUD").get_child(0),"Lan",close)

func show_panel(kind: String, title: String, text: String) -> void:
	world.soul_quest.close()
	world.map_panel.hide()
	world.player.cancel_chalk_charge()
	panel_kind = kind
	lan_view.hide()
	heading.show()
	body_text.show()
	heading.text = title
	body_text.text = text
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func add_option(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	options.add_child(button)
