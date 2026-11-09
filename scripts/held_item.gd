extends Node3D

var player: CharacterBody3D
var models := {}
var shown_kind := ""
var equip := 0.0
var arms: Node3D
var item_facing := {}
var finger_gun := "" # "", "aim" or "fire" while the Ctrl+1 finger gun is up.
var gesture := "" # One-off arm clip playing now (push, grab), or "".
var raise := 0.0 # 0 camera at rest .. 1 camera at the eye (viewfinder open).
const BASE_POSITION := Vector3(0.25, -0.27, -0.52)
# The rig holds its hand about 0.3 m from the eye; reach further so items keep
# the on-screen size they were tuned for at BASE_POSITION.
const HAND_REACH := Vector3(-0.02, -0.04, -0.12)
# Hand pose per item (actions in arms_rig.glb): the lantern is gripped round its
# body, upright sticks in the knife fist ("hold", built in first_person_arms.gd),
# the camera and the box are cradled, small things pinched.
const HOLD_POSES := {
	"torch": "hold_torch", "crank": "hold",
	"camera": "hold_camera", "medicine": "hold_camera",
	"battery": "hold_small", "chalk": "hold_small", "medal": "hold_small",
}
# Item origin relative to the pose's anchor (see first_person_arms.gd), in this
# node's space. Tuned by eye so each item sits in the hand, not near it.
const GRIP_OFFSETS := {
	"torch": Vector3.ZERO, # Laid along the fist instead, see ALONG_FIST.
	"camera": Vector3(-0.08, -0.04, -0.02), # Right hand on the grip side.
	"medicine": Vector3(-0.07, -0.04, 0.0), # Hand on the box's right edge.
	"crank": Vector3.ZERO, "battery": Vector3.ZERO, "chalk": Vector3.ZERO, "medal": Vector3.ZERO,
}
# Items laid across the palm (heel to index knuckle, tip forward, top towards
# the thumb) rather than kept at their tuned facing. "point" is the spot on the
# item's axis, in its own space, that goes to the hand's anchor; "depth" moves
# the axis that far off the palm, about the item's radius.
# Flashlight: gripped on the body behind the switch, ~2 cm radius.
const ALONG_FIST := {"torch": {"point": Vector3(0.0, 0.0, 0.036), "depth": 0.022}}
# The flashlight model runs along its X axis, head at +X, 2 units long; scale
# to a ~24 cm torch and turn the head to face -Z (forward).
const TORCH_SCALE := 0.12
const TORCH_ROTATION := Vector3(0.0, PI / 2, 0.0)
const TORCH_OFFSET := Vector3.ZERO
# The beam starts at the eye, behind the hand: nothing held in view (arms,
# torch, other items) may catch it, or the hand lights up instead of the room.
const HELD_LAYER := 1 << 19
# Right click lifts the camera to the eye; the viewfinder opens only once it gets there.
const RAISE_SECONDS := 0.3
const RAISED_POSITION := Vector3(0.10, -0.09, -0.27)
const RAISED_TURN := 0.28 # Cancels the model's resting yaw so the lens faces forward.

static func camera_model() -> Node3D:
	var pivot := Node3D.new()
	var source: Node3D = preload("res://assets/models/camera/camera.glb").instantiate()
	source.scale = Vector3.ONE * 0.068
	source.position.y = -0.129
	source.rotation.y = PI
	pivot.add_child(source)
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return pivot

static func torch_model() -> Node3D:
	var pivot := Node3D.new()
	var source: Node3D = preload("res://assets/models/horror_game_flashlight_download_game-ready.glb").instantiate()
	source.scale = Vector3.ONE * TORCH_SCALE
	source.rotation = TORCH_ROTATION
	source.position = TORCH_OFFSET
	pivot.add_child(source)
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.layers = HELD_LAYER
	return pivot

static func prop(kind: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = {"battery": Color(0.68, 0.57, 0.22), "medicine": Color(0.48, 0.66, 0.56), "chalk": Color(0.80, 0.80, 0.73), "medal": Color(0.86, 0.68, 0.24), "crank": Color(0.32, 0.36, 0.26)}[kind]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "medicine":
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.14, 0.12)
		visual.mesh = mesh
	else:
		var mesh := CylinderMesh.new()
		mesh.height = {"battery": 0.10, "chalk": 0.12, "medal": 0.012, "crank": 0.17}[kind]
		mesh.top_radius = {"battery": 0.021, "chalk": 0.009, "medal": 0.05, "crank": 0.042}[kind]
		mesh.bottom_radius = mesh.top_radius
		mesh.radial_segments = 12
		visual.mesh = mesh
		visual.rotation.x = -0.35
	return visual

func _ready() -> void:
	position = BASE_POSITION
	# Arms only appear together with a held item. Offset so that, at rest, the
	# rig's eye lines up with the camera this node hangs from.
	arms = preload("res://scripts/first_person_arms.gd").new()
	arms.name = "Arms"
	arms.position = -BASE_POSITION + HAND_REACH
	add_child(arms)
	arms.hide()
	arms.animation.animation_finished.connect(_on_arms_clip_finished)
	models["camera"] = camera_model()
	models["camera"].rotation.y = -0.28
	models["torch"] = torch_model()
	player.flashlight.light_cull_mask &= ~HELD_LAYER
	for kind in ["battery", "medicine", "chalk", "medal", "crank"]:
		models[kind] = prop(kind)
	for kind in models:
		# Items hang from the wrist bone; _hold() places them per pose.
		item_facing[kind] = models[kind].transform.basis
		arms.grip.add_child(models[kind])
		models[kind].hide()
	for mesh in arms.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = HELD_LAYER
	# Keep an equipped camera readable without adding a realtime light.
	for mesh in models["camera"].find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D = original.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface, material)

