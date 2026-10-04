extends Control

var player: CharacterBody3D
const SCALE := 2.65
const ORIGIN := Vector2(340, 310)

func point(x: float, z: float) -> Vector2:
	return ORIGIN + Vector2(x, z) * SCALE

func region(center: Vector2, dimensions: Vector2, color: Color) -> void:
	var rectangle := Rect2(point(center.x, center.y) - dimensions * SCALE * 0.5, dimensions * SCALE)
	draw_rect(rectangle, color)
	draw_rect(rectangle, Color(0.45, 0.56, 0.56), false, 1.0)

func caption(text: String, pos: Vector2, font_size := 14) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.83, 0.86, 0.77))

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	caption("NEH ACADEMY / KHU A + B", Vector2(26, 36), 22)
	caption("M đóng sơ đồ · ▲ người chơi · cầu thang khu A lên 3 tầng và sân thượng", Vector2(26, 62), 14)
	region(Vector2(0, -2), Vector2(116, 160), Color(0.09, 0.15, 0.13))
	region(Vector2(0, 32), Vector2(44, 44), Color(0.24, 0.26, 0.22))
	region(Vector2(0, 66), Vector2(8, 24), Color(0.24, 0.26, 0.22))
	region(Vector2(0, 60), Vector2(100, 4), Color(0.24, 0.26, 0.22))
	region(Vector2(0, -1.5), Vector2(76, 21), Color(0.24, 0.34, 0.37))
	for side in [-1, 1]:
		region(Vector2(side * 30, 33), Vector2(16, 46), Color(0.24, 0.34, 0.37))
		for z in [24.0, 43.0]:
			region(Vector2(side * 12, z), Vector2(10, 10), Color(0.11, 0.23, 0.16))
			draw_circle(point(side * 12, z), 9, Color(0.21, 0.41, 0.26))
	region(Vector2(44, 53), Vector2(19, 28), Color(0.32, 0.34, 0.28))
	region(Vector2(-45, 43), Vector2(9, 8), Color(0.12, 0.30, 0.37))
	draw_circle(point(0, 32), 13, Color(0.35, 0.45, 0.49))
	draw_arc(point(0, 32), 17, 0, TAU, 32, Color(0.70, 0.72, 0.55), 2)
	region(Vector2(1.5, -21.5), Vector2(3, 35), Color(0.35, 0.29, 0.20))
	region(Vector2(0, -52), Vector2(64, 20), Color(0.24, 0.34, 0.37))
	region(Vector2(0, -40.5), Vector2(64, 3), Color(0.35, 0.29, 0.20))
	for side in [-1, 1]:
		region(Vector2(side * 21, -31), Vector2(22, 16), Color(0.24, 0.34, 0.37))
	region(Vector2(-45, -53), Vector2(12, 12), Color(0.32, 0.25, 0.19))
	var codes := {"library": "TV", "lab": "TN", "computer": "MT", "staff": "GV", "infirmary": "YT", "storage": "KHO", "archive": "LT", "music": "AN", "art": "MỸ", "club": "CLB", "lecture": "ĐN", "classroom": "LỚP"}
	var floor_y := clampi(int((player.position.y + 0.2) / 3.9), 0, 2) * 3.9
	for room in player.get_parent().get_meta("room_catalog", []):
		if absf(room.center.y - floor_y) < 0.2:
			caption(codes.get(room.kind, ""), point(room.center.x - 3, room.center.z), 10)
	caption("KHU B", point(-8, -66), 14)
	caption("NHÀ KHO", point(-57, -61), 12)
	if not player.get_parent().has_master_key:
		draw_arc(point(-45, -53), 21, 0, TAU, 32, Color(0.96, 0.75, 0.37), 2)
		caption("01 / CHÌA KHÓA TỔNG → NHÀ KHO", Vector2(26, 540), 14)
	else:
		if player.get_parent().survival.active:
			caption("ĐÊM 01 / SỐNG TỚI 06:00 · GIẢI CỨU LINH HỒN", Vector2(26, 540), 14)
		else:
			caption("01 / ĐÃ CÓ CHÌA KHÓA TỔNG · E mở cửa phòng", Vector2(26, 540), 14)
	var progression: Node3D = player.get_parent().progression
	if progression != null:
		for i in range(4):
			var pos: Vector3 = progression.terminals[i].global_position
			var color := Color(0.38, 0.84, 0.70) if progression.completed.has(i) else Color(0.93, 0.55, 0.28)
			draw_circle(point(pos.x, pos.z), 5, color)
			caption(progression.SYMBOLS[i], point(pos.x, pos.z) + Vector2(7, -4), 13)
		for gate in progression.gates:
			if not gate.opened():
				draw_line(point(gate.position.x - 1, gate.position.z), point(gate.position.x + 1, gate.position.z), Color(0.90, 0.27, 0.21), 3)
	caption("NỐI A–B", point(5, -21), 12)
	caption("KHU A / CHỮ U", point(-21, -15), 14)
	caption("CẦU THANG", point(-12, 3), 12)
	var quest: Node3D = player.get_parent().soul_quest
	if quest != null and not player.get_parent().survival.soul_rescued:
		var soul_point := point(quest.soul.position.x, quest.soul.position.z)
		draw_circle(soul_point, 4, Color(0.52, 0.82, 0.91))
		caption("AN · SÂN THƯỢNG", soul_point + Vector2(-18, -23), 11)
	caption("CÁNH TÂY", point(-39, 30), 12)
	caption("CÁNH ĐÔNG", point(23, 30), 12)
	caption("ĐÀI PHUN", point(-11, 41), 12)
	caption("SÂN TRONG", point(-12, 53))
	caption("VƯỜN TÂY", point(-56, 51), 12)
	caption("SÂN BÓNG", point(35, 54), 12)
	caption("CỔNG CHÍNH", point(-12, 83))
	caption("SƠ ĐỒ KHÔNG DỪNG NGUY HIỂM · M đóng nhanh" if player.get_parent().survival.active else "A: lớp + phòng chức năng · B: khu học tập · kho riêng · sân thượng A.", Vector2(26, 565), 13)
	if player != null:
		var p := point(player.position.x, player.position.z)
		var direction := Vector2(-sin(player.rotation.y), -cos(player.rotation.y))
		var right := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([p + direction * 10, p - direction * 6 + right * 5, p - direction * 6 - right * 5]), Color(0.96, 0.75, 0.37))

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.98)
	style.border_color = Color(0.49, 0.55, 0.44)
	style.set_border_width_all(1)
	return style
