extends Node3D

enum Stage { ROOM_LURE, BLOOD_TRAIL, DOOR_SCARE, BLOODY_CLUBS, BLACKOUT, ESCAPE_GATE, GATE_INTERFERENCE, CORRIDOR_RUN, FOLLOW_LAN, ROOM_HIDE, LAN_DIALOGUE, TABLE_ESCAPE, UNDER_TABLE, INVESTIGATE_AN, COMFORT_AN, SURVIVE_DAWN, COMPLETE }
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
var escape_pressure: Node
var exit_beacon: Node3D
var laughter_echo: AudioStreamPlayer3D
var blood: Node3D
var apparition: Node3D
var stage_time := 0.0
var blink_time := 0.0
var blackout := false
var briefing_complete := false
var roof_open := false
var gates: Array[Node3D] = []
var lan_seen := {}
var lan_node := "hub"
var dialogue_data: Dictionary
var lan_view: Control
var panel: PanelContainer
var heading: Label
var body_text: Label
var options: VBoxContainer
var panel_kind := ""
var strange_sound: AudioStreamPlayer3D
var laugh: AudioStreamPlayer
var static_sound: AudioStreamPlayer
var shock: AudioStreamPlayer
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
	notebook.position = Vector3(-26.7,3.95,24.4)
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
	apparition = preload("res://scripts/teasing_apparition.gd").new()
	add_child(apparition)
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
	_build_exit_beacon()
	escape_pressure = preload("res://scripts/escape_pressure.gd").new()
	add_child(escape_pressure)
	escape_pressure.setup(self)
	static_sound = AudioStreamPlayer.new()
	static_sound.stream = loop_wav("res://assets/audio/gate_static.wav")
	static_sound.volume_db = -12
	add_child(static_sound)
	shock = AudioStreamPlayer.new()
	shock.stream = load("res://assets/audio/door_jumpscare.wav")
	shock.volume_db = -6
	add_child(shock)
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
	_build_ui()
	world.player.died.connect(close)
	world.get_node("Architecture/ClassroomDoor102").toggled.connect(on_blood_door)
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

func _build_exit_beacon() -> void:
	exit_beacon = Node3D.new()
	exit_beacon.name = "EmergencyExit"
	exit_beacon.position = Vector3(0, 3.2, 77.4)
	add_child(exit_beacon)
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color(0.025, 0.52, 0.18)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.79, 1.0, 0.78)
	for part in [[Vector3.ZERO,Vector3(2.8,1.1,0.12),green], [Vector3(0.45,0, -0.09),Vector3(1.05,0.12,0.03),white], [Vector3(0.9,0.18,-0.09),Vector3(0.14,0.5,0.03),white], [Vector3(0.9,-0.18,-0.09),Vector3(0.14,0.5,0.03),white], [Vector3(-0.65,0.27,-0.09),Vector3(0.17,0.17,0.03),white], [Vector3(-0.65,0.02,-0.09),Vector3(0.14,0.35,0.03),white]]:
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = part[1]
		mesh.mesh = shape
		mesh.position = part[0]
		mesh.material_override = part[2]
		exit_beacon.add_child(mesh)
		if part[0].x == 0.9: mesh.rotation.z = PI/4 if part[0].y > 0 else -PI/4
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, -1, -1.5)
	light.light_color = Color(0.32, 1.0, 0.48)
	light.omni_range = 16
	light.light_energy = 2.5
	exit_beacon.add_child(light)
	for z in [9.5, 25.0, 43.0, 61.0]:
		var path_light := OmniLight3D.new()
		path_light.position = Vector3(0, 1, z-77.4)
		path_light.light_color = Color(0.34, 0.68, 0.48)
		path_light.light_energy = 0.6
		path_light.omni_range = 8
		exit_beacon.add_child(path_light)

func _clear_escape_pressure() -> void:
	if escape_pressure!=null: escape_pressure.reset()
	if exit_beacon != null: exit_beacon.hide()

func panel_visible() -> bool:
	return panel != null and panel.visible or lan_view!=null and lan_view.visible

func narrative_paused() -> bool:
	return false

func tutorial_active() -> bool:
	return world.survival.active and stage < Stage.INVESTIGATE_AN

