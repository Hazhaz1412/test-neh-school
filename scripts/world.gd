extends Node3D
# The school at night. There is nothing supernatural in it: only the night guard, the evidence
# the group came for, and the way back out.
const VisualUpgrade := preload("res://scripts/visual_upgrade.gd")
const CityPlan := preload("res://scripts/city_backdrop/city_plan.gd")
const CityBuilder := preload("res://scripts/city_backdrop/city_builder.gd")
const Gear := preload("res://scripts/night_gear.gd")
const Settings := preload("res://scripts/game_settings.gd")
const Progress := preload("res://scripts/game_progress.gd")

@export_group("Night · guard hunt")
@export var hunt_enabled := true
@export_group("Night · opening and clock")
@export var play_opening_on_launch := true
@export_range(60.0, 3600.0, 30.0) var night_duration_seconds := 720.0
@export_range(10.0, 300.0, 5.0) var preparation_duration_seconds := 60.0
@export_group("Night · camera")
@export_range(0.6, 5.0, 0.1) var camera_shot_cooldown := 1.5
@export_group("Performance")
@export_enum("Nhẹ", "Cân bằng", "Cao") var quality_level := 1

# Night 1 is hunted by the guard through the whole school.
var guard_night := false
# AI A of Night 1 (hunt_director.gd); its `hunter` is the guard himself.
var hunt: Node
# Night 1's four students (hunt_team.gd); null on other nights.
var team: Node
# Night 1's kiting loops (kiting_course.gd); null on other nights.
var kiting: Node3D
# A longer breath on Night 1: running is how a chase is stretched out, not how it is won.
const HUNT_STAMINA := 260.0
var camera_flash: Node
var light_budget := 12
var local_lights: Array[OmniLight3D] = []
var flicker_lights: Array[OmniLight3D] = []
var light_clock := 0.0
var performance_label: Label
var show_performance := false
var overlay_rect: ColorRect
var overlay_mat: ShaderMaterial
var paused_by_user := false
var normal_environment: Environment
var light_defaults := {}
var hit_flash := 0.0
var interaction_label: Label
var notice_label: Label
var notice_time := 0.0
# Every room opens once the night has its key; the prologue opens rooms one story beat at a time.
var has_master_key := false
var threat_audio: AudioStreamPlayer
var threat := 0.0
var alarm := 0.0
var elapsed := 0.0
var map_panel: Control
var progression: Node3D
var journal: Node
var soundscape: Node
var help_panel: PanelContainer
var survival: Node3D
var test_cheats: Node
var cheat_finish_button: Button
var death_panel: ColorRect
var death_text: Label
@onready var player: CharacterBody3D = $Player

func _build_city_backdrop() -> void:
	var city := Node3D.new()
	city.name = "CityBackdrop"
	add_child(city)
	CityBuilder.new().build(city, CityPlan.new(CityPlan.layout()))

