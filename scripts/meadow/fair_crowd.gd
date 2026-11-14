extends Node3D
# The people at the fair on the wall of the box (land_fold.gd): shadows in the shape of people,
# standing about in little groups chatting, watching the rides, and strolling up and down the way
# through the plaza. Each group says a few lines in turn, one speech bubble at a time over the
# speaker's head, then falls quiet for a while and says them again, as people at a fair do.
# A bubble only shows to someone standing close to the speaker (HEAR). The bodies are the town's MIT Rocketbox
# people (town_person.gd) drawn in shadow_figure.gdshader; they have no colliders.
# Built in the fair's own frame (y is the wall's up). Disabled until the fold is shown.
const Person := preload("res://scripts/town/town_person.gd")
const SHADOW := preload("res://assets/materials/shadow_figure.gdshader")
const BUBBLE := preload("res://assets/materials/speech_bubble.gdshader")
# Only someone standing close by hears (and sees) what a figure says.
const HEAR := 7.0
const PIXEL := 0.0042
const FONT_SIZE := 52
const WRAP := 480.0
const TAIL := 0.25
const ADULTS := ["Female_Adult_02", "Male_Adult_01", "Female_Adult_05", "Male_Adult_02", "Female_Adult_07", "Male_Adult_06", "Female_Adult_11", "Male_Adult_08", "Female_Adult_12", "Male_Adult_14"]
const KIDS := ["Male_Child_01", "Female_Child_01"]
# Each group: where it stands (fair-local), what it looks at when it is not talking (or null for
# each other), and its conversation as [who, line].
const GROUPS := [
	{"at": [Vector3(-17.5, 0, 21.5), Vector3(-15.8, 0, 22.6)], "lines": [[0, "Cậu cũng không ngủ được à?"], [1, "Ở đây có ai ngủ đâu."], [0, "Thế thì chơi thêm một trò nữa nhé."]]},
	{"at": [Vector3(8.2, 0, 3.0), Vector3(9.4, 0, 5.4), Vector3(7.0, 0, 5.6)], "look": Vector3(15, 0, 10), "lines": [[1, "Ngựa gỗ quay mãi không mỏi nhỉ."], [2, "Tớ ngồi con màu trắng cả trăm vòng rồi."], [0, "Lần nào cũng thấy như lần đầu."]]},
	{"at": [Vector3(-6.6, 0, 16.6), Vector3(-6.8, 0, 19.4)], "lines": [[0, "Bỏng ngô ở đây không bao giờ hết."], [1, "Mà cũng chẳng bao giờ thấy no."]]},
	{"at": [Vector3(-3.4, 0, -2.0), Vector3(-2.4, 0, 1.4), Vector3(-5.4, 0, 0.9), Vector3(-5.0, 0, -2.6)], "lines": [[0, "Nghe nói thắng hết các trò là được về."], [2, "Về đâu cơ?"], [1, "Về chỗ cái giường ấy."], [3, "Suỵt… nhạc sắp lặp lại rồi."]]},
	{"at": [Vector3(-17.5, 0, -3.2), Vector3(-16.0, 0, -2.2)], "look": Vector3(-27, 12, -12), "lines": [[0, "Vòng đu quay này chưa từng dừng."], [1, "Từ trên đỉnh nhìn thấy cả cái giường đấy."]]},
	{"at": [Vector3(-13.8, 0, 5.8), Vector3(-10.4, 0, 6.0)], "look": Vector3(-12, 2, 3), "lines": [[0, "Thử đập búa đi, dễ lắm."], [1, "Cậu nói câu đó mỗi đêm."]]},
	{"at": [Vector3(18.0, 0, -8.6), Vector3(21.4, 0, -8.0)], "lines": [[0, "Trong lều đang diễn gì thế?"], [1, "Vẫn tiết mục hôm qua."], [0, "Hôm qua là hôm nào nhỉ?"]]},
	{"at": [Vector3(-9.8, 0, 11.4), Vector3(-11.6, 0, 10.6)], "kids": true, "look": Vector3(-14, 4, 16), "lines": [[0, "Cho tớ lên đu quay với!"], [1, "Thêm một vòng nữa thôi!"]]},
	{"at": [Vector3(22.0, 0, 17.0), Vector3(23.6, 0, 18.8)], "lines": [[1, "Cậu là người mới phải không?"], [0, "Ai ở đây cũng từng là người mới."]]},
	{"at": [Vector3(-23.0, 0, 6.0), Vector3(-24.4, 0, 7.6)], "lines": [[0, "Có ai nhớ mình vào đây bằng cách nào không?"], [1, "Đi bộ thẳng từ cái giường lên thôi."]]},
	{"at": [Vector3(6.0, 0, -24.0), Vector3(4.6, 0, -25.4)], "lines": [[0, "Ngôi nhà trên kia lúc nào cũng sáng đèn."], [1, "Đừng nhìn lên lâu, chóng mặt lắm."]]},
]
# Strollers up and down the way through the plaza: [x, from z, to z, speed].
const STROLLS := [[-0.6, -26.0, 24.0, 1.1], [2.6, 24.0, -26.0, 0.9], [-1.2, 10.0, -20.0, 1.0], [3.4, -12.0, 20.0, 1.2]]

