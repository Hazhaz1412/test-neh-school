extends Control
signal cell_pressed(cell: int)
var progression: Node3D
var highlight := -1
const COLORS := [Color(0.27, 0.31, 0.32), Color(0.92, 0.67, 0.32), Color(0.34, 0.69, 0.91)]

func text_at(value: String, pos: Vector2, font_size := 18, color := Color(0.86, 0.90, 0.86)) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := -1
		if progression.current_kind == 0:
			for i in range(6):
				if Rect2(Vector2(50 + (i % 2) * 240, 45 + (i / 2) * 90), Vector2(180, 65)).has_point(event.position):
					cell = i
		else:
			var width := 4 if progression.current_kind == 2 else 5
			var step := 300.0 / width
			var pos: Vector2 = event.position - Vector2(120, 20)
			if pos.x >= 0 and pos.y >= 0 and pos.x < 300 and pos.y < 300:
				cell = int(pos.y / step) * width + int(pos.x / step)
		if cell >= 0:
			cell_pressed.emit(cell)
		accept_event()

func _draw() -> void:
	if progression == null:
		return
	var puzzles: RefCounted = progression.puzzles
	match progression.current_kind:
		0:
			var amps: Array[int] = puzzles.electrical_loads()
			for bus in range(2):
				var x := 30.0 if bus == 0 else 510.0
				draw_line(Vector2(x, 20), Vector2(x, 310), COLORS[bus + 1], 5)
				text_at("%s · %d/5A" % ["A" if bus == 0 else "B", amps[bus]], Vector2(15 + bus * 370, 350), 20, Color(0.96, 0.27, 0.22) if amps[bus] > 5 else COLORS[bus + 1])
			for i in range(6):
				var origin := Vector2(50 + (i % 2) * 240, 45 + (i / 2) * 90)
				var state: int = puzzles.circuits[i]
				var color: Color = COLORS[state]
				draw_rect(Rect2(origin, Vector2(180, 65)), Color(0.08, 0.13, 0.14))
				draw_rect(Rect2(origin, Vector2(180, 65)), color, false, 2)
				if state > 0:
					draw_line(origin + Vector2(90, 32), Vector2(30 if state == 1 else 510, origin.y + 32), color, 2)
				draw_circle(origin + Vector2(20, 20), 7, color)
				text_at(["ĐÈN", "ĐIỀU KHIỂN", "BƠM", "KHÓA", "QUẠT", "BIỂN HIỆU"][i], origin + Vector2(37, 25), 14)
				text_at("%dA   %s %s" % [puzzles.LOADS[i], ["○", "A", "B"][state], "★" if i < 4 else ""], origin + Vector2(35, 52), 18)
		_:
			var width := 4 if progression.current_kind == 2 else 5
			var step := 300.0 / width
			var flow: Dictionary = puzzles.water_flow() if progression.current_kind == 2 else {}
			for cell in range(width * width):
				var corner := Vector2(120, 20) + Vector2(cell % width, cell / width) * step
				var center := corner + Vector2.ONE * step / 2
				var color := Color(0.14, 0.22, 0.23)
				if progression.current_kind == 1:
					if puzzles.WALLS.has(cell):
						color = Color(0.025, 0.03, 0.035)
					elif puzzles.route.has(cell):
						color = Color(0.18, 0.49, 0.44)
				elif progression.current_kind == 3:
					color = Color(0.30, 0.25, 0.18)
				draw_rect(Rect2(corner + Vector2.ONE * 2, Vector2.ONE * (step - 4)), color)
				if cell == highlight:
					draw_rect(Rect2(corner + Vector2.ONE, Vector2.ONE * (step - 2)), Color(0.99, 0.80, 0.40), false, 3)
				if progression.current_kind == 1:
					text_at("S" if cell == 10 else "B" if cell == 14 else "×" if puzzles.WALLS.has(cell) else str(puzzles.COSTS[cell]), center + Vector2(-8, 6), 21)
				elif progression.current_kind == 2:
					var water_color := Color(0.32, 0.79, 0.91) if flow.wet.has(cell) else Color(0.45, 0.52, 0.52)
					for d in range(4):
						if puzzles.pipes[cell] & (1 << d):
							var direction: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][d]
							draw_line(center, center + direction * step / 2, water_color, 9)
					draw_circle(center, 7, water_color)
				else:
					if puzzles.board[cell] == 1:
						draw_line(center + Vector2(-12, -12), center + Vector2(12, 12), Color(0.86, 0.94, 0.83), 4)
						draw_line(center + Vector2(-12, 12), center + Vector2(12, -12), Color(0.86, 0.94, 0.83), 4)
					elif puzzles.board[cell] == 2:
						draw_arc(center, 16, 0, TAU, 24, Color(0.92, 0.49, 0.35), 4)
			if progression.current_kind == 2:
				draw_line(Vector2(78, 57), Vector2(120, 57), Color(0.32, 0.79, 0.91), 9)
				draw_line(Vector2(420, 282), Vector2(464, 282), Color(0.32, 0.79, 0.91), 9)
				text_at("↓", Vector2(466, 309), 24)
