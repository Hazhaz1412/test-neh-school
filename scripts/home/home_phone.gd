extends Control
# Peter's phone: a modern full-screen phone with a home screen of apps. Only two open: Fake (the
# social feed) and Tili (chat). Everything else is set dressing and only wiggles when tapped.
# The look follows today's phones without any real brand's name, logo or artwork.
#
# Handling it is meant to feel like a real one: Tab lifts it up into the middle of the view (the
# room behind blurs and the camera dips to look at it), the screen wakes on the lock screen and
# unlocks by itself a moment later, or at once with a swipe up. Lists are dragged and flung
# (phone_scroll.gd). A swipe up from the bottom bar goes home; apps zoom out of their icon and
# back into it. Tab, Esc or a click beside the phone puts it away.
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
# The lift: how far below its rest the phone starts, how much it is turned, how long it takes.
const LIFT_DROP := 0.9
const LIFT_TILT := 0.20
const LIFT_SECONDS := 0.5
const LOWER_SECONDS := 0.3
# Face unlock: the lock screen shows this long before it lets you in by itself.
const UNLOCK_AFTER := 0.75
# A swipe this far up from the bottom bar counts as "go home".
const SWIPE_HOME := 70.0
const HOME_ZONE := 46.0
signal reply_chosen(index: int)
signal thread_opened(id: String)
signal feed_read
# Lifted (true) or put away (false), for the room to dip the camera with it.
signal raised_changed(raised: bool)
# A click beside the phone: the owner decides whether that puts it away.
signal dismiss_requested
var shell: PanelContainer
var display: Control
var veil: ColorRect
var veil_material: ShaderMaterial
var home_page: Control
var lock_page: Control
var lock_clock: Label
var lock_date: Label
var padlock: Padlock
var screen_off: ColorRect
var fake: Control
var tili: Control
var status_bar: Control
var clock_label: Label
var home_bar: Button
var notice: PanelContainer
var notice_id := ""
var notice_clock := 0.0
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var banner_icon: HBoxContainer
var pending := {}
var badges := {}
var app_icons := {}
var app := "home"
var raised := false
var locked := true
var date_text := "Thứ Sáu, 14 tháng 11"
var motion: Tween
var unlock_timer := 0.0
var swipe_from := Vector2.INF
var swipe_page: Control
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
	_build_veil()
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
	_build_lock()
	_build_overlays()
	_build_banner()
	# The bottom bar's swipe and the lock screen belong to the phone, not to the list under them.
	for list in [fake.feed_scroll, tili.list_scroll, tili.scroller]:
		list.ignore_press = func(at: Vector2) -> bool:
			return locked or _display_point(at).y > SCREEN.y - HOME_ZONE
	go_home()
	shell.hide()
	veil.hide()

# --- Frame and overlays -----------------------------------------------------------------------

# The room behind the phone, blurred and darkened while it is up.
func _build_veil() -> void:
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil_material = ShaderMaterial.new()
	veil_material.shader = preload("res://assets/materials/phone_backdrop.gdshader")
	veil.material = veil_material
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(event: InputEvent):
		if raised and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss_requested.emit())
	add_child(veil)

func _build_shell() -> void:
	shell = PanelContainer.new()
	var frame := Kit.box(Color.BLACK, SCREEN_RADIUS + FRAME, 3, Color(0.46, 0.44, 0.41))
	frame.set_content_margin_all(FRAME)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 28
	frame.shadow_offset = Vector2(0, 10)
	shell.add_theme_stylebox_override("panel", frame)
	add_child(shell)
	var outer := _outer()
	shell.custom_minimum_size = outer
	shell.size = outer
	shell.pivot_offset = outer * 0.5
	var glass := PanelContainer.new()
	glass.add_theme_stylebox_override("panel", Kit.box(Color.BLACK, SCREEN_RADIUS))
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shell.add_child(glass)
	display = Control.new()
	display.custom_minimum_size = SCREEN
	display.clip_contents = true
	glass.add_child(display)

