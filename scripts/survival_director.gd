extends Node3D

enum Phase { IDLE, INTRO, PREPARATION, NIGHT, DAWN }
signal midnight_started
signal dawn_reached(rescued: bool)
var world: Node3D
var active := false
var won := false
var finished := false
var phase: Phase = Phase.IDLE
var preparation_time := 0.0
var soul_rescued := false
var glimpse_on := false
var opening: Node3D
var run_time := 0.0
var hunt_remaining := 0.0
var bell_clock := 45.0
var fear_clock := 0.0
var fear_pressure := 0.0
var panic_damage_clock := 0.0
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
	end_text = world._label(end_panel, Vector2(230, 245), 25, Color(0.72, 0.86, 0.77))
	status_label.hide()
	warning_label.hide()
	world.master_key_collected.connect(_on_key)

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
	world.set_spirit_world(false)
	world.paused_by_user = false
	world.map_panel.hide()
	end_panel.hide()
	world.death_panel.hide()
	if world.soul_quest != null:
		world.soul_quest.reset()
	world.player.reset_survival()
	if world.progression != null:
		world.progression.reset()
	world.has_master_key = false
	world.master_key.collected = false
	world.master_key.show()
	world.master_key.get_node("Interaction").collision_layer = 16
	for door in world.get_node("Architecture").get_children():
		if door.has_method("request_toggle"):
			door.is_open = false
			door.slide = 0
			door.leaf.position.x = 0
	for item in items:
		item.reset_item()
	for child in get_children():
		if child is CharacterBody3D or child.get("dropped") == true:
			child.queue_free()
	run_time = 0
	preparation_time = 0
	soul_rescued = false
	glimpse_on = false
	bell.stop()
	midnight_bell.stop()
	breathing_audio.stop()
	warning_time = 0
	for environment in [world.normal_environment, world.cursed_environment]:
		environment.sky.sky_material.set_shader_parameter("dawn_amount", 0.0)
	hunt_remaining = 0
	bell_clock = 45
	panic_damage_clock = 0
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
	world.set_spirit_world(false, true)
	world.player.global_position = Vector3(12, 0.05, 75.2)
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	world.player.camera.current = true
	world.player.enabled = true
	world.paused_by_user = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.get_node("HUD").show()
	world.notify("23:30 · Tìm chìa tổng trong nhà kho · J")

func clock_text() -> String:
	var minutes := -30.0
	if phase == Phase.PREPARATION:
		minutes = -30 + 30 * preparation_time / world.preparation_duration_seconds
	elif phase == Phase.NIGHT:
		minutes = minf(360, 360 * run_time / world.night_duration_seconds)
	elif phase == Phase.DAWN:
		minutes = 360
	var time_minutes := posmod(int(floor(minutes)), 1440)
	return "%02d:%02d" % [int(time_minutes / 60.0), time_minutes % 60]

func begin_midnight() -> void:
	if not active or phase != Phase.PREPARATION:
		return
	phase = Phase.NIGHT
	preparation_time = world.preparation_duration_seconds
	run_time = 0
	glimpse_on = false
	# Finalize any brief visual glimpse, then spawn the night entities exactly once.
	world.set_spirit_world(false, true)
	world.set_spirit_world(true)
	opening.remove_companions()
	midnight_bell.play()
	warn("00:00 · CHUÔNG NỬA ĐÊM · Đồng đội đã biến mất. Sống sót tới 06:00.", 7)
	midnight_started.emit()

func mark_soul_rescued() -> bool:
	if not active or phase != Phase.NIGHT or finished or soul_rescued or world.soul_quest == null or not world.soul_quest.ready_for_rescue():
		return false
	soul_rescued = true
	return true

func advance_clock(delta: float) -> void:
	if not active or not world.simulation_active():
		return
	if phase == Phase.PREPARATION:
		preparation_time = minf(world.preparation_duration_seconds, preparation_time + delta)
		var progress: float = preparation_time / world.preparation_duration_seconds
		var glimpse := false
		for interval in [Vector2(0.20, 0.21), Vector2(0.46, 0.48), Vector2(0.71, 0.73), Vector2(0.88, 0.91)]:
			glimpse = glimpse or progress >= interval.x and progress < interval.y
		if glimpse_on != glimpse:
			glimpse_on = glimpse
			world.set_spirit_world(glimpse, true)
			if glimpse:
				warn("Đèn vừa tắt... cảnh vật có gì đó khác.", 2)
		if progress >= 1:
			begin_midnight()
	elif phase == Phase.NIGHT:
		run_time = minf(world.night_duration_seconds, run_time + delta)
		if run_time >= world.night_duration_seconds:
			_finish_dawn()

