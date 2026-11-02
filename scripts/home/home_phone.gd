extends Control
# In-game phone running "Nối", a fictional messenger. It uses the conventions every chat app
# shares and none of a real app's name, logo or colours.
const SCREEN := Vector2(392, 780)
const INK := Color(0.09, 0.11, 0.13)
const PAPER := Color(0.93, 0.95, 0.95)
const BRAND := Color(0.11, 0.62, 0.66)
const MINE := Color(0.72, 0.92, 0.90)
const THEIRS := Color(1, 1, 1)
const NIGHT := Color(0.07, 0.08, 0.10)
const GLYPHS := "ⱠꝒʭɮꞀƕȹʬȸꜩƢƾʨʫȣɤ▓▒░╬╪┼∷⁂"
signal reply_chosen(index: int)
signal thread_opened(id: String)
signal feed_read
var threads := {}
var order: Array[String] = []
var open_id := ""
var shell: PanelContainer
var list_page: VBoxContainer
var chat_page: VBoxContainer
var thread_rows: VBoxContainer
var title_label: Label
var status_label: Label
var messages: VBoxContainer
var scroller: ScrollContainer
var replies: VBoxContainer
var input_hint: Label
var typing_row: Control
var banner: PanelContainer
var banner_title: Label
var banner_text: Label
var clock_label: Label
var scrambled: Array = []
var feed_page: VBoxContainer
var feed_list: VBoxContainer
var feed_scroll: ScrollContainer
var feed_finished := false
var scramble_clock := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A phone is the one ordinary thing left, so it keeps an ordinary font.
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	_build_shell()
	_build_list()
	_build_chat()
	_build_banner()
	shell.hide()

