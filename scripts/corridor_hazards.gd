extends RefCounted
# The obstacles beyond plain furniture. Everything here telegraphs before it can hurt: it starts
# moving at a distance a running player can still answer, and every one has a way through.
const TRIGGER := 17.0
const PIT_DEPTH := 1.4
const PIT_CLEAR := 0.22
const SWING_REACH := 2.7
const SWING_PERIOD := 2.5
const SWING_HIT := 1.15
const AMBUSH_HIT := 1.0
const AMBUSH_SIDE := 1.6
const STACK_TIERS := 3
const HOLE_LENGTH := 7.0
var run: Node3D
var entries: Array[Dictionary] = []
var ambusher: Node3D

func _init(runner: Node3D) -> void:
	run = runner

func _root(at: float, index: int) -> AnimatableBody3D:
	var root := AnimatableBody3D.new()
	root.sync_to_physics = false
	root.collision_layer = 1
	root.collision_mask = 0
	root.set_meta("chase_hazard", index)
	run.add_child(root)
	root.transform = run.route_frame(at)
	run.bodies.append(root)
	return root

func _shape(root: Node3D, at: Vector3, size: Vector3, off := false) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = at
	collider.disabled = off
	root.add_child(collider)
	return collider

func _add(root: Node3D, at: float, kind: String, extra: Dictionary) -> Dictionary:
	var entry := {"kind": kind, "initial_kind": kind, "challenge": kind, "distance": at, "passed": false, "visual": root, "moving": false, "shifted": false, "shift": 0.0, "side": 1.0, "last_hit": -10.0, "custom": true}
	entry.merge(extra, true)
	run.obstacles.append(entry)
	entries.append(entry)
	return entry

# A wall of stacked school desks with one way through.
func desk_row(at: float, gap: float, index: int, tall := false) -> void:
	var root := _root(at, index)
	var half := 1.15
	var x := -3.05
	while x < 3.2:
		if absf(x - gap) > half + 0.25:
			if tall:
				run.prop(root, "drawer_cabinet", Vector3(x, 0, 0), Vector3(0.95, 2.5, 0.7), 0.0)
			else:
				for tier in range(STACK_TIERS):
					run.prop(root, "SchoolDesk_01", Vector3(x, tier * 0.8, 0), Vector3(1.05, 0.8, 0.65), 0.0)
				run.prop(root, "SchoolChair_01", Vector3(x, STACK_TIERS * 0.8, 0), Vector3(0.75, 0.85, 0.6), PI)
		x += 1.2
	var boards: StandardMaterial3D = run.material(Color(0.14, 0.085, 0.06))
	for side in [-1.0, 1.0]:
		var inner: float = gap + side * half
		var outer: float = side * 3.6
		var width: float = absf(outer - inner)
		if width > 0.1:
			_shape(root, Vector3((inner + outer) * 0.5, 1.5, 0), Vector3(width, 3.0, 0.8))
			# Boarded up behind: no crawling under the desks, no climbing over the stack.
			run.box(root, Vector3((inner + outer) * 0.5, 1.7, -0.36), Vector3(width, 3.4, 0.07), boards)
	# Chalk and a cold lamp mark the only way through, the same sign the low gates use.
	var chalk: StandardMaterial3D = run.material(Color(0.62, 0.73, 0.73), true)
	for side in [-1.0, 1.0]:
		run.box(root, Vector3(gap + side * half, 0.025, 0), Vector3(0.055, 0.02, 3.6), chalk)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(gap, 1.4, -0.9)
	lamp.light_color = Color(0.6, 0.85, 0.9)
	lamp.light_energy = 1.1
	lamp.omni_range = 5.0
	root.add_child(lamp)
	_add(root, at, "gap", {"gap": gap, "gap_light": lamp})

# A classroom door bursts open across half the corridor.
func door(at: float, side: float, index: int) -> void:
	var root := _root(at, index)
	var hinge := Node3D.new()
	hinge.position = Vector3(side * 3.5, 0, 0)
	root.add_child(hinge)
	var leaf: MeshInstance3D = run.box(hinge, Vector3(-side * 1.75, 1.3, 0), Vector3(3.5, 2.6, 0.12), run.material(Color(0.2, 0.08, 0.05)))
	hinge.rotation.y = -side * PI * 0.5
	var block := _shape(root, Vector3(side * 1.75, 1.5, 0), Vector3(3.6, 3.0, 0.5), true)
	var glow := OmniLight3D.new()
	glow.position = Vector3(side * 3.0, 1.6, 0.4)
	glow.light_color = Color(1, 0.1, 0.05)
	glow.light_energy = 0.0
	glow.omni_range = 7
	root.add_child(glow)
	_add(root, at, "door", {"side": side, "hinge": hinge, "block": block, "glow": glow})