func _outer() -> Vector2:
	return SCREEN + Vector2.ONE * FRAME * 2

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
	home_bar.tooltip_text = "Vuốt lên để về màn hình chính"
	home_bar.pressed.connect(_tap_home_bar)
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
	# The glass itself going dark: on while the phone is down, it wakes as it comes up.
	screen_off = ColorRect.new()
	screen_off.color = Color.BLACK
	screen_off.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(screen_off)

func _tap_home_bar() -> void:
	if not locked:
		go_home()

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

# The lock screen's padlock; `open` lifts the shackle as the face is recognised.
class Padlock extends Control:
	var open := 0.0:
		set(value):
			open = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(28, 34)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var lift := open * 7.0
		draw_arc(Vector2(14, 14 - lift), 8, PI, TAU, 16, Color.WHITE, 3.0, true)
		draw_line(Vector2(6, 14 - lift), Vector2(6, 17 - lift * 0.2), Color.WHITE, 3.0, true)
		draw_line(Vector2(22, 14 - lift), Vector2(22, 17), Color.WHITE, 3.0, true)
		var body := StyleBoxFlat.new()
		body.bg_color = Color.WHITE
		body.set_corner_radius_all(5)
		draw_style_box(body, Rect2(2, 16, 24, 18))

func _set_tint(light: bool) -> void:
	var tint := Color.WHITE if light else Kit.INK
	clock_label.add_theme_color_override("font_color", tint)
	for child in status_bar.get_children():
		if child is StatusIcons:
			child.tint = tint
			child.queue_redraw()
	home_bar.get_child(0).get_theme_stylebox("panel").bg_color = Color.WHITE if light else Kit.INK

# --- Lock screen ------------------------------------------------------------------------------

func _build_lock() -> void:
	lock_page = Control.new()
	lock_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_page.mouse_filter = Control.MOUSE_FILTER_STOP
	display.add_child(lock_page)
	lock_page.add_child(_wallpaper(0.15))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 70
	column.offset_bottom = -40
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_page.add_child(column)
	var lock_row := CenterContainer.new()
	lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padlock = Padlock.new()
	lock_row.add_child(padlock)
	column.add_child(lock_row)
	lock_date = Kit.text(date_text, 17, Color(1, 1, 1, 0.9), column, true)
	lock_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_clock = Kit.text("05:52", 92, Color.WHITE, column, true)
	lock_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var hint := Kit.text("Vuốt lên để mở", 14, Color(1, 1, 1, 0.8), column)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_meta("breathe", true)
	lock_page.set_meta("hint", hint)

func _wallpaper(darken := 0.0) -> TextureRect:
	var wall := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, WALL_TOP.darkened(darken))
	gradient.gradient.set_color(1, WALL_BOTTOM.darkened(darken))
	gradient.fill_from = Vector2(0.2, 0)
	gradient.fill_to = Vector2(0.8, 1)
	wall.texture = gradient
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return wall

func _lock() -> void:
	locked = true
	unlock_timer = UNLOCK_AFTER
	lock_page.show()
	lock_page.position = Vector2.ZERO
	lock_page.modulate.a = 1.0
	padlock.open = 0.0
	lock_clock.text = clock_label.text
	lock_date.text = date_text
	status_bar.modulate.a = 0.0
	_set_tint(true)

# The lock screen slides up out of the way and the page under it settles into place.
func unlock() -> void:
	if not locked:
		return
	locked = false
	unlock_timer = 0.0
	var under: Control = _page(app)
	under.pivot_offset = SCREEN * 0.5
	under.scale = Vector2.ONE * 1.06
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(padlock, "open", 1.0, 0.16)
	tween.tween_property(lock_page, "position:y", -SCREEN.y, 0.42).set_delay(0.1)
	tween.tween_property(lock_page, "modulate:a", 0.0, 0.42).set_delay(0.1)
	tween.tween_property(under, "scale", Vector2.ONE, 0.45).set_delay(0.1)
	tween.tween_property(status_bar, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tween.chain().tween_callback(func():
		lock_page.hide()
		_set_tint(app == "home")
		# A message that came while the phone was away waits on the home screen.
		if not pending.is_empty() and raised:
			go_home()
			_notify(pending.id, pending.title, pending.text, true)
			pending = {})

# --- Home screen ------------------------------------------------------------------------------

func _build_home() -> void:
	home_page = Control.new()
	home_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.add_child(home_page)
	home_page.add_child(_wallpaper())
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
	app_icons[kind] = icon
	var badge_holder := Control.new()
	badge_holder.position = Vector2(ICON - 14, -6)
	badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge_holder)
	badges[kind] = badge_holder
	button.button_down.connect(func(): icon.create_tween().tween_property(icon, "scale", Vector2.ONE * 0.9, 0.08))
	button.button_up.connect(func(): icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.12))
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

