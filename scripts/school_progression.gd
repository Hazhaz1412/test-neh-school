extends Node3D

enum Stage { ROOM_LURE, NOISE_UPSTAIRS, CABINET_SCARE, MIRROR_FOUND, HIDE, STEALTH, PHOTO_EVIDENCE, ESCAPE_RUN, GATE_BREAK, BASEMENT_DESCENT, CORRIDOR_RUN, SURVIVE_NIGHT, COMPLETE }
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
var runner: Node3D
var lure_light: OmniLight3D
var window_lure: Node3D
var guard_part: Node3D
var subtitle_label: Label
var subtitle_clock := 0.0
var escape: Node3D
var fear: CanvasLayer
var stage_time := 0.0
var blink_time := 0.0
var blackout := false
var power_surge := false
var briefing_complete := false
var stairs_open := false
var panel: PanelContainer
var heading: Label
var body_text: Label
var options: VBoxContainer
var panel_kind := ""

func setup(school: Node3D) -> void:
	world = school
	world.player.damaged.connect(func(_amount):
		if panel_visible(): close())
	name = "NightOneStory"
	_clear_lure_room()
	clip = make_interactable("clip", CLIP_SPOT)
	clip.rotation.y = 0.4
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
	runner = preload("res://scripts/tunnel_escape.gd").new()
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
			var changed := false
			for i in range(poses.size()):
				if not in_lure_room(batch.global_transform * poses[i].origin): continue
				poses[i].basis = Basis.from_scale(Vector3.ZERO)
				changed = true
			if changed:
				var clean := preload("res://scripts/static_multimesh.gd").new()
				clean.transform_format = MultiMesh.TRANSFORM_3D
				clean.mesh = batch.multimesh.mesh
				clean.custom_aabb = batch.multimesh.custom_aabb
				clean.placements = poses
				batch.multimesh = clean
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
	return panel != null and panel.visible

func narrative_paused() -> bool:
	return false

func tutorial_active() -> bool:
	return world.survival.active and stage < Stage.SURVIVE_NIGHT

# In the restroom and on the tail a flash would give the player away; only the papers in B-302
# are worth that.
func camera_allowed() -> bool:
	return not tutorial_active() or stage == Stage.PHOTO_EVIDENCE and guard_part.part == guard_part.Part.PHOTO

func controls_player() -> bool:
	return runner.active or escape.locks_player() or restroom.locks_player() or guard_part.locks_player() or stage == Stage.BASEMENT_DESCENT

func room_available(number: int) -> bool:
	# During the tail block B's top-floor rooms are open; on the way out every room is.
	return number == 103 or number == RESTROOM and stage >= Stage.NOISE_UPSTAIRS or number in [1301, 1302, 1303] and stage in [Stage.STEALTH, Stage.PHOTO_EVIDENCE] or stage == Stage.ESCAPE_RUN

func door_locked(_room_number: int) -> bool:
	return false

func sector_accessible(_feet: Vector3) -> bool:
	return true

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
		Stage.ESCAPE_RUN: return "BỊ PHÁT HIỆN · Lẻn ra cổng chính, đừng để bác bảo vệ bắt"
		Stage.GATE_BREAK: return "Cổng khóa · Phá cửa phòng kỹ thuật trước khi bác ấy xuống tới nơi"
		Stage.BASEMENT_DESCENT: return "Chạy xuống hầm kỹ thuật"
		Stage.CORRIDOR_RUN: return "CHẠY! · WASD di chuyển · SHIFT chạy · SPACE nhảy · CTRL trượt khi lấy đà"
		Stage.SURVIVE_NIGHT: return "Trụ tới 06:00 · Đừng để bác bảo vệ bắt cả nhóm"
	return "Bình minh · Đêm 1 kết thúc"

func journal_context() -> String:
	var text := ("ĐÊM 1\n" if world.get_tree().has_meta("night_one") else "ĐÊM 0 · MỞ ĐẦU\n") + current_goal()
	if evidence.has("clip"): text += "\n\nPhòng 103 sáng đèn dù trường đã cắt điện. Trên sàn chỉ có một chiếc cài tóc nhựa hồng bị gãy đôi, mất một cánh hoa."
	if restroom != null and restroom.broken: text += "\n\nVừa nhặt cài tóc thì có tiếng kính vỡ ở tầng 2, ngay phía trên. Gương trong nhà vệ sinh A-203 rơi xuống, làm bể vòi nước; nước tràn ra hành lang và thấm xuống trần phòng 103."
	if evidence.has("mirror"): text += "\n\nTrong tủ đồ của nhà vệ sinh, giữa đám gián và nhện, có một chiếc gương cầm tay bị vỡ. Ai đó đã cất nó ở đây."
	if stage >= Stage.HIDE: text += "\n\nBác bảo vệ trường nghe tiếng động, lên soát từng phòng tầng 2. Tiếng gì đó đổ trên tầng 3 kéo bác đi ngay trước cửa nhà vệ sinh."
	if evidence.has("photo"): text += "\n\nĐã chụp được tập giấy tờ và một tấm ảnh lớp học mà bác bảo vệ lén dọn khỏi bàn giáo viên phòng B-302."
	elif stage >= Stage.ESCAPE_RUN: text += "\n\nTấm ảnh chụp vội không thấy rõ giấy tờ trên bàn phòng B-302."
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
	escape.reset()
	guard_part.reset()
	fear.clear()
	subtitle_label.hide()
	clip.set_available(true)
	lure_light.show()
	window_lure.reset()
	restroom.reset()
	crash_sound.stop()

