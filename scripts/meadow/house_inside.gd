extends Node3D
# The inside of the little house on the ceiling of the box (land_fold.gd). Its door is a doorway
# (portal.gd): seen from the path it already shows the inside, and stepping through is stepping
# in, no cut. The inside is a living room sixteen times too big: old yellow wallpaper going up
# forty metres, a wooden floor, a rug the size of a field, a sofa like a hill, an armchair, a
# grandfather clock nearly touching the ceiling, a bookshelf, a window full of night sky, and the
# little door the player came in by, at the foot of the wall. A spiral of giant books leads up
# onto the coffee table, where an oil lamp burns beside a glass ball on a wooden stand. Inside
# the ball is a tiny planet: grass, a tree, a bed, the same little house.
# Looking into the ball and touching it, the eye falls into it, slowly, a power of ten at a time,
# and comes down standing on the planet. That planet is real, at full size, far away
# (PLANET_AT), and round it stands a copy of the whole room, made K times bigger, so that looking
# up from the planet is looking out through the glass at a room kilometres high, lit by the
# same lamp; the eye's fall ends exactly where the tiny copy would have put it, so it never cuts.
# The little house on the planet has a doorway too: it opens on the meadow as the dream first
# was, dark, one bright place far off (dream_meadow.gd, `again`). Its bed is only a bed.
# Gravity: up_at() for the box (land_fold), the room (up) and the planet (away from its middle).
# Everything here and every licence: ASSETS.md, assets/polyhaven_house/sources.json.
const Portal := preload("res://scripts/meadow/portal.gd")
const MODEL := "res://assets/polyhaven_house/%s/%s_1k.gltf"
const SOFA := "res://assets/polyhaven_town/models/Sofa_01/Sofa_01.gltf"
const FLOOR := "res://assets/polyhaven_town/textures/laminate_floor_02_%s.jpg"
const GRASS_TEX := "res://assets/polyhaven_meadow/leafy_grass_%s_1k.jpg"
const NIGHT := "res://assets/polyhaven_meadow/qwantani_night_puresky_2k.hdr"
const TREE := "res://assets/polyhaven_meadow/island_tree_01/island_tree_01.gltf"
const BED := "res://assets/polyhaven_meadow/GothicBed_01/GothicBed_01_1k.gltf"
const SHRUB := "res://assets/polyhaven_meadow/shrub_01/shrub_01_1k.gltf"
const DANDELION := "res://assets/polyhaven_meadow/dandelion_01/dandelion_01_1k.gltf"
const MUSIC := "res://assets/music/fair_rollup.ogg"
const BOOK := preload("res://assets/materials/house_book.gdshader")
const WALLPAPER := preload("res://assets/materials/house_wallpaper.gdshader")
const RUG := preload("res://assets/materials/house_rug.gdshader")
const WINDOW := preload("res://assets/materials/house_window.gdshader")
const GLASS := preload("res://assets/materials/house_glass.gdshader")
const PLANET_GRASS := preload("res://assets/materials/planet_grass.gdshader")
# Render layers (bits): the room and the tiny planet in it, the real planet, the room's huge copy.
# Each has its own lights, so the moon never shines indoors and the room's lamp never lights the box.
const ROOM := 16
const PLANET := 32
const COPY := 64
const ROOM_AT := Vector3(0, -6000, 0)
const PLANET_AT := Vector3(0, -6000, -12000)
# The room: a living room at sixteen times its size. Room-local: floor at y 0, the wall with the
# little door at z +60.
const S := 16.0
const HALF := Vector2(44, 60)
const HEIGHT := 42.0
const DOOR_AT := Vector3(-30, 0, 60)
const TABLE_AT := Vector3(0, 0, -6)
const TABLE_TOP := 7.83
# The table's top is flat out to about 8.6 m and ends at about 9.3; its legs splay out further.
const TABLE_RIM := 9.2
const LAMP_AT := Vector3(5.4, 0, -3.6)
const GLOBE_AT := Vector3(-1.6, 0, 1.6)
const BASE_H := 0.7
const GLOBE_R := 2.4
const MINI_R := 1.0
const PLANET_R := 45.0
const K := PLANET_R / MINI_R
const STAIR_COUNT := 24
const STAIR_RISE := TABLE_TOP / STAIR_COUNT
const STAIR_RADIUS := 11.95
const STAIR_STEP := 2.05
const STAIR_FROM := 0.35
const GLOBE_REACH := 4.2
# A tiny sun hanging in the glass over the planet (room-local, from the ball's middle): it is what
# lights the planet, and from the planet it is the sun overhead.
const STAR_AT := Vector3(0.75, 1.3, 0.55)
const STAR_R := 0.07
const FOG := 0.0028
# The fall into the glass ball: over the ball, then straight down to the planet, the height
# shrinking by the same factor every moment.
const ZOOM_OVER := 2.4
const ZOOM_DOWN := 4.6
const EYE := 1.6

var fold: Node3D
var room: Node3D
var copy: Node3D
var planet: Node3D
var mini: Node3D
var room_environment: Environment
var planet_environment: Environment
var quality := 1
var share := 1.0
var blade: Callable
var portal_out: Node3D
var portal_room: Node3D
var portal_planet: Node3D
var planet_hinge: Node3D
var planet_bed: Node3D
var planet_house: Node3D
var planet_door := 0.0
var planet_opening := false
var music: AudioStreamPlayer
var zoom_from: Transform3D
var zoom_lift: Vector3
var stair_count := STAIR_COUNT

