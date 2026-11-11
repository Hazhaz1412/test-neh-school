@tool
extends RefCounted
# Turns the plan into a town: asphalt, wires, river, salt fields and the named places. The
# ordinary houses on every other lot come from town_houses.gd.
const Batch := preload("res://scripts/town/mesh_batch.gd")
const Houses := preload("res://scripts/town/town_houses.gd")
const TEXTURE := "res://assets/polyhaven_town/textures/%s_%s.jpg"
const SCHOOL_X := 262.0
# Plastic table sets at the size adults sit at; town_diners seats people on them.
const CHAIR_SCALE := 0.85
const CHAIR_OFFSET := 0.7
const SEAT_HEIGHT := 0.38
const TABLE_TOP := 0.66
const TABLE_SIZE := 0.76
# The model is about 197 units long and its nose points +Z; the game's forward is -Z.
const SCOOTER_FRAME := Transform3D(Basis(Vector3(-0.0094, 0, 0), Vector3(0, 0.0094, 0), Vector3(0, 0, -0.0094)), Vector3.ZERO)
var scooter_mesh: Mesh
var plan: RefCounted
var batch := Batch.new()
var root: Node3D
var materials := {}
var rng := RandomNumberGenerator.new()
var solids: StaticBody3D
var signs_root: Node3D
var scatter := {}
var triangles := 0
# Every table set built: {"frame": table centre on the ground, "along": street direction, "inside": in a shop}.
var tables: Array = []

func build(owner: Node3D, town_plan: RefCounted) -> void:
	root = owner
	plan = town_plan
	rng.seed = 90210
	_make_materials()
	solids = StaticBody3D.new()
	solids.name = "Solids"
	root.add_child(solids)
	signs_root = Node3D.new()
	signs_root.name = "Signs"
	root.add_child(signs_root)
	_ground()
	for road in plan.roads:
		_road(road)
	_junctions()
	var houses := Houses.new(self)
	for lot in plan.lots:
		if not _landmark(lot):
			houses.build(lot)
	houses.back_blocks()
	for road in plan.roads:
		_wires(road)
		_street_life(road)
	_river()
	_fields()
	_school()
	_roadside()
	_edges()
	var meshes := Node3D.new()
	meshes.name = "Meshes"
	root.add_child(meshes)
	triangles = batch.bake(meshes, materials, {"rail": 150.0, "grille": 150.0, "cable": 220.0, "lit": 260.0, "paint": 300.0})
	_bake_scatter()
	scooter_mesh = _scooter_source()

func _scooter_source() -> Mesh:
	return _model_mesh("res://assets/polypizza_town/low_poly_scooter.glb", SCOOTER_FRAME, true)

func _texture(name: String, scale: float, tinted := true, roughness := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TEXTURE % [name, "diff"])
	material.normal_enabled = true
	material.normal_texture = load(TEXTURE % [name, "nor"])
	material.normal_scale = 0.8
	material.roughness = roughness
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.vertex_color_use_as_albedo = tinted
	return material

func _school_texture(name: String, scale: float) -> StandardMaterial3D:
	var material := _texture("white_plaster_02", scale)
	material.albedo_texture = load("res://assets/polyhaven_school/%s_diff_1k.jpg" % name)
	material.normal_texture = load("res://assets/polyhaven_school/%s_nor_1k.jpg" % name)
	return material

