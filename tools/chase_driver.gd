extends RefCounted
var runner: Node3D
var world: Node3D
var resting := false
var jumps := 0
var slides := 0
var corners := {}
var shifted_seen := false
var last_yaw := 0.0

func key(code: int, down: bool) -> void:
	if runner.held_keys.get(code,false)==down: return
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	runner._input(event)

func tick() -> void:
	var p: CharacterBody3D = world.player
	var lateral := 0.0
	var hazard: Dictionary = {}
	for obstacle in runner.obstacles:
		var lead: float = obstacle.distance-runner.distance
		if lead>-1.7 and lead<28:
			hazard = obstacle
			if obstacle.shifted: shifted_seen = true
			if obstacle.kind=="lane_right": lateral = 2.55
			elif obstacle.kind=="lane_left": lateral = -2.55
			elif obstacle.kind=="gap": lateral = obstacle.gap
			elif obstacle.kind in ["door","ambush"]: lateral = -obstacle.side*2.2
			elif obstacle.kind=="swing": lateral = -signf(obstacle.x)*2.5 if absf(obstacle.x)>.2 else 2.5
			break
	var target: Vector3 = runner.ORIGIN+runner.route_frame(runner.distance+5).origin
	target += runner.route_frame(runner.distance+5).basis.x*lateral
	if runner.room_open and runner.distance>=runner.ROOM_DISTANCE-1:
		target = runner.refuge.to_global(Vector3(-6.5,0.05,0))
	var toward := target-p.global_position
	var yaw := atan2(-toward.x,-toward.z)
	var motion := InputEventMouseMotion.new()
	motion.relative.x = wrapf(p.rotation.y-yaw,-PI,PI)/p.LOOK_SENSITIVITY
	if DisplayServer.get_name() == "headless": runner.look(motion.relative)
	else: runner._input(motion)
	for junction in runner.junctions:
		if runner.distance>float(junction.distance)-10: corners[junction.distance] = true
	if p.stamina<32: resting = true
	if p.stamina>64: resting = false
	# Build sprint momentum before a forced low passage, even if a stamina
	# recovery window otherwise happens to fall at the same place.
	if not hazard.is_empty() and hazard.kind=="slide" and float(hazard.distance)-runner.distance<12 and p.stamina>6: resting = false
	key(KEY_SHIFT,not resting)
	key(KEY_W,true)
	if not hazard.is_empty():
		var lead: float = hazard.distance-runner.distance
		var reach: float = runner.speed*.39+(1.0 if hazard.kind=="topple" else 0.0)
		if hazard.kind in ["jump","pit","fall","topple"] and lead>.3 and lead<reach and runner.jump_height<0.05 and p.is_on_floor():
			key(KEY_SPACE,true)
			key(KEY_SPACE,false)
			jumps += 1
		if hazard.kind=="slide" and lead>0 and lead<runner.speed*.42 and runner.slide_remaining==0:
			# Begin from genuine speed/momentum, never directly setting posture.
			key(KEY_CTRL,true)
			key(KEY_CTRL,false)
			if runner.slide_remaining>0: slides += 1
