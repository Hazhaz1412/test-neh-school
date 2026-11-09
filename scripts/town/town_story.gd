extends Node
# The free morning. People are placed by map lots; talking never needs getting off the bike.
const Person := preload("res://scripts/town/town_person.gd")
const Dialogue := preload("res://scripts/visual_novel_dialogue.gd")
const Gear := preload("res://scripts/night_gear.gd")
const CaroPeople := preload("res://scripts/caro/caro_people.gd")
const PosedPerson := preload("res://scripts/town/posed_person.gd")
const CAST := {
	"hoa": {"name": "Cô Hoa", "look": "Female_Adult_07", "place": "post", "inward": -0.8, "motion": "idle"},
	"sau": {"name": "Bà Sáu", "look": "Female_Adult_02", "place": "shop", "inward": 0.9, "motion": "sit"},
	"luc": {"name": "Bác Lực", "look": "Security_Male_01", "place": "stall", "inward": 1.0, "motion": "sit"},
	"phuc": {"name": "Anh Phúc", "look": "Male_Adult_01", "place": "pho", "inward": 0.8, "motion": "idle"},
	"mai": {"name": "Chị Mai", "look": "Female_Adult_12", "place": "market", "inward": 1.2, "motion": "idle"},
	"khoa": {"name": "Bơ Tồ", "look": "Male_Adult_08", "place": "cafe", "inward": -1.2, "motion": "sit"},
}
const SMALL_TALK := {
	"hoa": [["Cô Hoa", "Bưu điện mở tới năm giờ chiều nhé cậu."]],
	"sau": [["Con sáo", "Ăn cơm chưa? Ăn cơm chưa?"], ["Bà Sáu", "Kệ nó. Đèn pin với pin thì bà không bán đâu. Thử vô Hẻm 5 phía Lò Than, chỗ có cái lồng đèn đỏ."]],
	"luc": [["Bác Lực", "Trà đá hai ngàn. Qua cầu này chỉ có đi lạc hoặc đi tìm chuyện."]],
	"phuc": [["Anh Phúc", "Vui bốn chục, buồn hai lăm, thất tình miễn phí nếu kể đủ ba chi tiết."]],
	"mai": [["Chị Mai", "Chuối đây em. Đêm qua lại thấy đèn trường bật. Trường đóng cửa mấy năm rồi, ai còn vô đó làm gì?"]],
	"khoa": [["Bơ Tồ", "Mày sống rồi à. Có gì tối tính, bên kia cầu vắng lắm."]],
}
var world: Node3D
var people := {}
var view: Control
var talking := ""
var finished_day := false
var gear := {}
var chess_table: Node3D
var caro_table: Node3D
var caro_interaction: Dictionary
var muoi_gio: Node

func setup(town: Node3D) -> void:
	world = town
	for id in CAST:
		var role: Dictionary = CAST[id]
		var lot: Dictionary = world.plan.place_lot(role.place)
		var person: Node3D = Person.new()
		person.look = role.look
		person.motion = role.motion
		world.add_child(person)
		var spot: Vector2 = lot.front + lot.normal * role.inward
		person.global_position = Vector3(spot.x, world.plan.ground(spot), spot.y)
		person.rotation.y = atan2(-lot.normal.x, -lot.normal.y)
		people[id] = person
		if role.motion == "sit":
			_stool(person.global_position)
		world.add_interaction(person.global_position, "Nói chuyện với %s" % role.name, talk.bind(id))
	world.add_interaction(Vector3(262, 0, 26), "Vào trường · Bắt đầu đêm", _gate)
	gear = Gear.read()
	world.life.start_activities()
	var curio: Dictionary = world.plan.place_lot("curio")
	var keeper: Node3D = Person.new()
	keeper.look = "Male_Adult_14"
	keeper.motion = "idle"
	world.add_child(keeper)
	var stand: Vector2 = curio.front + curio.normal * 2.75
	keeper.global_position = Vector3(stand.x, 0, stand.y)
	keeper.rotation.y = atan2(-curio.normal.x, -curio.normal.y)
	var counter: Vector2 = curio.front + curio.normal * 0.9
	world.add_interaction(Vector3(counter.x, 0, counter.y), "Vào tiệm", open_shop)
	var corner: Dictionary = world.plan.place_lot("chess")
	var frame: Transform3D = world.builder._frame(corner)
	chess_table = preload("res://scripts/chess/chess_table.gd").new()
	world.add_child(chess_table)
	chess_table.global_transform = Transform3D(frame.basis, frame * Vector3(0, 0.68, 1.7))
	chess_table.lay(preload("res://scripts/chess/chess_rules.gd").new().board)
	world.add_interaction(chess_table.global_position, "Chơi cờ", open_chess)
	_place_baro(frame)
	muoi_gio = preload("res://scripts/town/muoi_gio.gd").new()
	add_child(muoi_gio)
	muoi_gio.setup(self)

