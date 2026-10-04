extends Node3D

var quest: Node3D
var index := 0
var collected := false
var emblem: MeshInstance3D

func _ready() -> void:
	var entry: Dictionary = quest.memories[index]
	if entry.model != "bandage":
		var prop: Node3D = load("res://assets/kenney_furniture/%s.glb" % entry.model).instantiate()
		add_child(prop)
		var bounds := AABB()
		var first := true
		for part in prop.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = prop.global_transform.affine_inverse() * part.global_transform * part.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var factor := 0.36 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		prop.scale = Vector3.ONE * factor
		prop.position = -bounds.get_center() * factor
	else:
		var band := MeshInstance3D.new()
		var band_mesh := TorusMesh.new()
		band_mesh.inner_radius = 0.06
		band_mesh.outer_radius = 0.11
		band_mesh.rings = 16
		band_mesh.ring_segments = 8
		band.mesh = band_mesh
		var cotton := StandardMaterial3D.new()
		cotton.albedo_color = Color(0.75, 0.70, 0.56)
		cotton.roughness = 1
		band.material_override = cotton
		add_child(band)
	emblem = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 12
	sphere.rings = 6
	emblem.mesh = sphere
	emblem.position.y = 0.23
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.42, 0.76, 0.80)
	glow.emission_enabled = true
	glow.emission = Color(0.24, 0.52, 0.58)
	glow.emission_energy_multiplier = 1.4
	emblem.material_override = glow
	add_child(emblem)
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.65, 0.5, 0.65)
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	hide()

func interaction_text() -> String:
	return "E · " + quest.memories[index].item

func interact(actor: CharacterBody3D) -> bool:
	return quest.collect(index, actor)

func reset_fragment() -> void:
	collected = false
	$Interaction.collision_layer = 16

func _process(_delta: float) -> void:
	if quest.world == null:
		return
	visible = not collected and quest.fragment_available(index) and quest.world.survival.active and quest.world.survival.phase == quest.world.survival.Phase.NIGHT and quest.world.spirit_enabled
	$Interaction.collision_layer = 16 if visible else 0
	emblem.position.y = 0.23 + sin(quest.world.elapsed * 2 + index) * 0.025
