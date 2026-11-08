extends Control
# Peter's phone: a modern full-screen phone with a home screen of apps. Only two open: Fake (the
# social feed) and Tili (chat). Everything else is set dressing and only wiggles when tapped.
# The look follows today's phones without any real brand's name, logo or artwork.
const Kit := preload("res://scripts/home/phone/phone_kit.gd")
const Fake := preload("res://scripts/home/phone/phone_fake.gd")
const Tili := preload("res://scripts/home/phone/phone_tili.gd")
const SCREEN := Vector2(400, 860)
const FRAME := 7
const SCREEN_RADIUS := 54
const WALL_TOP := Color(0.09, 0.11, 0.26)
const WALL_BOTTOM := Color(0.38, 0.17, 0.36)
const GRID_APPS := [["calendar", "Lịch"], ["photos", "Ảnh"], ["camera", "Camera"], ["clock", "Đồng hồ"],
	["weather", "Thời tiết"], ["maps", "Bản đồ"], ["notes", "Ghi chú"], ["settings", "Cài đặt"]]
const DOCK_APPS := ["phone", "tili", "fake", "music"]
const ICON := 62
const NOTICE_SECONDS := 6.0
signal reply_chosen(index: int)
signal thread_opened(id: String)
signal feed_read
var shell: PanelContainer
var display: Control
var home_page: Control
var fake: Control
var tili: Control
var status_bar: Control
var clock_label: Label
var home_bar: Button
var notice: PanelContainer
var notice_title: Label
var notice_text: Label
var notice_id := ""
var notice_clock := 0.0
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var banner_icon: HBoxContainer
var pending := {}
var badges := {}
var app := "home"
# New posts waiting in Fake; the badge clears once the app is opened.
var fake_new := 0:
	set(value):
		fake_new = value
		_refresh_badges()

# The story and tests talk to the chat and feed through the phone, as before the apps existed.
var threads: Dictionary:
	get: return tili.threads
var open_id: String:
	get: return tili.open_id
var replies: VBoxContainer:
	get: return tili.replies
var scrambled: Array:
	get: return tili.scrambled
var status_label: Label:
	get: return tili.status_label
var feed_list: VBoxContainer:
	get: return fake.feed_list

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A phone is the one ordinary thing left, so it keeps an ordinary font.
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	_build_shell()
	_build_home()
	fake = Fake.new()
	display.add_child(fake)
	fake.build(SCREEN.x)
	fake.feed_read.connect(func(): feed_read.emit())
	tili = Tili.new()
	display.add_child(tili)
	tili.build()
	tili.clock = func(): return clock_label.text
	tili.reply_chosen.connect(func(index): reply_chosen.emit(index))
	tili.thread_opened.connect(_on_thread_opened)
	tili.unread_changed.connect(_refresh_badges)
	_build_overlays()
	_build_banner()
	go_home()
	shell.hide()

# --- Frame and overlays -----------------------------------------------------------------------

func _build_shell() -> void:
	shell = PanelContainer.new()
	var frame := Kit.box(Color.BLACK, SCREEN_RADIUS + FRAME, 3, Color(0.46, 0.44, 0.41))
	frame.set_content_margin_all(FRAME)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 18
	shell.add_theme_stylebox_override("panel", frame)
	add_child(shell)
	var outer := SCREEN + Vector2.ONE * FRAME * 2
	shell.custom_minimum_size = outer
	shell.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	shell.offset_left = -outer.x - 70
	shell.offset_right = -70
	shell.offset_top = -outer.y * 0.5
	shell.offset_bottom = outer.y * 0.5
	shell.pivot_offset = Vector2(outer.x, outer.y * 0.5)
	var glass := PanelContainer.new()
	glass.add_theme_stylebox_override("panel", Kit.box(Color.BLACK, SCREEN_RADIUS))
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shell.add_child(glass)
	display = Control.new()
	display.custom_minimum_size = SCREEN
	display.clip_contents = true
	glass.add_child(display)

