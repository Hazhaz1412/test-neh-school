extends SkeletonModifier3D
# Moves a seated townsperson's hands to things on the table, on top of whatever clip is playing.
# Rocketbox has no clips for eating, drinking or chess, so the arms are solved here instead:
# a two-bone reach per arm, after an optional lean of the upper body. Goals are in the person's
# own space (+Z the way they face, +Y up); an arm with no goal keeps the clip's pose.
# Which way each elbow bends, in person space: out to the side, down and a little back.
const POLES := {"R": Vector3(-1.0, -0.8, -0.3), "L": Vector3(1.0, -0.8, -0.3)}
var person: Node3D
var goals := {}
# Which way the fingers of each hand point, in person space; a hand left out follows its forearm,
# which at odd angles leaves it waving with the palm out.
var aims := {}
# Forward lean of the upper body in radians, for reaching across the table.
var lean := 0.0
var arms := {}
var spine := -1
var head := -1

func attach(body: Node3D) -> void:
	person = body
	var skeleton: Skeleton3D = body.skeleton
	var prefix := String(skeleton.get_bone_name(0))
	for side in ["R", "L"]:
		arms[side] = [skeleton.find_bone("%s %s UpperArm" % [prefix, side]), skeleton.find_bone("%s %s Forearm" % [prefix, side]), skeleton.find_bone("%s %s Hand" % [prefix, side]), skeleton.find_bone("%s %s Finger2" % [prefix, side])]
	spine = skeleton.find_bone(prefix + " Spine1")
	head = skeleton.find_bone(prefix + " Head")
	skeleton.add_child(self)

# Where the mouth is now, in person space: just in front of the head bone, which sits at the
# base of the skull.
func mouth() -> Vector3:
	var skeleton: Skeleton3D = person.skeleton
	var at: Vector3 = person.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(head).origin)
	return at + Vector3(0, 0.03, 0.11) * person.height / 1.64

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or person == null:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse() * person.global_transform
	if lean != 0.0 and spine >= 0:
		var pose := skeleton.get_bone_global_pose(spine)
		var axis := (to_skeleton.basis * Vector3.RIGHT).normalized()
		skeleton.set_bone_global_pose(spine, Transform3D(Basis(axis, lean) * pose.basis, pose.origin))
	for side in goals:
		var pole: Vector3 = (to_skeleton.basis * POLES[side]).normalized()
		_reach(skeleton, arms[side], to_skeleton * goals[side], pole)
		if aims.has(side) and arms[side][3] >= 0:
			_point(skeleton, arms[side], (to_skeleton.basis * aims[side]).normalized())

# Turns the hand at the wrist so its middle finger points along direction.
func _point(skeleton: Skeleton3D, bones: Array, direction: Vector3) -> void:
	var hand := skeleton.get_bone_global_pose(bones[2])
	var finger := skeleton.get_bone_global_pose(bones[3]).origin
	var turn := Quaternion((finger - hand.origin).normalized(), direction)
	skeleton.set_bone_global_pose(bones[2], Transform3D(Basis(turn) * hand.basis, hand.origin))

# Bends shoulder and elbow so the wrist lands on goal, as near as the arm's length allows.
func _reach(skeleton: Skeleton3D, bones: Array, goal: Vector3, pole: Vector3) -> void:
	var upper := skeleton.get_bone_global_pose(bones[0])
	var fore := skeleton.get_bone_global_pose(bones[1])
	var hand := skeleton.get_bone_global_pose(bones[2])
	var shoulder := upper.origin
	var a := shoulder.distance_to(fore.origin)
	var b := fore.origin.distance_to(hand.origin)
	var toward := goal - shoulder
	var d := clampf(toward.length(), absf(a - b) + 0.01 * (a + b), (a + b) * 0.995)
	var u := toward.normalized()
	# The elbow sits on the circle where both bones meet; the pole picks the point on it.
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var bend := pole - u * pole.dot(u)
	if bend.length_squared() < 0.000001:
		bend = u.cross(Vector3.UP)
	var elbow := shoulder + u * x + bend.normalized() * h
	var turn := Quaternion((fore.origin - shoulder).normalized(), (elbow - shoulder).normalized())
	skeleton.set_bone_global_pose(bones[0], Transform3D(Basis(turn) * upper.basis, shoulder))
	fore = skeleton.get_bone_global_pose(bones[1])
	hand = skeleton.get_bone_global_pose(bones[2])
	turn = Quaternion((hand.origin - fore.origin).normalized(), (shoulder + u * d - fore.origin).normalized())
	skeleton.set_bone_global_pose(bones[1], Transform3D(Basis(turn) * fore.basis, fore.origin))
