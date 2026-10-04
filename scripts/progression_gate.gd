extends Node3D
var progression: Node3D
var branch := 1
var gate_size := Vector3(3, 2.8, 0.16)
var body: StaticBody3D
var interaction: Area3D
var bars: Node3D
var was_open := false

func _ready() -> void:
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
	bars = Node3D.new()
	add_child(bars)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.17, 0.17)
	material.metallic = 0.65
	material.roughness = 0.65
	# One instanced draw for vertical bars and one for rails, rather than dozens
	# of mesh nodes per barrier on the already large campus.
	var vertical := MultiMeshInstance3D.new()
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.065, gate_size.y, 0.08)
	instances.mesh = bar_mesh
	instances.instance_count = int(gate_size.x / 0.22) + 1
	for i in range(instances.instance_count):
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-gate_size.x / 2 + i * 0.22, gate_size.y / 2, 0)))
	vertical.multimesh = instances
	vertical.material_override = material
	vertical.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bars.add_child(vertical)
	var rails := MultiMeshInstance3D.new()
	var horizontal := MultiMesh.new()
	horizontal.transform_format = MultiMesh.TRANSFORM_3D
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(gate_size.x, 0.08, 0.10)
	horizontal.mesh = rail_mesh
	horizontal.instance_count = 2
	horizontal.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)))
	horizontal.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(0, gate_size.y - 0.25, 0)))
	rails.multimesh = horizontal
	rails.material_override = material
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bars.add_child(rails)
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
	refresh()

func opened() -> bool:
	return progression.roof_open if branch == 4 else progression.completed.has(branch)

func refresh() -> void:
	var open := opened()
	body.collision_layer = 0 if open else 5
	interaction.collision_layer = 0 if open else 16
	bars.visible = not open
	if open and not was_open and progression.world.soundscape != null:
		progression.world.soundscape.at("door", global_position, -14)
	was_open = open

func interaction_text() -> String:
	if branch == 4:
		return "E · Mở sân thượng" if progression.roof_key else "E · Khóa sân thượng"
	return "E · " + ["", "Tủ điều khiển ↗", "Van nước ↗"][branch]

func interact(actor: CharacterBody3D) -> bool:
	if actor != progression.world.player or not progression.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	if branch == 4 and progression.roof_key:
		progression.roof_open = true
		refresh()
		return true
	progression.world.soundscape.cue("lock", -20)
	return false
