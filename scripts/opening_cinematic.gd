extends Node3D

# Lightweight, deterministic cinematic using imported animated Quaternius characters.
# Only the three companions remain after the camera returns to the player.
const PRELUDE_DURATION := 36.0
const DURATION := PRELUDE_DURATION + 34.0
var director: Node3D
var playing := false
var paused := false
var elapsed := 0.0
var stage := -1
var camera: Camera3D
var scenery: Node3D
var cast: Node3D
var vehicle: Node3D
var actors: Array[Node3D] = []
var animations: Array[AnimationPlayer] = []
var layer: CanvasLayer
var subtitle: Label
var hint: Label
var fade: ColorRect
var engine: AudioStreamPlayer3D
var foley: AudioStreamPlayer
var previous_glimpse := false
var latch_cut := false
var cutters: Node3D
var investigation: Node3D
var title_label: Label

func start() -> void:
	process_priority = 2
	name = "OpeningCinematic"
	playing = true
	paused = false
	elapsed = 0
	stage = -1
	latch_cut = false
	previous_glimpse = false
	director.world.player.enabled = false
	director.world.player.velocity = Vector3.ZERO
	director.world.get_node("HUD").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	director.world.get_node("Campus/ServiceEntry").set_open_amount(0)
	_build_set()
	investigation = preload("res://scripts/investigation_prologue.gd").new()
	add_child(investigation)
	investigation.setup(self)
	_build_ui()
	sample(0)

func _build_set() -> void:
	scenery = Node3D.new()
	scenery.name = "ArrivalSet"
	add_child(scenery)
	# The road is outside the existing south boundary, used only by the shot.
	var road := MeshInstance3D.new()
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(100, 0.2, 12)
	road.mesh = road_mesh
	road.position = Vector3(0, -0.13, 85)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.09, 0.115, 0.13)
	asphalt.roughness = 0.95
	road.material_override = asphalt
	scenery.add_child(road)
	vehicle = preload("res://assets/kenney_car/van.glb").instantiate()
	vehicle.name = "InvestigationVan"
	vehicle.scale = Vector3.ONE * 1.75
	vehicle.rotation.y = -PI / 2
	scenery.add_child(vehicle)
	for side in [-1, 1]:
		var headlight := SpotLight3D.new()
		headlight.position = Vector3(side * 0.52, 0.67, 1.29)
		headlight.rotation.y = PI
		headlight.spot_range = 18
		headlight.spot_angle = 27
		headlight.light_energy = 2.8
		headlight.light_color = Color(0.82, 0.86, 0.74)
		headlight.shadow_enabled = false
		vehicle.add_child(headlight)
	var fill := OmniLight3D.new()
	fill.position = Vector3(6, 5, 85)
	fill.omni_range = 22
	fill.light_energy = 1.8
	fill.light_color = Color(0.54, 0.63, 0.75)
	fill.shadow_enabled = false
	scenery.add_child(fill)
	camera = Camera3D.new()
	camera.name = "OpeningCamera"
	camera.fov = 62
	camera.far = 220
	add_child(camera)
	camera.current = true
	cast = Node3D.new()
	cast.name = "ArrivalCompanions"
	add_child(cast)
	actors.clear()
	animations.clear()
	for i in range(4):
		var actor: Node3D = preload("res://scripts/humanoid_model.gd").new()
		actor.variant = "Casual_Female" if i == 1 else "Casual_Male"
		actor.target_height = 1.76 if i == 1 else 1.86
		actor.shirt_color = [Color(0.15, 0.26, 0.30), Color(0.33, 0.20, 0.21), Color(0.27, 0.29, 0.19), Color(0.16, 0.20, 0.24)][i]
		actor.name = ["Minh", "Lan", "Khoa", "PlayerDouble"][i]
		cast.add_child(actor)
		actors.append(actor)
		var animation: AnimationPlayer = actor.animation
		animations.append(animation)
	engine = AudioStreamPlayer3D.new()
	var stream: AudioStreamWAV = preload("res://assets/audio/arrival_engine.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	engine.stream = stream
	engine.volume_db = -14
	engine.max_distance = 55
	vehicle.add_child(engine)
	foley = AudioStreamPlayer.new()
	foley.stream = preload("res://assets/audio/arrival_climb.wav")
	foley.volume_db = -14
	add_child(foley)
	cutters = Node3D.new()
	cutters.name = "BoltCutters"
	scenery.add_child(cutters)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.42, 0.45, 0.43)
	steel.metallic = 0.65
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.38, 0.07, 0.035)
	for side in [-1, 1]:
		var handle := MeshInstance3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.018
		shaft.bottom_radius = 0.022
		shaft.height = 0.44
		handle.mesh = shaft
		handle.material_override = rubber
		handle.position = Vector3(side * 0.075, -0.23, 0)
		handle.rotation.z = side * -0.22
		cutters.add_child(handle)
		var jaw := MeshInstance3D.new()
		var jaw_mesh := BoxMesh.new()
		jaw_mesh.size = Vector3(0.035, 0.13, 0.045)
		jaw.mesh = jaw_mesh
		jaw.material_override = steel
		jaw.position = Vector3(side * 0.025, 0.03, 0)
		jaw.rotation.z = side * 0.3
		cutters.add_child(jaw)

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	for bottom in [false, true]:
		var bar := ColorRect.new()
		bar.color = Color(0.006, 0.012, 0.016, 0.97)
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -95 if bottom else 0
		bar.offset_bottom = 0 if bottom else 75
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bar)
	title_label = director.world._label(ui, Vector2(32, 14), 21, Color(0.72, 0.82, 0.82))
	hint = director.world._label(ui, Vector2(32, 43), 13, Color(0.55, 0.65, 0.67))
	title_label.hide()
	hint.text = "Enter · Bỏ qua"
	subtitle = director.world._label(ui, Vector2(60, 638), 21, Color(0.87, 0.89, 0.82))
	subtitle.size = Vector2(1160, 74)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.hide() # Tell the story through framing, evidence and gestures.
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)

