extends Node3D

@export_group("Spirit realm · visuals")
@export_range(0.005, 0.06, 0.001) var spirit_fog_density := 0.014
@export var spirit_fog_color := Color(0.055, 0.065, 0.085)
@export_range(0.05, 0.8, 0.01) var spirit_ambient_energy := 0.36
@export_group("Spirit realm · bullies")
@export_range(0, 12, 1) var enemy_count := 3
@export_range(0, 5, 1) var special_enemy_count := 3
@export_group("Survival · encounters")
@export var smart_spawn_enabled := true
@export_range(1, 6, 1) var max_active_ghosts := 3
@export_range(8.0, 60.0, 1.0) var encounter_interval_seconds := 22.0
var encounters: Node
@export_range(5.0, 35.0, 0.5) var ghost_detection_range := 18.0
@export_range(1.0, 6.0, 0.1) var ghost_chase_speed := 4.65
@export_range(4.0, 9.0, 0.1) var ghost_rush_speed := 6.4
@export_range(1.0, 40.0, 1.0) var ghost_damage := 14.0
@export_group("Night · opening and clock")
@export var play_opening_on_launch := true
@export_range(60.0, 3600.0, 30.0) var night_duration_seconds := 720.0
@export_range(10.0, 300.0, 5.0) var preparation_duration_seconds := 60.0
@export_group("Survival · camera")
@export_range(1.0, 20.0, 0.5) var camera_banish_seconds := 6.0
@export_range(0.6, 5.0, 0.1) var camera_shot_cooldown := 1.5
var camera_flash: Node
@export_group("Performance")
@export_enum("Nhẹ", "Cân bằng", "Cao") var quality_level := 1
var light_budget := 12
var local_lights: Array[OmniLight3D] = []
var flicker_lights: Array[OmniLight3D] = []
var light_clock := 0.0
var quality_label: Label
var performance_label: Label
var show_performance := false
var overlay_rect: ColorRect
var paused_by_user := false
var realm_version := 0
var spirit_enabled := false
var enemies: Array[CharacterBody3D] = []
var enemy_root: Node3D
var spirit_decor: Node3D
var normal_environment: Environment
var cursed_environment: Environment
var light_defaults := {}
var realm_mix := 0.0
var hit_flash := 0.0
var overlay_mat: ShaderMaterial
var health_label: Label
var realm_label: Label
var death_panel: ColorRect
var interaction_label: Label
var objective_label: Label
var notice_label: Label
var notice_time := 0.0
var has_master_key := false
var master_key: Node3D
var realm_scenery: Node3D
var realm_audio: AudioStreamPlayer
var threat_audio: AudioStreamPlayer
var threat := 0.0
var alarm := 0.0
var startle_cooldown := 0.0
var realm_entry_position := Vector3.ZERO
signal master_key_collected
var elapsed := 0.0
var title: Label
var location_label: Label
var stamina_bar: ProgressBar
var map_panel: Control
@export var comfort_ai_url := "http://127.0.0.1:8765/comfort"
var progression: Node3D
var soul_quest: Node3D
var soundscape: Node
var help_panel: PanelContainer
var survival: Node3D
var test_cheats: Node
var cheat_ai_button: Button
var cheat_finish_button: Button
var death_text: Label
@onready var player: CharacterBody3D = $Player

