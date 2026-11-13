extends CanvasLayer
# The camera the main character carries in the dream. Through it the dream shows how things were,
# and a photo can carry a thing from where it was taken to wherever it is put down.
#
# Render layers split the world in three: layer 1 is everything that is the same then and now,
# layer 2 (PAST) only existed back then, layer 3 (PRESENT) only exists now. The player's eye
# draws 1 + 3. The lens is a second Camera3D in a SubViewport that draws 1 + 2 and follows the
# player's eye every frame, so raising the camera (right mouse) shows the past from the same spot.
#
# Left mouse takes a photo: the SubViewport's texture is copied into an Image (render to texture).
# Two kinds of thing can be kept in it, if they are in the lens frustum at that moment:
#  - movable things (group "dream_movable", past or present). The photo stores each one's
#    transform relative to the lens: rel = lens^-1 * object.
#  - fixed things (groups "dream_past" / "dream_present" that are not movable), such as the gate.
# F holds the photo up over the view. While it is up the head keeps the tilt the photo was taken
# at, so the photo lies exactly over what it will become. Left mouse then puts it down:
#  - every movable thing is moved to eye * rel, the same place in the new view as it had in the
#    photo, and if it was only a memory it becomes real. From which side and how far a thing was
#    photographed decides how it lands, which is the puzzle.
#  - fixed things only take if the view matches the photo's own view (projected gap under
#    PLACE_PX): the past ones become real where they stood, the present ones in shot are gone.
signal photo_taken(photo: Dictionary)
signal photo_placed(photo: Dictionary)
const PAST := 2
const PRESENT := 3
const PLACE_PX := 16.0
const REFERENCE_WIDTH := 1280.0
const SHUTTER := preload("res://assets/audio/camera.wav")
const MEMORY := preload("res://assets/audio/memory.wav")

var eye: Camera3D
var viewport: SubViewport
var lens: Camera3D
var view: TextureRect
var held: TextureRect
var thumb: TextureRect
var frame: Control
var flash: ColorRect
var meter: Label
var tag: Label
var raised := false
var holding := false
var photo: Dictionary = {}
var flash_left := 0.0
var thumb_left := 0.0
# Set by dream_world: returns a 0..1 "how close" for the meter, or -1 when nothing to line up.
var meter_source: Callable
var meter_value := -1.0
var enabled := true
var shutter: AudioStreamPlayer
var chime: AudioStreamPlayer

static func put_on_layer(node: Node, layer: int) -> void:
	var nodes: Array = node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		nodes.append(node)
	for visual: VisualInstance3D in nodes:
		visual.layers = 1 << (layer - 1)

# A thing is either only a memory (seen through the lens, cannot be touched) or real.
static func make_past(node: Node3D) -> void:
	node.add_to_group("dream_past")
	put_on_layer(node, PAST)
	for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0

static func make_real(node: Node3D) -> void:
	node.remove_from_group("dream_past")
	put_on_layer(node, 1)
	for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 1

func setup(player_camera: Camera3D) -> void:
	eye = player_camera
	eye.cull_mask = 0xFFFFF & ~(1 << (PAST - 1))
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	lens = Camera3D.new()
	lens.cull_mask = 0xFFFFF & ~(1 << (PRESENT - 1))
	viewport.add_child(lens)
	view = TextureRect.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.texture = viewport.get_texture()
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.visible = false
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	held = TextureRect.new()
	held.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	held.stretch_mode = TextureRect.STRETCH_SCALE
	held.modulate = Color(1, 0.97, 0.92, 0.6)
	held.visible = false
	held.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(held)
	frame = Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	add_child(frame)
	meter = _label(Control.PRESET_TOP_RIGHT, Vector2(-270, 34), 18)
	tag = _label(Control.PRESET_TOP_LEFT, Vector2(40, 34), 18)
	thumb = TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	thumb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	thumb.offset_left = -250
	thumb.offset_top = -160
	thumb.offset_right = -30
	thumb.offset_bottom = -30
	thumb.visible = false
	add_child(thumb)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	shutter = AudioStreamPlayer.new()
	shutter.stream = SHUTTER
	shutter.volume_db = -6
	add_child(shutter)
	chime = AudioStreamPlayer.new()
	chime.stream = MEMORY
	chime.volume_db = -8
	add_child(chime)

