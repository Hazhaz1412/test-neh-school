extends Node
# The free morning. People are placed by map lots; talking never needs getting off the bike.
const Person := preload("res://scripts/town/town_person.gd")
const Dialogue := preload("res://scripts/visual_novel_dialogue.gd")
const Gear := preload("res://scripts/night_gear.gd")
const CAST := {
	"hoa": {"name": "Cô Hoa", "look": "Female_Adult_07", "place": "post", "inward": -0.8, "motion": "idle"},
	"sau": {"name": "Bà Sáu", "look": "Female_Adult_02", "place": "shop", "inward": 0.9, "motion": "sit"},
	"luc": {"name": "Bác Lực", "look": "Security_Male_01", "place": "stall", "inward": 1.0, "motion": "sit"},
	"phuc": {"name": "Anh Phúc", "look": "Male_Adult_01", "place": "pho", "inward": 0.8, "motion": "idle"},
	"mai": {"name": "Chị Mai", "look": "Female_Adult_12", "place": "market", "inward": 1.2, "motion": "idle"},
	"khoa": {"name": "Khoa", "look": "Male_Adult_08", "place": "cafe", "inward": -1.2, "motion": "sit"},
}
const SMALL_TALK := {
	"hoa": [["Cô Hoa", "Bưu điện mở tới năm giờ chiều nhé cậu."]],
	"sau": [["Con sáo", "Ăn cơm chưa? Ăn cơm chưa?"], ["Bà Sáu", "Kệ nó. Đồ trị ma thì bà không bán đâu. Thử vô Hẻm 5 phía Lò Than, chỗ có cái lồng đèn đỏ."]],
	"luc": [["Bác Lực", "Trà đá hai ngàn. Qua cầu này chỉ có đi lạc hoặc đi tìm chuyện."]],
	"phuc": [["Anh Phúc", "Vui bốn chục, buồn hai lăm, thất tình miễn phí nếu kể đủ ba chi tiết."]],
	"mai": [["Chị Mai", "Chuối đây em. Đêm qua lại thấy đèn trường bật. Ông già Hẻm 5 mua muối đồng của chị hoài, chả biết để làm gì."]],
	"khoa": [["Khoa", "Mày sống rồi à. Có gì tối tính, bên kia cầu vắng lắm."]],
}
var world: Node3D
var people := {}
var view: Control
var talking := ""
var finished_day := false
var gear := {}

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
	_passers_by()

func open_shop() -> void:
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = preload("res://scripts/town/town_shop.gd").new()
	world.hud.add_child(view)
	view.setup(gear, close)

# People standing about; the street reads empty without them.
func _passers_by() -> void:
	var looks := ["Female_Adult_05", "Male_Adult_01", "Female_Adult_02", "Male_Adult_06", "Female_Adult_12", "Male_Adult_08"]
	var road: Dictionary = world.plan.road_named("Đường Cổ Đằng")
	for n in range(looks.size()):
		var i: int = 60 + n * 22
		var along: Vector2 = road.tangents[i]
		var side := 1.0 if n % 2 == 0 else -1.0
		var spot: Vector2 = road.path[i] + Vector2(-along.y, along.x) * side * (road.width * 0.5 + 2.2)
		var person: Node3D = Person.new()
		person.look = looks[n]
		world.add_child(person)
		person.global_position = Vector3(spot.x, world.plan.ground(spot), spot.y)
		person.rotation.y = n * 2.1

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
	return {"text": "Tới cổng Trường NEH khi bạn sẵn sàng", "position": Vector3(262, 0, 26)}

func talking_now() -> bool:
	return view != null

func _open(id: String) -> void:
	talking = id
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view = Dialogue.new()
	var actor: Node3D = Person.new()
	actor.look = CAST[id].look
	actor.motion = "talk"
	actor.height = 1.7
	view.setup(world.hud, CAST[id].name, close, actor)

func close() -> void:
	if view == null:
		return
	view.queue_free()
	view = null
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	talking = ""

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

func _gate() -> void:
	finished_day = true
	world.enter_night()
