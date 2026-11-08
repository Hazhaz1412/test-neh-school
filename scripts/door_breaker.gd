extends Control

# Close-up of the technical room's lock plate, held on by four screws. Hold the left button on a
# screw and circle the mouse round it: three full turns back it out (either way round, but going
# back undoes it). With all four out the plate drops and the door has to be kicked in: every
# press of SPACE (or the left button) is a kick, and the push fades if the kicks slow down.
signal ticked(index: int)
signal screw_out(index: int)
signal screws_done
signal kicked(power: float)
signal burst_open

const TURNS := 3.0
const HEAD := 24.0
const GRAB := 52.0
# Circle further out than this and the screwdriver slips off the screw.
const SLIP := 230.0
const DEAD_ZONE := 12.0
const KICK_GAIN := 0.075
const KICK_DECAY := 0.22
const TICK_ANGLE := PI / 3.0
var step := ""
var turned: Array[float] = [0.0, 0.0, 0.0, 0.0]
var removed: Array[bool] = [false, false, false, false]
var held := -1
var last_angle := 0.0
var in_dead_zone := true
var ticks: Array[int] = [0, 0, 0, 0]
var popped: Array[float] = [0.0, 0.0, 0.0, 0.0]
var power := 0.0
var kick_flash := 0.0
var plate_drop := 0.0
var scratches: Array = []
var title: Label
var help: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(30, Color(1.0, 0.86, 0.66), true)
	add_child(title)
	help = _label(18, Color(0.92, 0.88, 0.8), false)
	add_child(help)
	var dice := RandomNumberGenerator.new()
	dice.seed = 1302
	for i in range(26):
		scratches.append([Vector2(dice.randf(), dice.randf()), dice.randf_range(-0.5, 0.5), dice.randf_range(0.04, 0.16), dice.randf_range(0.05, 0.16)])
	hide()

func _label(font_size: int, color: Color, heading: bool) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heading: label.add_theme_font_override("font", preload("res://scripts/horror_type.gd").TITLE)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8 if heading else 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func begin() -> void:
	step = "screws"
	for i in range(4):
		turned[i] = 0.0
		removed[i] = false
		ticks[i] = 0
		popped[i] = 0.0
	held = -1
	power = 0.0
	plate_drop = 0.0
	kick_flash = 0.0
	show()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN

func close() -> void:
	step = ""
	held = -1
	hide()

func plate_size() -> float:
	return clampf(size.y * 0.52, 280.0, 440.0)

func plate_center() -> Vector2:
	return size * 0.5 + Vector2(0, 10)

func screw_center(index: int) -> Vector2:
	var half := plate_size() * 0.5 - 56.0
	return plate_center() + Vector2(half * (-1.0 if index % 2 == 0 else 1.0), half * (-1.0 if index < 2 else 1.0))

func progress(index: int) -> float:
	return 1.0 if removed[index] else clampf(absf(turned[index]) / (TAU * TURNS), 0.0, 1.0)

func screws_left() -> int:
	return removed.count(false)

func screw_at(point: Vector2) -> int:
	for i in range(4):
		if not removed[i] and point.distance_to(screw_center(i)) < GRAB: return i
	return -1

func engage(index: int, point: Vector2) -> bool:
	if step != "screws" or index < 0 or removed[index]: return false
	held = index
	var offset := point - screw_center(index)
	in_dead_zone = offset.length() < DEAD_ZONE
	last_angle = offset.angle()
	return true

func release() -> void:
	held = -1

# The mouse moved to `point` while holding a screw.
func drag(point: Vector2) -> void:
	if held < 0: return
	var offset := point - screw_center(held)
	if offset.length() > SLIP:
		held = -1
		return
	if offset.length() < DEAD_ZONE:
		in_dead_zone = true
		return
	var angle := offset.angle()
	if in_dead_zone:
		in_dead_zone = false
	else:
		turn(held, wrapf(angle - last_angle, -PI, PI))
	last_angle = angle

func turn(index: int, radians: float) -> void:
	if step != "screws" or removed[index]: return
	turned[index] += radians
	var notches := int(absf(turned[index]) / TICK_ANGLE)
	if notches > ticks[index]:
		ticks[index] = notches
		ticked.emit(index)
	if absf(turned[index]) >= TAU * TURNS:
		removed[index] = true
		popped[index] = 1.0
		if held == index: held = -1
		screw_out.emit(index)
		if screws_left() == 0:
			step = "kick"
			plate_drop = 0.001
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
			screws_done.emit()

func kick() -> bool:
	if step != "kick": return false
	power = minf(1.0, power + KICK_GAIN)
	kick_flash = 1.0
	kicked.emit(power)
	if power >= 1.0:
		step = "open"
		burst_open.emit()
	return true