func open_shop() -> void:
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = preload("res://scripts/town/town_shop.gd").new()
	world.hud.add_child(view)
	view.setup(gear, close)

func open_chess() -> void:
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = preload("res://scripts/chess/chess_view.gd").new()
	world.hud.add_child(view)
	view.setup(world, self, chess_table)

# Day 1: Bảy Rô waits beside the chess board, as he wrote on Tili, and guards the way to Night 1.
func _place_baro(frame: Transform3D) -> void:
	caro_table = Node3D.new()
	world.add_child(caro_table)
	caro_table.global_transform = Transform3D(frame.basis, frame * Vector3(1.9, 0.0, 1.7))
	var top := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.7, 0.68, 0.7)
	top.mesh = slab
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.86, 0.80, 0.66)
	paint.roughness = 0.8
	top.material_override = paint
	caro_table.add_child(top)
	top.position.y = 0.34
	var baro: Node3D = PosedPerson.new()
	baro.who = "bayro"
	baro.motion = "sit"
	world.add_child(baro)
	var seat: Vector3 = caro_table.to_global(Vector3(0, 0, 0.55))
	baro.global_position = Vector3(seat.x, world.plan.ground(Vector2(seat.x, seat.z)), seat.z)
	baro.global_rotation.y = caro_table.global_rotation.y + PI
	_stool(baro.global_position)
	world.add_interaction(caro_table.global_position, _baro_label(), open_caro)
	caro_interaction = world.interactions.back()

func _baro_label() -> String:
	return "Nói chuyện với Bảy Rô" if gear.caro_won else "Chơi caro với Bảy Rô"

func open_caro() -> void:
	if gear.caro_won:
		_open("baro")
		_lines(CaroPeople.REVEAL, close)
		return
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = preload("res://scripts/caro/caro_view.gd").new()
	world.hud.add_child(view)
	view.setup(world, self)

func pay(amount: int) -> void:
	gear.money += amount
	Gear.write(gear)

func _stool(at: Vector3) -> void:
	var seat := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.17
	shape.bottom_radius = 0.2
	shape.height = 0.42
	seat.mesh = shape
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.72, 0.12, 0.10)
	paint.roughness = 0.5
	seat.material_override = paint
	world.add_child(seat)
	seat.global_position = at + Vector3.UP * 0.21

func playing() -> bool:
	return not finished_day

func objective() -> Dictionary:
	if not gear.caro_won:
		return {"text": "Gặp Bảy Rô ở Góc Cờ · Thắng một ván caro", "position": caro_table.global_position}
	if muoi_gio.known() and not muoi_gio.done():
		return {"text": "Mua bẻ khóa và dây thừng của Mười Gió · Hẻm 8", "position": muoi_gio.spot}
	return {"text": "Tới cổng Trường NEH khi bạn sẵn sàng", "position": Vector3(262, 0, 26)}

func talking_now() -> bool:
	return view != null

func _open(id: String) -> void:
	talking = id
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = Dialogue.new()
	var role: Dictionary = CAST[id] if CAST.has(id) else ({"name": muoi_gio.NAME} if id == "muoigio" else CaroPeople.BARO)
	var actor: Node3D
	if CAST.has(id):
		actor = Person.new()
		actor.look = role.look
		actor.motion = "talk"
	else:
		actor = PosedPerson.new()
		actor.who = "muoigio" if id == "muoigio" else "bayro"
		actor.motion = "fold" if id == "muoigio" else "stand"
	actor.height = 1.7
	view.setup(world.hud, role.name, close, actor)

func close() -> void:
	if view == null:
		return
	view.queue_free()
	view = null
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	talking = ""
	if not caro_interaction.is_empty():
		caro_interaction.label = _baro_label()
	muoi_gio.show_pending()
	world.player.camera.make_current()
	world.spend(0)

func _input(event: InputEvent) -> void:
	if view != null and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func talk(id: String) -> void:
	_open(id)
	_lines(SMALL_TALK[id], close)

func _lines(lines: Array, then: Callable, index := 0) -> void:
	if view == null:
		return
	if index >= lines.size():
		then.call()
		return
	var line: Array = lines[index]
	view.show_line(line[0], line[1], [{"text": "Tiếp", "action": _lines.bind(lines, then, index + 1)}])

# Bảy Rô points the way to Mười Gió once a game with him is over, won or lost.
func caro_finished() -> void:
	muoi_gio.learn("baro")

func on_hub_message(message: Dictionary) -> void:
	if message.get("type") == "contact" and message.get("id") == "muoigio":
		muoi_gio.learn("soichi")

func _gate() -> void:
	if not gear.caro_won:
		world.hud.show_hint(CaroPeople.GATE_HINT)
		return
	finished_day = true
	world.enter_night()
