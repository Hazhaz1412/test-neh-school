extends Node3D

enum Phase { IDLE, INTRO, PREPARATION, NIGHT, DAWN }
signal midnight_started
signal dawn_reached
var world: Node3D
var active := false
var won := false
var finished := false
var phase: Phase = Phase.IDLE
var preparation_time := 0.0
var opening: Node3D
var run_time := 0.0
var hunt_remaining := 0.0
var bell_clock := 45.0
var fear_clock := 0.0
var fear_pressure := 0.0
var warning_time := 0.0
var warning_text := ""
var status_label: Label
var warning_label: Label
var end_panel: ColorRect
var bell: AudioStreamPlayer
var midnight_bell: AudioStreamPlayer
var end_text: Label
var breathing_audio: AudioStreamPlayer
var items: Array[Node3D] = []
var gate: Node3D

func setup(school: Node3D) -> void:
	world = school
	name = "SurvivalSystems"
	opening = preload("res://scripts/opening_cinematic.gd").new()
	opening.director = self
	add_child(opening)
	bell = AudioStreamPlayer.new()
	bell.stream = preload("res://assets/audio/school_bell.wav")
	bell.volume_db = -13
	add_child(bell)
	midnight_bell = AudioStreamPlayer.new()
	midnight_bell.stream = preload("res://assets/audio/midnight_bell.wav")
	midnight_bell.volume_db = -9
	add_child(midnight_bell)
	breathing_audio = world._loop_audio("PlayerBreathing", "res://assets/audio/player_breath.wav", -35)
	var catalog := [
		["battery", Vector3(-44.9, 0.15, -50.2)],
		["battery", Vector3(-6, 0.15, -40.5)],
		["battery", Vector3(17, 0.15, 7.8)],
		["battery", Vector3(-30, 0.15, 28)],
		["battery", Vector3(-21, 0.15, -55)],
		["medicine", Vector3(-46, 0.15, -52)],
		["medicine", Vector3(29.5, 0.15, -2)],
		["medicine", Vector3(21, 0.15, -31)],
		["chalk", Vector3(-43.8, 0.15, -51)],
		["chalk", Vector3(8, 4.05, 7.5)]]
	for entry in catalog:
		var item: Node3D = preload("res://scripts/survival_item.gd").new()
		item.world = world
		item.kind = entry[0]
		item.position = entry[1]
		item.name = "%s_%02d" % [entry[0], items.size()]
		add_child(item)
		items.append(item)
	gate = preload("res://scripts/survival_item.gd").new()
	gate.world = world
	gate.kind = "gate"
	gate.position = Vector3(0, 1.2, 77.72)
	gate.rotation.y = PI
	gate.name = "EscapeGate"
	add_child(gate)
	var ui: Control = world.get_node("HUD").get_child(0)
	status_label = world._label(ui, Vector2(30, 168), 14, Color(0.65, 0.8, 0.74))
	warning_label = world._label(ui, Vector2(30, 196), 14, Color(0.91, 0.57, 0.45))
	end_panel = ColorRect.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_panel.color = Color(0.015, 0.045, 0.04, 0.93)
	end_panel.hide()
	ui.add_child(end_panel)
	end_text = world._label(end_panel, Vector2(160, 230), 23, Color(0.72, 0.86, 0.77))
	end_text.size.x = 960
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.hide()
	warning_label.hide()

func start_run(with_opening := true) -> void:
	if active and not finished and world.player.health > 0:
		world.notify("Đêm sinh tồn đang chạy. R bắt đầu lại từ đầu.")
		return
	if world.test_cheats != null:
		world.test_cheats.reset_run()
	active = false
	won = false
	finished = false
	phase = Phase.IDLE
	world.paused_by_user = false
	world.map_panel.hide()
	end_panel.hide()
	world.death_panel.hide()
	if world.journal != null:
		world.journal.reset()
	world.player.reset_survival()
	if world.progression != null:
		world.progression.reset()
	world.has_master_key = false
	for door in world.get_node("Architecture").get_children():
		if door.has_method("request_toggle"):
			door.snap(false)
	for item in items:
		item.reset_item()
	for child in get_children():
		if child is CharacterBody3D or child.get("dropped") == true:
			child.queue_free()
	run_time = 0
	preparation_time = 0
	bell.stop()
	midnight_bell.stop()
	breathing_audio.stop()
	warning_time = 0
	world.normal_environment.sky.sky_material.set_shader_parameter("dawn_amount", 0.0)
	hunt_remaining = 0
	bell_clock = 45
	fear_pressure = 0
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if with_opening:
		phase = Phase.INTRO
		opening.start()
	else:
		complete_opening()

func complete_opening() -> void:
	phase = Phase.PREPARATION
	world.player.global_position = Vector3(12, 0.05, 75.2)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	world.player.camera.current = true
	world.player.enabled = true
	world.paused_by_user = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.get_node("HUD").show()
	world.notice_time = 0

func clock_text() -> String:
	var minutes: float = 1350.0 + (preparation_time + run_time) * 360.0 / world.night_duration_seconds
	if phase == Phase.DAWN:
		minutes = 360
	var time_minutes := posmod(int(floor(minutes)), 1440)
	return "%02d:%02d" % [int(time_minutes / 60.0), time_minutes % 60]

