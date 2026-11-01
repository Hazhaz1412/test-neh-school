extends Control
# Fiducials around the view: seeing any one of them tells the phone where the whole screen is.
const SOURCE := "res://assets/lens/markers.json"
const SIDE := 112.0
const QUIET := 12.0
const MARGIN := 16.0
# Dim enough to read as grime on a dark scene; a phone's adaptive threshold still finds it.
const LIGHT := Color(0.5, 0.5, 0.5)
const GATE_INK := Color(0.55, 0.92, 0.82)
# The top and bottom middle markers would sit on the rotating gate.
const GATE_HIDDEN := [1, 5]
var bits: Array = []
var grid := 6
var gate := false
var progress := 0.0
var reveal := 0.0
var backdrop: ColorRect
var tween: Tween

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	grid = int(data.size)
	bits = data.markers
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop = ColorRect.new()
	backdrop.show_behind_parent = true
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/materials/lens_gate.gdshader")
	backdrop.material = material
	backdrop.visible = false
	add_child(backdrop)

# Top-left corners of the black squares, clockwise from the top-left of the view.
func placements() -> Array[Vector2]:
	var inset := MARGIN + QUIET
	var far := size - Vector2.ONE * (SIDE + inset)
	var middle := (size - Vector2.ONE * SIDE) * 0.5
	return [Vector2(inset, inset), Vector2(middle.x, inset), Vector2(far.x, inset), Vector2(far.x, middle.y),
		Vector2(far.x, far.y), Vector2(middle.x, far.y), Vector2(inset, far.y), Vector2(inset, middle.y)]

func layout() -> Dictionary:
	var entries := []
	var spots := placements()
	for index in range(bits.size()):
		entries.append({"id": bits[index].id, "x": spots[index].x, "y": spots[index].y, "size": SIDE})
	return {"type": "lens_layout", "width": size.x, "height": size.y, "markers": entries}

func show_gate(enabled: bool) -> void:
	if tween != null:
		tween.kill()
	gate = enabled
	reveal = 0.0
	progress = 0.0
	if enabled:
		_set_shader("finish", 0.0)
		tween = create_tween()
		tween.tween_method(_set_reveal, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sync_backdrop()
	queue_redraw()

# Markers vanish at once; the gate then bursts open over the game.
func play_open(done: Callable) -> void:
	if tween != null:
		tween.kill()
	reveal = 0.0
	queue_redraw()
	tween = create_tween()
	tween.tween_method(func(value: float): _set_shader("finish", value), 0.0, 1.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		gate = false
		_sync_backdrop()
		queue_redraw()
		done.call())

func set_progress(value: float) -> void:
	progress = value
	_set_shader("progress", value)
	queue_redraw()

func _set_reveal(value: float) -> void:
	reveal = value
	queue_redraw()

func _set_shader(key: String, value: float) -> void:
	backdrop.material.set_shader_parameter(key, value)

func _sync_backdrop() -> void:
	backdrop.visible = gate
	_set_shader("aspect", size.x / maxf(size.y, 1.0))
	_set_shader("progress", progress)

func _marker(at: Vector2, code: String, ink: Color) -> void:
	var cell := SIDE / (grid + 2)
	draw_rect(Rect2(at - Vector2.ONE * QUIET, Vector2.ONE * (SIDE + QUIET * 2)), ink)
	draw_rect(Rect2(at, Vector2.ONE * SIDE), Color.BLACK)
	for y in range(grid):
		for x in range(grid):
			if code[y * grid + x] == "1":
				draw_rect(Rect2(at + Vector2(x + 1, y + 1) * cell, Vector2.ONE * cell), ink)

func _draw_centre() -> void:
	var font := ThemeDB.fallback_font
	var centre := size * 0.5
	var label := "%d%%" % roundi(progress * 100.0)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	draw_string(font, centre + Vector2(-width * 0.5, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.86, 1.0, 0.95))
	var hint := "RÀ THIẾT BỊ CHẬM QUA MÀN HÌNH"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(centre.x - hint_width * 0.5, size.y - 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.9, 0.84, reveal))

func _draw() -> void:
	var spots := placements()
	var shown := reveal if gate else 1.0
	if shown > 0.0:
		for index in range(bits.size()):
			var grow := SIDE * 0.5
			var pivot := spots[index] + Vector2.ONE * grow
			if gate and index in GATE_HIDDEN:
				continue
			# Ends at exactly 1: the phone measures against the true marker size.
			draw_set_transform(pivot, 0.0, Vector2.ONE * shown)
			_marker(Vector2.ONE * -grow, bits[index].bits, GATE_INK if gate else LIGHT)
		draw_set_transform(Vector2.ZERO)
	if gate and reveal > 0.0:
		_draw_centre()
