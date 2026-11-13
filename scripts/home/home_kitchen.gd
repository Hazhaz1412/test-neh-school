extends Node3D
# The morning after the dream Peter makes himself a mì net, the instant noodles every internet
# café sells, eaten dry: boiled, drained, tossed with the seasoning, then topped with a fried
# egg, a sausage, chopped spring onion and chilli sauce, with a can of Xiteen beside it. Each step
# is one small action on a fixed camera over the counter; nothing can be failed, a sloppy step
# only changes what he says while eating. Then he carries the bowl to the dining table and eats.
signal acted
const KIT := "res://assets/kitchen/%s.glb"
const SOUND := "res://assets/audio/kitchen/%s.ogg"
const TOP := 0.92
const STOVE := Vector3(5.2, TOP, 0.42)
const BURNER := 0.166
const BURNER_TOP := 0.2
const BOARD := Vector3(4.0, TOP, 0.44)
const BOWL := Vector3(4.56, TOP, 0.46)
const SINK := Vector3(3.2, TOP, 0.42)
const SINK_SIZE := Vector3(0.6, TOP, 0.66)
# Peter's place at the dining table (x 2.0-3.2, z 4.1-6.1, top 0.76): the chair on the east side
# nearest the kitchen, facing west. Bowl and can stand on the tabletop in front of it.
const TABLE_TOP := 0.76
const TABLE_BOWL := Vector3(2.96, TABLE_TOP, 4.6)
const TABLE_CAN := Vector3(2.98, TABLE_TOP, 4.36)
const SHOTS := {
	"overview": [Vector3(4.6, 1.72, 1.55), Vector3(4.6, 0.95, 0.4)],
	"stove": [Vector3(5.2, 1.6, 1.02), Vector3(5.2, 1.08, 0.42)],
	"pack": [Vector3(4.3, 1.42, 1.08), Vector3(4.3, 0.95, 0.62)],
	"sink": [Vector3(3.5, 1.55, 1.1), Vector3(3.22, 1.0, 0.42)],
	"board": [Vector3(4.0, 1.46, 0.96), Vector3(4.0, 0.93, 0.44)],
	"bowl": [Vector3(4.56, 1.4, 0.74), Vector3(4.56, 0.98, 0.46)],
	"seat": [Vector3(3.5, 1.17, 4.6), Vector3(2.92, 0.8, 4.56)],
}
const CHOPS := 10
const STIRS := 4
const SAUCE_LIMIT := 120

