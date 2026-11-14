extends Node3D
# A doorway that opens somewhere else. This node is the doorway's frame: origin at the middle of
# the threshold, +Z out towards whoever is looking in. `exit` is the frame of where it comes out;
# walking in through this one (from +Z to -Z) is walking out of `exit` (from -Z to +Z), looking
# the same way. A second camera stands behind `exit` where the eye would be and draws that place
# into a SubViewport, and the doorway shows it in screen space, so the doorway is a window onto
# the other place from every angle. Only drawn while the doorway is near and in view.
# Camera layers: the house's shell (SHELL) and every doorway's screen (SCREEN) are hidden from
# the portal cameras, so the far side is never blocked by the walls round its own door or by a
# doorway drawn inside a doorway.
const SCREEN_SHADER := preload("res://assets/materials/portal_screen.gdshader")
const SHELL := 4
const SCREEN := 8
const DEPTH := 0.78
signal crossed(portal: Node3D)
var exit: Node3D
var size := Vector2(1.08, 2.18)
# Bottom of the opening, from the frame's origin (the floor of the doorway can be a little lower).
var bottom := -0.09
var raw_environment: Environment
var walker: CharacterBody3D
var viewport: SubViewport
var eye: Camera3D
var screen: MeshInstance3D
var material: ShaderMaterial
# A doorway into a world of its own (the planet house's, onto the first meadow): the far side
# lives in this doorway's viewport, and stepping through only says so (crossed), for the scene
# to take over.
var hand_over := false
var look_exposure := 1.0
var resolution := 0.7
var reach := 160.0
var open := 0.0

# `look` is the environment of the far side, graded the way the eye there would see it. With
# `world` the far side is that node, given a world of its own inside this doorway (its own
# environment is then the look, and the doorway hands over instead of carrying the walker).
func setup(to: Node3D, look: Environment, body: CharacterBody3D, quality: int, world: Node3D = null) -> void:
	exit = to
	walker = body
	resolution = [0.5, 0.7, 1.0][quality]
	viewport = SubViewport.new()
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.audio_listener_enable_3d = false
	viewport.positional_shadow_atlas_size = 2048
	if world != null:
		viewport.own_world_3d = true
		viewport.add_child(world)
		hand_over = true
	add_child(viewport)
	if look == null and world != null:
		look = world.get("environment")
	raw_environment = raw(look)
	look_exposure = look.tonemap_exposure
	eye = Camera3D.new()
	eye.environment = raw_environment
	eye.cull_mask = 0xFFFFF & ~(SHELL | SCREEN)
	viewport.add_child(eye)
	material = ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter("view", viewport.get_texture())
	material.set_shader_parameter("open", open)
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, DEPTH)
	screen = MeshInstance3D.new()
	screen.mesh = box
	screen.material_override = material
	screen.layers = SCREEN
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = Vector3(0, bottom + size.y / 2, -DEPTH / 2)
	add_child(screen)
	screen.visible = false
	process_priority = 50
	process_physics_priority = 50

# The far side's environment, left untone-mapped so the eye's own grading applies once.
static func raw(look: Environment) -> Environment:
	var copy: Environment = look.duplicate()
	copy.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	copy.tonemap_exposure = 1.0
	copy.glow_enabled = false
	copy.adjustment_enabled = false
	return copy

# From this side to the far side.
func mapping() -> Transform3D:
	return exit.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * global_transform.affine_inverse()

func set_open(amount: float) -> void:
	open = amount
	material.set_shader_parameter("open", amount)
	screen.visible = amount > 0.0

func _process(_delta: float) -> void:
	if viewport == null:
		return
	var main := get_viewport().get_camera_3d()
	var drawn := open > 0.0 and main != null and _in_view(main)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if drawn else SubViewport.UPDATE_DISABLED
	if not drawn:
		return
	var want := Vector2i(get_viewport().get_visible_rect().size * resolution)
	if viewport.size != want:
		viewport.size = want
	eye.global_transform = mapping() * main.global_transform
	# The eye's own exposure is applied over the picture once more: give the far side's, divided by it.
	var here: Environment = main.environment if main.environment != null else main.get_world_3d().environment
	if here != null and here.tonemap_exposure > 0.0:
		raw_environment.tonemap_exposure = look_exposure / here.tonemap_exposure
	eye.fov = main.fov
	eye.far = main.far
	eye.near = 0.05

func _in_view(main: Camera3D) -> bool:
	var at := main.global_position
	var local := to_local(at)
	if local.z < -DEPTH - 0.2 or at.distance_to(global_position) > reach:
		return false
	if absf(local.x) < size.x and local.z < 1.5 and local.y > -1.0 and local.y < size.y + 1.0:
		return true
	for corner: Vector3 in [Vector3(-size.x / 2, bottom, 0), Vector3(size.x / 2, bottom, 0), Vector3(-size.x / 2, bottom + size.y, 0), Vector3(size.x / 2, bottom + size.y, 0), Vector3(0, bottom + size.y / 2, 0)]:
		if main.is_position_in_frustum(to_global(corner)):
			return true
	return false

# Stepping through: the walker is carried over to the far side, turned with it, moving on. Any
# time it is in the doorway past the threshold and going on in, not only on the frame it
# crossed, so a nudge back from the wall never leaves it standing in the doorway.
func _physics_process(_delta: float) -> void:
	if walker == null or open < 0.6:
		return
	var now := to_local(walker.global_position)
	var going := (global_basis.inverse() * walker.velocity).z
	var inside := absf(now.x) < size.x / 2 + 0.2 and now.y > bottom - 0.6 and now.y < size.y
	if inside and now.z <= 0.0 and now.z > -DEPTH - 0.4 and going < -0.05:
		if hand_over:
			walker = null
		else:
			carry(walker, mapping())
		crossed.emit(self)

static func carry(body: CharacterBody3D, move: Transform3D) -> void:
	var turn := move.basis.orthonormalized()
	body.global_position = move * body.global_position
	body.velocity = turn * body.velocity
	if "frame" in body:
		body.frame = (turn * body.frame).orthonormalized()
		body.up_direction = body.frame.y
		body.global_basis = body.frame * Basis(Vector3.UP, body.yaw)
	else:
		body.global_basis = turn * body.global_basis
	body.reset_physics_interpolation()