func _build_overlays() -> void:
	status_bar = Control.new()
	status_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_bar.offset_bottom = 50
	status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(status_bar)
	clock_label = Kit.text("05:52", 16, Color.WHITE, status_bar, true)
	clock_label.position = Vector2(42, 16)
	var signal_icons := StatusIcons.new()
	signal_icons.position = Vector2(SCREEN.x - 112, 19)
	status_bar.add_child(signal_icons)
	var island := Panel.new()
	island.add_theme_stylebox_override("panel", Kit.box(Color.BLACK, 18))
	island.size = Vector2(122, 36)
	island.position = Vector2((SCREEN.x - island.size.x) * 0.5, 11)
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(island)
	home_bar = Kit.plain_button(display)
	home_bar.size = Vector2(170, 26)
	home_bar.position = Vector2((SCREEN.x - home_bar.size.x) * 0.5, SCREEN.y - home_bar.size.y)
	home_bar.tooltip_text = "Về màn hình chính"
	home_bar.pressed.connect(go_home)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", Kit.box(Color.WHITE, 3))
	pill.size = Vector2(136, 5)
	pill.position = Vector2((home_bar.size.x - pill.size.x) * 0.5, 13)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_bar.add_child(pill)
	notice = _notice_card()
	notice.position = Vector2(10, -130)
	notice.size = Vector2(SCREEN.x - 20, 0)
	display.add_child(notice)
	var tap := Kit.plain_button(notice)
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(tap_notice)

# Signal bars and battery, drawn so they need no symbol font.
class StatusIcons extends Control:
	var tint := Color.WHITE

	func _init() -> void:
		size = Vector2(80, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(4):
			var bar_height := 4.0 + i * 3.0
			draw_rect(Rect2(i * 5.0, 13.0 - bar_height, 3.5, bar_height), tint)
		draw_string(ThemeDB.fallback_font, Vector2(24, 12), "5G", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		var battery := Rect2(46, 1, 25, 12)
		draw_rect(battery, Color(tint, 0.45), false, 1.2)
		draw_rect(Rect2(battery.position + Vector2(2, 2), Vector2(battery.size.x * 0.63 - 4, battery.size.y - 4)), tint)
		draw_rect(Rect2(72, 5, 2, 4), Color(tint, 0.45))

func _set_tint(light: bool) -> void:
	var tint := Color.WHITE if light else Kit.INK
	clock_label.add_theme_color_override("font_color", tint)
	for child in status_bar.get_children():
		if child is StatusIcons:
			child.tint = tint
			child.queue_redraw()
	home_bar.get_child(0).get_theme_stylebox("panel").bg_color = Color.WHITE if light else Kit.INK

# --- Home screen ------------------------------------------------------------------------------

func _build_home() -> void:
	home_page = Control.new()
	home_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.add_child(home_page)
	var wall := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, WALL_TOP)
	gradient.gradient.set_color(1, WALL_BOTTOM)
	gradient.fill_from = Vector2(0.2, 0)
	gradient.fill_to = Vector2(0.8, 1)
	wall.texture = gradient
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_page.add_child(wall)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 66
	column.offset_left = 22
	column.offset_right = -22
	column.offset_bottom = -30
	column.add_theme_constant_override("separation", 18)
	home_page.add_child(column)
	column.add_child(_weather_widget())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for entry in GRID_APPS:
		grid.add_child(_app_slot(entry[0], entry[1]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var search := PanelContainer.new()
	search.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill := Kit.box(Color(1, 1, 1, 0.22), 14)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 5
	pill.content_margin_bottom = 5
	search.add_theme_stylebox_override("panel", pill)
	Kit.text("⌕ Tìm kiếm", 13, Color.WHITE, search)
	column.add_child(search)
	var dock := PanelContainer.new()
	var glass := Kit.box(Color(1, 1, 1, 0.24), 32)
	glass.set_content_margin_all(12)
	dock.add_theme_stylebox_override("panel", glass)
	column.add_child(dock)
	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 26)
	dock.add_child(dock_row)
	for kind in DOCK_APPS:
		dock_row.add_child(_app_slot(kind, ""))

func _weather_widget() -> PanelContainer:
	var card := PanelContainer.new()
	var glass := Kit.box(Color(1, 1, 1, 0.16), 24)
	glass.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", glass)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)
	Kit.text("Bến Trầu", 15, Color.WHITE, column, true)
	Kit.text("27°", 40, Color.WHITE, column)
	Kit.text("Nhiều mây · Đêm nay có thể mưa", 13, Color(1, 1, 1, 0.85), column)
	return card

func _app_slot(kind: String, title: String) -> Control:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 5)
	var button := Kit.plain_button(slot)
	button.custom_minimum_size = Vector2.ONE * ICON
	var icon := Kit.Icon.new(kind, ICON)
	button.add_child(icon)
	var badge_holder := Control.new()
	badge_holder.position = Vector2(ICON - 14, -6)
	badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge_holder)
	badges[kind] = badge_holder
	button.pressed.connect(_tap_app.bind(kind, icon))
	if not title.is_empty():
		var label := Kit.text(title, 11, Color.WHITE, slot)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		label.add_theme_constant_override("outline_size", 3)
	return slot

