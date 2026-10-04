extends Node3D
var progression: Node3D
var kind := 0
var indicator: MeshInstance3D
var npc: Node3D

func _ready() -> void:
	var prop: Node3D = load("res://assets/kenney_furniture/computerScreen.glb").instantiate()
	prop.scale = Vector3.ONE * 0.6
	add_child(prop)
	prop.visible = kind in [0, 1]
	if kind == 2:
		var pipe := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.08
		cylinder.bottom_radius = 0.08
		cylinder.height = 1.05
		cylinder.radial_segments = 12
		pipe.mesh = cylinder
		pipe.rotation.z = PI / 2
		add_child(pipe)
		var valve := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.18
		ring.outer_radius = 0.22
		ring.rings = 12
		ring.ring_segments = 8
		valve.mesh = ring
		valve.rotation.x = PI / 2
		valve.position.z = 0.12
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.60, 0.16, 0.09)
		valve.material_override = red
		add_child(valve)
	if kind == 4:
		var cabinet := MeshInstance3D.new()
		var case_mesh := BoxMesh.new()
		case_mesh.size = Vector3(0.24, 0.70, 1.07)
		cabinet.mesh = case_mesh
		cabinet.position.x = 0.12
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color(0.12, 0.20, 0.21)
		steel.metallic = 0.45
		steel.roughness = 0.72
		cabinet.material_override = steel
		add_child(cabinet)
		var case_body := StaticBody3D.new()
		case_body.collision_layer = 5
		case_body.collision_mask = 0
		var case_collision := CollisionShape3D.new()
		var case_shape := BoxShape3D.new()
		case_shape.size = case_mesh.size
		case_collision.shape = case_shape
		case_collision.position = cabinet.position
		case_body.add_child(case_collision)
		add_child(case_body)
		var key := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.06
		ring.outer_radius = 0.09
		ring.rings = 12
		ring.ring_segments = 8
		key.mesh = ring
		key.rotation.z = PI / 2
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.86, 0.69, 0.30)
		gold.metallic = 0.5
		key.material_override = gold
		key.position.x = -0.07
		var stem := MeshInstance3D.new()
		var stem_mesh := BoxMesh.new()
		stem_mesh.size = Vector3(0.18, 0.035, 0.035)
		stem.mesh = stem_mesh
		stem.position = Vector3(-0.16, 0, 0)
		stem.material_override = gold
		key.add_child(stem)
		var tooth := MeshInstance3D.new()
		var tooth_mesh := BoxMesh.new()
		tooth_mesh.size = Vector3(0.04, 0.035, 0.12)
		tooth.mesh = tooth_mesh
		tooth.position = Vector3(-0.21, 0, 0.04)
		tooth.material_override = gold
		key.add_child(tooth)
		key.name = "RoofKey"
		add_child(key)
	indicator = MeshInstance3D.new()
	var orb := SphereMesh.new()
	orb.radius = 0.045
	orb.height = 0.09
	orb.radial_segments = 8
	orb.rings = 4
	indicator.mesh = orb
	indicator.position = Vector3(0, 0.32, 0)
	indicator.visible = kind != 4
	add_child(indicator)
	var area := Area3D.new()
	area.name = "Interaction"
	area.collision_layer = 16
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.7, 1.05) if kind == 4 else Vector3(0.8, 0.7, 0.35)
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	if kind == 3:
		npc = preload("res://scripts/humanoid_model.gd").new()
		npc.variant = "Casual_Male"
		npc.target_height = 1.65
		npc.shirt_color = Color(0.18, 0.27, 0.30)
		npc.position = Vector3(0, -position.y, -0.85)
		add_child(npc)
		var desk: Node3D = load("res://assets/kenney_furniture/desk.glb").instantiate()
		add_child(desk)
		var bounds := AABB()
		var first := true
		for part in desk.find_children("*", "MeshInstance3D", true, false):
			var local: Transform3D = desk.global_transform.affine_inverse() * part.global_transform
			var bound: AABB = local * part.get_aabb()
			bounds = bound if first else bounds.merge(bound)
			first = false
		var factor := position.y / bounds.size.y
		desk.scale = Vector3.ONE * factor
		desk.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor - Vector3.UP * position.y
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(0.75, 0.025, 0.65)
		board.mesh = board_mesh
		board.position.z = 0.3
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.58, 0.45, 0.28)
		board.material_override = wood
		add_child(board)
		for x in range(5):
			for z in range(5):
				var mark := MeshInstance3D.new()
				var piece := CylinderMesh.new()
				piece.top_radius = 0.025
				piece.bottom_radius = 0.025
				piece.height = 0.015
				piece.radial_segments = 8
				mark.mesh = piece
				mark.position = Vector3(-0.26 + x * 0.13, 0.03, 0.05 + z * 0.13)
				mark.name = "Piece_%d" % (z * 5 + x)
				add_child(mark)
	refresh()

func refresh() -> void:
	var complete: bool = progression.all_complete() if kind == 4 else progression.completed.has(kind)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.36, 0.83, 0.68) if complete else Color(0.88, 0.32, 0.12)
	indicator.material_override = mat
	if kind == 4:
		$RoofKey.visible = not progression.roof_key
	if kind == 3:
		for i in range(25):
			var mark: MeshInstance3D = get_node("Piece_%d" % i)
			mark.visible = progression.puzzles.board[i] != 0
			var piece_mat := StandardMaterial3D.new()
			piece_mat.albedo_color = Color(0.84, 0.87, 0.79) if progression.puzzles.board[i] == 1 else Color(0.06, 0.10, 0.11)
			mark.material_override = piece_mat

func interaction_text() -> String:
	if kind == 3 and not progression.world.spirit_enabled:
		return "Bàn cờ trống"
	if kind == 4:
		return "E · Chìa sân thượng" if progression.all_complete() else "E · Hộp chìa · 4 đèn báo"
	return "E · " + ["Tủ điện", "Điều khiển hành lang", "Van bơm", "Bàn cờ"][kind]

func interact(actor: CharacterBody3D) -> bool:
	if actor != progression.world.player or not progression.world.simulation_active() or actor.get_interaction_target() != self or actor.combat.busy():
		return false
	if kind == 4:
		if not progression.all_complete() or progression.roof_key:
			return false
		progression.roof_key = true
		$RoofKey.hide()
		progression.world.soundscape.cue("pickup")
		progression.world.notify("Chìa sân thượng")
		$Interaction.collision_layer = 0
		return true
	return progression.open_terminal(self)