func _finish_dawn() -> void:
	world.soul_quest.close()
	if world.progression != null:
		world.progression.close()
	phase = Phase.DAWN
	finished = true
	won = soul_rescued and world.player.health > 0
	world.set_spirit_world(false, true)
	world.normal_environment.sky.sky_material.set_shader_parameter("dawn_amount", 1.0)
	world.player.enabled = false
	world.player.velocity = Vector3.ZERO
	end_text.text = ("06:00 · AN ĐÃ ĐƯỢC GIẢI THOÁT" if won else "06:00 · AN VẪN MẮC KẸT") + "\n\nR · Chơi lại"
	if world.test_cheats.used_this_run:
		end_text.text += "\nTEST · Có dùng cheat trong lượt này"
	end_panel.show()
	bell.stop()
	midnight_bell.stop()
	breathing_audio.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dawn_reached.emit(soul_rescued)

func win() -> void:
	if active and phase == Phase.NIGHT and run_time >= world.night_duration_seconds and soul_rescued and world.simulation_active():
		_finish_dawn()

func hearing_multiplier() -> float:
	return 1.35 if active and hunt_remaining > 0 else 1.0

func warn(message: String, duration: float) -> void:
	warning_text = message
	warning_time = duration

func trigger_hunt() -> void:
	if not active or finished or phase != Phase.NIGHT:
		return
	hunt_remaining = 12
	bell.play()
	world.notify("Chuông truy đuổi · chúng nghe xa hơn trong 12 giây. Cắt đường nhìn, đi nhẹ và tìm chỗ nấp.")

func _on_key() -> void:
	if active:
		trigger_hunt()
		warn("ĐÃ LẤY CHÌA · Các phòng đã mở được · Sống tới 06:00 và tìm linh hồn học sinh", 8)

func _physics_process(delta: float) -> void:
	bell.stream_paused = not world.simulation_active()
	midnight_bell.stream_paused = not world.simulation_active()
	breathing_audio.stream_paused = not world.simulation_active()
	if not world.spirit_enabled:
		breathing_audio.stop()
	if not world.simulation_active():
		return
	warning_time = maxf(0, warning_time - delta)
	advance_clock(delta)
	if finished or not world.spirit_enabled or active and phase != Phase.NIGHT:
		return
	if active:
		hunt_remaining = maxf(0, hunt_remaining - delta)
		bell_clock -= delta
		if bell_clock <= 0:
			trigger_hunt()
			bell_clock = 55 if run_time < 180 else 38
	fear_clock -= delta
	if world.is_soul_sanctuary(world.player.global_position):
		fear_pressure = 0
		panic_damage_clock = 0
	if fear_clock <= 0:
		fear_clock = 0.25
		fear_pressure = 0
		for ghost in world.enemies:
			var distance: float = ghost.global_position.distance_to(world.player.global_position)
			if not world.is_soul_sanctuary(world.player.global_position) and ghost.active and distance < 12 and (ghost.has_line_of_sight() or ghost.suspected_spot == world.player.hidden_spot and world.player.is_hidden()):
				fear_pressure = maxf(fear_pressure, 12 * (1 - distance / 12))
	world.player.fear = clampf(world.player.fear + (fear_pressure - (7.0 if world.player.is_hidden() else 4.0)) * delta, 0, 100)
	world.player.tick_survival(delta, Input.is_physical_key_pressed(KEY_SPACE))
	if world.player.fear > 25 and not world.player.holding_breath:
		if not breathing_audio.playing:
			breathing_audio.play()
		breathing_audio.volume_db = -36 + world.player.fear * 0.19
		breathing_audio.pitch_scale = 1 + world.player.fear * 0.0025
	else:
		breathing_audio.stop()
	if active and world.player.fear >= 98 and not world.is_soul_sanctuary(world.player.global_position):
		panic_damage_clock += delta
		if panic_damage_clock > 1:
			panic_damage_clock = 0
			world.player.take_damage(5)
	else:
		panic_damage_clock = 0

func _process(_delta: float) -> void:
	status_label.visible = false
	status_label.text = "PIN %d%%   ·   HOẢNG LOẠN %d%%   ·   HƠI THỞ %d%%   ·   PHẤN %d" % [world.player.battery, world.player.fear, world.player.breath, world.player.chalk]
	warning_label.visible = false
	warning_label.text = warning_text if warning_time > 0 else "CHUÔNG TRUY ĐUỔI · %.0f giây · Chúng đang lắng nghe" % hunt_remaining