func globe_local() -> Vector3:
	return TABLE_AT + GLOBE_AT + Vector3(0, TABLE_TOP + BASE_H + GLOBE_R - 0.2, 0)

func globe_centre() -> Vector3:
	return ROOM_AT + globe_local()

func table_top() -> float:
	return ROOM_AT.y + TABLE_TOP

# A point by the ball, in the room, to the same point round the real planet.
func to_planet(at: Vector3) -> Vector3:
	return PLANET_AT + (at - globe_centre()) * K

func zone(at: Vector3) -> String:
	if at.y > ROOM_AT.y * 0.5:
		return "box"
	if at.distance_to(PLANET_AT) < 3500.0:
		return "planet"
	return "room"

func up_at(at: Vector3) -> Vector3:
	match zone(at):
		"box": return fold.up_at(at)
		"planet": return (at - PLANET_AT).normalized()
	return Vector3.UP

# `grass` makes a blade mesh with that many segments (the meadow's); `grass_share` the graphics
# setting's share of grass.
func build(box: Node3D, grass: Callable, graphics: int, grass_share: float) -> void:
	fold = box
	blade = grass
	quality = graphics
	share = grass_share
	_environments()
	room = Node3D.new()
	room.name = "Room"
	room.position = ROOM_AT
	add_child(room)
	_room(room, false)
	mini = Node3D.new()
	mini.name = "TinyPlanet"
	mini.position = globe_local()
	mini.scale = Vector3.ONE / K
	room.add_child(mini)
	_planet(mini, true)
	_lights(room, Transform3D.IDENTITY, 1.0, ROOM)
	_dust()
	_layer(room, ROOM)
	copy = Node3D.new()
	copy.name = "RoomGiant"
	copy.transform = Transform3D(Basis.from_scale(Vector3.ONE * K), PLANET_AT - globe_local() * K)
	add_child(copy)
	_room(copy, true)
	_layer(copy, COPY)
	_lights(self, copy.transform, K, PLANET | COPY)
	planet = Node3D.new()
	planet.name = "Planet"
	planet.position = PLANET_AT
	add_child(planet)
	_planet(planet, false)
	_layer(planet, PLANET)
	music = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = load(MUSIC)
	music.stream = loop
	music.volume_db = -80.0
	add_child(music)

func _environments() -> void:
	room_environment = Environment.new()
	room_environment.background_mode = Environment.BG_COLOR
	room_environment.background_color = Color(0.02, 0.015, 0.012)
	room_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_environment.ambient_light_color = Color(0.55, 0.45, 0.36)
	room_environment.ambient_light_energy = 0.32
	room_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	room_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	room_environment.tonemap_white = 6.0
	room_environment.tonemap_exposure = 1.25
	room_environment.ssao_enabled = quality == 2
	room_environment.ssao_radius = 2.0
	room_environment.glow_enabled = true
	room_environment.glow_intensity = 0.5
	room_environment.glow_bloom = 0.05
	room_environment.glow_hdr_threshold = 1.2
	room_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	room_environment.fog_enabled = true
	room_environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	room_environment.fog_density = FOG
	room_environment.fog_light_color = Color(0.42, 0.33, 0.22)
	room_environment.fog_aerial_perspective = 0.0
	room_environment.adjustment_enabled = true
	room_environment.adjustment_saturation = 1.0
	preload("res://scripts/game_settings.gd").track(room_environment)
	planet_environment = room_environment.duplicate()
	planet_environment.fog_density = FOG / K
	preload("res://scripts/game_settings.gd").track(planet_environment)

# --- The room ----------------------------------------------------------------------------------

# The room, built in room-local coordinates into `root` (the room itself, or its huge copy,
# which has no colliders and none of the room's moving things).
func _room(root: Node3D, is_copy: bool) -> void:
	var collide := not is_copy
	_shell(root, collide)
	_put(root, SOFA, Vector3(0, 0, -49), 0.0, collide)
	_put(root, MODEL % ["ArmChair_01", "ArmChair_01"], Vector3(27, 0, -6), -PI / 2 + 0.25, collide)
	_put(root, MODEL % ["wooden_bookshelf_worn", "wooden_bookshelf_worn"], Vector3(HALF.x - 4.8, 0, 22), -PI / 2, collide)
	_put(root, MODEL % ["mantel_clock_01", "mantel_clock_01"], Vector3(HALF.x - 4.8, 33.05, 16), -PI / 2, false)
	_put(root, MODEL % ["vintage_grandfather_clock_01", "vintage_grandfather_clock_01"], Vector3(-HALF.x + 3.2, 0, -30), PI / 2, collide)
	_put(root, MODEL % ["hanging_picture_frame_01", "hanging_picture_frame_01"], Vector3(0, 27, -HALF.y + 0.3), PI, false)
	var plant := _put(root, MODEL % ["potted_plant_01", "potted_plant_01"], Vector3(-35, 0, -50), 0.6, false)
	if collide:
		_cylinder(root, Vector3(-35, 0, -50), 4.6, 9.0)
	plant.name = "Plant"
	var books := _put(root, MODEL % ["book_encyclopedia_set_01", "book_encyclopedia_set_01"], Vector3(-20, 0, 18), 0.35, false)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.8, 3.8, 2.6)
		shape.shape = box
		shape.position = Vector3(4.1, 1.9, 0.3)
		body.add_child(shape)
		body.transform = Transform3D(Basis(Vector3.UP, books.rotation.y), books.position)
		root.add_child(body)
	_put(root, MODEL % ["coffee_table_round_01", "coffee_table_round_01"], TABLE_AT, 0.0, collide)
	_put(root, MODEL % ["vintage_oil_lamp", "vintage_oil_lamp"], TABLE_AT + LAMP_AT + Vector3(0, TABLE_TOP, 0), 0.4, collide)
	_rug(root)
	_stairs(root, collide)
	_globe(root, collide)
	_window(root)
	_big_door(root)
	_little_door(root)