func _label(preset: int, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset)
	label.position += at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.visible = false
	add_child(label)
	return label

func keeps_something() -> bool:
	return not photo.is_empty() and not (photo.movables.is_empty() and photo.fixed.is_empty())

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and holding:
			holding = false
		raised = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if raised:
			take()
		elif holding:
			place()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if keeps_something() and not raised:
			holding = not holding

func _process(delta: float) -> void:
	if eye == null:
		return
	lens.global_transform = eye.global_transform
	lens.fov = eye.fov
	lens.far = eye.far
	var size := get_viewport().get_visible_rect().size
	viewport.size = Vector2i(int(size.x / 2), int(size.y / 2))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if raised else SubViewport.UPDATE_DISABLED
	view.visible = raised
	held.visible = holding
	flash_left = maxf(flash_left - delta, 0.0)
	flash.color.a = flash_left / 0.35 * 0.85
	thumb_left = maxf(thumb_left - delta, 0.0)
	# The photo in hand stays in the corner for as long as it is carrying something.
	thumb.visible = not holding and not raised and (thumb_left > 0.0 or keeps_something())
	thumb.modulate.a = 0.92 if keeps_something() else clampf(thumb_left, 0.0, 1.0)
	meter.visible = false
	meter_value = -1.0
	tag.visible = raised or holding
	if raised:
		tag.text = "NGÀY ẤY"
		var closeness: float = meter_source.call() if meter_source.is_valid() else -1.0
		if closeness >= 0.0:
			meter.visible = true
			meter.text = "Độ khớp"
			meter_value = closeness
	elif holding:
		if not photo.movables.is_empty():
			tag.text = "Chuột trái · đặt xuống đúng như trong ảnh"
		else:
			var error := place_error()
			tag.text = "Đưa ảnh cho khớp với cảnh rồi bấm chuột trái" if error > PLACE_PX else "Khớp rồi · chuột trái để dán ảnh"
			meter.visible = true
			meter.text = "Độ khớp"
			meter_value = clampf(1.0 - (error - PLACE_PX) / 160.0, 0.0, 1.0)
	frame.queue_redraw()

func _draw_frame() -> void:
	if not (raised or holding):
		return
	var size := frame.size
	var ink := Color(1, 1, 1, 0.85)
	if holding and (not photo.movables.is_empty() or place_error() <= PLACE_PX):
		ink = Color(1.0, 0.82, 0.55, 1.0)
	var m := 28.0
	var arm := Vector2(size.x * 0.08, size.y * 0.12)
	var a := Vector2(m, m)
	var b := size - Vector2(m, m)
	for corner in [a, Vector2(b.x, a.y), Vector2(a.x, b.y), b]:
		var sx := 1.0 if corner.x < size.x / 2 else -1.0
		var sy := 1.0 if corner.y < size.y / 2 else -1.0
		frame.draw_line(corner, corner + Vector2(arm.x * sx, 0), ink, 3.0)
		frame.draw_line(corner, corner + Vector2(0, arm.y * sy), ink, 3.0)
	if meter_value >= 0.0:
		# Ten cells next to the "Độ khớp" label, filled as the view comes into line.
		var origin := Vector2(size.x - 170, 40)
		for i in range(10):
			var cell := Rect2(origin + Vector2(i * 13, 0), Vector2(10, 14))
			frame.draw_rect(cell, ink if i < int(round(meter_value * 10)) else Color(1, 1, 1, 0.25))
	var c := size / 2
	frame.draw_line(c - Vector2(10, 0), c + Vector2(10, 0), ink, 2.0)
	frame.draw_line(c - Vector2(0, 10), c + Vector2(0, 10), ink, 2.0)

func _anchor(node: Node3D) -> Vector3:
	# A node can name the point that has to be in shot (meta "anchor", local); else its origin.
	return node.to_global(node.get_meta("anchor", Vector3.ZERO))

