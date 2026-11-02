extends Node3D

# A folding iron gate across a staircase. It stays jammed until the
# club scare, then concertinas towards its right-hand post by itself.
var progression: Node3D
var gate_size := Vector3(3.8, 3.5, 0.16)
var body: StaticBody3D
var interaction: Area3D
var leaf: Node3D
var was_open := true
var folded := 1.0

func _ready() -> void:
	name = "StairGate"
	body = StaticBody3D.new()
	body.collision_layer = 5
	body.collision_mask = 0
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = gate_size
	collider.shape = shape
	collider.position.y = gate_size.y / 2
	body.add_child(collider)
	leaf = Node3D.new()
	leaf.position.x = gate_size.x / 2
	add_child(leaf)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.17, 0.17)
	material.metallic = 0.65
	material.roughness = 0.65
	# One instanced draw for the bars and one for the rails.
	var vertical := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.065, gate_size.y, 0.08)
	instances.mesh = bar_mesh
	instances.instance_count = int(gate_size.x / 0.22) + 1
	for i in range(instances.instance_count):
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-gate_size.x + i * 0.22, gate_size.y / 2, 0)))
	vertical.multimesh = instances
	vertical.material_override = material
	vertical.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(vertical)
	var rails := MultiMeshInstance3D.new()
	var horizontal := MultiMesh.new()
	horizontal.transform_format = MultiMesh.TRANSFORM_3D
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(gate_size.x, 0.08, 0.10)
	horizontal.mesh = rail_mesh
	horizontal.instance_count = 3
	for i in range(3):
		horizontal.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-gate_size.x / 2, 0.25 + i * (gate_size.y - 0.5) / 2, 0)))
	rails.multimesh = horizontal
	rails.material_override = material
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(rails)
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.14, gate_size.y, 0.2)
		post.mesh = post_mesh
		post.material_override = material
		post.position = Vector3(side * gate_size.x / 2, gate_size.y / 2, 0)
		add_child(post)
	interaction = Area3D.new()
	interaction.collision_layer = 16
	interaction.collision_mask = 0
	var touch := CollisionShape3D.new()
	var touch_shape := BoxShape3D.new()
	touch_shape.size = gate_size + Vector3(0.05, 0, 0.10)
	touch.shape = touch_shape
	touch.position.y = gate_size.y / 2
	interaction.add_child(touch)
	add_child(interaction)
	refresh(true)

func opened() -> bool:
	return progression.stairs_open or not progression.world.survival.active

func refresh(instant := false) -> void:
	var open := opened()
	if open != was_open or instant:
		was_open = open
		body.collision_layer = 0 if open else 5
		interaction.collision_layer = 0 if open else 16
		# It only ever folds away on screen; a new night starts with it shut.
		if instant or not open: folded = 1.0 if open else 0.0

func _process(delta: float) -> void:
	refresh()
	folded = move_toward(folded, 1.0 if was_open else 0.0, delta / 1.2)
	leaf.scale.x = lerpf(1.0, 0.09, smoothstep(0.0, 1.0, folded))

func interaction_text() -> String:
	return "E · Cửa sắt cầu thang"

func interact(actor: CharacterBody3D) -> bool:
	if actor != progression.world.player or not progression.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	progression.world.soundscape.at("lock", global_position + Vector3.UP, -14)
	return false
