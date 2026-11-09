extends SceneTree
# Night 1 chase audit: the guard runs a fleeing friend down on the real map. Reports how often he
# stands still mid-chase (a stall over STALL seconds), how often he loses the trail, and when he
# catches them. godot --headless --fixed-fps 60 --path . --script tools/measure_guard_chase.gd
const STALL := 1.0
const SECONDS := 70.0
const STARTS := [Vector3(-46, 0.05, 20), Vector3(0, 0.05, 40), Vector3(45, 0.05, -45), Vector3(-20, 0.05, 66)]
# Where he starts, from the prey: always out in the same open ground, never inside a room.
const BEHIND := [Vector3(0, 0, -9), Vector3(9, 0, 0), Vector3(0, 0, -9), Vector3(9, 0, 0)]

var trace := OS.get_cmdline_user_args().has("trace")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(300):
		await physics_frame
		if school.hunt.started: break
	for i in range(30): await physics_frame
	var team: Node = school.team
	var hunter: CharacterBody3D = school.hunt.hunter
	var player: CharacterBody3D = school.player
	player.global_position = Vector3(0, 0.05, -78)
	for run_index in range(STARTS.size()):
		var prey: CharacterBody3D = team.members[1 + run_index % 3].body
		for entry in team.members:
			if entry.body != player and entry.body != prey:
				entry.body.global_position = Vector3(-55 + run_index, 0.05, -78)
		prey.global_position = STARTS[run_index]
		prey.stamina = prey.MAX_STAMINA
		prey.fatigue = 0.0
		hunter.global_position = STARTS[run_index] + BEHIND[run_index]
		hunter.target = prey
		hunter.state = hunter.State.CHASE
		hunter.chase_time = 0.0
		hunter.unseen = 0.0
		var stalls := 0
		var stalled := 0.0
		var losses := 0
		var was_chasing := true
		var caught_at := -1.0
		var last := hunter.global_position
		var crossing := false
		var gap_before := 0.0
		var kind := ""
		var longest := 0.0
		var clock := 0.0
		while clock < SECONDS:
			await physics_frame
			clock += 1.0 / 60.0
			var moved := hunter.global_position.distance_to(last) / (1.0 / 60.0)
			last = hunter.global_position
			# Each time the prey starts a crossing, and once the guard is past it: the gap won.
			if prey.cross_time > 0.0 and not crossing:
				crossing = true
				gap_before = walk(school, hunter.global_position, prey.global_position)
				kind = "khe thấp" if prey.crawling else "cửa sổ/kệ"
			elif crossing and prey.cross_time <= 0.0 and hunter.cross_time <= 0.0 and hunter.clear_time <= 0.0:
				crossing = false
				print("  %s at t %.1f: his walk to them %.1f -> %.1f m" % [kind, clock, gap_before, walk(school, hunter.global_position, prey.global_position)])
			if int(clock * 60.0) % 30 == 0:
				var w := walk(school, hunter.global_position, prey.global_position)
				longest = maxf(longest, w)
				if trace:
					print("    t %.1f guard %s %s prey %s walk %.1f stam %d fat %.2f" % [clock, hunter.global_position.snapped(Vector3.ONE * 0.1), hunter.state_name(), prey.global_position.snapped(Vector3.ONE * 0.1), w, prey.stamina, prey.fatigue])
			var chasing: bool = hunter.state in [hunter.State.CHASE, hunter.State.STRIKE]
			if chasing and moved < 0.3 and hunter.cross_time <= 0.0 and hunter.clear_time <= 0.0 and hunter.board_time <= 0.0:
				stalled += 1.0 / 60.0
				if is_equal_approx(stalled, STALL) or stalled >= STALL and stalled - 1.0 / 60.0 < STALL:
					stalls += 1
					print("  stall at ", hunter.global_position.snapped(Vector3.ONE * 0.1), " t ", snappedf(clock, 0.1))
			else:
				stalled = 0.0
			if was_chasing and not chasing and hunter.state != hunter.State.GRAB:
				losses += 1
				print("  lost the trail at t ", snappedf(clock, 0.1), " gap ", snappedf(hunter.global_position.distance_to(prey.global_position), 0.1), " -> ", hunter.state_name())
			was_chasing = chasing
			if team.member(prey).status != team.Status.FREE:
				caught_at = clock
				break
		print("RUN %d from %s: caught %s, stalls %d, lost trail %d, longest walk to them %.1f m" % [run_index, STARTS[run_index], ("at %.1f s" % caught_at) if caught_at >= 0.0 else "no", stalls, losses, longest])
		if caught_at >= 0.0:
			# Let him finish the walk and the lock-up, then free them for the next run.
			await until_status(team, prey, 40.0)
			for door in team.jails:
				if not team.prisoners(door).is_empty():
					team._free_jail(door, player)
		prey.invulnerable_time = 0.0
	quit()

# How far he has to walk to reach them (crawl gaps closed to him).
func walk(school: Node3D, from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(school.get_world_3d().navigation_map, from, to, true, 1)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

func until_status(team: Node, body: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and team.member(body).status == team.Status.CARRIED:
		await physics_frame
		left -= 1.0 / 60.0
