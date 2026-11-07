extends "res://scripts/town/town_builder.gd"
# Dresses the city plan round the school with the town's street kit (tube
# houses, shopfronts, signs, wires, scooters), at night. Backdrop only: the
# player never leaves the campus, so nothing out here gets collision.
const CityPlan := preload("res://scripts/city_backdrop/city_plan.gd")
# Filler blocks reach this far; towers stand between it and SKYLINE.
const FILL := 240.0
const SKYLINE := 460.0
# One texel per window cell (~2.5 m), so each window is either lit or dark.
const WINDOW_CELL := 2.5
const FLOOR_CELL := 3.4
# Shop lettering fades out at 70 m (town_builder), and the camera never leaves
# the campus, so signs further out than this only get the coloured board.
const SIGN_REACH := 75.0
const VluTower := preload("res://scripts/city_backdrop/vlu_tower.gd")

func build(owner: Node3D, town_plan: RefCounted) -> void:
	root = owner
	plan = town_plan
	rng.seed = 3105
	_make_materials()
	_night_materials()
	# _solid() still files its shapes here; they are dropped at the end.
	solids = StaticBody3D.new()
	signs_root = Node3D.new()
	signs_root.name = "Signs"
	root.add_child(signs_root)
	_ground()
	for road in plan.roads:
		_road(road)
	_junctions()
	for lot in plan.lots:
		_house(lot)
	_back_blocks()
	_skyline()
	for road in plan.roads:
		_wires(road)
		_street_life(road)
	var meshes := Node3D.new()
	meshes.name = "Meshes"
	root.add_child(meshes)
	triangles = batch.bake(meshes, materials, {"rail": 150.0, "cable": 220.0, "paint": 300.0})
	_bake_scatter()
	solids.free()
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		# Far away and behind a wall: shadows cost a lot and are never seen.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _night_materials() -> void:
	# The town's walls are tuned bright for its daytime sun; at night under the
	# moon they would glow next to the school.
	for name in ["plaster", "aged", "tile", "paver"]:
		materials[name].albedo_color *= 0.62
	# Windows: a coarse random pattern, mapped in world space, lights some.
	materials.glass.emission_enabled = true
	# Emission colour is added to the texture, so black leaves only the lit cells.
	materials.glass.emission = Color.BLACK
	materials.glass.emission_energy_multiplier = 1.4
	materials.glass.emission_texture = _random_windows(64, 1, 1, 0.38)
	materials.glass.uv1_triplanar = true
	materials.glass.uv1_world_triplanar = true
	materials.glass.uv1_scale = Vector3.ONE / (64.0 * WINDOW_CELL)
	materials.glass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Towers: bands of windows, one 4 px cell per floor.
	var tower := StandardMaterial3D.new()
	tower.vertex_color_use_as_albedo = true
	tower.vertex_color_is_srgb = true
	tower.roughness = 0.9
	tower.emission_enabled = true
	tower.emission = Color.BLACK
	tower.emission_energy_multiplier = 1.1
	tower.emission_texture = _random_windows(256, 4, 2, 0.3)
	tower.uv1_triplanar = true
	tower.uv1_world_triplanar = true
	tower.uv1_scale = Vector3.ONE / (64.0 * FLOOR_CELL)
	tower.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	materials.tower = tower
	# The VLU logo's red square, glowing like the lit sign on the real tower.
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.80, 0.08, 0.12)
	red.emission_enabled = true
	red.emission = Color(0.95, 0.10, 0.14)
	red.emission_energy_multiplier = 1.3
	materials.vlu_red = red

# `cell` px per window, of which a `cell - gap` square glows when lit. Warm
# bulbs mixed with the white tube lights most Saigon homes use.
func _random_windows(size: int, cell: int, gap: int, lit_share: float) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var colours := [Color(1.0, 0.78, 0.48), Color(0.92, 0.95, 1.0), Color(1.0, 0.88, 0.66), Color(0.80, 0.90, 1.0)]
	for cx in range(size / cell):
		for cy in range(size / cell):
			var colour := Color.BLACK
			if rng.randf() < lit_share:
				colour = colours[rng.randi() % colours.size()] * rng.randf_range(0.55, 1.0)
			for x in range(cell - (gap if cell > 1 else 0)):
				for y in range(cell - (gap if cell > 1 else 0)):
					image.set_pixel(cx * cell + x, cy * cell + y, colour)
	return ImageTexture.create_from_image(image)

