extends Node3D
# Forced perspective puzzle: the path across the rift, broken into slabs that hang at every depth.
#
# Each slab starts as a piece of a straight walkway (its "home" transform) and is then scaled by a
# factor k about the eye point EYE: position' = EYE + (position - EYE) * k, size' = size * k.
# A pinhole camera at EYE sees the scaled slab exactly where it saw the home slab (same rays, same
# outline), so from EYE the scattered slabs join into one walkway, and the chalk on them, projected
# from EYE by anamorphic_path.gdshader, joins into one drawing. Anywhere else they fall apart.
# The slabs drift slowly by changing k, which moves them along those rays, so even while they
# breathe the picture from EYE never changes.
#
# misalignment() measures how far apart the picture is from the player's actual camera: every
# slab's centre is projected twice (where it is, and where its home is) and the average gap in
# pixels is the error. When a photo is taken with the error under ALIGNED_PX the moment is kept:
# every slab slides along its ray back to k = 1 and the walkway becomes real.
signal joined
const SHADER := preload("res://assets/materials/anamorphic_path.gdshader")
const PIECES := 12
const WIDTH := 2.4
const THICK := 0.3
const ALIGNED_PX := 14.0
# Errors are measured on a 1280-pixel-wide screen whatever the window is.
const REFERENCE_WIDTH := 1280.0

var eye: Vector3
var start: Vector3
var finish: Vector3
var rift_near: float
var rift_far: float
var slabs: Array[MeshInstance3D] = []
var homes: Array[Transform3D] = []
var factors: Array[float] = []
var phases: Array[float] = []
var material: ShaderMaterial
var shown := 0.0
var joining := -1.0
var solid := false
var clock := 0.0

func setup(eye_at: Vector3, from: Vector3, to: Vector3, near_z: float, far_z: float, tiles: Texture2D) -> void:
	eye = eye_at
	start = from
	finish = to
	rift_near = near_z
	rift_far = far_z
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tile_albedo", tiles)
	material.set_shader_parameter("eye", eye)
	material.set_shader_parameter("origin", start)
	var dir := (finish - start).normalized()
	material.set_shader_parameter("along", Vector2(dir.x, dir.z))
	material.set_shader_parameter("width", WIDTH)
	var length := start.distance_to(finish)
	var piece := length / PIECES
	var basis := Basis.looking_at(dir, Vector3.UP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1994
	var candidates := [0.32, 0.42, 0.55, 0.68, 1.3, 1.45, 1.6, 1.8, 2.1, 0.48, 0.6, 1.7]
	for i in range(PIECES):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(WIDTH, THICK, piece - 0.06)
		var slab := MeshInstance3D.new()
		slab.mesh = mesh
		slab.material_override = material
		add_child(slab)
		var home := Transform3D(basis, start + dir * (piece * (i + 0.5)) - Vector3(0, THICK / 2, 0))
		homes.append(home)
		slabs.append(slab)
		factors.append(_pick(home.origin, candidates, rng))
		phases.append(rng.randf() * TAU)
		slab.visible = false
	_place()

# A factor that moves the slab well away from home and leaves it somewhere it can be seen: in the
# air (k < 1 always lifts it towards the eye), or down inside the rift, not under solid floor.
func _pick(home: Vector3, candidates: Array, rng: RandomNumberGenerator) -> float:
	var order := candidates.duplicate()
	for i in range(order.size()):
		var j := rng.randi_range(i, order.size() - 1)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap
	for k in order:
		var at: Vector3 = eye + (home - eye) * float(k)
		if k < 1.0 and at.distance_to(eye) > 2.5:
			candidates.erase(k)
			return k
		if k > 1.0 and at.z < rift_near - 2.0 and at.z > rift_far + 2.0 and at.y > -25.0:
			candidates.erase(k)
			return k
	return 0.5

func scaled(i: int, k: float) -> Transform3D:
	var home := homes[i]
	return Transform3D(home.basis.scaled(Vector3.ONE * k), eye + (home.origin - eye) * k)

func _place() -> void:
	for i in range(slabs.size()):
		var k := factors[i]
		if joining >= 0.0:
			k = lerpf(k, 1.0, smoothstep(0.0, 1.0, joining))
		elif not solid:
			# Breathing along the ray: the size and distance change together, the picture does not.
			k *= 1.0 + 0.05 * sin(clock * 0.6 + phases[i])
		slabs[i].transform = scaled(i, k) if not solid else homes[i]

# The pieces rise out of the rift after the collapse.
func reveal() -> void:
	shown = 0.001
	for slab in slabs:
		slab.visible = true

func _process(delta: float) -> void:
	clock += delta
	if material == null:
		return
	material.set_shader_parameter("clock", clock)
	if shown > 0.0 and shown < 1.0:
		shown = minf(shown + delta / 2.5, 1.0)
		for slab in slabs:
			slab.transparency = 1.0 - shown
	if joining >= 0.0 and not solid:
		joining = minf(joining + delta / 1.8, 1.0)
		if joining >= 1.0:
			_make_solid()
	_place()

func _make_solid() -> void:
	solid = true
	joining = -1.0
	material.set_shader_parameter("glow", 0.0)
	for i in range(slabs.size()):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(WIDTH, THICK, (slabs[i].mesh as BoxMesh).size.z + 0.08)
		shape.shape = box
		body.add_child(shape)
		body.transform = homes[i]
		add_child(body)
	joined.emit()

func project(camera: Camera3D, point: Vector3, size: Vector2) -> Vector2:
	var p := camera.unproject_position(point)
	return p * (REFERENCE_WIDTH / size.x)

# Mean gap in reference pixels between where the slabs are seen and where their home would be seen.
# Slabs behind the camera or off the screen count as fully wrong.
func misalignment(camera: Camera3D) -> float:
	if slabs.is_empty() or not slabs[0].visible:
		return INF
	var size := camera.get_viewport().get_visible_rect().size
	var total := 0.0
	var seen := 0
	for i in range(slabs.size()):
		var now := slabs[i].global_position
		var home := homes[i].origin
		if camera.is_position_behind(now) or camera.is_position_behind(home):
			total += 400.0
			continue
		var a := project(camera, now, size)
		var b := project(camera, home, size)
		total += minf(a.distance_to(b), 400.0)
		var screen := camera.unproject_position(home)
		if Rect2(Vector2.ZERO, size).has_point(screen):
			seen += 1
	# The picture has to be in view, not just right behind the player's back.
	if seen < slabs.size() / 2:
		return INF
	return total / slabs.size()

func feedback(error: float) -> void:
	if material != null and not solid and joining < 0.0:
		material.set_shader_parameter("glow", clampf(1.0 - (error - ALIGNED_PX) / 80.0, 0.0, 1.0))

func aligned(camera: Camera3D) -> bool:
	return misalignment(camera) < ALIGNED_PX

func join() -> void:
	if not solid and joining < 0.0:
		joining = 0.0
