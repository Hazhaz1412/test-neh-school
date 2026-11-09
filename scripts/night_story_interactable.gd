extends Node3D

var story: Node3D
# "clip" (room 103) or "mirror" (the restroom cabinet): the prologue's evidence.
var kind := "clip"
var index := 0
var caption := ""
var visual: Node3D

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	if kind == "mirror":
		_build_hand_mirror()
	else:
		_build_hair_clip()
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 0.3, 0.45)
	collider.shape = shape
	collider.position.y = 0.08
	area.add_child(collider)
	add_child(area)

func _paint(color: Color, metallic := 0.0, roughness := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _part(mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = mat
	(parent if parent != null else visual).add_child(node)
	return node

func _glint(pos: Vector3, size: float, phase: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/glint.gdshader")
	mat.set_shader_parameter("phase", phase)
	mat.set_shader_parameter("intensity", 0.9)
	var node := _part(quad, pos, Vector3.ZERO, mat)
	node.name = "Glint"
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

# A pink plastic barrette snapped in two, about 8 cm long, with a rhinestone flower that catches
# the classroom lamp. The halves lie a few centimetres apart, the spring clasp bent out.
func _build_hair_clip() -> void:
	var plastic := _paint(Color(0.72, 0.16, 0.36), 0.0, 0.42)
	var steel := _paint(Color(0.72, 0.73, 0.75), 0.9, 0.25)
	var pearl := _paint(Color(0.95, 0.93, 0.88), 0.2, 0.15)
	var gem := _paint(Color(0.92, 0.96, 1.0), 0.1, 0.02)
	gem.emission_enabled = true
	gem.emission = Color(0.9, 0.95, 1.0)
	gem.emission_energy_multiplier = 0.6
	var halves := [[Vector3(-0.022, 0.006, 0.0), 0.12, 0.048], [Vector3(0.034, 0.006, 0.012), -0.42, 0.034]]
	for i in range(halves.size()):
		var half := Node3D.new()
		half.position = halves[i][0]
		half.rotation.y = halves[i][1]
		visual.add_child(half)
		var length: float = halves[i][2]
		var body := CapsuleMesh.new()
		body.radius = 0.008
		body.height = length
		var shell := _part(body, Vector3.ZERO, Vector3(0, 0, PI / 2), plastic, half)
		shell.scale = Vector3(0.35, 1.0, 1.0)
		var bar := BoxMesh.new()
		bar.size = Vector3(length * 0.92, 0.0016, 0.004)
		_part(bar, Vector3(0, -0.004, 0), Vector3(0, 0, 0.18 if i == 1 else 0.0), steel, half)
		# The broken ends: jagged little teeth of plastic.
		var tooth := PrismMesh.new()
		tooth.size = Vector3(0.006, 0.006, 0.004)
		for k in range(3):
			var side := 1.0 if i == 0 else -1.0
			_part(tooth, Vector3(side * length * 0.5, 0.0, -0.005 + k * 0.005), Vector3(0, 0, side * -PI / 2), plastic, half)
	# The flower sits on the longer half; one petal broke off and lies beside it.
	var petal := SphereMesh.new()
	petal.radius = 0.0055
	petal.height = 0.004
	for k in range(5):
		var a := k * TAU / 5.0
		if k == 3: continue
		_part(petal, Vector3(-0.026 + cos(a) * 0.0065, 0.012, sin(a) * 0.0065), Vector3.ZERO, pearl)
	_part(petal, Vector3(0.006, 0.003, 0.03), Vector3(0.3, 0, 0), pearl)
	var stone := SphereMesh.new()
	stone.radius = 0.0033
	stone.height = 0.0045
	_part(stone, Vector3(-0.026, 0.014, 0.0), Vector3.ZERO, gem)
	# Real size would be a speck on the classroom floor; keep it readable at a glance.
	visual.scale = Vector3.ONE * 2.4
	var glint := _glint(Vector3(-0.026, 0.02, 0.0), 0.16, 0.0)
	glint.material_override.set_shader_parameter("intensity", 1.0)

# A round hand mirror with a plastic back and handle; the glass has a star fracture and the
# middle is gone. It lies face up so the cracks catch the torch.
func _build_hand_mirror() -> void:
	var frame := _paint(Color(0.55, 0.36, 0.42), 0.0, 0.35)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.058
	ring.outer_radius = 0.068
	ring.rings = 24
	ring.ring_segments = 8
	var rim := _part(ring, Vector3(0, 0.008, 0), Vector3.ZERO, frame)
	rim.scale = Vector3(1, 0.7, 1.15)
	var back := CylinderMesh.new()
	back.top_radius = 0.062
	back.bottom_radius = 0.062
	back.height = 0.008
	back.radial_segments = 24
	var plate := _part(back, Vector3(0, 0.004, 0), Vector3.ZERO, frame)
	plate.scale = Vector3(1, 1, 1.15)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.011
	handle.bottom_radius = 0.009
	handle.height = 0.11
	handle.radial_segments = 10
	_part(handle, Vector3(0, 0.008, 0.125), Vector3(PI / 2, 0, 0), frame)
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.058
	glass_mesh.bottom_radius = 0.058
	glass_mesh.height = 0.002
	glass_mesh.radial_segments = 28
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://assets/materials/cracked_glass.gdshader")
	glass.set_shader_parameter("impact", Vector2(0.42, 0.55))
	glass.set_shader_parameter("hole", 0.10)
	var face := _part(glass_mesh, Vector3(0, 0.0095, 0), Vector3.ZERO, glass)
	face.scale = Vector3(1, 1, 1.15)
	# Two shards came loose and lie beside it.
	var shard := PrismMesh.new()
	shard.size = Vector3(0.02, 0.03, 0.0015)
	var loose := _paint(Color(0.7, 0.74, 0.76), 1.0, 0.05)
	_part(shard, Vector3(0.09, 0.002, -0.03), Vector3(-PI / 2, 0, 0.6), loose)
	_part(shard, Vector3(0.075, 0.002, 0.04), Vector3(-PI / 2, 0, -1.9), loose)
	_glint(Vector3(-0.01, 0.02, 0.005), 0.16, 1.3)

func set_available(value: bool) -> void:
	visible = value
	$Interaction.collision_layer = 16 if value else 0

func interaction_text() -> String:
	return "E · Lấy chiếc gương cầm tay" if kind == "mirror" else "E · Nhặt chiếc cài tóc"

func interact(actor: CharacterBody3D) -> bool:
	if actor != story.world.player or not story.world.simulation_active() or actor.get_interaction_target() != self:
		return false
	return story.interact_with(self)
