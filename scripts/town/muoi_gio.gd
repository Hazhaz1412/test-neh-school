extends Node
# Mười Gió sells what a night at the school might need, sitting in the open porch of a house on
# Hẻm 8: the builder leaves that one porch without its iron gate. He only deals with people sent
# to him, through his reply on Sợi Chỉ or by Bảy Rô after caro. What he sells is a task to finish
# by day, so it never takes a bag slot.
const Gear := preload("res://scripts/night_gear.gd")
const PosedPerson := preload("res://scripts/town/posed_person.gd")
const NAME := "Mười Gió"
# The house across the alley from the narrow gap first chosen on Hẻm 8.
const ROAD := "Hẻm 8"
const ROAD_INDEX := 44
const SIDE := 1.0
# Inside the porch, measured inward from the street front (the porch is 2.6 m deep).
const SEAT_DEPTH := 1.75
const TABLE_DEPTH := 1.05
const TOUCH_DEPTH := 0.8
# "Rope Knots" by aneeqayounas, CC-BY-4.0 (Sketchfab).
const ROPE := "res://assets/models/rope_knots.glb"
const ROPE_LENGTH := 0.45
const LINES := {
	"stranger": "Không quen. Đi chỗ khác.",
	"menu": "Cần gì thì nói. Không hỏi để làm gì, không ghi sổ.",
	"bought": "Cầm lấy. Gặp ai hỏi thì không biết tôi.",
	"done": "Hết hàng rồi. Đi đi, ngồi lâu người ta để ý.",
}
# How the player hears of him, shown once.
const INTRODUCED := {
	"soichi": "Mười Gió nhắn: \"Hẻm 8, căn có cửa gỗ nâu. Ban ngày tôi ngồi trong hiên.\"",
	"baro": "Bảy Rô: \"Cần đồ nghề thì tìm Mười Gió, ngồi trong hiên một căn ở Hẻm 8. Nói là Bảy Rô gửi.\"",
}
var story: Node
var world: Node3D
var lot: Dictionary
var spot := Vector3.ZERO
var touch: Dictionary
var pending_hint := ""

# Marks his house before the street is built, so its porch is left open.
static func reserve(plan: RefCounted) -> Dictionary:
	var road: Dictionary = plan.road_named(ROAD)
	var side: Vector2 = plan._normal(road, ROAD_INDEX) * SIDE
	var best := {}
	var gap := INF
	for candidate in plan.lots:
		if candidate.road != road.index or candidate.has("place") or candidate.normal.dot(side) < 0.5:
			continue
		var distance: float = candidate.front.distance_to(road.path[ROAD_INDEX])
		if distance < gap:
			gap = distance
			best = candidate
	best.kiosk = true
	# Whatever the plan meant to build there, he gets an ordinary tube house with its porch.
	best.kind = "tube"
	best.width = minf(best.width, 6.0)
	return best

func setup(owner_story: Node) -> void:
	story = owner_story
	world = story.world
	for candidate in world.plan.lots:
		if candidate.get("kiosk", false):
			lot = candidate
	var frame: Transform3D = world.builder._frame(lot)
	var facing := atan2(-lot.normal.x, -lot.normal.y)
	var seat: Vector3 = frame * Vector3(0, 0, SEAT_DEPTH)
	var body: Node3D = PosedPerson.new()
	body.who = "muoigio"
	body.motion = "sit"
	body.height = 1.7
	world.add_child(body)
	body.global_position = seat
	body.rotation.y = facing
	story._stool(seat)
	_stall(frame, facing)
	spot = frame * Vector3(0, 0, TOUCH_DEPTH)
	world.add_interaction(spot, _label(), talk)
	touch = world.interactions.back()

