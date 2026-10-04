extends SceneTree

var school: Node3D
var architecture: Node3D
var furniture: Node3D
var atmosphere: Node3D
var wall_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var elevation := 0.0
var landscape: Node3D
var campus: Node3D
var floor_mat: ShaderMaterial
var glass_mat: StandardMaterial3D
var exterior_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var room_catalog: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("build")

func material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func add(parent: Node, child: Node, label: String) -> Node:
	child.name = label
	parent.add_child(child, true)
	child.owner = school
	return child

func box(parent: Node, label: String, pos: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	add(parent, body, label)
	body.position = pos + Vector3(0, elevation, 0)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	add(body, mesh, "Mesh")
	if solid:
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		add(body, collision, "Collision")
	return body

func wall(pos: Vector3, size: Vector3) -> void:
	box(architecture, "Wall", pos, size, wall_mat)
	box(architecture, "PaintedWainscot", Vector3(pos.x, 0.65, pos.z), Vector3(size.x + 0.015, 1.3, size.z + 0.015), trim_mat, false)
	box(architecture, "Skirting", Vector3(pos.x, 0.09, pos.z), Vector3(size.x + 0.035, 0.18, size.z + 0.035), dark_mat, false)

func sign_text(parent: Node, text: String, pos: Vector3, yaw := 0.0, font_size := 40, color := Color(0.72, 0.82, 0.78)) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = font_size
	sign.pixel_size = 0.008
	sign.modulate = color
	sign.outline_size = 0
	sign.no_depth_test = false
	add(parent, sign, "Sign")
	sign.position = pos + Vector3(0, elevation, 0)
	sign.rotation.y = yaw
	return sign

func floor_area(center: Vector2, size: Vector2) -> void:
	box(architecture, "Foundation", Vector3(center.x, -0.16, center.y), Vector3(size.x, 0.3, size.y), dark_mat)
	box(architecture, "PavedFloor", Vector3(center.x, 0.004, center.y), Vector3(size.x, 0.016, size.y), floor_mat, false)
	box(architecture, "Ceiling", Vector3(center.x, 3.7, center.y), Vector3(size.x, 0.18, size.y), wall_mat)

func fixture(pos: Vector3, powered := false) -> void:
	box(atmosphere, "FluorescentHousing", pos, Vector3(0.3, 0.10, 1.6), dark_mat, false)
	box(atmosphere, "FluorescentTube", pos - Vector3(0, 0.06, 0), Vector3(0.20, 0.035, 1.4), material(Color(0.6, 0.82, 0.78), 0.8), false)
	var light := OmniLight3D.new()
	add(atmosphere, light, "CeilingLight")
	light.position = pos + Vector3(0, elevation - 0.3, 0)
	light.light_color = Color(0.56, 0.77, 0.74)
	light.light_energy = 0.65 if powered else 0.35
	light.omni_range = 8.0
	if not powered:
		light.set_meta("flicker", true)

func prop(asset: String, pos: Vector3, height: float, yaw := 0.0, solid := true, nature := false) -> Node3D:
	var directory := "res://assets/kenney_nature/" if nature else "res://assets/kenney_furniture/"
	if asset == "fountain":
		directory = "res://assets/poly_fountain/"
	var packed := load(directory + asset + ".glb") as PackedScene
	assert(packed != null, "Missing asset: " + asset)
	var pivot := Node3D.new()
	add(landscape if nature else furniture, pivot, asset)
	pivot.position = pos + Vector3(0, elevation, 0)
	pivot.rotation.y = yaw
	var model := packed.instantiate() as Node3D
	add(pivot, model, "Model")
	var bounds := AABB()
	var started := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = model.global_transform.affine_inverse() * node.global_transform
		var part: AABB = local * node.get_aabb()
		bounds = bounds.merge(part) if started else part
		started = true
	assert(started)
	if nature:
		# This pack's original GLB materials mark foliage as metallic. Use matte
		# instance materials so leaves retain their colour under the night sky.
		model.scene_file_path = ""
		model.set_meta("source_asset", directory + asset + ".glb")
		for child in model.find_children("*", "", true, false):
			child.owner = school
		for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh_node.mesh.get_surface_count()):
				var source: Material = mesh_node.mesh.surface_get_material(surface)
				if source is StandardMaterial3D:
					var adapted := source.duplicate() as StandardMaterial3D
					adapted.metallic = 0.0
					adapted.roughness = 0.95
					if source.resource_name.begins_with("leafs"):
						adapted.albedo_color = Color(0.50, 0.26, 0.29) if asset.ends_with("fall") else Color(0.19, 0.37, 0.24)
					elif source.resource_name == "grass":
						adapted.albedo_color = Color(0.20, 0.34, 0.22)
					elif source.resource_name == "woodBark":
						adapted.albedo_color = Color(0.28, 0.21, 0.16)
					mesh_node.set_surface_override_material(surface, adapted)
	var factor := height / bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	if solid:
		var body := StaticBody3D.new()
		add(pivot, body, "FurnitureCollision")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.55, height * 0.65, 0.55) if nature and asset.begins_with("tree") else bounds.size * factor
		collision.shape = shape
		collision.position.y = shape.size.y * 0.5
		add(body, collision, "Collision")

	return pivot

