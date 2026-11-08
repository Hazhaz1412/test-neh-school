extends Node
# What makes the street feel lived in: walkers, the ward loudspeaker and small things to do.
const Person := preload("res://scripts/town/town_person.gd")
const WALKER_LOOKS := ["Female_Adult_05", "Male_Adult_01", "Female_Adult_02", "Male_Adult_06", "Female_Adult_12", "Male_Adult_08", "Female_Adult_07", "Male_Adult_14", "Female_Adult_05", "Male_Adult_06"]
const WALK_ROADS := ["Đường Cổ Đằng", "Phố Chợ", "Đường Bến Trầu", "Phố Hàng Cau", "Phố Lò Than"]
const WALK_SPEED := 1.25
const AWAKE_RANGE := 110.0
const SPEAKER_SECONDS := 75.0
const SPEAKER := ["Loa phường: Bà con khu phố Bến Trầu chú ý, chiều nay cúp nước từ 14 giờ.", "Loa phường: Đề nghị không phơi quần áo màu sặc sỡ ở ban công mặt phố.", "Loa phường: Ai đánh rơi con ngỗng ở cổng chung cư, xin đến nhận.", "Loa phường: Khuyến cáo bà con không vào khu trường NEH sau khi trời tối.", "Loa phường: Cúp điện đêm nay. Đèn ở Trường NEH mà sáng thì không phải do điện lực."]
const ACTIVITIES := [
	{"place": "pho", "inward": 2.0, "label": "Ăn tô phở · 5$ · 30 phút", "cost": 5, "minutes": 30, "boost": true, "lines": ["Ấm bụng hẳn. Đêm nay chạy đỡ hụt hơi hơn.", "Anh Phúc tính giá theo mặt. Hôm nay mặt mình đáng năm đô."]},
	{"place": "cafe", "inward": 2.0, "label": "Uống cà phê · 3$ · 20 phút", "cost": 3, "minutes": 20, "boost": true, "lines": ["Đắng tỉnh cả người. Đêm nay chân sẽ nghe lời hơn.", "Bơ Tồ đổi tiếng nhạc to lên rồi nói gì đó, không nghe rõ."]},
	{"place": "stall", "inward": 0.6, "label": "Làm ly trà đá · 1$ · 10 phút", "cost": 1, "minutes": 10, "lines": ["Bác Lực: Trường đó đêm nào cũng sáng đèn, mà đường dây cắt mười mấy năm rồi.", "Bác Lực: Hồi xưa có đứa nhỏ ngày nào cũng ôm bàn cờ qua đây.", "Trà đá lạnh buốt. Có con ruồi đậu lên thành ly rồi bay đi."]},
	{"place": "market", "inward": 0.8, "label": "Mua vé số · 2$ · 5 phút", "cost": 2, "minutes": 5, "lottery": true, "lines": ["Trật hết. Bà bán vé cười như biết trước."]},
	{"place": "shop", "inward": 1.8, "label": "Cho con sáo ăn · 5 phút", "cost": 0, "minutes": 5, "lines": ["Con sáo: Ăn cơm chưa? Ăn cơm chưa?", "Con sáo: Tên em đâu rồi? Tên em đâu rồi?", "Con sáo mổ một phát vào ngón tay rồi quay đi."]},
	{"place": "post", "inward": 0.4, "label": "Đọc bảng tin phường · 10 phút", "cost": 0, "minutes": 10, "lines": ["Tìm người thân của nữ sinh lớp 10A6 để nhận thư thất lạc.", "Tuyển bảo vệ ca đêm, Trường NEH cũ. Tờ này đã vàng, mép rách.", "Chợ Bến Trầu cần người bốc vác. Ai đó gạch chữ vác, viết thành bỏ."]},
]
const FISH_SPOT := Vector3(63, 0, 28)
var world: Node3D
var walkers: Array = []
var speaker_clock := 40.0
var rng := RandomNumberGenerator.new()

func setup(town: Node3D) -> void:
	world = town
	_spawn_walkers()

