@tool
extends RefCounted
# The ordinary buildings of the town. The plan gives every lot a kind: tube house, modern town
# house, single-storey cottage or old collective block. The ground behind the street rows is
# filled with plainer roofs, so no gap looks out on empty land.
const FACADES := [Color(0.95, 0.88, 0.62), Color(0.72, 0.85, 0.74), Color(0.93, 0.93, 0.88), Color(0.95, 0.74, 0.60), Color(0.70, 0.82, 0.90), Color(0.96, 0.80, 0.82), Color(0.86, 0.84, 0.78), Color(0.60, 0.72, 0.70), Color(0.98, 0.92, 0.78)]
const SIGNS := [Color(0.72, 0.10, 0.10), Color(0.08, 0.26, 0.58), Color(0.96, 0.78, 0.10), Color(0.06, 0.42, 0.28), Color(0.92, 0.42, 0.06), Color(0.95, 0.95, 0.92)]
const AWNINGS := [Color(0.16, 0.36, 0.62), Color(0.76, 0.16, 0.14), Color(0.14, 0.50, 0.34), Color(0.90, 0.62, 0.12)]
const GOODS := [Color(0.82, 0.22, 0.16), Color(0.92, 0.72, 0.18), Color(0.16, 0.44, 0.72), Color(0.92, 0.92, 0.88), Color(0.20, 0.58, 0.34), Color(0.78, 0.44, 0.20)]
# New builds keep to white, grey and stone; the colour stays with the older houses.
const MODERN := [Color(0.95, 0.95, 0.93), Color(0.84, 0.84, 0.82), Color(0.66, 0.67, 0.68), Color(0.92, 0.88, 0.80), Color(0.40, 0.42, 0.44)]
const BLOCKS := [Color(0.96, 0.88, 0.62), Color(0.88, 0.88, 0.80), Color(0.80, 0.88, 0.82), Color(0.94, 0.84, 0.70)]
# Painted doors, shutters and window frames; then gates, fences and balcony cages.
const WOODWORK := [Color(0.32, 0.20, 0.14), Color(0.16, 0.36, 0.42), Color(0.20, 0.40, 0.28), Color(0.50, 0.30, 0.16), Color(0.24, 0.30, 0.50)]
const IRONWORK := [Color(0.42, 0.16, 0.12), Color(0.30, 0.32, 0.34), Color(0.16, 0.34, 0.26), Color(0.20, 0.30, 0.46)]
# Boxed goods on a general store's shelves; then the small pale packets of a pharmacy or phone shop.
const PACKETS := [Color(0.94, 0.94, 0.92), Color(0.78, 0.88, 0.94), Color(0.82, 0.92, 0.84), Color(0.96, 0.86, 0.80), Color(0.90, 0.90, 0.96)]
# What a shop sells decides what stands in its open front, told from how its name begins.
# Anything not listed is a general store with shelves.
const TRADES := {
	"eatery": ["Cơm", "Bún", "Phở", "Hủ Tiếu", "Bánh", "Xôi", "Cháo", "Chè", "Ốc", "Bia", "Trà", "Nước", "Cà Phê"],
	"repair": ["Sửa Xe", "Vá Xe"],
	"counter": ["Điện Thoại", "Thuốc", "Sim", "Vàng", "Kính", "Khóa", "Photocopy"],
	"clothes": ["Áo", "Tiệm May"],
	"glazed": ["Tiệm Tóc", "Karaoke", "Nha Khoa", "Giặt"],
}
const DARK := Color(0.12, 0.13, 0.14)
const CEMENT := Color(0.86, 0.86, 0.84)
const SHEET := Color(0.85, 0.82, 0.76)
const TILE := Color(0.86, 0.60, 0.46)
# How far the open ground floor of a shop house is set back from the street.
const PORCH := 2.6
var builder: RefCounted
var batch: RefCounted
var plan: RefCounted
var rng: RandomNumberGenerator
var shop_names: Array = []
var block_index := 0

# Draws into the builder's batch and from its random stream, so the whole town stays one seed.
func _init(owner: RefCounted) -> void:
	builder = owner
	batch = owner.batch
	plan = owner.plan
	rng = owner.rng

func build(lot: Dictionary) -> void:
	var frame: Transform3D = builder._frame(lot)
	batch.at(frame.origin)
	match lot.get("kind", "tube"):
		"modern":
			_modern(lot, frame)
		"cottage":
			_cottage(lot, frame)
		"block":
			_block(lot, frame)
		_:
			_tube(lot, frame)

func _solid(frame: Transform3D, centre: Vector3, size: Vector3) -> void:
	builder._solid(frame, centre, size)

func _add_scatter(model: String, transform: Transform3D, color := Color.WHITE) -> void:
	builder._add_scatter(model, transform, color)

# ---- Shared pieces ----

# A flat panel on a wall. The face looks out along its own -Z; at is the panel's centre.
func _panel(material: String, face: Transform3D, at: Vector3, size: Vector2, color := Color.WHITE, uv := Vector2.ONE) -> void:
	var h := size * 0.5
	batch.quad(material, face * (at + Vector3(h.x, -h.y, 0)), face * (at + Vector3(-h.x, -h.y, 0)), face * (at + Vector3(-h.x, h.y, 0)), face * (at + Vector3(h.x, h.y, 0)), color, uv)

# A framed window, with the usual iron bars when asked; blank walls read as unfinished geometry.
func _window(face: Transform3D, at: Vector3, size: Vector2, trim: Color, bars := false, pane := "glass") -> void:
	batch.box("paint", face, at + Vector3(0, 0, -0.01), Vector3(size.x + 0.18, size.y + 0.18, 0.05), trim)
	_panel(pane, face, at + Vector3(0, 0, -0.05), size)
	if bars:
		_panel("rail", face, at + Vector3(0, 0, -0.1), size + Vector2(0.04, 0.04), Color.WHITE, Vector2(size.x * 2.2, 1.2))