func _ready() -> void:
	_build_ui()
	_prepare_spirit_world()
	realm_scenery = preload("res://scripts/spirit_scenery.gd").new()
	add_child(realm_scenery)
	realm_scenery.setup(self)
	realm_audio = _loop_audio("SpiritAmbience", "res://assets/audio/spirit_ambience.wav", -17)
	threat_audio = _loop_audio("ThreatHeartbeat", "res://assets/audio/threat_heartbeat.wav", -80)
	master_key = preload("res://scripts/master_key.gd").new()
	master_key.world = self
	master_key.position = Vector3(-45, 0.90, -56)
	add_child(master_key)
	survival = preload("res://scripts/survival_director.gd").new()
	add_child(survival)
	survival.setup(self)
	soundscape = preload("res://scripts/soundscape.gd").new()
	add_child(soundscape)
	soundscape.setup(self)
	encounters = preload("res://scripts/encounter_director.gd").new()
	encounters.name = "Encounters"
	encounters.world = self
	add_child(encounters)
	camera_flash = preload("res://scripts/camera_flash.gd").new()
	camera_flash.name = "CameraFlash"
	camera_flash.world = self
	add_child(camera_flash)
	soul_quest = preload("res://scripts/soul_quest.gd").new()
	survival.add_child(soul_quest)
	soul_quest.setup(self)
	progression = preload("res://scripts/school_progression.gd").new()
	survival.add_child(progression)
	progression.setup(self)
	test_cheats = preload("res://scripts/test_cheats.gd").new()
	test_cheats.name = "TestCheats"
	test_cheats.world = self
	add_child(test_cheats)
	var ai_service := preload("res://scripts/soul_ai_service.gd").new()
	ai_service.name = "SoulAIService"
	add_child(ai_service)
	var compact := preload("res://scripts/compact_hud.gd").new()
	compact.world = self
	compact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_node("HUD").get_child(0).add_child(compact)
	for sign in find_children("HideSign", "Label3D", true, false):
		sign.hide()
	for child in $Atmosphere.get_children():
		if child is OmniLight3D:
			local_lights.append(child)
			if child.has_meta("flicker"):
				flicker_lights.append(child)
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		quality_level = clampi(int(settings.get_value("graphics", "quality", quality_level)), 0, 2)
	set_quality(quality_level, false)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)
	if bool(get_tree().get_meta("next_survival_run", false)):
		get_tree().remove_meta("next_survival_run")
		survival.call_deferred("start_run")
	elif play_opening_on_launch and not OS.get_cmdline_args().has("--script"):
		# Script tools explicitly control their camera/mode; F5 plays the story opening.
		survival.call_deferred("start_run")

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var strip := ColorRect.new()
	strip.color = Color(0.025, 0.04, 0.05, 0.85)
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_bottom = 86
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(strip)
	strip.hide()
	title = _label(ui, Vector2(30, 18), 23, Color(0.77, 0.88, 0.86))
	location_label = _label(ui, Vector2(30, 52), 16, Color(0.61, 0.70, 0.71))
	var controls := _label(ui, Vector2(30, 672), 15, Color(0.65, 0.73, 0.73))
	controls.add_theme_font_size_override("font_size", 13)
	controls.text = "WASD đi   SHIFT chạy   CTRL đi nhẹ   E tương tác / nấp / ra   F đèn pin   SPACE nín thở khi nấp   G ném phấn\nN đêm sinh tồn   B thử linh hồn   M sơ đồ   F6 chất lượng   F7 FPS   ESC dừng   R chơi lại"
	stamina_bar = ProgressBar.new()
	stamina_bar.position = Vector2(1050, 36)
	stamina_bar.size = Vector2(195, 8)
	stamina_bar.show_percentage = false
	stamina_bar.max_value = player.MAX_STAMINA
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.15, 0.22, 0.22)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.50, 0.73, 0.65)
	stamina_bar.add_theme_stylebox_override("background", background)
	stamina_bar.add_theme_stylebox_override("fill", fill)
	ui.add_child(stamina_bar)
	health_label = _label(ui, Vector2(1060, 66), 14, Color(0.79, 0.78, 0.69))
	quality_label = _label(ui, Vector2(1040, 102), 12, Color(0.65, 0.73, 0.73))
	performance_label = _label(ui, Vector2(1040, 124), 12, Color(0.65, 0.73, 0.73))
	performance_label.hide()
	realm_label = _label(ui, Vector2(30, 104), 15, Color(0.77, 0.67, 0.65))
	interaction_label = _label(ui, Vector2(500, 608), 19, Color(0.88, 0.82, 0.65))
	interaction_label.position.x = 380
	interaction_label.size.x = 520
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label = _label(ui, Vector2(30, 134), 15, Color(0.87, 0.78, 0.53))
	notice_label = _label(ui, Vector2(30, 641), 15, Color(0.94, 0.74, 0.51))
	var crosshair := _label(ui, Vector2(635, 348), 18, Color(0.65, 0.71, 0.69, 0.7))
	crosshair.text = "·"
	death_panel = ColorRect.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.color = Color(0.025, 0.005, 0.015, 0.88)
	death_panel.hide()
	ui.add_child(death_panel)
	death_text = _label(death_panel, Vector2(330, 270), 26, Color(0.85, 0.68, 0.65))
	death_text.text = "OÁN KHÍ ĐÃ NUỐT CHỬNG BẠN\n\nB  trở về thế giới thường     ·     R  chơi lại"
	for legacy in [title, location_label, controls, stamina_bar, health_label, quality_label, realm_label, objective_label]:
		legacy.hide()
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(390, 130)
	help_panel.size = Vector2(500, 340)
	ui.add_child(help_panel)
	var help_text := Label.new()
	help_text.text = "TẠM DỪNG · Esc tiếp tục\n\nWASD đi · Shift chạy · Ctrl đi nhẹ\nE nhặt / mở / nấp · Space nín thở / QTE né\n1–6 / cuộn chuột chọn đồ · Chuột trái dùng\nQ thả đồ · F đèn pin · Giữ/thả G ném phấn\nPhấn tích 1,5 giây: tầm xa ×5 · Pin sạc 50%\nMáy ảnh: 20% pin / ảnh · Ma tan 6 giây\nJ ký ức · M sơ đồ · F6 chất lượng · F7 FPS\nR chơi lại · N mở đầu\n\nTìm chìa tổng, 4 ký ức và cứu An.\nSống tới 06:00 · Một đêm dài 12 phút."
	help_text.add_theme_font_size_override("font_size", 18)
	var help_stack := VBoxContainer.new()
	help_panel.add_child(help_stack)
	help_stack.add_child(help_text)
	var cheat_hint := Label.new()
	cheat_hint.text = "H + P · TEST: bất tử, nhanh ×3, đủ ký ức; An vẫn chờ"
	cheat_hint.add_theme_font_size_override("font_size", 14)
	help_stack.add_child(cheat_hint)
	cheat_ai_button = Button.new()
	cheat_ai_button.text = "TEST · Đưa tới An để thử chấm AI"
	cheat_ai_button.pressed.connect(func(): test_cheats.prepare_ai_test())
	help_stack.add_child(cheat_ai_button)
	cheat_finish_button = Button.new()
	cheat_finish_button.text = "TEST · Hoàn thành đêm, tới 06:00"
	cheat_finish_button.pressed.connect(func(): test_cheats.finish_night())
	help_stack.add_child(cheat_finish_button)
	help_panel.hide()
	map_panel = Control.new()
	map_panel.set_script(preload("res://scripts/campus_map.gd"))
	map_panel.size = Vector2(680, 590)
	map_panel.position = Vector2(300, 96)
	map_panel.set("player", player)
	map_panel.hide()
	ui.add_child(map_panel)

