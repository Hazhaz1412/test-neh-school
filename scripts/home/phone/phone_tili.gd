extends Control
# Tili: the chat app (team, landlady, Lan, the stranger). Messages either land in the open chat
# or count as unread; the phone shell decides whether to show a notification.
const Kit := preload("res://scripts/home/phone/phone_kit.gd")
const ACCENT := Color(0.16, 0.53, 0.90)
const MINE := Color(0.88, 0.98, 0.78)
const THEIRS := Color.WHITE
const WALL_TOP := Color(0.80, 0.87, 0.68)
const WALL_BOTTOM := Color(0.62, 0.77, 0.60)
const SENDER_COLOURS := [Color(0.86, 0.36, 0.24), Color(0.18, 0.52, 0.84), Color(0.25, 0.58, 0.28), Color(0.62, 0.34, 0.74)]
const GLYPHS := "ⱠꝒʭɮꞀƕȹʬȸꜩƢƾʨʫȣɤ▓▒░╬╪┼∷⁂"
const TOP_SPACE := 50
const BOTTOM_SPACE := 22
const BUBBLE_WIDTH := 250.0
signal reply_chosen(index: int)
signal thread_opened(id: String)
signal unread_changed
var threads := {}
var order: Array[String] = []
var open_id := ""
# Returns the phone's clock text, stamped on each message.
var clock: Callable = func(): return ""
var list_page: Control
var chat_page: Control
var thread_rows: VBoxContainer
var title_label: Label
var status_label: Label
var face_holder: HBoxContainer
var messages: VBoxContainer
var scroller: ScrollContainer
var replies: VBoxContainer
var input_hint: Label
var typing_row: Control
var scrambled: Array = []
var scramble_clock := 0.0
var rng := RandomNumberGenerator.new()

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_list()
	_build_chat()

# --- Chat list --------------------------------------------------------------------------------

