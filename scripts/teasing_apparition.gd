extends Node3D

# A visual encounter, deliberately without a body, hitbox or combat controller.
var model: Node3D
var face: Node3D

func _ready() -> void:
	name = "LaughingStudent"
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "Suit_Male"
	model.target_height = 1.72
	model.faceless = true
	model.shirt_color = Color(0.075, 0.10, 0.16)
	model.rotation.y = PI
	add_child(model)
	face = model.bone_frame("Head", "LaughingMask")
	var pale := ShaderMaterial.new()
	pale.shader = preload("res://assets/materials/ghost_skin.gdshader")
	pale.set_shader_parameter("porcelain", Color(0.55, 0.61, 0.56))
	var oval := SphereMesh.new()
	oval.radius = 0.11
	oval.height = 0.36
	oval.radial_segments = 16
	oval.rings = 8
	_mesh(oval, pale, Vector3(0, 0.14, 0))
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.012, 0.016, 0.02)
	var hair := SphereMesh.new()
	hair.radius = 0.13
	hair.height = 0.13
	hair.radial_segments = 16
	hair.rings = 6
	_mesh(hair, dark, Vector3(0, 0.265, 0))
	for side in [-1, 1]:
		var eye := SphereMesh.new()
		eye.radius = 0.012
		eye.height = 0.075
		eye.radial_segments = 8
		eye.rings = 4
		var socket := _mesh(eye, dark, Vector3(side * 0.038, 0.18, 0.105))
		socket.scale.z = 0.25
	# Blank eye region and a narrow curved smile, not a written warning.
	for i in range(11):
		var x := (i - 5) * 0.014
		var bead := SphereMesh.new()
		bead.radius = 0.005
		bead.height = 0.015
		bead.radial_segments = 6
		bead.rings = 3
		_mesh(bead, dark, Vector3(x, 0.04 + pow(x * 3.5, 2) + sin(i * 1.4) * 0.007, sqrt(0.11 * 0.11 - x * x) * 0.81))
	hide()
	set_process(false)
	model.set_process(false)
	model.animation.speed_scale = 0

func _mesh(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	face.add_child(part)
	return part

func appear(at: Vector3, observer: Vector3) -> void:
	global_position = at
	look_at(Vector3(observer.x, at.y, observer.z))
	face.rotation.z = -0.40
	model.reach = 0.8
	model.animation.speed_scale = 0.8
	model.animation.play("idle")
	model.set_process(true)
	show()

func retreat(direction: Vector3) -> void:
	look_at(global_position + direction)
	model.reach = 0
	model.animation.speed_scale = 2.6
	model.animation.play("sprint")

func vanish() -> void:
	hide()
	model.set_process(false)
	model.animation.speed_scale = 0
