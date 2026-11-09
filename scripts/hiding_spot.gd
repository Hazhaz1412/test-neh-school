extends Node3D

enum Kind { LOCKER, TABLE, BED }
# How close something has to come to spot a hider. Metal doors hide you completely, a desk barely.
const SEEN_FROM := {Kind.LOCKER: 0.0, Kind.TABLE: 5.5, Kind.BED: 1.3}
const EYE_HEIGHT := {Kind.LOCKER: 1.58, Kind.TABLE: 0.52, Kind.BED: 0.16}
const CRAWL_HEIGHT := 0.68
const BED_SIZE := Vector3(2.1, 0.38, 1.0)
const BED_DECK := 0.42
const BED_HEM := 0.3
@export var kind: Kind = Kind.LOCKER
var world: Node3D
var occupant: CharacterBody3D
var entry_position := Vector3.ZERO

func _ready() -> void:
	if world == null: world = get_parent().get_parent()
	add_to_group("hiding_spots")
	if not has_node("Cover"):
		build_cover()

func interaction_text() -> String:
	return ["E / Nấp trong tủ", "E / Nấp dưới bàn", "E / Chui xuống gầm giường"][kind]

func approach_position() -> Vector3:
	return to_global(Vector3(0, 0.05, 1.45))

func hide_position() -> Vector3:
	return to_global(Vector3(0, 0.05, 0))

func body_height() -> float:
	return 1.75 if kind == Kind.LOCKER else CRAWL_HEIGHT

func eye_height() -> float:
	return EYE_HEIGHT[kind]

func seen_from() -> float:
	return SEEN_FROM[kind]

func interact(actor: CharacterBody3D) -> bool:
	if occupant != null or actor != world.player or not world.simulation_active() or actor.is_hidden() or actor.get_interaction_target() != self:
		return false
	entry_position = actor.global_position
	if not actor.can_fit(hide_position(), body_height()):
		world.notify("Chỗ nấp đang bị chắn.")
		return false
	# Evaluate sight BEFORE lowering the camera or concealing the player.
	if world.get("hunt") != null and world.hunt.hunter != null:
		world.hunt.hunter.witness(self)
	occupant = actor
	actor.begin_hide(self)
	return true

func exit_candidates() -> Array[Vector3]:
	var candidates: Array[Vector3] = [entry_position]
	for z in [1.5, 2.1]:
		for x in [0.0, -0.65, 0.65]:
			candidates.append(to_global(Vector3(x, 0.05, z)))
	return candidates

func release() -> void:
	occupant = null

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, solid := true) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = size
		shape.shape = collider
		body.position = pos
		body.add_child(shape)
		parent.add_child(body)