func _plain(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = true
	# Palette colours are authored in sRGB; read raw they wash every sign out to pastel.
	material.vertex_color_is_srgb = true
	return material

func _make_materials() -> void:
	materials = {
		"asphalt": _texture("asphalt_02", 0.31, false),
		"paver": _texture("concrete_pavers", 0.75),
		"concrete": _school_texture("dirty_concrete", 0.3),
		"plaster": _texture("white_plaster_02", 0.28),
		"aged": _school_texture("worn_plaster_wall", 0.24),
		"tile": _texture("square_tiled_wall", 0.6),
		"shutter": _texture("painted_metal_shutter", 0.42),
		"rust": _texture("rusty_metal_shutter", 0.42),
		"tin": _texture("corrugated_iron", 0.34),
		"rust_tin": _texture("rusty_corrugated_iron", 0.34),
		"roof": _texture("clay_roof_tiles", 0.4),
		"dirt": _texture("dirt", 0.14),
		"mud": _texture("brown_mud", 0.12),
		"brick": _texture("red_brick", 0.8),
		"peel": _texture("damaged_plaster", 0.45),
		"mossy": _texture("worn_mossy_plasterwall", 0.25),
		"yellow": _texture("yellow_plaster", 0.3),
		"cladding": _texture("exterior_wall_cladding_03", 0.4),
		"stone": _texture("stone_tile_wall", 0.33),
		"granite": _texture("granite_tile_03", 0.7, true, 0.45),
		"wood": _school_texture("rough_wood", 0.5),
		"pane": _plain(Color(0.20, 0.27, 0.32), 0.1, 0.5),
		"paint": _plain(Color.WHITE),
		"cable": _plain(Color(0.03, 0.03, 0.035), 0.7),
		"steel": _plain(Color(0.75, 0.77, 0.78), 0.32, 0.9),
		"glass": _plain(Color(0.10, 0.13, 0.16), 0.18, 0.0),
	}
	materials.asphalt.albedo_color = Color(0.72, 0.72, 0.74)
	materials.glass.metallic_specular = 0.3
	materials.plaster.albedo_color = Color(1.28, 1.26, 1.22)
	materials.aged.albedo_color = Color(1.4, 1.38, 1.32)
	materials.paver.albedo_color = Color(0.92, 1.0, 1.1)
	materials.mossy.albedo_color = Color(1.25, 1.22, 1.15)
	materials.yellow.albedo_color = Color(1.3, 1.25, 1.1)
	materials.lit = _plain(Color.WHITE)
	materials.lit.emission_enabled = true
	materials.lit.emission_energy_multiplier = 1.5
	materials.lit.emission = Color(1.0, 0.86, 0.62)
	materials.lantern = _plain(Color(0.6, 0.04, 0.02))
	materials.lantern.emission_enabled = true
	materials.lantern.emission = Color(1.0, 0.08, 0.03)
	materials.lantern.emission_energy_multiplier = 3.0
	materials.rail = _plain(Color(0.10, 0.11, 0.12), 0.6, 0.3)
	materials.rail.albedo_texture = _rail_texture()
	materials.rail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	materials.rail.alpha_scissor_threshold = 0.5
	materials.rail.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials.rail.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# The same bars in whatever colour the ironwork was painted.
	materials.grille = materials.rail.duplicate()
	materials.grille.albedo_color = Color.WHITE

func _rail_texture() -> ImageTexture:
	var image := Image.create(64, 64, true, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var solid: bool = y < 7 or y > 58 or x % 16 < 3 or (y > 26 and y < 31)
			image.set_pixel(x, y, Color(1, 1, 1, 1.0 if solid else 0.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _flat(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)

func _solid(frame: Transform3D, centre: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = frame.translated_local(centre)
	solids.add_child(shape)

func _ground() -> void:
	batch.at(Vector3.ZERO)
	batch.facing(Vector3.UP, "concrete", Vector3(-420, -0.03, -300), Vector3(BridgeLimit(), -0.03, -300), Vector3(BridgeLimit(), -0.03, 300), Vector3(-420, -0.03, 300), Color(0.62, 0.62, 0.60))

func BridgeLimit() -> float:
	return plan.BRIDGE_START - 2.0

func _road(road: Dictionary) -> void:
	if road.kind == "bridge":
		_bridge(road)
		return
	var surface: String = "concrete" if road.kind == "alley" else "asphalt"
	var half: float = road.width * 0.5
	var tint := Color(0.70, 0.70, 0.68) if road.kind == "alley" else Color.WHITE
	for i in range(road.path.size() - 1):
		var a: Vector2 = road.path[i]
		var b: Vector2 = road.path[i + 1]
		var na: Vector2 = _side(road, i)
		var nb: Vector2 = _side(road, i + 1)
		batch.at(_flat(a))
		batch.facing(Vector3.UP, surface, _flat(a - na * half), _flat(b - nb * half), _flat(b + nb * half), _flat(a + na * half), tint)
		if road.walk > 0.0:
			_sidewalk(road, i, a, b, na, nb, half, 1.0)
			_sidewalk(road, i, a, b, na, nb, half, -1.0)
		if road.kind != "alley" and i % 5 < 2 and not plan.in_corridor(a, 0.0, road.index, true):
			batch.facing(Vector3.UP, "paint", _flat(a - na * 0.07, 0.02), _flat(b - nb * 0.07, 0.02), _flat(b + nb * 0.07, 0.02), _flat(a + na * 0.07, 0.02), Color(0.86, 0.86, 0.80))
		if road.kind == "country":
			for side in [-1.0, 1.0]:
				var low: float = plan.FIELD_LEVEL - 0.06
				var ea: Vector2 = a + na * side * half
				var eb: Vector2 = b + nb * side * half
				batch.facing(Vector3.UP, "dirt", _flat(ea + na * side * 1.6, low), _flat(eb + nb * side * 1.6, low), _flat(eb, 0.0), _flat(ea, 0.0), Color(0.62, 0.60, 0.54))

func _side(road: Dictionary, index: int) -> Vector2:
	var tangent: Vector2 = road.tangents[index]
	return Vector2(-tangent.y, tangent.x)

func _sidewalk(road: Dictionary, i: int, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, half: float, side: float) -> void:
	var mid: Vector2 = (a + b) * 0.5 + (na + nb) * 0.5 * side * (half + road.walk * 0.5)
	if plan.in_corridor(mid, 0.2, road.index, true) or plan.in_corridor((a + b) * 0.5 + (na + nb) * 0.5 * side * (half + 0.2), 0.2, road.index, true):
		return
	var y: float = plan.KERB
	var inner_a: Vector3 = _flat(a + na * side * half, y)
	var inner_b: Vector3 = _flat(b + nb * side * half, y)
	var outer_a: Vector3 = _flat(a + na * side * (half + road.walk), y)
	var outer_b: Vector3 = _flat(b + nb * side * (half + road.walk), y)
	var tone := 0.70 + 0.06 * sin(i * 1.7)
	batch.facing(Vector3.UP, "paver", inner_a, inner_b, outer_b, outer_a, Color(tone, tone, tone))
	var kerb_side := Vector3(-na.x * side, 0, -na.y * side)
	batch.facing(kerb_side, "paint", Vector3(inner_a.x, 0, inner_a.z), Vector3(inner_b.x, 0, inner_b.z), inner_b, inner_a, Color(0.58, 0.58, 0.56))

func _junctions() -> void:
	var seen := {}
	for road in plan.roads:
		if road.kind in ["alley", "bridge", "country"]:
			continue
		for i in range(0, road.path.size(), 3):
			var other: Dictionary = plan.nearest(road.path[i], road.index)
			if other.is_empty() or other.distance > 1.5 or plan.roads[other.road].kind in ["alley", "bridge", "country"]:
				continue
			var key := Vector2i(mini(road.index, other.road), maxi(road.index, other.road))
			if seen.has(key):
				continue
			seen[key] = true
			_traffic_lights(road, i)

func _traffic_lights(road: Dictionary, index: int) -> void:
	var at: Vector2 = road.path[index]
	var along: Vector2 = road.tangents[index]
	var across := Vector2(-along.y, along.x)
	batch.at(_flat(at))
	var half: float = road.width * 0.5
	for side in [-1.0, 1.0]:
		var foot: Vector2 = at + across * side * (half + 7.0) + along * side * (half + 3.2)
		var frame := Transform3D(Basis.IDENTITY, _flat(foot, plan.KERB))
		batch.box("paint", frame, Vector3(0, 2.9, 0), Vector3(0.14, 5.8, 0.14), Color(0.30, 0.32, 0.34))
		batch.box("paint", frame, Vector3(0, 4.9, 0), Vector3(0.34, 1.0, 0.34), Color(0.05, 0.05, 0.05))
		var lamp := Transform3D(Basis.IDENTITY, _flat(foot, plan.KERB + 4.6))
		batch.box("lit", lamp, Vector3(0, 0, 0), Vector3(0.36, 0.2, 0.36), Color(0.2, 1.0, 0.35))
		_solid(frame, Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))

func _frame(lot: Dictionary) -> Transform3D:
	var inward := Vector3(lot.normal.x, 0, lot.normal.y)
	var x := Vector3.UP.cross(inward).normalized()
	return Transform3D(Basis(x, Vector3.UP, inward), _flat(lot.front, 0.0))

# The named places that have a building of their own; every other lot is an ordinary house.
func _landmark(lot: Dictionary) -> bool:
	var frame := _frame(lot)
	batch.at(frame.origin)
	match lot.get("place", {}).get("style", ""):
		"market":
			_market(lot, frame)
		"civic":
			_civic(lot, frame)
		"stall":
			_stall(lot, frame)
		"curio":
			_curio(lot, frame)
		_:
			return false
	return true

func _civic(lot: Dictionary, frame: Transform3D) -> void:
	var place: Dictionary = lot.place
	var w: float = lot.width
	var d: float = lot.depth
	var height: float = place.floors * plan.FLOOR + 0.8
	batch.box("plaster", frame, Vector3(0, height * 0.5, d * 0.5 + 1.0), Vector3(w, height, d - 2.0), place.tint)
	_solid(frame, Vector3(0, 6, d * 0.5 + 1.0), Vector3(w, 12, d - 2.0))
	for x in range(-3, 4):
		var at := x * 2.1
		batch.box("plaster", frame, Vector3(at, height * 0.5, 0.2), Vector3(0.42, height, 0.42), Color(0.95, 0.92, 0.84))
		_solid(frame, Vector3(at, 2, 0.2), Vector3(0.42, 4, 0.42))
		if x < 3:
			batch.box("glass", frame, Vector3(at + 1.05, 1.55, 1.97), Vector3(1.55, 2.5, 0.04), Color.WHITE)
			batch.box("glass", frame, Vector3(at + 1.05, 5.1, 1.97), Vector3(1.4, 1.9, 0.04), Color.WHITE)
	batch.box("plaster", frame, Vector3(0, plan.FLOOR, 0.9), Vector3(w, 0.28, 2.3), Color(0.95, 0.92, 0.84))
	batch.box("roof", frame, Vector3(0, height + 0.15, d * 0.5), Vector3(w + 0.6, 0.3, d + 0.4), Color(0.74, 0.46, 0.34))
	batch.box("paint", frame, Vector3(0, height - 0.6, -0.08), Vector3(w * 0.72, 0.9, 0.12), place.sign)
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = place.label.to_upper()
	label.font_size = 72
	label.pixel_size = 0.0075
	label.modulate = Color(0.98, 0.95, 0.82)
	label.shaded = true
	label.double_sided = false
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(0, height - 0.6, -0.16))
	signs_root.add_child(label)

func _stall(lot: Dictionary, frame: Transform3D) -> void:
	var w: float = lot.width
	var d: float = lot.depth
	for corner in [Vector2(-1, 0.1), Vector2(1, 0.1), Vector2(-1, 1), Vector2(1, 1)]:
		var post := Vector3(corner.x * w * 0.45, 1.25, corner.y * d * 0.9)
		batch.box("paint", frame, post, Vector3(0.1, 2.5 + (0.3 if corner.y > 0.5 else 0.0), 0.1), Color(0.34, 0.26, 0.18))
		_solid(frame, post, Vector3(0.14, 3, 0.14))
	var roof := [frame * Vector3(-w * 0.55, 2.3, -0.3), frame * Vector3(w * 0.55, 2.3, -0.3), frame * Vector3(w * 0.55, 2.8, d), frame * Vector3(-w * 0.55, 2.8, d)]
	batch.quad("paint", roof[1], roof[0], roof[3], roof[2], Color(0.18, 0.36, 0.58))
	batch.quad("paint", roof[0], roof[1], roof[2], roof[3], Color(0.14, 0.28, 0.46))
	batch.box("paint", frame, Vector3(0, 0.34, 1.7), Vector3(1.6, 0.68, 0.7), Color(0.46, 0.32, 0.20))
	batch.box("steel", frame, Vector3(-0.4, 0.86, 1.7), Vector3(0.26, 0.34, 0.26))
	_solid(frame, Vector3(0, 0.4, 1.7), Vector3(1.6, 0.8, 0.7))
	batch.box("paint", frame, Vector3(0, 2.0, -0.28), Vector3(3.2, 0.42, 0.05), Color(0.92, 0.88, 0.76))
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = lot.place.label.to_upper()
	label.font_size = 48
	label.pixel_size = 0.0058
	label.modulate = Color(0.12, 0.12, 0.14)
	label.shaded = true
	label.double_sided = false
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(0, 2.0, -0.32))
	signs_root.add_child(label)

func _market(lot: Dictionary, frame: Transform3D) -> void:
	var place: Dictionary = lot.place
	var w: float = lot.width
	var d: float = lot.depth
	var height := 5.4
	for x in range(-5, 6, 2):
		for z in range(0, 5, 2):
			var column := Vector3(x * w / 10.0, height * 0.5, 1.0 + z * (d - 2.0) / 4.0)
			batch.box("paint", frame, column, Vector3(0.2, height, 0.2), Color(0.24, 0.30, 0.30))
			_solid(frame, Vector3(column.x, 2, column.z), Vector3(0.3, 4, 0.3))
	batch.quad("rust_tin", frame * Vector3(w * 0.5 + 0.6, height, -0.8), frame * Vector3(-w * 0.5 - 0.6, height, -0.8), frame * Vector3(-w * 0.5 - 0.6, height + 2.4, d * 0.5), frame * Vector3(w * 0.5 + 0.6, height + 2.4, d * 0.5), Color(0.82, 0.78, 0.70))
	batch.quad("tin", frame * Vector3(-w * 0.5 - 0.6, height, d + 0.8), frame * Vector3(w * 0.5 + 0.6, height, d + 0.8), frame * Vector3(w * 0.5 + 0.6, height + 2.4, d * 0.5), frame * Vector3(-w * 0.5 - 0.6, height + 2.4, d * 0.5), Color(0.82, 0.80, 0.74))
	batch.quad("rust_tin", frame * Vector3(-w * 0.5 - 0.6, height, -0.8), frame * Vector3(w * 0.5 + 0.6, height, -0.8), frame * Vector3(w * 0.5 + 0.6, height + 2.4, d * 0.5), frame * Vector3(-w * 0.5 - 0.6, height + 2.4, d * 0.5), Color(0.5, 0.48, 0.44))
	for row in range(4):
		for x in range(-4, 5):
			var at := Vector3(x * w / 9.0, 0.45, 3.5 + row * (d - 7.0) / 3.0)
			if x % 3 == 0:
				continue
			batch.box("paint", frame, at, Vector3(2.8, 0.9, 1.5), Color(0.52, 0.42, 0.32))
			_solid(frame, at, Vector3(2.8, 1.0, 1.5))
			for n in range(14):
				batch.box("paint", frame, at + Vector3(rng.randf_range(-1.2, 1.2), 0.55, rng.randf_range(-0.6, 0.6)), Vector3(0.3, 0.2, 0.26), Houses.GOODS[rng.randi() % Houses.GOODS.size()])
			batch.quad("paint", frame * Vector3(at.x - 1.6, 2.5, at.z + 0.9), frame * Vector3(at.x + 1.6, 2.5, at.z + 0.9), frame * Vector3(at.x + 1.6, 2.2, at.z - 0.9), frame * Vector3(at.x - 1.6, 2.2, at.z - 0.9), Houses.AWNINGS[rng.randi() % Houses.AWNINGS.size()])
	batch.quad("rust_tin", frame * Vector3(w * 0.5 + 0.6, height + 2.4, d * 0.5), frame * Vector3(-w * 0.5 - 0.6, height + 2.4, d * 0.5), frame * Vector3(-w * 0.5 - 0.6, height, d + 0.8), frame * Vector3(w * 0.5 + 0.6, height, d + 0.8), Color(0.5, 0.48, 0.44))
	batch.box("paint", frame, Vector3(0, height + 0.5, -0.9), Vector3(13, 1.0, 0.14), Color(0.72, 0.12, 0.10))
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = place.label.to_upper()
	label.font_size = 84
	label.pixel_size = 0.0085
	label.modulate = Color(0.99, 0.90, 0.40)
	label.shaded = true
	label.double_sided = false
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(0, height + 0.5, -0.98))
	signs_root.add_child(label)

# The shop the map leaves out: half-shuttered, one red lantern, no name over the door.
func _curio(lot: Dictionary, frame: Transform3D) -> void:
	var w: float = lot.width
	var d: float = lot.depth
	var dark := Color(0.20, 0.24, 0.24)
	var height: float = plan.FLOOR * 2.0
	batch.box("aged", frame, Vector3(0, height * 0.5 + plan.FLOOR * 0.5, d * 0.5), Vector3(w, height - plan.FLOOR, d), dark)
	batch.box("aged", frame, Vector3(0, plan.FLOOR * 0.5, d * 0.5 + 1.5), Vector3(w, plan.FLOOR, d - 3.0), dark.darkened(0.3))
	for side in [-1.0, 1.0]:
		batch.box("aged", frame, Vector3(side * (w * 0.5 - 0.15), plan.FLOOR * 0.5, 1.5), Vector3(0.3, plan.FLOOR, 3.0), dark)
		_solid(frame, Vector3(side * (w * 0.5 - 0.15), 6, 1.5), Vector3(0.3, 12, 3.0))
	batch.box("plaster", frame, Vector3(0, plan.FLOOR - 0.05, 1.5), Vector3(w, 0.1, 3.0), Color(0.16, 0.14, 0.13), false)
	_solid(frame, Vector3(0, 6, d * 0.5 + 1.5), Vector3(w, 12, d - 3.0))
	batch.box("rust", frame, Vector3(0, plan.FLOOR - 0.65, 0.2), Vector3(w - 0.6, 1.3, 0.06), Color(0.46, 0.42, 0.38))
	batch.box("paint", frame, Vector3(0, 0.5, 2.0), Vector3(w - 1.2, 1.0, 0.6), Color(0.22, 0.13, 0.08))
	_solid(frame, Vector3(0, 0.5, 2.0), Vector3(w - 1.2, 1.0, 0.6))
	for shelf in range(3):
		var y := 1.2 + shelf * 0.5
		batch.box("paint", frame, Vector3(0, y, 2.86), Vector3(w - 1.0, 0.04, 0.24), Color(0.16, 0.10, 0.07))
		for n in range(9):
			batch.box("paint", frame, Vector3(-w * 0.36 + n * w * 0.09, y + 0.11, 2.86), Vector3(0.14, rng.randf_range(0.1, 0.28), 0.14), Color(0.72, 0.56, 0.20).darkened(rng.randf() * 0.6))
	batch.box("cable", frame, Vector3(1.2, plan.FLOOR - 0.28, -0.3), Vector3(0.02, 0.5, 0.02))
	batch.box("lantern", frame, Vector3(1.2, plan.FLOOR - 0.72, -0.3), Vector3(0.34, 0.42, 0.34))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.34, 0.16)
	glow.light_energy = 2.2
	glow.omni_range = 6.0
	root.add_child(glow)
	glow.global_position = frame * Vector3(1.2, plan.FLOOR - 0.9, 0.3)