# Paving everywhere outside the campus; the school keeps its own ground.
func _ground() -> void:
	var campus: Dictionary = CityPlan.CAMPUS
	var west: float = campus.centre.x - campus.width * 0.5
	var east: float = campus.centre.x + campus.width * 0.5
	var north: float = campus.centre.y - campus.depth * 0.5
	var south: float = campus.centre.y + campus.depth * 0.5
	var y := -0.03
	var tone := Color(0.50, 0.50, 0.48)
	for strip in [Rect2(-SKYLINE, -SKYLINE, SKYLINE * 2.0, north + SKYLINE), Rect2(-SKYLINE, south, SKYLINE * 2.0, SKYLINE - south), Rect2(-SKYLINE, north, west + SKYLINE, south - north), Rect2(east, north, SKYLINE - east, south - north)]:
		batch.at(Vector3(strip.get_center().x, 0, strip.get_center().y))
		batch.facing(Vector3.UP, "concrete", Vector3(strip.position.x, y, strip.position.y), Vector3(strip.end.x, y, strip.position.y), Vector3(strip.end.x, y, strip.end.y), Vector3(strip.position.x, y, strip.end.y), tone)

# Fill what the street rows leave empty, up to FILL, never on the campus.
func _back_blocks() -> void:
	var step := 9.0
	var x := -FILL
	while x < FILL:
		var z := -FILL
		while z < FILL:
			var p := Vector2(x + rng.randf_range(-1, 1), z + rng.randf_range(-1, 1))
			if not plan.inside_campus(p, step):
				_back_cell(p, step)
			z += step
		x += step

# Mid-rise and tower blocks on the horizon, the way the city looks from a
# school roof at night: mostly dark mass with scattered lit windows.
func _skyline() -> void:
	var cell := 34.0
	var x := -SKYLINE
	while x < SKYLINE:
		var z := -SKYLINE
		while z < SKYLINE:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			var far := maxf(absf(p.x), absf(p.y))
			if far > FILL + 12.0 and rng.randf() < 0.55:
				var footprint := Vector3(rng.randf_range(14, 26), 0, rng.randf_range(14, 26))
				# Taller further out, so the ring of towers reads as a skyline.
				footprint.y = rng.randf_range(18.0, 40.0) + (far - FILL) * rng.randf_range(0.05, 0.22)
				var frame := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), Vector3(p.x, 0, p.y))
				batch.at(frame.origin)
				var tint: Color = FACADES[rng.randi() % FACADES.size()].darkened(rng.randf_range(0.35, 0.55))
				batch.box("tower", frame, Vector3(0, footprint.y * 0.5, 0), footprint, tint)
				if rng.randf() < 0.25:
					# Red aircraft warning light on the tallest roofs.
					batch.box("lantern", frame, Vector3(0, footprint.y + 0.4, 0), Vector3(0.6, 0.6, 0.6))
			z += cell
		x += cell

func _shop_sign(frame: Transform3D, w: float, tall: float, place: Dictionary) -> void:
	var at := Vector2(frame.origin.x, frame.origin.z)
	if plan.inside_campus(at, SIGN_REACH):
		super(frame, w, tall, place)
		return
	batch.box("paint", frame, Vector3(0, tall + 0.42, -0.14), Vector3(w - 0.12, 0.8, 0.14), SIGNS[rng.randi() % SIGNS.size()])

func _house(lot: Dictionary) -> void:
	if lot.get("place", {}).get("style", "") != "vlu":
		super(lot)
		return
	var frame := _frame(lot)
	batch.at(frame.origin)
	VluTower.new(self).build(lot, frame)