func _ready() -> void:
	preload("res://scripts/campus_fixes.gd").apply(self)
	_build_ui()
	VisualUpgrade.apply(self)
	_prepare_environment()
	_build_city_backdrop()
	threat_audio = _loop_audio("ThreatHeartbeat", "res://assets/audio/threat_heartbeat.wav", -80)
	survival = preload("res://scripts/survival_director.gd").new()
	add_child(survival)
	survival.setup(self)
	soundscape = preload("res://scripts/soundscape.gd").new()
	add_child(soundscape)
	soundscape.setup(self)
	camera_flash = preload("res://scripts/camera_flash.gd").new()
	camera_flash.name = "CameraFlash"
	camera_flash.world = self
	add_child(camera_flash)
	journal = preload("res://scripts/case_journal.gd").new()
	journal.name = "CaseJournal"
	survival.add_child(journal)
	journal.setup(self)
	progression = preload("res://scripts/school_progression.gd").new()
	survival.add_child(progression)
	progression.setup(self)
	hunt = preload("res://scripts/hunt_director.gd").new()
	hunt.name = "HuntDirector"
	add_child(hunt)
	hunt.setup(self)
	test_cheats = preload("res://scripts/test_cheats.gd").new()
	test_cheats.name = "TestCheats"
	test_cheats.world = self
	add_child(test_cheats)
	var arg_bridge := preload("res://scripts/arg_bridge.gd").new()
	arg_bridge.name = "ArgBridge"
	arg_bridge.world = self
	add_child(arg_bridge)
	# Added before compact_hud so the inventory and gauges draw on top of the frame.
	var viewfinder := preload("res://scripts/camera_viewfinder.gd").new()
	viewfinder.name = "CameraViewfinder"
	viewfinder.world = self
	viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewfinder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewfinder.hide()
	get_node("HUD").get_child(0).add_child(viewfinder)
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
	Settings.track(normal_environment)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_death)
	if get_tree().has_meta("night_one"):
		get_tree().remove_meta("next_survival_run")
		call_deferred("_begin_night_one")
	elif get_tree().has_meta("chapter_corridor"):
		get_tree().remove_meta("next_survival_run")
		call_deferred("_begin_corridor")
	elif bool(get_tree().get_meta("next_survival_run", false)):
		get_tree().remove_meta("next_survival_run")
		survival.call_deferred("start_run")
	elif play_opening_on_launch and not OS.get_cmdline_args().has("--script"):
		# Script tools explicitly control their camera/mode; the menu or F6 plays Night 0.
		Progress.mark("night0")
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
	performance_label = _label(ui, Vector2(1040, 124), 12, Color(0.65, 0.73, 0.73))
	performance_label.hide()
	interaction_label = _label(ui, Vector2(380, 608), 19, Color(0.88, 0.82, 0.65))
	interaction_label.size.x = 520
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label = _label(ui, Vector2(30, 641), 15, Color(0.94, 0.74, 0.51))
	var crosshair := _label(ui, Vector2(635, 348), 18, Color(0.65, 0.71, 0.69, 0.7))
	crosshair.text = "·"
	death_panel = ColorRect.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.color = Color(0.015, 0.02, 0.03, 0.88)
	death_panel.hide()
	ui.add_child(death_panel)
	death_text = _label(death_panel, Vector2(330, 270), 26, Color(0.82, 0.80, 0.74))
	death_text.text = "ĐÊM CHƯA HOÀN THÀNH\n\nR · Chơi lại"
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(390, 130)
	help_panel.size = Vector2(500, 340)
	ui.add_child(help_panel)
	var help_text := Label.new()
	help_text.text = "TẠM DỪNG · Esc tiếp tục\n\nWASD đi · Shift chạy · Ctrl đi nhẹ · C cúi · Space nhảy\nE nhặt / mở / nấp · Space nín thở khi nấp\n1–6 / cuộn chuột chọn đồ · Chuột trái dùng\nQ thả đồ · F đèn pin · Giữ/thả G ném phấn để đánh lạc hướng\nMáy ảnh: chụp lại bằng chứng · 20% pin / ảnh\nJ sổ điều tra · M sơ đồ · F6 chất lượng · F7 FPS\nR chơi lại · N mở đầu\n\nLẻn vào trường, tìm bằng chứng, đừng để bác bảo vệ bắt.\nĐường hầm: Shift chạy · Space nhảy · Ctrl trượt khi lấy đà."
	help_text.add_theme_font_size_override("font_size", 18)
	var help_stack := VBoxContainer.new()
	help_panel.add_child(help_stack)
	help_stack.add_child(help_text)
	var cheat_hint := Label.new()
	cheat_hint.text = "H + P · TEST: bất tử, nhanh ×3"
	cheat_hint.add_theme_font_size_override("font_size", 14)
	help_stack.add_child(cheat_hint)
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
	if survival.opening.playing or journal != null and journal.panel_visible() or progression != null and progression.panel_visible():
		return
	if event is InputEventKey and event.pressed and not event.echo:
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
			if survival.won and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				if get_tree().has_meta("chapter_corridor"):
					get_tree().remove_meta("chapter_corridor")
				if get_tree().has_meta("night_one"):
					var hunter: Node = hunt.hunter
					Gear.finish_night(Gear.read(), player.inventory, hunter.confiscated if hunter != null else [])
				get_tree().remove_meta("night_one")
				get_tree().change_scene_to_file("res://scenes/town.tscn")
			return
		if event.keycode == KEY_M and not progression.controls_player():
			paused_by_user = false
			map_panel.visible = not map_panel.visible
			player.enabled = (not map_panel.visible or survival.active) and player.health > 0 and not survival.won
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_panel.visible else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_ESCAPE and not map_panel.visible:
			paused_by_user = not paused_by_user
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused_by_user else Input.MOUSE_MODE_CAPTURED
		if event.keycode == KEY_ESCAPE and map_panel.visible:
			map_panel.hide()
			paused_by_user = false
			player.enabled = player.health > 0
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if simulation_active():
		elapsed += delta
	var environmental_story: bool = survival.active and progression.stage <= progression.Stage.BASEMENT_DESCENT
	# The heartbeat follows the guard on your heels, not a meter.
	var nearest := 16.0
	var hunter: Node3D = hunt.hunter if hunt != null else null
	if simulation_active() and hunter != null and hunter.is_hunting() and hunter.target == player:
		nearest = player.global_position.distance_to(hunter.global_position)
	threat = move_toward(threat, 1.0 - minf(nearest, 16.0) / 16.0, delta * 1.2)
	threat_audio.volume_db = lerpf(-60, -9, threat)
	threat_audio.pitch_scale = 0.95 + threat * 0.55
	if threat > 0.01 and not threat_audio.playing:
		threat_audio.play()
	elif threat <= 0.01 and threat_audio.playing:
		threat_audio.stop()
	hit_flash = maxf(0, hit_flash - delta * 1.8)
	overlay_mat.set_shader_parameter("hit", hit_flash)
	overlay_mat.set_shader_parameter("danger", threat)
	overlay_mat.set_shader_parameter("panic", player.fear / 100)
	alarm = maxf(0, alarm - delta * 2)
	overlay_mat.set_shader_parameter("alarm", alarm)
	overlay_mat.set_shader_parameter("photo_flash", camera_flash.intensity)
	overlay_rect.visible = hit_flash > 0.001 or alarm > 0.001 or threat > 0.001 or player.fear > 1 or camera_flash.intensity > 0
	light_clock -= delta
	if light_clock <= 0.0:
		light_clock = 0.35
		_update_light_budget()
	if show_performance:
		performance_label.text = "%s · %s\n%d FPS\n%d lượt vẽ" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	var target: Node3D = player.get_interaction_target() if simulation_active() else null
	interaction_label.text = target.interaction_text() if target != null else ""
	notice_time = maxf(0, notice_time - delta)
	notice_label.visible = notice_time > 0 and not environmental_story and not journal.panel_visible() and not progression.panel_visible()
	interaction_label.visible = not journal.panel_visible() and not progression.panel_visible() and not map_panel.visible
	help_panel.visible = paused_by_user and not survival.opening.playing
	cheat_finish_button.visible = test_cheats.enabled and not survival.finished
	if player.is_hidden():
		interaction_label.text = "E · Ra ngoài"
	elif target != null and target.has_method("request_toggle"):
		interaction_label.text = "E · Cửa khóa" if target.is_locked() else ("E · Đóng cửa" if target.is_open else "E · Mở cửa")
	elif target != null and target.has_method("hide_position"):
		interaction_label.text = "E · Nấp"
	if kiting != null and not player.is_hidden() and not kiting.prompt().is_empty():
		interaction_label.text = kiting.prompt()
	# The rescue bar carries its own prompt.
	if team != null and not team.prompt().is_empty():
		interaction_label.text = ""
	if environmental_story and target != null and not player.is_hidden():
		interaction_label.text = "E"
	for light in flicker_lights:
		if light.visible:
			light.light_energy = flicker_energy(light)