func _input(event: InputEvent) -> void:
	if not visible or step == "" or step == "open": return
	if step == "screws":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: engage(screw_at(get_local_mouse_position()), get_local_mouse_position())
			else: release()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			drag(get_local_mouse_position())
			get_viewport().set_input_as_handled()
	elif step == "kick":
		var press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_E]: press = true
		if press:
			kick()
			get_viewport().set_input_as_handled()

# Called by the escape while the game runs, so the push does not fade during a pause.
func tick(delta: float) -> void:
	if step == "kick": power = maxf(0.0, power - KICK_DECAY * delta)

func _process(delta: float) -> void:
	if not visible: return
	kick_flash = maxf(0.0, kick_flash - delta * 6.0)
	if plate_drop > 0.0: plate_drop = minf(1.0, plate_drop + delta * 2.2)
	for i in range(4): popped[i] = maxf(0.0, popped[i] - delta * 2.5)
	var plate := plate_size()
	if step == "screws":
		title.text = "THÁO 4 CON VÍT"
		help.text = "Giữ chuột trái lên một con vít rồi xoay chuột thành vòng tròn quanh nó · 3 vòng mỗi con · còn %d con" % screws_left()
		title.position = Vector2(plate_center().x - 300, plate_center().y - plate * 0.5 - 70)
		help.position = Vector2(plate_center().x - 330, plate_center().y + plate * 0.5 + 16)
	else:
		title.text = "ĐẠP TUNG CỬA!"
		help.text = "Nhấn SPACE liên tục thật nhanh · chậm tay là cửa đứng lại"
		title.position = Vector2(size.x * 0.5 - 300, size.y - 196)
		help.position = Vector2(size.x * 0.5 - 330, size.y - 104)
	title.size = Vector2(600, 44)
	help.size = Vector2(660, 60)
	queue_redraw()

func _draw() -> void:
	if step == "screws" or plate_drop > 0.0 and plate_drop < 1.0:
		_draw_plate()
	if step == "kick" or step == "open":
		_draw_kick_meter()

func _draw_plate() -> void:
	var drop := plate_drop * plate_drop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5 * (1.0 - drop)))
	var plate := plate_size()
	var center := plate_center() + Vector2(0, drop * size.y * 0.9)
	draw_set_transform(center, drop * 0.6, Vector2.ONE)
	var rect := Rect2(Vector2(-plate, -plate) * 0.5, Vector2(plate, plate))
	# Door steel behind the plate, then the plate with a bevel.
	draw_rect(rect.grow(26), Color(0.17, 0.21, 0.2))
	draw_rect(rect, Color(0.42, 0.44, 0.43))
	draw_rect(Rect2(rect.position, Vector2(plate, 5)), Color(0.62, 0.64, 0.62))
	draw_rect(Rect2(rect.position, Vector2(5, plate)), Color(0.58, 0.6, 0.58))
	draw_rect(Rect2(rect.position + Vector2(0, plate - 6), Vector2(plate, 6)), Color(0.2, 0.21, 0.21))
	draw_rect(Rect2(rect.position + Vector2(plate - 6, 0), Vector2(6, plate)), Color(0.22, 0.23, 0.23))
	for scratch in scratches:
		var from: Vector2 = rect.position + scratch[0] * plate
		var along: Vector2 = Vector2.from_angle(scratch[1]) * scratch[2] * plate
		draw_line(from, from + along, Color(0.7, 0.72, 0.7, scratch[3]), 1.0)
	for spot in [[Vector2(0.78, 0.2), 30.0], [Vector2(0.22, 0.72), 22.0], [Vector2(0.65, 0.86), 16.0]]:
		draw_circle(rect.position + spot[0] * plate, spot[1], Color(0.45, 0.24, 0.12, 0.28))
	# The lock body and its keyhole in the middle.
	var body := Rect2(Vector2(-plate * 0.17, -plate * 0.22), Vector2(plate * 0.34, plate * 0.44))
	draw_rect(body, Color(0.24, 0.25, 0.25))
	draw_rect(body, Color(0.12, 0.12, 0.12), false, 3.0)
	draw_circle(Vector2(0, -plate * 0.04), plate * 0.045, Color(0.03, 0.03, 0.03))
	draw_colored_polygon(PackedVector2Array([Vector2(-plate * 0.025, -plate * 0.02), Vector2(plate * 0.025, -plate * 0.02), Vector2(plate * 0.04, plate * 0.1), Vector2(-plate * 0.04, plate * 0.1)]), Color(0.03, 0.03, 0.03))
	draw_string(get_theme_default_font(), Vector2(-plate * 0.5, -plate * 0.36), "PHÒNG KỸ THUẬT · CẤM VÀO", HORIZONTAL_ALIGNMENT_CENTER, plate, 15, Color(0.85, 0.7, 0.3, 0.8))
	for i in range(4):
		_draw_screw(i, screw_center(i) - plate_center())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if step == "screws": _draw_cursor()

