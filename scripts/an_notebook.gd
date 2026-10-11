extends Node3D

var story: Node3D
var inspected := false
var lamp: OmniLight3D

func _ready() -> void:
	name = "NguyenBinhAnNotebook"
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(.74,.68,.51)
	paper.roughness = 1
	var cover := paper.duplicate()
	cover.albedo_color = Color(.16,.12,.10)
	for item in [[Vector3(0,.02,0),Vector3(.63,.035,.45),cover], [Vector3(0,.045,0),Vector3(.60,.018,.42),paper]]:
		var part := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = item[1]
		part.mesh = shape
		part.position = item[0]
		part.material_override = item[2]
		add_child(part)
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(.045,.025,.022)
	var rng := RandomNumberGenerator.new()
	rng.seed = 205
	for i in range(44):
		var stroke := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(rng.randf_range(.05,.23),.001,.002)
		stroke.mesh = shape
		stroke.material_override = ink
		stroke.position = Vector3(rng.randf_range(-.2,.2),.056,rng.randf_range(-.15,.15))
		stroke.rotation.y = rng.randf_range(-.7,.7)
		add_child(stroke)
	var label := Label3D.new()
	label.text = "Nguyễn Bình An"
	label.font_size = 32
	label.pixel_size = .00065
	label.modulate = Color(.13,.055,.035)
	label.rotation.x = -PI/2
	label.position = Vector3(0,.058,-.14)
	label.outline_size = 0
	add_child(label)
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.7,.25,.5)
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0,.6,0)
	lamp.light_color = Color(.67,.73,.8)
	lamp.light_energy = .45
	lamp.omni_range = 3
	add_child(lamp)

func set_available(value: bool) -> void:
	visible = value
	$Interaction.collision_layer = 16 if value else 0

func interaction_text() -> String:
	return "E · Mở vở"

func interact(actor: CharacterBody3D) -> bool:
	if actor != story.world.player or not visible or not story.world.simulation_active() or actor.get_interaction_target()!=self: return false
	inspected = true
	story.collect_notebook()
	story.show_panel("notebook","","")
	story.heading.hide()
	story.body_text.hide()
	story.notebook_page.show()
	story.add_option("Đóng vở",story.close)
	story.world.soundscape.cue("paper",-18)
	return true
