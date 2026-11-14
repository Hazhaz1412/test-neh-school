extends SceneTree
# godot --headless --path . --script tools/validate_dream.gd
# The dream shore end to end, solved the intended way, with the wrong ways checked to fail:
# the rise, the floor giving way, falling and coming back, bridge 1 (forced perspective),
# the carried board (side-on fails, end-on spans), the leapfrog, the pier to the second
# viewpoint and bridge 2, the gate photo, the lucid climb past the gate (pulling the missing
# steps in, every jump of the spiral made on real physics, the cloud and the door) and waking
# at home. Also: a weightless jump still cannot clear a gap of the photo puzzles.
var failures := 0
var dream: Node3D
var p: CharacterBody3D

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: failures += 1

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

# Put the eye at `at` looking at `target`, physics off so nothing moves it.
func stand(at: Vector3, target: Vector3) -> void:
	p.set_physics_process(false)
	p.global_position = at - Vector3.UP * p.EYE
	p.velocity = Vector3.ZERO
	var flat := Vector3(target.x - at.x, 0, target.z - at.z)
	p.yaw = atan2(-flat.x, -flat.z)
	p.pitch = atan2(target.y - at.y, flat.length())
	p.rotation.y = p.yaw
	p.camera.rotation.x = p.pitch
	p.camera.position.y = p.EYE
	await frames(3)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func snap() -> void:
	dream.camera.raised = true
	await frames(2)
	dream.camera.take()
	dream.camera.raised = false
	await frames(1)

func put_down() -> void:
	dream.camera.holding = true
	await frames(2)
	dream.camera.place()
	await frames(2)

# Walk in a straight line on real physics; true if the player got there without falling.
func walk_to(target: Vector3, seconds := 12.0) -> bool:
	p.set_physics_process(true)
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		var to := target - p.global_position
		to.y = 0
		if to.length() < 0.3: return true
		if dream.state != "walk": return false
		p.velocity.x = to.normalized().x * 6.0
		p.velocity.z = to.normalized().z * 6.0
		await physics_frame
	return false

func feet(x: float, z: float) -> Vector3:
	return Vector3(x, 1.6 + maxf(p.global_position.y, 0.0), z)