func _draw_screw(index: int, at: Vector2) -> void:
	if removed[index]:
		# Just the hole, and the screw jumping out of it for a moment.
		draw_circle(at, 9.0, Color(0.05, 0.05, 0.05))
		draw_arc(at, 11.0, 0, TAU, 24, Color(0.25, 0.25, 0.24), 2.0)
		if popped[index] > 0.0:
			var fly := (1.0 - popped[index])
			_draw_head(at + Vector2(fly * 70, -fly * 90 + fly * fly * 140), HEAD * (1.0 + fly * 0.3), fly * 9.0, popped[index])
		return
	var lift := progress(index)
	var hover: bool = held < 0 and get_local_mouse_position().distance_to(screw_center(index)) < GRAB
	draw_circle(at + Vector2(3, 4) * (1.0 + lift * 2.5), HEAD + lift * 3.0, Color(0, 0, 0, 0.45))
	_draw_head(at, HEAD + lift * 5.0, -turned[index], 1.0)
	draw_arc(at, HEAD + 16.0, 0, TAU, 48, Color(0, 0, 0, 0.5), 6.0)
	if lift > 0.0:
		draw_arc(at, HEAD + 16.0, -PI / 2, -PI / 2 + lift * TAU, 64, Color(1.0, 0.72, 0.25), 6.0)
	if held == index:
		# The circle to follow with the mouse.
		draw_arc(at, 90.0, 0, TAU, 64, Color(1, 1, 1, 0.16), 2.0)
		for k in range(8):
			var a := k * TAU / 8.0 - turned[index] * 0.25
			draw_circle(at + Vector2.from_angle(a) * 90.0, 3.0, Color(1, 0.85, 0.5, 0.5))
	elif hover:
		draw_arc(at, HEAD + 24.0, 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0)

func _draw_head(at: Vector2, radius: float, angle: float, alpha: float) -> void:
	draw_circle(at, radius, Color(0.55, 0.55, 0.52, alpha))
	draw_circle(at - Vector2(radius, radius) * 0.18, radius * 0.72, Color(0.7, 0.7, 0.66, alpha))
	draw_arc(at, radius, 0, TAU, 32, Color(0.25, 0.25, 0.23, alpha), 2.0)
	for turn in [0.0, PI / 2]:
		var dir := Vector2.from_angle(angle + turn) * radius * 0.62
		draw_line(at - dir, at + dir, Color(0.15, 0.15, 0.14, alpha), radius * 0.2)

# The screwdriver follows the mouse. On a screw its tip stays in the head and the handle swings
# round it like a crank, which shows what the circling does.
func _draw_cursor() -> void:
	var mouse := get_local_mouse_position()
	var tip := screw_center(held) if held >= 0 else mouse
	var handle := mouse if held >= 0 else mouse + Vector2(46, -46)
	if tip.distance_to(handle) < 30.0:
		var away := handle - tip
		handle = tip + (away.normalized() if away.length() > 0.01 else Vector2(0.7, -0.7)) * 30.0
	var dir := (handle - tip).normalized()
	var neck := handle - dir * 26.0
	draw_line(tip, neck, Color(0.08, 0.08, 0.08, 0.6), 9.0)
	draw_line(tip, neck, Color(0.78, 0.8, 0.82), 6.0)
	draw_line(neck, handle + dir * 22.0, Color(0.05, 0.05, 0.05), 20.0)
	draw_line(neck, handle + dir * 22.0, Color(0.95, 0.72, 0.1), 16.0)
	draw_line(neck + dir * 10.0, neck + dir * 16.0, Color(0.1, 0.1, 0.1), 16.0)
	draw_circle(tip, 3.5, Color(0.9, 0.9, 0.9))

func _draw_kick_meter() -> void:
	var width := minf(size.x - 80.0, 640.0)
	var bar := Rect2(Vector2(size.x * 0.5 - width * 0.5, size.y - 142), Vector2(width, 26))
	draw_rect(bar.grow(4), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(width * power, bar.size.y)), Color(1.0, 0.45 + kick_flash * 0.3, 0.15 + kick_flash * 0.3))
	for k in range(1, 10):
		var x := bar.position.x + width * k / 10.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.55), 2.0)
	draw_rect(bar, Color(1, 0.9, 0.7, 0.8), false, 2.0)
