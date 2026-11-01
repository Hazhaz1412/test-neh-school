extends RefCounted
# The neighbourhood as data; meshes, traffic and the map screen are all generated from this.
# Metres, X east, Z south. West of the river is the dense quarter, east is the salt fields.
const STEP := 2.0
const CELL := 12.0
const BRIDGE_START := 70.0
const BRIDGE_END := 130.0
const BRIDGE_RISE := 3.0
const FIELD_LEVEL := -0.22
const KERB := 0.14
const FLOOR := 3.4
const ROADS := [
	{"name": "Đường Cổ Đằng", "kind": "main", "width": 11.0, "walk": 4.0, "points": [Vector2(-282, 8), Vector2(-200, -2), Vector2(-120, 6), Vector2(-40, -2), Vector2(30, 2), Vector2(70, -2)]},
	{"name": "Cầu Mây", "kind": "bridge", "width": 9.0, "walk": 1.5, "points": [Vector2(70, -2), Vector2(100, -2), Vector2(130, -2)]},
	{"name": "Đường Đồng Muối", "kind": "country", "width": 7.5, "walk": 0.0, "points": [Vector2(130, -2), Vector2(170, 6), Vector2(214, 24), Vector2(262, 26)]},
	{"name": "Phố Chợ", "kind": "street", "width": 8.0, "walk": 3.0, "points": [Vector2(-86, -156), Vector2(-78, -60), Vector2(-82, 4), Vector2(-90, 70), Vector2(-80, 156)]},
	{"name": "Đường Bến Trầu", "kind": "street", "width": 7.0, "walk": 3.0, "points": [Vector2(58, -156), Vector2(66, -80), Vector2(62, -2), Vector2(68, 80), Vector2(58, 156)]},
	{"name": "Phố Lò Than", "kind": "street", "width": 6.5, "walk": 2.0, "points": [Vector2(-226, -92), Vector2(-150, -98), Vector2(-79, -92), Vector2(0, -102), Vector2(66, -94)]},
	{"name": "Phố Hàng Cau", "kind": "street", "width": 6.5, "walk": 2.0, "points": [Vector2(-232, 86), Vector2(-150, 92), Vector2(-90, 86), Vector2(0, 94), Vector2(67, 88)]},
	{"name": "Đường Gò Sậy", "kind": "street", "width": 7.0, "walk": 2.5, "points": [Vector2(-236, -156), Vector2(-226, -92), Vector2(-204, -2), Vector2(-232, 86), Vector2(-224, 156)]},
	{"name": "Hẻm 12", "kind": "alley", "width": 3.2, "walk": 0.0, "points": [Vector2(22, 1), Vector2(24, -36), Vector2(8, -58), Vector2(12, -100)]},
	{"name": "Hẻm 27", "kind": "alley", "width": 3.2, "walk": 0.0, "points": [Vector2(-30, -2), Vector2(-33, 40), Vector2(-18, 60), Vector2(-20, 92)]},
	{"name": "Hẻm 31", "kind": "alley", "width": 3.0, "walk": 0.0, "points": [Vector2(-19, 60), Vector2(20, 56), Vector2(30, 40), Vector2(64, 40)]},
	{"name": "Hẻm 8", "kind": "alley", "width": 3.0, "walk": 0.0, "points": [Vector2(-79, -46), Vector2(-40, -50), Vector2(-24, -38), Vector2(23, -36)]},
	{"name": "Hẻm 5", "kind": "alley", "width": 3.0, "walk": 0.0, "points": [Vector2(-150, -98), Vector2(-152, -52), Vector2(-138, -30), Vector2(-142, 4)]},
	{"name": "Hẻm 40", "kind": "alley", "width": 3.0, "walk": 0.0, "points": [Vector2(-150, 92), Vector2(-146, 44), Vector2(-132, 24), Vector2(-136, 5)]},
]
# Peter's day: the places of the map, ordered from his door outwards.
const PLACES := [
	{"id": "home", "label": "Nhà Peter", "road": "Hẻm 31", "on": Vector2(14, 66), "width": 4.2, "depth": 11.0, "floors": 3, "style": "home", "tint": Color(0.70, 0.82, 0.72)},
	{"id": "shop", "label": "Tạp Hóa Bà Sáu", "road": "Hẻm 27", "on": Vector2(-40, 26), "width": 6.0, "depth": 10.0, "floors": 2, "style": "open", "tint": Color(0.94, 0.86, 0.62), "sign": Color(0.73, 0.14, 0.12)},
	{"id": "post", "label": "Bưu Điện Cổ Đằng", "road": "Đường Cổ Đằng", "on": Vector2(-160, -18), "width": 16.0, "depth": 14.0, "floors": 2, "style": "civic", "tint": Color(0.93, 0.78, 0.40), "sign": Color(0.10, 0.28, 0.55)},
	{"id": "pho", "label": "Phở Tâm Trạng", "road": "Phố Chợ", "on": Vector2(-70, 34), "width": 7.0, "depth": 12.0, "floors": 3, "style": "open", "tint": Color(0.92, 0.92, 0.86), "sign": Color(0.82, 0.32, 0.08)},
	{"id": "cafe", "label": "Cà Phê Bến Sông", "road": "Đường Bến Trầu", "on": Vector2(50, -46), "width": 8.0, "depth": 11.0, "floors": 2, "style": "open", "tint": Color(0.74, 0.86, 0.90), "sign": Color(0.12, 0.34, 0.30)},
	{"id": "stall", "label": "Trà Đá Bác Lực", "road": "Đường Đồng Muối", "on": Vector2(200, 10), "width": 6.0, "depth": 4.5, "floors": 1, "style": "stall", "tint": Color(0.8, 0.8, 0.7)},
	{"id": "curio", "label": "", "road": "Hẻm 5", "on": Vector2(-127, -28), "width": 6.0, "depth": 9.0, "floors": 2, "style": "curio", "hidden": true},
	{"id": "chess", "label": "Góc Cờ", "road": "Đường Bến Trầu", "on": Vector2(52, 26), "width": 6.0, "depth": 4.5, "floors": 1, "style": "stall", "tint": Color(0.8, 0.8, 0.7)},
	{"id": "market", "label": "Chợ Bến Trầu", "road": "Phố Chợ", "on": Vector2(-120, 48), "width": 44.0, "depth": 30.0, "floors": 1, "style": "market", "tint": Color(0.82, 0.80, 0.72)},
]
const SHOPS := ["Cơm Bình Dân", "Bún Riêu Cô Ba", "Sửa Xe Hoàng", "Tiệm Tóc Thu Hà", "Điện Thoại Minh Phát", "Photocopy Hùng", "Thuốc Tây Đức Tâm", "Bánh Mì Bảy Hổ", "Vá Xe 24h", "Hủ Tiếu Năm Lửa", "Nhà Sách Tuổi Xanh", "Trà Đá Chị Tư", "Gas Phú Lộc", "Áo Quần Thúy", "Ốc Cô Hai", "Sim Thẻ Nam Anh", "Karaoke Hồng Ân", "Giặt Ủi Sao Mai", "Nha Khoa Nụ Cười", "Vàng Bạc Kim Thành", "Bia Hơi Bạn Hiền", "Khóa Thợ Lành", "Kính Mắt Sáng", "Đồ Khô Hải Lâm", "Nước Mía Sầu Riêng", "Tiệm May Thanh", "Xôi Bà Lành", "Sơn Nhà Đại Lợi", "Cháo Lòng Cổ Đằng", "Chè Bến Trầu"]
var roads: Array = []
var lots: Array = []
var grid := {}
var lot_grid := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 7171
	for index in range(ROADS.size()):
		roads.append(_sample(ROADS[index], index))
	_place_lots()