var people: Array[Node3D] = []
var bubbles: Array[Dictionary] = []
var talk: Array[Dictionary] = []
var walkers: Array[Dictionary] = []
var shadow: ShaderMaterial
var rng := RandomNumberGenerator.new()

func build() -> void:
	rng.seed = 707
	var adult := 0
	for g in range(GROUPS.size()):
		var group: Dictionary = GROUPS[g]
		var spots: Array = group.at
		var middle := Vector3.ZERO
		for spot: Vector3 in spots:
			middle += spot
		middle /= spots.size()
		var members: Array[int] = []
		for i in range(spots.size()):
			var kid: bool = group.get("kids", false)
			var look: String = KIDS[i % KIDS.size()] if kid else ADULTS[adult % ADULTS.size()]
			if not kid:
				adult += 1
			var height := rng.randf_range(1.15, 1.3) if kid else rng.randf_range(1.58, 1.86)
			var talking := not group.has("look") or i == 0
			var body := _person(look, height, "talk" if talking else "idle")
			body.position = spots[i]
			var toward: Vector3 = group.get("look", middle)
			if toward.distance_to(spots[i]) < 0.1:
				toward = spots[(i + 1) % spots.size()]
			var flat := Vector3(toward.x - spots[i].x, 0, toward.z - spots[i].z)
			body.rotation.y = atan2(flat.x, flat.z)
			members.append(people.size() - 1)
		talk.append({"members": members, "lines": group.lines, "at": 0, "wait": rng.randf_range(0.5, 6.0), "speaking": -1, "left": 0.0})
	for plan: Array in STROLLS:
		var body := _person(ADULTS[adult % ADULTS.size()], rng.randf_range(1.6, 1.84), "walk")
		adult += 1
		walkers.append({"node": body, "x": plan[0], "from": plan[1], "to": plan[2], "speed": plan[3], "t": rng.randf()})

func _person(look: String, height: float, motion: String) -> Node3D:
	var body: Node3D = Person.new()
	body.look = look
	body.height = height
	body.motion = motion
	add_child(body)
	var paint := ShaderMaterial.new()
	paint.shader = SHADOW
	paint.set_shader_parameter("seed", rng.randf())
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(surface, null)
		mesh.material_override = paint
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	people.append(body)
	bubbles.append(_bubble(body, height))
	return body

# A speech bubble over the head: a pale rounded box (speech_bubble.gdshader) and the words.
func _bubble(body: Node3D, height: float) -> Dictionary:
	var holder := Node3D.new()
	holder.position = Vector3(0, height + 0.75, 0)
	body.add_child(holder)
	var paint := ShaderMaterial.new()
	paint.shader = BUBBLE
	paint.set_shader_parameter("shown", 1.0)
	paint.render_priority = -10
	var quad := QuadMesh.new()
	var back := MeshInstance3D.new()
	back.mesh = quad
	back.material_override = paint
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(back)
	var words := Label3D.new()
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	words.font_size = FONT_SIZE
	words.pixel_size = PIXEL
	words.outline_size = 0
	words.modulate = Color(0.04, 0.03, 0.06, 1.0)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.width = WRAP
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Cut out, not blended: the words then sit at their own depth, and the far blur leaves them sharp.
	words.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	words.offset = Vector2(0, TAIL * 0.5 / PIXEL)
	words.visible = false
	holder.add_child(words)
	back.visible = false
	return {"words": words, "back": back, "paint": paint, "quad": quad, "shown": 0.0, "want": 0.0, "sized": false}

