@tool
extends RefCounted
# The neighbourhood as data, read from the Layout node of town.tscn; meshes, traffic and the map
# screen are all generated from this.
# Metres, X east, Z south. West of the river is the dense quarter, east is the salt fields.
const STEP := 2.0
const CELL := 12.0
const BRIDGE_START := 70.0
const BRIDGE_END := 130.0
const BRIDGE_RISE := 3.0
const FIELD_LEVEL := -0.22
const KERB := 0.14
const FLOOR := 3.4
# What lines each kind of street: weights for tube house, modern town house, single-storey cottage.
const KINDS := ["tube", "modern", "cottage"]
const MIX := {"main": [0.50, 0.42, 0.08], "street": [0.52, 0.26, 0.22], "alley": [0.45, 0.10, 0.45], "country": [0.15, 0.0, 0.85]}
const WIDTHS := {"tube": Vector2(3.6, 6.4), "modern": Vector2(4.6, 8.0), "cottage": Vector2(6.0, 9.5)}
const DEPTHS := {"tube": [15.0, 11.0, 7.5, 5.0], "modern": [15.0, 11.0, 7.5, 5.0], "cottage": [13.0, 10.0, 7.5, 5.0]}
const SHOPS := ["Cơm Bình Dân", "Bún Riêu Cô Ba", "Sửa Xe Hoàng", "Tiệm Tóc Thu Hà", "Điện Thoại Minh Phát", "Photocopy Hùng", "Thuốc Tây Đức Tâm", "Bánh Mì Bảy Hổ", "Vá Xe 24h", "Hủ Tiếu Năm Lửa", "Nhà Sách Tuổi Xanh", "Trà Đá Chị Tư", "Gas Phú Lộc", "Áo Quần Thúy", "Ốc Cô Hai", "Sim Thẻ Nam Anh", "Karaoke Hồng Ân", "Giặt Ủi Sao Mai", "Nha Khoa Nụ Cười", "Vàng Bạc Kim Thành", "Bia Hơi Bạn Hiền", "Khóa Thợ Lành", "Kính Mắt Sáng", "Đồ Khô Hải Lâm", "Nước Mía Sầu Riêng", "Tiệm May Thanh", "Xôi Bà Lành", "Sơn Nhà Đại Lợi", "Cháo Lòng Cổ Đằng", "Chè Bến Trầu"]
var roads: Array = []
var places: Array = []
var lots: Array = []
var grid := {}
var lot_grid := {}
var rng := RandomNumberGenerator.new()

func _init(layout: Dictionary) -> void:
	rng.seed = 7171
	places = layout.places
	for index in range(layout.roads.size()):
		roads.append(_sample(layout.roads[index], index))
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
	for place in places:
		var road: Dictionary = road_named(place.road) if place.road != "" else roads[nearest_road(place.on)]
		var index := _closest_index(road, place.on)
		var side := signf((place.on - road.path[index]).dot(_normal(road, index)))
		var fit := _lot_on(road, index, side, place.width, place.depth)
		fit.place = place
		# Named places are written against the tube house, whatever stands around them.
		fit.kind = "tube"
		_claim(fit)
	_place_blocks()
	for road in roads:
		if road.kind == "bridge":
			continue
		for side in [-1.0, 1.0]:
			_fill_side(road, side)

# Old collective housing takes a whole stretch of street, so it is fitted before the single houses.
func _place_blocks() -> void:
	for road in roads:
		if road.kind not in ["main", "street"]:
			continue
		for side in [-1.0, 1.0]:
			var at := rng.randf_range(15.0, 140.0)
			while at < road.length - 20.0:
				var width := rng.randf_range(21.0, 30.0)
				if _try_block(road, int(at / STEP), side, width):
					at += width + rng.randf_range(160.0, 260.0)
				else:
					at += 8.0

# A long front only fits a bend when it stands back from the kerb, which leaves a forecourt.
func _try_block(road: Dictionary, index: int, side: float, width: float) -> bool:
	if index >= road.path.size():
		return false
	for setback in [0.1, 1.5, 3.0]:
		var lot := _lot_on(road, index, side, width, 10.5, setback)
		lot.kind = "block"
		if _free(lot):
			_claim(lot)
			return true
	return false

func nearest_road(p: Vector2) -> int:
	var best := 0
	var gap := INF
	for road in roads:
		var here: float = road.path[_closest_index(road, p)].distance_squared_to(p)
		if here < gap:
			gap = here
			best = road.index
	return best

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
	var kind := "tube"
	while at < road.length:
		# Neighbours often match: a run of cottages, two new builds side by side.
		if rng.randf() > 0.3:
			kind = _pick_kind(road.kind)
		var width := rng.randf_range(WIDTHS[kind].x, WIDTHS[kind].y)
		var index := int((at + width * 0.5) / STEP)
		if index >= road.path.size():
			return
		at += width
		if country and (road.path[index].x > 176 or rng.randf() > 0.55):
			at += rng.randf_range(4.0, 14.0)
			continue
		_try_lot(road, index, side, width, kind)

func _pick_kind(road_kind: String) -> String:
	var weights: Array = MIX.get(road_kind, MIX.street)
	var roll := rng.randf()
	for i in range(KINDS.size()):
		roll -= weights[i]
		if roll < 0.0:
			return KINDS[i]
	return KINDS[0]

func _try_lot(road: Dictionary, index: int, side: float, width: float, kind: String) -> void:
	for setback in [0.1, 0.6, 1.2]:
		for depth in ([10.0] if road.kind == "country" else DEPTHS[kind]):
			var lot := _lot_on(road, index, side, width, depth, setback)
			lot.kind = kind
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