func _put(root: Node3D, path: String, at: Vector3, turn: float, collide: bool) -> Node3D:
	var node: Node3D = load(path).instantiate()
	node.position = at
	node.rotation.y = turn
	node.scale = Vector3.ONE * S
	root.add_child(node)
	if collide:
		_trimesh(root, node)
	return node

# A collider that is the model's own triangles, in `root`'s coordinates.
func _trimesh(root: Node3D, node: Node3D) -> void:
	var body := StaticBody3D.new()
	root.add_child(body)
	var into := root.global_transform.affine_inverse()
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var faces := mesh.mesh.get_faces()
		var move := into * mesh.global_transform
		for i in range(faces.size()):
			faces[i] = move * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)

func _cylinder(root: Node3D, at: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position = at + Vector3(0, height / 2, 0)
	body.add_child(shape)
	root.add_child(body)

func _box_body(root: Node3D, part: AABB) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = part.size
	shape.shape = box
	shape.position = part.get_center()
	body.add_child(shape)
	root.add_child(body)

func _noise(frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	texture.generate_mipmaps = true
	return texture

func _paint(colour: Color, roughness := 0.8) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = roughness
	return paint

func _block(root: Node3D, part: AABB, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = part.size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = part.get_center()
	root.add_child(node)
	return node

# One face, seen from the side `normal` points to (only from there: the walls are one-sided, so
# from outside the room, where a doorway's camera stands, they are not there at all).
func _quad(tool: SurfaceTool, corners: Array, normal: Vector3, uv_scale: float) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var d: Vector3 = corners[3]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = d
		d = swap
	for corner: Vector3 in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		var flat := Vector2(corner.x + corner.z, corner.y) if absf(normal.y) < 0.5 else Vector2(corner.x, corner.z)
		tool.set_uv(flat / uv_scale)
		tool.add_vertex(corner)

func _wall(tool: SurfaceTool, x0: float, x1: float, y0: float, y1: float, plane: float, along_x: bool, normal: Vector3) -> void:
	if along_x:
		_quad(tool, [Vector3(x0, y0, plane), Vector3(x1, y0, plane), Vector3(x1, y1, plane), Vector3(x0, y1, plane)], normal, 1.0)
	else:
		_quad(tool, [Vector3(plane, y0, x0), Vector3(plane, y0, x1), Vector3(plane, y1, x1), Vector3(plane, y1, x0)], normal, 1.0)

func _shell(root: Node3D, collide: bool) -> void:
	var paper := ShaderMaterial.new()
	paper.shader = WALLPAPER
	paper.set_shader_parameter("stains", _noise(0.02))
	paper.set_shader_parameter("height", HEIGHT)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole := Vector2(DOOR_AT.x - 0.58, DOOR_AT.x + 0.58)
	var hole_top := 2.14
	_wall(walls, -HALF.x, HALF.x, 0, HEIGHT, -HALF.y, true, Vector3.BACK)
	_wall(walls, -HALF.x, hole.x, 0, HEIGHT, HALF.y, true, Vector3.FORWARD)
	_wall(walls, hole.y, HALF.x, 0, HEIGHT, HALF.y, true, Vector3.FORWARD)
	_wall(walls, hole.x, hole.y, hole_top, HEIGHT, HALF.y, true, Vector3.FORWARD)
	_wall(walls, -HALF.y, HALF.y, 0, HEIGHT, -HALF.x, false, Vector3.RIGHT)
	_wall(walls, -HALF.y, HALF.y, 0, HEIGHT, HALF.x, false, Vector3.LEFT)
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "Walls"
	wall_mesh.mesh = walls.commit()
	wall_mesh.material_override = paper
	root.add_child(wall_mesh)
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(ground, [Vector3(-HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, HALF.y)], Vector3.UP, 30.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = ground.commit()
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load(FLOOR % "diff")
	wood.normal_enabled = true
	wood.normal_texture = load(FLOOR % "nor")
	wood.albedo_color = Color(0.8, 0.66, 0.52)
	wood.roughness = 0.55
	floor_mesh.material_override = wood
	root.add_child(floor_mesh)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(top, [Vector3(-HALF.x, HEIGHT, -HALF.y), Vector3(HALF.x, HEIGHT, -HALF.y), Vector3(HALF.x, HEIGHT, HALF.y), Vector3(-HALF.x, HEIGHT, HALF.y)], Vector3.DOWN, 30.0)
	var ceiling := MeshInstance3D.new()
	ceiling.name = "Ceiling"
	ceiling.mesh = top.commit()
	ceiling.material_override = _paint(Color(0.8, 0.77, 0.7), 0.95)
	root.add_child(ceiling)
	# Skirting along the foot of every wall (leaving the little door clear) and a cornice under the ceiling.
	var white := _paint(Color(0.88, 0.85, 0.78), 0.6)
	var skirt := 1.9
	var lip := 0.35
	for part: AABB in [
			AABB(Vector3(-HALF.x, 0, -HALF.y), Vector3(HALF.x * 2, skirt, lip)),
			AABB(Vector3(-HALF.x, 0, HALF.y - lip), Vector3(hole.x - 0.25 + HALF.x, skirt, lip)),
			AABB(Vector3(hole.y + 0.25, 0, HALF.y - lip), Vector3(HALF.x - hole.y - 0.25, skirt, lip)),
			AABB(Vector3(-HALF.x, 0, -HALF.y), Vector3(lip, skirt, HALF.y * 2)),
			AABB(Vector3(HALF.x - lip, 0, -HALF.y), Vector3(lip, skirt, HALF.y * 2)),
			AABB(Vector3(-HALF.x, HEIGHT - 1.4, -HALF.y), Vector3(HALF.x * 2, 1.4, 0.7)),
			AABB(Vector3(-HALF.x, HEIGHT - 1.4, HALF.y - 0.7), Vector3(HALF.x * 2, 1.4, 0.7)),
			AABB(Vector3(-HALF.x, HEIGHT - 1.4, -HALF.y), Vector3(0.7, 1.4, HALF.y * 2)),
			AABB(Vector3(HALF.x - 0.7, HEIGHT - 1.4, -HALF.y), Vector3(0.7, 1.4, HALF.y * 2))]:
		_block(root, part, white)
	if not collide:
		return
	const T := 4.0
	for part: AABB in [
			AABB(Vector3(-HALF.x - T, -T, -HALF.y - T), Vector3(HALF.x * 2 + T * 2, T, HALF.y * 2 + T * 2)),
			AABB(Vector3(-HALF.x - T, HEIGHT, -HALF.y - T), Vector3(HALF.x * 2 + T * 2, T, HALF.y * 2 + T * 2)),
			AABB(Vector3(-HALF.x - T, 0, -HALF.y - T), Vector3(HALF.x * 2 + T * 2, HEIGHT, T)),
			AABB(Vector3(-HALF.x - T, 0, HALF.y), Vector3(hole.x + HALF.x + T, HEIGHT, T)),
			AABB(Vector3(hole.y, 0, HALF.y), Vector3(HALF.x + T - hole.y, HEIGHT, T)),
			AABB(Vector3(hole.x, hole_top, HALF.y), Vector3(hole.y - hole.x, HEIGHT - hole_top, T)),
			AABB(Vector3(-HALF.x - T, 0, -HALF.y), Vector3(T, HEIGHT, HALF.y * 2)),
			AABB(Vector3(HALF.x, 0, -HALF.y), Vector3(T, HEIGHT, HALF.y * 2))]:
		_box_body(root, part)
	# The floor of the little doorway, out past the wall to the end of the doorway's screen.
	_box_body(root, AABB(Vector3(hole.x, -1.0, HALF.y), Vector3(hole.y - hole.x, 1.0, Portal.DEPTH + 0.2)))

func _rug(root: Node3D) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(58, 41)
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	rug.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = RUG
	material.set_shader_parameter("aspect", Vector2(1.414, 1.0))
	material.set_shader_parameter("wear", _noise(0.05))
	rug.material_override = material
	rug.position = TABLE_AT + Vector3(0, 0.05, 2)
	rug.rotation.y = 0.04
	root.add_child(rug)

# A spiral of giant books round the coffee table, each pile one book higher than the last, up to
# the table's top: low enough steps to walk up without a jump.
func _stairs(root: Node3D, collide: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	var covers := [Color(0.42, 0.12, 0.1), Color(0.12, 0.22, 0.32), Color(0.2, 0.3, 0.18), Color(0.55, 0.42, 0.22), Color(0.3, 0.16, 0.3), Color(0.62, 0.58, 0.5), Color(0.15, 0.14, 0.13)]
	var placed: Array[Transform3D] = []
	var colours: Array[Color] = []
	var body: StaticBody3D
	if collide:
		body = StaticBody3D.new()
		body.name = "Stairs"
		root.add_child(body)
	for i in range(stair_count):
		var centre := _stair_foot(i)
		var turn := STAIR_FROM - i * STAIR_STEP / STAIR_RADIUS
		var height := (i + 1) * STAIR_RISE
		var pile := Basis(Vector3.UP, turn)
		for level in range(i + 1):
			var size := Vector3(rng.randf_range(2.0, 2.3), STAIR_RISE, rng.randf_range(3.1, 3.5))
			var jitter := Basis(Vector3.UP, rng.randf_range(-0.07, 0.07))
			var shift := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.12, 0.12))
			if level == i:
				jitter = Basis.IDENTITY
				shift = Vector3.ZERO
			var at := centre + pile * shift + Vector3(0, (level + 0.5) * STAIR_RISE, 0)
			placed.append(Transform3D(pile * jitter * Basis.from_scale(size), at))
			colours.append(covers[rng.randi() % covers.size()] * rng.randf_range(0.8, 1.15))
		if collide:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(2.0, height, 3.1)
			shape.shape = box
			shape.transform = Transform3D(pile, centre + Vector3(0, height / 2, 0))
			body.add_child(shape)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = placed.size()
	for i in range(placed.size()):
		multi.set_instance_transform(i, placed[i])
		multi.set_instance_custom_data(i, colours[i])
	var material := ShaderMaterial.new()
	material.shader = BOOK
	var books := MultiMeshInstance3D.new()
	books.name = "BookStairs"
	books.multimesh = multi
	books.material_override = material
	root.add_child(books)

# Where pile i stands (room-local, on the floor). The spiral keeps clear of the table's legs and
# draws in under its edge for the last few piles, so the top one meets the tabletop.
func _stair_foot(i: int) -> Vector3:
	var turn := STAIR_FROM - i * STAIR_STEP / STAIR_RADIUS
	var radius := STAIR_RADIUS - smoothstep(STAIR_COUNT - 6.0, STAIR_COUNT - 1.0, float(i)) * 1.5
	return TABLE_AT + Vector3(sin(turn), 0, cos(turn)) * radius

# The top of pile i, and of the last one, room-local (for the tests).
func stair_step(i: int) -> Vector3:
	return _stair_foot(i) + Vector3(0, (i + 1) * STAIR_RISE, 0)

func stair_top() -> Vector3:
	return stair_step(stair_count - 1)

func _globe(root: Node3D, collide: bool) -> void:
	var foot := TABLE_AT + GLOBE_AT + Vector3(0, TABLE_TOP, 0)
	var stand := CylinderMesh.new()
	stand.top_radius = 1.7
	stand.bottom_radius = 2.0
	stand.height = BASE_H
	var wood := _paint(Color(0.22, 0.12, 0.07), 0.4)
	var base := MeshInstance3D.new()
	base.mesh = stand
	base.material_override = wood
	base.position = foot + Vector3(0, BASE_H / 2, 0)
	root.add_child(base)
	var ring := CylinderMesh.new()
	ring.top_radius = 1.74
	ring.bottom_radius = 1.78
	ring.height = 0.12
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.3)
	brass.metallic = 1.0
	brass.roughness = 0.3
	var band := MeshInstance3D.new()
	band.mesh = ring
	band.material_override = brass
	band.position = foot + Vector3(0, BASE_H - 0.05, 0)
	root.add_child(band)
	var ball := SphereMesh.new()
	ball.radius = GLOBE_R
	ball.height = GLOBE_R * 2
	ball.radial_segments = 96
	ball.rings = 48
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	var shell := MeshInstance3D.new()
	shell.name = "Glass"
	shell.mesh = ball
	shell.material_override = glass
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position = globe_local()
	root.add_child(shell)
	var star := SphereMesh.new()
	star.radius = STAR_R
	star.height = STAR_R * 2
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.6)
	var sun := MeshInstance3D.new()
	sun.name = "TinySun"
	sun.mesh = star
	sun.material_override = glow
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.position = globe_local() + STAR_AT
	root.add_child(sun)
	var halo := QuadMesh.new()
	halo.size = Vector2.ONE * STAR_R * 14.0
	var halo_paint := StandardMaterial3D.new()
	halo_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_paint.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_paint.albedo_texture = _halo()
	halo_paint.albedo_color = Color(1.0, 0.8, 0.5, 0.8)
	var glare := MeshInstance3D.new()
	glare.mesh = halo
	glare.material_override = halo_paint
	glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glare.position = sun.position
	root.add_child(glare)
	if collide:
		_cylinder(root, foot, 2.0, BASE_H)
		var body := StaticBody3D.new()
		body.name = "GlobeBody"
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = GLOBE_R
		shape.shape = sphere
		shape.position = globe_local()
		body.add_child(shape)
		root.add_child(body)

func _halo() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# A tall window on the left wall full of night sky, with heavy curtains and a sill.
func _window(root: Node3D) -> void:
	var x := -HALF.x + 0.06
	var span := Vector2(2, 30)
	var rise := Vector2(11, 35)
	var sky := ShaderMaterial.new()
	sky.shader = WINDOW
	sky.set_shader_parameter("sky", load(NIGHT))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wall(tool, span.x, span.y, rise.x, rise.y, x, false, Vector3.RIGHT)
	var pane := MeshInstance3D.new()
	pane.name = "Window"
	pane.mesh = tool.commit()
	pane.material_override = sky
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pane)
	var white := _paint(Color(0.9, 0.88, 0.82), 0.5)
	var bar := 0.6
	for z: float in [span.x, (span.x + span.y) / 2, span.y]:
		_block(root, AABB(Vector3(x, rise.x, z - bar / 2), Vector3(0.6, rise.y - rise.x, bar)), white)
	for y: float in [rise.x, rise.x + (rise.y - rise.x) / 3, rise.x + 2 * (rise.y - rise.x) / 3, rise.y]:
		_block(root, AABB(Vector3(x, y - bar / 2, span.x), Vector3(0.6, bar, span.y - span.x)), white)
	_block(root, AABB(Vector3(x, rise.x - 1.2, span.x - 1.5), Vector3(2.0, 0.8, span.y - span.x + 3.0)), white)
	# Curtains: real folds, hanging from a rod above the window to just off the floor.
	var velvet := StandardMaterial3D.new()
	velvet.albedo_color = Color(0.34, 0.07, 0.07)
	velvet.roughness = 0.95
	velvet.rim_enabled = true
	velvet.rim = 0.4
	velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: Array in [[span.x - 6.5, span.x + 1.5], [span.y - 1.5, span.y + 6.5]]:
		var cloth := SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 40
		for i in range(steps):
			var z0: float = lerpf(side[0], side[1], i / float(steps))
			var z1: float = lerpf(side[0], side[1], (i + 1) / float(steps))
			var d0 := 1.6 + sin(i * 0.9) * 0.7
			var d1 := 1.6 + sin((i + 1) * 0.9) * 0.7
			var n := Vector3(1, 0, -(d1 - d0) / (z1 - z0)).normalized()
			for corner: Vector3 in [Vector3(x + d0, 0.8, z0), Vector3(x + d1, 0.8, z1), Vector3(x + d1, rise.y + 4.0, z1), Vector3(x + d0, 0.8, z0), Vector3(x + d1, rise.y + 4.0, z1), Vector3(x + d0, rise.y + 4.0, z0)]:
				cloth.set_normal(n)
				cloth.add_vertex(corner)
		var curtain := MeshInstance3D.new()
		curtain.mesh = cloth.commit()
		curtain.material_override = velvet
		root.add_child(curtain)
	var brass := _paint(Color(0.6, 0.45, 0.25), 0.35)
	brass.metallic = 1.0
	_block(root, AABB(Vector3(x + 1.2, rise.y + 4.0, span.x - 8.0), Vector3(0.4, 0.4, span.y - span.x + 16.0)), brass)