# A thin sheet seen from above and from below: roofing, lean-tos, cage lids.
func _sheet(material: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	batch.facing(Vector3.UP, material, a, b, c, d, color)
	batch.facing(Vector3.DOWN, material, a, b, c, d, color.darkened(0.45))

# A pitched roof over the frame-local rectangle lo..hi (x, z) with its eaves at height eave.
# along_street runs the ridge along x, so the slopes face the street and the back; otherwise
# the gable end faces the street.
func _gable(frame: Transform3D, lo: Vector2, hi: Vector2, eave: float, rise: float, along_street: bool, cover: String, color: Color, wall: String, wall_color: Color) -> void:
	var over := 0.4
	var verge := 0.2
	var ridge := Vector2(lo.x, hi.x) if along_street else Vector2(lo.y, hi.y)
	var span := Vector2(lo.y, hi.y) if along_street else Vector2(lo.x, hi.x)
	var mid := (span.x + span.y) * 0.5
	var drop := over * rise / (mid - span.x)
	var at := func(along: float, y: float, across: float) -> Vector3:
		return frame * (Vector3(along, y, across) if along_street else Vector3(across, y, along))
	for edge in [span.x - over, span.y + over]:
		_sheet(cover, at.call(ridge.x - verge, eave - drop, edge), at.call(ridge.y + verge, eave - drop, edge), at.call(ridge.y + verge, eave + rise, mid), at.call(ridge.x - verge, eave + rise, mid), color)
	for end in [ridge.x, ridge.y]:
		var outward: Vector3 = at.call(end + signf(end - (ridge.x + ridge.y) * 0.5), 0.0, mid) - at.call(end, 0.0, mid)
		batch.triangle(outward, wall, at.call(end, eave, span.x), at.call(end, eave, span.y), at.call(end, eave + rise, mid), wall_color)

# A single slope over lo..hi: low over the frame's street side, rising to a wall at the back.
func _shed(frame: Transform3D, lo: Vector2, hi: Vector2, eave: float, rise: float, cover: String, color: Color, wall: String, wall_color: Color) -> void:
	var over := 0.35
	var slope := rise / (hi.y - lo.y)
	_sheet(cover, frame * Vector3(lo.x - 0.15, eave - over * slope, lo.y - over), frame * Vector3(hi.x + 0.15, eave - over * slope, lo.y - over), frame * Vector3(hi.x + 0.15, eave + rise + 0.1 * slope, hi.y + 0.1), frame * Vector3(lo.x - 0.15, eave + rise + 0.1 * slope, hi.y + 0.1), color)
	for x in [lo.x, hi.x]:
		var outward: Vector3 = frame.basis.x * signf(x - (lo.x + hi.x) * 0.5)
		batch.triangle(outward, wall, frame * Vector3(x, eave, lo.y), frame * Vector3(x, eave, hi.y), frame * Vector3(x, eave + rise, hi.y), wall_color)
	batch.facing(frame.basis.z, wall, frame * Vector3(lo.x, eave, hi.y), frame * Vector3(hi.x, eave, hi.y), frame * Vector3(hi.x, eave + rise, hi.y), frame * Vector3(lo.x, eave + rise, hi.y), wall_color)

# The steel tank every roof carries, lying on its side.
func _water_tank(frame: Transform3D, spot: Vector3) -> void:
	var tank := Transform3D(frame.basis * Basis(Vector3.FORWARD, PI * 0.5), frame * spot)
	for n in range(8):
		var turn := Transform3D(Basis(Vector3.UP, n * TAU / 8.0), Vector3.ZERO)
		batch.box("steel", tank * turn, Vector3(0.0, 0, 0.53), Vector3(0.44, 1.5, 0.05), Color.WHITE)

func _air_con(face: Transform3D, at: Vector3) -> void:
	batch.box("paint", face, at, Vector3(0.72, 0.5, 0.3), Color(0.82, 0.82, 0.80))

func _plants(frame: Transform3D, lo: Vector3, hi: Vector3, count: int, size := 0.9) -> void:
	for n in range(count):
		var at := Vector3(rng.randf_range(lo.x, hi.x), lo.y, rng.randf_range(lo.z, hi.z))
		_add_scatter("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), frame * at))

# ---- Tube house ----

# The narrow shop house: recessed ground floor, a balcony or a barred window on every floor above.
func _tube(lot: Dictionary, frame: Transform3D) -> void:
	var place: Dictionary = lot.get("place", {})
	var road: Dictionary = plan.roads[lot.road]
	var w: float = lot.width
	var d: float = lot.depth
	var floors: int = place.get("floors", _floors_for(road))
	var tall: float = plan.FLOOR
	var height: float = floors * tall
	var tint: Color = place.get("tint", FACADES[rng.randi() % FACADES.size()])
	tint = tint.darkened(rng.randf_range(0.0, 0.08))
	var skin: String = "aged" if rng.randf() < 0.12 else "plaster"
	# Upper body with a recessed ground floor, the usual shop shape.
	batch.box(skin, frame, Vector3(0, tall + (height - tall) * 0.5, d * 0.5), Vector3(w, height - tall, d), tint)
	batch.box(skin, frame, Vector3(0, tall * 0.5, (d + PORCH) * 0.5), Vector3(w, tall, d - PORCH), tint.darkened(0.08))
	for side in [-1.0, 1.0]:
		batch.box("plaster", frame, Vector3(side * (w * 0.5 - 0.13), tall * 0.5, PORCH * 0.5), Vector3(0.26, tall, PORCH), tint)
	batch.box("plaster", frame, Vector3(0, tall - 0.05, PORCH * 0.5), Vector3(w, 0.1, PORCH), Color(0.82, 0.80, 0.74), false)
	_solid(frame, Vector3(0, 6, d * 0.5 + PORCH * 0.5), Vector3(w, 12.0, d - PORCH))
	for side in [-1.0, 1.0]:
		_solid(frame, Vector3(side * (w * 0.5 - 0.13), 6, PORCH * 0.5), Vector3(0.26, 12.0, PORCH))
	_shopfront(lot, frame, w, PORCH, tall, place, road)
	for level in range(1, floors):
		_upper_floor(frame, w, level * tall, tall, tint, skin, level, floors)
	_rooftop(frame, w, d, height, tint)
	_side_windows(frame, w, d, floors)

func _floors_for(road: Dictionary) -> int:
	match road.kind:
		"main":
			return rng.randi_range(3, 6)
		"street":
			return rng.randi_range(2, 5)
		"country":
			return rng.randi_range(1, 2)
	return rng.randi_range(2, 4)

func _shopfront(lot: Dictionary, frame: Transform3D, w: float, recess: float, tall: float, place: Dictionary, road: Dictionary) -> void:
	var inner := w - 0.52
	var alley: bool = road.kind == "alley"
	var title: String = place.get("label", "")
	var kind: String = place.get("style", "")
	if kind.is_empty():
		var roll := rng.randf()
		kind = ("shut" if roll < 0.35 else ("home" if roll < 0.75 else "open")) if alley else ("shut" if roll < 0.14 else ("home" if roll < 0.24 else "open"))
	# Mười Gió is found by "the house with the brown wooden door", so his lot is always a home.
	if lot.get("kiosk", false):
		kind = "home"
	match kind:
		"shut":
			var set_name: String = "rust" if rng.randf() < 0.4 else "shutter"
			batch.box(set_name, frame, Vector3(0, (tall - 0.1) * 0.5, 0.2), Vector3(inner, tall - 0.1, 0.06), Color(0.86, 0.87, 0.86).darkened(rng.randf_range(0, 0.25)))
			_solid(frame, Vector3(0, 1.5, 0.2), Vector3(inner, 3.0, 0.2))
		"home":
			batch.box("paint", frame, Vector3(0, 1.25, recess - 0.04), Vector3(inner * 0.92, 2.5, 0.08), Color(0.32, 0.20, 0.14))
			# Mười Gió sells from this porch, so its gate is left off and it stays open.
			if not lot.get("kiosk", false):
				batch.quad("rail", frame * Vector3(inner * 0.5, 0, 0.3), frame * Vector3(-inner * 0.5, 0, 0.3), frame * Vector3(-inner * 0.5, 2.8, 0.3), frame * Vector3(inner * 0.5, 2.8, 0.3), Color.WHITE, Vector2(inner * 2.0, 3.0))
				_solid(frame, Vector3(0, 1.5, 0.3), Vector3(inner, 3.0, 0.12))
		_:
			# An unnamed shop is named here, because the name says what to put inside.
			if title.is_empty():
				title = _shop_name()
			batch.box("lit", frame, Vector3(0, tall - 0.14, 1.2), Vector3(inner * 0.5, 0.05, 0.1), Color.WHITE)
			_open_front(_trade(title), frame, inner, recess, tall)
			if rng.randf() < 0.7 or not place.is_empty():
				_awning(frame, w, tall)
	if alley and place.is_empty() and rng.randf() < 0.65:
		return
	if kind == "home" and place.get("id", "") == "home":
		var plate := Label3D.new()
		plate.font = ThemeDB.fallback_font
		plate.text = "14"
		plate.font_size = 96
		plate.pixel_size = 0.004
		plate.double_sided = false
		plate.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(w * 0.5 - 0.5, 2.3, 0.2))
		builder.signs_root.add_child(plate)
		return
	if kind != "home" or rng.randf() < 0.3:
		_shop_sign(frame, w, tall, place, title)

# Names are dealt like a shuffled deck: each comes round equally often, but a row of shops
# never repeats the order of the last one. Shuffled by hand so it follows the town's seed.
func _shop_name() -> String:
	if shop_names.is_empty():
		shop_names = plan.SHOPS.duplicate()
		for i in range(shop_names.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swapped: String = shop_names[i]
			shop_names[i] = shop_names[j]
			shop_names[j] = swapped
	return shop_names.pop_back()

func _trade(title: String) -> String:
	for trade in TRADES:
		for start in TRADES[trade]:
			if title.begins_with(start):
				return trade
	return "goods"

# The inside of an open shop, by what it sells.
func _open_front(trade: String, frame: Transform3D, inner: float, recess: float, tall: float) -> void:
	if trade == "glazed":
		# Salon, clinic, karaoke: a glass front with a frosted band and nothing of the room to see.
		_glazing(frame, Vector3(0, (tall - 0.1) * 0.5, 0.3), Vector2(inner, tall - 0.1))
		_panel("paint", frame, Vector3(0, 1.25, 0.26), Vector2(inner - 0.1, 0.5), Color(0.86, 0.90, 0.92))
		_solid(frame, Vector3(0, 1.5, 0.3), Vector3(inner, 3.0, 0.12))
		return
	batch.box("plaster", frame, Vector3(0, 1.4, recess - 0.04), Vector3(inner, 2.8, 0.08), Color(0.70, 0.66, 0.58))
	match trade:
		"eatery":
			_eatery(frame, inner, recess)
		"repair":
			_workshop(frame, inner, recess)
		"counter":
			_display_counter(frame, inner, recess)
		"clothes":
			_clothes_racks(frame, inner, recess)
		_:
			_shelves(frame, inner, recess, GOODS)

# Three shelves of boxes across the back wall.
func _shelves(frame: Transform3D, inner: float, recess: float, colours: Array) -> void:
	for shelf in range(3):
		var y := 0.62 + shelf * 0.68
		batch.box("paint", frame, Vector3(0, y, recess - 0.3), Vector3(inner * 0.9, 0.05, 0.5), Color(0.30, 0.23, 0.18))
		var n := -inner * 0.43
		while n < inner * 0.43:
			var size := Vector3(rng.randf_range(0.1, 0.24), rng.randf_range(0.14, 0.46), 0.22)
			if rng.randf() < 0.88:
				batch.box("paint", frame, Vector3(n, y + size.y * 0.5 + 0.03, recess - 0.3), size, colours[rng.randi() % colours.size()].darkened(rng.randf() * 0.35))
			n += size.x + 0.02

# A shop window: one sheet of glass divided by dark frames, with a transom across the top.
func _glazing(face: Transform3D, at: Vector3, size: Vector2) -> void:
	_panel("pane", face, at, size)
	var panes := maxi(int(size.x / 1.3), 2)
	for n in range(panes + 1):
		batch.box("paint", face, at + Vector3(-size.x * 0.5 + n * size.x / panes, 0, -0.01), Vector3(0.06, size.y, 0.06), DARK)
	for y in [-size.y * 0.5 + 0.03, size.y * 0.5 - 0.55, size.y * 0.5 - 0.03]:
		batch.box("paint", face, at + Vector3(0, y, -0.01), Vector3(size.x, 0.06, 0.06), DARK)

# Somewhere to eat: plastic chairs round low tables, a menu board, and the steel counter with
# its glass case that the food is served from. Two tables leave an aisle up the middle to the
# counter; one table shares the width with it.
func _eatery(frame: Transform3D, inner: float, recess: float) -> void:
	var tables := 2 if inner >= 5.0 else 1
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	# A set with its chairs needs about a metre each way from the table's centre.
	var reach := maxf(inner * 0.5 - 1.05, 0.0)
	for n in range(tables):
		_table_set(frame, Vector3(side * reach * (1.0 - 2.0 * n), 0, 1.0))
	# Against the back wall, clear of the chairs on the back side of the tables.
	var counter := Vector3(0.0 if tables == 2 else -side * (inner * 0.5 - 0.8), 0, recess - 0.3)
	batch.box("steel", frame, counter + Vector3(0, 0.42, 0), Vector3(1.2, 0.84, 0.45), Color(0.9, 0.9, 0.9))
	batch.box("pane", frame, counter + Vector3(-0.2, 1.09, 0), Vector3(0.7, 0.5, 0.38))
	batch.box("steel", frame, counter + Vector3(0.4, 1.0, 0), Vector3(0.3, 0.32, 0.3))
	_panel("paint", frame, Vector3(side * inner * 0.22, 2.0, recess - 0.09), Vector2(1.3, 0.7), SIGNS[rng.randi() % SIGNS.size()])

# The street's own plastic chairs and table, set down inside the shop.
func _table_set(frame: Transform3D, at: Vector3) -> void:
	var here: Vector3 = frame * at
	builder._sidewalk_seats(Vector2(here.x, here.z), Vector2(frame.basis.x.x, frame.basis.x.z), here.y, true)
	# The builder files the table under its own map chunk; go back to this house's.
	batch.at(frame.origin)

# A repair shop: bikes waiting on the floor, a tool chest, a stack of tyres, a compressor.
func _workshop(frame: Transform3D, inner: float, recess: float) -> void:
	for n in range(rng.randi_range(2, 3)):
		var at := Vector3(rng.randf_range(-inner * 0.3, inner * 0.3), 0, rng.randf_range(0.6, 1.4))
		var tone := Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.5), rng.randf_range(0.35, 0.95))
		_add_scatter("scooter", Transform3D(frame.basis * Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.6, 0.6)), frame * at), tone)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	batch.box("paint", frame, Vector3(side * (inner * 0.5 - 0.5), 0.5, recess - 0.36), Vector3(0.8, 1.0, 0.5), Color(0.70, 0.10, 0.08))
	for n in range(4):
		batch.box("paint", frame, Vector3(-side * (inner * 0.5 - 0.42), 0.09 + n * 0.17, recess - 0.42), Vector3(0.58, 0.15, 0.58), Color(0.07, 0.07, 0.08))
	batch.box("paint", frame, Vector3(-side * (inner * 0.5 - 1.25), 0.3, recess - 0.3), Vector3(0.7, 0.36, 0.36), Color(0.85, 0.45, 0.10))
	batch.box("paint", frame, Vector3(0, 1.75, recess - 0.25), Vector3(inner * 0.9, 0.05, 0.36), Color(0.30, 0.23, 0.18))
	var x := -inner * 0.4
	while x < inner * 0.4:
		var size := Vector3(rng.randf_range(0.15, 0.4), rng.randf_range(0.12, 0.3), 0.22)
		batch.box("paint", frame, Vector3(x, 1.78 + size.y * 0.5, recess - 0.25), size, Color(0.3, 0.3, 0.32).lightened(rng.randf() * 0.4))
		x += size.x + rng.randf_range(0.05, 0.3)