func ground_material(tint: Color, paving := 0.0, tile_size := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/materials/ground.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("paving", paving)
	mat.set_shader_parameter("tile_size", tile_size)
	return mat

func window_band(center: Vector2, length: float, along_x: bool) -> void:
	# Solid piers and waist-high masonry enclose the corridor. Only the
	# inset glass openings expose the courtyard or moonlit grounds.
	var bays := maxi(1, int(ceil(length / 4.0)))
	var bay := length / bays
	var opening := minf(2.5, bay - 1.2)
	for i in range(bays):
		var offset := -length * 0.5 + (i + 0.5) * bay
		var pos := Vector3(center.x + (offset if along_x else 0.0), 0, center.y + (0.0 if along_x else offset))
		var lower_size := Vector3(bay, 1.2, 0.25) if along_x else Vector3(0.25, 1.2, bay)
		wall(pos + Vector3(0, 0.6, 0), lower_size)
		box(architecture, "WindowHeader", pos + Vector3(0, 3.1, 0), Vector3(bay, 1.0, 0.25) if along_x else Vector3(0.25, 1.0, bay), wall_mat)
		var pier := (bay - opening) * 0.5
		for side in [-1, 1]:
			var delta: float = side * (opening + pier) * 0.5
			var edge := pos + (Vector3(delta, 1.9, 0) if along_x else Vector3(0, 1.9, delta))
			box(architecture, "WindowPier", edge, Vector3(pier, 1.4, 0.25) if along_x else Vector3(0.25, 1.4, pier), wall_mat)
			var jamb := pos + (Vector3(side * opening * 0.5, 1.9, 0) if along_x else Vector3(0, 1.9, side * opening * 0.5))
			box(architecture, "WindowJamb", jamb, Vector3(0.065, 1.4, 0.30) if along_x else Vector3(0.30, 1.4, 0.065), dark_mat, false)
		box(architecture, "WindowSill", pos + Vector3(0, 1.22, 0), Vector3(opening, 0.08, 0.40) if along_x else Vector3(0.40, 0.08, opening), exterior_mat)
		var pane := box(architecture, "TransparentWindow", pos + Vector3(0, 1.9, 0), Vector3(opening - 0.06, 1.32, 0.025) if along_x else Vector3(0.025, 1.32, opening - 0.06), glass_mat)
		pane.set_meta("transparent_window", true)
		pane.get_node("Mesh").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(architecture, "WindowMullion", pos + Vector3(0, 1.9, 0), Vector3(0.04, 1.4, 0.08) if along_x else Vector3(0.08, 1.4, 0.04), dark_mat, false)

func window_wall(x: float, z: float, length: float) -> void:
	window_band(Vector2(x, z), length, false)

func door_partition(center: Vector2, length: float, along_x: bool, door_offset: float, number: int) -> void:
	var opening := 1.9
	for side in [-1, 1]:
		var edge: float = side * length * 0.5
		var jamb: float = door_offset + side * opening * 0.5
		var span := absf(edge - jamb)
		var mid: float = (edge + jamb) * 0.5
		wall(Vector3(center.x + (mid if along_x else 0.0), 1.8, center.y + (0.0 if along_x else mid)), Vector3(span, 3.6, 0.25) if along_x else Vector3(0.25, 3.6, span))
	var doorway := Vector3(center.x + (door_offset if along_x else 0.0), 0, center.y + (0.0 if along_x else door_offset))
	box(architecture, "ClassroomDoorHeader", doorway + Vector3(0, 3.15, 0), Vector3(opening, 0.9, 0.25) if along_x else Vector3(0.25, 0.9, opening), wall_mat)
	build_classroom_door(doorway, 0.0 if along_x else PI / 2, number)

func build_classroom_door(pos: Vector3, yaw: float, number: int) -> void:
	var doorway := Node3D.new()
	add(architecture, doorway, "ClassroomDoor" + str(number))
	doorway.position = pos + Vector3(0, elevation, 0)
	doorway.rotation.y = yaw
	doorway.set_meta("room_number", number)
	# Build in local coordinates; the moving leaf slides into the adjacent wall.
	var saved := elevation
	elevation = 0.0
	for side in [-1, 1]:
		box(doorway, "DoorFrame", Vector3(side * 0.99, 1.35, 0), Vector3(0.09, 2.7, 0.30), dark_mat, false)
	box(doorway, "DoorLintel", Vector3(0, 2.68, 0), Vector3(2.08, 0.08, 0.3), dark_mat, false)
	box(doorway, "SlidingTrack", Vector3(0.95, 2.74, 0), Vector3(4.0, 0.06, 0.34), dark_mat, false)
	var leaf := AnimatableBody3D.new()
	add(doorway, leaf, "Leaf")
	leaf.collision_layer = 4
	leaf.collision_mask = 3
	box(leaf, "DoorWoodPanel", Vector3(0, 0.87, 0), Vector3(1.87, 1.74, 0.14), wood_mat, false)
	var frosted := material(Color(0.20, 0.28, 0.29))
	box(leaf, "DoorFrostedGlass", Vector3(0, 2.12, 0), Vector3(1.70, 0.77, 0.10), frosted, false)
	for side in [-1, 1]:
		box(leaf, "DoorStile", Vector3(side * 0.90, 1.34, 0), Vector3(0.07, 2.68, 0.16), wood_mat, false)
		box(leaf, "DoorHandle", Vector3(-0.65, 1.1, side * 0.105), Vector3(0.07, 0.28, 0.07), exterior_mat, false)
	box(leaf, "DoorTopRail", Vector3(0, 2.61, 0), Vector3(1.87, 0.13, 0.16), wood_mat, false)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.87, 2.68, 0.16)
	collision.shape = shape
	collision.position.y = 1.34
	add(leaf, collision, "Collision")
	var area := Area3D.new()
	add(doorway, area, "Interaction")
	area.collision_layer = 8
	area.collision_mask = 0
	var target := CollisionShape3D.new()
	var target_shape := BoxShape3D.new()
	target_shape.size = Vector3(1.9, 2.7, 0.32)
	target.shape = target_shape
	target.position.y = 1.35
	add(area, target, "Target")
	doorway.set_script(load("res://scripts/classroom_door.gd"))
	elevation = saved

func lamp(pos: Vector3, tall := true) -> void:
	var height := 3.1 if tall else 1.0
	box(campus, "GardenLampPost", pos + Vector3(0, height * 0.5, 0), Vector3(0.10, height, 0.10), dark_mat)
	box(campus, "LanternFrame", pos + Vector3(0, height, 0), Vector3(0.38, 0.5, 0.38), dark_mat, false)
	box(campus, "LanternGlass", pos + Vector3(0, height, 0), Vector3(0.28, 0.37, 0.28), material(Color(0.91, 0.59, 0.26), 2.0), false)
	box(campus, "LanternCap", pos + Vector3(0, height + 0.3, 0), Vector3(0.50, 0.10, 0.50), dark_mat, false)
	var light := OmniLight3D.new()
	add(atmosphere, light, "GardenLight")
	light.position = pos + Vector3(0, height, 0)
	light.light_color = Color(1.0, 0.66, 0.32)
	light.light_energy = 1.0 if tall else 0.6
	light.omni_range = 8.0 if tall else 4.0

func planter(center: Vector2, size: Vector2) -> void:
	box(campus, "GardenBed", Vector3(center.x, 0.015, center.y), Vector3(size.x, 0.035, size.y), ground_material(Color(0.17, 0.26, 0.15)), false)
	for side in [-1, 1]:
		box(campus, "BedBorder", Vector3(center.x + side * size.x / 2, 0.09, center.y), Vector3(0.16, 0.18, size.y), exterior_mat)
		box(campus, "BedBorder", Vector3(center.x, 0.09, center.y + side * size.y / 2), Vector3(size.x, 0.18, 0.16), exterior_mat)
	for i in range(18):
		var p := Vector3(center.x + rng.randf_range(-size.x * 0.43, size.x * 0.43), 0.04, center.y + rng.randf_range(-size.y * 0.43, size.y * 0.43))
		prop("grass" if i % 3 == 0 else "flower_purpleA", p, rng.randf_range(0.22, 0.42), rng.randf_range(0, TAU), false, true)