func _tap_app(kind: String, icon: Control) -> void:
	if kind == "fake" or kind == "tili":
		open_app(kind)
		return
	# Set dressing: a small shake says "not now" without leaving the home screen.
	var tween := icon.create_tween()
	for angle in [0.09, -0.09, 0.06, -0.04, 0.0]:
		tween.tween_property(icon, "rotation", angle, 0.05)

func _refresh_badges() -> void:
	if tili == null:
		return
	var counts := {"tili": tili.unread_total(), "fake": fake_new}
	for kind in counts:
		var holder: Control = badges.get(kind)
		if holder == null:
			continue
		for child in holder.get_children():
			child.queue_free()
		if counts[kind] > 0:
			holder.add_child(Kit.badge(counts[kind]))

# --- Apps -------------------------------------------------------------------------------------

func go_home() -> void:
	app = "home"
	home_page.show()
	fake.hide()
	tili.hide()
	_set_tint(true)
	_refresh_badges()

func open_app(app_name: String) -> void:
	app = app_name
	home_page.hide()
	fake.visible = app_name == "fake"
	tili.visible = app_name == "tili"
	_set_tint(false)
	if app_name == "fake":
		fake_new = 0
	var page: Control = fake if app_name == "fake" else tili
	page.pivot_offset = SCREEN * 0.5
	page.scale = Vector2.ONE * 0.92
	page.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(page, "scale", Vector2.ONE, 0.22)
	tween.tween_property(page, "modulate:a", 1.0, 0.16)

func show_list() -> void:
	open_app("tili")
	tili.show_list()

func open_thread(id: String) -> void:
	if app != "tili":
		open_app("tili")
	tili.open_thread(id)

func _on_thread_opened(id: String) -> void:
	if notice_id == id:
		_hide_notice()
	pending.erase(id)
	thread_opened.emit(id)

func add_thread(id: String, title: String, status: String, avatar: Color, initial: String) -> void:
	tili.add_thread(id, title, status, avatar, initial)

func _refresh_list() -> void:
	tili.refresh_list()

func finish_feed() -> void:
	fake.finish_feed()

# --- Messages ---------------------------------------------------------------------------------

# Lands in the open chat; otherwise a notification inside the phone, or above it when it is away.
func receive(id: String, text: String, garbled := false) -> void:
	if tili.receive(id, text, garbled):
		return
	var title: String = threads[id].title
	var preview: String = tili._noise(18) if garbled else text
	if shell.visible:
		_notify(id, title, preview, app == "home")
	else:
		pending = {"id": id, "title": title, "text": preview}
		_show_banner(title, preview, "tili")

