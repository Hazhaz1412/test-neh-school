extends Control

var world: Node3D
var refresh := 0.0
var ink := Color(0.77, 0.84, 0.81)
var slot_styles: Array[StyleBoxFlat] = []

func _ready() -> void:
	for selected in [false, true]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.045, 0.05, 0.80)
		style.border_color = Color(ink, 0.85 if selected else 0.20)
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(4)
		slot_styles.append(style)

func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0:
		refresh = 0.10
		queue_redraw()

func text_at(value: String, at: Vector2, color := Color(0.77, 0.84, 0.81), font_size := 16) -> void:
	draw_string(get_theme_default_font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func meter(at: Vector2, amount: float, color: Color, width := 100.0) -> void:
	draw_rect(Rect2(at, Vector2(width, 3)), Color(0.08, 0.12, 0.14, 0.8))
	draw_rect(Rect2(at, Vector2(width * clampf(amount / 100, 0, 1), 3)), color)

func _draw() -> void:
	if world == null or world.survival.opening.playing:
		return
	var p: CharacterBody3D = world.player
	var width := get_viewport_rect().size.x
	var height := get_viewport_rect().size.y
	text_at(world.survival.clock_text() if world.survival.active else "22:30", Vector2(width - 110, 40), ink, 22)
	for i in range(world.journal.entries.size()):
		var center := Vector2(width - 110 + i * 21, 63)
		var diamond := PackedVector2Array([center + Vector2(0, -5), center + Vector2(5, 0), center + Vector2(0, 5), center + Vector2(-5, 0)])
		var found: bool = world.journal.found.has(i)
		if found:
			draw_colored_polygon(diamond, Color(0.52, 0.79, 0.81))
		else:
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(ink, 0.4), 1)
	if world.has_master_key:
		draw_arc(Vector2(width - 137, 61), 4, 0, TAU, 12, ink, 1.5)
		draw_line(Vector2(width - 133, 61), Vector2(width - 124, 61), ink, 1.5)
		draw_line(Vector2(width - 126, 61), Vector2(width - 126, 65), ink, 1.5)
	# Health is always legible. Other gauges appear only when they matter.
	text_at("♥", Vector2(30, height - 36), Color(0.76, 0.47, 0.43), 20)
	meter(Vector2(60, height - 42), p.health, Color(0.68, 0.76, 0.67), 105)
	var stamina_percent: float = p.stamina / p.max_stamina * 100
	if stamina_percent < 97 or world.progression.runner.active:
		meter(Vector2(60, height - 31), stamina_percent, Color(0.45, 0.60, 0.60), 105)
	# Fatigue: how much slower the next breath comes back while he is on your heels.
	if p.fatigue > 0.02:
		meter(Vector2(60, height - 26), p.fatigue * 100.0, Color(0.86, 0.55, 0.25), 105)
		text_at("MỆT", Vector2(170, height - 22), Color(0.86, 0.55, 0.25, 0.85), 11)
	var crank: bool = p.selected_item() == "crank"
	var charge: float = p.crank_charge if crank else p.battery
	if crank or p.flashlight.visible or p.selected_item() == "camera" or p.selected_item() == "battery" or p.battery < 20:
		var at := Vector2(width - 130, height - 44)
		draw_rect(Rect2(at, Vector2(26, 12)), ink, false, 1)
		draw_rect(Rect2(at + Vector2(26, 4), Vector2(3, 4)), ink)
		draw_rect(Rect2(at + Vector2(3, 3), Vector2(20 * charge / 100, 6)), ink)
		text_at(str(int(charge)), at + Vector2(38, 12))
	if p.is_hidden():
		meter(Vector2(width / 2 - 45, height - 91), p.breath, Color(0.46, 0.69, 0.78), 90)
	if p.fear > 35:
		meter(Vector2(60, height - 20), p.fear, Color(0.63, 0.28, 0.25), 105)
	if world.survival.hunt_remaining > 0:
		draw_circle(Vector2(width - 148, 33), 3 + sin(world.elapsed * 6), Color(0.8, 0.25, 0.2))
	if p.is_hidden():
		text_at("SPACE", Vector2(width / 2 - 24, height - 101), Color(ink, 0.6), 12)
	if not world.survival.finished:
		text_at("J", Vector2(30, 40), Color(ink, 0.65), 13)
		if world.test_cheats.used_this_run:
			text_at("TEST · ON" if world.test_cheats.enabled else "TEST · OFF", Vector2(56, 40), Color(0.91, 0.73, 0.40), 12)
		# Looking through the viewfinder: the bag stays out of the frame.
		if p.camera_aiming and p.held_visual.camera_raised():
			return
		# Six physical slots, compact icons, one label for the selected item.
		var start := Vector2(width / 2 - 171, height - 66)
		for i in range(p.BAG_SIZE):
			var at := start + Vector2(i * 58, 0)
			var selected: bool = i == p.selected_slot
			draw_style_box(slot_styles[1 if selected else 0], Rect2(at, Vector2(52, 45)))
			text_at(str(i + 1), at + Vector2(5, 12), Color(ink, 0.75), 11)
			_draw_item(p.inventory[i], at + Vector2(26, 27), ink if selected else Color(ink, 0.55))
			if p.inventory[i] == "camera" and world.camera_flash.cooldown > 0:
				meter(at + Vector2(5, 40), 100 * (1 - world.camera_flash.cooldown / world.camera_shot_cooldown), ink, 42)
		var kind: String = p.selected_item()
		if not kind.is_empty():
			var name_text: String = p.ITEM_NAMES[kind]
			if kind == "camera":
				name_text += " · 20%"
			elif kind == "crank":
				name_text += " · chuột phải để bấm sạc"
			elif kind == "chalk":
				name_text += " · giữ / thả"
			text_at(name_text, start + Vector2(0, -9), ink, 13)
		if p.chalk_charging:
			meter(Vector2(width / 2 - 55, height - 139), p.chalk_charge_fraction() * 100, Color(0.82, 0.77, 0.52), 110)
			text_at("×%.1f" % lerpf(1, p.CHALK_MAX_RANGE_MULTIPLIER, p.chalk_charge_fraction()), Vector2(width / 2 - 15, height - 149), ink, 13)

