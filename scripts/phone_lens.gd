extends Node
# Renders the other world from the player's own view and streams it to a paired phone.
# Materials are swapped per node, so the other world is a second set of instances sharing
# the same mesh data. The desktop camera never sees that layer, the lens never sees the normal one.
const NORMAL_ONLY := 1 << 17
const OTHER_WORLD := 1 << 18
const FRAME_WIDTH := 640
const FRAMES_PER_SECOND := 24.0
const JPEG_QUALITY := 0.55
const STALKER_DISTANCE := 3.4
const STALKER_SPEED := 0.9
var world: Node3D
var bridge: Node
var active := false
var aiming := false
var calibrating := false
var marker_free := false
var built := false
var viewport: SubViewport
var camera: Camera3D
var root: Node3D
var stalker: Node3D
var originals: Array[GeometryInstance3D] = []
var original_layers: Array[int] = []
var clock := 0.0
var markers: Control
var marker_layer: CanvasLayer

func _ready() -> void:
	set_process(false)

func set_active(enabled: bool) -> void:
	if enabled == active:
		return
	active = enabled
	if enabled and not built:
		_build()
	set_process(enabled)
	if enabled:
		bridge.send_text(JSON.stringify(markers.layout()))
	else:
		set_aiming(false)
	root.visible = enabled
	for index in range(originals.size()):
		originals[index].layers = NORMAL_ONLY if enabled else original_layers[index]
	var decor: Node3D = world.realm_scenery.decor
	decor.visible = enabled or world.spirit_enabled
	if enabled:
		_mask_desktop_camera()
		_place_stalker_behind()

func phone_update(update: Dictionary) -> void:
	if not active:
		return
	if update.has("calibrating"):
		var was_calibrating := calibrating
		calibrating = update.calibrating == true
		if calibrating:
			marker_layer.visible = true
			if not was_calibrating:
				markers.show_gate(true)
		elif was_calibrating:
			markers.play_open(_after_gate)
	if update.has("progress"):
		markers.set_progress(float(update.progress))
	if update.has("aim"):
		marker_free = marker_free or update.get("anchored", false) == true
		set_aiming(update.aim == true)

func _after_gate() -> void:
	marker_layer.visible = aiming and not marker_free

# Markers and the second render exist only while the player holds the phone's button.
func set_aiming(enabled: bool) -> void:
	if not active or enabled == aiming:
		aiming = enabled and active
		return
	aiming = enabled
	if not markers.gate:
		marker_layer.visible = calibrating or enabled and not marker_free
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED

func _build() -> void:
	built = true
	marker_layer = CanvasLayer.new()
	marker_layer.name = "LensMarkers"
	marker_layer.layer = 90
	markers = preload("res://scripts/lens_markers.gd").new()
	marker_layer.add_child(markers)
	marker_layer.visible = false
	add_child(marker_layer)
	viewport = SubViewport.new()
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	viewport.size = Vector2i(FRAME_WIDTH, roundi(FRAME_WIDTH * view_size.y / view_size.x))
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	add_child(viewport)
	camera = Camera3D.new()
	camera.cull_mask = 0xFFFFF & ~NORMAL_ONLY
	camera.environment = world.cursed_environment
	viewport.add_child(camera)
	root = Node3D.new()
	root.name = "OtherWorld"
	root.visible = false
	add_child(root)
	for entry in world.realm_scenery.visuals:
		_clone(entry.node, entry.cursed)
	for node in world.realm_scenery.decor.find_children("*", "GeometryInstance3D", true, false):
		node.layers = OTHER_WORLD
	stalker = preload("res://scripts/humanoid_model.gd").new()
	stalker.variant = "student"
	stalker.look = "b"
	stalker.target_height = 2.05
	stalker.rotation.y = PI
	var holder := Node3D.new()
	holder.name = "LensStalker"
	root.add_child(holder)
	holder.add_child(stalker)
	for mesh in stalker.find_children("*", "GeometryInstance3D", true, false):
		mesh.layers = OTHER_WORLD
	stalker.animation.play("walk")

func _clone(node: GeometryInstance3D, material: Material) -> void:
	var copy: GeometryInstance3D
	if node is MultiMeshInstance3D:
		copy = MultiMeshInstance3D.new()
		copy.multimesh = node.multimesh
	elif node is MeshInstance3D:
		copy = MeshInstance3D.new()
		copy.mesh = node.mesh
	else:
		return
	copy.material_override = material
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copy.layers = OTHER_WORLD
	root.add_child(copy)
	copy.global_transform = node.global_transform
	originals.append(node)
	original_layers.append(node.layers)

func _mask_desktop_camera() -> void:
	var view := get_viewport().get_camera_3d()
	if view != null:
		view.cull_mask &= ~OTHER_WORLD

func _place_stalker_behind() -> void:
	var view: Camera3D = world.player.camera
	var back := view.global_basis.z
	back.y = 0
	stalker.get_parent().global_position = world.player.global_position + back.normalized() * STALKER_DISTANCE

func _walk_stalker(delta: float) -> void:
	var holder: Node3D = stalker.get_parent()
	var offset: Vector3 = world.player.global_position - holder.global_position
	offset.y = 0
	var distance := offset.length()
	if distance > 0.01:
		holder.look_at(world.player.global_position * Vector3(1, 0, 1) + Vector3.UP * holder.global_position.y)
	if distance > 1.6:
		holder.global_position += offset / distance * minf(STALKER_SPEED * delta, distance)
	holder.global_position.y = world.player.global_position.y

func _process(delta: float) -> void:
	var view: Camera3D = world.player.camera
	camera.global_transform = view.global_transform
	camera.fov = view.fov
	_mask_desktop_camera()
	_walk_stalker(delta)
	clock -= delta
	if not aiming or clock > 0.0 or not bridge.ready_for_frame():
		return
	clock = 1.0 / FRAMES_PER_SECOND
	bridge.send_frame(viewport.get_texture().get_image().save_jpg_to_buffer(JPEG_QUALITY))