# A low table with a coil of rope and a tool roll on it, crates of stock behind him.
func _stall(frame: Transform3D, facing: float) -> void:
	_box(frame * Vector3(0, 0.25, TABLE_DEPTH), Vector3(1.1, 0.5, 0.5), Color(0.34, 0.24, 0.16), facing)
	_rope(frame * Vector3(-0.22, 0.5, TABLE_DEPTH), facing)
	_box(frame * Vector3(0.25, 0.54, TABLE_DEPTH), Vector3(0.32, 0.07, 0.16), Color(0.12, 0.12, 0.13), facing)
	for x in [-0.75, 0.75]:
		_box(frame * Vector3(x, 0.21, 2.25), Vector3(0.5, 0.42, 0.4), Color(0.20, 0.36, 0.62), facing)
	_box(frame * Vector3(0.75, 0.63, 2.25), Vector3(0.5, 0.42, 0.4), Color(0.62, 0.48, 0.30), facing + 0.2)

# The knotted rope he sells, laid flat on the table with its longest side about 0.45 m.
# The import may stand it on end, so its long axis is turned level before sizing.
func _rope(at: Vector3, facing: float) -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	var rope: Node3D = load(ROPE).instantiate()
	holder.add_child(rope)
	var bounds := _bounds(holder)
	if bounds.size.y > maxf(bounds.size.x, bounds.size.z):
		rope.rotation.x = -PI * 0.5
		bounds = _bounds(holder)
	rope.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	holder.scale = Vector3.ONE * ROPE_LENGTH / maxf(bounds.size.x, bounds.size.z)
	holder.global_position = at
	holder.rotation.y = facing + PI * 0.5

# Mesh bounds in the holder's space; the holder sits untransformed while this is read.
func _bounds(holder: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part in holder.find_children("*", "MeshInstance3D", true, false):
		var piece: AABB = holder.global_transform.affine_inverse() * part.global_transform * part.get_aabb()
		bounds = piece if first else bounds.merge(piece)
		first = false
	return bounds

func _box(at: Vector3, size: Vector3, colour: Color, facing: float) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _paint(colour)
	world.add_child(mesh)
	mesh.global_position = at
	mesh.rotation.y = facing

func _paint(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 0.8
	return paint

func known() -> bool:
	return story.gear.get("muoi_gio_known", false)

func _label() -> String:
	return "Mua đồ của %s" % NAME if known() else "Người ngồi trong hiên nhà"

# Called by the Sợi Chỉ contact or by Bảy Rô; the hint waits until no window is open.
func learn(source: String) -> void:
	if known():
		return
	story.gear.muoi_gio_known = true
	story.pay(0)
	touch.label = _label()
	pending_hint = INTRODUCED[source]
	if not story.talking_now():
		show_pending()

func show_pending() -> void:
	if not pending_hint.is_empty():
		world.hud.show_hint(pending_hint, 8.0)
		pending_hint = ""

func done() -> bool:
	return Gear.black_market_done(story.gear)

func talk() -> void:
	story._open("muoigio")
	if not known():
		story._lines([[NAME, LINES.stranger]], story.close)
		return
	menu(LINES.menu)

func menu(line: String) -> void:
	if story.view == null:
		return
	if done():
		story.view.show_line(NAME, LINES.done, [{"text": "Đi", "action": story.close}])
		return
	var items := []
	for entry in Gear.BLACK_MARKET:
		if not story.gear.get(entry.kind, false):
			items.append({"text": "%s · %d$" % [entry.name, entry.price], "action": buy.bind(entry.kind)})
	items.append({"text": "Thôi", "action": story.close})
	story.view.show_line(NAME, line, items, "Trong ví: %d$" % story.gear.money)

func buy(kind: String) -> void:
	var problem := Gear.buy_black(story.gear, kind)
	if not problem.is_empty():
		menu(problem)
		return
	for entry in Gear.BLACK_MARKET:
		if entry.kind == kind and done():
			story.view.show_line(NAME, "%s %s" % [LINES.bought, entry.text], [{"text": "Đi", "action": story.close}], "Đã có đủ đồ.")
		elif entry.kind == kind:
			menu("%s %s" % [LINES.bought, entry.text])