func _box(colour: Color, radius := 0, border := 0, edge := Color.BLACK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = edge
	box.anti_aliasing_size = 0.8
	return box

func _text(content: String, size_px: int, colour: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	if parent != null:
		parent.add_child(label)
	return label

func _build_shell() -> void:
	shell = PanelContainer.new()
	shell.add_theme_stylebox_override("panel", _box(NIGHT, 44, 7, Color(0.19, 0.20, 0.23)))
	add_child(shell)
	shell.custom_minimum_size = SCREEN + Vector2(14, 14)
	shell.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	shell.offset_left = -SCREEN.x - 84
	shell.offset_right = -70
	shell.offset_top = -(SCREEN.y + 14) * 0.5
	shell.offset_bottom = (SCREEN.y + 14) * 0.5
	shell.pivot_offset = Vector2(SCREEN.x + 14.0, (SCREEN.y + 14.0) * 0.5)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", _box(PAPER, 38))
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shell.add_child(screen)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	screen.add_child(stack)
	var status := MarginContainer.new()
	for side in ["left", "right"]:
		status.add_theme_constant_override("margin_" + side, 30)
	status.add_theme_constant_override("margin_top", 12)
	var row := HBoxContainer.new()
	status.add_child(row)
	clock_label = _text("05:52", 14, INK, row)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text("▂▄▆  63%", 12, INK, row)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _box(Color.WHITE))
	bar.add_child(status)
	stack.add_child(bar)
	list_page = VBoxContainer.new()
	list_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_page.add_theme_constant_override("separation", 0)
	stack.add_child(list_page)
	chat_page = VBoxContainer.new()
	chat_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_page.add_theme_constant_override("separation", 0)
	stack.add_child(chat_page)
	_build_feed(stack)

func _build_feed(stack: VBoxContainer) -> void:
	feed_page = VBoxContainer.new()
	feed_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_page.add_theme_constant_override("separation", 0)
	feed_page.hide()
	stack.add_child(feed_page)
	var head := PanelContainer.new()
	var band := _box(Color(0.22, 0.31, 0.25))
	band.content_margin_left = 10
	band.content_margin_top = 6
	band.content_margin_bottom = 8
	head.add_theme_stylebox_override("panel", band)
	var row := HBoxContainer.new()
	head.add_child(row)
	var back := Button.new()
	back.text = "‹"
	back.flat = true
	back.add_theme_font_size_override("font_size", 28)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.pressed.connect(show_list)
	row.add_child(back)
	_text("Làng Ta", 24, Color(0.98, 0.96, 0.91), row)
	feed_page.add_child(head)
	feed_scroll = ScrollContainer.new()
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_scroll.get_v_scroll_bar().value_changed.connect(_feed_scrolled)
	feed_page.add_child(feed_scroll)
	feed_list = VBoxContainer.new()
	feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_list.add_theme_constant_override("separation", 8)
	feed_scroll.add_child(feed_list)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_posts.json"))
	for post in data.posts:
		_feed_card(post, data.groups.filter(func(g): return g.slug == post.group)[0].name)

func _feed_card(post: Dictionary, group: String) -> void:
	var card := PanelContainer.new()
	var paper := _box(Color(1.0, 0.99, 0.96))
	paper.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	_text(post.author, 16, INK, column)
	_text("%s · %s" % [group, post.time], 12, Color(0.48, 0.45, 0.39), column)
	_wrapped(post.text, 15, INK, column)
	_text("♥ %d   ☠ %d   %d bình luận" % [post.love, post.fear, post.comments.size()], 12, Color(0.43, 0.39, 0.33), column)
	for said in post.comments:
		_wrapped("%s: %s" % [said[0], said[1]], 13, Color(0.34, 0.31, 0.27), column)
	feed_list.add_child(card)

func _wrapped(content: String, size_px: int, colour: Color, parent: Node) -> void:
	var label := _text(content, size_px, colour, parent)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = SCREEN.x - 48.0

func _feed_scrolled(value: float) -> void:
	var bar := feed_scroll.get_v_scroll_bar()
	if value + bar.page >= bar.max_value - 4.0:
		finish_feed()

func finish_feed() -> void:
	if not feed_finished:
		feed_finished = true
		feed_read.emit()

func _build_list() -> void:
	var head := PanelContainer.new()
	var padded := _box(Color.WHITE)
	padded.content_margin_left = 22
	padded.content_margin_right = 22
	padded.content_margin_top = 10
	padded.content_margin_bottom = 14
	head.add_theme_stylebox_override("panel", padded)
	var name_row := HBoxContainer.new()
	head.add_child(name_row)
	var title := _text("Nối", 30, BRAND, name_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text("Trò chuyện", 14, Color(0.45, 0.48, 0.5), name_row)
	list_page.add_child(head)
	thread_rows = VBoxContainer.new()
	thread_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thread_rows.add_theme_constant_override("separation", 1)
	var back := PanelContainer.new()
	back.size_flags_vertical = Control.SIZE_EXPAND_FILL
	back.add_theme_stylebox_override("panel", _box(Color(0.96, 0.97, 0.97)))
	back.add_child(thread_rows)
	list_page.add_child(back)

func _build_chat() -> void:
	chat_page.hide()
	var head := PanelContainer.new()
	var padded := _box(Color.WHITE)
	padded.content_margin_left = 14
	padded.content_margin_right = 14
	padded.content_margin_top = 6
	padded.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", padded)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	head.add_child(row)
	var back := Button.new()
	back.text = "‹"
	back.flat = true
	back.add_theme_font_size_override("font_size", 30)
	back.add_theme_color_override("font_color", BRAND)
	back.pressed.connect(show_list)
	row.add_child(back)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	row.add_child(names)
	title_label = _text("", 18, INK, names)
	status_label = _text("", 12, Color(0.45, 0.48, 0.5), names)
	chat_page.add_child(head)
	scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation", 8)
	pad.add_child(messages)
	scroller.add_child(pad)
	chat_page.add_child(scroller)
	var foot := PanelContainer.new()
	var foot_box := _box(Color.WHITE)
	foot_box.content_margin_left = 12
	foot_box.content_margin_right = 12
	foot_box.content_margin_top = 8
	foot_box.content_margin_bottom = 18
	foot.add_theme_stylebox_override("panel", foot_box)
	var foot_stack := VBoxContainer.new()
	foot_stack.add_theme_constant_override("separation", 6)
	foot.add_child(foot_stack)
	replies = VBoxContainer.new()
	replies.add_theme_constant_override("separation", 6)
	foot_stack.add_child(replies)
	var field := PanelContainer.new()
	var field_box := _box(Color(0.93, 0.95, 0.95), 18)
	field_box.content_margin_left = 16
	field_box.content_margin_top = 8
	field_box.content_margin_bottom = 8
	field.add_theme_stylebox_override("panel", field_box)
	input_hint = _text("Aa", 15, Color(0.55, 0.58, 0.6), field)
	foot_stack.add_child(field)
	chat_page.add_child(foot)

func _build_banner() -> void:
	banner = PanelContainer.new()
	var box := _box(Color(1, 1, 1, 0.97), 16, 1, Color(0.82, 0.85, 0.86))
	box.set_content_margin_all(12)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 10
	banner.add_theme_stylebox_override("panel", box)
	add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	banner.offset_left = -440
	banner.offset_right = -40
	banner.offset_top = -120
	banner.offset_bottom = -30
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	banner.add_child(stack)
	banner_title = _text("", 15, INK, stack)
	banner_text = _text("", 14, Color(0.32, 0.35, 0.37), stack)
	banner_text.clip_text = true

func add_thread(id: String, title: String, status: String, avatar: Color, initial: String) -> void:
	threads[id] = {"title": title, "status": status, "avatar": avatar, "initial": initial, "log": [], "unread": 0}
	order.push_front(id)
	_refresh_list()

func _avatar(id: String, diameter: int) -> Control:
	var thread: Dictionary = threads[id]
	var circle := PanelContainer.new()
	circle.custom_minimum_size = Vector2.ONE * diameter
	circle.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	circle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	circle.add_theme_stylebox_override("panel", _box(thread.avatar, diameter / 2))
	var letter := _text(thread.initial, diameter / 2, Color.WHITE, circle)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return circle

func _refresh_list() -> void:
	for child in thread_rows.get_children():
		child.queue_free()
	for id in order:
		var thread: Dictionary = threads[id]
		var row := Button.new()
		row.custom_minimum_size.y = 76
		row.add_theme_stylebox_override("normal", _box(Color.WHITE))
		row.add_theme_stylebox_override("hover", _box(Color(0.93, 0.97, 0.97)))
		row.add_theme_stylebox_override("pressed", _box(Color(0.88, 0.95, 0.95)))
		row.add_theme_stylebox_override("focus", _box(Color.WHITE))
		row.pressed.connect(open_thread.bind(id))
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 16
		inner.offset_right = -16
		inner.offset_top = 12
		inner.add_theme_constant_override("separation", 12)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)
		var face := _avatar(id, 50)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(face)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 0)
		inner.add_child(words)
		_text(thread.title, 17, INK, words)
		var last: String = thread.log[-1].text if not thread.log.is_empty() else ""
		var preview := _text(last, 13, Color(0.45, 0.48, 0.5), words)
		preview.clip_text = true
		preview.custom_minimum_size.x = 230
		if thread.unread > 0:
			var dot := PanelContainer.new()
			dot.custom_minimum_size = Vector2(24, 24)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.add_theme_stylebox_override("panel", _box(BRAND, 12))
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var count := _text(str(thread.unread), 13, Color.WHITE, dot)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(dot)
		thread_rows.add_child(row)

