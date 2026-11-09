extends Control
# A list that scrolls like a phone's: drag it with the mouse (or a finger), fling it and it keeps
# gliding, pull past either end and it stretches and springs back. The wheel flings it too. A thin
# bar shows where you are only while it moves. A drag never counts as a tap on what it started on.
signal scrolled(offset: float)
# Past this many pixels a press becomes a drag.
const DRAG_START := 7.0
# How fast a fling dies out, per second; the larger, the sooner it stops.
const FRICTION := 3.2
# How much one wheel notch adds to the glide, in px/s.
const WHEEL_KICK := 900.0
const MAX_SPEED := 5200.0
# Pulling past an end moves the list this much less than the hand.
const STRETCH := 0.42
const SPRING := 15.0
const BAR_WIDTH := 4.0
var content := VBoxContainer.new()
# Drawn above the content, so the bar is never hidden under a card.
var bar := Control.new()
var offset := 0.0
var velocity := 0.0
var pressed := false
var dragging := false
var press_at := Vector2.ZERO
var last_at := Vector2.ZERO
var samples: Array = []
var bar_alpha := 0.0
var bar_tint := Color(0, 0, 0, 0.35)
# A press that only stopped a fling: it must not tap whatever is under it.
var caught := false
# Lets the owner keep a press for itself (a swipe from the phone's bottom bar).
var ignore_press: Callable = func(_at: Vector2) -> bool: return false

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 0)
	add_child(content)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.draw.connect(_draw_bar)
	add_child(bar)

func _ready() -> void:
	resized.connect(_layout)
	content.minimum_size_changed.connect(_layout)
	_layout()

func max_offset() -> float:
	return maxf(0.0, content.get_combined_minimum_size().y - size.y)

func at_end(margin := 4.0) -> bool:
	return offset >= max_offset() - margin

func scroll_to_end(animated := true) -> void:
	await get_tree().process_frame
	_layout()
	if animated and is_visible_in_tree():
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_offset, offset, max_offset(), 0.3)
	else:
		_set_offset(max_offset())

func scroll_to_top() -> void:
	velocity = 0.0
	_set_offset(0.0)

func _set_offset(value: float) -> void:
	offset = value
	_layout()
	scrolled.emit(offset)

func _layout() -> void:
	content.size = Vector2(size.x, maxf(size.y, content.get_combined_minimum_size().y))
	content.position = Vector2(0.0, -roundf(offset))

func _local(at: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * at

func _inside(at: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_local(at))

# Read before the buttons inside, so a drag can be told from a tap.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		pressed = false
		dragging = false
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and _inside(event.position) and not ignore_press.call(Vector2(-INF, -INF)):
			var notch := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			velocity = clampf(velocity + notch * WHEEL_KICK * maxf(event.factor, 1.0), -MAX_SPEED, MAX_SPEED)
			bar_alpha = 1.0
			get_viewport().set_input_as_handled()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed and _inside(event.position) and not ignore_press.call(event.position):
			pressed = true
			dragging = false
			caught = absf(velocity) > 220.0
			velocity = 0.0
			press_at = _local(event.position)
			last_at = press_at
			samples = [[Time.get_ticks_msec(), press_at.y]]
			if caught:
				get_viewport().set_input_as_handled()
		elif not event.pressed and pressed:
			pressed = false
			if dragging:
				dragging = false
				velocity = clampf(_release_speed(), -MAX_SPEED, MAX_SPEED)
				get_viewport().set_input_as_handled()
			elif caught:
				get_viewport().set_input_as_handled()
			caught = false
	elif event is InputEventMouseMotion and pressed:
		var at := _local(event.position)
		if not dragging and absf(at.y - press_at.y) > DRAG_START:
			dragging = true
			last_at = at
		if dragging:
			var step := at.y - last_at.y
			last_at = at
			# Past an end the list follows the hand less and less.
			var resist := STRETCH if offset < 0.0 or offset > max_offset() else 1.0
			_set_offset(offset - step * resist)
			samples.append([Time.get_ticks_msec(), at.y])
			while samples.size() > 6:
				samples.pop_front()
			bar_alpha = 1.0
			get_viewport().set_input_as_handled()

# The speed of the last ~80 ms of the drag, in px/s, as the glide to carry on with.
func _release_speed() -> float:
	var now := Time.get_ticks_msec()
	var first = null
	for sample in samples:
		if now - sample[0] <= 90:
			first = sample
			break
	if first == null or samples.is_empty():
		return 0.0
	var last: Array = samples[-1]
	var seconds := maxf(0.016, (last[0] - first[0]) / 1000.0)
	return -(last[1] - first[1]) / seconds

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var top := 0.0
	var bottom := max_offset()
	if not dragging:
		if offset < top or offset > bottom:
			# Out past an end: a glide is braked hard, then a spring pulls the list back.
			var edge := top if offset < top else bottom
			velocity *= exp(-SPRING * 1.6 * delta)
			_set_offset(edge + (offset - edge) * exp(-SPRING * delta) + velocity * delta)
			if absf(offset - edge) < 0.5 and absf(velocity) < 20.0:
				velocity = 0.0
				_set_offset(edge)
		elif absf(velocity) > 4.0:
			_set_offset(offset + velocity * delta)
			velocity *= exp(-FRICTION * delta)
		else:
			velocity = 0.0
	if not dragging and absf(velocity) < 4.0:
		bar_alpha = maxf(0.0, bar_alpha - delta * 1.6)
	bar.queue_redraw()

func _draw_bar() -> void:
	var total := content.get_combined_minimum_size().y
	if bar_alpha <= 0.0 or total <= size.y + 1.0:
		return
	var length := maxf(36.0, size.y * size.y / total)
	var travel := size.y - length - 8.0
	var shown := clampf(offset / maxf(1.0, max_offset()), 0.0, 1.0)
	# Squashed while stretched past an end, as phones do.
	var squash := clampf(1.0 - absf(offset - clampf(offset, 0.0, max_offset())) / 120.0, 0.35, 1.0)
	var rect := Rect2(size.x - BAR_WIDTH - 3.0, 4.0 + travel * shown, BAR_WIDTH, length * squash)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bar_tint, bar_tint.a * bar_alpha)
	style.set_corner_radius_all(int(BAR_WIDTH / 2))
	bar.draw_style_box(style, rect)
