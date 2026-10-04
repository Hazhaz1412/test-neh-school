extends Node3D

var world: Node3D
var puzzles: RefCounted = preload("res://scripts/technical_puzzles.gd").new()
var completed := {}
var roof_key := false
var roof_open := false
var gates: Array[Node3D] = []
var terminals: Array[Node3D] = []
var cries: Array[AudioStreamPlayer3D] = []
var cry_clock := 1.0
var panel: PanelContainer
var board: Control
var title: Label
var hint: Label
var status: Label
var algorithm: Label
var submit_button: Button
var current_kind := -1
var trace_clock := 0.0
var trace_index := -1
var nod_clock := 0.0
var indicators: Array[MeshInstance3D] = []
var power_lamps: Array[MeshInstance3D] = []
var flood: MeshInstance3D
const SYMBOLS := ["ϟ", "↗", "≋", "×○"]

func setup(school: Node3D) -> void:
	world = school
	name = "SchoolProgression"
	var positions := [Vector3(-43, 1.15, -55), Vector3(5.3, 1.15, 7.25), Vector3(-35, 1.15, -43.5), Vector3(-14, 0.95, 7.1), Vector3(6.3, 12.85, 3.3)]
	for kind in range(5):
		var terminal: Node3D = preload("res://scripts/technical_terminal.gd").new()
		terminal.kind = kind
		terminal.progression = self
		terminal.position = positions[kind]
		terminal.name = ["Power", "Routing", "Pump", "Chess", "RoofKeyBox"][kind]
		add_child(terminal)
		terminals.append(terminal)
	for floor_y in [0.0, 3.9, 7.8]:
		make_gate(Vector3(1.5, floor_y, -14), Vector3(3.2, 2.9, 0.18), 1)
	make_gate(Vector3(-32, 0, -40.5), Vector3(3.2, 2.9, 0.18), 2, PI / 2)
	make_gate(Vector3(7, 11.7, 1), Vector3(10.15, 2.75, 0.18), 4, PI / 2)
	# Four physical circuits converge at the key cabinet. Their lamps change
	# immediately when a branch is finished, independently of the other branches.
	for i in range(4):
		var led := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.055
		sphere.height = 0.11
		sphere.radial_segments = 8
		sphere.rings = 4
		led.mesh = sphere
		led.position = Vector3(6.25, 13.05, 2.93 + i * 0.21)
		add_child(led)
		indicators.append(led)
		var wire := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.018
		mesh.bottom_radius = 0.018
		mesh.height = 11.7
		mesh.radial_segments = 6
		wire.mesh = mesh
		wire.position = Vector3(6.70, 6.90, 2.93 + i * 0.21)
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color(0.59, 0.36, 0.16), Color(0.16, 0.38, 0.48), Color(0.20, 0.42, 0.34), Color(0.50, 0.29, 0.32)][i]
		wire.material_override = material
		add_child(wire)
		var icon := Label3D.new()
		icon.text = SYMBOLS[i]
		icon.pixel_size = 0.002
		icon.font_size = 28
		icon.position = led.position + Vector3(-0.03, 0.18, 0)
		icon.rotation.y = -PI / 2
		add_child(icon)
	# Existing ambient light budget is unchanged: restored bulbs are emissive.
	for pos in [Vector3(1.5, 2.75, -12), Vector3(1.5, 2.75, -28), Vector3(-43, 2.7, -55), Vector3(6.4, 13.5, 1)]:
		var bulb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		mesh.radial_segments = 8
		mesh.rings = 4
		bulb.mesh = mesh
		bulb.position = pos
		add_child(bulb)
		power_lamps.append(bulb)
	flood = MeshInstance3D.new()
	var water := PlaneMesh.new()
	water.size = Vector2(20, 14)
	flood.mesh = water
	flood.position = Vector3(-21, 3.99, -31)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.065, 0.18, 0.19, 0.66)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.22
	flood.material_override = water_material
	flood.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flood)
	var stream: AudioStreamOggVorbis = load("res://assets/audio/an_cry.ogg")
	for i in range(3):
		var cry := AudioStreamPlayer3D.new()
		cry.stream = stream
		cry.position = [Vector3(15, 12.7, 5), Vector3(5.6, 6.3, 3), Vector3(5.6, 2.4, 3)][i]
		cry.max_distance = 48 if i == 0 else 22
		cry.unit_size = 9 if i == 0 else 5
		cry.volume_db = -9 if i == 0 else -18
		add_child(cry)
		cries.append(cry)
	_build_ui()
	world.player.damaged.connect(func(_amount): close())
	world.player.died.connect(close)
	refresh()

func make_gate(pos: Vector3, dimensions: Vector3, branch: int, angle := 0.0) -> void:
	var gate := preload("res://scripts/progression_gate.gd").new()
	gate.progression = self
	gate.branch = branch
	gate.gate_size = dimensions
	gate.position = pos
	gate.rotation.y = angle
	add_child(gate)
	gates.append(gate)

func all_complete() -> bool:
	return completed.size() == 4

