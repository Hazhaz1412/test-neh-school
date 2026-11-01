extends RefCounted
# What the player owns between nights. Prices are in thousands of dong.
const PATH := "user://night_gear.cfg"
const START_MONEY := 300
const NIGHT_PAY := 150
const BAG_ROOM := 4
const FREE_CHALK := 2
const REDEEM_SHARE := 0.5
# It only wants what looks like a prize; a torch is beneath it.
const VALUE := {"medal": 120, "camera": 100}
const STOCK := [
	{"kind": "salt_gun", "name": "Súng muối", "price": 180, "text": "Một phát. Bắn lúc bị nó chụp lên: nó đau, ném bạn đi và mất dấu."},
	{"kind": "medal", "name": "Huy chương mạ", "price": 120, "text": "Giả, nhưng sáng. Nó sẽ giật thứ này thay vì ăn thịt bạn."},
	{"kind": "battery", "name": "Pin", "price": 30, "text": "Thêm 50% pin cho đèn và máy ảnh."},
	{"kind": "medicine", "name": "Sơ cứu", "price": 40, "text": "Hồi 30 máu."},
	{"kind": "chalk", "name": "Phấn", "price": 10, "text": "Ném ra để dụ tiếng động."},
]

static func fresh() -> Dictionary:
	return {"money": START_MONEY, "bag": [], "camera": true, "pawned": []}

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
	if state.bag.size() >= BAG_ROOM:
		return "Túi đầy rồi."
	if state.money < price(kind):
		return "Không đủ tiền."
	state.money -= price(kind)
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

# Six slots, the torch always first; leftover room gets the free chalk.
static func loadout(state: Dictionary) -> Array:
	var slots: Array = ["torch"]
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
		if not kind in ["", "torch", "camera", "chalk"]:
			kept.append(kind)
	state.bag = kept.slice(0, BAG_ROOM)
	state.camera = inventory.has("camera")
	state.pawned.append_array(stolen)
	state.money += NIGHT_PAY
	write(state)