# Phones, medicine, gold: a glass display counter across the front, small packets on the wall.
func _display_counter(frame: Transform3D, inner: float, recess: float) -> void:
	_shelves(frame, inner, recess, PACKETS)
	var length := inner * 0.62
	var x := (1.0 if rng.randf() < 0.5 else -1.0) * (inner * 0.5 - length * 0.5 - 0.1)
	batch.box("paint", frame, Vector3(x, 0.3, 0.7), Vector3(length, 0.6, 0.5), Color(0.90, 0.90, 0.88))
	batch.box("pane", frame, Vector3(x, 0.8, 0.7), Vector3(length, 0.4, 0.5))
	batch.box("steel", frame, Vector3(x, 1.02, 0.7), Vector3(length + 0.04, 0.04, 0.54))
	_solid(frame, Vector3(x, 0.5, 0.7), Vector3(length, 1.0, 0.5))

# Clothes: two rails of garments along the back wall and one more rack near the door.
func _clothes_racks(frame: Transform3D, inner: float, recess: float) -> void:
	# _laundry hangs its washing 0.6 m in front of the frame it is given, from 2.42 m above y.
	var wall := frame.translated_local(Vector3(0, 0, recess + 0.35))
	for y in [-0.5, -1.45]:
		batch.box("steel", wall, Vector3(0, y + 2.45, -0.6), Vector3(inner * 0.84, 0.03, 0.03))
		_laundry(wall, inner, y)
	var rack := frame.translated_local(Vector3((1.0 if rng.randf() < 0.5 else -1.0) * (inner * 0.5 - 1.0), 0, 1.5))
	batch.box("steel", rack, Vector3(0, 1.7, -0.6), Vector3(1.5, 0.03, 0.03))
	for side in [-1.0, 1.0]:
		batch.box("steel", rack, Vector3(side * 0.75, 0.85, -0.6), Vector3(0.03, 1.7, 0.03))
	_laundry(rack, 1.6, -0.75)

func _awning(frame: Transform3D, w: float, tall: float) -> void:
	var color: Color = AWNINGS[rng.randi() % AWNINGS.size()]
	var stripes := int(w / 0.8)
	for n in range(stripes):
		var left := -w * 0.5 + n * w / stripes
		var right := left + w / stripes
		var tone: Color = color if n % 2 == 0 else Color(0.92, 0.90, 0.84)
		batch.quad("paint", frame * Vector3(left, tall - 0.75, -1.5), frame * Vector3(right, tall - 0.75, -1.5), frame * Vector3(right, tall - 0.2, 0.0), frame * Vector3(left, tall - 0.2, 0.0), tone)
		batch.quad("paint", frame * Vector3(left, tall - 0.2, 0.0), frame * Vector3(right, tall - 0.2, 0.0), frame * Vector3(right, tall - 0.75, -1.5), frame * Vector3(left, tall - 0.75, -1.5), tone.darkened(0.3))