func _wires(road: Dictionary) -> void:
	if road.kind in ["bridge"]:
		return
	var alley: bool = road.kind == "alley"
	var spacing: int = 12 if alley else 15
	var side := 1.0
	var offset: float = road.width * 0.5 + (0.4 if road.walk > 0.0 else -0.1)
	var last := Vector3.INF
	for i in range(3, road.path.size() - 2, spacing):
		var foot: Vector2 = road.path[i] + _side(road, i) * side * offset
		if plan.in_corridor(foot, 0.3, road.index, true):
			last = Vector3.INF
			continue
		var top := Vector3(foot.x, 7.8 if not alley else 6.2, foot.y)
		batch.at(top)
		if not alley:
			_pole(foot, road, i, side)
		if last != Vector3.INF:
			_cables(last, top, 7 if not alley else 4)
		last = top

func _pole(foot: Vector2, road: Dictionary, index: int, side: float) -> void:
	var y: float = plan.KERB if road.walk > 0.0 else 0.0
	var along: Vector2 = road.tangents[index]
	var frame := Transform3D(Basis(Vector3.UP, atan2(along.x, along.y)), _flat(foot, y))
	batch.box("concrete", frame, Vector3(0, 4.3, 0), Vector3(0.26, 8.6, 0.26), Color(0.74, 0.74, 0.72))
	batch.box("paint", frame, Vector3(0, 7.6, 0), Vector3(1.5, 0.1, 0.1), Color(0.30, 0.30, 0.32))
	batch.box("paint", frame, Vector3(0, 6.9, 0), Vector3(1.1, 0.08, 0.08), Color(0.30, 0.30, 0.32))
	_solid(frame, Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
	if index % 45 == 0:
		batch.box("paint", frame, Vector3(0.4, 5.3, 0), Vector3(0.6, 1.1, 0.5), Color(0.52, 0.54, 0.52))
	# Service loops of spare cable, the knot every Vietnamese pole carries.
	for n in range(6):
		var height := rng.randf_range(6.1, 7.3)
		var knot := frame * Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.8, 0.8)), Vector3(rng.randf_range(-0.2, 0.2), height, 0.15))
		batch.box("cable", knot, Vector3.ZERO, Vector3(rng.randf_range(0.5, 1.0), 0.05, 0.05))
	# Lamp arm over the carriageway.
	var over: Vector2 = Vector2(-along.y, along.x) * -side
	var arm := Vector3(over.x, 0, over.y)
	var lamp := Transform3D(Basis.IDENTITY, _flat(foot, y + 6.6))
	if index % 30 == 3:
		batch.quad("paint", lamp.origin + Vector3.UP * 0.05, lamp.origin + arm * 1.8 + Vector3.UP * 0.5, lamp.origin + arm * 1.8 + Vector3.UP * 0.45, lamp.origin, Color(0.25, 0.25, 0.26))
		batch.box("lit", Transform3D(Basis.IDENTITY, lamp.origin + arm * 1.8 + Vector3.UP * 0.42), Vector3.ZERO, Vector3(0.5, 0.08, 0.2), Color(1.0, 0.9, 0.75))