# The room's own door: a door for a giant, closed, on the same wall as the little one.
func _big_door(root: Node3D) -> void:
	var white := _paint(Color(0.86, 0.84, 0.78), 0.55)
	var z := HALF.y
	var centre := 14.0
	var w := 17.6
	var h := 35.0
	_block(root, AABB(Vector3(centre - w / 2, 0, z - 0.5), Vector3(w, h, 0.5)), white)
	for part: AABB in [
			AABB(Vector3(centre - w / 2 - 1.4, 0, z - 0.9), Vector3(1.4, h + 1.4, 0.9)),
			AABB(Vector3(centre + w / 2, 0, z - 0.9), Vector3(1.4, h + 1.4, 0.9)),
			AABB(Vector3(centre - w / 2, h, z - 0.9), Vector3(w, 1.4, 0.9))]:
		_block(root, part, white)
	for row in range(3):
		for col in range(2):
			var panel := AABB(Vector3(centre - w / 2 + 1.6 + col * (w / 2 - 0.8), 2.5 + row * 11.0, z - 0.75), Vector3(w / 2 - 2.4, 9.0, 0.3))
			_block(root, panel, _paint(Color(0.8, 0.78, 0.72), 0.6))
	var knob := SphereMesh.new()
	knob.radius = 0.9
	knob.height = 1.8
	var brass := _paint(Color(0.75, 0.58, 0.3), 0.3)
	brass.metallic = 1.0
	var handle := MeshInstance3D.new()
	handle.mesh = knob
	handle.material_override = brass
	handle.position = Vector3(centre - w / 2 + 2.2, 16.0, z - 1.3)
	root.add_child(handle)

