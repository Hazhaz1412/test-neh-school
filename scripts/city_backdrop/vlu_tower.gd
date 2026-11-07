extends RefCounted
# Van Lang University, campus 1 (45 Nguyễn Khắc Nhu, Q.1), across the road from
# the school gate. Built with the city builder's batch like every other house:
# local frame x across the front, y up, z into the lot, the street at -z.
# Seen from the street, +x is on the viewer's left.
const ORANGE := Color(0.93, 0.40, 0.10)
const GREY := Color(0.70, 0.71, 0.72)
const DARK := Color(0.15, 0.16, 0.17)
const FLOOR := 3.6
const LEVELS := 13 # Above the two-storey podium.
const PODIUM := 7.2
const CROWN := 6.0
const BAY := 2.0
const ENTRANCE := 9.0

var city: RefCounted # city_builder.gd, for its batch, materials and helpers.

func _init(builder: RefCounted) -> void:
	city = builder

func build(lot: Dictionary, frame: Transform3D) -> void:
	var w: float = lot.width
	var d: float = lot.depth
	var top := PODIUM + LEVELS * FLOOR
	var height := top + CROWN
	# Core mass, its front 0.6 m back so the facade layers sit on it, not in it.
	_box("paint", frame, Vector3(0, height * 0.5, 0.6 + (d - 1.0) * 0.5), Vector3(w - 0.4, height, d - 1.0), GREY.darkened(0.3))
	_podium(frame, w)
	for level in range(LEVELS):
		_tower_floor(frame, w, d, PODIUM + level * FLOOR, level)
	_frame_and_crown(frame, w, top)
	_flags(frame, w)
	for x in [-w * 0.5 + 2.5, w * 0.5 - 7.0]:
		city._add_scatter("tree", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.3), frame * Vector3(x, city.plan.KERB, -2.4)))

# Orange-clad base with a lit glass lobby and the university's name over it.
func _podium(frame: Transform3D, w: float) -> void:
	var side := (w - ENTRANCE) * 0.5
	for sign_x in [-1.0, 1.0]:
		_box("paint", frame, Vector3(sign_x * (ENTRANCE * 0.5 + side * 0.5), PODIUM * 0.5, 0.3), Vector3(side, PODIUM, 0.6), ORANGE)
	_box("paint", frame, Vector3(0, (PODIUM + 4.2) * 0.5, 0.3), Vector3(ENTRANCE, PODIUM - 4.2, 0.6), ORANGE)
	_box("lit", frame, Vector3(0, 2.1, 0.55), Vector3(ENTRANCE, 4.2, 0.1), Color(1.0, 0.95, 0.85))
	_box("paint", frame, Vector3(0, 4.25, 0.0), Vector3(ENTRANCE + 0.6, 0.12, 1.2), DARK)
	# Cladding seams.
	var x := -w * 0.5 + 1.8
	while x < w * 0.5:
		if absf(x) > ENTRANCE * 0.5:
			_box("paint", frame, Vector3(x, PODIUM * 0.5, -0.01), Vector3(0.04, PODIUM, 0.02), ORANGE.darkened(0.25))
		x += 1.8
	for y in [2.4, 4.8]:
		_box("paint", frame, Vector3(0, y, -0.01), Vector3(w, 0.04, 0.02), ORANGE.darkened(0.25))
	_logo(frame, Vector3(2.9, 5.7, -0.03), 0.9)
	_label(frame, "Trường Đại học Văn Lang", Vector3(-1.4, 6.0, -0.05), 0.012, Color(1, 1, 1))
	_label(frame, "VAN LANG UNIVERSITY", Vector3(-1.4, 5.35, -0.05), 0.008, Color(1, 1, 1))
	_label(frame, "45 NGUYỄN KHẮC NHU, P. CÔ GIANG, Q.1", Vector3(w * 0.5 - 4.6, 4.6, -0.05), 0.0045, Color(1, 0.96, 0.9))