func _build_list() -> void:
	list_page = Panel.new()
	list_page.add_theme_stylebox_override("panel", Kit.box(Color.WHITE))
	list_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(list_page)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	list_page.add_child(stack)
	var head := MarginContainer.new()
	head.add_theme_constant_override("margin_top", TOP_SPACE + 4)
	head.add_theme_constant_override("margin_left", 16)
	head.add_theme_constant_override("margin_right", 16)
	head.add_theme_constant_override("margin_bottom", 8)
	stack.add_child(head)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	head.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	var edit := Kit.text("Sửa", 16, ACCENT, row)
	edit.custom_minimum_size.x = 60
	var title := Kit.text("Đoạn chat", 17, Kit.INK, row, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var write := Kit.text("✎", 20, ACCENT, row)
	write.custom_minimum_size.x = 60
	write.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var search := PanelContainer.new()
	var field := Kit.box(Color(0.93, 0.93, 0.94), 10)
	field.content_margin_top = 7
	field.content_margin_bottom = 7
	search.add_theme_stylebox_override("panel", field)
	var hint := Kit.text("⌕  Tìm kiếm", 15, Kit.GREY, search)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(search)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(list_scroll)
	thread_rows = VBoxContainer.new()
	thread_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread_rows.add_theme_constant_override("separation", 0)
	list_scroll.add_child(thread_rows)
	stack.add_child(_tab_bar())

func _tab_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var style := Kit.box(Color(0.97, 0.97, 0.98))
	style.border_width_top = 1
	style.border_color = Kit.LINE
	style.content_margin_top = 6
	style.content_margin_bottom = BOTTOM_SPACE + 4
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	bar.add_child(row)
	for tab in ["Danh bạ", "Cuộc gọi", "Đoạn chat", "Cài đặt"]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var colour := ACCENT if tab == "Đoạn chat" else Kit.GREY
		var dot := Kit.text("●", 16, colour, cell)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var word := Kit.text(tab, 10, colour, cell)
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return bar

func add_thread(id: String, title: String, status: String, avatar: Color, initial: String) -> void:
	threads[id] = {"title": title, "status": status, "avatar": avatar, "initial": initial, "log": [], "unread": 0}
	order.push_front(id)
	refresh_list()

func unread_total() -> int:
	var total := 0
	for id in threads:
		total += threads[id].unread
	return total

func refresh_list() -> void:
	for child in thread_rows.get_children():
		child.queue_free()
	for id in order:
		var thread: Dictionary = threads[id]
		var row := Kit.plain_button(thread_rows)
		row.custom_minimum_size.y = 78
		row.pressed.connect(open_thread.bind(id))
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 12
		inner.offset_right = -14
		inner.add_theme_constant_override("separation", 12)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)
		inner.add_child(Kit.avatar(thread.avatar, thread.initial, 56))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 2)
		inner.add_child(words)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(top)
		var name_label := Kit.text(thread.title, 16, Kit.INK, top, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		var last: Dictionary = thread.log[-1] if not thread.log.is_empty() else {}
		Kit.text(last.get("time", ""), 13, Kit.GREY, top)
		var bottom := HBoxContainer.new()
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(bottom)
		var preview := Kit.text(_noise(16) if last.get("garbled", false) else last.get("text", ""), 14, Kit.GREY, bottom)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.clip_text = true
		preview.custom_minimum_size.x = 180
		if thread.unread > 0:
			bottom.add_child(Kit.badge(thread.unread, ACCENT))
		var rule := ColorRect.new()
		rule.color = Kit.LINE
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		rule.offset_left = 80
		rule.offset_top = -1
		row.add_child(rule)
	unread_changed.emit()

func show_list() -> void:
	open_id = ""
	chat_page.hide()
	list_page.show()
	refresh_list()

# --- Chat -------------------------------------------------------------------------------------

func _build_chat() -> void:
	chat_page = Control.new()
	chat_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_page.hide()
	add_child(chat_page)
	var wall := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, WALL_TOP)
	gradient.gradient.set_color(1, WALL_BOTTOM)
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(0.3, 1)
	wall.texture = gradient
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chat_page.add_child(wall)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	chat_page.add_child(stack)
	var head := PanelContainer.new()
	var band := Kit.box(Color(0.97, 0.97, 0.98, 0.96))
	band.content_margin_top = TOP_SPACE
	band.content_margin_left = 6
	band.content_margin_right = 12
	band.content_margin_bottom = 6
	band.border_width_bottom = 1
	band.border_color = Kit.LINE
	head.add_theme_stylebox_override("panel", band)
	stack.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	head.add_child(row)
	var back := Button.new()
	back.text = "‹ Chat"
	back.flat = true
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_color_override("font_color", ACCENT)
	back.add_theme_color_override("font_hover_color", ACCENT.darkened(0.2))
	back.custom_minimum_size.x = 76
	back.pressed.connect(show_list)
	row.add_child(back)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	row.add_child(names)
	title_label = Kit.text("", 16, Kit.INK, names, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.clip_text = true
	status_label = Kit.text("", 12, Kit.GREY, names)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_holder = HBoxContainer.new()
	face_holder.custom_minimum_size.x = 64
	face_holder.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(face_holder)
	scroller = ScrollContainer.new()
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroller)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	scroller.add_child(pad)
	messages = VBoxContainer.new()
	messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	messages.add_theme_constant_override("separation", 6)
	pad.add_child(messages)
	var foot := PanelContainer.new()
	var foot_box := Kit.box(Color(0.97, 0.97, 0.98))
	foot_box.content_margin_left = 10
	foot_box.content_margin_right = 10
	foot_box.content_margin_top = 6
	foot_box.content_margin_bottom = BOTTOM_SPACE + 6
	foot_box.border_width_top = 1
	foot_box.border_color = Kit.LINE
	foot.add_theme_stylebox_override("panel", foot_box)
	stack.add_child(foot)
	var foot_stack := VBoxContainer.new()
	foot_stack.add_theme_constant_override("separation", 6)
	foot.add_child(foot_stack)
	replies = VBoxContainer.new()
	replies.add_theme_constant_override("separation", 5)
	foot_stack.add_child(replies)
	var input := HBoxContainer.new()
	input.add_theme_constant_override("separation", 8)
	foot_stack.add_child(input)
	Kit.text("+", 26, Kit.GREY, input)
	var field := PanelContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field_box := Kit.box(Color.WHITE, 17, 1, Kit.LINE)
	field_box.content_margin_left = 14
	field_box.content_margin_top = 7
	field_box.content_margin_bottom = 7
	field.add_theme_stylebox_override("panel", field_box)
	input_hint = Kit.text("Tin nhắn", 15, Kit.GREY, field)
	input.add_child(field)
	var mic := Kit.text("◉", 22, Kit.GREY, input)
	mic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func open_thread(id: String) -> void:
	open_id = id
	var thread: Dictionary = threads[id]
	thread.unread = 0
	list_page.hide()
	chat_page.show()
	title_label.text = thread.title
	status_label.text = thread.status
	status_label.add_theme_color_override("font_color", Kit.GREY)
	for child in face_holder.get_children():
		child.queue_free()
	face_holder.add_child(Kit.avatar(thread.avatar, thread.initial, 38))
	scrambled.clear()
	typing_row = null
	for child in messages.get_children():
		child.queue_free()
	for entry in thread.log:
		_add_bubble(entry, false)
	_to_bottom()
	unread_changed.emit()
	thread_opened.emit(id)

func viewing(id: String) -> bool:
	return open_id == id and chat_page.visible and is_visible_in_tree()

