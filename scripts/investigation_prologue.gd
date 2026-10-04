extends Node3D

# Fictional evidence, authored as readable 3D newspaper cards rather than bitmaps.
const ORIGIN := Vector3(150, 0, 0)
var opening: Node3D
var equipment: Array[Node3D] = []
var board: Node3D
var last_foley := false
var comparison_report: MeshInstance3D

func setup(cinematic: Node3D) -> void:
	opening = cinematic
	name = "InvestigationRoom"
	position = ORIGIN
	_box(self, "Floor", Vector3(0, -0.10, 0), Vector3(9, 0.15, 9), Color(0.12, 0.14, 0.15))
	_box(self, "BackWall", Vector3(0, 2, -4.3), Vector3(9, 4, 0.15), Color(0.17, 0.21, 0.23))
	_box(self, "SideWall", Vector3(-4.5, 2, 0), Vector3(0.15, 4, 9), Color(0.13, 0.17, 0.18))
	_box(self, "Ceiling", Vector3(0, 4.1, 0), Vector3(9, 0.15, 9), Color(0.10, 0.14, 0.15))
	board = Node3D.new()
	board.name = "EvidenceBoard"
	board.position = Vector3(0, 2.30, -4.1)
	add_child(board)
	_box(board, "CorkBoard", Vector3.ZERO, Vector3(5.5, 2.7, 0.08), Color(0.27, 0.21, 0.16))
	_label(board, "HỒ SƠ NEH / NHỮNG NGƯỜI CHƯA TRỞ VỀ", Vector3(0, 1.12, 0.06), 0.0042, Color(0.89, 0.81, 0.61))
	var cards := [
		[Vector2(-1.75, 0.45), "BÁO ĐỊA PHƯƠNG\nHỌC SINH MẤT TÍCH\nLần cuối ở dãy lớp học B", Vector2(1.48, 1.04)],
		[Vector2(0, 0.40), "HỒ SƠ VỤ ÁN / 01\nLỜI KHAI BỎ TRỐNG\nAi đã ở lại sau giờ học?", Vector2(1.48, 1.04)],
		[Vector2(1.75, 0.45), "LỜI KỂ NGƯỜI GÁC\nCHUÔNG LÚC 00:00\nTrường đã bị cắt điện", Vector2(1.48, 1.04)],
		[Vector2(-1.75, -0.66), "ẢNH CAMERA / CỔNG\nKHÔNG AI TRỞ RA\n23:30 · lần cuối xuất hiện", Vector2(1.48, 1.04)],
		[Vector2(0, -0.70), "MẢNH NHẬT KÝ\n'MÌNH SỢ ĐẾN LỚP'\nMột trang giấy bị xé", Vector2(1.48, 1.04)],
		[Vector2(1.75, -0.66), "SƠ ĐỒ / KHU A ↔ B\nCÙNG MỘT ĐỊA ĐIỂM\nKho phía Tây · sân trong", Vector2(1.48, 1.04)]]
	var photos := ["campus-preview", "hallway-preview", "window-moon-preview", "warehouse-exterior-preview", "realm-handprints-preview", "campus-ab-preview"]
	for i in range(cards.size()):
		var paper := Node3D.new()
		paper.name = "Clue_%02d" % i
		paper.position = Vector3(cards[i][0].x, cards[i][0].y, 0.07)
		paper.rotation.z = (-0.035 if i % 2 else 0.045)
		board.add_child(paper)
		_box(paper, "Paper", Vector3.ZERO, Vector3(cards[i][2].x, cards[i][2].y, 0.008), Color(0.70, 0.68, 0.57))
		var lines: PackedStringArray = cards[i][1].split("\n")
		_label(paper, lines[0] + "\n" + lines[1], Vector3(0, 0.34, 0.02), 0.0015, Color(0.085, 0.09, 0.075))
		_label(paper, lines[2], Vector3(0, -0.39, 0.02), 0.0011, Color(0.14, 0.14, 0.12))
		var photo := MeshInstance3D.new()
		photo.name = "EvidencePhoto"
		var quad := QuadMesh.new()
		quad.size = Vector2(1.27, 0.43)
		photo.mesh = quad
		photo.position = Vector3(0, -0.02, 0.015)
		var photo_mat := StandardMaterial3D.new()
		photo_mat.albedo_texture = load("res://docs/%s.png" % photos[i])
		photo_mat.albedo_color = Color(0.80, 0.80, 0.72)
		photo_mat.uv1_scale = Vector3(0.8, 0.50, 1)
		photo_mat.uv1_offset = Vector3(0.1, 0.25, 0)
		photo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		photo.material_override = photo_mat
		paper.add_child(photo)
		var circle := MeshInstance3D.new()
		circle.name = "RedCircle"
		var ring := TorusMesh.new()
		ring.inner_radius = 0.17
		ring.outer_radius = 0.184
		ring.rings = 32
		ring.ring_segments = 6
		circle.mesh = ring
		circle.rotation.x = PI / 2
		circle.scale = Vector3(1.45, 0.76, 1)
		circle.position = Vector3(-0.22 if i % 2 else 0.20, -0.015, 0.032)
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.66, 0.025, 0.035)
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		circle.material_override = red
		paper.add_child(circle)
		_box(paper, "RedPin", Vector3(0, cards[i][2].y * 0.46, 0.027), Vector3(0.04, 0.04, 0.02), Color(0.52, 0.025, 0.035))
	for edge in [[0, 1], [1, 2], [0, 3], [1, 4], [2, 5], [4, 5], [3, 4]]:
		var a: Vector2 = cards[edge[0]][0]
		var b: Vector2 = cards[edge[1]][0]
		var cord := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.009
		cylinder.bottom_radius = 0.009
		cylinder.height = a.distance_to(b)
		cylinder.radial_segments = 5
		cord.mesh = cylinder
		cord.position = Vector3((a.x + b.x) / 2, (a.y + b.y) / 2, 0.06)
		cord.rotation.z = -atan2(b.x - a.x, b.y - a.y)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.40, 0.025, 0.028)
		cord.material_override = mat
		board.add_child(cord)
	_prop("desk", Vector3(0, 0, -0.5), Vector3(2.2, 1.6, 1.4))
	_prop("desk", Vector3(2.7, 0, -2.5), Vector3(3.8, 1.6, 1.6))
	_prop("bookcaseOpen", Vector3(-3.7, 0, -3.6), Vector3(1.3, 1.3, 1.3))
	_prop("books", Vector3(-0.9, 0.84, -0.4), Vector3.ONE * 0.7)
	_prop("computerScreen", Vector3(0.9, 0.84, -0.8), Vector3.ONE * 0.8)
	_prop("cardboardBoxClosed", Vector3(3.8, 0, -2.9), Vector3.ONE * 0.8)
	var paper_hand: Node3D = opening.actors[1].bone_frame("Fist.R", "EvidencePaper")
	comparison_report = _box(paper_hand, "ComparedReport", Vector3(0, 0, 0.08), Vector3(0.28, 0.01, 0.34), Color(0.71, 0.69, 0.60))
	comparison_report.hide()
	for x in [-1.0, 0.0, 1.0]:
		var report := _box(self, "TableReport", Vector3(x, 0.87, -0.2), Vector3(0.52, 0.008, 0.40), Color(0.65, 0.65, 0.55))
		report.rotation.y = x * 0.12
	for i in range(4):
		var kit := Node3D.new()
		kit.name = "PreparedKit_%d" % i
		add_child(kit)
		kit.position = Vector3(1.5 + i * 0.7, 0.9, -2.5)
		_box(kit, "EquipmentBag", Vector3.ZERO, Vector3(0.32, 0.36, 0.18), Color(0.12, 0.17, 0.19))
		_box(kit, "Journal", Vector3(0.18, 0.05, 0), Vector3(0.12, 0.24, 0.15), Color(0.30, 0.16, 0.13))
		var torch := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.height = 0.22
		cylinder.top_radius = 0.045
		cylinder.bottom_radius = 0.034
		cylinder.radial_segments = 10
		torch.mesh = cylinder
		var torch_material := StandardMaterial3D.new()
		torch_material.albedo_color = Color(0.32, 0.34, 0.31)
		torch.material_override = torch_material
		torch.position = Vector3(-0.18, 0, 0)
		kit.add_child(torch)
		equipment.append(kit)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.4, 0.2)
	light.omni_range = 10
	light.light_energy = 2.3
	light.light_color = Color(0.84, 0.76, 0.57)
	light.shadow_enabled = false
	add_child(light)