func _process(delta: float) -> void:
	var world: Node3D = player.get_parent()
	if world.get("survival") == null:
		hide()
		return
	var kind: String = player.selected_item()
	# At the eye the viewfinder replaces the hands and camera; as the head turns back (right mouse,
	# hands empty or holding anything but the camera) the hands sink out of view.
	visible = player.enabled and not player.seized and player.health > 0 and not player.is_hidden() and not world.survival.opening.playing and not world.survival.finished and not camera_raised() and player.look_back_eased < 0.3
	if kind != shown_kind:
		# Switching slots puts the finger gun away too.
		shown_kind = kind
		raise = 0.0
		_restore_item()
	if not world.simulation_active():
		return
	var raise_target := 1.0 if kind == "camera" and player.camera_aiming else 0.0
	raise = move_toward(raise, raise_target, delta / RAISE_SECONDS)
	equip = maxf(0, equip - delta * 7)
	var recoil: float = world.camera_flash.intensity if kind == "camera" else (player.crank_kick if kind == "crank" else 0.0)
	position = BASE_POSITION + Vector3(0, -equip * 0.18 - recoil * 0.035, recoil * 0.06)
	var charge: float = player.chalk_charge_fraction() if kind == "chalk" and player.chalk_charging else 0.0
	position += Vector3(0.03, -0.02, 0.10) * charge
	position.y -= 0.3 * minf(player.look_back_eased / 0.3, 1.0)
	rotation.x = -charge * 0.45
	rotation.z = sin(player.step_time) * player.velocity.length() * 0.003
	var lift := smoothstep(0.0, 1.0, raise)
	position = position.lerp(RAISED_POSITION, lift)
	rotation.y = RAISED_TURN * lift
	rotation.z *= 1.0 - lift

func camera_raised() -> bool:
	return raise >= 1.0

func _show(kind: String) -> void:
	shown_kind = kind
	equip = 1.0
	for item in models:
		models[item].visible = item == kind
	arms.visible = models.has(kind)
	if arms.visible:
		_hold(kind)

# Ctrl+1: put the item down and raise a finger gun; Ctrl+1 again brings the item back.
func toggle_finger_gun() -> void:
	if not finger_gun.is_empty():
		_restore_item()
		return
	finger_gun = "aim"
	equip = 1.0
	for item in models:
		models[item].hide()
	arms.show()
	# The pack's clips are framed for its own eye, without the item reach.
	arms.position = -BASE_POSITION
	arms.play_clip(arms.FINGER_GUN_AIM, 0.0)

# Returns false when there is no finger gun raised, so the click uses the item.
func fire_finger_gun() -> bool:
	if finger_gun != "aim":
		return finger_gun == "fire" # Swallow clicks during the shot.
	finger_gun = "fire"
	arms.play_clip(arms.FINGER_GUN_FIRE, 0.05)
	return true

func _on_arms_clip_finished(clip: StringName) -> void:
	# Back to aiming after each shot; the gun stays up until Ctrl+1.
	if clip == gesture:
		_restore_item()
	if clip == arms.FINGER_GUN_FIRE and finger_gun == "fire":
		finger_gun = "aim"
		arms.play_clip(arms.FINGER_GUN_AIM)

# Right click with empty hands: both arms come up and shove forward once.
func push_both_hands() -> bool:
	if not player.selected_item().is_empty():
		return false
	return _play_gesture(arms.PUSH)

# Shouldering a door open mid-run: both palms out whatever is in hand, put away meanwhile.
func shove() -> bool:
	return _play_gesture(arms.PUSH)

# E: the right hand reaches out and grabs; a held item is put away meanwhile.
func grab_with_right_hand() -> bool:
	return _play_gesture(arms.GRAB)

func _play_gesture(clip: String) -> bool:
	if not gesture.is_empty() or not finger_gun.is_empty():
		return false
	gesture = clip
	for item in models:
		models[item].hide()
	arms.show()
	# The pack's clips are framed for its own eye, without the item reach.
	arms.position = -BASE_POSITION
	arms.play_clip(clip, 0.0)
	return true

# Back to the selected item's pose (or no arms) after the finger gun or a gesture.
func _restore_item() -> void:
	finger_gun = ""
	gesture = ""
	arms.position = -BASE_POSITION + HAND_REACH
	_show(shown_kind)

# Pose the hand for this item, then put the item at the pose's anchor: with the
# facing it was tuned with, or laid across the palm for ALONG_FIST items.
func _hold(kind: String) -> void:
	arms.hold(HOLD_POSES[kind])
	var hand: Transform3D = arms.bone_transform_in(self, "hand.R")
	var anchor: Vector3 = arms.anchor_in(self) + GRIP_OFFSETS[kind]
	var held := Transform3D(item_facing[kind], anchor)
	if ALONG_FIST.has(kind):
		var axes: Array[Vector3] = arms.grip_axes_in(self)
		var fit: Dictionary = ALONG_FIST[kind]
		var facing := Basis.looking_at(axes[0], axes[2])
		held = Transform3D(facing, anchor + axes[1] * fit.depth - facing * fit.point)
	models[kind].transform = hand.affine_inverse() * held
