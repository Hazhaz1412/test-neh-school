extends Control
# The back-alley shop: a dark ledger of what it sells and what the demon pawned.
const Gear := preload("res://scripts/night_gear.gd")
const PAPER := Color(0.91, 0.84, 0.68)
const BRASS := Color(0.86, 0.66, 0.28)
const FADED := Color(0.62, 0.56, 0.46)
var gear: Dictionary
var on_close: Callable
var money: Label
var note: Label
var list: VBoxContainer

func setup(state: Dictionary, close: Callable) -> void:
	gear = state
	on_close = close
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.012, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.045, 0.98)
	style.border_color = Color(0.42, 0.28, 0.14)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _text("TIỆM KHÔNG TÊN", 28, BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	money = _text("", 22, PAPER)
	head.add_child(money)
	column.add_child(_text("“Mua gì thì mua. Đêm nay nó không chờ cậu đâu.”", 16, FADED))
	column.add_child(HSeparator.new())
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	column.add_child(list)
	column.add_child(HSeparator.new())
	note = _text("", 15, Color(0.92, 0.46, 0.34))
	column.add_child(note)
	var leave := _button("Rời tiệm · Esc")
	leave.pressed.connect(func(): on_close.call())
	column.add_child(leave)
	refresh()

func _text(content: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if size_px < 18 else TextServer.AUTOWRAP_OFF
	return label

func _button(content: String) -> Button:
	var button := Button.new()
	button.text = content
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size = Vector2(150, 38)
	return button

func _row(title: String, detail: String, action: String, press: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	list.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_text(title, 19, PAPER))
	words.add_child(_text(detail, 14, FADED))
	row.add_child(words)
	var button := _button(action)
	button.pressed.connect(press)
	row.add_child(button)

func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	money.text = "%d$ · Túi %d/%d" % [gear.money, gear.bag.size(), Gear.BAG_ROOM]
	for entry in Gear.STOCK:
		if entry.kind == "torch" and gear.torch:
			_row(entry.name, "Đang dùng.", "Đã có", func(): pass)
		else:
			_row(entry.name, entry.text, "Mua · %d$" % entry.price, _buy.bind(entry.kind))
	var names := {"medal": "Huy chương mạ", "camera": "Máy ảnh"}
	for kind in gear.pawned:
		_row("%s của cậu" % names.get(kind, kind), "Sáng nay có kẻ đem cầm ở đây. Đừng hỏi là ai.", "Chuộc · %d$" % Gear.redeem_price(kind), _redeem.bind(kind))

func _buy(kind: String) -> void:
	note.text = Gear.buy(gear, kind)
	refresh()

func _redeem(kind: String) -> void:
	note.text = Gear.redeem(gear, kind)
	refresh()