func _input(event: InputEvent) -> void:
	if not playing:
		return
	# Consume cinematic input before both player and world gameplay handlers.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			finish()
		elif event.keycode == KEY_ESCAPE:
			paused = not paused
			hint.text = "ĐANG DỪNG · ESC tiếp tục    ·    ENTER bỏ qua" if paused else "ENTER bỏ qua mở đầu    ·    ESC tạm dừng"
			for animation in animations:
				animation.speed_scale = 0 if paused else 1
			engine.stream_paused = paused
			foley.stream_paused = paused
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not playing or paused:
		return
	elapsed += delta
	if elapsed >= DURATION:
		finish()
	else:
		sample(elapsed)

func _animate(index: int, wanted: String) -> void:
	for animation_name in animations[index].get_animation_list():
		if String(animation_name).get_file() == wanted and animations[index].current_animation != animation_name:
			animations[index].play(animation_name, 0.2)

func _shot(from: Vector3, to: Vector3, focus: Vector3, progress: float) -> void:
	camera.global_position = from.lerp(to, smoothstep(0, 1, clampf(progress, 0, 1)))
	camera.look_at(focus)

func sample(total_time: float) -> void:
	if total_time < PRELUDE_DURATION:
		scenery.hide()
		investigation.show()
		hint.visible = total_time < 4
		title_label.text = "NEH / ĐÊM 01     ·     PHÒNG ĐIỀU TRA     ·     TRƯỚC CHUYẾN ĐI"
		investigation.sample(total_time)
		fade.color.a = maxf(clampf(1 - total_time / 0.9, 0, 1), clampf((total_time - 35.2) / 0.8, 0, 1))
		return
	var time := total_time - PRELUDE_DURATION
	if investigation.visible:
		investigation.hide()
		scenery.show()
		engine.play()
	title_label.text = "NEH / ĐÊM 01     ·     23:30     ·     CỔNG TRƯỜNG"
	var next_stage := 0 if time < 7 else (1 if time < 14 else (2 if time < 22 else (3 if time < 27 else 4)))
	if next_stage != stage:
		stage = next_stage
		if stage == 1:
			engine.pitch_scale = 0.65
			foley.play()
		if stage >= 2:
			engine.stop()
	vehicle.position = Vector3(lerpf(32, 9, smoothstep(0, 1, minf(time / 7, 1))), 0, 85)
	var entry: Node3D = director.world.get_node("Campus/ServiceEntry")
	entry.set_open_amount(clampf((time - 18.5) / 2.8, 0, 1) * (1 - clampf((time - 26.8) / 0.7, 0, 1)))
	cutters.visible = time >= 15 and time < 19.2
	cutters.position = Vector3(12.72, 1.06, 78.25)
	cutters.rotation.z = sin(clampf((time - 15) / 3.5, 0, 1) * PI) * 0.2
	if time >= 18.5 and not latch_cut:
		latch_cut = true
		foley.play()
	for i in range(4):
		var actor: Node3D = actors[i]
		actor.head_pitch = 0
		actor.reach = 0
		actor.hand_target = Vector3(INF, INF, INF)
		actor.visible = time >= 7 and (i != 3 or time < 27)
		var outside := Vector3(13.7 + (i - 1) * 0.70, 0.05, 80.1 + i * 0.25)
		if i == 2:
			outside = Vector3(12.94, 0.05, 78.80)
		var inside := Vector3(12.0 + (i - 1) * 1.0, 0.05, 72.0 + i * 0.65)
		actor.rotation = Vector3(0, PI, 0)
		if time < 14:
			var progress := clampf((time - 7) / 6.5, 0, 1)
			var gate_check := Vector3(1.0 + i * 0.65, 0.05, 80.1 + i * 0.30)
			if progress < 0.35:
				actor.position = Vector3(7 + i * 1.0, 0.05, 83 + i * 0.3).lerp(gate_check, progress / 0.35)
			else:
				actor.position = gate_check.lerp(outside, (progress - 0.35) / 0.65)
			_animate(i, "walk" if progress < 1 else "idle")
		elif time < 22:
			actor.position = outside
			_animate(i, "idle")
			if i == 2:
				actor.head_pitch = 0.18
				actor.hand_target = Vector3(12.65, 0.80, 78.25) if time < 19.2 else Vector3(INF, INF, INF)
				actor.reach = 0.0
				investigation.equipment[2].hide()
				actor.rotation.x = -0.08
		else:
			investigation.equipment[i].show()
			# Feet remain on the ground; the only crossing is through the open doorway.
			var passage := clampf((time - 22 - i * 0.55) / 2.8, 0, 1)
			if passage < 0.25:
				actor.position = outside.lerp(Vector3(12, 0.05, 79.3), passage / 0.25)
			elif passage < 0.70:
				actor.position = Vector3(12, 0.05, 79.3).lerp(Vector3(12, 0.05, 76.5), (passage - 0.25) / 0.45)
			else:
				actor.position = Vector3(12, 0.05, 76.5).lerp(inside, (passage - 0.70) / 0.30)
			_animate(i, "walk" if passage < 1 else "idle")
	match stage:
		0:
			_shot(Vector3(18, 4.0, 94), Vector3(13, 2.6, 91), vehicle.position + Vector3(0, 1, 0), time / 7)
		1:
			_shot(Vector3(5, 2.2, 84), Vector3(16, 2.3, 82.5), Vector3(6.5, 1.5, 78), (time - 7) / 7)
		2:
			_shot(Vector3(11.2, 1.65, 80.3), Vector3(11.5, 1.4, 79.8), Vector3(12.65, 1.1, 78.1), (time - 14) / 8)
		3:
			_shot(Vector3(14.5, 2.5, 75), Vector3(12, 1.67, 75.2), Vector3(12, 1.5, 79), (time - 22) / 5)
		4:
			_shot(Vector3(12, 1.67, 75.2), Vector3(12, 1.67, 75.2), Vector3(0, 3.0, 18), 1)
	var glimpse := time >= 27.1 and time < 27.8 or time >= 30.0 and time < 31.0
	if previous_glimpse != glimpse:
		previous_glimpse = glimpse
		director.world.set_spirit_world(glimpse, true)
	var darkness := maxf(1 - time / 0.9, clampf((time - 33.2) / 0.8, 0, 1))
	fade.color.a = clampf(darkness, 0, 1)