func controls_player() -> bool:
	return runner.active or stage in [Stage.DOOR_SCARE, Stage.GATE_INTERFERENCE] or stage == Stage.UNDER_TABLE and not portal_arrived

func room_available(number: int) -> bool:
	return number == 103 or number in [102,205] and evidence.has("bear")

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
		Stage.DOOR_SCARE: return "..."
		Stage.BLOODY_CLUBS: return "Cuốn vở trong phòng 205 vẫn chưa được tìm thấy" if evidence.has("clubs") else "Nhìn vào trong phòng... những cây gậy dính máu"
		Stage.BLACKOUT, Stage.ESCAPE_GATE: return "THOÁT KHỎI ĐÂY · Chạy ra cổng chính!"
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
	var text := "ĐÊM 1 · BẠO LỰC HỌC ĐƯỜNG\n" + current_goal()
	if evidence.has("bear"): text += "\n\nĐã nhặt một con gấu bông bị bỏ lại trong phòng học sáng đèn."
	if evidence.has("clubs"): text += "\n\nBên kia hành lang có vết máu, tiếng gõ lặp lại và những cây gậy dính máu."
	if evidence.has("notebook"): text += "\n\nCuốn vở trong phòng 205 ghi tên Nguyễn Bình An. Các trang đầy chữ nguệch ngoạc, gạch xóa và những đôi mắt vẽ lặp lại."
	if blackout: text += "\n\nSau khi tìm đủ ba manh mối, điện tắt. Tiếng cười vang khắp trường và không khí trở nên ngột ngạt."
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
	roof_open = false
	blackout = false
	portal_arrived = false
	return_table.set_available(false)
	_clear_escape_pressure()
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
	apparition.vanish()
	strange_sound.stop()
	laugh.stop()
	laughter_echo.stop()
	static_sound.stop()
	static_sound.volume_db = -12
	shock.stop()
	interference.hide()
	interference_material.set_shader_parameter("strength", 0.0)

func record_evidence(index: int) -> void:
	world.soul_quest.found[index] = true
	world.soul_quest.selected_page = index
	world.soundscape.cue("memory")

func interact_with(item: Node3D) -> bool:
	if not world.survival.active or world.survival.finished:
		return false
	if item == bear and stage == Stage.ROOM_LURE:
		evidence["bear"] = true
		record_evidence(0)
		bear.set_available(false)
		stage = Stage.BLOOD_TRAIL
		stage_time = 0
		lure_light.hide()
		blood.show()
		room_shadow.activate()
		notebook.set_available(true)
		return true
	if item == clubs and stage == Stage.BLOODY_CLUBS:
		discover_clubs()
		return true
	if item == lan and stage == Stage.LAN_DIALOGUE:
		show_lan_page()
		return true
	return false

func on_blood_door(opened: bool) -> void:
	if not opened or stage != Stage.BLOOD_TRAIL: return
	stage = Stage.DOOR_SCARE
	stage_time = 0
	strange_sound.stop()
	var p: CharacterBody3D = world.player
	apparition.appear(p.global_position-p.camera.global_basis.z*0.9, p.camera.global_position)
	shock.play()
	world.hit_flash = 0.7
	p.startle = 1.0

func discover_clubs() -> void:
	if stage != Stage.BLOODY_CLUBS or evidence.has("clubs"): return
	evidence["clubs"] = true
	record_evidence(1)
	clubs.get_node("Interaction").collision_layer = 0
	try_begin_blackout()

func collect_notebook() -> void:
	if not evidence.has("notebook"):
		evidence["notebook"] = true
		record_evidence(2)
	try_begin_blackout()

func try_begin_blackout() -> bool:
	if blackout or not ["bear","clubs","notebook"].all(func(item):return evidence.has(item)): return false
	stage = Stage.BLACKOUT
	stage_time = 0
	blackout = true
	lure_light.hide()
	world._update_light_budget()
	world.soundscape.cue("torch", -8)
	laugh.play()
	laughter_echo.play(2.0)
	exit_beacon.show()
	room_shadow.conceal()
	escape_pressure.start()
	return true

