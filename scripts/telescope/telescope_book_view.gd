extends Control
# Astronomy Guidebook (`books.glb`) — Multi-Page 12-Constellation Star Atlas.
# Each individual page is divided vertically into two sections:
#   - TOP HALF: Large star chart & representative animal figure of that constellation
#     with Bayer Greek symbols (alpha, beta, gamma...) and its 2-digit astronomical code.
#   - BOTTOM HALF: Detailed information about that constellation (Representative animal,
#     2-digit safe code, primary stars alpha/beta/gamma for filtering out decoy stars, and lore).

signal open_telescope_requested
signal closed

const DomeProjection := preload("res://scripts/telescope/dome_projection.gd")

var close_callback: Callable
var open_telescope_callback: Callable
var current_spread := 2 # Starts at Spread 2 (Pages 5-6: Leo [59] & Virgo [63]) so player immediately sees a key constellation, with full 1..6 navigation.
var left_page_box: VBoxContainer
var right_page_box: VBoxContainer
var page_indicator_label: Label
var spread_buttons: Array[Button] = []

class SingleConstellationChart extends Control:
	var entry: Dictionary = {}

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		# Deep celestial navy card for the top half of the page.
		draw_rect(rect, Color(0.04, 0.08, 0.14, 0.98), true)
		draw_rect(rect, Color(0.66, 0.52, 0.28, 0.95), false, 2.0)

		var chart_center := size * 0.5 + Vector2(0.0, 10.0)
		var max_r := minf(size.x, size.y) * 0.40
		# Subtle celestial coordinate rings & crosshair inside the chart.
		var grid_col := Color(0.28, 0.62, 0.52, 0.18)
		draw_arc(chart_center, max_r * 0.55, 0.0, TAU, 48, grid_col, 1.0, true)
		draw_arc(chart_center, max_r * 0.95, 0.0, TAU, 64, grid_col, 1.2, true)
		draw_line(chart_center - Vector2(max_r, 0), chart_center + Vector2(max_r, 0), grid_col, 1.0)
		draw_line(chart_center - Vector2(0, max_r), chart_center + Vector2(0, max_r), grid_col, 1.0)

		if entry.is_empty():
			return

		var font := ThemeDB.fallback_font
		if font != null:
			var header_str := "HÌNH CHÒM SAO: %s" % str(entry.name).to_upper()
			var code_str := "MÃ SỐ: %s" % str(entry.code)
			draw_string(font, Vector2(12, 22), header_str, HORIZONTAL_ALIGNMENT_LEFT, size.x - 130.0, 14, Color(0.96, 0.90, 0.72))
			draw_string(font, Vector2(size.x - 108.0, 22), code_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.42, 0.98, 0.68))
			draw_string(font, Vector2(12, size.y - 10.0), "Linh vật: %s" % str(entry.get("animal_name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.98, 0.84, 0.44, 0.92))

		var scale_xy := Vector2((size.x - 80.0) / 0.21, (size.y - 68.0) / 0.18)

		# 1. Draw the representative animal figure behind the constellation stars.
		DomeProjection.draw_constellation_animal(self, str(entry.id), chart_center, scale_xy, 0.88)

		# 2. Project & draw real constellation edges and stars with (alpha, beta, gamma) labels.
		var stars: Array = entry.get("stars", [])
		var pts := PackedVector2Array()
		pts.resize(stars.size())
		for i in range(stars.size()):
			var st: Dictionary = stars[i]
			pts[i] = chart_center + Vector2(float(st.da) * scale_xy.x, -float(st.dd) * scale_xy.y)

		var edges: Array = entry.get("edges", [])
		for edge in edges:
			var u: int = edge[0]
			var v: int = edge[1]
			if u >= 0 and u < pts.size() and v >= 0 and v < pts.size():
				draw_line(pts[u], pts[v], Color(0.38, 0.95, 0.72, 0.30), 6.0, true)
				draw_line(pts[u], pts[v], Color(0.52, 0.98, 0.78, 0.92), 2.2, true)

		for i in range(pts.size()):
			var p := pts[i]
			var st: Dictionary = stars[i]
			var sym := str(st.get("symbol", ""))
			draw_circle(p, 7.5, Color(0.42, 0.96, 0.74, 0.34))
			draw_circle(p, 3.8, Color(1.0, 0.97, 0.82, 0.98))
			if font != null and sym != "":
				draw_string(font, p + Vector2(6, -4), "%s (%s)" % [sym, str(st.name).split(" ")[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.90, 0.46))

func setup(on_close: Callable, on_open_telescope: Callable = Callable()) -> void:
	close_callback = on_close
	open_telescope_callback = on_open_telescope
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	show_spread(current_spread)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.025, 0.04, 0.86)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Outer leather book cover.
	var cover := PanelContainer.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cover.custom_minimum_size = Vector2(1160, 680)
	cover.offset_left = -580
	cover.offset_right = 580
	cover.offset_top = -340
	cover.offset_bottom = 340
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color(0.18, 0.11, 0.07, 1.0)
	cover_style.border_color = Color(0.68, 0.53, 0.28, 1.0)
	cover_style.set_border_width_all(3)
	cover_style.set_corner_radius_all(10)
	cover_style.content_margin_left = 14
	cover_style.content_margin_right = 14
	cover_style.content_margin_top = 10
	cover_style.content_margin_bottom = 10
	cover.add_theme_stylebox_override("panel", cover_style)
	add_child(cover)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	cover.add_child(outer_vbox)

	# Top spread navigation bar (quick jump across all 12 constellations / 6 spreads).
	var nav_bar := HBoxContainer.new()
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(nav_bar)

	var prev_btn := _nav_button("◀ Trang trước", func(): show_spread(current_spread - 1))
	nav_bar.add_child(prev_btn)

	spread_buttons.clear()
	var spread_titles := [
		"1–2: Bạch Dương · Kim Ngưu",
		"3–4: Song Tử · Cự Giải",
		"5–6: Sư Tử (59) · Xử Nữ",
		"7–8: Thiên Bình · Thiên Yết (84)",
		"9–10: Nhân Mã · Ma Kết",
		"11–12: Bảo Bình (18) · Song Ngư"
	]
	for s_idx in range(spread_titles.size()):
		var sb := _nav_button(spread_titles[s_idx], show_spread.bind(s_idx))
		nav_bar.add_child(sb)
		spread_buttons.append(sb)

	var next_btn := _nav_button("Trang sau ▶", func(): show_spread(current_spread + 1))
	nav_bar.add_child(next_btn)

	# Open two-page spread.
	var spread := HBoxContainer.new()
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(spread)

	left_page_box = _create_page(spread)
	var spine := ColorRect.new()
	spine.custom_minimum_size = Vector2(6, 0)
	spine.color = Color(0.28, 0.18, 0.11, 0.9)
	spread.add_child(spine)
	right_page_box = _create_page(spread)

	# Bottom action bar.
	var bottom_bar := HBoxContainer.new()
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 18)
	outer_vbox.add_child(bottom_bar)

	page_indicator_label = Label.new()
	page_indicator_label.add_theme_font_size_override("font_size", 14)
	page_indicator_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	bottom_bar.add_child(page_indicator_label)

	if open_telescope_callback.is_valid():
		var look_btn := _styled_button("🔭 Nhìn vào Kính Thiên Văn ngay", Color(0.12, 0.38, 0.26), Color(0.92, 0.98, 0.88))
		look_btn.pressed.connect(_on_open_telescope)
		bottom_bar.add_child(look_btn)

	var close_btn := _styled_button("Đóng sách · Esc", Color(0.32, 0.20, 0.14), Color(0.95, 0.90, 0.80))
	close_btn.pressed.connect(close_book)
	bottom_bar.add_child(close_btn)

func _create_page(parent: Control) -> VBoxContainer:
	var page_panel := PanelContainer.new()
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page_style := StyleBoxFlat.new()
	page_style.bg_color = Color(0.94, 0.90, 0.80, 1.0)
	page_style.border_color = Color(0.72, 0.62, 0.45, 1.0)
	page_style.set_border_width_all(2)
	page_style.set_corner_radius_all(6)
	page_style.content_margin_left = 14
	page_style.content_margin_right = 14
	page_style.content_margin_top = 10
	page_style.content_margin_bottom = 10
	page_panel.add_theme_stylebox_override("panel", page_style)
	parent.add_child(page_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	page_panel.add_child(vbox)
	return vbox

func show_spread(spread_idx: int) -> void:
	var total_spreads := DomeProjection.ZODIAC_ATLAS.size() / 2
	current_spread = posmod(spread_idx, total_spreads)
	var left_idx := current_spread * 2
	var right_idx := current_spread * 2 + 1

	_populate_constellation_page(left_page_box, DomeProjection.ZODIAC_ATLAS[left_idx], left_idx + 1)
	_populate_constellation_page(right_page_box, DomeProjection.ZODIAC_ATLAS[right_idx], right_idx + 1)

	if page_indicator_label != null:
		page_indicator_label.text = "Trang %d–%d / 12 Cung Sao (Dùng ◀ / ▶ hoặc phím A / D để lật trang)" % [left_idx + 1, right_idx + 1]

	for i in range(spread_buttons.size()):
		spread_buttons[i].modulate = Color(1.0, 0.95, 0.72) if i == current_spread else Color(0.78, 0.78, 0.78)

# Populates a single page so the TOP HALF is the constellation & animal diagram
# and the BOTTOM HALF is the detailed information about that constellation.
func _populate_constellation_page(page: VBoxContainer, entry: Dictionary, page_number: int) -> void:
	for child in page.get_children():
		child.queue_free()

	# --- TOP HALF: HÌNH CHÒM SAO & LINH VẬT ĐẠI DIỆN ---
	var top_caption := Label.new()
	top_caption.text = "TRANG %d · CUNG %s — MÃ SỐ THIÊN VĂN: %s" % [page_number, str(entry.name).to_upper(), str(entry.code)]
	top_caption.add_theme_font_size_override("font_size", 15)
	top_caption.add_theme_color_override("font_color", Color(0.36, 0.16, 0.06))
	page.add_child(top_caption)

	var chart := SingleConstellationChart.new()
	chart.entry = entry
	chart.custom_minimum_size = Vector2(510, 275)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(chart)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.68, 0.52, 0.28, 0.8)
	page.add_child(divider)

	# --- BOTTOM HALF: THÔNG TIN VỀ CHÒM SAO ---
	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var istyle := StyleBoxFlat.new()
	istyle.bg_color = Color(0.89, 0.84, 0.72, 1.0)
	istyle.border_color = Color(0.68, 0.54, 0.34, 0.9)
	istyle.set_border_width_all(1)
	istyle.set_corner_radius_all(5)
	istyle.content_margin_left = 12
	istyle.content_margin_right = 12
	istyle.content_margin_top = 8
	istyle.content_margin_bottom = 8
	info_panel.add_theme_stylebox_override("panel", istyle)
	page.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_vbox)

	var info_header := Label.new()
	info_header.text = "THÔNG TIN CHÒM SAO & CÁCH NHẬN DIỆN SAO THẬT (V_real)"
	info_header.add_theme_font_size_override("font_size", 14)
	info_header.add_theme_color_override("font_color", Color(0.42, 0.18, 0.06))
	info_vbox.add_child(info_header)

	var animal_lbl := Label.new()
	animal_lbl.text = "• Linh vật đại diện: %s   |   Mã số Két sắt: %s   |   Số sao thật: %d sao" % [
		str(entry.get("animal_name", "")),
		str(entry.code),
		(entry.get("stars", []) as Array).size()
	]
	animal_lbl.add_theme_font_size_override("font_size", 13)
	animal_lbl.add_theme_color_override("font_color", Color(0.14, 0.34, 0.22))
	animal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(animal_lbl)

	var stars_lbl := Label.new()
	stars_lbl.text = "• " + str(entry.get("main_stars_info", ""))
	stars_lbl.add_theme_font_size_override("font_size", 12)
	stars_lbl.add_theme_color_override("font_color", Color(0.20, 0.14, 0.08))
	stars_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(stars_lbl)

	var lore_lbl := Label.new()
	lore_lbl.text = "• Đặc điểm nhận dạng & lọc sao nhiễu: " + str(entry.get("lore", ""))
	lore_lbl.add_theme_font_size_override("font_size", 12)
	lore_lbl.add_theme_color_override("font_color", Color(0.22, 0.16, 0.10))
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(lore_lbl)

	var rule_lbl := Label.new()
	rule_lbl.text = "💡 Ghi nhớ: Sao nhiễu trên kính ngắm có cùng màu với sao thật — hãy dựa vào sơ đồ nối trên để bỏ qua sao nhiễu, nối đạt η ≥ 95% để hiện hình linh vật và mở khóa Chìa khóa phòng bí mật!"
	rule_lbl.add_theme_font_size_override("font_size", 11)
	rule_lbl.add_theme_color_override("font_color", Color(0.48, 0.24, 0.08))
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(rule_lbl)

func _nav_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(cb)
	return btn

func _styled_button(text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.75, 0.62, 0.36)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn

func _on_open_telescope() -> void:
	var cb := open_telescope_callback
	close_book()
	if cb.is_valid():
		cb.call()
	open_telescope_requested.emit()

func close_book() -> void:
	closed.emit()
	if close_callback.is_valid():
		close_callback.call()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_book()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_A]:
			show_spread(current_spread - 1)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			show_spread(current_spread + 1)
			get_viewport().set_input_as_handled()