func build_sports_court() -> void:
	box(campus, "BasketballCourt", Vector3(44, -0.01, 53), Vector3(19, 0.05, 28), ground_material(Color(0.27, 0.34, 0.33)), false)
	var paint := material(Color(0.69, 0.69, 0.57))
	for x in [-8.5, 8.5]:
		box(campus, "CourtLine", Vector3(44 + x, 0.023, 53), Vector3(0.10, 0.012, 26), paint, false)
	for z in [-13.0, 0.0, 13.0]:
		box(campus, "CourtLine", Vector3(44, 0.023, 53 + z), Vector3(17, 0.012, 0.10), paint, false)
	for z in [40.5, 65.5]:
		box(campus, "HoopPost", Vector3(44, 1.8, z), Vector3(0.16, 3.6, 0.16), dark_mat)
		box(campus, "Backboard", Vector3(44, 3.25, z), Vector3(1.9, 1.2, 0.12), exterior_mat, false)
		box(campus, "BackboardTarget", Vector3(44, 3.25, z + (0.07 if z < 53 else -0.07)), Vector3(0.60, 0.40, 0.025), paint, false)
		var hoop := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.23
		ring.outer_radius = 0.27
		hoop.mesh = ring
		hoop.material_override = material(Color(0.6, 0.21, 0.12))
		add(campus, hoop, "BasketballRim")
		hoop.position = Vector3(44, 2.96, z + (0.42 if z < 53 else -0.42))
	sign_text(campus, "SPORTS / 立入禁止", Vector3(44, 0.6, 39.5), 0, 22)