func _page(app_name: String) -> Control:
	return fake if app_name == "fake" else (tili if app_name == "tili" else home_page)

# Where an app's icon sits on the screen, for it to open out of and close back into.
func _icon_centre(kind: String) -> Vector2:
	var icon: Control = app_icons.get(kind)
	if icon == null or not icon.is_inside_tree():
		return SCREEN * 0.5
	return display.get_global_transform_with_canvas().affine_inverse() * icon.get_global_transform_with_canvas() * (icon.size * 0.5)

func go_home() -> void:
	var leaving: Control = _page(app) if app != "home" else null
	app = "home"
	home_page.show()
	_set_tint(true)
	_refresh_badges()
	if leaving == null or not leaving.visible or not is_open():
		fake.hide()
		tili.hide()
		return
	# The app shrinks back into its icon while the home screen comes forward.
	var kind := "fake" if leaving == fake else "tili"
	leaving.pivot_offset = _icon_centre(kind)
	home_page.pivot_offset = SCREEN * 0.5
	home_page.scale = Vector2.ONE * 0.94
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(leaving, "scale", Vector2.ONE * 0.16, 0.32)
	tween.tween_property(leaving, "modulate:a", 0.0, 0.24)
	tween.tween_property(home_page, "scale", Vector2.ONE, 0.36)
	tween.chain().tween_callback(func():
		if app == "home":
			leaving.hide()
		leaving.scale = Vector2.ONE
		leaving.modulate.a = 1.0)

func open_app(app_name: String) -> void:
	app = app_name
	var page: Control = _page(app_name)
	fake.visible = app_name == "fake"
	tili.visible = app_name == "tili"
	_set_tint(false)
	if app_name == "fake":
		fake_new = 0
	# The app grows out of its icon, as on a phone.
	page.pivot_offset = _icon_centre(app_name)
	page.scale = Vector2.ONE * 0.16
	page.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(page, "scale", Vector2.ONE, 0.38)
	tween.tween_property(page, "modulate:a", 1.0, 0.16)
	tween.tween_property(home_page, "scale", Vector2.ONE * 0.94, 0.38)
	tween.chain().tween_callback(func():
		if app != "home":
			home_page.hide()
		home_page.scale = Vector2.ONE)

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
func receive(id: String, text: String) -> void:
	if tili.receive(id, text):
		return
	var title: String = threads[id].title
	if is_open() and not locked:
		_notify(id, title, text, app == "home")
	else:
		pending = {"id": id, "title": title, "text": text}
		if not is_open():
			_show_banner(title, text, "tili")

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

# --- Lifting it up and putting it away --------------------------------------------------------

func is_open() -> bool:
	return raised

# The canvas is scaled by the project, so it can be shorter than the phone.
func _fit() -> float:
	return minf(1.0, (get_viewport_rect().size.y - 28.0) / _outer().y)

func _rest() -> Vector2:
	return (get_viewport_rect().size - _outer()) * 0.5

func toggle() -> void:
	if raised:
		lower()
	else:
		lift()