func _label(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if survival.opening.playing or soul_quest != null and soul_quest.panel_visible() or progression != null and progression.panel_visible():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			set_spirit_world(not spirit_enabled)
		if event.keycode == KEY_N:
			survival.start_run()
		if event.keycode == KEY_F6:
			set_quality((quality_level + 1) % 3)
		if event.keycode == KEY_F7:
			show_performance = not show_performance
			performance_label.visible = show_performance
		if event.keycode == KEY_R:
			get_tree().set_meta("next_survival_run", survival.active)
			get_tree().reload_current_scene()
		if survival.finished:
			return
		if event.keycode == KEY_M and not player.combat.busy():
			paused_by_user = false
			map_panel.visible = not map_panel.visible
			player.enabled = (not map_panel.visible or survival.active) and player.health > 0 and not survival.won
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_panel.visible else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_ESCAPE and not map_panel.visible:
			paused_by_user = not paused_by_user
		if event.keycode == KEY_ESCAPE and map_panel.visible:
			map_panel.hide()
			paused_by_user = false
			player.enabled = player.health > 0
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if simulation_active():
		elapsed += delta
		startle_cooldown = maxf(0, startle_cooldown - delta)
	var nearest := 16.0
	if spirit_enabled and simulation_active() and not is_soul_sanctuary(player.global_position):
		for ghost in enemies:
			if ghost.active and (ghost.state == 2 or ghost.state == 3 or ghost.state == 4 or (player.is_hidden() and ghost.state == 1) or (ghost.archetype == "listener" and ghost.state == 1 and ghost.memory > 0)):
				nearest = minf(nearest, player.global_position.distance_to(ghost.global_position))
	threat = move_toward(threat, 1.0 - nearest / 16.0, delta * 1.2)
	threat_audio.volume_db = lerpf(-60, -9, threat)
	threat_audio.pitch_scale = 0.95 + threat * 0.55
	if player.combat.adrenaline_remaining > 0:
		threat_audio.volume_db = -60
	realm_mix = move_toward(realm_mix, 1.0 if spirit_enabled else 0.0, delta * 2.5)
	hit_flash = maxf(0, hit_flash - delta * 1.8)
	overlay_mat.set_shader_parameter("strength", realm_mix)
	overlay_mat.set_shader_parameter("hit", hit_flash)
	overlay_mat.set_shader_parameter("danger", threat)
	overlay_mat.set_shader_parameter("panic", player.fear / 100)
	overlay_mat.set_shader_parameter("adrenaline", minf(1, player.combat.adrenaline_remaining / 1.5))
	alarm = maxf(0, alarm - delta * 2)
	overlay_mat.set_shader_parameter("alarm", alarm)
	overlay_mat.set_shader_parameter("photo_flash", camera_flash.intensity)
	overlay_rect.visible = realm_mix > 0.001 or hit_flash > 0.001 or alarm > 0.001 or camera_flash.intensity > 0
	light_clock -= delta
	if light_clock <= 0.0:
		light_clock = 0.35
		_update_light_budget()
	if show_performance:
		performance_label.text = "%d FPS\n%d lượt vẽ" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	health_label.text = "SINH LỰC  %d" % int(player.health)
	realm_label.text = ("%s · ĐÊM 01 · %s" % [survival.clock_text(), "CHUẨN BỊ TRƯỚC NỬA ĐÊM" if survival.phase == survival.Phase.PREPARATION else "SỐNG SÓT ĐẾN 06:00"]) if survival.active else ("B / THẾ GIỚI LINH HỒN · %d THỰC THỂ · N chơi đêm 01" % enemies.size() if spirit_enabled else "N / XEM MỞ ĐẦU ĐÊM 01    ·    B / Thử thế giới linh hồn")
	stamina_bar.value = player.stamina
	var target: Node3D = player.get_interaction_target() if simulation_active() else null
	interaction_label.text = ("ĐANG NÍN THỞ · Thả SPACE để hồi hơi · E ra" if player.holding_breath else "ĐANG NẤP · SPACE nín thở · E ra ngoài") if player.is_hidden() else (target.interaction_text() if target != null else "")
	objective_label.text = "ĐÃ CÓ CHÌA KHÓA TỔNG · E mở các cửa phòng" if has_master_key else "01 / TÌM CHÌA KHÓA TỔNG · Nhà kho phía Tây khu B · M xem đường"
	if survival.active and has_master_key:
		objective_label.text = "ĐÊM 01 / Sống sót đến 06:00 · Giải cứu linh hồn học sinh" if not survival.soul_rescued else "ĐÃ GIẢI CỨU LINH HỒN · Giữ an toàn tới 06:00"
	notice_time = maxf(0, notice_time - delta)
	notice_label.visible = notice_time > 0 and not soul_quest.panel_visible()
	interaction_label.visible = not soul_quest.panel_visible() and not map_panel.visible
	help_panel.visible = paused_by_user and not survival.opening.playing
	cheat_ai_button.visible = test_cheats.enabled and not survival.finished
	cheat_finish_button.visible = test_cheats.enabled and not survival.finished
	if player.is_hidden():
		interaction_label.text = "E · Ra ngoài"
	elif target != null and target.has_method("request_toggle"):
		interaction_label.text = "E · Cửa khóa" if target.is_locked() else ("E · Đóng cửa" if target.is_open else "E · Mở cửa")
	elif target != null and target.has_method("hide_position"):
		interaction_label.text = "E · Nấp"
	for light in flicker_lights:
		if light.visible:
			light.light_energy = (0.18 if spirit_enabled else 0.40) * (0.70 + 0.30 * sin(elapsed * (19.0 if spirit_enabled else 7.0) + light.position.z))

func set_quality(level: int, persist := true) -> void:
	quality_level = clampi(level, 0, 2)
	light_budget = [8, 12, 24][quality_level]
	get_viewport().scaling_3d_scale = [0.75, 1.0, 1.0][quality_level]
	get_viewport().positional_shadow_atlas_size = [0, 1024, 2048][quality_level]
	player.flashlight.shadow_enabled = quality_level > 0
	$Atmosphere/Moonlight.shadow_enabled = quality_level > 0
	$Atmosphere/Moonlight.directional_shadow_max_distance = [40.0, 65.0, 110.0][quality_level]
	quality_label.text = "F6 / " + ["NHẸ", "CÂN BẰNG", "CAO"][quality_level]
	_update_light_budget()
	if persist:
		var settings := ConfigFile.new()
		settings.set_value("graphics", "quality", quality_level)
		settings.save("user://settings.cfg")

func _update_light_budget() -> void:
	var position_seen := player.global_position
	local_lights.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(position_seen) < b.global_position.distance_squared_to(position_seen))
	for index in range(local_lights.size()):
		local_lights[index].visible = index < light_budget