func run() -> void:
	Engine.time_scale = 1.0
	change_scene_to_file("res://scenes/dream_shore.tscn")
	await frames(2)
	dream = current_scene
	p = dream.player
	var cam: CanvasLayer = dream.camera
	check(dream.state == "rise" and not p.enabled, "starts lying in the water without control")
	await create_timer(6.5).timeout
	check(dream.state == "walk" and p.enabled, "control after the rise")
	check(not cam.enabled, "no camera before the floor goes")
	await stand(Vector3(0, 1.6, -18), Vector3(0, 1.6, -40))
	check(dream.stage == "collapse", "walking past the classroom brings the floor down")
	await create_timer(5.0).timeout
	check(dream.stage == "bridge1" and cam.enabled, "the pieces rise and the camera comes out")
	# Off the edge and back.
	p.set_physics_process(true)
	p.global_position = Vector3(0, 0, -40)
	await create_timer(1.3).timeout
	check(dream.state == "fall", "stepping into the rift falls")
	await create_timer(2.4).timeout
	check(dream.state == "walk" and p.global_position.distance_to(dream.SAFE["bridge1"]) < 1.0, "and comes back at the lip")
	# 1. Bridge 1.
	await stand(Vector3(-2, 1.6, -26), Vector3(0, 0, -41))
	await snap()
	check(not dream.bridge.solid and dream.bridge.joining < 0.0, "1 a photo from the wrong place leaves the pieces (%.0f px)" % dream.bridge.misalignment(p.camera))
	await stand(dream.EYE, Vector3(0, 0, -41))
	check(dream.bridge.misalignment(p.camera) < dream.bridge.ALIGNED_PX, "1 beside the lone desk the pieces line up (%.1f px)" % dream.bridge.misalignment(p.camera))
	await snap()
	await create_timer(2.4).timeout
	check(dream.bridge.solid, "1 a photo from there joins the path")
	p.global_position = Vector3(0, 0.05, -31)
	check(await walk_to(Vector3(0, 0, -54)), "1 the path carries the player to island A")
	await frames(3)
	check(dream.stage == "board", "2 island A begins the board puzzle")
	# 2. The board only exists in the past, lying east-west. Side-on it lands sideways.
	var board: Node3D = dream.boards[0].node
	check(board.is_in_group("dream_past") and board.is_in_group("dream_movable"), "2 the board is a memory that can be carried")
	await stand(Vector3(-2, 1.6, -52.5), Vector3(-2, 0, -57))
	await snap()
	check(cam.photo.movables.has(board), "2 the photo keeps the board")
	await stand(Vector3(0, 1.6, -62.3), Vector3(0, 0, -66.8))
	await put_down()
	check(not board.is_in_group("dream_past"), "2 put down, it is real")
	var along := board.global_basis.z
	check(absf(along.x) > 0.9, "2 photographed side-on it lands across the way, not over the gap")
	p.global_position = Vector3(0, 0.1, -62.0)
	check(not await walk_to(Vector3(0, 0, -71), 5.0), "2 and does not carry the player over")
	await create_timer(2.6).timeout
	# Photograph it again end-on (it is real now, wherever it lies) and put it across.
	dream.reset_boards()
	await frames(2)
	check(board.is_in_group("dream_past") and board.position.distance_to(Vector3(-2, 0, -57)) < 0.01, "2 R puts it back as a memory")
	# A running jump off the lip of island A, weightless as it is, does not reach island B.
	p.set_physics_process(true)
	p.global_position = Vector3(0, 0.05, -60.5)
	p.yaw = 0.0
	p.drive = Vector2(0, -1)
	await create_timer(1.0).timeout
	p.jump()
	var flew := 0.0
	while dream.state == "walk" and flew < 6.0:
		flew += 1.0 / 60.0
		await physics_frame
	p.drive = Vector2.ZERO
	check(dream.state == "fall", "2 a jump does not clear the 6 m gap")
	await create_timer(2.6).timeout
	await stand(Vector3(-7.0, 1.6, -57), Vector3(-2, 0, -57))
	await snap()
	await stand(Vector3(0, 1.6, -62.4), Vector3(0, 1.6 - 1.6 / 4.6 * 4.5, -66.9))
	p.pitch = cam.photo.pitch
	p.camera.rotation.x = p.pitch
	await put_down()
	along = board.global_basis.z
	check(absf(along.z) > 0.95 and absf(board.global_position.z + 66.5) < 1.0, "2 photographed end-on it lands over the gap (centre z %.1f)" % board.global_position.z)
	p.global_position = Vector3(0, 0.1, -62.0)
	check(await walk_to(Vector3(0, 0, -72)), "2 and carries the player to island B")
	await frames(3)
	check(dream.stage == "leap" and not board.is_in_group("dream_movable"), "3 island B begins the leapfrog; the old board stays put")
	# 3. Leapfrog two boards over 18 m.
	var b1: Node3D = dream.boards[1].node
	var b2: Node3D = dream.boards[2].node
	var edge := -80.4
	var from := edge
	var carry := [b1, b2, b1]
	for hop in range(3):
		var b: Node3D = carry[hop]
		if hop < 2:
			# On the island: stand at the board's end, a little off it, looking along it.
			# From the end where the other board is out of frame: two boards in one photo move together.
			var dir := b.global_basis.z.normalized()
			await stand(b.global_position + dir * 5.0 + Vector3(0, 1.6, 0), b.global_position - dir * 0.5)
		else:
			# The third hop is taken standing on the second board, the first one behind.
			# From far away it would land just as far away, so go back to where the two meet.
			var near_end := maxf((b2.global_position - b2.global_basis.z * 4.0).z, (b2.global_position + b2.global_basis.z * 4.0).z)
			await stand(feet(0, from + 0.2), b1.global_position)
			await snap()
			await stand(feet(0, from + 0.2), Vector3(0, 0, from - 4.4))
			var far_pitch: float = cam.photo.pitch
			check(cam.photo.movables.has(b1), "3 hop 3: from the far end the first board is in the photo too")
			cam.holding = true
			await frames(2)
			var lands: Vector3 = (p.camera.global_transform * cam.photo.relative[0]).origin
			cam.holding = false
			check(lands.z + 4.0 < from - 3.0, "3 hop 3: but from that far it would land short of nothing, %.1f m ahead" % (from - lands.z - 4.0))
			var _unused := far_pitch
			await stand(feet(0, near_end - 0.9), b1.global_position)
		await snap()
		check(cam.photo.movables.has(b) and cam.photo.movables.size() == 1, "3 hop %d: only that board in the photo (%d)" % [hop + 1, cam.photo.movables.size()])
		await stand(feet(0, from + 0.2), Vector3(0, 0, from - 4.4))
		p.pitch = cam.photo.pitch
		p.camera.rotation.x = p.pitch
		await put_down()
		var far_end := minf((b.global_position - b.global_basis.z * 4.0).z, (b.global_position + b.global_basis.z * 4.0).z)
		print("     hop %d: board now z %.1f .. %.1f" % [hop + 1, far_end + 8.0, far_end])
		p.global_position = Vector3(0, 0.15, from + 0.1)
		if hop < 2:
			check(await walk_to(Vector3(0, 0, far_end + 0.8)), "3 hop %d: walks out to its end" % (hop + 1))
			from = p.global_position.z
	check(await walk_to(Vector3(0, 0, -102)), "3 the third board reaches island C")
	await frames(3)
	check(dream.stage == "bridge2", "4 island C begins the second broken path")
	# 4. The viewpoint is over the void: make a pier of the island's board.
	await stand(Vector3(0, 1.6, -108), Vector3(0, 0, -120))
	check(dream.bridge2.misalignment(p.camera) > 60.0, "4 from the island the pieces do not line up (%.0f px)" % dream.bridge2.misalignment(p.camera))
	var pier: Node3D = dream.boards[3].node
	await stand(Vector3(-4, 1.6, -100.0), Vector3(-4, 0, -104.9))
	await snap()
	check(cam.photo.movables.has(pier), "4 the island's board in the photo")
	await stand(Vector3(8.4, 1.6, -104.0), Vector3(12.9, 0, -104.0))
	p.pitch = cam.photo.pitch
	p.camera.rotation.x = p.pitch
	await put_down()
	check(absf(pier.global_basis.z.x) > 0.95 and pier.global_position.x > 11.0, "4 it lands out over the void as a pier (centre x %.1f)" % pier.global_position.x)
	p.global_position = Vector3(8.0, 0.1, -104.0)
	var reached: bool = await walk_to(Vector3(dream.EYE2.x, 0, dream.EYE2.z))
	check(reached, "4 the pier carries the player to the viewpoint (at %s, pier %s, state %s)" % [p.global_position, pier.global_position, dream.state])
	await stand(dream.EYE2 + Vector3(0, p.global_position.y, 0) * 0.0, Vector3(0, 0, -120))
	check(dream.bridge2.misalignment(p.camera) < dream.bridge2.ALIGNED_PX, "4 from there the pieces line up (%.1f px)" % dream.bridge2.misalignment(p.camera))
	await snap()
	await create_timer(2.4).timeout
	check(dream.bridge2.solid, "4 a photo from there joins the second path")
	p.global_position = Vector3(0, 0.1, -109)
	check(await walk_to(Vector3(0, 0, -133)), "4 the path carries the player to the far bank")
	await frames(3)
	check(dream.stage == "gate", "5 the gate is next")
	# 5. The gate.
	var gate_z: float = dream.GATE_AT.z
	p.global_position = Vector3(0, 0.05, gate_z + 5)
	check(not await walk_to(Vector3(0, 0, gate_z - 4), 3.0) and p.global_position.z > gate_z, "5 the shut gate blocks the way")
	var spot := Vector3(1.5, 1.6, gate_z + 20)
	await stand(spot, Vector3(0, 2, gate_z))
	await snap()
	check(cam.photo.fixed.has(dream.school.get_node("GateOpen")), "5 the photo remembers the open gate")
	await stand(spot + Vector3(1.0, 0, 0), Vector3(1.0, 2, gate_z))
	cam.holding = true
	await frames(2)
	var aside: float = cam.place_error()
	cam.place()
	check(dream.stage == "gate", "5 pressed in from a step aside it does nothing (%.0f px)" % aside)
	await stand(spot, Vector3(0, 2, gate_z))
	cam.place()
	check(dream.stage == "open" and not dream.school.get_node("GateShut").visible, "5 pressed in, in line, the gate opens")
	p.global_position = Vector3(0, 0.05, gate_z + 5)
	await walk_to(Vector3(0, 0, gate_z - 6), 5.0)
	check(dream.stage == "lucid" and p.lucid and not cam.enabled and dream.state == "walk", "6 through the gate the dream goes lucid")
	var sky: Node3D = dream.sky
	await create_timer(9.0).timeout
	check(sky.risen(), "6 the yard's things have risen into a spiral")
	# Before anything is pulled, a missing step cannot be jumped.
	var first_gap: int = sky.MISSING[0]
	check(not await hop(sky.pieces[first_gap - 1], sky.pieces[first_gap + 1]), "6 a missing step is too far to jump")
	# Pull each missing piece into its slot, standing on the step before it.
	for gap in sky.MISSING:
		var piece: Dictionary = sky.pieces[gap]
		var before: Dictionary = sky.pieces[gap - 1]
		var top: Vector3 = before.body.global_position
		var eye := top + Vector3(0, 1.6, 0)
		await stand(eye, piece.body.global_position - Vector3(0, piece.size.y * 0.5, 0))
		check(sky.aimed().get("index", -1) == gap, "6 step %d: looking at it picks the piece that floated off" % gap)
		sky.set_pulling(true)
		var slot: Vector3 = sky.to_global(sky.slot_at(gap))
		await stand(eye, slot)
		await create_timer(4.0).timeout
		sky.set_pulling(false)
		await frames(3)
		var off: float = piece.body.global_position.distance_to(slot)
		check(off < 1.5, "6 step %d: pulled in where the eye put it (%.2f m from the slot)" % [gap, off])
	# Climb it for real: every jump, ground to cloud.
	p.set_physics_process(true)
	var ground: Vector3 = sky.to_global(sky.slot_at(0)) + Vector3(0, -sky.FIRST, 3.0)
	p.global_position = ground
	p.velocity = Vector3.ZERO
	await frames(5)
	var climbed := 0
	var target_body: Node3D = sky.pieces[0].body
	if await hop_to(target_body):
		climbed = 1
		for i in range(1, sky.STEPS):
			if not await hop(sky.pieces[i - 1], sky.pieces[i]):
				print("     missed step %d at %s" % [i, p.global_position])
				break
			climbed += 1
	check(climbed == sky.STEPS, "6 the whole spiral climbed jump by jump (%d / %d)" % [climbed, sky.STEPS])
	var cloud: Node3D = sky.get_node("CloudIsland")
	var on_cloud: Vector3 = cloud.global_position + Vector3(0, 0.5, 0) - sky.island_dir * 12.0
	check(await hop_to(null, on_cloud), "6 and onto the cloud (at %s)" % p.global_position)
	var door: Node3D = sky.door
	var left := 12.0
	while dream.state == "walk" and left > 0.0:
		var to := door.global_position - p.global_position
		p.yaw = atan2(-to.x, -to.z)
		p.drive = Vector2(0, -1)
		left -= 1.0 / 60.0
		await physics_frame
	p.drive = Vector2.ZERO
	check(dream.state == "leave", "walking through the door in the clouds ends the dream")
	await create_timer(4.5).timeout
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/home.tscn", "wakes up at home")
	print("failures: %d" % failures)
	quit(failures)