func _box(parent: Node3D, label: String, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	node.material_override = mat
	parent.add_child(node)
	return node

func _label(parent: Node3D, text: String, pos: Vector3, pixel: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 44
	label.pixel_size = pixel
	label.position = pos
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)

func _prop(asset: String, pos: Vector3, scale_by: Vector3) -> void:
	var prop: Node3D = load("res://assets/kenney_furniture/%s.glb" % asset).instantiate()
	prop.position = pos
	prop.scale = scale_by
	add_child(prop)

func sample(time: float) -> void:
	comparison_report.visible = time >= 11 and time < 24
	var places := [Vector3(-1.35, 0, -2.0), Vector3(1.3, 0, -1.8), Vector3(-1.45, 0, 0.7), Vector3(1.40, 0, 0.7)]
	for i in range(4):
		var actor: Node3D = opening.actors[i]
		actor.head_pitch = 0
		actor.reach = 0
		actor.hand_target = Vector3(INF, INF, INF)
		actor.show()
		actor.position = ORIGIN + places[i]
		actor.rotation = Vector3.ZERO
		actor.look_at(ORIGIN + Vector3(0, 0, -0.4), Vector3.UP, true)
		opening._animate(i, "idle")
		if time >= 7 and time < 11:
			if i == 0:
				actor.position = ORIGIN + Vector3(-1.3, 0, -3.0)
				actor.look_at(ORIGIN + Vector3(0, 0, -4.1), Vector3.UP, true)
				actor.reach = 0.75
			else:
				actor.look_at(ORIGIN + Vector3(-1.3, 0, -3.0), Vector3.UP, true)
		if time >= 11 and time < 24 and i == 1:
			actor.reach = 0.7
			actor.head_pitch = 0.18
		if time >= 24 and time < 29:
			actor.head_pitch = sin(clampf((time - 24 - i * 0.5) / 1.6, 0, 1) * PI) * 0.32
		if time >= 29:
			var progress := clampf((time - 29) / 4, 0, 1)
			actor.position = ORIGIN + places[i].lerp(Vector3(1.5 + i * 0.7, 0, -1.4), progress)
			actor.rotation.y = PI
			opening._animate(i, "walk" if progress < 0.85 else "pickup")
			if progress >= 1:
				if equipment[i].get_parent() == self:
					var hand: Node3D = actor.bone_frame("Fist.R", "EquipmentHand")
					equipment[i].reparent(hand)
					equipment[i].position = Vector3(0, -0.14, 0)
				actor.reach = 0.75
	if time < 7:
		opening._shot(ORIGIN + Vector3(-0.4, 2.4, -0.25), ORIGIN + Vector3(0.3, 2.3, -0.6), ORIGIN + Vector3(0, 2.3, -4.1), time / 7)
	elif time < 17:
		opening._shot(ORIGIN + Vector3(4.0, 2.7, 3.1), ORIGIN + Vector3(3.6, 2.3, 2.5), ORIGIN + Vector3(0, 1.4, -1.2), (time - 7) / 10)
	elif time < 24:
		opening._shot(ORIGIN + Vector3(0.1, 1.8, 0.6), ORIGIN + Vector3(0.4, 1.75, 0.3), ORIGIN + Vector3(1.3, 1.45, -1.8), (time - 17) / 7)
	elif time < 29:
		opening._shot(ORIGIN + Vector3(0, 2.2, 3.1), ORIGIN + Vector3(0, 2.0, 2.7), ORIGIN + Vector3(0, 1.4, -0.6), (time - 24) / 5)
	else:
		opening._shot(ORIGIN + Vector3(5.6, 2.4, -2.7), ORIGIN + Vector3(5.3, 2.0, -3.1), ORIGIN + Vector3(2.8, 1.0, -1.8), (time - 29) / 7)
		if not last_foley:
			last_foley = true
			opening.foley.play()