func _cables(from: Vector3, to: Vector3, count: int) -> void:
	for n in range(count):
		var offset := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-1.0, 0.1), rng.randf_range(-0.25, 0.25))
		var sag := rng.randf_range(0.25, 0.8)
		var width := rng.randf_range(0.018, 0.04)
		var previous := from + offset
		for segment in range(1, 9):
			var t := segment / 8.0
			var point := from.lerp(to, t) + offset * (1.0 - absf(t - 0.5)) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			batch.quad("cable", previous + Vector3.UP * width, point + Vector3.UP * width, point - Vector3.UP * width, previous - Vector3.UP * width)
			batch.quad("cable", previous - Vector3.UP * width, point - Vector3.UP * width, point + Vector3.UP * width, previous + Vector3.UP * width)
			previous = point

func _add_scatter(model: String, transform: Transform3D, color := Color.WHITE) -> void:
	var key := [model, Vector2i(floori(transform.origin.x / batch.CHUNK), floori(transform.origin.z / batch.CHUNK))]
	if not scatter.has(key):
		scatter[key] = []
	scatter[key].append([transform, color])

func _street_life(road: Dictionary) -> void:
	if road.kind == "bridge" or road.kind == "country":
		return
	var i := 4
	while i < road.path.size() - 4:
		i += rng.randi_range(4, 12)
		if i >= road.path.size():
			return
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var normal := _side(road, i) * side
		var spot: Vector2 = road.path[i] + normal * (road.width * 0.5 + maxf(road.walk * 0.55, -0.6))
		if plan.in_corridor(spot, 0.1, road.index, true) or (road.walk == 0.0 and rng.randf() < 0.6):
			continue
		var along: Vector2 = road.tangents[i]
		var roll := rng.randf()
		var y: float = plan.KERB if road.walk > 0.0 else 0.0
		if roll < 0.5:
			var angle := atan2(normal.x, normal.y) + rng.randf_range(-0.25, 0.25)
			for n in range(rng.randi_range(2, 6)):
				var at: Vector2 = spot + along * (n * 0.82 - 1.5)
				var tone := Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.5), rng.randf_range(0.35, 0.95))
				_add_scatter("scooter", Transform3D(Basis(Vector3.UP, angle), _flat(at, y)), tone)
		elif roll < 0.72 and road.walk > 1.9:
			_sidewalk_seats(spot, along, y)
		elif roll < 0.9 and road.kind in ["main", "street"]:
			var tree: Vector2 = road.path[i] + normal * (road.width * 0.5 + 0.8)
			if not plan.in_corridor(tree, 0.2, road.index, true):
				_add_scatter("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.36, 0.46)), _flat(tree, y)))
				_solid(Transform3D(Basis.IDENTITY, _flat(tree)), Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))
		else:
			var clutter: String = ["pot", "crate", "box", "meter"][rng.randi() % 4]
			var size: float = {"pot": 3.0, "crate": 1.0, "box": 1.0, "meter": 1.0}[clutter]
			for n in range(rng.randi_range(1, 3)):
				_add_scatter(clutter, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), _flat(spot + along * n * 0.7 + normal * 0.9, y)))