# title is the name an open shop already took for itself; without one the board takes the next.
func _shop_sign(frame: Transform3D, w: float, tall: float, place: Dictionary, title := "") -> void:
	var color: Color = place.get("sign", SIGNS[rng.randi() % SIGNS.size()])
	var text: String = title if not title.is_empty() else _shop_name()
	if place.is_empty() and rng.randf() < 0.4:
		_blade_sign(frame, w, tall, color)
	var y := tall + 0.42
	batch.box("paint", frame, Vector3(0, y, -0.14), Vector3(w - 0.12, 0.8, 0.14), color)
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = text.to_upper()
	label.font_size = 64
	label.pixel_size = 0.0058
	label.width = 900
	label.modulate = Color(0.09, 0.08, 0.07) if color.get_luminance() > 0.55 else Color(0.98, 0.95, 0.82)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.visibility_range_end = 70.0
	var fit := minf(1.0, (w - 0.5) / (text.length() * 0.27 + 0.2))
	label.scale = Vector3.ONE * fit
	# The label reads towards the street, which is the frame's -Z.
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * fit), frame * Vector3(0, y, -0.225))
	builder.signs_root.add_child(label)

func _upper_floor(frame: Transform3D, w: float, y: float, tall: float, tint: Color, skin: String, level: int, floors: int) -> void:
	var inner := w - 0.5
	var balcony := rng.randf() < 0.72
	if balcony:
		batch.box("plaster", frame, Vector3(0, y + 0.03, -0.42), Vector3(w - 0.1, 0.14, 0.84), tint.darkened(0.12), false)
		var low := y + 0.1
		var high := y + 1.12
		batch.quad("rail", frame * Vector3(inner * 0.5 + 0.2, low, -0.8), frame * Vector3(-inner * 0.5 - 0.2, low, -0.8), frame * Vector3(-inner * 0.5 - 0.2, high, -0.8), frame * Vector3(inner * 0.5 + 0.2, high, -0.8), Color.WHITE, Vector2(inner * 2.2, 1.0))
		if rng.randf() < 0.13:
			_laundry(frame, inner, y)
		if rng.randf() < 0.4:
			for n in range(rng.randi_range(1, 3)):
				var ledge := frame * Vector3(rng.randf_range(-inner * 0.42, inner * 0.42), y + 0.1, -0.62)
				_add_scatter("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.9), ledge))
	var door := inner * rng.randf_range(0.5, 0.76)
	var top := y + tall - 0.62
	var bottom := y + (0.12 if balcony else 0.95)
	var middle := (top + bottom) * 0.5
	batch.box("glass", frame, Vector3(0, middle, -0.01), Vector3(door, top - bottom, 0.03), Color(0.75, 0.82, 0.86))
	if rng.randf() < 0.55:
		var cloth := Color.from_hsv(rng.randf_range(0.05, 0.6), rng.randf_range(0.08, 0.3), rng.randf_range(0.7, 0.92))
		var half_way := door * rng.randf_range(0.2, 0.5)
		batch.box("paint", frame, Vector3(-door * 0.5 + half_way * 0.5, middle, -0.03), Vector3(half_way, top - bottom, 0.02), cloth)
	var trim: Color = Color(0.88, 0.86, 0.80) if rng.randf() < 0.6 else Color(0.34, 0.24, 0.16)
	batch.box("paint", frame, Vector3(0, top + 0.03, -0.03), Vector3(door + 0.14, 0.07, 0.07), trim)
	batch.box("paint", frame, Vector3(0, bottom - 0.03, -0.03), Vector3(door + 0.14, 0.07, 0.07), trim)
	for x in [-door * 0.5, 0.0, door * 0.5]:
		batch.box("paint", frame, Vector3(x, middle, -0.03), Vector3(0.06, top - bottom, 0.06), trim)
	if not balcony:
		batch.quad("rail", frame * Vector3(door * 0.5, bottom, -0.08), frame * Vector3(-door * 0.5, bottom, -0.08), frame * Vector3(-door * 0.5, top, -0.08), frame * Vector3(door * 0.5, top, -0.08), Color.WHITE, Vector2(door * 2.4, 2.0))
	if rng.randf() < 0.3:
		_air_con(frame, Vector3(-inner * 0.34 * (1.0 if rng.randf() < 0.5 else -1.0), y + 2.75, -0.2))
	if level == floors - 1 and rng.randf() < 0.3:
		batch.box("paint", frame, Vector3(0, y + tall - 0.2, -0.02), Vector3(inner, 0.12, 0.05), tint.darkened(0.3))

func _laundry(frame: Transform3D, inner: float, y: float) -> void:
	var x := -inner * 0.4
	while x < inner * 0.4:
		var cloth := Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.45), rng.randf_range(0.35, 0.7))
		var size := Vector2(rng.randf_range(0.26, 0.4), rng.randf_range(0.4, 0.68))
		var top := y + 2.42
		batch.quad("paint", frame * Vector3(x + size.x, top - size.y, -0.6), frame * Vector3(x, top - size.y, -0.6), frame * Vector3(x, top, -0.6), frame * Vector3(x + size.x, top, -0.6), cloth)
		batch.quad("paint", frame * Vector3(x, top - size.y, -0.6), frame * Vector3(x + size.x, top - size.y, -0.6), frame * Vector3(x + size.x, top, -0.6), frame * Vector3(x, top, -0.6), cloth)
		x += size.x + rng.randf_range(0.08, 0.3)

func _rooftop(frame: Transform3D, w: float, d: float, height: float, tint: Color) -> void:
	var roof := rng.randf()
	var wall := 0.85 if roof > 0.32 else 0.3
	batch.box("plaster", frame, Vector3(0, height + wall * 0.5, 0.09), Vector3(w, wall, 0.18), tint.darkened(0.05))
	for side in [-1.0, 1.0]:
		batch.box("plaster", frame, Vector3(side * (w * 0.5 - 0.08), height + 0.3, d * 0.5), Vector3(0.16, 0.6, d), tint.darkened(0.15))
	if roof < 0.32:
		var ridge := height + 2.0
		batch.quad("roof", frame * Vector3(w * 0.5 + 0.2, height + 0.25, -0.3), frame * Vector3(-w * 0.5 - 0.2, height + 0.25, -0.3), frame * Vector3(-w * 0.5, ridge, 2.5), frame * Vector3(w * 0.5, ridge, 2.5), Color(0.86, 0.60, 0.46))
		batch.quad("roof", frame * Vector3(-w * 0.5, height + 0.2, 5.0), frame * Vector3(w * 0.5, height + 0.2, 5.0), frame * Vector3(w * 0.5, ridge, 2.5), frame * Vector3(-w * 0.5, ridge, 2.5), Color(0.8, 0.56, 0.44))
	var tin: String = "rust_tin" if rng.randf() < 0.45 else "tin"
	batch.quad(tin, frame * Vector3(-w * 0.5, height + 0.3, d), frame * Vector3(w * 0.5, height + 0.3, d), frame * Vector3(w * 0.5, height + 1.6, d * 0.55), frame * Vector3(-w * 0.5, height + 1.6, d * 0.55), Color(0.85, 0.82, 0.76))
	if rng.randf() < 0.75:
		var spot := Vector3(rng.randf_range(-w * 0.2, w * 0.2), height + 0.95, d * 0.42)
		_water_tank(frame, spot)

func _side_windows(frame: Transform3D, w: float, d: float, floors: int) -> void:
	for side in [-1.0, 1.0]:
		var face := frame * Transform3D(Basis(Vector3.UP, -side * PI * 0.5), Vector3(side * w * 0.5, 0, d * 0.5))
		for level in range(1, floors):
			if rng.randf() < 0.7:
				_window(face, Vector3(rng.randf_range(-d * 0.3, d * 0.3), level * plan.FLOOR + 1.7, 0), Vector2(1.06, 1.16), Color(0.78, 0.76, 0.70), true)

func _blade_sign(frame: Transform3D, w: float, tall: float, color: Color) -> void:
	var x := (w * 0.5 - 0.2) * (1.0 if rng.randf() < 0.5 else -1.0)
	var length := rng.randf_range(1.6, 2.8)
	batch.box("paint", frame, Vector3(x, tall + 0.6 + length * 0.5, -0.5), Vector3(0.12, length, 0.72), color)
	batch.box("lit", frame, Vector3(x, tall + 0.6 + length * 0.5, -0.5), Vector3(0.14, length * 0.86, 0.1), Color(1.0, 0.95, 0.8))

# ---- Modern town house ----