func is_open() -> bool:
	return shell.visible

func toggle() -> void:
	if shell.visible:
		shell.hide()
		return
	# The canvas is scaled by the project, so it can be shorter than the phone.
	var fit := minf(1.0, (get_viewport_rect().size.y - 28.0) / (SCREEN.y + 14.0))
	shell.show()
	shell.scale = Vector2.ONE * fit * 0.96
	shell.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(shell, "scale", Vector2.ONE * fit, 0.22)
	tween.tween_property(shell, "modulate:a", 1.0, 0.18)

func show_list() -> void:
	open_id = ""
	chat_page.hide()
	feed_page.hide()
	list_page.show()
	_refresh_list()

func open_thread(id: String) -> void:
	open_id = id
	var thread: Dictionary = threads[id]
	thread.unread = 0
	list_page.hide()
	if thread.get("feed", false):
		feed_page.show()
		thread_opened.emit(id)
		return
	chat_page.show()
	title_label.text = thread.title
	status_label.text = thread.status
	scrambled.clear()
	for child in messages.get_children():
		child.queue_free()
	for entry in thread.log:
		_add_bubble(entry, false)
	_to_bottom()
	thread_opened.emit(id)

func _to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scroller.scroll_vertical = int(scroller.get_v_scroll_bar().max_value)

