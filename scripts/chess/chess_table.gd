extends Node3D
# The Poly Haven set on the table of Góc Cờ. Each piece of the model is cut loose and re-laid
# from the rules, so the board can never show a position the game does not hold.
const SQUARE := 0.058
const EDGE := 0.203
const TOP := 0.017
const KINDS := {1: "pawn", 2: "knight", 3: "bishop", 4: "rook", 5: "queen", 6: "king"}
var templates := {}
var pieces := {}
var mark_pool: Array = []
var marks_used := 0

func _ready() -> void:
	var source: Node3D = load("res://assets/polyhaven_town/models/chess_set/chess_set.gltf").instantiate()
	add_child(source)
	for part in source.find_children("*", "MeshInstance3D", true, false):
		var words: PackedStringArray = part.name.split("_")
		if part.name == "board":
			part.visibility_range_end = 60.0
		elif not templates.has(words[1] + words[2]):
			templates[words[1] + words[2]] = part.mesh
		if part.name != "board":
			part.queue_free()
	for i in range(40):
		var mark := MeshInstance3D.new()
		var plate := PlaneMesh.new()
		plate.size = Vector2.ONE * SQUARE * 0.96
		mark.mesh = plate
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mark.material_override = paint
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.hide()
		add_child(mark)
		mark_pool.append(mark)

func spot(square: int) -> Vector3:
	return Vector3(EDGE - (square % 8) * SQUARE, TOP, -EDGE + (square / 8) * SQUARE)

func lay(board: PackedInt32Array) -> void:
	for node in pieces.values():
		node.queue_free()
	pieces.clear()
	for square in range(64):
		if board[square] != 0:
			pieces[square] = _piece(board[square], square)

func _piece(piece: int, square: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = templates[KINDS[absi(piece)] + ("white" if piece > 0 else "black")]
	node.position = spot(square)
	node.visibility_range_end = 60.0
	add_child(node)
	return node

func slide(from: int, to: int, seconds := 0.28) -> void:
	if not pieces.has(from):
		return
	var node: Node3D = pieces[from]
	var tween := create_tween()
	var middle: Vector3 = (node.position + spot(to)) * 0.5 + Vector3.UP * 0.05
	tween.tween_property(node, "position", middle, seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", spot(to), seconds * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

func lift(square: int, raised: bool) -> void:
	if pieces.has(square):
		pieces[square].position.y = TOP + (0.012 if raised else 0.0)

func clear_marks() -> void:
	for mark in mark_pool:
		mark.hide()
	marks_used = 0

func mark(square: int, color: Color) -> void:
	var plate: MeshInstance3D = mark_pool[marks_used]
	marks_used += 1
	plate.material_override.albedo_color = color
	plate.position = spot(square) + Vector3.UP * 0.0015
	plate.show()

# Mouse ray to board square, or -1 off the board.
func square_at(camera: Camera3D, screen: Vector2) -> int:
	var origin := to_local(camera.project_ray_origin(screen))
	var ahead := to_local(camera.project_ray_origin(screen) + camera.project_ray_normal(screen)) - origin
	if absf(ahead.y) < 0.0001:
		return -1
	var hit := origin + ahead * ((TOP - origin.y) / ahead.y)
	var file := roundi((EDGE - hit.x) / SQUARE)
	var rank := roundi((hit.z + EDGE) / SQUARE)
	return rank * 8 + file if file >= 0 and file < 8 and rank >= 0 and rank < 8 else -1
