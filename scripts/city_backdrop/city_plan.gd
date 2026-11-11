extends "res://scripts/town/town_plan.gd"
# The streets round the school, as a town plan: a ring of roads hugging the
# campus wall, a second ring of streets further out and alleys (hẻm) between
# them. Only seen over the wall, so there is no river, bridge or story place;
# the one place is the landmark tower across from the gate.
# Metres, X east, Z south; the school gate faces +Z at z 78.

# Campus wall footprint (x -58..58, z -82..78) plus a little margin.
const CAMPUS := {"centre": Vector2(0, -2), "normal": Vector2(0, 1), "width": 120.0, "depth": 164.0}
# Streets run this far from the school; beyond it only filler blocks and skyline.
const REACH := 260.0
# Proper houses stop here; past it they are specks the filler blocks stand in for.
const LOT_REACH := 200.0
# Probe spacing round a lot's edge for roads; the narrowest alley is ~2.9 m across.
const PROBE := 2.0

static func layout() -> Dictionary:
	var roads: Array = [
		_road("Đường Trước Trường", "main", 12.0, 4.0, [Vector2(-REACH, 90), Vector2(REACH, 90)]),
		_road("Đường Hông Tây", "street", 8.0, 3.0, [Vector2(-70, -REACH), Vector2(-70, REACH)]),
		_road("Đường Hông Đông", "street", 8.0, 3.0, [Vector2(70, -REACH), Vector2(70, REACH)]),
		_road("Đường Sau Trường", "street", 8.0, 3.0, [Vector2(-REACH, -95), Vector2(REACH, -95)]),
		_road("Phố Ngoài Trước", "street", 9.0, 3.0, [Vector2(-REACH, 152), Vector2(REACH, 152)]),
		_road("Phố Ngoài Sau", "street", 8.0, 2.5, [Vector2(-REACH, -160), Vector2(REACH, -160)]),
		_road("Phố Ngoài Tây", "street", 8.0, 2.5, [Vector2(-136, -REACH), Vector2(-136, REACH)]),
		_road("Phố Ngoài Đông", "street", 8.0, 2.5, [Vector2(136, -REACH), Vector2(136, REACH)]),
	]
	# Alleys between the two rings, the narrow lanes most of the city lives on.
	var number := 11
	for x in [-104.0, -40.0, 30.0, 100.0]:
		roads.append(_road("Hẻm %d" % number, "alley", 3.2, 0.0, [Vector2(x, 96), Vector2(x, 147)]))
		roads.append(_road("Hẻm %d" % (number + 1), "alley", 3.2, 0.0, [Vector2(x, -101), Vector2(x, -155)]))
		number += 2
	for z in [-125.0, -40.0, 40.0, 120.0]:
		for side in [-1.0, 1.0]:
			roads.append(_road("Hẻm %d" % number, "alley", 3.2, 0.0, [Vector2(side * 76, z), Vector2(side * 131, z)]))
			number += 1
	# Straight across the main road from the school gate (x 0): the Van Lang
	# University tower, the landmark the gate looks out on.
	var places: Array = [{"id": "vlu", "road": "Đường Trước Trường", "on": Vector2(0, 112), "width": 28.0, "depth": 20.0, "style": "vlu"}]
	return {"roads": roads, "places": places}

static func _road(title: String, kind: String, width: float, walk: float, points: Array) -> Dictionary:
	return {"name": title, "kind": kind, "width": width, "walk": walk, "points": points}

# The backdrop keeps to the tube houses its night materials are tuned for.
func _place_blocks() -> void:
	pass

func _pick_kind(_road_kind: String) -> String:
	return "tube"

# No river out here.
func river_west(_z: float) -> float:
	return INF

func inside_campus(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x - CAMPUS.centre.x) < CAMPUS.width * 0.5 + margin and absf(p.y - CAMPUS.centre.y) < CAMPUS.depth * 0.5 + margin

# Same rules as the town's lots, but bounded by the school instead of the river.
# Cheapest checks first: this runs for every size tried on every lot, and
# building the school's level must not stall on it.
func _free(lot: Dictionary) -> bool:
	if absf(lot.centre.x) > LOT_REACH or absf(lot.centre.y) > LOT_REACH or _overlap(lot, CAMPUS):
		return false
	var cell := Vector2i(floori(lot.centre.x / 24.0), floori(lot.centre.y / 24.0))
	for x in range(cell.x - 2, cell.x + 3):
		for y in range(cell.y - 2, cell.y + 3):
			for other in lot_grid.get(Vector2i(x, y), []):
				if _overlap(lot, other):
					return false
	var edge: Array = corners(lot)
	for i in range(4):
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[(i + 1) % 4]
		var steps := int(a.distance_to(b) / PROBE) + 1
		for n in range(steps + 1):
			if in_corridor(a.lerp(b, float(n) / steps), -0.15):
				return false
	return true
