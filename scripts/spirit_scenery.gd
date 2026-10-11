extends Node3D

const Rules = preload("res://scripts/realm_prop_rules.gd")
var world: Node3D
var visuals: Array[Dictionary] = []
var shapes: Array[CollisionShape3D] = []
var material_cache := {}
var decor: Node3D
var enabled := false
var moved_instances := 0

func setup(school: Node3D) -> void:
	world = school
	name = "RealmScenery"
	# Cache the normal resources and placements once. Never duplicate the whole
	# campus on B or rebuild its physics/navigation at runtime.
	if school.has_node("RuntimeGeometry"):
		for batch in school.get_node("RuntimeGeometry").get_children():
			var category: int = batch.get_meta("realm_category", -1)
			if category < 0:
				continue
			var original: Material = batch.material_override
			var source: Material = original if original != null else batch.multimesh.mesh.surface_get_material(0)
			visuals.append({"node": batch, "material": original, "cursed": cursed_material(source, category), "placements": batch.get_meta("realm_placements", [])})
		for door in school.get_node("Architecture").get_children():
			if door.has_method("request_toggle"):
				for mesh in door.find_children("*", "MeshInstance3D", true, false):
					visuals.append({"node": mesh, "material": mesh.material_override, "cursed": cursed_material(mesh.material_override, 1), "placements": []})
		if school.has_node("HidingSpots"):
			for mesh in school.get_node("HidingSpots").find_children("*", "MeshInstance3D", true, false):
				var source: Material = mesh.material_override if mesh.material_override != null else mesh.mesh.surface_get_material(0)
				visuals.append({"node": mesh, "material": mesh.material_override, "cursed": cursed_material(source, 2), "placements": []})
	else:
		for mesh in school.find_children("*", "MeshInstance3D", true, false):
			var category := Rules.category_for(mesh, school)
			if mesh.material_override is ShaderMaterial:
				category = 0
			if category < 0 or mesh.get_path().get_concatenated_names().contains("Player"):
				continue
			var source: Material = mesh.material_override if mesh.material_override != null else mesh.mesh.surface_get_material(0)
			visuals.append({"node": mesh, "material": mesh.material_override, "cursed": cursed_material(source, category), "normal": mesh.transform, "realm": mesh.get_parent().global_transform.affine_inverse() * Rules.change_for(mesh, school) * mesh.global_transform, "placements": []})
	for shape in school.find_children("*", "CollisionShape3D", true, false):
		if shape.has_meta("realm_transform"):
			shapes.append(shape)
		elif not school.has_node("RuntimeGeometry"):
			var change := Rules.change_for(shape, school)
			if not change.is_equal_approx(Transform3D.IDENTITY):
				shape.set_meta("normal_transform", shape.transform)
				shape.set_meta("realm_transform", shape.get_parent().global_transform.affine_inverse() * change * shape.global_transform)
				shapes.append(shape)
	decor = Node3D.new()
	decor.name = "Manifestations"
	add_child(decor)
	_build_manifestations()
	decor.hide()

func cursed_material(source: Material, category: int) -> Material:
	var tint := Color(0.38, 0.30, 0.23)
	if source is StandardMaterial3D:
		tint = source.albedo_color
	elif source is ShaderMaterial:
		var value = source.get_shader_parameter("tint")
		if value is Color:
			tint = value
	var key := str(tint) + "/" + str(category)
	if not material_cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/materials/realm_surface.gdshader")
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("category", float(category))
		mat.set_shader_parameter("decay_texture", preload("res://assets/polyhaven_horror/cracked_concrete_diff_1k.jpg") if category == 0 else preload("res://assets/polyhaven_horror/concrete_wall_003_diff_1k.jpg"))
		material_cache[key] = mat
	return material_cache[key]

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	moved_instances = 0
	for entry in visuals:
		var node: GeometryInstance3D = entry.node
		node.material_override = entry.cursed if value else entry.material
		if node is MultiMeshInstance3D and not entry.placements.is_empty():
			var placements: Array = entry.placements if value else node.multimesh.placements
			for index in range(placements.size()):
				node.multimesh.set_instance_transform(index, placements[index])
				if not entry.placements[index].is_equal_approx(node.multimesh.placements[index]):
					moved_instances += 1
		elif node is MeshInstance3D and entry.has("normal"):
			node.transform = entry.realm if value else entry.normal
	for shape in shapes:
		shape.transform = shape.get_meta("realm_transform" if value else "normal_transform")
	decor.visible = value