# A new build: flat front, big glass, and often a top floor set back behind a terrace.
func _modern(lot: Dictionary, frame: Transform3D) -> void:
	var road: Dictionary = plan.roads[lot.road]
	var w: float = lot.width
	var d: float = lot.depth
	var tall: float = plan.FLOOR
	var floors: int = rng.randi_range(4, 7) if road.kind == "main" else rng.randi_range(3, 5)
	if d < 7.0:
		floors = mini(floors, 4)
	var stepped: bool = d > 7.0 and rng.randf() < 0.55
	var front_floors: int = floors - 1 if stepped else floors
	var height: float = floors * tall
	var front: float = front_floors * tall
	var tint: Color = MODERN[rng.randi() % MODERN.size()]
	var skin: String = ["plaster", "cladding", "stone"][rng.randi() % 3]
	# Party walls stay bare cement; only the street front is finished.
	batch.box("concrete", frame, Vector3(0, front * 0.5, d * 0.5), Vector3(w, front, d), CEMENT)
	batch.box(skin, frame, Vector3(0, tall + (front - tall) * 0.5, -0.05), Vector3(w, front - tall, 0.1), tint)
	_solid(frame, Vector3(0, 6, d * 0.5), Vector3(w, 12.0, d))
	_modern_ground(frame, w, tall, road)
	match rng.randi() % 3:
		0:
			_ribbon_front(frame, w, tall, front_floors)
		1:
			_framed_front(frame, w, tall, front_floors)
		2:
			_punched_front(frame, w, tall, front_floors)
	if stepped:
		_terrace_floor(frame, w, d, front, tall, tint)
	else:
		batch.box(skin, frame, Vector3(0, height + 0.3, 0.04), Vector3(w, 0.6, 0.28), tint)
	for side in [-1.0, 1.0]:
		batch.box("concrete", frame, Vector3(side * (w * 0.5 - 0.08), height + 0.25, d * 0.5), Vector3(0.16, 0.5, d), CEMENT)
	# The stair head and the tank.
	if rng.randf() < 0.6:
		batch.box("concrete", frame, Vector3(rng.randf_range(-0.5, 0.5), height + 1.3, d * 0.7), Vector3(minf(w - 1.0, 3.0), 2.6, minf(d * 0.35, 3.4)), CEMENT)
	if rng.randf() < 0.7:
		_water_tank(frame, Vector3(rng.randf_range(-w * 0.2, w * 0.2), height + 0.95, d * 0.35))
	_side_windows(frame, w, d, floors)

# Stone-clad ground floor: a glazed shop on busy streets, a garage and a door elsewhere.
func _modern_ground(frame: Transform3D, w: float, tall: float, road: Dictionary) -> void:
	batch.box("granite", frame, Vector3(0, tall * 0.5, -0.05), Vector3(w, tall, 0.1), Color(0.80, 0.80, 0.80).darkened(rng.randf_range(0.0, 0.45)))
	if rng.randf() < {"main": 0.75, "street": 0.5}.get(road.kind, 0.15):
		_glazing(frame, Vector3(0, 1.45, -0.11), Vector2(w - 0.9, 2.6))
		_shop_sign(frame, w, tall, {})
		return
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var garage := minf(w * 0.5, 3.2)
	batch.box("shutter", frame, Vector3(side * (w * 0.5 - 0.45 - garage * 0.5), 1.35, -0.11), Vector3(garage, 2.7, 0.04), Color(0.88, 0.88, 0.86))
	var door := -side * (w * 0.5 - 1.15)
	batch.box("wood", frame, Vector3(door, 1.15, -0.11), Vector3(1.0, 2.3, 0.05), Color(0.62, 0.44, 0.30))
	batch.box("steel", frame, Vector3(door + side * 0.36, 1.1, -0.15), Vector3(0.04, 0.5, 0.04))
	if rng.randf() < 0.7:
		batch.box("plaster", frame, Vector3(0, tall - 0.08, -0.6), Vector3(w, 0.14, 1.2), Color(0.92, 0.92, 0.90), false)

# Strip windows from wall to wall on every floor, some with the blinds down.
func _ribbon_front(frame: Transform3D, w: float, tall: float, floors: int) -> void:
	var span := w - 0.7
	var panes := maxi(int(span / 1.1), 2)
	var pane := span / panes
	for level in range(1, floors):
		var y := level * tall + 1.75
		_panel("pane", frame, Vector3(0, y, -0.11), Vector2(span, 1.9))
		for n in range(panes + 1):
			batch.box("paint", frame, Vector3(-span * 0.5 + n * pane, y, -0.12), Vector3(0.05, 1.9, 0.05), DARK)
			if n < panes and rng.randf() < 0.3:
				_panel("paint", frame, Vector3(-span * 0.5 + (n + 0.5) * pane, y + 0.95 - 0.6, -0.115), Vector2(pane - 0.06, 1.2), Color(0.86, 0.84, 0.78))
		for edge in [-0.95, 0.95]:
			batch.box("paint", frame, Vector3(0, y + edge, -0.13), Vector3(span + 0.1, 0.07, 0.1), DARK)

# A white frame around the whole front, balconies inside it, and a screen of timber fins.
func _framed_front(frame: Transform3D, w: float, tall: float, floors: int) -> void:
	var low := tall + 0.2
	var high := floors * tall - 0.1
	var white := Color(0.95, 0.95, 0.93)
	for side in [-1.0, 1.0]:
		batch.box("plaster", frame, Vector3(side * (w * 0.5 - 0.11), (low + high) * 0.5, -0.45), Vector3(0.22, high - low, 0.9), white)
	for y in [low, high]:
		batch.box("plaster", frame, Vector3(0, y, -0.45), Vector3(w, 0.22, 0.9), white, false)
	for level in range(1, floors):
		var y := level * tall
		_panel("pane", frame, Vector3(0, y + 1.5, -0.11), Vector2(w - 0.7, 2.5))
		if level > 1:
			batch.box("plaster", frame, Vector3(0, y, -0.45), Vector3(w - 0.44, 0.12, 0.9), white, false)
		_panel("rail", frame, Vector3(0, y + 0.62, -0.86), Vector2(w - 0.44, 1.0), Color.WHITE, Vector2((w - 0.44) * 2.0, 1.0))
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var fins := int(w * rng.randf_range(0.28, 0.42) / 0.24)
	var tone := Color(0.74, 0.54, 0.36).darkened(rng.randf_range(0.0, 0.3))
	for n in range(fins):
		batch.box("wood", frame, Vector3(side * (w * 0.5 - 0.4 - n * 0.24), (low + high) * 0.5, -0.78), Vector3(0.07, high - low - 0.2, 0.2), tone)

# A solid finished wall with tall windows and one contrasting strip up the full height.
func _punched_front(frame: Transform3D, w: float, tall: float, floors: int) -> void:
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var strip := w * 0.24
	var accent: String = ["wood", "granite", "paint"][rng.randi() % 3]
	var tone: Color = {"wood": Color(0.74, 0.54, 0.36), "granite": Color(0.55, 0.55, 0.55), "paint": Color(0.78, 0.38, 0.20)}[accent]
	var top := floors * tall
	batch.box(accent, frame, Vector3(side * (w * 0.5 - strip * 0.5), (tall + top) * 0.5, -0.13), Vector3(strip, top - tall, 0.08), tone)
	var room := w - strip
	var columns := 2 if room > 4.4 else 1
	var wide := minf(room / columns - 0.7, 1.8)
	var juliet := rng.randf() < 0.5
	for level in range(1, floors):
		var y := level * tall
		for column in range(columns):
			var x := -side * (w * 0.5 - room * (column + 0.5) / columns)
			_window(frame, Vector3(x, y + 1.6, -0.1), Vector2(wide, 2.1), DARK, false, "pane")
			if juliet:
				_panel("rail", frame, Vector3(x, y + 1.05, -0.22), Vector2(wide + 0.2, 1.0), Color.WHITE, Vector2(wide * 2.4, 1.0))
		if rng.randf() < 0.3:
			_air_con(frame, Vector3(side * (w * 0.5 - strip * 0.5), y + 0.6, -0.3))

# The top floor set back behind a terrace, under a slab that sails out over it.
func _terrace_floor(frame: Transform3D, w: float, d: float, y: float, tall: float, tint: Color) -> void:
	var back := 2.8
	batch.box("plaster", frame, Vector3(0, y + tall * 0.5, (d + back) * 0.5), Vector3(w - 0.3, tall, d - back), tint)
	_panel("pane", frame, Vector3(0, y + 1.3, back - 0.02), Vector2(w - 1.6, 2.4))
	batch.box("plaster", frame, Vector3(0, y + 0.2, 0.04), Vector3(w, 0.4, 0.28), tint)
	_panel("rail", frame, Vector3(0, y + 0.85, 0.0), Vector2(w - 0.2, 0.9), Color.WHITE, Vector2(w * 2.0, 1.0))
	batch.box("plaster", frame, Vector3(0, y + tall + 0.1, (d + 1.0) * 0.5), Vector3(w, 0.2, d - 1.0), Color(0.92, 0.92, 0.90), false)
	if rng.randf() < 0.6:
		_plants(frame, Vector3(-w * 0.4, y + 0.02, 0.5), Vector3(w * 0.4, y + 0.02, 1.2), rng.randi_range(2, 4), 1.1)

