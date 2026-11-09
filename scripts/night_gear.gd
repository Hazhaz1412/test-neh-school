extends RefCounted
# What the player owns between nights. Prices are in dollars, as people on the street quote them.
const PATH := "user://night_gear.cfg"
const START_MONEY := 300
const NIGHT_PAY := 150
const BAG_ROOM := 4
const FREE_CHALK := 2
const REDEEM_SHARE := 0.5
const BOOST_CARE := 0.1
# What a pawned item costs to buy back.
const VALUE := {"camera": 100}
const STOCK := [
	{"kind": "battery", "name": "Pin", "price": 30, "text": "Thêm 50% pin cho đèn và máy ảnh."},
	{"kind": "medicine", "name": "Sơ cứu", "price": 40, "text": "Hồi 30 sức khỏe."},
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

# Six slots, the torch always first (the same one as Night 0); leftover room gets the free chalk.
static func loadout(state: Dictionary) -> Array:
	var slots: Array = ["torch"]
	if state.camera:
		slots.append("camera")
	# Medals and hand torches from older saves no longer do anything.
	slots.append_array(state.bag.filter(func(kind): return not kind in ["medal", "crank", "torch"]))
	for i in range(FREE_CHALK):
		if slots.size() < 6:
			slots.append("chalk")
	while slots.size() < 6:
		slots.append("")
	return slots

# Only a survived night counts, so a retry never punishes twice. What the guard confiscated turns
# up at the shop.
static func finish_night(state: Dictionary, inventory: Array, confiscated: Array) -> void:
	var kept: Array = []
	for kind in inventory:
		if not kind in ["", "torch", "crank", "camera", "chalk"]:
			kept.append(kind)
	state.bag = kept.slice(0, BAG_ROOM)
	state.camera = inventory.has("camera")
	state.pawned.append_array(confiscated)
	state.money += NIGHT_PAY
	state.boosts = 0
	state.minutes = 420
	write(state)