func _sidewalk_seats(spot: Vector2, along: Vector2, y: float, inside := false) -> void:
	var colours := [Color(0.72, 0.10, 0.10), Color(0.12, 0.28, 0.62), Color(0.90, 0.72, 0.16)]
	var tint: Color = colours[rng.randi() % colours.size()]
	for n in range(4):
		# Each chair is turned from its own offset: the model's seat faces +Z, so +Z is aimed back
		# at the table. A shared angle plus quarter turns would not do, because Vector2.rotated and
		# a basis about Y turn opposite ways and two of the four chairs end up facing out.
		var out: Vector2 = along.rotated(n * PI * 0.5)
		_add_scatter("chair", Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.y)).scaled(Vector3.ONE * CHAIR_SCALE), _flat(spot + out * CHAIR_OFFSET, y)), tint)
	# A top on four corner legs, so a seated person's knees go under it.
	var frame := Transform3D(Basis(Vector3.UP, atan2(along.x, along.y)), _flat(spot, y))
	var colour := tint.darkened(0.15)
	var leg := TABLE_TOP - 0.04
	batch.at(frame.origin)
	batch.box("paint", frame, Vector3(0, TABLE_TOP - 0.02, 0), Vector3(TABLE_SIZE, 0.04, TABLE_SIZE), colour, false)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		batch.box("paint", frame, Vector3(corner.x, 0, corner.y) * (TABLE_SIZE * 0.5 - 0.05) + Vector3.UP * leg * 0.5, Vector3(0.05, leg, 0.05), colour)
	tables.append({"frame": frame, "along": along, "inside": inside})