func door_locked(room_number: int) -> bool:
	if room_number < 1000:
		return false
	# Two independently repairable entrances into B; either restores access.
	if not completed.has(1) and not completed.has(2):
		return true
	return room_number == 1204 and not completed.has(2)

func sector_accessible(feet: Vector3) -> bool:
	return feet.z >= -14 or feet.x < -32 or completed.has(1) or completed.has(2)

func ready_for_rescue() -> bool:
	return all_complete() and roof_key and roof_open

func current_goal() -> String:
	if not all_complete():
		return "ϟ Nhà kho  ·  ↗ Hành lang A  ·  ≋ Sân dịch vụ  ·  ×○ Sảnh A"
	if not roof_key:
		return "Hộp chìa · Đầu cầu thang sân thượng"
	if not roof_open:
		return "Mở cửa sân thượng · Tiếng khóc phía sau"
	return "An · Sân thượng · 4 câu chuyện trong trường"

func reset() -> void:
	close()
	puzzles = preload("res://scripts/technical_puzzles.gd").new()
	completed.clear()
	roof_key = false
	roof_open = false
	cry_clock = 1
	trace_index = -1
	for cry in cries:
		cry.stop()
	terminals[4].get_node("Interaction").collision_layer = 16
	refresh()

func bypass_for_test() -> void:
	close()
	for i in range(4):
		completed[i] = true
	roof_key = true
	roof_open = true
	refresh()

func refresh() -> void:
	if flood != null:
		flood.visible = not completed.has(2)
	for gate in gates:
		gate.refresh()
	for terminal in terminals:
		terminal.refresh()
	for i in range(indicators.size()):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.37, 0.88, 0.70) if completed.has(i) else Color(0.70, 0.22, 0.10)
		indicators[i].material_override = material
	for bulb in power_lamps:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.92, 0.75, 0.48) if completed.has(0) else Color(0.08, 0.10, 0.10)
		bulb.material_override = material

func open_terminal(terminal: Node3D) -> bool:
	if terminal.kind == 3 and not world.spirit_enabled:
		return false
	if panel.visible or world.player.is_hidden() or world.survival.opening.playing or world.survival.finished:
		return false
	world.map_panel.hide()
	world.soul_quest.close()
	world.player.cancel_chalk_charge()
	current_kind = terminal.kind
	trace_index = -1
	board.highlight = -1
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title.text = ["ϟ  TỦ ĐIỆN", "↗  ĐIỀU KHIỂN HÀNH LANG", "≋  BƠM NƯỚC", "×○  CÂU LẠC BỘ CỜ"][current_kind]
	hint.text = ["Click chuyển ○ → A → B. Cấp điện 4 mạch ★; mỗi nhánh tối đa 5A.", "Click ô kề để nối S → B với chi phí thấp nhất. Click ô cũ để quay lại.", "Click xoay ống. Đưa nước từ nguồn đến cống, không rò rỉ.", "Anh là ×. Nối 4 quân; thắng hoặc hòa để nhận một phần mã khóa."][current_kind]
	algorithm.text = ""
	_update_panel()
	return true

func panel_visible() -> bool:
	return panel != null and panel.visible

func close() -> void:
	if panel == null or not panel.visible:
		return
	panel.hide()
	trace_index = -1
	if not world.paused_by_user and world.player.health > 0 and not world.survival.finished and not world.map_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func cell_click(cell: int) -> void:
	if not panel_visible() or not world.simulation_active() or completed.has(current_kind):
		return
	match current_kind:
		0: puzzles.circuits[cell] = (puzzles.circuits[cell] + 1) % 3
		1: puzzles.route_click(cell)
		2: puzzles.rotate_pipe(cell)
		3:
			puzzles.chess_click(cell)
			nod_clock = 0.65
			terminals[3].refresh()
			if puzzles.chess_result == 1 or puzzles.chess_result == 3:
				finish_branch()
	board.highlight = -1
	_update_panel()

func submit() -> void:
	if not panel_visible() or not world.simulation_active() or completed.has(current_kind):
		return
	var valid := false
	match current_kind:
		0: valid = puzzles.electrical_valid()
		1: valid = puzzles.route_valid()
		2: valid = puzzles.pipes_valid()
		3:
			if puzzles.chess_result == 2:
				puzzles.board.fill(0)
				puzzles.chess_result = 0
				terminals[3].refresh()
				_update_panel()
				return
	if valid:
		finish_branch()
	else:
		world.soundscape.at("lock", terminals[current_kind].global_position, -12)
		world.emit_noise(terminals[current_kind].global_position, 12, "repair")
		status.text = ["⚠ Mạch ★ chưa đủ hoặc quá tải", "⚠ Tuyến chưa tới B hoặc chi phí còn cao", "⚠ Van thử: nước chưa tới cống hoặc đang rò", "Tới lượt ×"][current_kind]

