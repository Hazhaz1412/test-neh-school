extends Node3D

const WINDOW := Vector3(-22.45,3.95,22.2)
const RETREAT_PATH := [Vector3(-23.4,3.95,22.2), Vector3(-23.4,3.95,25), Vector3(-26.8,3.95,25)]
var world: Node3D
var story: Node3D
var model: Node3D
var rim: OmniLight3D
var tap: AudioStreamPlayer3D
var activated := false
var withdrawn := false
var retreat := 0.0
var retreat_step := 0
var classroom: Node3D
var tap_clock := 0.0
static var shadow_material: StandardMaterial3D

func setup(school: Node3D, progression: Node3D) -> void:
	world = school
	story = progression
	name = "UpperFloorWindowShadow"
	classroom = world.get_node("Architecture/ClassroomDoor205")
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
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.44,1.32)
	glow.mesh = quad
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.top_level = true
	glow.position = Vector3(-22.85,5.8,22.708)
	glow.rotation.y = PI/2
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.albedo_color = Color(0.31,0.40,0.46)
	pale.cull_mode = BaseMaterial3D.CULL_BACK
	glow.material_override = pale
	add_child(glow)
	rim = OmniLight3D.new()
	rim.top_level = true
	rim.position = Vector3(-23.1,5.6,WINDOW.z)
	rim.light_color = Color(0.48,0.62,0.75)
	rim.light_energy = 0.65
	rim.omni_range = 3.0
	add_child(rim)
	tap = AudioStreamPlayer3D.new()
	tap.stream = load("res://assets/audio/strange_knock.wav")
	tap.unit_size = 25
	tap.max_distance = 70
	tap.volume_db = -12
	add_child(tap)
	reset()

func reset() -> void:
	activated = false
	withdrawn = false
	retreat = 0
	retreat_step = 0
	tap_clock = 0
	position = WINDOW
	rotation = Vector3(0,-PI/2,0)
	rim.light_energy = 0.65
	tap.stop()
	hide()
	model.animation.speed_scale = 0

func activate() -> void:
	activated = true
	show()
	model.animation.play("idle")
	model.animation.speed_scale = 0.4

func conceal() -> void:
	hide()
	tap.stop()
	model.animation.speed_scale = 0

func _process(delta: float) -> void:
	tap.stream_paused = not world.simulation_active()
	if not activated or not visible: return
	if story.stage == story.Stage.DOOR_SCARE:
		model.animation.speed_scale = 0
		return
	if not story.stage in [story.Stage.BLOOD_TRAIL,story.Stage.BLOODY_CLUBS] or not world.survival.active:
		conceal()
		return
	if not world.simulation_active():
		model.animation.speed_scale = 0
		return
	model.animation.speed_scale = 1 if withdrawn else 0.4
	if not withdrawn:
		tap_clock -= delta
		if tap_clock<=0:
			tap.play()
			tap_clock = 10
		var feet: Vector3 = world.player.global_position
		# The landing triggers the event, even when the player is still across
		# the building. Looking from below or climbing partway does not.
		if feet.y >= 3.8 and feet.y < 7.4:
			withdrawn = true
			classroom.set_open(true)
			model.animation.play("walk")
	if withdrawn:
		var target: Vector3 = RETREAT_PATH[retreat_step]
		if position.distance_to(target)>0.02:
			look_at(target)
		position = position.move_toward(target,delta*1.65)
		retreat = (float(retreat_step)+1.0-position.distance_to(target)/3.4)/RETREAT_PATH.size()
		if position.distance_to(target)<=0.02:
			retreat_step += 1
			if retreat_step>=RETREAT_PATH.size():
				retreat = 1
				conceal()

func _exit_tree() -> void:
	if tap!=null:
		tap.stop()
		tap.stream = null
