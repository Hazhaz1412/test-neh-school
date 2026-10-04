extends Node3D

var world: Node3D
var kind := "battery"
var collected := false
var dropped := false

func _ready() -> void:
	var colors := {"battery": Color(0.67, 0.55, 0.18), "medicine": Color(0.48, 0.65, 0.57), "chalk": Color(0.73, 0.73, 0.65), "gate": Color(0.5, 0.72, 0.6), "camera": Color(0.30, 0.39, 0.45), "torch": Color(0.55, 0.57, 0.48)}
	if kind == "camera":
		var camera_model: Node3D = preload("res://scripts/held_item.gd").camera_model()
		camera_model.scale *= 0.6
		camera_model.position.y = -0.02
		add_child(camera_model)
	elif kind != "gate":
		var model := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.24, 0.20, 0.14) if kind != "medicine" else Vector3(0.38, 0.24, 0.22)
		model.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[kind]
		material.emission_enabled = true
		material.emission = colors[kind] * 0.22
		model.material_override = material
		add_child(model)
		if kind == "medicine":
			var cross := Label3D.new()
			cross.text = "+"
			cross.font_size = 32
			cross.pixel_size = 0.004
			cross.position = Vector3(0, 0, 0.12)
			add_child(cross)
	var label := Label3D.new()
	label.text = "CỔNG PHONG KÍN / E" if kind == "gate" else world.player.ITEM_NAMES[kind]
	label.font_size = 24
	label.pixel_size = 0.003 if kind != "gate" else 0.01
	label.position.y = 0.3 if kind != "gate" else 0.8
	label.modulate = colors[kind]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if kind != "gate" else BaseMaterial3D.BILLBOARD_DISABLED
	add_child(label)
	label.hide()
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.5, 0.5) if kind != "gate" else Vector3(3, 2.2, 0.3)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)

func reset_item() -> void:
	collected = false
	show()
	$Interaction.collision_layer = 16

func interaction_text() -> String:
	if kind == "gate":
		if not world.survival.active:
			return "N / Bắt đầu đêm sinh tồn"
		return "E · Cổng phong kín"
	return "E · " + world.player.ITEM_NAMES[kind]

func interact(actor: CharacterBody3D) -> bool:
	if collected or actor != world.player or not world.simulation_active() or actor.get_interaction_target() != self:
		return false
	if kind == "gate":
		world.notify("Chìa tổng chỉ mở các phòng. Phải sống tới 06:00 và giải cứu linh hồn để phá lời nguyền.")
		return false
	if not actor.add_item(kind):
		world.notify("Túi đầy · Q thả vật đang chọn")
		return false
	world.soundscape.cue("pickup", -22)
	collected = true
	hide()
	$Interaction.collision_layer = 0
	world.notify("Đã cất " + actor.ITEM_NAMES[kind] + " · 1–6 chọn đồ")
	if dropped:
		queue_free()
	return true