func road_named(title: String) -> Dictionary:
	for road in roads:
		if road.name == title:
			return road
	return {}

func _sample(definition: Dictionary, index: int) -> Dictionary:
	var road := definition.duplicate()
	road.index = index
	var points: Array = definition.points
	var path := PackedVector2Array()
	for i in range(points.size() - 1):
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 2, points.size() - 1)]
		var count := maxi(int(points[i].distance_to(points[i + 1]) / STEP), 1)
		for n in range(count):
			path.append(points[i].cubic_interpolate(points[i + 1], before, after, float(n) / count))
	path.append(points[-1])
	road.path = path
	var tangents := PackedVector2Array()
	var along := PackedFloat32Array()
	var length := 0.0
	for i in range(path.size()):
		tangents.append((path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized())
		if i > 0:
			length += path[i].distance_to(path[i - 1])
		along.append(length)
		var key := _cell(path[i])
		if not grid.has(key):
			grid[key] = []
		grid[key].append(Vector2i(index, i))
	road.tangents = tangents
	road.along = along
	road.length = length
	return road

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

# Nearest centre-line sample, or an empty dictionary when no road is within two cells.
func nearest(p: Vector2, skip := -1) -> Dictionary:
	var best := {}
	var best_distance := INF
	var cell := _cell(p)
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for entry in grid.get(Vector2i(x, y), []):
				if entry.x == skip:
					continue
				var distance: float = p.distance_squared_to(roads[entry.x].path[entry.y])
				if distance < best_distance:
					best_distance = distance
					best = {"road": entry.x, "at": entry.y}
	if not best.is_empty():
		best.distance = sqrt(best_distance)
	return best

func in_corridor(p: Vector2, margin: float, skip := -1, kerb_only := false) -> bool:
	var cell := _cell(p)
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			for entry in grid.get(Vector2i(x, y), []):
				if entry.x == skip:
					continue
				var road: Dictionary = roads[entry.x]
				var reach: float = road.width * 0.5 + margin + (0.0 if kerb_only else road.walk)
				if p.distance_squared_to(road.path[entry.y]) < reach * reach:
					return true
	return false

func hump(x: float) -> float:
	if x <= BRIDGE_START or x >= BRIDGE_END:
		return 0.0
	return BRIDGE_RISE * sin(PI * (x - BRIDGE_START) / (BRIDGE_END - BRIDGE_START))

# All walkable ground is analytic, so riders never catch a kerb or fall through a seam.
func ground(p: Vector2) -> float:
	if p.x > BRIDGE_START and p.x < BRIDGE_END:
		return hump(p.x)
	if in_corridor(p, 0.0, -1, true):
		return 0.0
	if p.x >= BRIDGE_END:
		return FIELD_LEVEL
	return KERB if in_corridor(p, 0.0) else 0.0

func river_west(z: float) -> float:
	var road: Dictionary = road_named("Đường Bến Trầu")
	var best := 70.0
	var gap := INF
	for i in range(0, road.path.size(), 4):
		if absf(road.path[i].y - z) < gap:
			gap = absf(road.path[i].y - z)
			best = road.path[i].x
	return best + 6.5

func _place_lots() -> void:
	for place in PLACES:
		var road := road_named(place.road)
		var index := _closest_index(road, place.on)
		var side := signf((place.on - road.path[index]).dot(_normal(road, index)))
		var fit := _lot_on(road, index, side, place.width, place.depth)
		fit.place = place
		_claim(fit)
	for road in roads:
		if road.kind == "bridge":
			continue
		for side in [-1.0, 1.0]:
			_fill_side(road, side)

func _closest_index(road: Dictionary, p: Vector2) -> int:
	var best := 0
	for i in range(road.path.size()):
		if road.path[i].distance_squared_to(p) < road.path[best].distance_squared_to(p):
			best = i
	return best

func _normal(road: Dictionary, index: int) -> Vector2:
	var tangent: Vector2 = road.tangents[index]
	return Vector2(-tangent.y, tangent.x)

func _lot_on(road: Dictionary, index: int, side: float, width: float, depth: float, setback := 0.1) -> Dictionary:
	var normal := _normal(road, index) * side
	var front: Vector2 = road.path[index] + normal * (road.width * 0.5 + road.walk + setback)
	return {"front": front, "centre": front + normal * depth * 0.5, "normal": normal, "width": width, "depth": depth, "road": road.index}

func _fill_side(road: Dictionary, side: float) -> void:
	var at := 0.0
	var country: bool = road.kind == "country"
	while at < road.length:
		var width := rng.randf_range(3.6, 6.4)
		var index := int((at + width * 0.5) / STEP)
		if index >= road.path.size():
			return
		at += width
		if country and (road.path[index].x > 176 or rng.randf() > 0.55):
			at += rng.randf_range(4.0, 14.0)
			continue
		_try_lot(road, index, side, width, country)

func _try_lot(road: Dictionary, index: int, side: float, width: float, country: bool) -> void:
	for setback in [0.1, 0.6, 1.2]:
		for depth in ([9.0] if country else [15.0, 11.0, 7.5, 5.0]):
			var lot := _lot_on(road, index, side, width, depth, setback)
			if _free(lot):
				_claim(lot)
				return

func corners(lot: Dictionary, grow := 0.0) -> Array:
	var normal: Vector2 = lot.normal
	var along: Vector2 = Vector2(-normal.y, normal.x) * (lot.width * 0.5 + grow)
	var back: Vector2 = normal * (lot.depth * 0.5 + grow)
	return [lot.centre - along - back, lot.centre + along - back, lot.centre + along + back, lot.centre - along + back]

func _free(lot: Dictionary) -> bool:
	if lot.centre.x > BRIDGE_START - 12.0 and lot.centre.x < BRIDGE_END + 2.0:
		return false
	var edge: Array = corners(lot)
	for i in range(4):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % 4]
		var steps := int(a.distance_to(b) / 1.5) + 1
		for n in range(steps + 1):
			if in_corridor(a.lerp(b, float(n) / steps), -0.15):
				return false
	if absf(lot.centre.y) > 176 or lot.centre.x < -300:
		return false
	var cell := Vector2i(floori(lot.centre.x / 24.0), floori(lot.centre.y / 24.0))
	for x in range(cell.x - 2, cell.x + 3):
		for y in range(cell.y - 2, cell.y + 3):
			for other in lot_grid.get(Vector2i(x, y), []):
				if _overlap(lot, other):
					return false
	return true

func _overlap(a: Dictionary, b: Dictionary) -> bool:
	# Neighbours on a bend may touch at the back, where nobody sees the seam.
	var first: Array = corners(a, -0.5)
	var second: Array = corners(b, -0.5)
	for axis in [a.normal, Vector2(-a.normal.y, a.normal.x), b.normal, Vector2(-b.normal.y, b.normal.x)]:
		var from_a := _span(first, axis)
		var from_b := _span(second, axis)
		if from_a.y <= from_b.x + 0.02 or from_b.y <= from_a.x + 0.02:
			return false
	return true

func _span(points: Array, axis: Vector2) -> Vector2:
	var low := INF
	var high := -INF
	for p in points:
		low = minf(low, p.dot(axis))
		high = maxf(high, p.dot(axis))
	return Vector2(low, high)

func _claim(lot: Dictionary) -> void:
	lots.append(lot)
	var cell := Vector2i(floori(lot.centre.x / 24.0), floori(lot.centre.y / 24.0))
	if not lot_grid.has(cell):
		lot_grid[cell] = []
	lot_grid[cell].append(lot)

func place_lot(id: String) -> Dictionary:
	for lot in lots:
		if lot.has("place") and lot.place.id == id:
			return lot
	return {}