func finish() -> void:
	if not playing:
		return
	playing = false
	paused = false
	# Skipping and watching produce the same arrival position and story state.
	for i in range(3):
		actors[i].show()
		actors[i].hand_target = Vector3(INF, INF, INF)
		investigation.equipment[i].show()
		actors[i].position = Vector3(11.0 + i * 1.0, 0.05, 72.0 + i * 0.65)
		animations[i].speed_scale = 1
		_animate(i, "idle")
	_release_after_frame(actors[3])
	actors.resize(3)
	animations.resize(3)
	engine.stop()
	foley.stop()
	_release_after_frame(scenery)
	_release_after_frame(investigation)
	layer.hide()
	_release_after_frame(layer)
	camera.current = false
	_release_after_frame(camera)
	_release_after_frame(foley)
	director.world.get_node("Campus/ServiceEntry").set_open_amount(0)
	director.complete_opening()

func remove_companions() -> void:
	if is_instance_valid(cast):
		_release_after_frame(cast)
	actors.clear()
	animations.clear()

func _release_after_frame(node: Node) -> void:
	# A fast skip can free a newly created skinned mesh before the renderer has
	# consumed its material dependencies. Hide immediately, release after a frame.
	var retained_materials: Array[Material] = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != null:
			retained_materials.append(mesh.material_override)
		if mesh.mesh != null:
			for surface in range(mesh.mesh.get_surface_count()):
				var material: Material = mesh.get_surface_override_material(surface)
				if material != null:
					retained_materials.append(material)
	if node is Node3D:
		node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(node):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	retained_materials.clear()