func finish_branch() -> void:
	if completed.has(current_kind) or current_kind < 0:
		return
	var valid: bool = puzzles.electrical_valid() if current_kind == 0 else puzzles.route_valid() if current_kind == 1 else puzzles.pipes_valid() if current_kind == 2 else puzzles.chess_result in [1, 3] and puzzles.winner() in [1, 3]
	if not valid:
		return
	completed[current_kind] = true
	world.soundscape.at("pickup", terminals[current_kind].global_position, -18)
	world.emit_noise(terminals[current_kind].global_position, 14, "repair")
	refresh()
	_update_panel()
	if all_complete():
		world.soundscape.at("lock", terminals[4].global_position, -12)

func _update_panel() -> void:
	submit_button.disabled = completed.has(current_kind)
	submit_button.text = "Thử mạch" if current_kind == 0 else "Truyền tuyến" if current_kind == 1 else "Mở van thử" if current_kind == 2 else "Ván mới"
	submit_button.visible = current_kind != 3 or puzzles.chess_result == 2
	if completed.has(current_kind):
		status.text = "✓ " + ["Đèn sáng · hộp khóa đã có điện", "Cửa hành lang A–B đã mở", "Lối sân dịch vụ và kho lưu trữ đã mở", "Mã khóa được gửi về hộp chìa"][current_kind]
	elif current_kind == 1:
		status.text = "Chi phí: %d" % puzzles.route_cost()
	elif current_kind == 2:
		var flow: Dictionary = puzzles.water_flow()
		status.text = "Rò: %d    %s" % [flow.leaks, "Đã tới cống" if flow.reached else "Chưa tới cống"]
	elif current_kind == 3:
		status.text = "Em ấy thắng · thử một ván khác" if puzzles.chess_result == 2 else "Tới lượt ×"
	else:
		status.text = "★ Đèn · điều khiển · bơm · khóa"
	board.queue_redraw()

func show_technique() -> void:
	if not panel_visible():
		return
	match current_kind:
		0: algorithm.text = "Phân tải: Σ dòng từng nhánh ≤ 5A; 4 tải ★ cùng hoạt động."
		1:
			var cost: int = puzzles.shortest_cost()
			algorithm.text = "Dijkstra · lấy ô chi phí nhỏ nhất → cập nhật ô kề. Mức cần đạt: %d." % cost
			trace_index = 0
			trace_clock = 0
		2:
			var flow: Dictionary = puzzles.water_flow()
			algorithm.text = "BFS · nước qua %d ô; chỉ đi qua hai đầu ống khớp nhau." % flow.wet.size()
		3:
			board.highlight = puzzles.best_move(1)
			algorithm.text = "Minimax · %d trạng thái · alpha-beta cắt %d nhánh · ô vàng là gợi ý." % [puzzles.nodes_searched, puzzles.pruned_branches]
	board.queue_redraw()

func _input(event: InputEvent) -> void:
	if not panel_visible():
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if world == null:
		return
	if panel_visible() and (world.survival.finished or world.player.health <= 0 or world.player.combat.busy()):
		close()
	for cry in cries:
		cry.stream_paused = not world.simulation_active()
	terminals[3].npc.visible = world.spirit_enabled and not world.survival.finished
	if not world.simulation_active():
		return
	var can_cry: bool = world.spirit_enabled and not world.survival.soul_rescued and not world.survival.finished and (not world.survival.active or world.survival.phase == world.survival.Phase.NIGHT)
	if not can_cry:
		for cry in cries:
			cry.stop()
		cry_clock = 1
	else:
		cry_clock -= delta
		if cry_clock <= 0:
			for cry in cries:
				cry.play()
			cry_clock = 22
	nod_clock = maxf(0, nod_clock - delta)
	terminals[3].npc.head_pitch = sin(nod_clock / 0.65 * PI) * 0.28
	if panel_visible() and trace_index >= 0:
		trace_clock -= delta
		if trace_clock <= 0:
			trace_clock = 0.13
			if trace_index < puzzles.trace.size():
				board.highlight = puzzles.trace[trace_index]
				trace_index += 1
				board.queue_redraw()
			else:
				trace_index = -1

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -295
	panel.offset_bottom = 295
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.06, 0.97)
	style.border_color = Color(0.35, 0.48, 0.45)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.y = 36
	box.add_child(hint)
	board = preload("res://scripts/technical_board.gd").new()
	board.progression = self
	board.custom_minimum_size = Vector2(560, 365)
	board.cell_pressed.connect(cell_click)
	box.add_child(board)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	box.add_child(status)
	algorithm = Label.new()
	algorithm.add_theme_font_size_override("font_size", 13)
	algorithm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	algorithm.custom_minimum_size.y = 30
	box.add_child(algorithm)
	var row := HBoxContainer.new()
	box.add_child(row)
	submit_button = Button.new()
	submit_button.pressed.connect(submit)
	row.add_child(submit_button)
	var technique := Button.new()
	technique.text = "Xem kỹ thuật"
	technique.pressed.connect(show_technique)
	row.add_child(technique)
	var leave := Button.new()
	leave.text = "Rời bàn · Esc"
	leave.pressed.connect(close)
	row.add_child(leave)
	panel.hide()