func _batch(label: String, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> void:
	var instances: MultiMesh = preload("res://scripts/static_multimesh.gd").new()
	instances.mesh = mesh
	instances.placements = transforms
	var bounds := AABB()
	for i in range(transforms.size()):
		var part: AABB = transforms[i] * mesh.get_aabb()
		bounds = part if i == 0 else bounds.merge(part)
	instances.custom_aabb = bounds
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(node)

func _segment(from: Vector3, to: Vector3, radius: float) -> Transform3D:
	var direction := to - from
	var basis := Basis()
	var up := direction.normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.1:
		side = up.cross(Vector3.RIGHT).normalized()
	basis = Basis(side * radius, up * direction.length(), side.cross(up).normalized() * radius)
	return Transform3D(basis, (from + to) * 0.5)

func _build_manifestations() -> void:
	var wood := cursed_material(null, 2)
	# Roots creep along ceilings/windows, leaving the walking floor clear.
	var root_mesh := CylinderMesh.new()
	root_mesh.top_radius = 1.0
	root_mesh.bottom_radius = 1.0
	root_mesh.height = 1.0
	root_mesh.radial_segments = 6
	var roots: Array[Transform3D] = []
	for floor_index in range(3):
		var y := floor_index * 3.9
		for side in [-1, 1]:
			for i in range(19):
				var a := Vector3(side * (23.0 + sin(i * 1.4) * 0.35), y + 2.85 + sin(i * 0.8) * 0.12, 13 + i * 2.2)
				var b := Vector3(side * (23.0 + sin((i + 1) * 1.4) * 0.35), y + 2.85 + sin((i + 1) * 0.8) * 0.12, 13 + (i + 1) * 2.2)
				roots.append(_segment(a, b, 0.065))
				if i % 3 == 0:
					roots.append(_segment(a, a + Vector3(side * -0.45, -0.55, 0.5), 0.035))
		for i in range(17):
			var a := Vector3(0.45 + sin(i * 1.2) * 0.28, y + 2.8, -5 - i * 2)
			var b := Vector3(0.45 + sin((i + 1) * 1.2) * 0.28, y + 2.8, -7 - i * 2)
			roots.append(_segment(a, b, 0.08))
	for side in [-1, 1]:
		for i in range(10):
			var a := Vector3(side * (1.4 + i * 0.8), 0.09, 32 + sin(i * 0.7) * 0.7)
			var b := Vector3(side * (2.2 + i * 0.8), 0.09, 32 + sin((i + 1) * 0.7) * 0.7)
			roots.append(_segment(a, b, 0.10))
	_batch("CreepingRoots", root_mesh, roots, wood)
	# A single flat mesh and one instanced draw for all handprints.
	var hand := _hand_mesh()
	var marks: Array[Transform3D] = []
	for floor_index in range(3):
		var y := floor_index * 3.9
		for side in [-1, 1]:
			for i in range(9):
				marks.append(Transform3D(Basis(Vector3.UP, -side * PI / 2).scaled_local(Vector3.ONE * 0.6), Vector3(side * 24.86, y + 1.25 + (i % 3) * 0.18, 14 + i * 4.5)))
		for i in range(7):
			marks.append(Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3.ONE * 0.55), Vector3(0.14, y + 1.45, -7 - i * 4.5)))
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.09, 0.006, 0.012)
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	_batch("Handprints", hand, marks, ink)
	var stains := StandardMaterial3D.new()
	stains.albedo_texture = preload("res://assets/horror_props/blood_splatter.png")
	stains.albedo_color = Color(0.18, 0.10, 0.11, 0.7)
	stains.uv1_scale = Vector3(0.5, 0.5, 1)
	stains.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stains.cull_mode = BaseMaterial3D.CULL_DISABLED
	stains.roughness = 1.0
	var stain_mesh := QuadMesh.new()
	stain_mesh.size = Vector2(0.85, 1.15)
	var stain_places: Array[Transform3D] = []
	for floor_index in range(3):
		for side in [-1, 1]:
			for index in range(3):
				stain_places.append(Transform3D(Basis.from_euler(Vector3(0, -side * PI / 2, index * 0.9)), Vector3(side * 24.84, floor_index * 3.9 + 0.75 + index * 0.17, 20 + index * 13)))
	_batch("FadedWallStains", stain_mesh, stain_places, stains)
	for floor_index in range(3):
		var y := floor_index * 3.9
		for i in range(3):
			_hanging_chair(Vector3(1.5, y + 2.85, -12 - i * 10), i * 0.7)
	_build_abandoned_traces()
	var pool := CylinderMesh.new()
	pool.top_radius = 2.05
	pool.bottom_radius = 2.05
	pool.height = 0.02
	pool.radial_segments = 32
	_batch("FountainBlackWater", pool, [Transform3D(Basis(), Vector3(0, 0.11, 32))], cursed_material(null, 4))

