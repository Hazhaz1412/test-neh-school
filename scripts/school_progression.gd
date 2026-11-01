extends Node3D

enum Stage { ROOM_LURE, BLOOD_TRAIL, CLUB_SCARE, ASCEND, DOOR_SIEGE, ESCAPE_RUN, GATE_INTERFERENCE, CORRIDOR_RUN, FOLLOW_LAN, ROOM_HIDE, LAN_DIALOGUE, TABLE_ESCAPE, UNDER_TABLE, INVESTIGATE_AN, COMFORT_AN, SURVIVE_DAWN, COMPLETE, LAN_FAREWELL }
const NOTEBOOK_SPOT := Vector3(-29.4,7.85,49.6)
const TOP_FLOOR_HEIGHT := 7.8
var world: Node3D
var stage := Stage.ROOM_LURE
var evidence := {}
var bear: Node3D
var clubs: Node3D
var lan: Node3D
var runner: Node3D
var lure_light: OmniLight3D
var window_lure: Node3D
var room_shadow: Node3D
var notebook: Node3D
var notebook_page: Control
var return_table: Node3D
var portal_arrived := false
var stair_gate: Node3D
var club_scare: Node3D
var door_siege: Node3D
var escape: Node3D
var fear: CanvasLayer
var uneasy_music: AudioStreamPlayer
var laughter_echo: AudioStreamPlayer3D
var blood: Node3D
var stage_time := 0.0
var blink_time := 0.0
var blackout := false
var power_surge := false
var briefing_complete := false
var stairs_open := false
var shadow_room_open := false
var lan_seen := {}
var lan_node := "hub"
var dialogue_data: Dictionary
var lan_view: Control
const FAREWELL := [
	["Lan", "Trời sắp sáng rồi. Lúc này nó không với tới cậu được, nhưng đừng ở lại lâu."],
	["Bạn", "Còn cô thì sao? Cô ra khỏi đây được chứ?"],
	["Lan", "Đừng lo cho tôi. Đưa điện thoại đây, tôi lưu số. Có chuyện gì tôi sẽ nhắn.", "Đưa điện thoại"],
	["Lan", "Xong rồi. Về nhà đi, ngủ một chút. Đừng trả lời tin nhắn nào không phải của tôi."],
]
var panel: PanelContainer
var heading: Label
var body_text: Label
var options: VBoxContainer
var panel_kind := ""
var strange_sound: AudioStreamPlayer3D
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
	bear = make_interactable("bear", Vector3(14.5, 0.05, 4.1))
	clubs = make_interactable("clubs", Vector3(-14.5, 0.05, 4.1))
	lan = make_interactable("lan", Vector3(212, 0.05, -910))
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
	room_shadow = preload("res://scripts/classroom_shadow.gd").new()
	add_child(room_shadow)
	room_shadow.setup(world, self)
	notebook = preload("res://scripts/an_notebook.gd").new()
	notebook.story = self
	notebook.position = NOTEBOOK_SPOT
	add_child(notebook)
	return_table = preload("res://scripts/story_table.gd").new()
	return_table.world = world
	return_table.story = self
	return_table.returning = true
	return_table.kind = 1
	return_table.position = Vector3(12.8, 0.05, 1.5)
	world.get_node("HidingSpots").add_child(return_table)
	return_table.get_node("Cover/HideSign").hide()
	blood = Node3D.new()
	blood.name = "MysteriousBloodTrail"
	add_child(blood)
	for i in range(12):
		var patch := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.13 + (i%3)*0.055
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.006
		mesh.radial_segments = 9
		patch.mesh = mesh
		patch.position = Vector3(9-i*2.05, 0.025, 7.5+sin(i*2.4)*0.38)
		patch.scale.z = 1.7
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.29, 0.018, 0.013)
		material.roughness = 0.35
		patch.material_override = material
		blood.add_child(patch)
	stair_gate = preload("res://scripts/progression_gate.gd").new()
	stair_gate.progression = self
	stair_gate.position = Vector3(-5.1, 0, 5.3)
	add_child(stair_gate)
	fear = preload("res://scripts/fear_overlay.gd").new()
	add_child(fear)
	strange_sound = AudioStreamPlayer3D.new()
	strange_sound.stream = loop_wav("res://assets/audio/strange_knock.wav")
	strange_sound.position = Vector3(-14.5, 1.2, 2.5)
	strange_sound.unit_size = 10
	strange_sound.max_distance = 35
	strange_sound.volume_db = -10
	add_child(strange_sound)
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
	club_scare = preload("res://scripts/club_scare.gd").new()
	add_child(club_scare)
	club_scare.setup(self)
	door_siege = preload("res://scripts/door_siege.gd").new()
	add_child(door_siege)
	door_siege.setup(self)
	escape = preload("res://scripts/school_escape.gd").new()
	add_child(escape)
	escape.setup(self)
	_build_ui()
	world.player.died.connect(close)
	reset()

