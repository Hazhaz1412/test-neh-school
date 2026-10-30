extends Node3D

# The figure the player follows upstairs. It first waits at a top-floor window,
# a reward for looking up after the scare, then at the far end of the wing.
enum Mode { HIDDEN, WINDOW, HALL, GLIDE, GONE }
const WINDOW := Vector3(-22.45,7.85,22.2)
const HALL := Vector3(-23.5,7.85,47.6)
const GLIDE_PATH := [Vector3(-25.0,7.85,49.0), Vector3(-28.0,7.85,49.0)]
const GLIDE_SPEED := 8.0
const TOP_FLOOR_FEET := 7.4
const SIGHT_DISTANCE := 15.0
const RECOGNITION_SECONDS := 0.5
const VIEW_DEGREES := 33.0
var world: Node3D
var story: Node3D
var mode := Mode.HIDDEN
var model: Node3D
var pane: MeshInstance3D
var rim: OmniLight3D
var hall_light: OmniLight3D
var slam: AudioStreamPlayer3D
var classroom: Node3D
var seen_clock := 0.0
var seen_from := 0.0
var glide_step := 0
static var shadow_material: StandardMaterial3D

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "TopFloorShadow"
	classroom = world.get_node("Architecture/ClassroomDoor306")
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "Casual_Female"
	model.target_height = 2.0
	model.rotation.y = PI
	add_child(model)
	if shadow_material == null:
		shadow_material = StandardMaterial3D.new()
		shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_material.albedo_color = Color(0.006,0.007,0.009)
	for part in model.visual.find_children("*","MeshInstance3D",true,false):
		for surface in range(part.mesh.get_surface_count()): part.set_surface_override_material(surface,shadow_material)
	model.head_pitch = 0.16
	pane = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.44,1.32)
	pane.mesh = quad
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pane.position = Vector3(-22.85,9.7,22.708)
	pane.rotation.y = PI/2
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.albedo_color = Color(0.31,0.40,0.46)
	pane.material_override = pale
	add_child(pane)
	rim = OmniLight3D.new()
	rim.position = Vector3(-23.1,9.5,WINDOW.z)
	rim.light_color = Color(0.48,0.62,0.75)
	rim.light_energy = 0.75
	rim.omni_range = 3.5
	add_child(rim)
	hall_light = OmniLight3D.new()
	hall_light.position = Vector3(-23.6,9.9,51.5)
	hall_light.light_color = Color(0.46,0.60,0.74)
	hall_light.light_energy = 1.6
	hall_light.omni_range = 10
	add_child(hall_light)
	slam = AudioStreamPlayer3D.new()
	slam.stream = load("res://assets/audio/door_bang.wav")
	slam.unit_size = 24
	slam.max_distance = 80
	slam.volume_db = 0
	add_child(slam)
	reset()

func _place(at: Vector3) -> void:
	# Child props are authored in world space, so only the figure itself moves.
	model.position = at
	model.rotation = Vector3(0,PI,0)

func _face(target: Vector3) -> void:
	var to: Vector3 = target-model.position
	model.rotation.y = atan2(to.x,to.z)

func reset() -> void:
	mode = Mode.HIDDEN
	seen_clock = 0
	seen_from = 0
	glide_step = 0
	_place(WINDOW)
	slam.stop()
	_refresh()

func _refresh() -> void:
	model.visible = mode in [Mode.WINDOW,Mode.HALL,Mode.GLIDE]
	pane.visible = mode == Mode.WINDOW
	rim.visible = mode == Mode.WINDOW
	hall_light.visible = mode in [Mode.HALL,Mode.GLIDE]
	model.animation.speed_scale = 0.4 if mode in [Mode.WINDOW,Mode.HALL] else 0.0

func show_at_window() -> void:
	mode = Mode.WINDOW
	_place(WINDOW)
	_face(WINDOW+Vector3.RIGHT)
	model.animation.play("idle")
	_refresh()

func conceal() -> void:
	mode = Mode.HIDDEN
	_refresh()

func player_sees() -> bool:
	var camera: Camera3D = world.player.camera
	var head: Vector3 = model.position+Vector3.UP*1.5
	var to: Vector3 = head-camera.global_position
	if rad_to_deg((-camera.global_basis.z).angle_to(to)) > VIEW_DEGREES: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,head,5)
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _begin_glide() -> void:
	mode = Mode.GLIDE
	glide_step = 0
	seen_from = world.player.camera.global_position.distance_to(model.position)
	story.shadow_room_open = true
	classroom.set_open(true)
	_refresh()

func tick(delta: float) -> void:
	match mode:
		Mode.WINDOW:
			if world.player.global_position.y >= TOP_FLOOR_FEET:
				mode = Mode.HALL
				_place(HALL)
				_face(GLIDE_PATH[0])
				_refresh()
		Mode.HALL:
			if not player_sees():
				seen_clock = 0
				return
			seen_clock += delta
			# Far away the player gets a moment to recognise her; up close she
			# is simply gone, so the figure is never met face to face.
			if seen_clock >= RECOGNITION_SECONDS or model.position.distance_to(world.player.global_position) < SIGHT_DISTANCE:
				_begin_glide()
		Mode.GLIDE:
			var target: Vector3 = GLIDE_PATH[glide_step]
			model.position = model.position.move_toward(target,delta*GLIDE_SPEED)
			if model.position.distance_to(target) < 0.01:
				glide_step += 1
				if glide_step >= GLIDE_PATH.size():
					classroom.set_open(false)
					slam.global_position = classroom.global_position+Vector3.UP*1.4
					slam.play()
					mode = Mode.GONE
					_refresh()
					story.on_shadow_entered()

func _process(_delta: float) -> void:
	slam.stream_paused = not world.simulation_active()
	if not world.simulation_active(): model.animation.speed_scale = 0
	elif mode in [Mode.WINDOW,Mode.HALL]: model.animation.speed_scale = 0.4

func _exit_tree() -> void:
	if slam != null:
		slam.stop()
		slam.stream = null