func _build_abandoned_traces() -> void:
	# Reuse licensed furniture meshes; the vignettes sit against walls and never
	# add collision or change a door, clue, hiding place or navigation surface.
	var rubble := StandardMaterial3D.new()
	rubble.albedo_texture = preload("res://assets/polyhaven_horror/rubble_diff_1k.jpg")
	rubble.albedo_color = Color(0.53, 0.47, 0.43)
	rubble.roughness = 1.0
	rubble.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rubble.vertex_color_use_as_albedo = true
	var patch := _rubble_patch()
	var patches: Array[Transform3D] = []
	var chairs: Array[Transform3D] = []
	var books: Array[Transform3D] = []
	var debris: Array[Transform3D] = []
	var splinters: Array[Transform3D] = []
	for floor_index in range(3):
		var y := floor_index * 3.9
		for side in [-1, 1]:
			for i in range(4):
				var pos := Vector3(side * 24.35, y + 0.045, 18 + i * 9)
				patches.append(Transform3D(Basis(), pos))
				chairs.append(Transform3D(Basis.from_euler(Vector3(0.0, i * 1.3, side * 1.4)).scaled(Vector3.ONE * 0.6), pos + Vector3(0, 0.3, 0)))
				books.append(Transform3D(Basis(Vector3.UP, i * 0.8).scaled(Vector3.ONE * 0.7), pos + Vector3(-side * 0.24, 0.03, 0.6)))
				debris.append(Transform3D(Basis(Vector3.UP, i * 1.7), pos + Vector3(0, 0.01, 0.7)))
				if i % 2 == 0:
					splinters.append(Transform3D(Basis(Vector3.UP, i * 0.9), pos + Vector3(0, 0.01, -0.6)))
		# Books left in a fan at the far end of the connecting passage.
		patches.append(Transform3D(Basis(), Vector3(0.5, y + 0.045, -30)))
		books.append(Transform3D(Basis(Vector3.UP, 0.8).scaled(Vector3.ONE), Vector3(0.5, y + 0.05, -30)))
	_batch("CrumblingPlaster", patch, patches, rubble)
	_asset_batch("OverturnedChairs", "res://assets/kenney_furniture/chair.glb", chairs, 0.9)
	_asset_batch("ScatteredBooks", "res://assets/kenney_furniture/books.glb", books, 0.4)
	_asset_batch("BrokenMasonry", "res://assets/kenney_horror/debris.glb", debris, 0.13, false)
	_asset_batch("BrokenTimber", "res://assets/kenney_horror/debris-wood.glb", splinters, 0.12, false)
	var benches: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-24.2, 0.05, 30)), Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(24.2, 3.95, 39))]
	_asset_batch("BrokenBenches", "res://assets/kenney_horror/bench-damaged.glb", benches, 0.65, false)
	var candles: Array[Transform3D] = [Transform3D(Basis(), Vector3(-46.6, 0.05, -58.1)), Transform3D(Basis(), Vector3(0.5, 3.95, -32)), Transform3D(Basis(), Vector3(-24.4, 7.85, 18))]
	_asset_batch("AbandonedCandles", "res://assets/kenney_horror/candle-multiple.glb", candles, 0.23, false)
	_asset_batch("WarehouseShovel", "res://assets/kenney_horror/shovel.glb", [Transform3D(Basis.from_euler(Vector3(0.0, 0.6, -0.4)), Vector3(-47.4, 0.12, -56.8))], 1.2, false)
	_asset_batch("ForgottenLantern", "res://assets/kenney_horror/lantern-glass.glb", [Transform3D(Basis(), Vector3(-44.2, 0.05, -58.3))], 0.3, false)