func take() -> void:
	shutter.play()
	flash_left = 0.35
	# The lens has been drawing every frame while raised; its latest frame is the photo.
	var image := viewport.get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	var shot := eye.global_transform
	var movables: Array[Node3D] = []
	var relative: Array[Transform3D] = []
	for node: Node3D in get_tree().get_nodes_in_group("dream_movable"):
		# What the photographer is standing on stays where it is: otherwise one board could
		# carry its own rider across anything.
		if _in_frustum(_anchor(node)) and not _stands_on(node):
			movables.append(node)
			relative.append(shot.affine_inverse() * node.global_transform)
	var fixed: Array[Node3D] = []
	var anchors: Array[Vector3] = []
	for node: Node3D in get_tree().get_nodes_in_group("dream_past") + get_tree().get_nodes_in_group("dream_present"):
		if not node.is_in_group("dream_movable") and _in_frustum(_anchor(node)):
			fixed.append(node)
			anchors.append(_anchor(node))
	photo = {"texture": texture, "transform": shot, "fov": eye.fov, "pitch": eye.rotation.x,
		"movables": movables, "relative": relative, "fixed": fixed, "anchors": anchors}
	held.texture = texture
	thumb.texture = texture
	thumb_left = 3.0
	holding = false
	photo_taken.emit(photo)

func _stands_on(node: Node3D) -> bool:
	if not node.has_meta("footprint"):
		return false
	var half: Vector2 = node.get_meta("footprint")
	var local := node.to_local(eye.global_position)
	return absf(local.x) < half.x and absf(local.z) < half.y and local.y > 0.0 and local.y < 2.6

func _in_frustum(point: Vector3) -> bool:
	if eye.is_position_behind(point):
		return false
	var p := eye.unproject_position(point)
	var size := get_viewport().get_visible_rect().size
	return p.x > 0 and p.y > 0 and p.x < size.x and p.y < size.y

# How far, in reference pixels, the eye's view is from the photo's view, judged on the fixed
# things the photo kept plus points a few metres in front of its lens: far points alone forgive
# standing in the wrong place (only turning shows on them), near ones give a step aside away.
func place_error() -> float:
	if photo.is_empty():
		return INF
	var shot: Transform3D = photo.transform
	var anchors: Array[Vector3] = photo.anchors.duplicate()
	for d in [3.0, 6.0, 12.0]:
		anchors.append(shot.origin - shot.basis.z * d)
	var size := get_viewport().get_visible_rect().size
	var ghost := Camera3D.new()
	ghost.fov = photo.fov
	add_child(ghost)
	ghost.global_transform = shot
	var total := 0.0
	for point in anchors:
		if eye.is_position_behind(point):
			total += 400.0
			continue
		var a := eye.unproject_position(point)
		var b := ghost.unproject_position(point)
		total += minf(a.distance_to(b), 400.0)
	ghost.queue_free()
	return total / anchors.size() * (REFERENCE_WIDTH / size.x)

func place() -> void:
	if not keeps_something():
		return
	var matched := place_error() <= PLACE_PX
	if photo.movables.is_empty() and not matched:
		return
	holding = false
	chime.play()
	flash_left = 0.35
	var now := eye.global_transform
	for i in range(photo.movables.size()):
		var node: Node3D = photo.movables[i]
		if not is_instance_valid(node) or not node.is_in_group("dream_movable"):
			continue
		node.global_transform = (now * photo.relative[i]).orthonormalized()
		if node.is_in_group("dream_past"):
			make_real(node)
	if matched:
		for node: Node3D in photo.fixed:
			if not is_instance_valid(node):
				continue
			if node.is_in_group("dream_past"):
				make_real(node)
			elif node.is_in_group("dream_present"):
				node.remove_from_group("dream_present")
				node.visible = false
				for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
					body.collision_layer = 0
	var placed := photo
	placed["matched"] = matched
	photo = {}
	thumb_left = 0.0
	photo_placed.emit(placed)
