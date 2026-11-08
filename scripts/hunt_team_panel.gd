extends Control
# The team strip: who is free, who is held and how long they have left, plus the rescue bar.
const INK := Color(0.77, 0.84, 0.81)
const ALARM := Color(0.95, 0.45, 0.35)
var team: Node
var refresh := 0.0

func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0.0:
		refresh = 0.1
		queue_redraw()

func _text(value: String, at: Vector2, color := INK, size := 15, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(get_theme_default_font(), at, value, align, width, size, color)

func _draw() -> void:
	if team == null or team.world.survival.finished:
		return
	var view := get_viewport_rect().size
	var top := Vector2(30, 176)
	draw_rect(Rect2(top - Vector2(10, 22), Vector2(250, 30 + team.members.size() * 34)), Color(0.02, 0.035, 0.04, 0.72))
	_text("ĐỘI · còn %d/%d" % [team.standing(), team.members.size()], top, Color(INK, 0.75), 13)
	for i in range(team.members.size()):
		var entry = team.members[i]
		var row := top + Vector2(0, 26 + i * 34)
		var held: bool = entry.status != team.Status.FREE
		var color := INK if not held else (ALARM if entry.status != team.Status.OUT else Color(0.45, 0.48, 0.5))
		_text(entry.title, row, color, 15)
		_text(team.STATUS_TEXT[entry.status], row + Vector2(92, 0), Color(color, 0.8), 13)
		var fill := clampf(entry.life / team.LIFE, 0.0, 1.0)
		draw_rect(Rect2(row + Vector2(0, 7), Vector2(220, 4)), Color(0.08, 0.12, 0.14, 0.9))
		draw_rect(Rect2(row + Vector2(0, 7), Vector2(220 * fill, 4)), color if held else Color(0.5, 0.72, 0.64))
		# Where one catch would cut the bar to.
		var after: float = (entry.life - team.CAPTURE_COST) / team.LIFE
		if not held and after > 0.0:
			draw_rect(Rect2(row + Vector2(220 * after, 5), Vector2(1, 8)), Color(INK, 0.5))
	var me = team.member(team.world.player)
	# Top centre: the guard's shout and the item bar own the bottom of the screen.
	var middle := Vector2(view.x * 0.5, 96)
	match me.status:
		team.Status.CARRIED:
			_text("BÁC BẢO VỆ ĐANG LÔI BẠN ĐI", middle + Vector2(-300, 0), ALARM, 24, HORIZONTAL_ALIGNMENT_CENTER, 600)
			_text("A / D liên tục, luân phiên · Vùng vẫy để thoát", middle + Vector2(-300, 26), Color(INK, 0.8), 15, HORIZONTAL_ALIGNMENT_CENTER, 600)
			var grip := Rect2(middle + Vector2(-150, 40), Vector2(300, 10))
			draw_rect(grip, Color(0.08, 0.12, 0.14, 0.9))
			draw_rect(Rect2(grip.position, Vector2(grip.size.x * me.struggle, grip.size.y)), Color(1.0, 0.8, 0.45))
			_text("KHÁNG CỰ", grip.position + Vector2(0, 28), Color(INK, 0.7), 12)
		team.Status.JAILED:
			_text("BỊ NHỐT · %d giây" % int(me.life), middle + Vector2(-300, 0), ALARM, 26, HORIZONTAL_ALIGNMENT_CENTER, 600)
			_text("Đi lại trong phòng được · Cửa đã khóa · Chờ đồng đội mở", middle + Vector2(-300, 26), Color(INK, 0.8), 15, HORIZONTAL_ALIGNMENT_CENTER, 600)
		team.Status.OUT:
			_text("BẠN ĐÃ BỊ LOẠI · TAB đổi người xem", middle + Vector2(-300, 0), Color(0.7, 0.72, 0.74), 20, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var hint: String = team.prompt()
	if not hint.is_empty():
		var door: Node3D = team.rescue_door_near(team.world.player.global_position)
		var bar := Rect2(Vector2(view.x * 0.5 - 130, view.y - 196), Vector2(260, 8))
		_text(hint, bar.position + Vector2(-70, -12), Color(1.0, 0.86, 0.62), 17, HORIZONTAL_ALIGNMENT_CENTER, 400)
		draw_rect(bar, Color(0.08, 0.12, 0.14, 0.9))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * team.rescue_fraction(door), bar.size.y)), Color(1.0, 0.8, 0.45))