func start_activities() -> void:
	for entry in ACTIVITIES:
		var lot: Dictionary = world.plan.place_lot(entry.place)
		var spot: Vector2 = lot.front + lot.normal * entry.inward
		world.add_interaction(Vector3(spot.x, 0, spot.y), entry.label, do.bind(entry))
	world.add_interaction(FISH_SPOT, "Câu cá sông Trầu · 30 phút", fish)
	var cart: Node3D = load("res://assets/polyhaven_town/models/CoffeeCart_01/CoffeeCart_01.gltf").instantiate()
	world.add_child(cart)
	var lot: Dictionary = world.plan.place_lot("cafe")
	var at: Vector2 = lot.front - lot.normal * 1.2 + Vector2(-lot.normal.y, lot.normal.x) * 5.5
	cart.global_position = Vector3(at.x, world.plan.ground(at), at.y)

func _spawn_walkers() -> void:
	for n in range(WALKER_LOOKS.size()):
		var road: Dictionary = world.plan.road_named(WALK_ROADS[n % WALK_ROADS.size()])
		var person: Node3D = Person.new()
		person.look = WALKER_LOOKS[n]
		person.motion = "walk"
		world.add_child(person)
		var index := rng.randi_range(4, road.path.size() - 5)
		walkers.append({"body": person, "road": road, "at": float(index), "way": 1.0 if n % 2 == 0 else -1.0, "side": 1.0 if n % 3 == 0 else -1.0})
		_place(walkers[-1], 0.0)

func _place(walker: Dictionary, delta: float) -> void:
	var road: Dictionary = walker.road
	walker.at += walker.way * WALK_SPEED * delta / world.plan.STEP
	if walker.at < 3.0 or walker.at > road.path.size() - 4.0:
		walker.way = -walker.way
		walker.at = clampf(walker.at, 3.0, road.path.size() - 4.0)
	var i := int(walker.at)
	var tangent: Vector2 = road.tangents[i]
	var along: Vector2 = tangent * walker.way
	var normal: Vector2 = Vector2(-tangent.y, tangent.x) * walker.side
	var spot: Vector2 = road.path[i].lerp(road.path[i + 1], walker.at - i) + normal * (road.width * 0.5 + road.walk * 0.55)
	var body: Node3D = walker.body
	body.global_position = Vector3(spot.x, world.plan.ground(spot), spot.y)
	body.global_rotation.y = atan2(along.x, along.y)

func _process(delta: float) -> void:
	if world.player == null:
		return
	var here: Vector3 = world.player.global_position
	for walker in walkers:
		var near: bool = walker.body.global_position.distance_to(here) < AWAKE_RANGE
		walker.body.visible = near
		if near:
			_place(walker, delta)
	speaker_clock -= delta
	if speaker_clock <= 0.0:
		speaker_clock = SPEAKER_SECONDS
		world.hud.show_hint(SPEAKER[rng.randi() % SPEAKER.size()], 8.0)

func do(entry: Dictionary) -> void:
	var story: Node = world.story
	if story.gear.money < entry.cost:
		world.hud.show_hint("Không đủ tiền.", 3.0)
		return
	story.pay(-entry.cost)
	var line: String = entry.lines[rng.randi() % entry.lines.size()]
	if entry.get("lottery", false) and rng.randf() < 0.08:
		story.pay(30)
		line = "Trúng! Bà bán vé đưa 30$ mà không nhìn bạn."
	if entry.get("boost", false) and story.gear.boosts < 2:
		story.gear.boosts += 1
		story.pay(0)
	world.hud.show_hint(line, 6.0)
	world.spend(entry.minutes)

func fish() -> void:
	var story: Node = world.story
	var catch_value: int = [0, 0, 2, 4, 6, 12][rng.randi() % 6]
	if catch_value > 0:
		story.pay(catch_value)
		world.hud.show_hint("Câu được con cá, bán lại cho quán được %d$." % catch_value, 6.0)
	else:
		world.hud.show_hint("Ngồi nửa tiếng, phao không nhúc nhích. Dưới nước có gì đó nhìn lên.", 6.0)
	world.spend(30)