# Arrives as a message: into the open chat with a pop, otherwise as a banner and an unread dot.
func receive(id: String, text: String, garbled := false) -> void:
	var thread: Dictionary = threads[id]
	var entry := {"text": text, "mine": false, "garbled": garbled}
	thread.log.append(entry)
	order.erase(id)
	order.push_front(id)
	if open_id == id and shell.visible:
		_add_bubble(entry, true)
		_to_bottom()
		return
	thread.unread += 1
	_refresh_list()
	_show_banner(thread.title, text if not garbled else _noise(18))

func send_mine(id: String, text: String) -> void:
	var entry := {"text": text, "mine": true, "garbled": false}
	threads[id].log.append(entry)
	if open_id == id:
		_add_bubble(entry, true)
		_to_bottom()

func set_typing(on: bool) -> void:
	if typing_row != null:
		typing_row.queue_free()
		typing_row = null
	if on and open_id != "":
		typing_row = _bubble_row({"text": "• • •", "mine": false, "garbled": false})
		messages.add_child(typing_row)
		_to_bottom()

func _noise(length: int) -> String:
	var result := ""
	for i in range(length):
		result += " " if rng.randf() < 0.14 else GLYPHS[rng.randi() % GLYPHS.length()]
	return result

func _bubble_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if entry.mine else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	if not entry.mine:
		row.add_child(_avatar(open_id, 34))
	var bubble := PanelContainer.new()
	var box := _box(MINE if entry.mine else THEIRS, 16)
	if entry.garbled:
		box.bg_color = Color(0.12, 0.13, 0.15)
	box.corner_radius_top_left = 16 if entry.mine else 4
	box.corner_radius_top_right = 4 if entry.mine else 16
	box.content_margin_left = 13
	box.content_margin_right = 13
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	bubble.add_theme_stylebox_override("panel", box)
	var label := _text(entry.text, 15, Color(0.86, 0.84, 0.82) if entry.garbled else INK, bubble)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(258.0, entry.text.length() * 8.6 + 6.0)
	row.add_child(bubble)
	if entry.garbled:
		scrambled.append({"label": label, "length": entry.text.length()})
	return row

func _add_bubble(entry: Dictionary, animate: bool) -> void:
	var row := _bubble_row(entry)
	messages.add_child(row)
	if typing_row != null:
		messages.move_child(typing_row, -1)
	if animate:
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.2)

func offer_replies(options: Array) -> void:
	clear_replies()
	input_hint.text = "Chọn câu trả lời"
	for i in range(options.size()):
		var button := Button.new()
		button.text = options[i]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", BRAND.darkened(0.25))
		button.add_theme_color_override("font_hover_color", BRAND.darkened(0.4))
		var chip := _box(Color(0.90, 0.97, 0.97), 15, 1, BRAND)
		chip.set_content_margin_all(9)
		button.add_theme_stylebox_override("normal", chip)
		button.add_theme_stylebox_override("hover", chip)
		button.add_theme_stylebox_override("pressed", chip)
		button.add_theme_stylebox_override("focus", chip)
		button.pressed.connect(func(): reply_chosen.emit(i))
		replies.add_child(button)

func clear_replies() -> void:
	input_hint.text = "Aa"
	for child in replies.get_children():
		child.queue_free()

func _show_banner(title: String, text: String) -> void:
	banner_title.text = title
	banner_text.text = text
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "offset_top", 24.0, 0.32)
	tween.parallel().tween_property(banner, "offset_bottom", 114.0, 0.32)
	tween.tween_interval(3.2)
	tween.tween_property(banner, "offset_top", -120.0, 0.25)
	tween.parallel().tween_property(banner, "offset_bottom", -30.0, 0.25)

func _process(delta: float) -> void:
	scramble_clock -= delta
	if scramble_clock > 0.0:
		return
	scramble_clock = 0.09
	for item in scrambled:
		if is_instance_valid(item.label):
			item.label.text = _noise(item.length)