func in_lure_room(at: Vector3) -> bool:
	return at.x > 7.05 and at.x < 21.95 and at.z > -11.9 and at.z < 5.85 and at.y >= -0.1 and at.y < 3.75

func _clear_lure_room() -> void:
	# Empty the first classroom so the teddy is its only object of interest.
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
	return world.survival.active and stage < Stage.INVESTIGATE_AN

func controls_player() -> bool:
	return runner.active or escape.active or club_scare.locks_player() or stage == Stage.GATE_INTERFERENCE or stage == Stage.UNDER_TABLE and not portal_arrived

func room_available(number: int) -> bool:
	return number == 103 or number == 102 and evidence.has("bear") or number == 306 and shadow_room_open and not door_siege.active

func door_locked(_room_number: int) -> bool:
	return false

func sector_accessible(_feet: Vector3) -> bool:
	return true

func ready_for_rescue() -> bool:
	return briefing_complete

func can_cross_midnight() -> bool:
	return stage == Stage.GATE_INTERFERENCE and stage_time >= 2.6 or briefing_complete

func current_goal() -> String:
	match stage:
		Stage.ROOM_LURE: return "Khám phá ngôi trường"
		Stage.BLOOD_TRAIL: return "Vết máu ở phía đối diện... tiếng gì đang lặp lại sau cánh cửa?"
		Stage.CLUB_SCARE: return "..."
		Stage.ASCEND: return "Có người đứng ở cửa sổ tầng trên cùng"
		Stage.DOOR_SIEGE: return "..."
		Stage.ESCAPE_RUN: return "THOÁT KHỎI ĐÂY · Chạy ra cổng chính!"
		Stage.GATE_INTERFERENCE: return "Cổng không mở... tiếng rè đang nuốt mọi thứ"
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
	if evidence.has("bear"): text += "\n\nĐã nhặt một con gấu bông bị bỏ lại trong phòng học sáng đèn."
	if evidence.has("clubs"): text += "\n\nBên kia hành lang có vết máu, tiếng gõ lặp lại và những cây gậy dính máu."
	if evidence.has("notebook"): text += "\n\nCuốn vở trong phòng 306 ghi tên Nguyễn Bình An. Các trang đầy chữ nguệch ngoạc, gạch xóa và một ký hiệu con mắt khóc vẽ bằng máu."
	if blackout: text += "\n\nKhi tìm đủ ba manh mối, điện toàn trường chập chờn rồi tắt hẳn và thứ đó phá cửa xông vào."
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
	stairs_open = false
	shadow_room_open = false
	blackout = false
	power_surge = false
	portal_arrived = false
	return_table.set_available(false)
	club_scare.reset()
	door_siege.reset()
	escape.reset()
	fear.clear()
	lan_seen.clear()
	lan_node = "hub"
	bear.set_available(true)
	clubs.set_available(false)
	lan.set_available(false)
	blood.hide()
	lure_light.show()
	window_lure.reset()
	room_shadow.reset()
	notebook.inspected = false
	notebook.set_available(false)
	strange_sound.stop()
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
	if item == bear and stage == Stage.ROOM_LURE:
		evidence["bear"] = true
		record_evidence(0)
		bear.set_available(false)
		clubs.set_available(true)
		stage = Stage.BLOOD_TRAIL
		stage_time = 0
		lure_light.hide()
		blood.show()
		return true
	if item == clubs and stage == Stage.BLOOD_TRAIL:
		collect_clubs()
		return true
	if item == lan and stage == Stage.LAN_DIALOGUE:
		show_lan_page()
		return true
	return false

func collect_clubs() -> void:
	evidence["clubs"] = true
	# The silence is the first beat of the scare, so no pickup sound plays.
	record_evidence(1,true)
	clubs.set_available(false)
	strange_sound.stop()
	world.soundscape.voice.stop()
	stage = Stage.CLUB_SCARE
	stage_time = 0
	club_scare.start()

func begin_uneasy_music() -> void:
	uneasy_music.volume_db = -30
	uneasy_music.play()
	room_shadow.show_at_window()