func say(who: int, line: String) -> void:
	var bubble := bubbles[who]
	var words: Label3D = bubble.words
	words.text = line
	# The box is fitted to the words once they are laid out (next frame).
	bubble.sized = false
	bubble.want = 1.0

func _fit(bubble: Dictionary) -> void:
	var words: Label3D = bubble.words
	var text_box := words.get_aabb()
	if text_box.size.x <= 0.0:
		return
	# A billboard's bounds are padded out to a square; the height is counted in lines instead.
	var font := ThemeDB.fallback_font
	var lines := maxf(1.0, roundf(font.get_multiline_string_size(words.text, HORIZONTAL_ALIGNMENT_CENTER, WRAP, FONT_SIZE).y / font.get_height(FONT_SIZE)))
	var box := Vector2(text_box.size.x + 0.4, lines * font.get_height(FONT_SIZE) * PIXEL + 0.3)
	(bubble.quad as QuadMesh).size = Vector2(box.x, box.y + TAIL)
	(bubble.paint as ShaderMaterial).set_shader_parameter("size", box)
	bubble.sized = true

func hush(who: int) -> void:
	bubbles[who].want = 0.0

func _process(delta: float) -> void:
	var eye := get_viewport().get_camera_3d()
	var near := eye != null and eye.global_position.distance_to(global_position) < HEAR + 40.0
	for group in talk:
		_converse(group, delta)
	for walker in walkers:
		var length: float = absf(walker.to - walker.from)
		walker.t = fmod(walker.t + delta * walker.speed / length, 2.0)
		var leg: float = walker.t if walker.t < 1.0 else 2.0 - walker.t
		var z: float = lerpf(walker.from, walker.to, leg)
		var going: float = signf(walker.to - walker.from) * (1.0 if walker.t < 1.0 else -1.0)
		var node: Node3D = walker.node
		node.position = Vector3(walker.x, 0, z)
		node.rotation.y = 0.0 if going > 0.0 else PI
	for i in range(bubbles.size()):
		var bubble := bubbles[i]
		var heard := 0.0
		if near:
			heard = 1.0 - smoothstep(HEAR * 0.75, HEAR, eye.global_position.distance_to(people[i].global_position))
		bubble.shown = move_toward(bubble.shown, bubble.want * heard, delta * 3.0)
		if bubble.want > 0.0 and not bubble.sized:
			_fit(bubble)
		var on: bool = bubble.shown > 0.001 and bubble.sized
		(bubble.words as Label3D).visible = on
		(bubble.back as MeshInstance3D).visible = on
		if on:
			# It pops up (and away) rather than fading: both halves are cut out, not blended.
			var pop: float = smoothstep(0.0, 1.0, bubble.shown)
			((bubble.back as Node3D).get_parent() as Node3D).scale = Vector3.ONE * maxf(pop, 0.001)

# One line at a time round the group; after the last, a quiet spell, then from the top again.
func _converse(group: Dictionary, delta: float) -> void:
	if group.speaking >= 0:
		group.left -= delta
		if group.left > 0.0:
			return
		hush(group.speaking)
		group.speaking = -1
		group.at += 1
		if group.at >= group.lines.size():
			group.at = 0
			group.wait = rng.randf_range(7.0, 15.0)
		else:
			group.wait = 0.7
		return
	group.wait -= delta
	if group.wait > 0.0:
		return
	var line: Array = group.lines[group.at]
	var who: int = group.members[line[0]]
	say(who, line[1])
	group.speaking = who
	group.left = 2.4 + String(line[1]).length() / 14.0
