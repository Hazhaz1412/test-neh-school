extends Control
# Fake: the social app where Peter scrolls the town's rumours. Reaching the last post is
# what the evening waits for, so the end of the feed is reported once.
const Kit := preload("res://scripts/home/phone/phone_kit.gd")
const BRAND := Color(0.23, 0.35, 0.85)
const PAGE := Color(0.89, 0.90, 0.92)
const TOP_SPACE := 54
const AUTHOR_COLOURS := [Color(0.85, 0.42, 0.28), Color(0.30, 0.55, 0.80), Color(0.45, 0.62, 0.35), Color(0.62, 0.40, 0.70), Color(0.80, 0.60, 0.25), Color(0.35, 0.60, 0.62)]
signal feed_read
var feed_list: VBoxContainer
var feed_scroll: ScrollContainer
var feed_finished := false
var post_count := 0
var width := 0.0

func build(screen_width: float) -> void:
	width = screen_width
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := Panel.new()
	paper.add_theme_stylebox_override("panel", Kit.box(PAGE))
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper)
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 0)
	add_child(stack)
	stack.add_child(_header())
	feed_scroll = ScrollContainer.new()
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_scroll.get_v_scroll_bar().value_changed.connect(_scrolled)
	stack.add_child(feed_scroll)
	feed_list = VBoxContainer.new()
	feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_list.add_theme_constant_override("separation", 8)
	feed_scroll.add_child(feed_list)
	feed_list.add_child(_composer())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_posts.json"))
	post_count = data.posts.size()
	for post in data.posts:
		var group: Dictionary = data.groups.filter(func(g): return g.slug == post.group)[0]
		feed_list.add_child(_post(post, group.name))
	var tail := Kit.text("Bạn đã xem hết tin mới.", 13, Kit.GREY, feed_list)
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tail.custom_minimum_size.y = 70

func _header() -> PanelContainer:
	var head := PanelContainer.new()
	var style := Kit.box(Color.WHITE)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = TOP_SPACE
	style.content_margin_bottom = 8
	head.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	head.add_child(row)
	var logo := Kit.text("fake", 30, BRAND, row, true)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for glyph in ["+", "⌕"]:
		var circle := PanelContainer.new()
		circle.custom_minimum_size = Vector2(36, 36)
		circle.add_theme_stylebox_override("panel", Kit.box(Color(0.92, 0.93, 0.95), 18))
		var mark := Kit.text(glyph, 20, Kit.INK, circle, true)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(circle)
	return head

func _composer() -> PanelContainer:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.add_child(Kit.avatar(Color(0.42, 0.46, 0.52), "P", 40))
	var field := PanelContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := Kit.box(Color.WHITE, 20, 1, Kit.LINE)
	style.content_margin_left = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	field.add_theme_stylebox_override("panel", style)
	Kit.text("Bạn đang nghĩ gì?", 15, Kit.GREY, field)
	row.add_child(field)
	return card

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := Kit.box(Color.WHITE)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)
	return card

func _post(post: Dictionary, group: String) -> PanelContainer:
	var card := _card()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var author: String = post.author
	top.add_child(Kit.avatar(AUTHOR_COLOURS[absi(author.hash()) % AUTHOR_COLOURS.size()], author.left(1), 40))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	top.add_child(names)
	Kit.wrapped(group, 14, Kit.INK, names, width - 110, true)
	Kit.text("%s · %s" % [author, post.time], 12, Kit.GREY, names)
	Kit.wrapped(post.text, 15, Kit.INK, column, width - 26)
	var counts := HBoxContainer.new()
	column.add_child(counts)
	var reactions := Kit.text("♥ %s   ☠ %s" % [_short(post.love), _short(post.fear)], 13, Kit.GREY, counts)
	reactions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.text("%d bình luận" % post.comments.size(), 13, Kit.GREY, counts)
	var rule := ColorRect.new()
	rule.color = Kit.LINE
	rule.custom_minimum_size.y = 1
	column.add_child(rule)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for word in ["Thích", "Bình luận", "Chia sẻ"]:
		var action := Kit.text(word, 14, Color(0.40, 0.41, 0.45), actions, true)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for said in post.comments:
		column.add_child(_comment(said[0], said[1]))
	return card

func _comment(who: String, words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(Kit.avatar(AUTHOR_COLOURS[absi(who.hash()) % AUTHOR_COLOURS.size()], who.left(1), 30))
	var bubble := PanelContainer.new()
	var style := Kit.box(Color(0.94, 0.95, 0.96), 16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 7
	bubble.add_theme_stylebox_override("panel", style)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	bubble.add_child(lines)
	Kit.text(who, 13, Kit.INK, lines, true)
	Kit.wrapped(words, 14, Kit.INK, lines, minf(width - 110, words.length() * 7.6 + 8))
	row.add_child(bubble)
	return row

static func _short(count: int) -> String:
	return "%.1fK" % (count / 1000.0) if count >= 1000 else str(count)

func _scrolled(value: float) -> void:
	var bar := feed_scroll.get_v_scroll_bar()
	if value + bar.page >= bar.max_value - 4.0:
		finish_feed()

func finish_feed() -> void:
	if not feed_finished:
		feed_finished = true
		feed_read.emit()