# The little door the player came in by, at the foot of the wall: a white frame and the door
# itself standing open against the wall.
func _little_door(root: Node3D) -> void:
	var white := _paint(Color(0.94, 0.93, 0.9), 0.5)
	var z := HALF.y
	var left := DOOR_AT.x - 0.58
	var right := DOOR_AT.x + 0.58
	_block(root, AABB(Vector3(left - 0.14, 0, z - 0.12), Vector3(0.14, 2.28, 0.12)), white)
	_block(root, AABB(Vector3(right, 0, z - 0.12), Vector3(0.14, 2.28, 0.12)), white)
	_block(root, AABB(Vector3(left - 0.14, 2.14, z - 0.12), Vector3(right - left + 0.28, 0.14, 0.12)), white)
	var hinge := Node3D.new()
	hinge.position = Vector3(right, 0.02, z - 0.1)
	hinge.rotation.y = deg_to_rad(-95)
	root.add_child(hinge)
	_block(hinge, AABB(Vector3(-1.1, 0, -0.06), Vector3(1.1, 2.1, 0.06)), white)

# The room's lights: the oil lamp's flame, moonlight through the window, a little warmth by the
# door. For the room's huge copy, `place` puts them where the copy has its lamp and window, and
# `grow` stretches their reach; their strength is grown with them (light falls off as 1/d).
func _lights(root: Node3D, place: Transform3D, grow: float, mask: int) -> void:
	var flame := OmniLight3D.new()
	flame.name = "LampLight"
	flame.light_color = Color(1.0, 0.68, 0.36)
	flame.light_energy = 7.0 * grow
	flame.omni_range = 150.0 * grow
	flame.omni_attenuation = 1.0
	flame.shadow_enabled = quality > 0 and grow == 1.0
	flame.light_cull_mask = mask
	flame.position = place * (TABLE_AT + LAMP_AT + Vector3(0, TABLE_TOP + 7.2, 0))
	root.add_child(flame)
	var moon := SpotLight3D.new()
	moon.name = "Moonbeam"
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 6.0 * grow
	moon.spot_range = 170.0 * grow
	moon.spot_angle = 24.0
	moon.spot_attenuation = 1.0
	moon.light_cull_mask = mask
	var from := place * Vector3(-HALF.x - 40.0, 52.0, 16.0)
	var to := place * Vector3(-4.0, 0.0, 6.0)
	moon.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	root.add_child(moon)
	var sun := OmniLight3D.new()
	sun.name = "TinySunLight"
	sun.light_color = Color(1.0, 0.88, 0.66)
	sun.light_energy = 1.2 * grow
	sun.omni_range = 4.0 * grow
	sun.omni_attenuation = 1.0
	sun.light_cull_mask = mask
	sun.position = place * (globe_local() + STAR_AT)
	root.add_child(sun)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.75, 0.5)
	warm.light_energy = 0.8 * grow
	warm.omni_range = 70.0 * grow
	warm.omni_attenuation = 1.0
	warm.light_cull_mask = mask
	warm.position = place * Vector3(DOOR_AT.x + 6.0, 18.0, HALF.y - 14.0)
	root.add_child(warm)