# Stand in the middle of one piece and make a running jump for another, floating on the way down.
func hop(from: Dictionary, to: Dictionary) -> bool:
	p.set_physics_process(true)
	var body: Node3D = from.body
	var away: Vector3 = body.global_position - to.body.global_position
	away.y = 0
	# Start a little back from the middle, on the side away from the target, for a run-up.
	var run_up := minf(maxf(from.size.x, from.size.z) * 0.3, 0.8)
	p.global_position = body.global_position + away.normalized() * run_up + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	await frames(4)
	return await hop_to(to.body)

# Run at `body` (or at `point`), jump when the floor ahead runs out, float down; true on landing.
func hop_to(body: Node3D, point := Vector3.ZERO) -> bool:
	var sky: Node3D = dream.sky
	var jumped := false
	var left := 7.0
	while left > 0.0:
		left -= 1.0 / 60.0
		var aim := point if body == null else body.global_position
		var to := aim - p.global_position
		to.y = 0
		p.yaw = atan2(-to.x, -to.z)
		p.drive = Vector2(0, -1) if to.length() > 0.25 else Vector2.ZERO
		p.drive_float = jumped and p.velocity.y < 0.0
		if p.is_on_floor():
			var under: Dictionary = sky.standing_on()
			var arrived: bool = (body != null and not under.is_empty() and under.body == body) or (body == null and p.global_position.y > sky.cloud_top - 0.3)
			if arrived:
				p.drive = Vector2.ZERO
				p.drive_float = false
				await frames(2)
				return true
			if jumped:
				break
			var forward := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
			var space := p.get_world_3d().direct_space_state
			var ray := PhysicsRayQueryParameters3D.create(p.global_position + forward * 0.5 + Vector3.UP * 0.3, p.global_position + forward * 0.5 + Vector3.DOWN * 0.4)
			ray.exclude = [p.get_rid()]
			if space.intersect_ray(ray).is_empty() or p.is_on_wall():
				p.jump()
				jumped = true
		await physics_frame
	p.drive = Vector2.ZERO
	p.drive_float = false
	return false
