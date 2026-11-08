extends RefCounted
# What the player owns between nights. Prices are in dollars, as people on the street quote them.
const PATH := "user://night_gear.cfg"
const START_MONEY := 300
const NIGHT_PAY := 150
const BAG_ROOM := 4
const FREE_CHALK := 2
const REDEEM_SHARE := 0.5
const BOOST_CARE := 0.1
# It only wants what looks like a prize; a torch is beneath it.
const VALUE := {"medal": 120, "camera": 100}
const STOCK := [
	{"kind": "torch", "name": "Đèn pin", "price": 300, "text": "Sáng hơn, pin dùng 5 phút, không cần bấm. Món này không chiếm chỗ trong túi."},
	{"kind": "salt_gun", "name": "Súng muối", "price": 180, "text": "Một phát. Bắn lúc bị nó chụp lên: nó đau, ném bạn đi và mất dấu."},
	{"kind": "medal", "name": "Huy chương mạ", "price": 120, "text": "Giả, nhưng sáng. Nó sẽ giật thứ này thay vì ăn thịt bạn."},
	{"kind": "battery", "name": "Pin", "price": 30, "text": "Thêm 50% pin cho đèn và máy ảnh."},
	{"kind": "medicine", "name": "Sơ cứu", "price": 40, "text": "Hồi 30 máu."},
	{"kind": "chalk", "name": "Phấn", "price": 10, "text": "Ném ra để dụ tiếng động."},
]

static func fresh() -> Dictionary:
	return {"money": START_MONEY, "bag": [], "camera": true, "pawned": [], "boosts": 0, "heard_khai": false, "torch": false, "minutes": 420,
		# Bảy Rô only remembers the last few games: enough to greet a returning player and go easier.
		"caro_won": false, "caro_losses": 0, "caro_last_decisive": "",
		"muoi_gio_known": false, "lockpick": false, "rope": false}

# Mười Gió's goods are a task, not luggage: owning them never takes a bag slot by day.
const BLACK_MARKET := [
	{"kind": "lockpick", "name": "Bộ bẻ khóa", "price": 90, "text": "Mấy cây móc thép mỏng, cuộn trong miếng vải dầu."},
	{"kind": "rope", "name": "Dây thừng", "price": 60, "text": "Dây dù mười lăm mét, có móc sắt ở đầu."},
]

# Empty when bought, otherwise Mười Gió's answer for why not.
static func buy_black(state: Dictionary, kind: String) -> String:
	for entry in BLACK_MARKET:
		if entry.kind != kind:
			continue
		if state.get(kind, false):
			return "Mua rồi còn hỏi."
		if state.money < entry.price:
			return "Không đủ tiền thì về đi."
		state.money -= entry.price
		state[kind] = true
		write(state)
		return ""
	return "Không có món đó."

static func black_market_done(state: Dictionary) -> bool:
	return BLACK_MARKET.all(func(entry): return state.get(entry.kind, false))

static func read() -> Dictionary:
	var state := fresh()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return state
	for key in state:
		state[key] = file.get_value("gear", key, state[key])
	return state

static func write(state: Dictionary) -> void:
	var file := ConfigFile.new()
	for key in state:
		file.set_value("gear", key, state[key])
	file.save(PATH)

static func price(kind: String) -> int:
	for entry in STOCK:
		if entry.kind == kind:
			return entry.price
	return 0

static func redeem_price(kind: String) -> int:
	return int(VALUE.get(kind, price(kind)) * REDEEM_SHARE)

static func buy(state: Dictionary, kind: String) -> String:
	if kind == "torch" and state.torch:
		return "Cậu có đèn này rồi."
	if kind != "torch" and state.bag.size() >= BAG_ROOM:
		return "Túi đầy rồi."
	if state.money < price(kind):
		return "Không đủ tiền."
	state.money -= price(kind)
	if kind == "torch":
		state.torch = true
	else:
		state.bag.append(kind)
	write(state)
	return ""

static func redeem(state: Dictionary, kind: String) -> String:
	if not state.pawned.has(kind):
		return "Không có món này."
	if state.money < redeem_price(kind):
		return "Không đủ tiền."
	if kind != "camera" and state.bag.size() >= BAG_ROOM:
		return "Túi đầy rồi."
	state.money -= redeem_price(kind)
	state.pawned.erase(kind)
	if kind == "camera":
		state.camera = true
	else:
		state.bag.append(kind)
	write(state)
	return ""

# Six slots, a light always first; leftover room gets the free chalk.
static func loadout(state: Dictionary) -> Array:
	var slots: Array = ["torch" if state.torch else "crank"]
	if state.camera:
		slots.append("camera")
	slots.append_array(state.bag)
	for i in range(FREE_CHALK):
		if slots.size() < 6:
			slots.append("chalk")
	while slots.size() < 6:
		slots.append("")
	return slots

# Only a survived night counts, so a retry never punishes twice. What it took turns up at the shop.
static func finish_night(state: Dictionary, inventory: Array, stolen: Array) -> void:
	var kept: Array = []
	for kind in inventory:
		if not kind in ["", "torch", "crank", "camera", "chalk"]:
			kept.append(kind)
	state.bag = kept.slice(0, BAG_ROOM)
	state.camera = inventory.has("camera")
	state.pawned.append_array(stolen)
	state.money += NIGHT_PAY
	state.boosts = 0
	state.minutes = 420
	write(state)