# Dust hanging in the lamplight.
func _dust() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 500 if quality > 0 else 250
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.visibility_aabb = AABB(Vector3(-HALF.x, 0, -HALF.y), Vector3(HALF.x * 2, HEIGHT, HALF.y * 2))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(30, 16, 40)
	process.direction = Vector3(0, 1, 0)
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.12
	process.gravity = Vector3(0, -0.01, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 9.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	dust.process_material = process
	var mote := QuadMesh.new()
	mote.size = Vector2(0.05, 0.05)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.vertex_color_use_as_albedo = true
	glow.albedo_color = Color(1.4, 1.1, 0.75, 0.55)
	mote.material = glow
	dust.draw_pass_1 = mote
	dust.position = TABLE_AT + Vector3(0, 16, 6)
	room.add_child(dust)

# --- The planet --------------------------------------------------------------------------------

# Where things stand on the planet: straight up from its middle is where the fall lands; the
# house a little ahead (-Z), the tree and the bed off to the right.
func _on_planet(tilt_x: float, tilt_z: float) -> Vector3:
	return (Basis(Vector3.BACK, deg_to_rad(tilt_z)) * Basis(Vector3.RIGHT, deg_to_rad(tilt_x)) * Vector3.UP).normalized()

func _stand(root: Node3D, node: Node3D, up: Vector3, facing: Vector3, sink: float) -> void:
	var back := (facing - up * facing.dot(up)).normalized()
	node.transform = Transform3D(Basis(up.cross(back), up, back), up * (PLANET_R - sink))
	root.add_child(node)

# The planet into `root` (its middle at root's origin): real, or the tiny one in the glass ball,
# which has the same of everything but no colliders and no lights of its own.
func _planet(root: Node3D, tiny: bool) -> void:
	var ball := SphereMesh.new()
	ball.radius = PLANET_R
	ball.height = PLANET_R * 2
	ball.radial_segments = 160
	ball.rings = 80
	var turf := StandardMaterial3D.new()
	turf.albedo_texture = load(GRASS_TEX % "diff")
	turf.normal_enabled = true
	turf.normal_texture = load(GRASS_TEX % "nor_gl")
	turf.uv1_triplanar = true
	turf.uv1_scale = Vector3.ONE * 0.3
	turf.albedo_color = Color(0.42, 0.56, 0.3)
	turf.roughness = 0.95
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = ball
	ground.material_override = turf
	root.add_child(ground)
	var house_up := _on_planet(-15.0, 0.0)
	var tree_up := _on_planet(-5.0, -21.0)
	var bed_up := _on_planet(3.0, -12.0)
	_planet_grass(root, [house_up, tree_up, bed_up], [0.105, 0.03, 0.035], tiny)
	var house := Node3D.new()
	house.name = "House"
	_stand(root, house, house_up, Vector3.UP - house_up, 0.12)
	var parts: Dictionary = fold.build_house(house, PLANET, PLANET, not tiny)
	var tree: Node3D = load(TREE).instantiate()
	tree.name = "Tree"
	_stand(root, tree, tree_up, Vector3.BACK, 0.1)
	tree.scale = Vector3.ONE * 2.3
	var bed: Node3D = load(BED).instantiate()
	bed.name = "Bed"
	_stand(root, bed, bed_up, tree_up - bed_up + Vector3(0.0, 0.0, 0.2), 0.02)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(14):
		var up := _on_planet(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0))
		if up.distance_to(house_up) < 0.16 or up.distance_to(Vector3.UP) < 0.05:
			continue
		var bush: Node3D = load(SHRUB if i % 3 == 0 else DANDELION).instantiate()
		_stand(root, bush, up, Vector3.BACK, 0.0)
		bush.scale = Vector3.ONE * (0.6 if i % 3 == 0 else 1.4)
	if tiny:
		for light: Light3D in root.find_children("*", "Light3D", true, false):
			light.queue_free()
		# Only drawn close up: from across the room the tiny planet is a green marble.
		for mesh: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			if mesh != ground:
				mesh.visibility_range_end = 14.0
		return
	planet_house = house
	planet_hinge = parts.hinge
	planet_bed = bed
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		light.light_cull_mask = PLANET
	var body := StaticBody3D.new()
	body.name = "PlanetBody"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PLANET_R
	shape.shape = sphere
	body.add_child(shape)
	root.add_child(body)
	var trunk := StaticBody3D.new()
	var trunk_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.75 / 2.3
	cylinder.height = 6.0 / 2.3
	trunk_shape.shape = cylinder
	trunk_shape.position = Vector3(0, 3.0 / 2.3, 0)
	trunk.add_child(trunk_shape)
	tree.add_child(trunk)
	var bed_body := StaticBody3D.new()
	var bed_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.45, 0.62, 2.0)
	bed_shape.shape = box
	bed_shape.position = Vector3(0, 0.31, 0)
	bed_body.add_child(bed_shape)
	bed.add_child(bed_body)
	portal_planet = Portal.new()
	portal_planet.name = "Doorway"
	(parts.frame as Node3D).add_child(portal_planet)