func begin_midnight() -> void:
	if not active or phase != Phase.PREPARATION or not world.progression.can_cross_midnight():
		return
	phase = Phase.NIGHT
	run_time = 0
	# Commits the gate transition, independently of the clock: the prologue runs into the
	# service tunnels under the school.
	opening.remove_companions()
	if not world.progression.briefing_complete:
		world.progression.begin_first_chase()
	midnight_started.emit()

func advance_clock(delta: float) -> void:
	if not active or not world.simulation_active():
		return
	if phase == Phase.PREPARATION:
		preparation_time += delta
	elif phase == Phase.NIGHT:
		run_time += delta
		if clock_reached_dawn() and world.progression.briefing_complete:
			_finish_dawn()

func clock_reached_dawn() -> bool:
	return (preparation_time + run_time) * 360.0 / world.night_duration_seconds >= 450.0

func _finish_dawn() -> void:
	world.journal.close()
	if world.progression != null:
		world.progression.close()
	phase = Phase.DAWN
	finished = true
	won = world.player.health > 0
	if world.team != null:
		won = world.team.standing() > 0
	world.normal_environment.sky.sky_material.set_shader_parameter("dawn_amount", 1.0)
	world.player.enabled = false
	world.player.velocity = Vector3.ZERO
	var survived := "06:00 · HOÀN THÀNH ĐÊM 1\nBạn đã trụ được tới sáng."
	if world.team != null:
		survived = "06:00 · HOÀN THÀNH ĐÊM 1\nTrời sáng, bác bảo vệ mở cổng. %d/%d người trong nhóm còn trụ được." % [world.team.remaining(), world.team.members.size()]
	end_text.text = (survived if won else "06:00 · ĐÊM 1 THẤT BẠI") + ("\n\nEnter · Sang sáng hôm sau · R · Chơi lại" if won else "\n\nR · Chơi lại")
	if world.test_cheats.used_this_run:
		end_text.text += "\nTEST · Có dùng cheat trong lượt này"
	end_panel.show()
	bell.stop()
	midnight_bell.stop()
	breathing_audio.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dawn_reached.emit()

# Night 1: everyone left is caught at the same moment.
func team_lost() -> void:
	if finished:
		return
	world.journal.close()
	if world.progression != null:
		world.progression.close()
	finished = true
	won = false
	world.player.velocity = Vector3.ZERO
	end_text.text = "ĐÊM 1 THẤT BẠI\nCả nhóm đều đã bị bác bảo vệ bắt.\n\nR · Chơi lại"
	end_panel.show()
	bell.stop()
	midnight_bell.stop()
	breathing_audio.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func win() -> void:
	if active and phase == Phase.NIGHT and clock_reached_dawn() and world.simulation_active():
		_finish_dawn()

func hearing_multiplier() -> float:
	return 1.35 if active and hunt_remaining > 0 else 1.0

func warn(message: String, duration: float) -> void:
	warning_text = message
	warning_time = duration

func trigger_hunt() -> void:
	if not active or finished or phase != Phase.NIGHT or world.progression.tutorial_active():
		return
	hunt_remaining = 12
	bell.play()
	world.notify("Chuông báo động · bác bảo vệ nghe xa hơn trong 12 giây. Cắt đường nhìn, đi nhẹ và tìm chỗ nấp.")

func _physics_process(delta: float) -> void:
	bell.stream_paused = not world.simulation_active()
	midnight_bell.stream_paused = not world.simulation_active()
	breathing_audio.stream_paused = not world.simulation_active()
	if not world.night_hunt():
		breathing_audio.stop()
	if not world.simulation_active():
		return
	warning_time = maxf(0, warning_time - delta)
	advance_clock(delta)
	if finished or not world.night_hunt() or active and phase != Phase.NIGHT:
		return
	if active and not world.progression.tutorial_active():
		hunt_remaining = maxf(0, hunt_remaining - delta)
		bell_clock -= delta
		if bell_clock <= 0:
			trigger_hunt()
			bell_clock = 55 if run_time < 180 else 38
	fear_clock -= delta
	if fear_clock <= 0:
		fear_clock = 0.25
		# Fear rises while the guard is close on your trail.
		fear_pressure = 12.0 * world.threat
	world.player.fear = clampf(world.player.fear + (fear_pressure - (7.0 if world.player.is_hidden() else 4.0)) * delta, 0, 100)
	world.player.tick_survival(delta, Input.is_physical_key_pressed(KEY_SPACE))
	if world.player.fear > 25 and not world.player.holding_breath:
		if not breathing_audio.playing:
			breathing_audio.play()
		breathing_audio.volume_db = -36 + world.player.fear * 0.19
		breathing_audio.pitch_scale = 1 + world.player.fear * 0.0025
	else:
		breathing_audio.stop()

func _process(_delta: float) -> void:
	status_label.visible = false
	status_label.text = "PIN %d%%   ·   HOẢNG LOẠN %d%%   ·   HƠI THỞ %d%%   ·   PHẤN %d" % [world.player.battery, world.player.fear, world.player.breath, world.player.chalk]
	warning_label.visible = false
	warning_label.text = warning_text if warning_time > 0 else "CHUÔNG BÁO ĐỘNG · %.0f giây · Bác bảo vệ đang lắng nghe" % hunt_remaining