# ---- Cottage ----

# A single-storey house in brick or lime wash under tile or tin. Deep lots keep a walled yard
# in front; shallow ones open straight onto the street, often as a small shop.
func _cottage(lot: Dictionary, frame: Transform3D) -> void:
	var road: Dictionary = plan.roads[lot.road]
	var w: float = lot.width
	var d: float = lot.depth
	var yard: float = rng.randf_range(2.4, 3.4) if d >= 10.0 else 0.0
	var shop: bool = yard == 0.0 and d >= 7.0 and rng.randf() < 0.6
	# A shop needs the height of a shop front; a house sits lower.
	var wall: float = plan.FLOOR if shop else rng.randf_range(2.9, 3.4)
	# A wide lot leaves a passage down one side.
	var passage: float = rng.randf_range(0.6, 1.3) if w > 7.5 and rng.randf() < 0.6 else 0.0
	var bw := w - passage
	var body := frame.translated_local(Vector3((passage if rng.randf() < 0.5 else -passage) * 0.5, 0, 0))
	var z0 := yard + (PORCH if shop else 0.0)
	var z1 := minf(d, yard + rng.randf_range(6.5, 9.5))
	var skin: String = ["brick", "yellow", "peel", "plaster", "plaster", "aged"][rng.randi() % 6]
	var tint: Color = FACADES[rng.randi() % FACADES.size()] if skin in ["plaster", "aged", "peel"] else Color.WHITE
	tint = tint.darkened(rng.randf_range(0.0, 0.12))
	batch.box(skin, body, Vector3(0, wall * 0.5, (z0 + z1) * 0.5), Vector3(bw, wall, z1 - z0), tint)
	_solid(frame, Vector3(0, 6, (z0 + d) * 0.5), Vector3(w, 12.0, d - z0))
	if shop:
		for side in [-1.0, 1.0]:
			batch.box(skin, body, Vector3(side * (bw * 0.5 - 0.13), wall * 0.5, PORCH * 0.5), Vector3(0.26, wall, PORCH), tint)
			_solid(body, Vector3(side * (bw * 0.5 - 0.13), 6, PORCH * 0.5), Vector3(0.26, 12.0, PORCH))
		batch.box("plaster", body, Vector3(0, wall - 0.05, PORCH * 0.5), Vector3(bw, 0.1, PORCH), Color(0.82, 0.80, 0.74), false)
		_shopfront(lot, body, bw, PORCH, wall, {}, road)
	else:
		_cottage_front(body, bw, z0, wall, yard > 0.0)
	if yard > 0.0:
		_yard(frame, w, yard, skin, tint)
	_cottage_roof(body, bw, yard, z1, wall, skin, tint, shop)

# Door in the middle, a barred window either side, a vent over the door.
func _cottage_front(body: Transform3D, bw: float, z0: float, wall: float, sheltered: bool) -> void:
	var face := body.translated_local(Vector3(0, 0, z0))
	var paint: Color = WOODWORK[rng.randi() % WOODWORK.size()]
	var pale := Color(0.86, 0.84, 0.78)
	batch.box("paint", face, Vector3(0, 1.15, -0.03), Vector3(1.3, 2.3, 0.06), paint)
	batch.box("paint", face, Vector3(0, 1.15, -0.065), Vector3(0.03, 2.3, 0.02), paint.darkened(0.45))
	batch.box("paint", face, Vector3(0, 2.36, -0.04), Vector3(1.5, 0.12, 0.1), pale)
	_panel("glass", face, Vector3(0, 2.66, -0.01), Vector2(1.3, 0.34), Color(0.5, 0.5, 0.5))
	_panel("grille", face, Vector3(0, 2.66, -0.02), Vector2(1.3, 0.34), pale, Vector2(3.0, 1.0))
	batch.box("concrete", face, Vector3(0, 0.07, -0.2), Vector3(1.9, 0.14, 0.4), Color(0.66, 0.66, 0.64), false)
	var reach := bw * 0.5 - 0.65
	if reach > 1.5:
		for side in [-1.0, 1.0]:
			_window(face, Vector3(side * (0.65 + reach * 0.5), 1.6, 0), Vector2(minf(reach - 0.6, 1.3), 1.2), paint, true)
	# The tin lean-to that keeps sun and rain off the door; in a yard it stands on posts.
	if rng.randf() < 0.55:
		var out := 1.6 if sheltered else 1.0
		var high := minf(wall - 0.2, 2.95)
		var low := high - 0.45
		var half := bw * 0.5 - 0.1
		_sheet("rust_tin" if rng.randf() < 0.4 else "tin", face * Vector3(-half, low, -out), face * Vector3(half, low, -out), face * Vector3(half, high, 0), face * Vector3(-half, high, 0), SHEET)
		if sheltered:
			for side in [-1.0, 1.0]:
				batch.box("paint", face, Vector3(side * (half - 0.15), low * 0.5, -out + 0.08), Vector3(0.06, low, 0.06), Color(0.30, 0.30, 0.32))

# The front yard: a low wall with iron above it, gate posts, and what the family keeps there.
func _yard(frame: Transform3D, w: float, yard: float, skin: String, tint: Color) -> void:
	var gate := rng.randf_range(1.6, 2.4)
	var gate_x := rng.randf_range(-1.0, 1.0) * (w * 0.5 - gate * 0.5 - 0.6)
	var iron: Color = IRONWORK[rng.randi() % IRONWORK.size()]
	for run in [Vector2(-w * 0.5, gate_x - gate * 0.5), Vector2(gate_x + gate * 0.5, w * 0.5)]:
		var length: float = run.y - run.x
		var mid: float = (run.x + run.y) * 0.5
		batch.box(skin, frame, Vector3(mid, 0.45, 0.1), Vector3(length, 0.9, 0.18), tint)
		_panel("grille", frame, Vector3(mid, 1.4, 0.1), Vector2(length, 1.0), iron, Vector2(length * 2.0, 1.0))
	for side in [-1.0, 1.0]:
		batch.box(skin, frame, Vector3(gate_x + side * gate * 0.5, 1.1, 0.1), Vector3(0.32, 2.2, 0.32), tint)
		batch.box(skin, frame, Vector3(side * (w * 0.5 - 0.08), 0.9, yard * 0.5), Vector3(0.16, 1.8, yard), tint)
	if rng.randf() < 0.5:
		batch.box("shutter", frame, Vector3(gate_x, 1.0, 0.1), Vector3(gate - 0.32, 2.0, 0.04), iron.lightened(0.3))
	else:
		_panel("grille", frame, Vector3(gate_x, 1.0, 0.1), Vector2(gate - 0.32, 2.0), iron, Vector2(gate * 2.4, 2.0))
	_solid(frame, Vector3(0, 1.5, 0.1), Vector3(w, 3.0, 0.24))
	batch.facing(Vector3.UP, "paver", frame * Vector3(-w * 0.5, 0.03, 0.2), frame * Vector3(w * 0.5, 0.03, 0.2), frame * Vector3(w * 0.5, 0.03, yard), frame * Vector3(-w * 0.5, 0.03, yard), Color(0.86, 0.62, 0.52))
	if rng.randf() < 0.45:
		var parked := Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.3, 0.3))
		var tone := Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.5), rng.randf_range(0.35, 0.95))
		_add_scatter("scooter", Transform3D(frame.basis * parked, frame * Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0.03, yard * 0.55)), tone)
	for n in range(rng.randi_range(0, 3)):
		_add_scatter("pot", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 3.0), frame * Vector3(rng.randf_range(-w * 0.42, w * 0.42), 0.03, yard - 0.35)))