func _bake_scatter() -> void:
	var folder := Node3D.new()
	folder.name = "Props"
	root.add_child(folder)
	var sources := {
		"scooter": _scooter_source(),
		"chair": _model_mesh("res://assets/polyhaven_town/models/plastic_monobloc_chair_01/plastic_monobloc_chair_01.gltf", Transform3D.IDENTITY, true),
		"pot": _model_mesh("res://assets/polyhaven_town/models/potted_plant_04/potted_plant_04.gltf", Transform3D.IDENTITY, false),
		"tree": _model_mesh("res://assets/polyhaven_town/models/jacaranda_street.glb", Transform3D.IDENTITY, false),
		"crate": _model_mesh("res://assets/polyhaven_town/models/plastic_crate_01/plastic_crate_01.gltf", Transform3D.IDENTITY, false),
		"box": _model_mesh("res://assets/polyhaven_town/models/cardboard_box_01/cardboard_box_01.gltf", Transform3D.IDENTITY, false),
		"meter": _model_mesh("res://assets/polyhaven_town/models/utility_box_01/utility_box_01.gltf", Transform3D.IDENTITY, false),
		"bush": _model_mesh("res://assets/kenney_nature/plant_bush.glb", Transform3D.IDENTITY, false),
	}
	for surface in range(sources.bush.get_surface_count()):
		sources.bush.surface_get_material(surface).albedo_color = Color(0.2, 0.33, 0.13)
	for key in scatter:
		var list: Array = scatter[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = sources[key[0]]
		multi.instance_count = list.size()
		for i in range(list.size()):
			multi.set_instance_transform(i, list[i][0])
			multi.set_instance_color(i, list[i][1])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.visibility_range_end = {"tree": 190.0, "scooter": 170.0}.get(key[0], 100.0)
		if key[0] in ["bush", "pot", "chair", "crate", "box", "meter"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		folder.add_child(node)

# Merges a model into one mesh; the largest coloured surface follows the instance colour.
func _model_mesh(path: String, offset: Transform3D, recolour: bool) -> ArrayMesh:
	var scene: Node3D = load(path).instantiate()
	var merged := ArrayMesh.new()
	root.add_child(scene)
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		if part.name == "Cube":
			continue
		var relative: Transform3D = offset * part.global_transform
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_NORMAL] == null:
				var shaded := SurfaceTool.new()
				shaded.create_from(part.mesh, surface)
				shaded.deindex()
				shaded.generate_normals()
				arrays = shaded.commit_to_arrays()
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(points.size()):
				points[i] = relative * points[i]
				normals[i] = (relative.basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material: StandardMaterial3D = part.mesh.surface_get_material(surface).duplicate()
			material.metallic = 0.0
			if material.resource_name.begins_with("leaves"):
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.vertex_color_use_as_albedo = recolour and _paintable(material)
			material.vertex_color_is_srgb = true
			if material.vertex_color_use_as_albedo:
				material.albedo_color = Color.WHITE
			merged.surface_set_material(merged.get_surface_count() - 1, material)
	scene.free()
	return _rested(merged)

# Models arrive centred on all sorts of origins; instances expect their feet at y = 0.
func _rested(mesh: ArrayMesh) -> ArrayMesh:
	var floor_y := mesh.get_aabb().position.y
	var rested := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(points.size()):
			points[i].y -= floor_y
		arrays[Mesh.ARRAY_VERTEX] = points
		rested.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		rested.surface_set_material(surface, mesh.surface_get_material(surface))
	return rested

func _paintable(material: StandardMaterial3D) -> bool:
	return material.albedo_texture != null or material.albedo_color.get_luminance() > 0.45

func _bridge(road: Dictionary) -> void:
	var half: float = road.width * 0.5 + road.walk
	var x: float = plan.BRIDGE_START - 6.0
	var z := -2.0
	while x < plan.BRIDGE_END + 6.0:
		var y_a: float = plan.hump(x)
		var y_b: float = plan.hump(x + 2.0)
		var next := x + 2.0
		batch.at(Vector3(x, 0, z))
		batch.facing(Vector3.UP, "asphalt", Vector3(x, y_a, z - road.width * 0.5), Vector3(next, y_b, z - road.width * 0.5), Vector3(next, y_b, z + road.width * 0.5), Vector3(x, y_a, z + road.width * 0.5))
		for side in [-1.0, 1.0]:
			var inner: float = z + side * road.width * 0.5
			var outer: float = z + side * half
			var kerb: float = plan.KERB
			var a := Vector3(x, y_a + kerb, inner)
			var b := Vector3(next, y_b + kerb, inner)
			var c := Vector3(next, y_b + kerb, outer)
			var d := Vector3(x, y_a + kerb, outer)
			batch.facing(Vector3.UP, "paver", a, b, c, d, Color(0.72, 0.72, 0.70))
			var rail_low := y_a + kerb
			var rail_b := y_b + kerb
			batch.quad("rail", Vector3(next, rail_b, outer), Vector3(x, rail_low, outer), Vector3(x, rail_low + 1.1, outer), Vector3(next, rail_b + 1.1, outer), Color(0.86, 0.30, 0.20), Vector2(4.0, 1.0))
			batch.box("paint", Transform3D(Basis.IDENTITY, Vector3(x, 0, outer)), Vector3(0, rail_low + 1.15, 0), Vector3(2.1, 0.08, 0.12), Color(0.80, 0.28, 0.18))
			_solid(Transform3D(Basis.IDENTITY, Vector3(x, 0, z + side * (half + 0.18))), Vector3(1, 4, 0), Vector3(2.1, 12, 0.3))
		batch.box("concrete", Transform3D(Basis.IDENTITY, Vector3(x + 1, 0, z)), Vector3(0, (y_a + y_b) * 0.5 - 0.5, 0), Vector3(2.0, 0.9, half * 2.0), Color(0.62, 0.62, 0.60), false)
		x = next
	var pier: float = plan.BRIDGE_START + 15.0
	while pier < plan.BRIDGE_END:
		batch.at(Vector3(pier, 0, z))
		batch.box("concrete", Transform3D(Basis.IDENTITY, Vector3(pier, 0, z)), Vector3(0, -1.5, 0), Vector3(2.2, 7.0, half * 2.0), Color(0.56, 0.56, 0.54))
		pier += 15.0

func _river() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 900)
	plane.subdivide_width = 1
	water.mesh = plane
	water.position = Vector3(plan.BRIDGE_START + 60.0, -2.1, 0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/river.gdshader")
	water.material_override = material
	water.name = "River"
	root.add_child(water)
	var z := -230.0
	while z < 230.0:
		var a: float = plan.river_west(z)
		var b: float = plan.river_west(z + 6.0)
		batch.at(Vector3(a, 0, z))
		batch.facing(Vector3(1, 1, 0), "concrete", Vector3(a, 0, z), Vector3(b, 0, z + 6.0), Vector3(b + 1.4, -2.4, z + 6.0), Vector3(a + 1.4, -2.4, z), Color(0.56, 0.54, 0.48))
		if absf(z + 2.0) > 10.0 and absf(z) < 165.0:
			batch.quad("rail", Vector3(b, 0.14, z + 6.0), Vector3(a, 0.14, z), Vector3(a, 1.2, z), Vector3(b, 1.2, z + 6.0), Color(0.3, 0.32, 0.34), Vector2(7.0, 1.0))
			var spine := Vector3(b - a, 0, 6.0)
			_solid(Transform3D(Basis(Vector3.UP, atan2(spine.x, spine.z)), Vector3((a + b) * 0.5, 0, z + 3.0)), Vector3(0, 3, 0), Vector3(0.3, 12, 6.2))
		z += 6.0

func _fields() -> void:
	var east: float = plan.BRIDGE_END
	batch.at(Vector3(east + 60, 0, 0))
	batch.facing(Vector3.UP, "mud", Vector3(east, plan.FIELD_LEVEL - 0.04, -300), Vector3(620, plan.FIELD_LEVEL - 0.04, -300), Vector3(620, plan.FIELD_LEVEL - 0.04, 300), Vector3(east, plan.FIELD_LEVEL - 0.04, 300), Color(0.96, 0.88, 0.74))
	batch.facing(Vector3(-1, 1, 0), "concrete", Vector3(east, plan.FIELD_LEVEL, -300), Vector3(east, plan.FIELD_LEVEL, 300), Vector3(east - 1.6, -2.4, 300), Vector3(east - 1.6, -2.4, -300), Color(0.56, 0.54, 0.48))
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.74, 0.80, 0.84)
	mirror.roughness = 0.05
	mirror.metallic = 0.75
	materials.pan = mirror
	mirror.vertex_color_use_as_albedo = true
	var x := east + 8.0
	while x < 600.0:
		var z := -240.0
		while z < 240.0:
			var pan := Vector2(x + 13.0, z + 11.0)
			if not plan.in_corridor(pan, 11.0) and pan.distance_to(Vector2(SCHOOL_X + 60, 26)) > 92.0:
				batch.at(_flat(pan))
				var edge := Vector2(12.0, 10.0)
				var y: float = plan.FIELD_LEVEL + 0.03
				batch.facing(Vector3.UP, "pan", _flat(pan + Vector2(-edge.x, -edge.y), y), _flat(pan + Vector2(edge.x, -edge.y), y), _flat(pan + Vector2(edge.x, edge.y), y), _flat(pan + Vector2(-edge.x, edge.y), y), Color(1, 1, 1).darkened(rng.randf() * 0.1))
			z += 24.0
		x += 28.0

func _school() -> void:
	var gate := Vector3(SCHOOL_X + 2.0, 0, 26)
	batch.at(gate)
	var frame := Transform3D(Basis(Vector3.UP, PI * 0.5), gate)
	var wall := Color(0.40, 0.41, 0.39)
	for side in [-1.0, 1.0]:
		batch.box("aged", frame, Vector3(side * 76.0, 1.5, 0), Vector3(144, 3.0, 0.4), wall)
		_solid(frame, Vector3(side * 76.0, 3, 0), Vector3(144, 12, 0.6))
		batch.box("aged", frame, Vector3(side * 4.2, 2.3, 0), Vector3(1.0, 4.6, 1.0), Color(0.62, 0.62, 0.58))
	batch.quad("rail", frame * Vector3(3.8, 0, 0), frame * Vector3(-3.8, 0, 0), frame * Vector3(-3.8, 3.2, 0), frame * Vector3(3.8, 3.2, 0), Color(0.5, 0.2, 0.14), Vector2(10, 2.0))
	_solid(frame, Vector3(0, 3, 0), Vector3(8, 12, 0.4))
	batch.box("paint", frame, Vector3(0, 4.7, 0), Vector3(9.6, 0.9, 0.3), Color(0.32, 0.34, 0.34))
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = "TRƯỜNG THPT NEH"
	label.font_size = 72
	label.pixel_size = 0.0085
	label.modulate = Color(0.78, 0.74, 0.62)
	label.shaded = true
	label.double_sided = false
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(0, 4.7, -0.17))
	signs_root.add_child(label)
	for wing in [Vector3(44, 0, -22), Vector3(44, 0, 66), Vector3(84, 0, 24)]:
		var size := Vector3(52, 13.0, 14) if wing.z != 24 else Vector3(14, 13.0, 70)
		var body := Transform3D(Basis.IDENTITY, gate + wing)
		batch.at(body.origin)
		batch.box("aged", body, Vector3(0, size.y * 0.5, 0), size, Color(0.42, 0.42, 0.39))
		var long_x: bool = size.x > size.z
		for level in range(3):
			var count := 12
			for n in range(count):
				var offset := (n - count * 0.5 + 0.5) * (size.x if long_x else size.z) / count
				var y := 2.4 + level * 4.1
				var window := Vector3(offset, y, -size.z * 0.5 - 0.02) if long_x else Vector3(-size.x * 0.5 - 0.02, y, offset)
				batch.box("glass", body, window, Vector3(2.0, 2.0, 0.05) if long_x else Vector3(0.05, 2.0, 2.0), Color(0.5, 0.52, 0.56))

