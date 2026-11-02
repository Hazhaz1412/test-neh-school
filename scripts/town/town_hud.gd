extends Control
# Day HUD: compass with the current goal, street names, prompts and the paper map.
const MAP_SCALE := 1.32
const ROAD_COLOURS := {"main": Color(1.0, 0.86, 0.48), "street": Color(0.98, 0.95, 0.86), "alley": Color(0.92, 0.88, 0.78), "bridge": Color(1.0, 0.86, 0.48), "country": Color(0.98, 0.95, 0.86)}
var world: Node3D
var clock: Label
var goal: Label
var prompt: Label
var street: Label
var speed: Label
var hint: Label
var fade: ColorRect
var banner: Label
var map_open := false
var street_time := 0.0
var hint_time := 0.0
var shown_hints := {}
var compass_yaw := 0.0
var targets: Array = []

func setup(town: Node3D) -> void:
	world = town
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock = _label(20, Color(0.97, 0.95, 0.88), Vector2(26, 18))
	goal = _label(19, Color(0.97, 0.95, 0.88), Vector2(0, 66))
	goal.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	goal.offset_left = -420
	goal.offset_right = 420
	goal.offset_top = 64
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = _label(22, Color(1.0, 0.92, 0.68), Vector2.ZERO)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -148
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	street = _label(32, Color(0.98, 0.96, 0.90), Vector2.ZERO)
	street.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	street.offset_left = 30
	street.offset_right = 700
	street.offset_top = -82
	speed = _label(34, Color(0.98, 0.96, 0.90), Vector2.ZERO)
	speed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed.offset_left = -240
	speed.offset_right = -30
	speed.offset_top = -82
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint = _label(18, Color(0.90, 0.92, 0.90), Vector2.ZERO)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -520
	hint.offset_right = 520
	hint.offset_top = -104
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade = ColorRect.new()
	fade.color = Color(0.015, 0.016, 0.02, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 30
	add_child(fade)
	banner = _label(44, Color(0.98, 0.95, 0.86), Vector2.ZERO)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -640
	banner.offset_right = 640
	banner.offset_top = -90
	banner.offset_bottom = 90
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.z_index = 31
	preload("res://scripts/horror_type.gd").title(banner)

func _label(size: int, color: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func hint_once(text: String) -> void:
	if shown_hints.has(text):
		return
	shown_hints[text] = true
	show_hint(text)

func show_hint(text: String, seconds := 6.0) -> void:
	hint.text = text
	hint_time = seconds

func announce_street(title: String) -> void:
	street.text = title
	street_time = 3.2

func _process(delta: float) -> void:
	street_time -= delta
	street.modulate.a = clampf(street_time, 0.0, 1.0)
	hint_time -= delta
	hint.modulate.a = clampf(hint_time, 0.0, 1.0)
	var player: CharacterBody3D = world.player
	speed.text = "%d km/h" % int(absf(player.speed) * 3.6) if player.riding() else ""
	compass_yaw = player.heading + player.free_look if player.riding() and not player.first_person else player.look_yaw
	var calm: bool = not map_open and not world.story.talking_now()
	for label in [goal, street, speed, hint, prompt, clock]:
		label.visible = calm
	queue_redraw()

func _draw() -> void:
	if world.story == null or not world.story.playing() or world.story.talking_now():
		return
	if not map_open:
		_draw_compass()
	if map_open:
		_draw_map()

func _draw_compass() -> void:
	var font := get_theme_default_font()
	var width := 620.0
	var left := (size.x - width) * 0.5
	draw_rect(Rect2(left, 22, width, 34), Color(0.02, 0.03, 0.04, 0.42))
	var marks := {0: "B", 90: "T", 180: "N", 270: "Đ"}
	for degrees in range(0, 360, 15):
		var off := angle_difference(-compass_yaw, deg_to_rad(float(degrees)))
		if absf(off) > 1.2:
			continue
		var x := size.x * 0.5 + off / 1.2 * width * 0.5
		if marks.has(degrees):
			draw_string(font, Vector2(x - 6, 46), marks[degrees], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(1, 1, 1, 0.92))
		else:
			draw_line(Vector2(x, 34), Vector2(x, 44), Color(1, 1, 1, 0.45), 1.5)
	for target in targets:
		_draw_target(target, width, font)

func _draw_target(target: Dictionary, width: float, font: Font) -> void:
	var player: Node3D = world.player
	var flat: Vector3 = target.position - player.global_position
	var bearing := atan2(flat.x, -flat.z)
	var off := angle_difference(-compass_yaw, bearing)
	var x := size.x * 0.5 + clampf(off, -1.2, 1.2) / 1.2 * width * 0.5
	var color: Color = target.color
	draw_colored_polygon(PackedVector2Array([Vector2(x, 22), Vector2(x - 8, 11), Vector2(x + 8, 11)]), color)
	draw_string(font, Vector2(x - 40, 74 if target.get("low", false) else 8), target.label, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, color)
	if target.get("distance", false):
		draw_string(font, Vector2(x + 13, 22), "%d m" % int(Vector2(flat.x, flat.z).length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)

func to_map(p: Vector2, centre: Vector2) -> Vector2:
	return centre + (p - Vector2(-10, 0)) * MAP_SCALE

func _draw_map() -> void:
	var centre := size * 0.5
	var panel := Rect2(centre - Vector2(410, 240) * MAP_SCALE, Vector2(820, 480) * MAP_SCALE)
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	draw_rect(panel, Color(0.86, 0.82, 0.70))
	var plan: RefCounted = world.plan
	var bank := PackedVector2Array()
	for z in range(-176, 180, 12):
		bank.append(to_map(Vector2(plan.river_west(float(z)), float(z)), centre))
	bank.append(to_map(Vector2(plan.BRIDGE_END, 176), centre))
	bank.append(to_map(Vector2(plan.BRIDGE_END, -176), centre))
	draw_colored_polygon(bank, Color(0.44, 0.58, 0.60))
	draw_rect(Rect2(to_map(Vector2(plan.BRIDGE_END, -176), centre), Vector2(280, 352) * MAP_SCALE).intersection(panel), Color(0.78, 0.76, 0.70))
	for pass_index in range(2):
		for road in plan.roads:
			var line := PackedVector2Array()
			for i in range(0, road.path.size(), 2):
				line.append(to_map(road.path[i], centre))
			var width := maxf(road.width * 0.72, 3.0)
			if pass_index == 0:
				draw_polyline(line, Color(0.42, 0.37, 0.28), width + 2.5, true)
			else:
				draw_polyline(line, ROAD_COLOURS[road.kind], width, true)
	for road in plan.roads:
		if road.kind in ["alley", "country", "bridge"] or road.name == "Đường Bến Trầu":
			continue
		var middle: Vector2 = road.path[road.path.size() / 6]
		draw_string(font, to_map(middle, centre) + Vector2(6, -9), road.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.26, 0.24, 0.20))
	for place in plan.PLACES:
		if place.get("hidden", false):
			continue
		var at: Vector2 = plan.place_lot(place.id).front
		draw_circle(to_map(at, centre), 5.0, Color(0.16, 0.30, 0.46))
		var label_at: Vector2 = to_map(at, centre) + (Vector2(-46, -12) if place.id == "stall" else Vector2(8, 5))
		draw_string(font, label_at, place.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.10, 0.20, 0.32))
	var school := to_map(Vector2(264, 26), centre)
	draw_circle(school, 6.0, Color(0.48, 0.10, 0.10))
	draw_string(font, school + Vector2(-60, 24), "Trường NEH", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.48, 0.10, 0.10))
	for target in targets:
		var spot := to_map(Vector2(target.position.x, target.position.z), centre)
		draw_circle(spot, 9.0, target.color)
		draw_arc(spot, 13.0, 0.0, TAU, 24, target.color, 2.0)
	var player: Node3D = world.player
	var me := to_map(Vector2(player.global_position.x, player.global_position.z), centre)
	var dir := Vector2(-sin(compass_yaw), -cos(compass_yaw))
	var across := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([me + dir * 13, me - dir * 8 + across * 8, me - dir * 8 - across * 8]), Color(0.78, 0.12, 0.10))
	draw_string(font, panel.position + Vector2(16, panel.size.y - 14), "M · Đóng bản đồ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.26, 0.24, 0.20))