func flicker_energy(light: OmniLight3D) -> float:
	return 0.40 * campus_light_scale() * (0.70 + 0.30 * sin(elapsed * 7.0 + light.position.z))

func campus_light_scale() -> float:
	if progression != null and progression.power_surge: return 1.0
	return 0.16 if survival.active and survival.phase == survival.Phase.PREPARATION and not progression.briefing_complete else 1.0

func set_quality(level: int, persist := true) -> void:
	quality_level = clampi(level, 0, 2)
	light_budget = [8, 12, 24][quality_level]
	get_viewport().scaling_3d_scale = [0.75, 1.0, 1.0][quality_level]
	get_viewport().positional_shadow_atlas_size = [0, 1024, 2048][quality_level]
	player.flashlight.shadow_enabled = quality_level > 0
	$Atmosphere/Moonlight.shadow_enabled = quality_level > 0
	$Atmosphere/Moonlight.directional_shadow_max_distance = [40.0, 65.0, 110.0][quality_level]
	VisualUpgrade.set_quality(normal_environment, quality_level)
	_update_light_budget()
	if persist:
		Settings.write("quality", quality_level)

func _update_light_budget() -> void:
	if progression != null and progression.blackout:
		for lamp in local_lights: lamp.hide()
		return
	var position_seen := player.global_position
	local_lights.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(position_seen) < b.global_position.distance_squared_to(position_seen))
	for index in range(local_lights.size()):
		local_lights[index].visible = index < light_budget
		local_lights[index].light_energy = light_defaults[local_lights[index]][1] * campus_light_scale()

# Night 0's tunnel, reached straight from the chapter menu.
func _begin_corridor() -> void:
	survival.start_run(false)
	survival.begin_midnight()
	progression.begin_first_chase()

