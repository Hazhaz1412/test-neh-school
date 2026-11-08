extends RefCounted
# Shared look of Peter's phone: rounded boxes, text, and app icons drawn by hand.
# The icons only echo a modern phone's home screen; no real brand artwork is used.
const INK := Color(0.07, 0.07, 0.08)
const GREY := Color(0.54, 0.55, 0.58)
const LINE := Color(0.86, 0.86, 0.88)
static var _bold: FontVariation

static func box(colour: Color, radius := 0, border := 0, edge := Color.BLACK) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = edge
	style.anti_aliasing_size = 0.8
	return style

static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold

static func text(content: String, size_px: int, colour: Color, parent: Node = null, heavy := false) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	if heavy:
		label.add_theme_font_override("font", bold_font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(label)
	return label

static func wrapped(content: String, size_px: int, colour: Color, parent: Node, width: float, heavy := false) -> Label:
	var label := text(content, size_px, colour, parent, heavy)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label

# A flat button whose look is fully given by the caller's children.
static func plain_button(parent: Node) -> Button:
	var button := Button.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	parent.add_child(button)
	return button

static func avatar(colour: Color, initial: String, diameter: int) -> PanelContainer:
	var circle := PanelContainer.new()
	circle.custom_minimum_size = Vector2.ONE * diameter
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_theme_stylebox_override("panel", box(colour, diameter / 2))
	var letter := text(initial, int(diameter * 0.42), Color.WHITE, circle, true)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return circle

# A red count in the corner of an app icon or a row.
static func badge(count: int, colour := Color(1.0, 0.23, 0.19)) -> PanelContainer:
	var dot := PanelContainer.new()
	var style := box(colour, 11)
	style.content_margin_left = 6
	style.content_margin_right = 6
	dot.add_theme_stylebox_override("panel", style)
	dot.custom_minimum_size = Vector2(22, 22)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := text(str(count), 13, Color.WHITE, dot, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return dot

class Icon extends Control:
	var kind := ""

	func _init(icon_kind: String, side: float) -> void:
		kind = icon_kind
		custom_minimum_size = Vector2.ONE * side
		size = custom_minimum_size
		pivot_offset = custom_minimum_size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size.x
		var c := Vector2.ONE * s * 0.5
		var background := {"fake": Color(0.23, 0.35, 0.85), "tili": Color(0.16, 0.62, 0.92), "phone": Color(0.20, 0.78, 0.35),
			"camera": Color(0.62, 0.64, 0.67), "photos": Color.WHITE, "clock": Color(0.05, 0.05, 0.06), "weather": Color(0.27, 0.56, 0.95),
			"maps": Color(0.93, 0.91, 0.84), "notes": Color.WHITE, "music": Color(0.98, 0.25, 0.38), "settings": Color(0.56, 0.57, 0.61),
			"calendar": Color.WHITE}
		draw_style_box(_square(background.get(kind, Color.GRAY), int(s * 0.225)), Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		match kind:
			"fake":
				_word("fake", s * 0.30, Color.WHITE, s * 0.6)
			"tili":
				# A speech bubble with a tail: the chat app's own mark.
				draw_circle(c + Vector2(0, -s * 0.03), s * 0.27, Color.WHITE)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.1), c + Vector2(-s * 0.3, s * 0.3), c + Vector2(-s * 0.02, s * 0.2)]), Color.WHITE)
				for dx in [-0.11, 0.0, 0.11]:
					draw_circle(c + Vector2(s * dx, -s * 0.03), s * 0.04, background.tili)
			"phone":
				draw_arc(Vector2(s * 0.62, s * 0.38), s * 0.27, deg_to_rad(95), deg_to_rad(178), 16, Color.WHITE, s * 0.13, true)
				draw_circle(Vector2(s * 0.355, s * 0.40), s * 0.085, Color.WHITE)
				draw_circle(Vector2(s * 0.60, s * 0.655), s * 0.085, Color.WHITE)
			"camera":
				draw_style_box(_square(Color(0.17, 0.17, 0.19), int(s * 0.08)), Rect2(s * 0.18, s * 0.32, s * 0.64, s * 0.44))
				draw_circle(c + Vector2(0, s * 0.04), s * 0.15, Color(0.85, 0.86, 0.88))
				draw_circle(c + Vector2(0, s * 0.04), s * 0.10, Color(0.2, 0.24, 0.33))
			"photos":
				var petals := [Color(0.99, 0.62, 0.15), Color(0.98, 0.83, 0.2), Color(0.55, 0.82, 0.3), Color(0.25, 0.68, 0.9), Color(0.55, 0.4, 0.9), Color(0.95, 0.35, 0.45)]
				for i in range(petals.size()):
					draw_circle(c + Vector2.from_angle(TAU * i / petals.size()) * s * 0.17, s * 0.14, Color(petals[i], 0.85))
			"clock":
				draw_circle(c, s * 0.4, Color.WHITE)
				draw_line(c, c + Vector2(s * 0.15, -s * 0.13), Color.BLACK, s * 0.05, true)
				draw_line(c, c + Vector2(-s * 0.04, -s * 0.28), Color.BLACK, s * 0.04, true)
				draw_line(c, c + Vector2(-s * 0.2, s * 0.22), Color(0.95, 0.5, 0.1), s * 0.02, true)
			"weather":
				draw_circle(Vector2(s * 0.38, s * 0.38), s * 0.17, Color(1.0, 0.85, 0.2))
				for blob in [[0.48, 0.62, 0.15], [0.66, 0.6, 0.12], [0.34, 0.66, 0.1]]:
					draw_circle(Vector2(s * blob[0], s * blob[1]), s * blob[2], Color.WHITE)
				draw_rect(Rect2(s * 0.34, s * 0.62, s * 0.34, s * 0.12), Color.WHITE)
			"maps":
				draw_rect(Rect2(0, 0, s * 0.45, s * 0.4), Color(0.6, 0.82, 0.5))
				draw_line(Vector2(s * 0.1, s * 0.95), Vector2(s * 0.95, s * 0.15), Color(0.98, 0.78, 0.3), s * 0.14)
				draw_circle(Vector2(s * 0.62, s * 0.5), s * 0.1, Color(0.95, 0.27, 0.25))
			"notes":
				draw_rect(Rect2(0, 0, s, s * 0.26), Color(0.99, 0.8, 0.2))
				for row in range(3):
					draw_line(Vector2(s * 0.16, s * (0.45 + row * 0.15)), Vector2(s * 0.84, s * (0.45 + row * 0.15)), Color(0.82, 0.82, 0.84), s * 0.03)
			"music":
				draw_circle(Vector2(s * 0.40, s * 0.68), s * 0.1, Color.WHITE)
				draw_line(Vector2(s * 0.48, s * 0.68), Vector2(s * 0.48, s * 0.26), Color.WHITE, s * 0.05)
				draw_line(Vector2(s * 0.48, s * 0.27), Vector2(s * 0.68, s * 0.34), Color.WHITE, s * 0.07)
			"settings":
				for i in range(8):
					var way := Vector2.from_angle(TAU * i / 8.0)
					draw_line(c + way * s * 0.2, c + way * s * 0.36, Color(0.27, 0.28, 0.31), s * 0.1)
				draw_circle(c, s * 0.26, Color(0.27, 0.28, 0.31))
				draw_circle(c, s * 0.12, background.settings)
			"calendar":
				draw_string(font, Vector2(0, s * 0.3), "THỨ SÁU", HORIZONTAL_ALIGNMENT_CENTER, s, int(s * 0.15), Color(0.95, 0.25, 0.2))
				draw_string(_heavy(), Vector2(0, s * 0.8), "14", HORIZONTAL_ALIGNMENT_CENTER, s, int(s * 0.48), Color(0.1, 0.1, 0.1))

	static var _heavy_font: FontVariation

	static func _heavy() -> Font:
		if _heavy_font == null:
			_heavy_font = FontVariation.new()
			_heavy_font.base_font = ThemeDB.fallback_font
			_heavy_font.variation_embolden = 0.9
		return _heavy_font

	static func _square(colour: Color, radius: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = colour
		style.set_corner_radius_all(radius)
		style.anti_aliasing_size = 0.8
		return style

	func _word(word: String, size_px: float, colour: Color, baseline: float) -> void:
		draw_string(_heavy(), Vector2(0, baseline), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size_px), colour)