func _to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scroller.scroll_vertical = int(scroller.get_v_scroll_bar().max_value)

# True when it landed in the chat on screen; otherwise it waits as unread.
func receive(id: String, text: String, garbled := false) -> bool:
	var thread: Dictionary = threads[id]
	var entry := {"text": text, "mine": false, "garbled": garbled, "time": clock.call()}
	thread.log.append(entry)
	order.erase(id)
	order.push_front(id)
	if viewing(id):
		_add_bubble(entry, true)
		_to_bottom()
		return true
	thread.unread += 1
	refresh_list()
	return false

func send_mine(id: String, text: String) -> void:
	var entry := {"text": text, "mine": true, "garbled": false, "time": clock.call()}
	threads[id].log.append(entry)
	if open_id == id:
		_add_bubble(entry, true)
		_to_bottom()

func set_typing(on: bool) -> void:
	if typing_row != null:
		typing_row.queue_free()
		typing_row = null
	if open_id == "":
		return
	status_label.text = "đang nhập…" if on else threads[open_id].status
	status_label.add_theme_color_override("font_color", ACCENT if on else Kit.GREY)
	if on:
		typing_row = _bubble_row({"text": "• • •", "mine": false, "garbled": false})
		messages.add_child(typing_row)
		_to_bottom()

func _noise(length: int) -> String:
	var result := ""
	for i in range(length):
		result += " " if rng.randf() < 0.14 else GLYPHS[rng.randi() % GLYPHS.length()]
	return result

# Group chats write "Name: text"; the name moves into the bubble, coloured per sender.
func _split_sender(entry: Dictionary) -> Array:
	var text: String = entry.text
	var colon := text.find(": ")
	if entry.mine or open_id == "" or not threads[open_id].status.contains(",") or colon < 1 or colon > 14:
		return ["", text]
	return [text.left(colon), text.substr(colon + 2)]

func _bubble_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if entry.mine else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	var bubble := PanelContainer.new()
	var style := Kit.box(MINE if entry.mine else THEIRS, 16)
	if entry.garbled:
		style.bg_color = Color(0.12, 0.13, 0.15)
	if entry.mine:
		style.corner_radius_bottom_right = 4
	else:
		style.corner_radius_bottom_left = 4
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 6
	style.content_margin_bottom = 5
	style.shadow_color = Color(0, 0, 0, 0.08)
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 1)
	bubble.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	bubble.add_child(column)
	var parts := _split_sender(entry)
	if not parts[0].is_empty():
		Kit.text(parts[0], 13, SENDER_COLOURS[absi(String(parts[0]).hash()) % SENDER_COLOURS.size()], column, true)
	var words: String = parts[1]
	var label := Kit.text(words, 15, Color(0.86, 0.84, 0.82) if entry.garbled else Kit.INK, column)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = clampf(words.length() * 8.4 + 6.0, 64.0, BUBBLE_WIDTH)
	var stamp: String = entry.get("time", "")
	if not stamp.is_empty():
		var time_label := Kit.text(stamp + ("  ✓✓" if entry.mine else ""), 11, Color(0.3, 0.6, 0.3) if entry.mine else Kit.GREY, column)
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(bubble)
	if entry.garbled:
		scrambled.append({"label": label, "length": words.length()})
	return row

func _add_bubble(entry: Dictionary, animate: bool) -> void:
	var row := _bubble_row(entry)
	messages.add_child(row)
	if typing_row != null:
		messages.move_child(typing_row, -1)
	if animate:
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.2)

# Answers sit where the keyboard would, as the chat app's quick-reply buttons.
func offer_replies(options: Array) -> void:
	clear_replies()
	input_hint.text = "Chọn câu trả lời"
	for i in range(options.size()):
		var button := Button.new()
		button.text = options[i]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", ACCENT.darkened(0.2))
		button.add_theme_color_override("font_hover_color", ACCENT.darkened(0.4))
		var chip := Kit.box(Color.WHITE, 10, 1, Kit.LINE)
		chip.set_content_margin_all(9)
		var hover := Kit.box(Color(0.93, 0.96, 1.0), 10, 1, ACCENT)
		hover.set_content_margin_all(9)
		button.add_theme_stylebox_override("normal", chip)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", chip)
		button.pressed.connect(func(): reply_chosen.emit(i))
		replies.add_child(button)

func clear_replies() -> void:
	input_hint.text = "Tin nhắn"
	for child in replies.get_children():
		child.queue_free()

func _process(delta: float) -> void:
	scramble_clock -= delta
	if scramble_clock > 0.0:
		return
	scramble_clock = 0.09
	for item in scrambled:
		if is_instance_valid(item.label):
			item.label.text = _noise(item.length)