func simulation_active() -> bool:
	return player.enabled and player.health > 0 and (not map_panel.visible or survival != null and survival.active) and not paused_by_user and (survival == null or not survival.opening.playing and not survival.finished)

func is_soul_sanctuary(feet: Vector3) -> bool:
	# The three wings of A's roof; do not include the open courtyard below.
	return feet.y >= 11.35 and absf(feet.x) <= 38.5 and feet.z >= -12.5 and feet.z <= 56.2 and (feet.z <= 9.2 or absf(feet.x) >= 21.7)

func emit_noise(position_heard: Vector3, radius: float, source: String) -> void:
	if not simulation_active() or not spirit_enabled or is_soul_sanctuary(position_heard):
		return
	for ghost in enemies:
		if is_instance_valid(ghost):
			ghost.hear_noise(position_heard, radius, source)

func notify(message: String) -> void:
	notice_label.text = message.left(85)
	notice_time = 2.5

func on_ghost_spotted(ghost: CharacterBody3D) -> void:
	if startle_cooldown > 0 or ghost.global_position.distance_to(player.global_position) > 18:
		return
	startle_cooldown = 2.5
	alarm = 0.7
	player.startle = 0.65

func collect_master_key() -> void:
	if has_master_key:
		return
	has_master_key = true
	soundscape.cue("pickup")
	notify("Chìa khóa tổng · J xem manh mối")
	master_key_collected.emit()