# Roadside trees and scrub, so the salt road is not a bare strip.
func _roadside() -> void:
	var road: Dictionary = plan.road_named("Đường Đồng Muối")
	for i in range(6, road.path.size() - 4, 7):
		for side in [-1.0, 1.0]:
			var at: Vector2 = road.path[i] + _side(road, i) * side * (road.width * 0.5 + rng.randf_range(3.5, 7.0))
			if rng.randf() < 0.5:
				_add_scatter("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.3, 0.42)), _flat(at, plan.FIELD_LEVEL)))
			else:
				_add_scatter("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.12, 0.2)), _flat(at, plan.FIELD_LEVEL)))

func _edges() -> void:
	for road in plan.roads:
		if road.kind in ["alley", "bridge", "country"]:
			continue
		for end in [0, road.path.size() - 1]:
			var at: Vector2 = road.path[end]
			var heading: Vector2 = road.tangents[end] * (1.0 if end > 0 else -1.0)
			if plan.nearest(at + heading * 3.0, road.index).get("distance", 99.0) < road.width:
				continue
			var frame := Transform3D(Basis(Vector3.UP, atan2(heading.x, heading.y)), _flat(at))
			batch.at(frame.origin)
			var span: float = road.width + road.walk * 2.0 + 1.0
			batch.box("tin", frame, Vector3(0, 1.3, -1.0), Vector3(span, 2.6, 0.12), Color(0.86, 0.80, 0.30))
			for n in range(int(span / 2.0)):
				batch.box("paint", frame, Vector3(n * 2.0 - span * 0.5 + 1.0, 1.0, -0.92), Vector3(1.0, 0.3, 0.03), Color(0.75, 0.12, 0.10))
			_solid(frame, Vector3(0, 3, -1.0), Vector3(span, 12, 0.5))
			var label := Label3D.new()
			label.font = ThemeDB.fallback_font
			label.text = "CÔNG TRÌNH ĐANG THI CÔNG"
			label.font_size = 48
			label.pixel_size = 0.0055
			label.modulate = Color(0.1, 0.09, 0.08)
			label.shaded = true
			label.double_sided = false
			label.visibility_range_end = 60.0
			label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(0, 2.0, -1.1))
			signs_root.add_child(label)
	# Keeps riders on the fields near the road.
	for wall in [[Vector3(200, 0, -92), Vector3(150, 12, 1)], [Vector3(200, 0, 134), Vector3(150, 12, 1)]]:
		_solid(Transform3D(Basis.IDENTITY, wall[0]), Vector3.ZERO, wall[1])