func record_evidence(index: int, silent := false) -> void:
	world.journal.record(index)
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

# Out in the yard: the guard spots the player from upstairs and the gate is chained.
func begin_escape() -> void:
	stage = Stage.GATE_BREAK
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
	runner.start()

# The jump into the reservoir is not the end of the dream: Peter comes up in the dream shore
# (scenes/dream_shore.tscn) and wakes at home only after reaching the gate there.
func finish_dream() -> void:
	runner.reset()
	runner.restore_pose()
	fear.fade = 1.0
	_go_home()

func _go_home() -> void:
	if world.get_tree().has_meta("story_stay_in_school"):
		return
	var tree := world.get_tree()
	if tree.has_meta("chapter_corridor"):
		tree.remove_meta("chapter_corridor")
	tree.change_scene_to_file.call_deferred("res://scenes/dream_shore.tscn")

func close() -> void:
	if panel != null: panel.hide()
	panel_kind = ""
	if world != null and world.player.health > 0 and not world.paused_by_user and not world.map_panel.visible and not world.survival.finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func begin_night_one() -> void:
	bypass_for_test()
	world.player.global_position = Vector3(12, 0.05, 75.2)
	world.survival.begin_midnight()
	world.collect_master_key()
	world.notice_time = 0
	# The prologue's evidence was carried out of the school and stays in the journal.
	for i in range(world.journal.entries.size()):
		world.journal.record(i)

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
	stage = Stage.SURVIVE_NIGHT
	evidence["clip"] = true
	evidence["mirror"] = true
	evidence["photo"] = true
	clip.set_available(false)
	restroom.hand_mirror.set_available(false)
	lure_light.hide()
	crash_sound.stop()
	runner.restore_pose()

func tick_player(delta: float) -> void:
	if runner.active: runner.tick(delta)
	elif escape.locks_player(): escape.tick(delta)
	else: world.player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not world.simulation_active() or not world.survival.active: return
	stage_time += delta
	if stage == Stage.NOISE_UPSTAIRS and stage_time >= CRASH_DELAY and not restroom.broken:
		mirror_falls()
	elif stage == Stage.MIRROR_FOUND and stage_time >= MIRROR_TO_CALL:
		begin_guard()
	elif stage in [Stage.HIDE, Stage.STEALTH, Stage.PHOTO_EVIDENCE, Stage.ESCAPE_RUN]:
		var parts := {guard_part.Part.HIDE: Stage.HIDE, guard_part.Part.STEALTH: Stage.STEALTH, guard_part.Part.PHOTO: Stage.PHOTO_EVIDENCE,
			guard_part.Part.DUCK: Stage.ESCAPE_RUN, guard_part.Part.SEARCH: Stage.ESCAPE_RUN, guard_part.Part.SNEAK: Stage.ESCAPE_RUN}
		if parts.has(guard_part.part) and parts[guard_part.part] != stage:
			stage = parts[guard_part.part]
			stage_time = 0
	if stage == Stage.BASEMENT_DESCENT:
		# Down the service stairs in the dark; the tunnel's red lamps come up out of it.
		fear.fade = clampf(stage_time / (DESCENT_SECONDS * 0.6), 0, 1)
		if stage_time >= DESCENT_SECONDS:
			fear.fade = 0.0
			world.survival.begin_midnight()

func _process(delta: float) -> void:
	var paused: bool = not world.simulation_active()
	if subtitle_clock > 0.0 and not paused:
		subtitle_clock -= delta
		if subtitle_clock <= 0.0: subtitle_label.hide()
	crash_sound.stream_paused = paused
	if world.survival.finished: stage = Stage.COMPLETE

func _input(event: InputEvent) -> void:
	if panel_visible() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if restroom != null: restroom.stop_audio()
	if crash_sound != null:
		crash_sound.stream_paused = false
		crash_sound.stop()
		crash_sound.stream = null

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

func show_panel(kind: String, title: String, text: String) -> void:
	world.journal.close()
	world.map_panel.hide()
	world.player.cancel_chalk_charge()
	panel_kind = kind
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