func _loop_audio(label: String, path: String, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = label
	var stream: AudioStreamWAV = load(path).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	sound.stream = stream
	sound.volume_db = volume
	add_child(sound)
	return sound

func _prepare_spirit_world() -> void:
	normal_environment = $Atmosphere/MoonlitEnvironment.environment.duplicate(true)
	normal_environment.sky.sky_material.set_shader_parameter("spirit_amount", 0.0)
	$Atmosphere/MoonlitEnvironment.environment = normal_environment
	cursed_environment = normal_environment.duplicate(true)
	cursed_environment.fog_density = spirit_fog_density
	cursed_environment.fog_light_color = spirit_fog_color
	cursed_environment.ambient_light_color = Color(0.42, 0.46, 0.55)
	cursed_environment.ambient_light_energy = spirit_ambient_energy
	cursed_environment.sky.sky_material.set_shader_parameter("spirit_amount", 1.0)
	for light in $Atmosphere.get_children():
		if light is Light3D:
			light_defaults[light] = [light.light_color, light.light_energy]
	enemy_root = Node3D.new()
	enemy_root.name = "SpiritBullies"
	add_child(enemy_root)
	var layer := CanvasLayer.new()
	layer.name = "SpiritOverlay"
	layer.layer = 5
	add_child(layer)
	var overlay := ColorRect.new()
	overlay_rect = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = preload("res://assets/materials/spirit_overlay.gdshader")
	overlay.material = overlay_mat
	layer.add_child(overlay)

func set_spirit_world(enabled: bool, glimpse := false) -> void:
	if survival != null and survival.active and not glimpse:
		if survival.opening.playing or survival.phase == survival.Phase.PREPARATION or not enabled and not survival.finished:
			notify("Thế giới đang biến đổi · B chỉ dùng ngoài đêm 01. R chơi lại.")
			return
	if spirit_enabled == enabled:
		return
	if encounters != null:
		encounters.reset()
	if player.combat != null:
		player.combat.reset()
	if camera_flash != null:
		camera_flash.clear_light()
	realm_version += 1
	if enabled:
		realm_entry_position = player.position
	spirit_enabled = enabled
	death_panel.hide()
	if survival == null or not survival.active:
		player.recover()
	player.enabled = (not map_panel.visible or survival != null and survival.active) and not (survival != null and (survival.finished or survival.opening.playing)) and player.health > 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_panel.visible or paused_by_user or survival != null and survival.opening.playing else Input.MOUSE_MODE_CAPTURED
	hit_flash = 0.0
	if enabled:
		cursed_environment.fog_density = spirit_fog_density
		cursed_environment.fog_light_color = spirit_fog_color
		cursed_environment.ambient_light_energy = spirit_ambient_energy
	$Atmosphere/MoonlitEnvironment.environment = cursed_environment if enabled else normal_environment
	realm_scenery.set_enabled(enabled)
	if enabled:
		realm_audio.play()
		threat_audio.play()
	else:
		realm_audio.stop()
		threat_audio.stop()
		threat = 0.0
		alarm = 0.0
		player.startle = 0.0
		_clear_restored_furniture(realm_version)
	for light in light_defaults:
		var original: Array = light_defaults[light]
		light.light_color = Color(0.65, 0.16, 0.10) if enabled and light is OmniLight3D else (Color(0.52, 0.62, 0.70) if enabled else original[0])
		light.light_energy = original[1] * (0.60 if enabled else 1.0)
	for ghost in enemies:
		if is_instance_valid(ghost):
			ghost.active = false
			ghost.collision_layer = 0
			ghost.collision_mask = 0
			ghost.hide()
			ghost.queue_free()
	enemies.clear()
	if is_instance_valid(spirit_decor):
		spirit_decor.queue_free()
	if enabled and not glimpse:
		_spawn_bullies(realm_version)
		_spawn_resentment()

func _clear_restored_furniture(version: int) -> void:
	# Shape transforms synchronize with physics after the realm changes.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if version != realm_version or spirit_enabled:
		return
	if player.is_hidden():
		return # Authored covers retain the same safe interior in both realms.
	var capsule: CapsuleShape3D = player.get_node("Collision").shape.duplicate()
	capsule.radius -= 0.015
	capsule.height -= 0.06
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 5
	query.exclude = [player.get_rid()]
	query.transform = player.get_node("Collision").global_transform
	var space := get_world_3d().direct_space_state
	if space.intersect_shape(query, 1).is_empty():
		return
	var initial := player.position
	var nav_map: RID = get_world_3d().navigation_map
	for radius in [0.55, 0.85, 1.2, 1.8, 2.5, 3.5]:
		for i in range(16):
			var candidate := NavigationServer3D.map_get_closest_point(nav_map, initial + Vector3(cos(i * TAU / 16) * radius, 0, sin(i * TAU / 16) * radius))
			if absf(candidate.y - initial.y) > 0.65:
				continue
			candidate.y = initial.y
			query.transform.origin = candidate + Vector3(0, 0.9, 0)
			var ray := PhysicsRayQueryParameters3D.create(initial + Vector3(0, 1.62, 0), candidate + Vector3(0, 1.62, 0), 5)
			ray.exclude = [player.get_rid()]
			if space.intersect_shape(query, 1).is_empty() and space.intersect_ray(ray).is_empty():
				player.position = candidate
				player.velocity = Vector3.ZERO
				return
	query.transform.origin = realm_entry_position + Vector3(0, 0.9, 0)
	if space.intersect_shape(query, 1).is_empty():
		player.position = realm_entry_position
		player.velocity = Vector3.ZERO

func _spawn_bullies(version: int) -> void:
	# Navigation regions synchronize asynchronously after the scene loads.
	# Never snap early spawns to an empty map's fallback point (0, 0, 0).
	var nav_map: RID = get_world_3d().navigation_map
	var ready := false
	for i in range(120):
		if not spirit_enabled or version != realm_version:
			return
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			var anchor := Vector3(0, 0, 64)
			if NavigationServer3D.map_get_closest_point(nav_map, anchor).distance_to(anchor) < 2.0:
				ready = true
				break
		await get_tree().physics_frame
	if not ready or not spirit_enabled or version != realm_version:
		return
	# A small pair and lone students spread over floors, rather than a crowd at entry.
	_spawn_squad(0, Vector3(23.5, 0, 36), [Vector3(23.5, 0, 48), Vector3(23.5, 0, 14)], mini(2, enemy_count))
	for i in range(maxi(0, enemy_count - 2)):
		var upper := 3.9 if i % 2 == 0 else 7.8
		_spawn_squad(-1, Vector3(-18, upper, -40.5), [Vector3(-18, upper, -40.5), Vector3(18, upper, 7.5)], 1)
	_spawn_specials(nav_map)
	encounters.prepare()

func _spawn_specials(nav_map: RID) -> void:
	var catalog := [
		[0, Vector3(23.5, 0, 42), [Vector3(23.5, 0, 15), Vector3(23.5, 0, 50)]],
		[0, Vector3(-12, 0, -40.5), [Vector3(-25, 0, -40.5), Vector3(25, 0, -40.5)]],
		[1, Vector3(17, 0, 7.5), [Vector3(18, 0, 7.5), Vector3(-18, 0, 7.5)]],
		[1, Vector3(16, 3.9, -40.5), [Vector3(24, 3.9, -40.5), Vector3(-12, 3.9, -40.5)]],
		[2, Vector3(26, 0, -40.5), [Vector3(26, 0, -40.5), Vector3(1.5, 0, -32), Vector3(1.5, 0, -10)]]]
	# Keep one of each specialized threat with the reduced default count.
	if special_enemy_count <= 3:
		catalog = [catalog[0], catalog[2], catalog[4]]
	for i in range(special_enemy_count):
		var entity: CharacterBody3D = preload("res://scripts/school_entity.gd").new()
		entity.name = "Entity_%02d" % i
		entity.kind = catalog[i][0]
		entity.world = self
		entity.player = player
		entity.patrol_route.assign(catalog[i][2])
		var start: Vector3 = catalog[i][1]
		if start.distance_to(player.position) < 10:
			for checkpoint in entity.patrol_route:
				if checkpoint.distance_to(player.position) > start.distance_to(player.position):
					start = checkpoint
		entity.position = NavigationServer3D.map_get_closest_point(nav_map, start) + Vector3(0, 0.05, 0)
		entity.patrol_route = campus_patrol_route(i + 3)
		enemy_root.add_child(entity)
		enemies.append(entity)

func _spawn_squad(group: int, spawn: Vector3, route: Array[Vector3], count: int) -> void:
	var nav_map: RID = get_world_3d().navigation_map
	for i in range(count):
		var ghost: CharacterBody3D = preload("res://scripts/bully_ghost.gd").new()
		ghost.name = "Bully_%02d" % enemies.size()
		ghost.world = self
		ghost.player = player
		ghost.squad_id = group
		ghost.patrol_route = route
		ghost.formation_offset = Vector3((i - (count - 1) * 0.5) * 0.85, 0, 0)
		ghost.detection_range = ghost_detection_range
		ghost.chase_speed = ghost_chase_speed
		ghost.rush_speed = ghost_rush_speed
		ghost.damage = ghost_damage
		var start: Vector3 = spawn + ghost.formation_offset + Vector3(0, 0, i * 0.4)
		if start.distance_to(player.position) < 10.0:
			var farthest := start.distance_to(player.position)
			for checkpoint in route:
				var candidate: Vector3 = checkpoint + ghost.formation_offset
				if candidate.distance_to(player.position) > farthest:
					farthest = candidate.distance_to(player.position)
					start = candidate
		if NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			start = NavigationServer3D.map_get_closest_point(nav_map, start)
		ghost.position = start + Vector3(0, 0.05, 0)
		ghost.patrol_route = campus_patrol_route(group if group >= 0 else enemies.size())
		enemy_root.add_child(ghost)
		enemies.append(ghost)
		ghost.look_at(Vector3(player.position.x, ghost.position.y, player.position.z))

func campus_patrol_route(variant: int) -> Array[Vector3]:
	# Shared circulation rather than room entrances or a timed two-point shuttle.
	# Every circuit covers A, B, the service yard and both upper floors; A's roof
	# remains the sanctuary. Different directions keep everyone from camping one door.
	var route: Array[Vector3] = [
		Vector3(8, 0, 48), Vector3(23.5, 0, 48), Vector3(23.5, 0, 14),
		Vector3(12, 0, 7.5), Vector3(1.5, 0, -18), Vector3(18, 0, -40.5),
		Vector3(-18, 0, -40.5), Vector3(-37, 0, -40.5), Vector3(-45, 0, -44),
		Vector3(1.5, 0, -10), Vector3(-18, 0, 7.5), Vector3(-23.5, 0, 48),
		Vector3(-23.5, 3.9, 14), Vector3(12, 3.9, 7.5),
		Vector3(18, 3.9, -40.5), Vector3(-18, 3.9, -40.5), Vector3(-18, 3.9, 7.5),
		Vector3(-23.5, 7.8, 14), Vector3(12, 7.8, 7.5),
		Vector3(18, 7.8, -40.5), Vector3(-18, 7.8, -40.5),
		Vector3(18, 7.8, 7.5), Vector3(23.5, 7.8, 48), Vector3(-23.5, 0, 14)]
	if posmod(variant, 2) == 1:
		route.reverse()
	return route

func alert_squad(group: int, position_seen: Vector3, source: CharacterBody3D) -> void:
	if group < 0:
		return
	for ghost in enemies:
		if is_instance_valid(ghost) and ghost != source and ghost.squad_id == group and ghost.position.distance_to(source.position) < 14.0:
			ghost.alert(position_seen)

func _spawn_resentment() -> void:
	spirit_decor = Node3D.new()
	spirit_decor.name = "Resentment"
	add_child(spirit_decor)
	for pos in [Vector3(0, 0.6, 32), Vector3(-23.5, 1.3, 24), Vector3(23.5, 5.2, 36), Vector3(0, 9.1, 8)]:
		var ash := CPUParticles3D.new()
		ash.position = pos
		ash.amount = 45
		ash.lifetime = 7.0
		ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ash.emission_box_extents = Vector3(8, 0.7, 8)
		ash.direction = Vector3.UP
		ash.spread = 45
		ash.initial_velocity_min = 0.15
		ash.initial_velocity_max = 0.40
		ash.gravity = Vector3(0, 0.05, 0)
		var mesh := SphereMesh.new()
		mesh.radius = 0.027
		mesh.height = 0.054
		mesh.radial_segments = 6
		mesh.rings = 3
		ash.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.1, 0.18)
		mat.emission_enabled = true
		mat.emission = Color(0.65, 0.08, 0.15)
		mat.emission_energy_multiplier = 0.7
		ash.material_override = mat
		spirit_decor.add_child(ash)

func _on_damage(_amount: float) -> void:
	hit_flash = 1.0
	soundscape.cue("hurt", -12)

func _on_death() -> void:
	camera_flash.clear_light()
	soul_quest.close()
	death_text.text = "ĐÊM CHƯA HOÀN THÀNH\n\nR · Chơi lại"
	map_panel.hide()
	death_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