# Grass all over the planet, every blade stood on the sphere (the tiny planet shares the blades).
var planet_blades: MultiMesh

func _planet_grass(root: Node3D, clear: Array, radius: Array, tiny: bool) -> void:
	if planet_blades == null:
		var count := int(140000 * share)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var placed: Array[Transform3D] = []
		while placed.size() < count:
			var up := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var free := true
			for i in range(clear.size()):
				if up.distance_to(clear[i]) < radius[i]:
					free = false
			if not free:
				continue
			placed.append(Transform3D(Basis(Quaternion(Vector3.UP, up)), up * PLANET_R))
		planet_blades = MultiMesh.new()
		planet_blades.transform_format = MultiMesh.TRANSFORM_3D
		var mesh: ArrayMesh = blade.call(2)
		var material := ShaderMaterial.new()
		material.shader = PLANET_GRASS
		mesh.surface_set_material(0, material)
		planet_blades.mesh = mesh
		planet_blades.instance_count = placed.size()
		for i in range(placed.size()):
			planet_blades.set_instance_transform(i, placed[i])
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = planet_blades
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)

func _layer(root: Node3D, layer: int) -> void:
	for mesh: VisualInstance3D in root.find_children("*", "VisualInstance3D", true, false):
		if not mesh is Light3D:
			mesh.layers = layer

