extends Node3D

enum Kind { LOCKER, TABLE }
@export var kind: Kind = Kind.LOCKER
var world: Node3D
var occupant: CharacterBody3D
var entry_position := Vector3.ZERO
var inspection_time := 0.0

func _ready() -> void:
	world = get_parent().get_parent()
	add_to_group("hiding_spots")
	if not has_node("Cover"):
		build_cover()

func interaction_text() -> String:
	return "E / Nấp trong tủ" if kind == Kind.LOCKER else "E / Nấp dưới bàn"

func approach_position() -> Vector3:
	return to_global(Vector3(0, 0.05, 1.45))

func hide_position() -> Vector3:
	return to_global(Vector3(0, 0.05, 0))

func interact(actor: CharacterBody3D) -> bool:
	if occupant != null or actor != world.player or not world.simulation_active() or actor.is_hidden() or actor.get_interaction_target() != self:
		return false
	entry_position = actor.global_position
	if not actor.can_fit(hide_position(), 0.68 if kind == Kind.TABLE else 1.75):
		world.notify("Chỗ nấp đang bị chắn.")
		return false
	# Evaluate sight BEFORE lowering the camera or concealing the player.
	for ghost in world.enemies:
		ghost.witness_hiding(self)
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
	inspection_time = 0.0

func inspect_by(ghost: CharacterBody3D, delta: float) -> bool:
	if occupant == null or occupant.hidden_spot != self:
		return true
	inspection_time += delta
	if inspection_time < 1.15:
		return false
	inspection_time = 0.0
	world.notify("Nó thấy bạn nấp ở đây!")
	if occupant.end_hide():
		return true
	# A blocked exit does not confer invulnerability. This only runs after a
	# witnessed entry and a physical approach; ordinary patrol cannot see inside.
	occupant.take_damage(ghost.damage)
	return false

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
		_box(cover, "Back", Vector3(0, 1.14, -0.55), Vector3(1.2, 2.28, 0.09), metal)
		for x in [-0.57, 0.57]:
			_box(cover, "Side", Vector3(x, 1.14, 0), Vector3(0.09, 2.28, 1.18), metal)
		_box(cover, "Top", Vector3(0, 2.25, 0), Vector3(1.2, 0.09, 1.18), metal)
		# Closed door with a narrow eye-level slit, visible from inside the cabinet.
		_box(cover, "DoorLower", Vector3(0, 0.72, 0.56), Vector3(1.02, 1.44, 0.06), metal)
		_box(cover, "DoorUpper", Vector3(0, 1.97, 0.56), Vector3(1.02, 0.50, 0.06), metal)
		for x in [-0.44, 0.44]:
			_box(cover, "VentEdge", Vector3(x, 1.58, 0.56), Vector3(0.14, 0.28, 0.06), metal)
		_box(cover, "Handle", Vector3(0.35, 1.12, 0.62), Vector3(0.055, 0.22, 0.06), Color(0.55, 0.51, 0.36), false)
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
	label.text = "TỦ DỤNG CỤ / E" if kind == Kind.LOCKER else "GẦM BÀN / E"
	label.position = Vector3(0, 2.04, 0.605) if kind == Kind.LOCKER else Vector3(0, 1.18, 0.76)
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
	shape.size = Vector3(1.15, 2.2, 0.18) if kind == Kind.LOCKER else Vector3(2.4, 0.85, 0.2)
	collision.shape = shape
	collision.position = Vector3(0, 1.1, 0.68) if kind == Kind.LOCKER else Vector3(0, 0.55, 0.87)
	area.add_child(collision)
	add_child(area)