func _draw_item(kind: String, at: Vector2, color: Color) -> void:
	match kind:
		"camera":
			draw_rect(Rect2(at - Vector2(13, 8), Vector2(26, 16)), color, false, 1.5)
			draw_arc(at, 5, 0, TAU, 20, color, 1.5)
			draw_rect(Rect2(at + Vector2(-4, -12), Vector2(9, 4)), color)
		"torch":
			draw_rect(Rect2(at + Vector2(-3, -6), Vector2(6, 16)), color, false, 1.5)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -11), at + Vector2(6, -11), at + Vector2(3, -5), at + Vector2(-3, -5)]), color)
		"crank":
			draw_rect(Rect2(at + Vector2(-6, -8), Vector2(12, 18)), color, false, 1.5)
			draw_arc(at + Vector2(9, 1), 6, -1.4, 1.4, 10, color, 1.5)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -12), at + Vector2(8, -12), at + Vector2(5, -8), at + Vector2(-5, -8)]), color)
		"battery":
			draw_rect(Rect2(at - Vector2(7, 10), Vector2(14, 20)), color, false, 1.5)
			draw_rect(Rect2(at + Vector2(-3, -13), Vector2(6, 3)), color)
			draw_line(at - Vector2(3, 3), at + Vector2(3, -3), color, 1.5)
			draw_line(at - Vector2(0, 6), at, color, 1.5)
		"medicine":
			draw_rect(Rect2(at - Vector2(11, 9), Vector2(22, 18)), color, false, 1.5)
			draw_rect(Rect2(at - Vector2(2, 6), Vector2(4, 12)), color)
			draw_rect(Rect2(at - Vector2(6, 2), Vector2(12, 4)), color)
		"chalk":
			draw_line(at + Vector2(-7, 8), at + Vector2(7, -8), color, 6)
		"medal":
			draw_arc(at + Vector2(0, 3), 7, 0, TAU, 20, color, 2)
			draw_line(at + Vector2(-5, -12), at + Vector2(0, -4), color, 2)
			draw_line(at + Vector2(5, -12), at + Vector2(0, -4), color, 2)