# --- Doorways ----------------------------------------------------------------------------------

# Once the night (and the box's environment) is set: the house's door to the room and back, and
# the planet house's door back out to the box.
func connect_portals(walker: CharacterBody3D, box_environment: Environment) -> void:
	portal_out = Portal.new()
	portal_out.name = "Doorway"
	fold.door_frame.add_child(portal_out)
	portal_room = Portal.new()
	portal_room.name = "Doorway"
	portal_room.transform = Transform3D(Basis(Vector3.UP, PI), DOOR_AT)
	room.add_child(portal_room)
	portal_out.setup(portal_room, room_environment, walker, quality)
	portal_room.setup(portal_out, box_environment, walker, quality)
	portal_room.set_open(1.0)
	portal_out.set_open(0.0)

func _process(delta: float) -> void:
	if portal_out != null:
		portal_out.set_open(smoothstep(0.05, 0.5, fold.door_open))
	if planet_opening:
		planet_door = move_toward(planet_door, 1.0, delta * 0.6)
		planet_hinge.rotation.y = smoothstep(0.0, 1.0, planet_door) * deg_to_rad(100)
		portal_planet.set_open(smoothstep(0.05, 0.5, planet_door))

# --- What the walker can do here ---------------------------------------------------------------

func near_globe(at: Vector3) -> bool:
	if zone(at) != "room" or absf(at.y - table_top()) > 0.8:
		return false
	var flat := Vector2(at.x - globe_centre().x, at.z - globe_centre().z)
	return flat.length() < GLOBE_REACH

func near_planet_door(at: Vector3) -> bool:
	if zone(at) != "planet" or planet_opening:
		return false
	return planet_house.to_local(at).distance_to(Vector3(fold.DOOR_X, 0.5, fold.HOUSE_D / 2 + 1.0)) < fold.DOOR_REACH

func open_planet_door() -> void:
	planet_opening = true

# The planet house's door opens on `meadow`, the dream's meadow as it first was, built in a world
# of its own; stepping out of the doorway is stepping onto `arrive` there.
func link_first_meadow(meadow: Node3D, arrive: Node3D, walker: CharacterBody3D) -> void:
	portal_planet.setup(arrive, null, walker, quality, meadow)
	portal_planet.set_open(0.0)

# The fall into the ball. `eye` is where the eye starts (the player's camera); zoom(t) gives the
# camera at t seconds and, once done, where to stand on the real planet.
func zoom_begin(eye: Transform3D) -> void:
	zoom_from = eye
	zoom_lift = globe_centre() + Vector3.UP * (MINI_R + GLOBE_R + 1.3)

func zoom_length() -> float:
	return ZOOM_OVER + ZOOM_DOWN

const LOOK_DOWN := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

func zoom(t: float) -> Dictionary:
	var landed := Basis.from_euler(Vector3(-0.05, 0, 0))
	if t < ZOOM_OVER:
		var u := smoothstep(0.0, 1.0, t / ZOOM_OVER)
		var mid := (zoom_from.origin + zoom_lift) / 2 + Vector3.UP * 1.2
		var at := zoom_from.origin.lerp(mid, u).lerp(mid.lerp(zoom_lift, u), u)
		var look := zoom_from.basis.orthonormalized().slerp(LOOK_DOWN, smoothstep(0.1, 1.0, u))
		return {"camera": Transform3D(look, at), "near": 0.05, "fog": FOG}
	var v := smoothstep(0.0, 1.0, clampf((t - ZOOM_OVER) / ZOOM_DOWN, 0.0, 1.0))
	var h0 := GLOBE_R + 1.3
	var h1 := EYE / K
	var h := h0 * pow(h1 / h0, v)
	var look2 := LOOK_DOWN.slerp(landed, smoothstep(0.55, 1.0, v))
	var at2 := globe_centre() + Vector3.UP * (MINI_R + h)
	return {"camera": Transform3D(look2, at2), "near": clampf(h * 0.03, 0.001, 0.05), "fog": FOG * pow(1.0 / K, v)}

# Where the fall comes down: on top of the real planet, facing the little house.
func landing() -> Vector3:
	return PLANET_AT + Vector3.UP * (PLANET_R + 0.02)

func start_music() -> void:
	if not music.playing:
		music.play()