# Night 1, reached through the school gate after the free morning: the prologue is over, so the
# campus is open and the guard hunts the group from the first minute.
func _begin_night_one() -> void:
	Progress.mark("night1")
	guard_night = true
	# Night 1's yards carry vault walls and crawl gaps; the guard's map knows them.
	var course := preload("res://scripts/kiting_course.gd")
	kiting = course.build(self)
	if ResourceLoader.exists(course.NAVIGATION):
		NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, course.NAV_CELL)
		NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, course.NAV_CELL_HEIGHT)
		$Navigation.navigation_mesh = load(course.NAVIGATION)
	survival.start_run(false)
	progression.begin_night_one()
	var gear := Gear.read()
	player.inventory.assign(Gear.loadout(gear))
	player.select_item("torch")
	player.stamina_care = 1.0 - Gear.BOOST_CARE * gear.boosts
	player.max_stamina = HUNT_STAMINA
	player.stamina = HUNT_STAMINA
	team = preload("res://scripts/hunt_team.gd").new()
	add_child(team)
	team.setup(self)
	hunt.hunting_night = true
	notify("Đêm 1 · Cả nhóm trụ tới 06:00 · Bị bắt thì chờ đồng đội cứu")

func simulation_active() -> bool:
	return (progression == null or not progression.narrative_paused()) and player.enabled and player.health > 0 and (not map_panel.visible or survival != null and survival.active) and not paused_by_user and (survival == null or not survival.opening.playing and not survival.finished)

# Whether the night's hunter, fear and decoys are in play.
func night_hunt() -> bool:
	return guard_night

func emit_noise(position_heard: Vector3, radius: float, source: String) -> void:
	# The prologue's guard listens through the story; Night 1's through the hunt director.
	if progression != null and simulation_active():
		progression.hear_noise(position_heard, radius, source)
	if not simulation_active() or not night_hunt():
		return
	if hunt != null and hunt.hunter != null:
		hunt.hunter.hear(position_heard, radius, source)

func notify(message: String) -> void:
	notice_label.text = message.left(85)
	notice_time = 2.5

func collect_master_key() -> void:
	has_master_key = true

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

func _prepare_environment() -> void:
	normal_environment = $Atmosphere/MoonlitEnvironment.environment.duplicate(true)
	$Atmosphere/MoonlitEnvironment.environment = normal_environment
	for light in $Atmosphere.get_children():
		if light is Light3D:
			light_defaults[light] = [light.light_color, light.light_energy]
	var layer := CanvasLayer.new()
	layer.name = "ScreenOverlay"
	layer.layer = 5
	add_child(layer)
	var overlay := ColorRect.new()
	overlay_rect = overlay
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = preload("res://assets/materials/screen_overlay.gdshader")
	overlay.material = overlay_mat
	layer.add_child(overlay)

# The guard's patrol loop on Night 1.
func campus_patrol_route(variant: int) -> Array[Vector3]:
	# Shared circulation rather than room entrances or a timed two-point shuttle. Every circuit
	# covers A, B, the service yard and both upper floors.
	var route: Array[Vector3] = [
		Vector3(8, 0, 48), Vector3(23.5, 0, 48), Vector3(23.5, 0, 14),
		Vector3(12, 0, 7.5), Vector3(1.5, 0, -18), Vector3(18, 0, -40.5),
		Vector3(-18, 0, -40.5), Vector3(-37, 0, -40.5), Vector3(-45, 0, -44),
		Vector3(-39.5, 0, -16), Vector3(-18, 0, 7.5), Vector3(-23.5, 0, 48),
		Vector3(-23.5, 3.9, 14), Vector3(12, 3.9, 7.5), Vector3(39.5, 3.9, -16),
		Vector3(18, 3.9, -40.5), Vector3(-18, 3.9, -40.5), Vector3(-18, 3.9, 7.5),
		Vector3(-23.5, 7.8, 14), Vector3(-39.5, 7.8, -16), Vector3(-18, 7.8, -40.5),
		Vector3(18, 7.8, -40.5), Vector3(1.5, 7.8, -18), Vector3(12, 7.8, 7.5),
		Vector3(18, 7.8, 7.5), Vector3(23.5, 7.8, 48), Vector3(-23.5, 0, 14)]
	if posmod(variant, 2) == 1:
		route.reverse()
	return route

func _on_damage(_amount: float) -> void:
	hit_flash = 1.0
	soundscape.cue("hurt", -12)

func _on_death() -> void:
	camera_flash.clear_light()
	journal.close()
	progression.close()
	death_text.text = "ĐÊM CHƯA HOÀN THÀNH\n\nR · Chơi lại"
	map_panel.hide()
	death_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