func _asset_batch(label: String, path: String, placements: Array[Transform3D], height: float, corrupt := true) -> void:
	var model: Node3D = load(path).instantiate()
	decor.add_child(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var started := false
	for mesh in meshes:
		var local: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = local * mesh.get_aabb()
		bounds = bounds.merge(part) if started else part
		started = true
	var factor := height / maxf(bounds.size.y, 0.01)
	var normalize := Transform3D(Basis().scaled(Vector3.ONE * factor), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor)
	for index in range(meshes.size()):
		var mesh: MeshInstance3D = meshes[index]
		var transforms: Array[Transform3D] = []
		var local: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		for placement in placements:
			transforms.append(placement * normalize * local)
		_batch(label + str(index), mesh.mesh, transforms, cursed_material(null, 2) if corrupt else null)
	model.free()

func _rubble_patch() -> ArrayMesh:
	var vertices := PackedVector3Array([Vector3.ZERO])
	var uv := PackedVector2Array([Vector2(0.5, 0.5)])
	var colors := PackedColorArray([Color.WHITE])
	var indices := PackedInt32Array()
	for i in range(16):
		var angle := i * TAU / 16
		var edge := Vector2(cos(angle), sin(angle)) * (0.88 + sin(i * 2.1) * 0.12)
		vertices.append(Vector3(edge.x * 0.4, 0, edge.y * 1.2))
		uv.append(edge * 0.5 + Vector2.ONE * 0.5)
		colors.append(Color(1, 1, 1, 0))
		indices.append_array(PackedInt32Array([0, 1 + (i + 1) % 16, i + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	for i in range(vertices.size()):
		arrays[Mesh.ARRAY_NORMAL].append(Vector3.UP)
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _hanging_chair(pos: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.name = "SuspendedChair"
	pivot.position = pos
	pivot.rotation = Vector3(0, yaw, PI)
	decor.add_child(pivot)
	var model: Node3D = preload("res://assets/kenney_furniture/chair.glb").instantiate()
	pivot.add_child(model)
	var bounds := AABB()
	var started := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(part) if started else part
		started = true
		mesh.material_override = cursed_material(null, 2)
	var factor := 0.7 / bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor

func _hand_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	# Palm plus five uneven fingers and a dragged wrist smear.
	var rectangles := [Rect2(-0.16, -0.12, 0.32, 0.28), Rect2(-0.25, -0.06, 0.08, 0.25), Rect2(-0.16, 0.10, 0.065, 0.28), Rect2(-0.075, 0.10, 0.065, 0.36), Rect2(0.01, 0.10, 0.065, 0.32), Rect2(0.095, 0.10, 0.065, 0.24), Rect2(-0.10, -0.50, 0.045, 0.42), Rect2(0.025, -0.65, 0.045, 0.54)]
	for rect in rectangles:
		var index := vertices.size()
		for p in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
			vertices.append(Vector3(p.x, p.y, 0))
		indices.append_array(PackedInt32Array([index, index + 1, index + 2, index, index + 2, index + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