func release_stairs() -> void:
	stairs_open = true
	stage = Stage.ASCEND
	stage_time = 0
	world.soundscape.at("lock", stair_gate.global_position+Vector3.UP*1.2, -4)

func on_shadow_entered() -> void:
	notebook.set_available(true)

func collect_notebook() -> void:
	if evidence.has("notebook"): return
	evidence["notebook"] = true
	record_evidence(2,true)
	uneasy_music.stop()
	notebook.set_available(false)
	room_shadow.conceal()
	# Shut the player in; the notebook sits too far inside to reach from the doorway.
	world.get_node("Architecture/ClassroomDoor306").set_open(false)
	door_siege.active = true

func begin_escape() -> void:
	stage = Stage.ESCAPE_RUN
	stage_time = 0
	escape.start()

func seal_broken() -> void:
	stage = Stage.GATE_INTERFERENCE
	stage_time = 0
	blink_time = 0.4
	static_sound.play()
	interference.show()
	world.player.velocity = Vector3.ZERO

func begin_first_chase() -> void:
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
	interference.show()
	interference_material.set_shader_parameter("strength", 0.25)
	static_sound.volume_db = -26
	static_sound.play()

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
	world.set_spirit_world(false, true)
	world.set_spirit_world(true)
	portal_arrived = true
	world.collect_master_key()
	world.notice_time = 0
	world.encounters.give_break(15)
	static_sound.stop()
	static_sound.volume_db = -12
	interference.hide()

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
	world.get_tree().change_scene_to_file("res://scenes/home.tscn")

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
	club_scare.reset()
	door_siege.reset()
	escape.reset()
	fear.clear()
	briefing_complete = true
	stairs_open = true
	shadow_room_open = true
	blackout = false
	power_surge = false
	stage = Stage.COMFORT_AN
	evidence["bear"] = true
	evidence["clubs"] = true
	evidence["notebook"] = true
	bear.set_available(false)
	clubs.set_available(false)
	notebook.set_available(false)
	lan.set_available(false)
	blood.hide()
	lure_light.hide()
	room_shadow.conceal()
	laugh.stop()
	laughter_echo.stop()
	strange_sound.stop()
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
	var p: CharacterBody3D = world.player
	if stage == Stage.BLOOD_TRAIL and p.global_position.distance_to(Vector3(-14.5, 0.05, 7.5)) < 14 and not strange_sound.playing:
		strange_sound.play()
	elif stage == Stage.CLUB_SCARE:
		club_scare.tick(delta)
	elif stage == Stage.ASCEND:
		room_shadow.tick(delta)
		# The lullaby is what draws the player up, so it grows floor by floor.
		var height := clampf(p.global_position.y/TOP_FLOOR_HEIGHT,0,1)
		if uneasy_music.playing: uneasy_music.volume_db = move_toward(uneasy_music.volume_db,lerpf(-24,-8,height),delta*5)
		if door_siege.active and not panel_visible():
			stage = Stage.DOOR_SIEGE
			stage_time = 0
			door_siege.start()
	elif stage == Stage.DOOR_SIEGE:
		door_siege.tick(delta)
	if stage == Stage.GATE_INTERFERENCE:
		blink_time -= delta
		if blink_time <= 0:
			blink_time = 0.8 if world.spirit_enabled else 1.5
			world.set_spirit_world(not world.spirit_enabled, true)
		interference_material.set_shader_parameter("strength", minf(1, stage_time/1.3))
		if stage_time >= 2.6:
			world.survival.begin_midnight()
	if stage == Stage.UNDER_TABLE and not portal_arrived and stage_time >= 1.8:
		arrive_under_table()
	if world.survival.soul_rescued: stage = Stage.SURVIVE_DAWN

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [strange_sound, laugh, laughter_echo, static_sound, uneasy_music]: audio.stream_paused = paused
	if laughter_echo.playing:
		laughter_echo.global_position = Vector3(-14.5+sin(stage_time*0.16)*9, 2.3, 30+absf(sin(stage_time*0.1))*30)
	if world.survival.finished: stage = Stage.COMPLETE

func _input(event: InputEvent) -> void:
	if panel_visible() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	for audio in [strange_sound, laugh, laughter_echo, static_sound, uneasy_music]:
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
	notebook_page = preload("res://scripts/an_notebook_page.gd").new()
	notebook_page.clip_contents = true
	notebook_page.custom_minimum_size = Vector2(680,410)
	stack.add_child(notebook_page)
	notebook_page.hide()
	stack.add_child(options)
	panel.hide()
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
	notebook_page.hide()
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