# A row of cabinets stands in the way, then falls towards the player as a low barrier to jump.
func topple(at: float, index: int) -> void:
	var root := _root(at, index)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, -0.4)
	root.add_child(pivot)
	for x in [-2.4, 0.0, 2.4]:
		run.prop(pivot, "bookcaseClosedWide", Vector3(x, 0, 0), Vector3(2.35, 2.6, 0.8))
	var tall := _shape(root, Vector3(0, 1.5, -0.4), Vector3(7.2, 3.0, 0.8))
	var low := _shape(root, Vector3(0, 0.4, 0.9), Vector3(7.2, 0.8, 2.6), true)
	_add(root, at, "topple", {"pivot": pivot, "tall": tall, "low": low})

# Lamps and chairs come down through the ceiling and block the floor at jump height.
func ceiling(at: float, index: int) -> void:
	var root := _root(at, index)
	for x in [-2.6, -0.9, 0.9, 2.6]:
		run.prop(root, "SchoolChair_01", Vector3(x, 0, 0), Vector3(1.0, 0.7, 0.7), x)
	run.box(root, Vector3(0, 0.62, 0), Vector3(7.0, 0.1, 0.25), run.material(Color(0.26, 0.26, 0.28)))
	_shape(root, Vector3(0, 0.35, 0), Vector3(7.2, 0.7, 0.8))
	root.position.y = 3.4
	_add(root, at, "fall", {})

# The floor is gone. Only a jump crosses it, and something below reaches up.
func pit(at: float, index: int) -> void:
	var root := Node3D.new()
	run.add_child(root)
	root.transform = run.route_frame(at)
	run.box(root, Vector3(0, 0.012, 0), Vector3(7.2, 0.01, PIT_DEPTH * 2.0), run.material(Color(0.004, 0.003, 0.004)))
	for side in [-1.0, 1.0]:
		run.box(root, Vector3(0, 0.02, side * (PIT_DEPTH + 0.06)), Vector3(7.2, 0.012, 0.1), run.material(Color(0.8, 0.12, 0.06), true))
	var hands: Array = []
	var skin: StandardMaterial3D = run.material(Color(0.5, 0.52, 0.46))
	for i in range(9):
		var arm: MeshInstance3D = run.box(root, Vector3(-3.0 + i * 0.75, 0.25, sin(i * 2.3) * 0.8), Vector3(0.09, 0.8, 0.09), skin)
		arm.rotation.z = sin(i * 1.7) * 0.4
		hands.append(arm)
	_add(root, at, "pit", {"hands": hands})

# The floor falls away across the whole corridor: there is no jumping this one.
func hole(at: float, index: int) -> void:
	var root := Node3D.new()
	run.add_child(root)
	root.transform = run.route_frame(at)
	var dark: MeshInstance3D = run.box(root, Vector3(0, 0.012, 0), Vector3(7.2, 0.01, HOLE_LENGTH), run.material(Color(0.004, 0.003, 0.004)))
	var rim: MeshInstance3D = run.box(root, Vector3(0, 0.02, HOLE_LENGTH * 0.5), Vector3(7.2, 0.012, 0.12), run.material(Color(0.8, 0.12, 0.06), true))
	dark.scale.z = 0.01
	rim.hide()
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 0.5, 0)
	glow.light_color = Color(1, 0.08, 0.04)
	glow.light_energy = 0.0
	glow.omni_range = 9
	root.add_child(glow)
	_add(root, at, "hole", {"dark": dark, "rim": rim, "glow": glow})

# A cabinet on chains sweeps the width of the corridor; the gap is read by timing it.
func swing(at: float, index: int) -> void:
	var root := Node3D.new()
	run.add_child(root)
	root.transform = run.route_frame(at)
	var arm := Node3D.new()
	arm.position.y = 3.4
	root.add_child(arm)
	var chain: StandardMaterial3D = run.material(Color(0.1, 0.1, 0.11))
	run.box(arm, Vector3(0, -1.0, 0), Vector3(0.06, 2.0, 0.06), chain)
	run.prop(arm, "industrial_storage_cart", Vector3(0, -3.1, 0), Vector3(1.5, 1.2, 0.9))
	_add(root, at, "swing", {"arm": arm, "x": 0.0, "phase": index * 1.3})