func _cottage_roof(body: Transform3D, bw: float, z0: float, z1: float, wall: float, skin: String, tint: Color, shop: bool) -> void:
	var lo := Vector2(-bw * 0.5, z0)
	var hi := Vector2(bw * 0.5, z1)
	var tin: String = "rust_tin" if rng.randf() < 0.45 else "tin"
	var tile := TILE.darkened(rng.randf_range(0.0, 0.3))
	var roll := rng.randf()
	if shop or roll < 0.2:
		# A false front carries the sign and hides a tin roof that drains to the back.
		var rise := rng.randf_range(0.6, 1.0)
		batch.box(skin, body, Vector3(0, wall + (rise + 0.4) * 0.5, z0 + 0.08), Vector3(bw, rise + 0.4, 0.2), tint)
		var turned := body * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, z0 + z1))
		_shed(turned, lo, hi, wall, rise, tin, SHEET, skin, tint)
	elif roll < 0.5:
		_gable(body, lo, hi, wall, (z1 - z0) * 0.5 * rng.randf_range(0.42, 0.58), true, "roof", tile, skin, tint)
	elif roll < 0.68:
		_gable(body, lo, hi, wall, bw * 0.5 * rng.randf_range(0.4, 0.55), false, "roof", tile, skin, tint)
	elif roll < 0.86:
		_gable(body, lo, hi, wall, (z1 - z0) * 0.5 * rng.randf_range(0.2, 0.3), true, tin, SHEET, skin, tint)
	else:
		batch.box("concrete", body, Vector3(0, wall + 0.1, (z0 + z1) * 0.5 - 0.2), Vector3(bw + 0.5, 0.2, z1 - z0 + 0.8), CEMENT, false)
		if rng.randf() < 0.6:
			_water_tank(body, Vector3(rng.randf_range(-bw * 0.2, bw * 0.2), wall + 0.95, (z0 + z1) * 0.5))

# ---- Collective block ----

# Old collective housing: one long slab of identical flats over a row of shops, where every
# family has since caged in or bricked up its own balcony.
func _block(lot: Dictionary, frame: Transform3D) -> void:
	var road: Dictionary = plan.roads[lot.road]
	var w: float = lot.width
	var d: float = lot.depth
	var tall: float = plan.FLOOR
	var floors := rng.randi_range(4, 5)
	var height := floors * tall
	var skin: String = "mossy" if rng.randf() < 0.6 else "yellow"
	# The yellow lime wash is its own colour; stained render takes whatever it was last painted.
	var tint: Color = Color.WHITE if skin == "yellow" else BLOCKS[rng.randi() % BLOCKS.size()]
	tint = tint.darkened(rng.randf_range(0.0, 0.1))
	var trim: Color = WOODWORK[1 + rng.randi() % 2]
	batch.box(skin, frame, Vector3(0, tall + (height - tall) * 0.5, d * 0.5), Vector3(w, height - tall, d), tint)
	batch.box(skin, frame, Vector3(0, tall * 0.5, (d + PORCH) * 0.5), Vector3(w, tall, d - PORCH), tint.darkened(0.1))
	batch.box("plaster", frame, Vector3(0, tall - 0.05, PORCH * 0.5), Vector3(w, 0.1, PORCH), Color(0.82, 0.80, 0.74), false)
	_solid(frame, Vector3(0, 6, (d + PORCH) * 0.5), Vector3(w, 12.0, d - PORCH))
	var bays := roundi(w / 3.7)
	var bay_w := w / bays
	var stairs: Array = [floori(bays * 0.5)] if bays < 7 else [1, bays - 2]
	for bay in range(bays):
		var x := -w * 0.5 + (bay + 0.5) * bay_w
		var unit := frame.translated_local(Vector3(x, 0, 0))
		for side in [-1.0, 1.0]:
			batch.box(skin, unit, Vector3(side * (bay_w * 0.5 - 0.13), tall * 0.5, PORCH * 0.5), Vector3(0.26, tall, PORCH), tint)
			_solid(unit, Vector3(side * (bay_w * 0.5 - 0.13), 6, PORCH * 0.5), Vector3(0.26, 12.0, PORCH))
		if bay in stairs:
			_stairwell(unit, bay_w, floors, tall, skin, tint)
			continue
		_shopfront(lot, unit, bay_w, PORCH, tall, {}, road)
		for level in range(1, floors):
			_flat_unit(unit, bay_w, level * tall, tall, skin, tint, trim, level == 1)
		# On the roof: a tank, or a room somebody added.
		var roll := rng.randf()
		if roll < 0.45:
			_water_tank(frame, Vector3(x, height + 0.95, d * rng.randf_range(0.35, 0.7)))
		elif roll < 0.62:
			var hut := frame.translated_local(Vector3(x, height, d * 0.6))
			var half := bay_w * 0.5 - 0.25
			var wall: String = ["brick", "aged", "tin"][rng.randi() % 3]
			batch.box(wall, hut, Vector3(0, 1.15, 0), Vector3(half * 2.0, 2.3, 4.0), Color(0.90, 0.88, 0.84))
			_shed(hut, Vector2(-half, -2.0), Vector2(half, 2.0), 2.3, 0.5, "rust_tin", SHEET, wall, Color(0.90, 0.88, 0.84))
	for level in range(1, floors + 1):
		batch.box(skin, frame, Vector3(0, level * tall, -0.02), Vector3(w + 0.04, 0.16, 0.1), tint.darkened(0.22))
	batch.box(skin, frame, Vector3(0, height + 0.35, 0.09), Vector3(w, 0.7, 0.18), tint.darkened(0.05))
	for side in [-1.0, 1.0]:
		batch.box(skin, frame, Vector3(side * (w * 0.5 - 0.08), height + 0.35, d * 0.5), Vector3(0.16, 0.7, d), tint.darkened(0.1))
	_side_windows(frame, w, d, floors)
	# The block's name, painted on the first stair head where the whole street can read it.
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = "NHÀ %s%d" % [String.chr(65 + block_index % 5), rng.randi_range(1, 6)]
	label.font_size = 96
	label.pixel_size = 0.008
	label.modulate = Color(0.42, 0.16, 0.12)
	label.shaded = true
	label.double_sided = false
	label.visibility_range_end = 120.0
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * Vector3(-w * 0.5 + (stairs[0] + 0.5) * bay_w, height + 1.5, -0.02))
	builder.signs_root.add_child(label)
	block_index += 1

# One family's bay on one floor. The floor over the shop signs stays flush with the wall.
func _flat_unit(unit: Transform3D, bay_w: float, y: float, tall: float, skin: String, tint: Color, trim: Color, flush: bool) -> void:
	var inner := bay_w - 0.4
	var roll := rng.randf()
	if rng.randf() < 0.3:
		_air_con(unit, Vector3(inner * (0.38 if rng.randf() < 0.5 else -0.38), y + 2.75, -0.2))
	if flush or roll > 0.82:
		# The balcony was bricked in long ago; two windows are all that shows.
		for side in [-1.0, 1.0]:
			_window(unit, Vector3(side * inner * 0.24, y + 1.7, 0), Vector2(inner * 0.36, 1.15), trim, rng.randf() < 0.6)
		return
	batch.box("paint", unit, Vector3(-inner * 0.24, y + 1.12, -0.01), Vector3(0.9, 2.1, 0.05), trim)
	_window(unit, Vector3(inner * 0.2, y + 1.7, 0), Vector2(inner * 0.36, 1.15), trim)
	if roll < 0.48:
		_cage(unit, inner, y, tall, tint)
		return
	batch.box("plaster", unit, Vector3(0, y + 0.03, -0.5), Vector3(inner, 0.12, 1.0), tint.darkened(0.15), false)
	batch.box(skin, unit, Vector3(0, y + 0.55, -0.96), Vector3(inner, 0.95, 0.08), tint.darkened(0.06))
	if rng.randf() < 0.35:
		_laundry(unit, inner, y)
	if rng.randf() < 0.3:
		_plants(unit, Vector3(-inner * 0.4, y + 0.1, -0.7), Vector3(inner * 0.4, y + 0.1, -0.7), rng.randi_range(1, 2))