# Up out of the pocket: it swings upright as it rises, the room behind it goes soft, and the
# screen wakes on the lock screen just before it reaches eye level.
func lift() -> void:
	if raised:
		return
	raised = true
	raised_changed.emit(true)
	if motion != null:
		motion.kill()
	var fit := _fit()
	var rest := _rest()
	shell.show()
	veil.show()
	_lock()
	shell.size = _outer()
	shell.position = rest + Vector2(_outer().x * 0.35, _outer().y * LIFT_DROP)
	shell.rotation = LIFT_TILT
	shell.scale = Vector2.ONE * fit * 0.86
	screen_off.modulate.a = 1.0
	motion = create_tween().set_parallel()
	motion.tween_property(shell, "position", rest, LIFT_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	motion.tween_property(shell, "rotation", 0.0, LIFT_SECONDS * 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(shell, "scale", Vector2.ONE * fit, LIFT_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_method(_set_veil, veil_material.get_shader_parameter("amount") if veil_material.get_shader_parameter("amount") != null else 0.0, 1.0, LIFT_SECONDS * 0.8)
	motion.tween_property(screen_off, "modulate:a", 0.0, 0.22).set_delay(LIFT_SECONDS * 0.45)

# Back down: the screen goes dark first, then it drops away and the room comes back into focus.
func lower() -> void:
	if not raised:
		return
	raised = false
	raised_changed.emit(false)
	if motion != null:
		motion.kill()
	_hide_notice()
	var rest := _rest()
	motion = create_tween().set_parallel()
	motion.tween_property(screen_off, "modulate:a", 1.0, 0.14)
	motion.tween_property(shell, "position", rest + Vector2(_outer().x * 0.25, _outer().y * LIFT_DROP), LOWER_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_property(shell, "rotation", LIFT_TILT * 0.7, LOWER_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_method(_set_veil, 1.0, 0.0, LOWER_SECONDS)
	motion.chain().tween_callback(func():
		if not raised:
			shell.hide()
			veil.hide())

func _set_veil(amount: float) -> void:
	veil_material.set_shader_parameter("amount", amount)

# --- Gestures ---------------------------------------------------------------------------------

func _display_point(at: Vector2) -> Vector2:
	return display.get_global_transform_with_canvas().affine_inverse() * at

# A swipe up: from the bottom bar it goes home; anywhere on the lock screen it unlocks.
# The page being left follows the finger, so the gesture is felt before it is let go.
func _input(event: InputEvent) -> void:
	if not raised or motion != null and motion.is_running() and not locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _display_point(event.position)
		if event.pressed:
			var inside := Rect2(Vector2.ZERO, SCREEN).has_point(at)
			swipe_from = at if inside and (locked or at.y > SCREEN.y - HOME_ZONE and app != "home") else Vector2.INF
			swipe_page = lock_page if locked else _page(app)
		elif swipe_from != Vector2.INF:
			var rise := swipe_from.y - at.y
			var page := swipe_page
			swipe_from = Vector2.INF
			if rise > SWIPE_HOME:
				get_viewport().set_input_as_handled()
				if locked:
					unlock()
				else:
					go_home()
			elif page != null:
				_settle(page)
	elif event is InputEventMouseMotion and swipe_from != Vector2.INF and swipe_page != null:
		var rise := maxf(0.0, swipe_from.y - _display_point(event.position).y)
		if locked:
			swipe_page.position.y = -rise
		else:
			swipe_page.pivot_offset = Vector2(SCREEN.x * 0.5, SCREEN.y)
			swipe_page.scale = Vector2.ONE * (1.0 - minf(rise / SCREEN.y, 0.5) * 0.5)
		if rise > 6.0:
			get_viewport().set_input_as_handled()

func _settle(page: Control) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if page == lock_page:
		tween.tween_property(page, "position:y", 0.0, 0.3)
	else:
		tween.tween_property(page, "scale", Vector2.ONE, 0.3)

func _process(delta: float) -> void:
	if raised and locked and unlock_timer > 0.0 and swipe_from == Vector2.INF:
		unlock_timer -= delta
		if unlock_timer <= 0.0:
			unlock()
	if lock_page.visible:
		var hint: Label = lock_page.get_meta("hint")
		hint.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	if notice_id.is_empty() or notice_clock == INF:
		return
	notice_clock -= delta
	if notice_clock <= 0.0:
		_hide_notice()