func build_cover() -> void:
	var cover := Node3D.new()
	cover.name = "Cover"
	add_child(cover)
	if kind == Kind.LOCKER:
		var metal := Color(0.19, 0.28, 0.25)
		_box(cover, "Back", Vector3(0, 1.05, -0.355), Vector3(0.94, 2.1, 0.09), metal)
		for x in [-0.425, 0.425]:
			_box(cover, "Side", Vector3(x, 1.05, 0), Vector3(0.09, 2.1, 0.8), metal)
		_box(cover, "Top", Vector3(0, 2.06, 0), Vector3(0.94, 0.09, 0.8), metal)
		# Closed door with a narrow eye-level slit, visible from inside the cabinet.
		_box(cover, "DoorLower", Vector3(0, 0.72, 0.37), Vector3(0.76, 1.44, 0.06), metal)
		_box(cover, "DoorUpper", Vector3(0, 1.87, 0.37), Vector3(0.76, 0.30, 0.06), metal)
		for x in [-0.33, 0.33]:
			_box(cover, "VentEdge", Vector3(x, 1.58, 0.37), Vector3(0.10, 0.28, 0.06), metal)
		_box(cover, "Handle", Vector3(0.27, 1.12, 0.42), Vector3(0.05, 0.22, 0.05), Color(0.55, 0.51, 0.36), false)
	elif kind == Kind.BED:
		_build_bed(cover)
	else:
		# Reuse the existing Kenney desk, with explicit top/leg colliders so the
		# underside is genuinely hollow rather than its old full AABB collider.
		var model: Node3D = preload("res://assets/kenney_furniture/desk.glb").instantiate()
		model.name = "KenneyDesk"
		# All descendants are authored into the generated campus. Break instance
		# inheritance so PackedScene does not also recreate duplicate GLB children.
		model.scene_file_path = ""
		model.set_meta("source_asset", "res://assets/kenney_furniture/desk.glb")
		cover.add_child(model)
		var bounds := AABB()
		var started := false
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var part: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			bounds = bounds.merge(part) if started else part
			started = true
		var scale_to := Vector3(2.6, 1.15, 1.5) / bounds.size
		model.scale = scale_to
		model.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_to
		var wood := Color(0.30, 0.21, 0.13)
		# Thin structural parts also make the tall work table legible at a glance.
		_box(cover, "TableTop", Vector3(0, 1.1, 0), Vector3(2.6, 0.1, 1.5), wood)
		for x in [-1.16, 1.16]:
			for z in [-0.61, 0.61]:
				_box(cover, "TableLeg", Vector3(x, 0.52, z), Vector3(0.12, 1.04, 0.12), wood)
	var label := Label3D.new()
	label.name = "HideSign"
	label.text = ["TỦ DỤNG CỤ / E", "GẦM BÀN / E", "GẦM GIƯỜNG / E"][kind]
	label.position = [Vector3(0, 1.9, 0.405), Vector3(0, 1.18, 0.76), Vector3(0, 0.62, BED_SIZE.z * 0.5 + 0.02)][kind]
	label.font_size = 22
	label.pixel_size = 0.0025
	label.modulate = Color(0.72, 0.77, 0.63)
	cover.add_child(label)
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = [Vector3(0.86, 2.0, 0.18), Vector3(2.4, 0.85, 0.2), Vector3(2.0, 0.75, 0.2)][kind]
	collision.shape = shape
	collision.position = [Vector3(0, 1.0, 0.48), Vector3(0, 0.55, 0.87), Vector3(0, 0.4, BED_SIZE.z * 0.5 + 0.12)][kind]
	area.add_child(collision)
	add_child(area)

# A sick-bay cot: the CC0 bed raised on steel legs. The sheet hangs low on every side, so from
# underneath only the floor and whatever is walking on it can be seen.
func _build_bed(cover: Node3D) -> void:
	var model: Node3D = preload("res://assets/home/bed.glb").instantiate()
	model.name = "Cot"
	cover.add_child(model)
	var bounds := AABB()
	var started := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(part) if started else part
		started = true
	var fit := Vector3(BED_SIZE.z, BED_SIZE.y, BED_SIZE.x) / bounds.size
	model.scale = fit
	model.rotation.y = PI * 0.5
	model.position = Basis(Vector3.UP, PI * 0.5) * (-bounds.get_center() * fit) + Vector3(0, BED_DECK + BED_SIZE.y * 0.5, 0)
	var steel := Color(0.34, 0.36, 0.37)
	var sheet := Color(0.56, 0.58, 0.54)
	_box(cover, "CotDeck", Vector3(0, BED_DECK, 0), Vector3(BED_SIZE.x, 0.05, BED_SIZE.z), steel, false)
	for x in [-0.98, 0.98]:
		for z in [-0.42, 0.42]:
			_box(cover, "CotLeg", Vector3(x, BED_DECK * 0.5, z), Vector3(0.06, BED_DECK, 0.06), steel)
	var drop: float = BED_DECK + 0.08 - BED_HEM
	for z in [-0.5, 0.5]:
		_box(cover, "Sheet", Vector3(0, BED_HEM + drop * 0.5, z * BED_SIZE.z), Vector3(BED_SIZE.x, drop, 0.02), sheet, false)
	for x in [-0.5, 0.5]:
		_box(cover, "Sheet", Vector3(x * BED_SIZE.x, BED_HEM + drop * 0.5, 0), Vector3(0.02, drop, BED_SIZE.z), sheet, false)
	# Solid only above crawling height, so the capsule fits underneath.
	var top := StaticBody3D.new()
	top.name = "CotTop"
	top.collision_mask = 0
	var collider := CollisionShape3D.new()
	var plate := BoxShape3D.new()
	plate.size = Vector3(BED_SIZE.x, 0.2, BED_SIZE.z)
	collider.shape = plate
	collider.position.y = CRAWL_HEIGHT + 0.2
	top.add_child(collider)
	cover.add_child(top)