# One storey: an orange spandrel band, then bays of grey louvre panels and
# dark windows, staggered from floor to floor.
func _tower_floor(frame: Transform3D, w: float, d: float, y: float, level: int) -> void:
	_box("paint", frame, Vector3(0, y + 0.45, 0.3), Vector3(w, 0.9, 0.6), ORANGE)
	var inner := w - 1.6
	var bays := int(inner / BAY)
	var bay := inner / bays
	var window_y := y + 0.9 + 1.35
	for i in range(bays):
		var x := -inner * 0.5 + (i + 0.5) * bay
		if (i + level) % 2 == 0:
			_box("glass", frame, Vector3(x, window_y, 0.56), Vector3(bay - 0.12, 2.6, 0.06), Color(0.55, 0.62, 0.68))
		else:
			_box("paint", frame, Vector3(x, window_y, 0.52), Vector3(bay - 0.06, 2.7, 0.1), GREY)
			for slat in range(6):
				_box("paint", frame, Vector3(x, y + 1.15 + slat * 0.45, 0.38), Vector3(bay - 0.1, 0.07, 0.18), GREY.darkened(0.35))
	# Side walls: a ribbon window per floor.
	for sign_x in [-1.0, 1.0]:
		_box("glass", frame, Vector3(sign_x * (w * 0.5 - 0.18), window_y, d * 0.5), Vector3(0.06, 1.8, d - 3.0), Color(0.55, 0.62, 0.68))

# Orange frame up both corners and over the roof, the dark crown with the logo.
func _frame_and_crown(frame: Transform3D, w: float, top: float) -> void:
	var height := top + CROWN
	for sign_x in [-1.0, 1.0]:
		_box("paint", frame, Vector3(sign_x * (w * 0.5 - 0.4), (PODIUM + height) * 0.5, 0.2), Vector3(0.8, height - PODIUM, 0.7), ORANGE)
	_box("paint", frame, Vector3(0, height + 0.5, 0.2), Vector3(w, 1.0, 0.7), ORANGE)
	_box("paint", frame, Vector3(0, top + CROWN * 0.5, 0.4), Vector3(w - 1.6, CROWN, 0.4), DARK)
	_logo(frame, Vector3(w * 0.5 - 4.4, top + CROWN * 0.5, 0.15), 3.6)
	_label(frame, "VLU", Vector3(w * 0.5 - 10.6, top + CROWN * 0.5, 0.12), 0.05, Color(1, 1, 1))

# The red square mark with a white chevron, lit like the real sign at night.
func _logo(frame: Transform3D, centre: Vector3, size: float) -> void:
	_box("vlu_red", frame, centre, Vector3(size, size, 0.12), Color.WHITE)
	var stroke := Vector3(size * 0.1, size * 0.62, 0.05)
	for sign_x in [-1.0, 1.0]:
		# Each stroke leans out at the top, so the pair meets low in a V.
		var stroke_frame := frame * Transform3D(Basis(Vector3.BACK, -sign_x * 0.42), centre + Vector3(sign_x * size * 0.13, 0, -0.08))
		city.batch.box("lit", stroke_frame, Vector3.ZERO, stroke, Color.WHITE)

# Vietnamese flag, party flag and the university's blue flag on the pavement.
func _flags(frame: Transform3D, w: float) -> void:
	var colours := [Color(0.85, 0.08, 0.06), Color(0.82, 0.06, 0.05), Color(0.10, 0.26, 0.62)]
	for i in range(3):
		var foot := Vector3(-w * 0.5 + 4.0 + i * 1.4, city.plan.KERB, -1.6)
		_box("steel", frame, foot + Vector3(0, 4.5, 0), Vector3(0.07, 9.0, 0.07), Color.WHITE)
		_box("paint", frame, foot + Vector3(-0.75, 8.3, 0), Vector3(1.4, 0.9, 0.03), colours[i])
		if i == 0:
			_box("paint", frame, foot + Vector3(-0.75, 8.3, -0.02), Vector3(0.3, 0.3, 0.02), Color(1.0, 0.85, 0.1))

func _box(material: String, frame: Transform3D, centre: Vector3, size: Vector3, colour: Color) -> void:
	city.batch.box(material, frame, centre, size, colour)

func _label(frame: Transform3D, text: String, at: Vector3, pixel: float, colour: Color) -> void:
	var label := Label3D.new()
	label.font = ThemeDB.fallback_font
	label.text = text
	label.font_size = 96
	label.pixel_size = pixel
	label.modulate = colour
	label.outline_size = 0
	# Unshaded: the sign letters are lit at night.
	label.shaded = false
	label.double_sided = false
	# Labels face +Z; turn them round to read from the street (-Z).
	label.transform = Transform3D(frame.basis * Basis(Vector3.UP, PI), frame * at)
	city.signs_root.add_child(label)