# A bar with named zones and a needle, drawn in the cooking panel.
class Meter extends Control:
	var zones: Array = []
	var needle := 0.0
	func _draw() -> void:
		var bar := Rect2(Vector2(0, 26), Vector2(size.x, 20))
		for zone in zones:
			var from: float = zone[0]
			var to: float = zone[1]
			var piece := Rect2(bar.position + Vector2(bar.size.x * from, 0), Vector2(bar.size.x * (to - from), bar.size.y))
			draw_rect(piece, zone[2])
			var font := get_theme_default_font()
			var width := font.get_string_size(zone[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(font, Vector2(piece.get_center().x - width * 0.5, 18), zone[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.93, 0.86))
		draw_rect(bar, Color(1, 1, 1, 0.7), false, 2.0)
		var x := bar.position.x + bar.size.x * clampf(needle, 0.0, 1.0)
		draw_rect(Rect2(x - 3, bar.position.y - 6, 6, bar.size.y + 12), Color(1, 1, 1))
		draw_rect(Rect2(x - 3, bar.position.y - 6, 6, bar.size.y + 12), Color(0, 0, 0, 0.8), false, 1.5)

var world: Node3D
var camera: Camera3D
var busy := false
# "", "tear", "pour" or "sauce": in those the left button is held, not clicked.
var mode := ""
var holding := false
var tear := 0.0
var water_left := 1.0
var panel: Control
var step_title: Label
var step_hint: Label
var meter: Meter
var pop: Label
var sounds := {}
var noodle_material: ShaderMaterial
var plain := {}
# Props on the counter for good, and the ones that only exist while cooking.
var pot: Node3D
var pot_home: Vector3
var pan: Node3D
# The middle of the pan's cooking surface (the model's own centre includes the handle).
var pan_centre: Vector3
var bowl: Node3D
var chili: Node3D
var can: Node3D
var water: MeshInstance3D
var stream: CPUParticles3D
var flames := []
var steam: CPUParticles3D
var smoke: CPUParticles3D
var noodles: MeshInstance3D
var toppings: Array = []
var sauce_dots: Array = []
var chopsticks: Node3D
var table_touch := {}
# How it turned out, which is what he comments on while eating.
var noodle_result := ""
var egg_result := ""
var shell := false
var spilled := false
var chop_time := 0.0

func setup(home: Node3D) -> void:
	world = home
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.02
	add_child(camera)
	for name in ["boil_loop", "fry_loop", "fizz", "stove_on", "can_on_table", "pick_chopsticks", "chop_1", "chop_2", "chop_3", "clink_1", "clink_2", "clink_3"]:
		var player := AudioStreamPlayer.new()
		player.stream = load(SOUND % name)
		player.volume_db = -9.0
		add_child(player)
		sounds[name] = player
	for name in ["boil_loop", "fry_loop"]:
		sounds[name].stream.loop = true
		sounds[name].volume_db = -80.0
	sounds["tear"] = _plain_sound("res://assets/audio/paper.wav")
	sounds["splash"] = _plain_sound("res://assets/audio/water_drip.wav")
	sounds["pour"] = _plain_sound("res://assets/audio/water_leak.wav")
	sounds["chair"] = _plain_sound("res://assets/audio/chair_scrape.wav")
	noodle_material = ShaderMaterial.new()
	noodle_material.shader = load("res://assets/materials/noodles.gdshader")
	noodle_material.set_shader_parameter("scale", 700.0)
	for entry in [["chip", Color(0.36, 0.66, 0.26)], ["sauce", Color(0.72, 0.07, 0.03)], ["shell", Color(0.97, 0.93, 0.85)], ["water", Color(0.78, 0.84, 0.86, 0.62)], ["pack", Color(0.93, 0.36, 0.12)], ["pack_top", Color(0.98, 0.78, 0.18)], ["egg_bite", Color(0.99, 0.97, 0.9)], ["sausage_bite", Color(0.78, 0.45, 0.3)]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = entry[1]
		material.roughness = 0.3 if entry[0] in ["sauce", "water"] else 0.7
		if entry[1].a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plain[entry[0]] = material
	_furnish()
	_build_panel()

func _plain_sound(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = -8.0
	add_child(player)
	return player

# --- Counter ---------------------------------------------------------------------------------

func _furnish() -> void:
	_model("gas_stove", 0.68, STOVE)
	pot_home = STOVE + Vector3(-BURNER, BURNER_TOP, 0)
	pot = _model("pot", 0.3, pot_home)
	# The pan's handle is along its +X; its round body sits 0.08 m the other way from the
	# model's centre. Put the body over the burner, handle out to the front right.
	pan_centre = STOVE + Vector3(BURNER, BURNER_TOP, 0)
	var turn := Basis(Vector3.UP, -0.6)
	pan = _model("pan", 0.42, pan_centre - turn * Vector3(-0.081, 0, 0), turn)
	_board()
	_sink()
	bowl = _model("bowl", 0.19, BOWL)
	chili = _model("chili_sauce", 0.19, Vector3(4.36, TOP, 0.2))
	_label(chili, "TƯƠNG ỚT", Vector3(0, 0.085, 0.034), 30, Color(1, 0.96, 0.86), 0.0)
	var light := OmniLight3D.new()
	light.position = Vector3(4.4, 1.75, 0.75)
	light.omni_range = 2.2
	light.light_energy = 0.55
	light.light_color = Color(1.0, 0.93, 0.82)
	add_child(light)
	# The water rides inside the pot, so tipping the pot tips it too.
	water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.004
	water.mesh = disc
	water.material_override = plain.water
	water.position = Vector3(0, 0.085, 0)
	water.hide()
	pot.add_child(water)
	stream = _particles(Vector3(-0.105, 0.1, 0), Color(0.82, 0.9, 0.95, 0.75), 0.018, false, pot)
	stream.amount = 70
	stream.lifetime = 0.45
	stream.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stream.emission_box_extents = Vector3(0.004, 0.004, 0.03)
	stream.direction = Vector3(-1, 0, 0)
	stream.spread = 8.0
	stream.initial_velocity_min = 0.25
	stream.initial_velocity_max = 0.35
	stream.gravity = Vector3(0, -4.0, 0)
	stream.local_coords = false
	for side in [-1, 1]:
		flames.append(_flame(STOVE + Vector3(BURNER * side, BURNER_TOP - 0.01, 0)))
	steam = _puffs(pot_home + Vector3(0, 0.1, 0), Color(1, 1, 1, 0.32), 0.09)
	smoke = _puffs(pan_centre + Vector3(0, 0.04, 0), Color(0.25, 0.24, 0.22, 0.55), 0.06)

# Kenney's sink cabinet, stretched to fill the gap left for it in the counter run.
func _sink() -> void:
	var model: Node3D = load(KIT % "sink").instantiate()
	add_child(model)
	var box := AABB()
	var first := true
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var piece: AABB = part.transform * part.mesh.get_aabb()
		box = piece if first else box.merge(piece)
		first = false
	var stretch := Vector3(SINK_SIZE.x / box.size.x, SINK_SIZE.y / box.size.y, SINK_SIZE.z / box.size.z)
	# Turned around so the tap is at the back, against the wall.
	var turn := Basis(Vector3.UP, PI)
	var anchor := Vector3(box.get_center().x, box.position.y, box.get_center().z) * stretch
	model.transform = Transform3D(turn * Basis.from_scale(stretch), Vector3(SINK.x, 0, SINK.z) - turn * anchor)

func _board() -> void:
	var board: Node3D = load("res://assets/kitchen/cutting_board/wooden_cutting_board.gltf").instantiate()
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.add_child(board)
	_fit(pivot, board, 0.36, Basis.IDENTITY)
	pivot.position = BOARD

func _model(file: String, longest: float, at: Vector3, tilt := Basis.IDENTITY, parent: Node3D = null) -> Node3D:
	var pivot := Node3D.new()
	(parent if parent != null else self).add_child(pivot)
	var model: Node3D = load(KIT % file).instantiate()
	pivot.add_child(model)
	_fit(pivot, model, longest, tilt)
	pivot.position = at
	return pivot

# Scales the model so its longest side is `longest`, standing on the pivot's origin.
func _fit(pivot: Node3D, model: Node3D, longest: float, tilt: Basis) -> void:
	model.transform = Transform3D(tilt, Vector3.ZERO)
	var inverse := pivot.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var piece: AABB = (inverse * part.global_transform) * part.mesh.get_aabb()
		box = piece if first else box.merge(piece)
		first = false
	var size := longest / maxf(box.size.x, maxf(box.size.y, box.size.z))
	var centre := box.get_center()
	model.transform = Transform3D(tilt.scaled(Vector3.ONE * size), Vector3(-centre.x, -box.position.y, -centre.z) * size)

# A pair of chopsticks with the pivot where the tips meet and local +Y running up the sticks,
# so placing the pivot places whatever they hold.
func _chopsticks() -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	var model: Node3D = load(KIT % "chopsticks").instantiate()
	pivot.add_child(model)
	# The bare wooden ends (the tips) are at the model's top; turn them to the bottom.
	_fit(pivot, model, 0.23, Basis(Vector3.RIGHT, PI))
	return pivot

func _label(on: Node3D, text: String, at: Vector3, font_size: int, colour: Color, turn: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0006
	label.modulate = colour
	label.outline_modulate = Color(0.45, 0.04, 0.03)
	label.outline_size = 10
	label.position = at
	label.rotation.z = turn
	on.add_child(label)
	return label

# Each material on the model, made its own so it can be tinted without touching other copies.
func _materials(root: Node) -> Array:
	var list := []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(i)
			if material is BaseMaterial3D:
				var own: BaseMaterial3D = material.duplicate()
				mesh.set_surface_override_material(i, own)
				list.append(own)
	return list

func _soft_dot() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.gradient = Gradient.new()
	texture.gradient.set_color(0, Color(1, 1, 1, 1))
	texture.gradient.set_color(1, Color(1, 1, 1, 0))
	return texture

func _particles(at: Vector3, colour: Color, size: float, additive: bool, parent: Node3D = null) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = material
	particles.mesh = quad
	particles.emitting = false
	particles.position = at
	var ramp := Gradient.new()
	ramp.set_color(0, Color(colour, 0.0))
	ramp.add_point(0.25, colour)
	ramp.set_color(ramp.get_point_count() - 1, Color(colour, 0.0))
	particles.color_ramp = ramp
	(parent if parent != null else self).add_child(particles)
	return particles

func _flame(at: Vector3) -> CPUParticles3D:
	var flame := _particles(at, Color(0.35, 0.55, 1.0, 0.9), 0.022, true)
	flame.amount = 48
	flame.lifetime = 0.22
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	flame.emission_ring_axis = Vector3.UP
	flame.emission_ring_radius = 0.05
	flame.emission_ring_inner_radius = 0.042
	flame.emission_ring_height = 0.002
	flame.direction = Vector3.UP
	flame.spread = 10.0
	flame.gravity = Vector3.ZERO
	flame.initial_velocity_min = 0.06
	flame.initial_velocity_max = 0.1
	return flame

func _puffs(at: Vector3, colour: Color, size: float) -> CPUParticles3D:
	var puffs := _particles(at, colour, size, false)
	puffs.amount = 22
	puffs.lifetime = 1.8
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puffs.emission_sphere_radius = 0.06
	puffs.direction = Vector3.UP
	puffs.spread = 15.0
	puffs.gravity = Vector3(0, 0.03, 0)
	puffs.initial_velocity_min = 0.07
	puffs.initial_velocity_max = 0.14
	puffs.scale_amount_min = 0.7
	puffs.scale_amount_max = 1.6
	return puffs

func _noodle_mesh(material: ShaderMaterial, top: float, bottom: float, height: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 24
	mesh.mesh = shape
	mesh.material_override = material
	return mesh

# --- Panel -----------------------------------------------------------------------------------

func _build_panel() -> void:
	panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.03, 0.04, 0.72)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 66
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.goal.get_parent().add_child(panel)
	world.goal.get_parent().move_child(panel, world.fade.get_index())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	step_title = Label.new()
	step_title.add_theme_font_size_override("font_size", 24)
	step_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	step_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(step_title)
	step_hint = Label.new()
	step_hint.add_theme_font_size_override("font_size", 17)
	step_hint.add_theme_color_override("font_color", Color(0.92, 0.91, 0.86))
	step_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(step_hint)
	meter = Meter.new()
	meter.custom_minimum_size = Vector2(480, 54)
	stack.add_child(meter)
	panel.hide()
	pop = Label.new()
	pop.add_theme_font_size_override("font_size", 52)
	pop.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	pop.add_theme_color_override("font_outline_color", Color(0.55, 0.08, 0.04))
	pop.add_theme_constant_override("outline_size", 14)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.hide()
	world.goal.get_parent().add_child(pop)
	world.goal.get_parent().move_child(pop, world.fade.get_index())

func _step(title: String, hint: String, zones := []) -> void:
	step_title.text = title
	step_hint.text = hint
	meter.zones = zones
	meter.needle = 0.0
	meter.visible = not zones.is_empty()
	meter.queue_redraw()

func _needle(value: float) -> void:
	meter.needle = value
	meter.queue_redraw()

func _zone(value: float) -> int:
	for i in range(meter.zones.size()):
		if value <= meter.zones[i][1]:
			return i
	return meter.zones.size() - 1

# Runs the needle from 0 to 1 over `seconds` (or back and forth when `swing`) until acted on.
func _race(seconds: float, swing := false, tick := Callable()) -> float:
	var state := {"done": false}
	var stop := func(): state.done = true
	acted.connect(stop)
	var clock := 0.0
	while not state.done:
		await get_tree().process_frame
		clock += get_process_delta_time()
		var value := clock / seconds
		if swing:
			value = 1.0 - absf(fmod(value, 2.0) - 1.0)
		elif value >= 1.0:
			value = 1.0
			state.done = true
		_needle(value)
		if tick.is_valid():
			tick.call(value)
	acted.disconnect(stop)
	return meter.needle

func _fly(shot: String, seconds := 0.7) -> void:
	var target := Transform3D(Basis.IDENTITY, SHOTS[shot][0]).looking_at(SHOTS[shot][1])
	await _fly_to(target, seconds)

func _fly_to(target: Transform3D, seconds: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", target, seconds)
	await tween.finished

func _fade(sound: String, volume: float, seconds: float) -> void:
	var player: AudioStreamPlayer = sounds[sound]
	if volume > -60.0 and not player.playing:
		player.play()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume, seconds)
	if volume <= -60.0:
		tween.tween_callback(player.stop)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _held() -> bool:
	return holding or Input.is_physical_key_pressed(KEY_SPACE)

func _unhandled_input(event: InputEvent) -> void:
	if not busy:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER]:
		get_viewport().set_input_as_handled()
		acted.emit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding = event.pressed
		if event.pressed and mode.is_empty():
			acted.emit()
	elif event is InputEventMouseMotion and mode == "tear" and holding:
		tear += maxf(event.relative.x, 0.0) / 280.0

# --- The cooking -----------------------------------------------------------------------------

func begin() -> void:
	busy = true
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.global_transform = world.player.camera.global_transform
	camera.make_current()
	world.goal.text = "Nấu một tô mì net"
	can = _model("xiteen_can", 0.125, Vector3(4.78, TOP, 0.24))
	_label(can, "XITEEN", Vector3(0, 0.064, 0.044), 46, Color(1.0, 0.86, 0.18), PI * 0.5)
	_label(can, "XITEEN", Vector3(0, 0.064, -0.044), 46, Color(1.0, 0.86, 0.18), PI * 0.5).rotation.y = PI
	panel.show()
	_step("Mì net", "Trứng, xúc xích, hành lá, lon Xiteen. Gói How How trong tủ.")
	await _fly("overview", 1.0)
	await _wait(1.2)
	await _boil()
	await _cook_noodles()
	await _drain()
	await _mix()
	await _crack_egg()
	await _fry()
	await _chop()
	await _squeeze()
	await _open_can()
	await _serve()

func _boil() -> void:
	await _fly("stove")
	_step("Bắc nồi nước", "Space · vặn bếp")
	await acted
	sounds.stove_on.play()
	flames[0].emitting = true
	water.show()
	_fade("boil_loop", -26.0, 1.0)
	await _wait(0.5)
	await _tear_pack()

func _tear_pack() -> void:
	var pack := Node3D.new()
	add_child(pack)
	pack.position = Vector3(4.3, TOP, 0.62)
	var body := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.13, 0.026, 0.105)
	body.mesh = shape
	body.position.y = 0.013
	body.material_override = plain.pack
	pack.add_child(body)
	var strip := MeshInstance3D.new()
	var strip_shape := BoxMesh.new()
	strip_shape.size = Vector3(0.13, 0.027, 0.018)
	strip.mesh = strip_shape
	strip.position = Vector3(0, 0.0135, -0.06)
	strip.material_override = plain.pack_top
	pack.add_child(strip)
	var brand := _label(pack, "HOW HOW\nmì tôm chua cay", Vector3(0, 0.0275, 0.004), 34, Color(1.0, 0.95, 0.4), 0.0)
	brand.rotation.x = -PI * 0.5
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await _fly("pack")
	_step("Xé gói mì", "Giữ chuột trái rồi kéo sang phải · hoặc gõ Space")
	mode = "tear"
	tear = 0.0
	var taps := func(): tear += 0.25
	acted.connect(taps)
	while tear < 1.0:
		await get_tree().process_frame
		strip.position.x = minf(tear, 1.0) * 0.05
		strip.rotation.z = minf(tear, 1.0) * 0.5
	acted.disconnect(taps)
	mode = ""
	sounds.tear.play()
	var fly := create_tween()
	fly.tween_property(strip, "position", Vector3(0.2, 0.12, -0.1), 0.35)
	fly.parallel().tween_property(strip, "rotation", Vector3(1.2, 0.4, 1.5), 0.35)
	await fly.finished
	strip.hide()
	# The dry brick comes out of the pack and goes into the pot.
	var brick := MeshInstance3D.new()
	var brick_shape := BoxMesh.new()
	brick_shape.size = Vector3(0.095, 0.022, 0.08)
	brick.mesh = brick_shape
	var dry: ShaderMaterial = noodle_material.duplicate()
	dry.set_shader_parameter("soft", 0.0)
	brick.material_override = dry
	add_child(brick)
	brick.position = pack.position + Vector3(0, 0.05, 0)
	await _wait(0.2)
	pack.queue_free()
	_step("Thả mì", "Nước sôi rồi")
	steam.emitting = true
	_fly("stove", 0.6)
	var drop := create_tween().set_trans(Tween.TRANS_QUAD)
	drop.tween_property(brick, "position", pot.position + Vector3(0, 0.2, 0), 0.5)
	drop.tween_property(brick, "position", pot.position + water.position, 0.25).set_ease(Tween.EASE_IN)
	await drop.finished
	sounds.splash.play()
	brick.reparent(pot, true)
	noodles = brick

func _cook_noodles() -> void:
	_step("Nấu mì", "Space · tắt bếp khi kim vào ô xanh", [[0.0, 0.42, Color(0.75, 0.62, 0.25), "Còn cứng"], [0.42, 0.72, Color(0.22, 0.62, 0.3), "Vừa chín"], [0.72, 1.0, Color(0.72, 0.28, 0.2), "Nở bung"]])
	var material: ShaderMaterial = noodles.material_override
	var cook := func(value: float):
		material.set_shader_parameter("soft", clampf(value * 1.5, 0.0, 1.0))
		noodles.scale = Vector3(lerpf(1.0, 1.5, value), lerpf(1.0, 0.75, value), lerpf(1.0, 1.5, value))
	var value := await _race(5.5, false, cook)
	noodle_result = ["hard", "good", "soggy"][_zone(value)]
	world.think(["Hơi cứng. Mì trộn dai dai cũng được.", "Sợi mì vừa tới.", "Nở mất rồi..."][_zone(value)], 2.4)
	flames[0].emitting = false
	_fade("boil_loop", -80.0, 1.2)
	await _wait(0.4)

# Mì khô: the water is poured off over the sink before the noodles go into the bowl.
func _drain() -> void:
	steam.emitting = false
	await _fly("sink", 0.6)
	var carry := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	carry.tween_property(pot, "position", SINK + Vector3(0.2, 0.16, 0.0), 0.6)
	await carry.finished
	_step("Chắt nước", "Giữ Space (hoặc chuột trái) để nghiêng nồi · thả ra khi ráo nước", [[0.0, 0.85, Color(0.35, 0.55, 0.75), "Còn nước"], [0.85, 1.0, Color(0.22, 0.62, 0.3), "Ráo"]])
	mode = "pour"
	water_left = 1.0
	var tilt := 0.0
	var over := 0.0
	while true:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		tilt = move_toward(tilt, 1.0 if _held() else 0.0, delta * 2.2)
		pot.rotation.z = tilt * 1.15
		var pouring := tilt > 0.45 and water_left > 0.0
		if pouring:
			water_left = maxf(water_left - delta * 0.55 * tilt, 0.0)
		stream.emitting = pouring
		if pouring and not sounds.pour.playing:
			sounds.pour.play()
		elif not pouring and sounds.pour.playing:
			sounds.pour.stop()
		water.position.y = 0.02 + 0.065 * water_left
		water.visible = water_left > 0.02
		_needle(1.0 - water_left)
		# Held on past empty, the noodles start sliding out after the water.
		if water_left <= 0.0 and tilt > 0.9:
			over += delta
			if over > 0.8 and not spilled:
				spilled = true
				world.think("Ối, rớt mấy sợi xuống bồn.", 2.2)
				noodles.scale *= 0.85
		if water_left <= 0.0 and tilt <= 0.0:
			break
	mode = ""
	stream.emitting = false
	if not spilled:
		world.think("Ráo nước. Giờ trộn gia vị.", 2.2)
	# Into the bowl; the pot goes back on the stove.
	await _fly("bowl", 0.6)
	noodles.queue_free()
	var cooked: ShaderMaterial = noodle_material.duplicate()
	noodles = _noodle_mesh(cooked, 0.062, 0.076, 0.03)
	add_child(noodles)
	noodles.position = bowl.position + Vector3(0, 0.25, 0)
	sounds.splash.play()
	var pour := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pour.tween_property(noodles, "position", bowl.position + Vector3(0, 0.062, 0), 0.4)
	pot.rotation = Vector3.ZERO
	pot.position = pot_home
	await pour.finished

# Seasoning powder and the chilli oil sachet, stirred in with chopsticks.
func _mix() -> void:
	var sticks := _chopsticks()
	sticks.global_transform = Transform3D(_along(Vector3(0.45, 1.0, 0.25)), bowl.position + Vector3(0, 0.07, 0))
	_step("Trộn gia vị", "Gõ Space để trộn · 0/%d" % STIRS)
	var material: ShaderMaterial = noodles.material_override
	# Every press counts, even while the last stir is still moving.
	var stir: Tween
	for i in range(STIRS):
		await acted
		sounds["clink_%d" % (i % 3 + 1)].play()
		if stir != null:
			stir.kill()
		stir = create_tween().set_trans(Tween.TRANS_SINE)
		for corner in [Vector3(0.03, 0, 0.02), Vector3(-0.03, 0, 0.01), Vector3(0, 0, -0.03), Vector3.ZERO]:
			stir.tween_property(sticks, "position", bowl.position + Vector3(0, 0.07, 0) + corner, 0.06)
		material.set_shader_parameter("swirl", float(i + 1) * 0.9)
		material.set_shader_parameter("glaze", float(i + 1) / STIRS)
		step_hint.text = "Gõ Space để trộn · %d/%d" % [i + 1, STIRS]
	await stir.finished
	sticks.queue_free()
	world.think("Thơm mùi dầu tỏi phi.", 2.0)
	await _wait(0.4)

# A basis whose +Y points along `direction`, for laying chopsticks.
func _along(direction: Vector3) -> Basis:
	var y := direction.normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	return Basis(x, y, x.cross(y))

func _crack_egg() -> void:
	await _fly("stove")
	sounds.stove_on.play()
	flames[1].emitting = true
	_fade("fry_loop", -30.0, 0.8)
	var egg := _model("egg", 0.055, pan_centre + Vector3(-0.06, 0.16, 0.06), Basis(Vector3.FORWARD, 0.4))
	_step("Đập trứng", "Space · đập khi kim vào ô xanh", [[0.0, 0.3, Color(0.45, 0.5, 0.6), "Nhẹ quá"], [0.3, 0.62, Color(0.22, 0.62, 0.3), "Vừa tay"], [0.62, 1.0, Color(0.72, 0.28, 0.2), "Mạnh quá"]])
	var tries := 0
	while true:
		var value := await _race(1.1, true)
		var tap := create_tween()
		tap.tween_property(egg, "position:y", egg.position.y - 0.05, 0.08)
		tap.tween_property(egg, "position:y", egg.position.y, 0.12)
		await tap.finished
		tries += 1
		if _zone(value) == 0 and tries < 3:
			world.think("Cốc. Chưa vỡ.", 1.6)
			continue
		shell = _zone(value) == 2
		break
	sounds.chop_2.play()
	egg.queue_free()
	var fried := _model("egg_fried", 0.12, pan_centre + Vector3(-0.035, 0.012, 0.01), Basis(Vector3.UP, 0.7))
	var white: BaseMaterial3D
	for material: BaseMaterial3D in _materials(fried):
		if material.resource_name != "yellow":
			white = material
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.albedo_color = Color(0.92, 0.9, 0.82, 0.45)
	fried.set_meta("white", white)
	fried.set_meta("bite", plain.egg_bite)
	fried.scale = Vector3.ONE * 0.4
	create_tween().tween_property(fried, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade("fry_loop", -14.0, 0.3)
	if shell:
		for i in range(3):
			var chip := MeshInstance3D.new()
			var piece := BoxMesh.new()
			piece.size = Vector3(0.012, 0.002, 0.009)
			chip.mesh = piece
			chip.material_override = plain.shell
			fried.add_child(chip)
			chip.position = Vector3(randf_range(-0.03, 0.03), 0.012, randf_range(-0.03, 0.03))
			chip.rotation.y = randf() * TAU
		world.think("Mạnh tay quá, vỏ rơi vào chảo rồi.", 2.4)
	toppings.append(fried)
	await _wait(0.6)
	var sausage := _model("sausage_fried", 0.1, pan_centre + Vector3(0.06, 0.18, -0.01), Basis(Vector3.UP, 1.2))
	for material: BaseMaterial3D in _materials(sausage):
		sausage.set_meta("skin", material)
		material.albedo_color = Color(0.93, 0.6, 0.52)
	sausage.set_meta("bite", plain.sausage_bite)
	var drop := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_property(sausage, "position:y", pan_centre.y + 0.012, 0.4)
	toppings.append(sausage)
	if not shell:
		world.think("Thêm cây xúc xích. Mì net phải có xúc xích.", 2.6)
	await drop.finished

func _fry() -> void:
	_step("Chiên", "Space · xúc ra khi trứng vàng mép", [[0.0, 0.4, Color(0.75, 0.7, 0.5), "Còn sống"], [0.4, 0.74, Color(0.22, 0.62, 0.3), "Vàng ruộm"], [0.74, 1.0, Color(0.3, 0.2, 0.15), "Khét"]])
	var fried: Node3D = toppings[0]
	var sausage: Node3D = toppings[1]
	var white: BaseMaterial3D = fried.get_meta("white")
	var skin: BaseMaterial3D = sausage.get_meta("skin")
	var cook := func(value: float):
		var firm := clampf(value / 0.4, 0.0, 1.0)
		var burn := clampf((value - 0.7) / 0.3, 0.0, 1.0)
		white.albedo_color = Color(0.92, 0.9, 0.82, 0.45).lerp(Color(1, 0.99, 0.95, 1), firm).lerp(Color(0.42, 0.28, 0.16, 1), burn)
		skin.albedo_color = Color(0.93, 0.6, 0.52).lerp(Color(0.8, 0.48, 0.32), firm).lerp(Color(0.28, 0.16, 0.1), burn)
		sausage.rotation.y = 1.2 + value * 2.0
		smoke.emitting = burn > 0.2
	var value := await _race(6.5, false, cook)
	egg_result = ["raw", "good", "burnt"][_zone(value)]
	if egg_result != "raw":
		white.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	world.think(["Lòng trắng còn hơi nhớt...", "Vàng mép, lòng đào. Đẹp.", "Khét lẹt. Mở cửa sổ ra..."][_zone(value)], 2.4)
	flames[1].emitting = false
	smoke.emitting = false
	_fade("fry_loop", -80.0, 1.0)
	var spatula := _model("spatula", 0.26, pan_centre + Vector3(0.2, 0.05, 0.12), Basis(Vector3.UP, 2.5))
	var scoop := create_tween()
	scoop.tween_property(spatula, "position", pan_centre + Vector3(0.0, 0.02, 0.02), 0.3)
	await scoop.finished
	spatula.queue_free()
	await _fly("bowl", 0.6)
	var top := bowl.position.y + 0.077
	var serve := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	serve.tween_property(fried, "position", Vector3(bowl.position.x - 0.012, top, bowl.position.z + 0.012), 0.5)
	serve.tween_property(fried, "scale", Vector3.ONE * 0.92, 0.5)
	serve.tween_property(sausage, "position", Vector3(bowl.position.x + 0.04, top + 0.004, bowl.position.z - 0.03), 0.55)
	await serve.finished
	await _wait(0.4)

func _chop() -> void:
	await _fly("board")
	var onion := _model("scallion", 0.28, BOARD + Vector3(0.03, 0.022, 0.02), Basis(Vector3.FORWARD, PI * 0.5))
	# Spring onion is thin: the leek model squashed to a stalk.
	onion.scale = Vector3(1.0, 0.3, 0.3)
	# Blade across the stalk, turned a little so its side shows to the camera.
	var knife := _model("knife", 0.24, BOARD + Vector3(-0.1, 0.09, 0.02), Basis(Vector3.UP, 0.55) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5))
	var root_x := onion.position.x - 0.14
	_step("Thái hành", "Gõ Space thật nhanh · 0/%d" % CHOPS)
	var chips: Array = []
	var started := -1.0
	for i in range(CHOPS):
		await acted
		if started < 0.0:
			started = Time.get_ticks_msec() / 1000.0
		var left := 1.0 - float(i + 1) / (CHOPS + 2)
		var cut_x := root_x + 0.28 * left
		knife.position.x = cut_x
		var chop := create_tween()
		chop.tween_property(knife, "position:y", BOARD.y + 0.03, 0.05)
		chop.tween_property(knife, "position:y", BOARD.y + 0.09, 0.08)
		sounds["chop_%d" % (i % 3 + 1)].play()
		onion.scale.x = left
		onion.position.x = root_x + 0.14 * left
		var chip := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 0.0045
		ring.bottom_radius = 0.0045
		ring.height = 0.005
		chip.mesh = ring
		chip.material_override = plain.chip
		add_child(chip)
		chip.position = Vector3(cut_x + 0.012 + randf_range(0.0, 0.03), BOARD.y + 0.026, BOARD.z + randf_range(-0.03, 0.05))
		chip.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		chips.append(chip)
		step_hint.text = "Gõ Space thật nhanh · %d/%d" % [i + 1, CHOPS]
	chop_time = Time.get_ticks_msec() / 1000.0 - started
	if chop_time < 2.6:
		world.think("Tay nghề đầu bếp quán net.", 2.2)
	await _wait(0.35)
	knife.queue_free()
	onion.queue_free()
	await _fly("bowl", 0.6)
	var sprinkle := create_tween().set_parallel()
	for chip: MeshInstance3D in chips:
		chip.set_meta("bite", plain.chip)
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 0.055
		sprinkle.tween_property(chip, "position", bowl.position + Vector3(spot.x, 0.082, spot.y), randf_range(0.35, 0.6)).set_trans(Tween.TRANS_QUAD)
		toppings.append(chip)
	await sprinkle.finished

func _squeeze() -> void:
	_step("Xịt tương ớt", "Giữ chuột trái rồi vẽ lên tô · Space khi xong", [[0.0, 0.15, Color(0.6, 0.55, 0.45), "Nhạt"], [0.15, 0.6, Color(0.22, 0.62, 0.3), "Vừa"], [0.6, 1.0, Color(0.75, 0.12, 0.06), "Cay xé"]])
	var home := chili.transform
	mode = "sauce"
	var state := {"done": false}
	var finish := func(): state.done = true
	acted.connect(finish)
	var last := Vector3.INF
	while not state.done:
		await get_tree().process_frame
		var aim := _aim()
		if aim == Vector3.INF:
			continue
		# Smaller in hand and tipped over away from the camera, so the nozzle sits just above
		# the point and the bottle does not hide the bowl.
		chili.scale = Vector3.ONE * 0.55
		chili.position = chili.position.lerp(aim + Vector3(0, 0.102, -0.054), 0.4)
		chili.rotation.x = lerp_angle(chili.rotation.x, 2.6, 0.3)
		if holding and sauce_dots.size() < SAUCE_LIMIT and (last == Vector3.INF or aim.distance_to(last) > 0.004):
			squirt(aim)
			last = aim
		if not holding:
			last = Vector3.INF
	acted.disconnect(finish)
	mode = ""
	var back := create_tween()
	back.tween_property(chili, "transform", home, 0.4)
	var amount := float(sauce_dots.size()) / SAUCE_LIMIT
	if sauce_dots.is_empty():
		world.think("Mì net mà không có tương ớt...", 2.4)
	elif amount > 0.6:
		world.think("Hơi tay một chút.", 2.0)

# Where the mouse points on the noodles, or INF when it is off the bowl.
func _aim() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var along := camera.project_ray_normal(mouse)
	var height := bowl.position.y + 0.08
	if absf(along.y) < 0.001:
		return Vector3.INF
	var hit := from + along * ((height - from.y) / along.y)
	var flat := Vector2(hit.x - bowl.position.x, hit.z - bowl.position.z)
	if flat.length() > 0.065:
		return Vector3.INF
	return hit

func squirt(at: Vector3) -> void:
	var dot := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.004
	blob.height = 0.003
	blob.radial_segments = 8
	blob.rings = 4
	dot.mesh = blob
	dot.material_override = plain.sauce
	add_child(dot)
	dot.position = at
	sauce_dots.append(dot)
	_needle(float(sauce_dots.size()) / SAUCE_LIMIT)

func _open_can() -> void:
	await _fly("overview", 0.7)
	_step("Khui lon Xiteen", "Space · khui")
	await acted
	sounds.fizz.play()
	var pop_can := create_tween()
	pop_can.tween_property(can, "scale", Vector3(1.08, 0.94, 1.08), 0.06)
	pop_can.tween_property(can, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await pop_can.finished

func _serve() -> void:
	panel.hide()
	world.think("Thơm ngon mời bạn ăn nha!", 3.2)
	pop.text = "Thơm ngon mời bạn ăn nha!"
	pop.show()
	pop.pivot_offset = pop.size * 0.5
	pop.scale = Vector2.ONE * 0.3
	var grow := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_property(pop, "scale", Vector2.ONE, 0.35)
	await _wait(2.2)
	var fade_out := create_tween()
	fade_out.tween_property(pop, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	pop.hide()
	pop.modulate.a = 1.0
	# Bowl and can go into Peter's hands; he carries them to the table himself.
	var dish := _dish()
	await _fly_to(world.player.camera.global_transform, 0.6)
	world.player.camera.make_current()
	dish.reparent(world.player.camera, false)
	dish.transform = Transform3D(Basis.IDENTITY, Vector3(0.02, -0.34, -0.42))
	can.reparent(dish, false)
	can.transform = Transform3D(Basis.IDENTITY, Vector3(0.15, 0.0, 0.02))
	busy = false
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.goal.text = "Bưng tô mì ra bàn ăn"
	table_touch = {"position": TABLE_BOWL + Vector3(0, 0.25, 0), "label": "Ngồi xuống ăn", "action": _sit}
	world.interactions.append(table_touch)
	world.story.cooked()

# Everything in the bowl, gathered under one node so it moves as one dish.
func _dish() -> Node3D:
	var dish := Node3D.new()
	add_child(dish)
	dish.position = bowl.position
	for part: Node3D in [bowl, noodles] + toppings + sauce_dots:
		part.reparent(dish, true)
	return dish

# Pull the chair out, put the bowl and can down on the table, sit, tuck the chair in.
func _sit() -> void:
	world.interactions.erase(table_touch)
	busy = true
	world.player.enabled = false
	var dish: Node3D = can.get_parent()
	camera.global_transform = world.player.camera.global_transform
	camera.make_current()
	dish.reparent(self, false)
	dish.transform = Transform3D(Basis.IDENTITY, TABLE_BOWL)
	can.reparent(self, false)
	can.transform = Transform3D(Basis.IDENTITY, TABLE_CAN)
	sounds.can_on_table.play()
	var chair: Node3D = world.seat_chair
	var tucked := chair.position
	sounds.chair.play()
	var out := create_tween().set_trans(Tween.TRANS_QUAD)
	out.tween_property(chair, "position", tucked + Vector3(0.3, 0, 0), 0.4)
	await _fly("seat", 0.9)
	var tuck := create_tween().set_trans(Tween.TRANS_QUAD)
	tuck.tween_property(chair, "position", tucked + Vector3(0.08, 0, 0), 0.35)
	world.story.sat_down()
	await eat(dish)

# Where the food goes: just under the middle of the view, a hand's length from the face.
func _mouth() -> Vector3:
	return camera.global_position + camera.global_basis * Vector3(0.0, -0.02, -0.15)

# Chopsticks resting in the bowl, sticks rising toward the hand at the lower right.
func _rest_pose(dish: Node3D) -> Transform3D:
	var side := camera.global_basis.x
	var back := camera.global_basis.z
	return Transform3D(_along(side * 0.55 + Vector3.UP * 0.75 + back * 0.4), dish.position + Vector3(0, 0.075, 0) + side * 0.02)

func eat(dish: Node3D) -> void:
	chopsticks = _chopsticks()
	chopsticks.global_transform = _rest_pose(dish)
	sounds.pick_chopsticks.play()
	world.goal.text = "Ăn sáng"
	panel.show()
	var lines := _verdicts()
	var bites := lines.size()
	var side := camera.global_basis.x
	var forward := -camera.global_basis.z
	# At the mouth the sticks run from the lips down and forward to the hand.
	var at_mouth := Transform3D(_along(side * 0.45 - Vector3.UP * 0.65 + forward * 0.45), _mouth())
	for i in range(bites):
		_step("Ăn mì", "Space · gắp (%d/%d)" % [i, bites])
		await acted
		var left := 1.0 - float(i + 1) / bites
		var spot := Vector2.from_angle(i * 2.1) * 0.025
		var dip := Transform3D(_rest_pose(dish).basis, dish.position + Vector3(spot.x, 0.068, spot.y))
		await _move_sticks(dip, 0.22)
		sounds["clink_%d" % (i % 3 + 1)].play()
		var bite := _bite(i, bites)
		# What the bite took leaves the bowl.
		noodles.position.y = 0.035 + 0.027 * left
		noodles.scale = Vector3(0.7 + 0.3 * left, 1.0, 0.7 + 0.3 * left)
		for n in range(toppings.size()):
			if float(n) / toppings.size() >= left and is_instance_valid(toppings[n]):
				toppings[n].hide()
		for dot: Node3D in sauce_dots:
			if randf() > left:
				dot.hide()
		await _move_sticks(at_mouth, 0.45, bite)
		# A moment at the mouth, then the bite is gone.
		await _wait(0.3)
		var munch := create_tween()
		munch.tween_property(bite, "scale", Vector3.ONE * 0.2, 0.15)
		await munch.finished
		bite.queue_free()
		world.think(lines[i], 3.0)
		await _wait(0.2)
		await _move_sticks(_rest_pose(dish), 0.35)
	noodles.hide()
	_step("Uống Xiteen", "Space · uống")
	await acted
	var home := can.transform
	var sip := create_tween().set_trans(Tween.TRANS_QUAD)
	sip.tween_property(can, "global_transform", Transform3D(camera.global_basis * Basis(Vector3.RIGHT, 1.0), _mouth() + camera.global_basis * Vector3(0, -0.02, 0)), 0.45)
	sip.tween_callback(sounds.fizz.play)
	sip.tween_interval(0.8)
	sip.tween_property(can, "transform", home, 0.4)
	await sip.finished
	sounds.can_on_table.play()
	world.think("Khà... Tỉnh cả người.", 3.0)
	await _wait(1.6)
	panel.hide()
	chopsticks.global_transform = Transform3D(_along(Vector3(0, 0.08, 1)), dish.position + Vector3(0.0, 0.1, -0.09))
	# Up from the chair and standing beside it, facing the table.
	var chair: Node3D = world.seat_chair
	sounds.chair.play()
	create_tween().tween_property(chair, "position", chair.position + Vector3(0.22, 0, 0), 0.4)
	world.player.global_position = Vector3(3.95, 0.05, 4.6)
	world.player.yaw = PI * 0.5
	world.player.pitch = -0.45
	await get_tree().process_frame
	await _fly_to(world.player.camera.global_transform, 0.7)
	world.player.camera.make_current()
	busy = false
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.story.ate()

# What hangs from the chopsticks: a tangle of noodles, plus a piece of the topping being eaten.
# It is not parented to the sticks: _move_sticks keeps it at the tips, hanging straight down.
func _bite(index: int, bites: int) -> Node3D:
	var bite := Node3D.new()
	add_child(bite)
	bite.global_position = chopsticks.global_position
	var strands := _noodle_mesh(noodles.material_override, 0.0075, 0.005, 0.035)
	strands.position = Vector3(0, -0.017, 0)
	bite.add_child(strands)
	var from := int(float(index) / bites * toppings.size())
	if from < toppings.size() and toppings[from].has_meta("bite"):
		var piece := MeshInstance3D.new()
		var lump := BoxMesh.new()
		lump.size = Vector3(0.014, 0.005, 0.012)
		piece.mesh = lump
		piece.material_override = toppings[from].get_meta("bite")
		bite.add_child(piece)
		piece.position = Vector3(0.0, -0.004, 0.0)
	return bite

# Moves the chopsticks; a bite they hold follows the tips the whole way.
func _move_sticks(target: Transform3D, seconds: float, bite: Node3D = null) -> void:
	var start := chopsticks.global_transform
	var clock := 0.0
	while clock < seconds:
		await get_tree().process_frame
		clock = minf(clock + get_process_delta_time(), seconds)
		chopsticks.global_transform = start.interpolate_with(target, ease(clock / seconds, -2.0))
		if bite != null:
			bite.global_position = chopsticks.global_position

# One line per bite, from how each part of the cooking went.
func _verdicts() -> Array:
	var lines: Array = []
	var noodle: String = {"hard": "Sợi mì còn dai dai. Kiểu mì trụng.", "good": "Sợi mì vừa tới, dai mềm, thấm gia vị.", "soggy": "Mì nở bung, mềm nhũn."}.get(noodle_result, "Sợi mì vừa tới.")
	lines.append(noodle + (" Hơi ít, rớt mất mấy sợi." if spilled else ""))
	var egg: String = {"raw": "Lòng trắng còn nhớt. Thôi, cũng là protein.", "good": "Trứng ốp la vàng mép, lòng đào chảy ra.", "burnt": "Trứng khét. Vị than hoa."}.get(egg_result, "Trứng ngon.")
	lines.append(egg + (" Rộp... vỏ trứng." if shell else ""))
	lines.append("Xúc xích chiên giòn vỏ. Đúng vị quán net.")
	var amount := float(sauce_dots.size()) / SAUCE_LIMIT
	lines.append("Thiếu tương ớt, thấy thiếu thiếu." if sauce_dots.is_empty() else ("Hơi nhạt, phải chi xịt thêm." if amount < 0.15 else ("Cay xé lưỡi. Chuẩn mì net." if amount > 0.6 else "Tương ớt vừa đủ cay.")))
	var good := int(noodle_result == "good") + int(egg_result == "good") + int(not shell) + int(not spilled) + int(amount >= 0.15 and amount <= 0.6)
	lines.append("Ngon hơn cả tô mì 15 nghìn ở quán net." if good >= 5 else ("Cũng ra gì đấy." if good >= 3 else "Ăn được. Đói thì cái gì cũng ngon."))
	return lines