# One of them is already ahead: it steps out of a doorway into a lane.
func ambush(at: float, side: float, index: int) -> void:
	var root := Node3D.new()
	run.add_child(root)
	root.transform = run.route_frame(at)
	_add(root, at, "ambush", {"side": side, "x": side * 3.4})

func reset() -> void:
	for entry in entries:
		entry.shifted = false
		entry.shift = 0.0
		entry.passed = false
		match entry.kind:
			"door":
				entry.hinge.rotation.y = -entry.side * PI * 0.5
				entry.block.disabled = true
				entry.glow.light_energy = 0.0
			"topple":
				entry.pivot.rotation.x = 0.0
				entry.tall.disabled = false
				entry.low.disabled = true
			"fall":
				entry.visual.position.y = 3.4
			"ambush":
				entry.x = entry.side * 3.4
			"hole":
				entry.dark.scale.z = 0.01
				entry.rim.hide()
				entry.glow.light_energy = 0.0
	if ambusher != null:
		ambusher.vanish()

func _start(entry: Dictionary, lead: float) -> void:
	if entry.shifted or lead <= 0.0 or lead > TRIGGER:
		return
	entry.shifted = true
	if entry.kind == "swing" or entry.kind == "pit":
		return
	run.scares.impact(entry.visual.global_position, entry.kind)

func tick(delta: float) -> void:
	for entry in entries:
		var lead: float = entry.distance - run.distance
		if absf(lead) > 60.0:
			continue
		_start(entry, lead)
		match entry.kind:
			"door":
				if entry.shifted and entry.shift < 1.0:
					entry.shift = minf(1.0, entry.shift + delta * 5.0)
					entry.hinge.rotation.y = lerpf(-entry.side * PI * 0.5, 0.0, entry.shift)
					entry.glow.light_energy = 3.0 * entry.shift
					entry.block.disabled = entry.shift < 0.6
			"topple":
				if entry.shifted and entry.shift < 1.0:
					entry.shift = minf(1.0, entry.shift + delta * 2.3)
					entry.pivot.rotation.x = entry.shift * entry.shift * PI * 0.5
					if entry.shift > 0.55:
						entry.tall.disabled = true
						entry.low.disabled = false
			"fall":
				if entry.shifted and entry.shift < 1.0:
					entry.shift = minf(1.0, entry.shift + delta * 3.2)
					entry.visual.position.y = lerpf(3.4, 0.0, entry.shift * entry.shift)
			"hole":
				if entry.shifted and entry.shift < 1.0:
					entry.shift = minf(1.0, entry.shift + delta * 3.0)
					entry.dark.scale.z = maxf(entry.shift, 0.01)
					entry.glow.light_energy = 4.0 * entry.shift
					entry.rim.show()
			"pit":
				for i in range(entry.hands.size()):
					entry.hands[i].position.y = 0.2 + sin(run.clock * 5.0 + i) * 0.22
				if absf(lead) < PIT_DEPTH and run.jump_height < PIT_CLEAR:
					run.obstacle_hit()
			"swing":
				var angle: float = sin(run.clock * TAU / SWING_PERIOD + entry.phase) * 0.92
				entry.arm.rotation.z = angle
				entry.x = sin(angle) * SWING_REACH / sin(0.92)
				if absf(lead) < 0.9 and absf(run.lane_x - entry.x) < SWING_HIT:
					run.obstacle_hit()
			"ambush":
				_tick_ambush(entry, lead, delta)

func _tick_ambush(entry: Dictionary, lead: float, delta: float) -> void:
	if not entry.shifted or lead < -3.0:
		return
	if ambusher.owner_entry != entry:
		ambusher.owner_entry = entry
		ambusher.appear(entry.visual.to_global(Vector3(entry.x, 0.05, 0)), run.world.player.global_position)
	entry.x = move_toward(entry.x, entry.side * AMBUSH_SIDE, delta * 9.0)
	ambusher.global_position = entry.visual.to_global(Vector3(entry.x, 0.05, 0))
	ambusher.animate(delta, 1.0)
	if lead < -2.0:
		ambusher.vanish()
	elif absf(lead) < 0.8 and absf(run.lane_x - entry.x) < AMBUSH_HIT:
		run.obstacle_hit()