# The "tiger cage": an iron box bolted over the balcony and roofed in tin, used as one more room.
func _cage(unit: Transform3D, inner: float, y: float, tall: float, tint: Color) -> void:
	var out := rng.randf_range(1.0, 1.4)
	var top := y + tall - 0.6
	var half := inner * 0.5
	var iron: Color = IRONWORK[rng.randi() % IRONWORK.size()]
	batch.box("plaster", unit, Vector3(0, y + 0.03, -out * 0.5), Vector3(inner, 0.12, out), tint.darkened(0.15), false)
	_panel("grille", unit, Vector3(0, (y + 0.1 + top) * 0.5, -out), Vector2(inner, top - y - 0.1), iron, Vector2(inner * 2.4, 2.0))
	for side in [-1.0, 1.0]:
		batch.quad("grille", unit * Vector3(side * half, y + 0.1, 0), unit * Vector3(side * half, y + 0.1, -out), unit * Vector3(side * half, top, -out), unit * Vector3(side * half, top, 0), iron, Vector2(out * 2.4, 2.0))
	_sheet("rust_tin" if rng.randf() < 0.5 else "tin", unit * Vector3(-half - 0.1, top - 0.1, -out - 0.25), unit * Vector3(half + 0.1, top - 0.1, -out - 0.25), unit * Vector3(half + 0.1, top + 0.3, 0), unit * Vector3(-half - 0.1, top + 0.3, 0), SHEET)
	# The lower half is often boarded or tarped against the rain.
	if rng.randf() < 0.5:
		var board: String = "tin" if rng.randf() < 0.5 else "paint"
		var tone: Color = SHEET if board == "tin" else AWNINGS[rng.randi() % AWNINGS.size()].lerp(Color(0.6, 0.6, 0.6), 0.4)
		_panel(board, unit, Vector3(0, y + 0.62, -out - 0.02), Vector2(inner, 1.0), tone)
	if rng.randf() < 0.45:
		_laundry(unit, inner, y)
	if rng.randf() < 0.35:
		_plants(unit, Vector3(-inner * 0.4, y + 0.1, -out + 0.25), Vector3(inner * 0.4, y + 0.1, -out + 0.25), rng.randi_range(1, 2))

# The shared stair: a doorway at street level, a screen of vent blocks up the front, and a
# stair head standing above the roof.
func _stairwell(unit: Transform3D, bay_w: float, floors: int, tall: float, skin: String, tint: Color) -> void:
	var height := floors * tall
	var span := bay_w - 1.3
	var shade := Color(0.4, 0.4, 0.4)
	_panel("glass", unit, Vector3(0, 1.25, PORCH - 0.02), Vector2(1.5, 2.5), shade)
	batch.box("concrete", unit, Vector3(0, 0.08, PORCH - 0.5), Vector3(1.9, 0.16, 0.9), Color(0.66, 0.66, 0.64), false)
	for level in range(1, floors):
		var y := level * tall + 1.7
		_panel("glass", unit, Vector3(0, y, -0.01), Vector2(span, 2.3), shade)
		_panel("grille", unit, Vector3(0, y, -0.03), Vector2(span, 2.3), tint.lightened(0.15), Vector2(span * 3.0, 5.0))
	for side in [-1.0, 1.0]:
		batch.box(skin, unit, Vector3(side * (span * 0.5 + 0.2), (tall + height) * 0.5 + 0.9, -0.08), Vector3(0.3, height - tall + 1.8, 0.2), tint.darkened(0.08))
	batch.box(skin, unit, Vector3(0, height + 1.3, 1.7), Vector3(bay_w - 0.3, 2.6, 3.4), tint)

# ---- Behind the streets ----

# Whatever the street rows leave empty is filled, so gaps show more town instead of the void.
func back_blocks() -> void:
	var step := 9.0
	var x := -430.0
	while x < plan.BRIDGE_START - 8.0:
		var z := -300.0
		while z < 300.0:
			_back_cell(Vector2(x + rng.randf_range(-1, 1), z + rng.randf_range(-1, 1)), step)
			z += step
		x += step

func _back_cell(p: Vector2, step: float) -> void:
	var half := step * 0.5
	var inside: bool = p.x > -290.0 and absf(p.y) < 170.0
	if p.x > plan.river_west(p.y) - 5.0:
		return
	var probes := [p, p + Vector2(half, half), p + Vector2(-half, half), p + Vector2(half, -half), p + Vector2(-half, -half)]
	for probe in probes:
		if plan.in_corridor(probe, 0.6):
			return
	var cell := Vector2i(floori(p.x / 24.0), floori(p.y / 24.0))
	var candidate := {"centre": p, "normal": Vector2.RIGHT, "width": step, "depth": step}
	for gx in range(cell.x - 1, cell.x + 2):
		for gy in range(cell.y - 1, cell.y + 2):
			for other in plan.lot_grid.get(Vector2i(gx, gy), []):
				if plan._overlap(candidate, other):
					return
	# A quarter turn at random, so the roofs do not all drain the same way.
	var frame := Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI * 0.5), Vector3(p.x, 0, p.y))
	batch.at(frame.origin)
	# The whole cell is closed to the player even where the building is smaller than it.
	if inside:
		_solid(frame, Vector3(0, 6, 0), Vector3(step, 12, step))
	var streetside: bool = plan.in_corridor(p, step)
	var roll := rng.randf()
	if not streetside:
		# Deep inside a block there is room for a tree, and now and then for something tall.
		if roll < 0.05:
			_add_scatter("tree", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.34, 0.46)), frame.origin))
			return
		if inside and roll < 0.065:
			_tower(frame, step - 1.0)
			return
	# Only a wall on a street is seen close up, so those cells are built out to their edges.
	var size := Vector2(step, step) if streetside else Vector2(rng.randf_range(6.0, step), rng.randf_range(6.5, step))
	var height: float = rng.randi_range(1, 4) * plan.FLOOR + rng.randf_range(0.2, 0.9)
	var skin: String = ["aged", "aged", "plaster", "plaster", "brick", "brick", "yellow", "peel"][rng.randi() % 8]
	var tint: Color = Color.WHITE if skin in ["brick", "yellow"] else FACADES[rng.randi() % FACADES.size()]
	tint = tint.darkened(rng.randf_range(0.02, 0.18))
	batch.box(skin, frame, Vector3(0, height * 0.5, 0), Vector3(size.x, height, size.y), tint)
	var top := rng.randf()
	if top < 0.4:
		_shed(frame, -size * 0.5, size * 0.5, height, rng.randf_range(0.5, 1.0), "tin" if rng.randf() < 0.5 else "rust_tin", SHEET, skin, tint)
	elif top < 0.65:
		_gable(frame, -size * 0.5, size * 0.5, height, size.y * 0.5 * rng.randf_range(0.4, 0.55), true, "roof", TILE.darkened(rng.randf_range(0.0, 0.3)), skin, tint)
	else:
		for turn in range(4):
			var edge := frame * Transform3D(Basis(Vector3.UP, turn * PI * 0.5))
			var run: float = size.x if turn % 2 == 0 else size.y
			var reach: float = size.y if turn % 2 == 0 else size.x
			batch.box(skin, edge, Vector3(0, height + 0.3, -reach * 0.5 + 0.08), Vector3(run, 0.6, 0.16), tint.darkened(0.1))
		if rng.randf() < 0.6:
			_water_tank(frame, Vector3(rng.randf_range(-1.5, 1.5), height + 0.95, rng.randf_range(-1.5, 1.5)))
	if streetside:
		for turn in range(4):
			var face := frame * Transform3D(Basis(Vector3.UP, turn * PI * 0.5)).translated_local(Vector3(0, 0, -half))
			for level in range(int(height / plan.FLOOR)):
				if level > 0 or rng.randf() < 0.5:
					_window(face, Vector3(rng.randf_range(-2.4, 2.4), level * plan.FLOOR + 1.7, 0), Vector2(1.06, 1.16), Color(0.78, 0.76, 0.70), true)

# A mini apartment tower, the one thing that shows over the roofs from every street.
func _tower(frame: Transform3D, size: float) -> void:
	var floors := rng.randi_range(7, 11)
	var height: float = floors * plan.FLOOR
	var skin: String = "mossy" if rng.randf() < 0.4 else "plaster"
	var tint: Color = BLOCKS[rng.randi() % BLOCKS.size()] if skin == "mossy" else MODERN[rng.randi() % MODERN.size()]
	batch.box(skin, frame, Vector3(0, height * 0.5, 0), Vector3(size, height, size), tint)
	for turn in range(4):
		var face := frame * Transform3D(Basis(Vector3.UP, turn * PI * 0.5)).translated_local(Vector3(0, 0, -size * 0.5))
		# The lowest floors are hidden by the neighbours.
		for level in range(2, floors):
			_panel("pane", face, Vector3(0, level * plan.FLOOR + 1.7, -0.02), Vector2(size - 1.6, 1.5))
			batch.box("plaster", face, Vector3(0, level * plan.FLOOR + 0.75, -0.2), Vector3(size - 1.2, 0.1, 0.4), tint.darkened(0.12), false)
	batch.box("concrete", frame, Vector3(0, height + 0.15, 0), Vector3(size + 0.5, 0.3, size + 0.5), CEMENT, false)
	batch.box(skin, frame, Vector3(size * 0.2, height + 1.6, 0), Vector3(3.0, 2.6, 3.0), tint)
	_water_tank(frame, Vector3(-size * 0.25, height + 1.25, 0))