func build_night() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	settings.sky = Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/materials/night_sky.gdshader")
	settings.sky.sky_material = sky_mat
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.55, 0.61, 0.70)
	settings.ambient_light_energy = 0.40
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.fog_enabled = true
	settings.fog_light_color = Color(0.075, 0.11, 0.17)
	settings.fog_density = 0.0028
	settings.fog_sky_affect = 0.12
	env.environment = settings
	add(atmosphere, env, "MoonlitEnvironment")
	var moon := DirectionalLight3D.new()
	add(atmosphere, moon, "Moonlight")
	moon.light_color = Color(0.75, 0.82, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.shadow_bias = 0.08
	moon.shadow_normal_bias = 1.5
	moon.directional_shadow_max_distance = 130.0
	moon.look_at_from_position(Vector3(0.58, 0.40, -0.71) * 100, Vector3.ZERO)

func build() -> void:
	school = Node3D.new()
	school.name = "School"
	get_root().add_child(school)
	school.set_script(load("res://scripts/world.gd"))
	architecture = add(school, Node3D.new(), "Architecture")
	furniture = add(school, Node3D.new(), "Furniture")
	atmosphere = add(school, Node3D.new(), "Atmosphere")
	landscape = add(school, Node3D.new(), "Landscape")
	campus = add(school, Node3D.new(), "Campus")
	rng.seed = 240903
	floor_mat = ground_material(Color(0.43, 0.44, 0.40), 1.0)
	exterior_mat = material(Color(0.69, 0.65, 0.53))
	wall_mat = material(Color(0.55, 0.54, 0.46))
	trim_mat = material(Color(0.13, 0.25, 0.23))
	dark_mat = material(Color(0.065, 0.08, 0.09))
	wood_mat = material(Color(0.26, 0.19, 0.13))
	glass_mat = material(Color(0.37, 0.57, 0.68, 0.06))
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for floor_index in range(3):
		elevation = floor_index * 3.9
		build_north_wing(floor_index + 1)
		build_side_wing(-1, floor_index + 1)
		build_side_wing(1, floor_index + 1)
		build_connector(floor_index + 1)
		build_annex(floor_index + 1)
	elevation = 0.0
	build_stairwell()
	build_service_storage()
	build_campus()
	preload("res://tools/perimeter_builder.gd").build(school)
	school.set_meta("room_catalog", room_catalog)
	preload("res://tools/hiding_builder.gd").build(school)
	build_night()
	build_player()
	preload("res://tools/navigation_builder.gd").bake(school)
	var scene := PackedScene.new()
	assert(scene.pack(school) == OK)
	assert(ResourceSaver.save(scene, "res://scenes/school.tscn") == OK)
	print("Saved A + B campus: ", school.find_children("*", "", true, false).size(), " nodes")
	preload("res://tools/runtime_optimizer.gd").save_runtime(school)
	quit()

func build_player() -> void:
	var player := CharacterBody3D.new()
	add(school, player, "Player")
	player.position = Vector3(0, 0.05, 64)
	player.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add(player, collision, "Collision")
	var camera := Camera3D.new()
	camera.position.y = 1.62
	camera.current = true
	camera.fov = 73
	camera.near = 0.05
	camera.far = 500
	add(player, camera, "Camera3D")
	var flashlight := SpotLight3D.new()
	flashlight.position = Vector3(0.18, -0.13, -0.12)
	flashlight.light_color = Color(1.0, 0.89, 0.69)
	flashlight.light_energy = 1.15
	flashlight.spot_range = 22
	flashlight.spot_angle = 34
	flashlight.spot_attenuation = 0.7
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.2
	flashlight.shadow_normal_bias = 2.0
	add(camera, flashlight, "Flashlight")
	player.set_script(load("res://scripts/player.gd"))

const ROOM_TITLES := {
	"classroom": "LỚP HỌC", "library": "THƯ VIỆN", "computer": "PHÒNG MÁY TÍNH",
	"lab": "PHÒNG THÍ NGHIỆM", "staff": "PHÒNG GIÁO VIÊN", "infirmary": "PHÒNG Y TẾ",
	"art": "PHÒNG MỸ THUẬT", "music": "PHÒNG ÂM NHẠC", "lecture": "PHÒNG ĐA NĂNG",
	"club": "PHÒNG CÂU LẠC BỘ", "archive": "PHÒNG LƯU TRỮ", "storage": "KHO THIẾT BỊ"
}

func register_room(x: float, z: float, width: float, depth: float, number: int, kind: String, block: String, variant := 0, turn := false) -> void:
	room_catalog.append({"number": number, "kind": kind, "label": ROOM_TITLES[kind], "block": block,
		"center": Vector3(x, elevation, z), "size": Vector2(width, depth), "layout": variant})
	var door: Node3D = architecture.get_node("ClassroomDoor" + str(number))
	door.set("room_label", ROOM_TITLES[kind])
	door.set_meta("room_kind", kind)
	var starts := [architecture.get_child_count(), furniture.get_child_count(), atmosphere.get_child_count()]
	furnish_room(x, z, width, depth, number, kind, variant)
	if turn:
		# South-facing rooms put the teaching wall opposite the entrance too.
		var groups := [architecture, furniture, atmosphere]
		var center := Vector3(x, elevation, z)
		for i in range(groups.size()):
			for child_index in range(starts[i], groups[i].get_child_count()):
				var node: Node3D = groups[i].get_child(child_index)
				node.position = center + Basis(Vector3.UP, PI) * (node.position - center)
				node.rotation.y += PI

func student_desk(pos: Vector3, yaw := PI, computer := false) -> void:
	prop("desk", pos, 0.78, yaw)
	var behind := Vector3(sin(yaw), 0, cos(yaw)) * -0.85
	prop("chairDesk" if computer else "chair", pos + behind, 0.85, yaw)
	if computer:
		prop("computerScreen", pos + Vector3(0, 0.78, 0), 0.48, yaw, false)
		prop("computerKeyboard", pos + Vector3(0, 0.78, 0.28), 0.04, yaw, false)

func furnish_room(x: float, z: float, width: float, depth: float, number: int, kind: String, variant: int) -> void:
	var front := z - depth * 0.5
	var left := x - width * 0.5
	var right := x + width * 0.5
	match kind:
		"classroom", "computer", "lecture":
			var rows := mini(6, int((depth - 6.0) / 2.3))
			for row in range(rows):
				for col in range(4):
					var offset: float = [-4.5, -2.2, 2.2, 4.5][col]
					var p := Vector3(x + offset, 0, front + 4.0 + row * 2.3)
					if kind == "classroom" and variant % 3 == 1:
						# Facing pairs form work islands, separated by wide aisles.
						p.z = front + 4.0 + (row / 2) * 4.2 + (row % 2) * 1.5
						student_desk(p, 0.0 if row % 2 == 0 else PI)
					elif kind == "classroom" and variant % 3 == 2:
						# U arrangement: leave a broad discussion space in the middle.
						if col == 1 or col == 2:
							if row != rows - 1:
								continue
						student_desk(p, PI if col in [1, 2] else (-PI / 2 if col == 0 else PI / 2))
					else:
						student_desk(p, PI, kind == "computer")
			prop("desk", Vector3(x, 0, front + 1.6), 0.85)
			box(architecture, "Blackboard", Vector3(x, 1.9, front + 0.20), Vector3(minf(8, width - 2), 1.6, 0.07), trim_mat, false)
			sign_text(architecture, "%s / %d" % [ROOM_TITLES[kind], number % 1000], Vector3(x, 1.95, front + 0.25), 0, 26)
		"library", "archive", "storage":
			var shelf_rows := maxi(3, int((depth - 5.0) / 2.2)) if kind == "library" else 3
			for row in range(shelf_rows):
				for side in [-1, 1]:
					var shelf := Vector3(x + side * (width * 0.5 - 2.2), 0, front + 3 + row * (2.2 if kind == "library" else 4))
					prop("bookcaseOpen", shelf, 2.3, side * PI / 2)
					for level in [0.65, 1.35]:
						if kind == "library":
							for offset in [-0.2, 0.0, 0.2]:
								prop("books", shelf + Vector3(0, level, offset), 0.35, side * PI / 2, false)
						else:
							prop("cardboardBoxClosed", shelf + Vector3(0, level, 0), 0.45, 0, false)
			if kind == "library":
				if width >= 18:
					for side in [-1, 1]:
						for row in range(4):
							var shelf := Vector3(x + side * 5.0, 0, front + 3 + row * 3.5)
							prop("bookcaseOpen", shelf, 2.3, side * PI / 2)
							for level in [0.65, 1.35]:
								for offset in [-0.2, 0.0, 0.2]:
									prop("books", shelf + Vector3(0, level, offset), 0.35, side * PI / 2, false)
				for side in [-1, 1]:
					for row in range(2):
						student_desk(Vector3(x + side * 2.5, 0, front + 5 + row * 4), -side * PI / 2)
			else:
				for row in range(3):
					prop("cardboardBoxClosed", Vector3(x - 2.5, 0, front + 4 + row * 2), 0.9)
					prop("cardboardBoxClosed", Vector3(x - 2.5, 0.9, front + 4 + row * 2), 0.65, 0, false)
				prop("coatRackStanding", Vector3(right - 1.2, 0, z + depth * 0.5 - 2), 1.8)
		"lab", "art":
			for row in range(3):
				for side in [-1, 1]:
					var p := Vector3(x + side * 3.8, 0, front + 4 + row * 3.5)
					student_desk(p, -side * PI / 2)
					student_desk(p + Vector3(0, 0, 1.4), side * PI / 2)
					if kind == "lab":
						box(furniture, "LabTray", p + Vector3(0, 0.81, 0), Vector3(0.55, 0.07, 0.35), dark_mat, false)
						for col in range(3):
							box(furniture, "SampleContainer", p + Vector3(-0.17 + col * 0.17, 0.94, 0), Vector3(0.09, 0.20, 0.09), material(Color(0.26, 0.45, 0.50)), false)
					else:
						prop("books", p + Vector3(0, 0.78, 0), 0.10, 0, false)
			prop("bookcaseOpen", Vector3(left + 1.5, 0, front + 1.5), 2.2)
			prop("desk", Vector3(x, 0, front + 1.5), 0.85)
		"staff", "club":
			for row in range(2):
				for side in [-1, 1]:
					student_desk(Vector3(x + side * 3.2, 0, front + 4 + row * 4), side * PI / 2, kind == "staff")
			prop("bookcaseOpen", Vector3(left + 1.5, 0, front + 1.3), 2.1)
			prop("coatRackStanding", Vector3(right - 1.2, 0, front + 1.4), 1.8)
			prop("bench", Vector3(x, 0, z + depth * 0.5 - 2.5), 0.85)
		"infirmary":
			for row in range(3):
				var p := Vector3(left + 3.0, 0, front + 3 + row * 4.5)
				var bed := prop("bench", p, 0.65, PI / 2)
				bed.scale.z = 1.5
				box(furniture, "MedicalMattress", p + Vector3(0, 0.72, 0), Vector3(2.6, 0.18, 1.1), material(Color(0.58, 0.66, 0.65)), false)
			student_desk(Vector3(right - 3, 0, front + 3), PI, true)
			prop("bookcaseOpen", Vector3(right - 1.5, 0, front + 1), 2)
			sign_text(architecture, "＋ Y TẾ / FIRST AID", Vector3(x, 2.0, front + 0.20), 0, 30)
		"music":
			# Semicircle seating faces a low rehearsal platform.
			box(architecture, "RehearsalPlatform", Vector3(x, 0.10, front + 2), Vector3(width - 3, 0.2, 2.5), wood_mat)
			for i in range(9):
				var angle := PI * 0.12 + i * PI * 0.76 / 8
				prop("chair", Vector3(x + cos(angle) * 4, 0, front + 4 + sin(angle) * 5), 0.85, PI)
			prop("bookcaseOpen", Vector3(left + 1.5, 0, z + depth * 0.5 - 2), 2.1)
	for offset in [-width * 0.25, width * 0.25]:
		fixture(Vector3(x + offset, 3.48, z), true)
	prop("trashcan", Vector3(right - 1.0, 0, front + 1.2), 0.65)

func window_wall_z(z: float, x: float, length: float) -> void:
	window_band(Vector2(x, z), length, true)

func gallery_rail(center: Vector3, length: float, along_x := false) -> void:
	var size := Vector3(length, 0.10, 0.10) if along_x else Vector3(0.10, 0.10, length)
	box(architecture, "GalleryHandrail", center + Vector3(0, 1.15, 0), size, dark_mat)
	box(architecture, "GalleryLowerRail", center + Vector3(0, 0.4, 0), size, dark_mat, false)
	var posts := int(length / 2.0)
	for i in range(posts + 1):
		var offset := -length / 2 + i * length / posts
		box(architecture, "GalleryBaluster", center + (Vector3(offset, 0.6, 0) if along_x else Vector3(0, 0.6, offset)), Vector3(0.07, 1.2, 0.07), dark_mat, false)

func build_north_wing(floor_number: int) -> void:
	floor_area(Vector2(0, 7.5), Vector2(76, 3))
	box(architecture, "CorridorDroppedCeiling", Vector3(0, 3.05, 7.5), Vector3(76, 0.18, 3), wall_mat)
	var kinds: Array = [
		["staff", "classroom", "classroom", "infirmary"],
		["computer", "classroom", "classroom", "lab"],
		["art", "classroom", "classroom", "music"]][floor_number - 1]
	for index in range(4):
		var x: float = [-29.5, -14.5, 14.5, 29.5][index]
		var number := floor_number * 100 + index + 1
		floor_area(Vector2(x, -3), Vector2(15, 18))
		window_wall_z(-12, x, 15)
		for edge in [-7.5, 7.5]:
			wall(Vector3(x + edge, 1.8, -3), Vector3(0.25, 3.6, 18))
		door_partition(Vector2(x, 6), 15, true, 0.0, number)
		register_room(x, -3, 15, 18, number, kinds[index], "A", (index + floor_number) % 3)
		sign_text(architecture, "A-%d / %s" % [number, ROOM_TITLES[kinds[index]]], Vector3(x, 2.87, 6.2), 0, 20)
	for x in [-38.0, 38.0]:
		wall(Vector3(x, 1.8, 7.5), Vector3(0.25, 3.6, 3))
	if floor_number == 1:
		for side in [-1, 1]:
			window_wall_z(9, side * 11.8, 20.4)
		box(architecture, "MainEntranceHeader", Vector3(0, 3.1, 9), Vector3(3.2, 1.0, 0.25), wall_mat)
	else:
		window_wall_z(9, 0, 44)
	for x in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		fixture(Vector3(x, 2.85, 7.5), false)
	sign_text(architecture, "A / TẦNG %d  ·  CẦU THANG ↑  ·  KHU B ↑" % floor_number, Vector3(0, 2.8, 5.9), 0, 22)
	box(architecture, "FloorBand", Vector3(0, 3.65, 9.1), Vector3(76, 0.22, 0.35), dark_mat, false)

func build_side_wing(side: int, floor_number: int) -> void:
	var x := side * 31.5
	floor_area(Vector2(side * 23.5, 32.5), Vector2(3, 47))
	box(architecture, "CorridorDroppedCeiling", Vector3(side * 23.5, 3.05, 32.5), Vector3(3, 0.18, 47), wall_mat)
	floor_area(Vector2(x, 32), Vector2(13, 48))
	for z in [8.0, 32.0, 56.0]:
		wall(Vector3(x, 1.8, z), Vector3(13, 3.6, 0.25))
	var kinds: Array = ([["library", "classroom"], ["classroom", "club"], ["archive", "classroom"]] if side == -1 else [["classroom", "storage"], ["lab", "classroom"], ["classroom", "lecture"]])[floor_number - 1]
	for index in range(2):
		var z := 20.0 + index * 24.0
		window_wall(side * 38.0, z, 24)
		var number := floor_number * 100 + index + (5 if side == -1 else 7)
		door_partition(Vector2(side * 25.0, z), 24, false, 5.0, number)
		register_room(x, z, 13, 24, number, kinds[index], "A", (index + floor_number + (1 if side > 0 else 0)) % 3)
		sign_text(architecture, "A-%d / %s" % [number, ROOM_TITLES[kinds[index]]], Vector3(side * 24.8, 2.87, z + 5.0), -side * PI / 2, 20)
	window_wall(side * 22.0, 32.5, 47)
	if floor_number > 1:
		wall(Vector3(side * 23.5, 1.8, 56), Vector3(3, 3.6, 0.25))
	else:
		for offset in [-1.30, 1.30]:
			wall(Vector3(side * 23.5 + offset, 1.8, 56), Vector3(0.40, 3.6, 0.25))
		box(architecture, "WingEntranceHeader", Vector3(side * 23.5, 3.1, 56), Vector3(2.2, 1.0, 0.25), wall_mat)
	for z in [15.0, 29.0, 43.0, 53.0]:
		fixture(Vector3(side * 23.5, 2.85, z), false)
	box(architecture, "WingFloorBand", Vector3(side * 21.95, 3.65, 32.5), Vector3(0.32, 0.22, 47), dark_mat, false)

func build_connector(floor_number: int) -> void:
	floor_area(Vector2(1.5, -21.5), Vector2(3, 35))
	box(architecture, "ConnectorLowCeiling", Vector3(1.5, 3.05, -21.5), Vector3(3, 0.18, 35), wall_mat)
	window_wall(0, -21.5, 35)
	window_wall(3, -21.5, 35)
	for z in [-8.0, -18.0, -28.0, -37.0]:
		fixture(Vector3(1.5, 2.85, z), false)
	sign_text(architecture, "KHU B ↑ / TẦNG %d" % floor_number, Vector3(1.5, 2.75, -5.5), 0, 22)
	sign_text(architecture, "KHU A ↑", Vector3(1.5, 2.75, -37.5), PI, 22)

func build_annex(floor_number: int) -> void:
	floor_area(Vector2(0, -40.5), Vector2(64, 3))
	box(architecture, "AnnexLowCeiling", Vector3(0, 3.05, -40.5), Vector3(64, 0.18, 3), wall_mat)
	var kinds: Array = [
		["library", "classroom", "lab", "staff", "infirmary"],
		["computer", "classroom", "art", "archive", "classroom"],
		["lecture", "classroom", "music", "club", "storage"]][floor_number - 1]
	for index in range(5):
		var north := index < 3
		var x: float = [-21.0, 0.0, 21.0, -21.0, 21.0][index]
		var z := -52.0 if north else -31.0
		var width := 20.0 if index == 1 else 22.0
		var depth := 20.0 if north else 16.0
		var front := -42.0 if north else -39.0
		var number := 1000 + floor_number * 100 + index + 1
		floor_area(Vector2(x, z), Vector2(width, depth))
		window_wall_z(-62 if north else -23, x, width)
		for side in [-1, 1]:
			wall(Vector3(x + side * width * 0.5, 1.8, z), Vector3(0.25, 3.6, depth))
		door_partition(Vector2(x, front), width, true, 0, number)
		register_room(x, z, width, depth, number, kinds[index], "B", (index + floor_number) % 3, not north)
		sign_text(architecture, "B-%d / %s" % [number % 1000, ROOM_TITLES[kinds[index]]], Vector3(x, 2.87, front + (0.2 if north else -0.2)), 0 if north else PI, 20)
	# Close the southern side of the hall around the connector mouth.
	for x in [-5.0, 6.5]:
		wall(Vector3(x, 1.8, -39), Vector3(10 if x < 0 else 7, 3.6, 0.25))
	if floor_number == 1:
		for z in [-41.8, -39.2]:
			wall(Vector3(-32, 1.8, z), Vector3(0.25, 3.6, 0.4))
		box(architecture, "AnnexServiceExitHeader", Vector3(-32, 3.1, -40.5), Vector3(0.25, 1.0, 2.2), wall_mat)
	else:
		window_wall(-32, -40.5, 3)
	window_wall(32, -40.5, 3)
	for x in [-25.0, -12.0, 1.5, 14.0, 27.0]:
		fixture(Vector3(x, 2.85, -40.5), false)
	sign_text(architecture, "B / THƯ VIỆN · LỚP HỌC · PHÒNG CHỨC NĂNG", Vector3(1.5, 2.8, -41.8), 0, 20)

func build_service_storage() -> void:
	floor_area(Vector2(-45, -53), Vector2(12, 12))
	for x in [-51.0, -39.0]:
		wall(Vector3(x, 1.8, -53), Vector3(0.25, 3.6, 12))
	wall(Vector3(-45, 1.8, -59), Vector3(12, 3.6, 0.25))
	door_partition(Vector2(-45, -47), 12, true, 0, 990)
	register_room(-45, -53, 12, 12, 990, "storage", "SERVICE")
	prop("desk", Vector3(-45, 0, -56), 0.85)
	sign_text(architecture, "NHÀ KHO / THIẾT BỊ TRƯỜNG", Vector3(-45, 3.15, -46.8), 0, 24)
	box(campus, "StorageRoof", Vector3(-45, 3.95, -53), Vector3(12.5, 0.20, 12.5), dark_mat)

func stair_floor(center: Vector2, dimensions: Vector2, height: float) -> void:
	box(architecture, "StairLanding", Vector3(center.x, height - 0.10, center.y), Vector3(dimensions.x, 0.20, dimensions.y), floor_mat)

func build_stairwell() -> void:
	# The stairwell is open through all three storeys, with separate landing
	# pieces so an upper floor never caps the route up the stairs.
	stair_floor(Vector2(0, 1), Vector2(14, 10), 0)
	# Door-sized connections open the back of each stair landing to block B.
	for x in [-3.5, 5.0]:
		box(architecture, "StairwellBack", Vector3(x, 5.8, -4), Vector3(7 if x < 0 else 4, 11.6, 0.25), exterior_mat)
	for floor_index in range(3):
		box(architecture, "ConnectorEntryHeader", Vector3(1.5, floor_index * 3.9 + 3.2, -4), Vector3(3, 1.4, 0.25), exterior_mat)
	box(architecture, "StairwellRoof", Vector3(0, 15.55, 1), Vector3(14, 0.20, 10), exterior_mat)
	box(architecture, "RooftopStairBack", Vector3(0, 13.6, -4), Vector3(14, 3.8, 0.25), exterior_mat)
	box(architecture, "RooftopStairWest", Vector3(-7, 13.6, 1), Vector3(0.25, 3.8, 10), exterior_mat)
	box(architecture, "RooftopStairFront", Vector3(0, 13.6, 6), Vector3(14, 3.8, 0.25), exterior_mat)
	# East side stays open to step out onto the rooftop.
	box(architecture, "RooftopExitHeader", Vector3(7, 14.95, 1), Vector3(0.25, 1.1, 10), exterior_mat)
	sign_text(architecture, "SÂN THƯỢNG →", Vector3(0, 13.7, -3.8), 0, 30)
	for height in [3.9, 7.8, 11.7]:
		stair_floor(Vector2(1.9, 2), Vector2(10.2, 8), height)
		stair_floor(Vector2(-6.7, 2), Vector2(0.6, 8), height)
		stair_floor(Vector2(0, -3), Vector2(14, 2), height)
		gallery_rail_at_height(height)
	for floor_index in range(3):
		var height := floor_index * 3.9
		var ramp := StaticBody3D.new()
		add(architecture, ramp, "StairRamp" + str(floor_index + 1))
		var collision := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		var vertices := PackedVector3Array()
		for x in [-6.3, -3.3]:
			vertices.append(Vector3(x, height, 6))
			vertices.append(Vector3(x, height - 0.2, 6))
			vertices.append(Vector3(x, height + 3.9, -2))
			vertices.append(Vector3(x, height + 3.7, -2))
		shape.points = vertices
		collision.shape = shape
		add(ramp, collision, "SmoothStairCollider")
		for step in range(24):
			var z := 6.0 - (step + 0.5) * 8.0 / 24.0
			var y := height + (step + 0.5) * 3.9 / 24.0
			box(architecture, "StairTread", Vector3(-4.8, y - 0.04, z), Vector3(3.0, 0.08, 8.0 / 24.0), exterior_mat, false)
			box(architecture, "StairRiser", Vector3(-4.8, y - 0.08, z - 4.0 / 24.0), Vector3(3.0, 0.16, 0.03), exterior_mat, false)
		for x in [-6.25, -3.35]:
			var rail := box(architecture, "StairHandrail", Vector3(x, height + 2.95, 2), Vector3(0.08, 0.08, sqrt(64 + 3.9 * 3.9)), dark_mat, false)
			rail.rotation.x = atan(3.9 / 8.0)
		for i in range(5):
			var z := 6.0 - i * 2.0
			box(architecture, "StairRailPost", Vector3(-3.35, height + i * 3.9 / 4 + 0.5, z), Vector3(0.08, 1.0, 0.08), dark_mat, false)
	for floor_index in range(3):
		sign_text(architecture, "TẦNG " + str(floor_index + 1) + " / 1–2–3", Vector3(1.6, floor_index * 3.9 + 1.8, -3.8), 0, 30)
		var light := OmniLight3D.new()
		add(atmosphere, light, "StairwellLight")
		light.position = Vector3(0, floor_index * 3.9 + 2.8, 0)
		light.light_color = Color(0.83, 0.68, 0.43)
		light.light_energy = 0.7
		light.omni_range = 7

func gallery_rail_at_height(height: float) -> void:
	var saved := elevation
	elevation = height
	gallery_rail(Vector3(-3.25, 0, 2), 8)
	elevation = saved

func build_campus() -> void:
	var grass_mat := ground_material(Color(0.22, 0.30, 0.20))
	var paving_mat := ground_material(Color(0.52, 0.50, 0.43), 1.0, 1.5)
	box(campus, "CampusGround", Vector3(0, -0.26, 19), Vector3(120, 0.45, 126), grass_mat)
	box(campus, "CourtyardPaving", Vector3(0, -0.015, 32), Vector3(44, 0.045, 44), paving_mat, false)
	box(campus, "ApproachWalk", Vector3(0, -0.014, 66), Vector3(8, 0.048, 24), paving_mat, false)
	box(campus, "FrontCrossWalk", Vector3(0, -0.014, 60), Vector3(100, 0.048, 4), paving_mat, false)
	box(campus, "GardenWalk", Vector3(-46, -0.014, 25), Vector3(3, 0.048, 66), paving_mat, false)
	# Imported fountain is the courtyard's focal point. Walkways split around it.
	prop("fountain", Vector3(0, 0.02, 32), 2.8)
	var particles := CPUParticles3D.new()
	add(campus, particles, "FountainWaterSpray")
	particles.position = Vector3(0, 2.75, 32)
	particles.amount = 90
	particles.lifetime = 1.6
	particles.direction = Vector3.UP
	particles.spread = 9.0
	particles.initial_velocity_min = 1.3
	particles.initial_velocity_max = 2.2
	particles.gravity = Vector3(0, -3.2, 0)
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	particles.mesh = drop
	particles.material_override = material(Color(0.42, 0.63, 0.73), 0.25)
	for side in [-1, 1]:
		planter(Vector2(side * 12, 24), Vector2(10, 12))
		planter(Vector2(side * 12, 43), Vector2(10, 10))
		prop("tree_detailed", Vector3(side * 12, 0.05, 24), 7.1, side * 0.5, true, true)
		prop("tree_oak", Vector3(side * 12, 0.05, 44), 7.0, side, true, true)
		prop("tree_detailed_fall", Vector3(side * 21, 0.05, 65), 7.1, side * 0.7, true, true)
		for z in [20.0, 37.0, 50.0]:
			prop("bench", Vector3(side * 19.0, 0.02, z), 0.85, -side * PI / 2)
		for z in [16.0, 46.0, 62.0, 75.0]:
			lamp(Vector3(side * 5.7, 0, z))
		for z in [21.0, 39.0, 53.0]:
			lamp(Vector3(side * 20, 0, z), false)
		for z in range(-32, 76, 9):
			prop("tree_oak" if z % 2 else "tree_pineRoundB", Vector3(side * rng.randf_range(49, 55), 0, z), rng.randf_range(7, 11), rng.randf() * TAU, true, true)
		for z in range(-36, 76, 3):
			prop("plant_bush", Vector3(side * 56.5, 0, z), 1.0, rng.randf() * TAU, false, true)
		box(campus, "BoundaryWall", Vector3(side * 58, 0.55, 19), Vector3(0.30, 1.1, 118), exterior_mat)
		box(campus, "FrontBoundary", Vector3(side * 30.5, 0.55, 78), Vector3(55, 1.1, 0.30), exterior_mat)
		for z in range(-40, 79, 3):
			box(campus, "FencePost", Vector3(side * 58, 1.7, z), Vector3(0.09, 1.8, 0.09), dark_mat)
		box(campus, "FenceTopRail", Vector3(side * 58, 2.55, 19), Vector3(0.07, 0.07, 118), dark_mat, false)
		box(campus, "GatePillar", Vector3(side * 3.3, 1.7, 78), Vector3(0.65, 3.4, 0.65), exterior_mat)
		lamp(Vector3(side * 4.5, 0, 77))
	box(campus, "ClosedCampusGate", Vector3(0, 1.3, 78), Vector3(6, 2.6, 0.10), dark_mat)
	box(campus, "BackBoundary", Vector3(0, 1.25, -82), Vector3(116, 2.5, 0.30), exterior_mat)
	for x in range(-54, 55, 8):
		prop("tree_pineRoundB", Vector3(x, 0, -76), rng.randf_range(8.0, 12.0), rng.randf() * TAU, true, true)
	for i in range(28):
		var p := Vector3(rng.randf_range(-54, -40), 0, rng.randf_range(-15, 50))
		prop("stone_largeA" if i % 2 else "plant_bushLarge", p, rng.randf_range(0.35, 0.9), rng.randf() * TAU, false, true)
		prop("grass", p + Vector3(0.8, 0, 0.4), 0.35, 0, false, true)
	box(campus, "GardenPondBorder", Vector3(-45, 0.04, 43), Vector3(9, 0.08, 8), dark_mat, false)
	var water := material(Color(0.08, 0.19, 0.25))
	water.roughness = 0.2
	water.metallic = 0.15
	box(campus, "GardenPondWater", Vector3(-45, 0.09, 43), Vector3(8.5, 0.03, 7.5), water, false)
	for i in range(12):
		var angle := i * TAU / 12.0
		prop("stone_largeC", Vector3(-45 + cos(angle) * 4.5, 0, 43 + sin(angle) * 4), 0.6, angle, false, true)
	build_sports_court()
	build_rear_grounds()
	build_rooftop()
	# Roof pieces leave a real opening over the stair flights.
	for side in [-1, 1]:
		box(campus, "SchoolRoofNorth", Vector3(side * 22.75, 11.60, -1.5), Vector3(31.5, 0.2, 22), dark_mat)
	box(campus, "SchoolRoofNorthBack", Vector3(0, 11.60, -8.25), Vector3(14, 0.2, 8.5), dark_mat)
	box(campus, "SchoolRoofNorthFront", Vector3(0, 11.60, 7.75), Vector3(14, 0.2, 3.5), dark_mat)
	for side in [-1, 1]:
		box(campus, "SchoolRoofWing", Vector3(side * 30, 11.60, 33), Vector3(16.5, 0.2, 47), dark_mat)
	box(campus, "ClockTower", Vector3(0, 12.6, 7.8), Vector3(5.4, 4.4, 2.5), exterior_mat)
	box(campus, "ClockTowerCap", Vector3(0, 14.95, 7.8), Vector3(6, 0.3, 3), dark_mat)
	var clock := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.10
	clock.mesh = disc
	clock.material_override = material(Color(0.78, 0.73, 0.56), 0.22)
	add(campus, clock, "ClockFace")
	clock.position = Vector3(0, 13, 9.13)
	clock.rotation.x = PI / 2
	box(campus, "ClockHourHand", Vector3(0.21, 13.05, 9.2), Vector3(0.55, 0.07, 0.04), dark_mat, false)
	var hand := box(campus, "ClockMinuteHand", Vector3(-0.1, 13.35, 9.2), Vector3(0.07, 0.8, 0.04), dark_mat, false)
	hand.rotation.z = -0.35
	sign_text(campus, "A / N E H   A C A D E M Y", Vector3(0, 3.3, 10.2), 0, 36, Color(0.85, 0.78, 0.57))
	sign_text(campus, "CỔNG CHÍNH", Vector3(0, 3.35, 77.7), PI, 24)
	box(campus, "CampusNoticeBoard", Vector3(-6.3, 1.4, 66), Vector3(3.0, 1.8, 0.15), wood_mat)
	sign_text(campus, "NEH / KHU A + B\nKhu B qua hành lang sau cầu thang\nNhà kho ở sân dịch vụ phía Tây\n← Vườn phía Tây     Sân thể thao →", Vector3(-6.3, 1.4, 66.09), 0, 20)

func build_rear_grounds() -> void:
	box(campus, "RearCampusGround", Vector3(0, -0.26, -64), Vector3(120, 0.45, 40), ground_material(Color(0.22, 0.30, 0.20)))
	box(campus, "ServiceWalk", Vector3(-38.5, -0.014, -40.5), Vector3(14, 0.048, 3), floor_mat, false)
	box(campus, "StorageApproach", Vector3(-45, -0.014, -44), Vector3(3, 0.048, 8), floor_mat, false)
	for side in [-1, 1]:
		box(campus, "RearSideBoundary", Vector3(side * 58, 0.55, -61), Vector3(0.30, 1.1, 42), exterior_mat)
		box(campus, "RearFenceRail", Vector3(side * 58, 2.55, -61), Vector3(0.07, 0.07, 42), dark_mat, false)
		for z in range(-82, -40, 3):
			box(campus, "RearFencePost", Vector3(side * 58, 1.7, z), Vector3(0.09, 1.8, 0.09), dark_mat)
	box(campus, "AnnexRoofNorth", Vector3(0, 11.75, -52), Vector3(64.5, 0.2, 20.5), dark_mat)
	box(campus, "AnnexRoofHall", Vector3(0, 11.75, -40.5), Vector3(64.5, 0.2, 3.5), dark_mat)
	for side in [-1, 1]:
		box(campus, "AnnexRoofSouth", Vector3(side * 21, 11.75, -31), Vector3(22.5, 0.2, 16.5), dark_mat)
	# Match A's rooftop: the old 15 cm lip trapped the non-jumping player.
	box(campus, "ConnectorRoof", Vector3(1.5, 11.60, -21.5), Vector3(3.5, 0.2, 35), dark_mat)
	lamp(Vector3(-35, 0, -38.5))
	lamp(Vector3(-47, 0, -44))
	sign_text(campus, "B / KHU HỌC TẬP VÀ CHỨC NĂNG", Vector3(1.5, 3.3, -38.7), 0, 26)

func build_rooftop() -> void:
	var mat := material(Color(0.30, 0.33, 0.32))
	box(architecture, "RooftopBackParapet", Vector3(0, 12.30, -12.3), Vector3(77, 1.2, 0.25), exterior_mat)
	box(architecture, "RooftopCourtyardParapet", Vector3(0, 12.30, 9.1), Vector3(44, 1.2, 0.25), exterior_mat)
	for side in [-1, 1]:
		box(architecture, "RooftopOuterParapet", Vector3(side * 38.2, 12.30, 21.85), Vector3(0.25, 1.2, 68.3), exterior_mat)
		box(architecture, "RooftopInnerParapet", Vector3(side * 21.9, 12.30, 32.5), Vector3(0.25, 1.2, 47), exterior_mat)
		box(architecture, "RooftopEndParapet", Vector3(side * 30, 12.30, 56), Vector3(16.5, 1.2, 0.25), exterior_mat)
		for z in [19.0, 43.0]:
			box(campus, "RooftopVentilation", Vector3(side * 32, 12.35, z), Vector3(3.5, 1.3, 2.2), mat)
			for row in range(5):
				box(campus, "VentGrille", Vector3(side * 32, 12.03 + row * 0.13, z + 1.11), Vector3(2.9, 0.045, 0.03), dark_mat, false)
	box(campus, "RooftopWaterTank", Vector3(-29, 13.0, -6), Vector3(5, 2.6, 4), mat)
	box(campus, "RooftopMaintenanceCabinet", Vector3(26, 12.60, -7), Vector3(3.8, 1.8, 2), wood_mat)
	sign_text(architecture, "KHU A / SÂN THƯỢNG", Vector3(15, 13.05, -12.1), 0, 30)