func touch_gate() -> bool:
	if stage != Stage.ESCAPE_GATE: return false
	escape_pressure.reset()
	stage = Stage.GATE_INTERFERENCE
	stage_time = 0
	static_sound.play()
	interference.show()
	world.player.velocity = Vector3.ZERO
	return true

func begin_first_chase() -> void:
	stage = Stage.CORRIDOR_RUN
	stage_time = 0
	laugh.stop()
	laughter_echo.stop()
	_clear_escape_pressure()
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
	roof_open = true
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

func finish_table_crossing() -> void:
	stage = Stage.COMFORT_AN
	stage_time = 0

func close() -> void:
	if panel != null: panel.hide()
	if lan_view!=null: lan_view.hide()
	panel_kind = ""
	if world != null and world.player.health > 0 and not world.paused_by_user and not world.map_panel.visible and not world.survival.finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func bypass_for_test() -> void:
	close()
	if world.player.is_hidden():
		world.player.hidden_spot.release()
		world.player.hidden_spot = null
	if world.player.position.x > 100:
		world.player.global_position = Vector3(17, 0.05, 7.5)
	runner.reset()
	briefing_complete = true
	roof_open = true
	blackout = false
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
	_clear_escape_pressure()
	strange_sound.stop()
	static_sound.stop()
	interference.hide()
	runner.restore_pose()

func tick_player(delta: float) -> void:
	if runner.active: runner.tick(delta)
	else: world.player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not world.simulation_active() or not world.survival.active: return
	stage_time += delta
	var p: CharacterBody3D = world.player
	if stage == Stage.ESCAPE_GATE and Vector2(p.position.x,p.position.z-77.72).length()<1.55: touch_gate()
	if stage in [Stage.BLACKOUT,Stage.ESCAPE_GATE]: escape_pressure.tick(delta)
	if stage == Stage.BLOOD_TRAIL and p.global_position.distance_to(Vector3(-14.5, 0.05, 7.5)) < 14 and not strange_sound.playing:
		strange_sound.play()
	elif stage == Stage.DOOR_SCARE:
		if stage_time >= 1.1:
			apparition.vanish()
			clubs.set_available(true)
			stage = Stage.BLOODY_CLUBS
			stage_time = 0
	elif stage == Stage.BLOODY_CLUBS and stage_time >= 0.5 and p.global_position.z < 5.5 and p.get_interaction_target() == clubs:
		discover_clubs()
	elif stage == Stage.BLACKOUT and stage_time >= 1.5:
		stage = Stage.ESCAPE_GATE
		stage_time = 0
		blink_time = 0.4
	if stage in [Stage.ESCAPE_GATE, Stage.GATE_INTERFERENCE]:
		blink_time -= delta
		if blink_time <= 0:
			blink_time = 0.8 if world.spirit_enabled else 1.5
			world.set_spirit_world(not world.spirit_enabled, true)
		if stage == Stage.GATE_INTERFERENCE:
			interference_material.set_shader_parameter("strength", minf(1, stage_time/1.3))
			if stage_time >= 2.6:
				world.survival.begin_midnight()
	if stage == Stage.UNDER_TABLE and not portal_arrived and stage_time >= 1.8:
		arrive_under_table()
	if world.survival.soul_rescued: stage = Stage.SURVIVE_DAWN

func _process(_delta: float) -> void:
	if stage == Stage.DOOR_SCARE and apparition.visible:
		var camera: Camera3D = world.player.camera
		var face_target := camera.global_position - camera.global_basis.z * 0.70 - Vector3.UP * 0.12
		apparition.global_position += face_target - apparition.face.global_position
	var paused: bool = not world.simulation_active()
	for audio in [strange_sound, laugh, laughter_echo, static_sound, shock]: audio.stream_paused = paused
	if exit_beacon.visible:
		exit_beacon.get_node("Light").light_energy = 2.5 + sin(stage_time * 2.2) * 0.6
		laughter_echo.global_position = Vector3(-14.5+sin(stage_time*0.16)*9, 2.3, 8+absf(sin(stage_time*0.1))*20)
	if world.survival.finished: stage = Stage.COMPLETE

func _input(event: InputEvent) -> void:
	if panel_visible() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	for audio in [strange_sound, laugh, laughter_echo, static_sound, shock]:
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
