extends "res://scripts/town/town_houses.gd"
# The town's houses as the backdrop round the school uses them: lettering only near the campus,
# filler blocks out to the skyline, and nothing on the campus itself.
# Shop lettering fades out at 70 m (town_houses), and the camera never leaves the campus, so
# signs further out than this only get the coloured board.
const SIGN_REACH := 75.0

func _shop_sign(frame: Transform3D, w: float, tall: float, place: Dictionary, title := "") -> void:
	var at := Vector2(frame.origin.x, frame.origin.z)
	if plan.inside_campus(at, SIGN_REACH):
		super(frame, w, tall, place, title)
		return
	batch.box("paint", frame, Vector3(0, tall + 0.42, -0.14), Vector3(w - 0.12, 0.8, 0.14), SIGNS[rng.randi() % SIGNS.size()])

# Every open shop is the plain shelf front: chairs, bikes and racks would be far too much
# detail for streets that are only ever seen over the school wall.
func _open_front(_trade: String, frame: Transform3D, inner: float, recess: float, tall: float) -> void:
	super("goods", frame, inner, recess, tall)

# Fill what the street rows leave empty, up to the builder's FILL, never on the campus.
func back_blocks() -> void:
	var step := 9.0
	var reach: float = builder.FILL
	var x := -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var p := Vector2(x + rng.randf_range(-1, 1), z + rng.randf_range(-1, 1))
			if not plan.inside_campus(p, step):
				_back_cell(p, step)
			z += step
		x += step

# A tall block among the houses joins the skyline: dark mass with bands of lit windows.
func _tower(frame: Transform3D, size: float) -> void:
	var height := rng.randf_range(24.0, 36.0)
	var tint: Color = FACADES[rng.randi() % FACADES.size()].darkened(rng.randf_range(0.35, 0.55))
	batch.box("tower", frame, Vector3(0, height * 0.5, 0), Vector3(size, height, size), tint)