func send_mine(id: String, text: String) -> void:
	tili.send_mine(id, text)

func set_typing(on: bool) -> void:
	tili.set_typing(on)

func offer_replies(options: Array) -> void:
	tili.offer_replies(options)

func clear_replies() -> void:
	tili.clear_replies()

# --- Notifications ----------------------------------------------------------------------------

func _notice_card() -> PanelContainer:
	var card := PanelContainer.new()
	var glass := Kit.box(Color(0.97, 0.97, 0.98, 0.95), 24)
	glass.set_content_margin_all(12)
	glass.shadow_color = Color(0, 0, 0, 0.25)
	glass.shadow_size = 12
	card.add_theme_stylebox_override("panel", glass)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon_holder := HBoxContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(Kit.Icon.new("tili", 38))
	row.add_child(icon_holder)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(top)
	var title := Kit.text("", 15, Kit.INK, top, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	Kit.text("bây giờ", 12, Kit.GREY, top)
	var body := Kit.text("", 14, Color(0.25, 0.26, 0.28), words)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 2
	body.custom_minimum_size.x = 250
	card.set_meta("title", title)
	card.set_meta("body", body)
	card.set_meta("icon", icon_holder)
	return card

# Sticky notices wait on the home screen until tapped; inside an app they slide away.
func _notify(id: String, title: String, text: String, sticky: bool) -> void:
	notice_id = id
	notice.get_meta("title").text = title
	notice.get_meta("body").text = text
	notice_clock = INF if sticky else NOTICE_SECONDS
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(notice, "position:y", 54.0, 0.32)

func _hide_notice() -> void:
	notice_id = ""
	create_tween().tween_property(notice, "position:y", -130.0, 0.22)

func tap_notice() -> void:
	if not notice_id.is_empty():
		var id := notice_id
		_hide_notice()
		open_thread(id)

# Outside the phone, for when it is in Peter's pocket.
func _build_banner() -> void:
	banner = _notice_card()
	add_child(banner)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	banner.offset_left = -440
	banner.offset_right = -40
	banner.offset_top = -120
	banner.offset_bottom = -30
	banner_title = banner.get_meta("title")
	banner_text = banner.get_meta("body")
	banner_icon = banner.get_meta("icon")

func _show_banner(title: String, text: String, kind := "settings") -> void:
	banner_title.text = title
	banner_text.text = text
	for child in banner_icon.get_children():
		child.queue_free()
	banner_icon.add_child(Kit.Icon.new(kind, 38))
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "offset_top", 24.0, 0.32)
	tween.parallel().tween_property(banner, "offset_bottom", 114.0, 0.32)
	tween.tween_interval(3.2)
	tween.tween_property(banner, "offset_top", -120.0, 0.25)
	tween.parallel().tween_property(banner, "offset_bottom", -30.0, 0.25)

# --- Opening ----------------------------------------------------------------------------------

func is_open() -> bool:
	return shell.visible

func toggle() -> void:
	if shell.visible:
		shell.hide()
		return
	# The canvas is scaled by the project, so it can be shorter than the phone.
	var fit := minf(1.0, (get_viewport_rect().size.y - 28.0) / (SCREEN.y + FRAME * 2.0))
	shell.show()
	# A message that came while the phone was away waits on the home screen.
	if not pending.is_empty():
		go_home()
		_notify(pending.id, pending.title, pending.text, true)
		pending = {}
	shell.scale = Vector2.ONE * fit * 0.96
	shell.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(shell, "scale", Vector2.ONE * fit, 0.22)
	tween.tween_property(shell, "modulate:a", 1.0, 0.18)

func _process(delta: float) -> void:
	if notice_id.is_empty() or notice_clock == INF:
		return
	notice_clock -= delta
	if notice_clock <= 0.0:
		_hide_notice()
