extends "res://tools/validate_progression.gd"
# An autopilot runs the whole corridor with real physics: if it can finish, a player can.
# godot --headless --fixed-fps 60 --path . --script tools/validate_corridor_run.gd
const LOOK := 7.0
var runner: Node3D

func nearest_hazard() -> Dictionary:
	var best := {}
	var lead := INF
	for item in runner.obstacles:
		var gap: float = item.distance - runner.distance
		if gap > -1.2 and gap < 16.0 and gap < lead:
			lead = gap
			best = item
	return best

func lane_for(item: Dictionary) -> float:
	match item.get("kind", ""):
		"gap": return item.gap
		"door", "ambush": return -item.side * 2.2
		"swing": return -signf(item.x) * 2.5 if absf(item.x) > 0.2 else 2.5
		"lane_left", "lane_right":
			var local: Vector3 = runner.route_frame(item.distance).affine_inverse() * (item.visual.position)
			return -signf(local.x) * 2.5
	return 0.0

func drive() -> void:
	var p: CharacterBody3D = school.player
	var item := nearest_hazard()
	var lead: float = item.distance - runner.distance if not item.is_empty() else 99.0
	var ahead: Transform3D = runner.route_frame(runner.distance + LOOK)
	var aim: Vector3 = runner.ORIGIN + ahead.origin + ahead.basis.x * (lane_for(item) if not item.is_empty() else 0.0)
	if runner.distance >= runner.ROOM_DISTANCE - 2.0:
		aim = runner.refuge.to_global(Vector3(-7.5, 0, 1.7))
	var flat: Vector3 = aim - p.global_position
	p.rotation.y = atan2(-flat.x, -flat.z)
	runner.held_keys[KEY_W] = true
	runner.held_keys[KEY_SHIFT] = true
	if not item.is_empty():
		var low_jump: bool = item.kind in ["jump", "pit", "fall"] or (item.kind == "topple")
		var air: float = runner.speed * 0.39
		if low_jump and lead < air + (1.0 if item.kind == "topple" else 0.0) and lead > 0.3 and p.is_on_floor():
			runner.jump()
		if item.kind == "slide" and lead < runner.speed * 0.42 and lead > 0.0:
			runner.slide()

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	story.stage = story.Stage.CORRIDOR_RUN
	school.survival.begin_midnight()
	runner = story.runner
	runner.start()
	school.player.test_invincible()
	var kinds := {}
	for item in runner.obstacles:
		kinds[item.initial_kind if item.challenge == item.initial_kind else item.challenge] = true
	print("variants ", kinds.keys())
	check(kinds.size() >= 11, "the corridor has many obstacle variants: %d" % kinds.size())
	var turns := {}
	for i in range(1, runner.PATH.size() - 1):
		var a: Vector3 = runner.PATH[i] - runner.PATH[i - 1]
		var b: Vector3 = runner.PATH[i + 1] - runner.PATH[i]
		turns["left" if a.cross(b).y > 0 else "right"] = true
	check(turns.size() == 2 and runner.PATH.size() >= 11, "the route turns both ways")
	var longest := 0.0
	for i in range(runner.PATH.size() - 1):
		longest = maxf(longest, runner.PATH[i].distance_to(runner.PATH[i + 1]))
	check(longest <= 110.0, "no leg runs longer than 110 m")
	var frames_run := 0
	var least := 100.0
	var seen_hits := 0
	while runner.active and frames_run < 14000 and school.player.health > 0 and runner.entering_room == false:
		await physics_frame
		drive()
		runner.tick(1.0 / 60)
		frames_run += 1
		least = minf(least, school.player.health)
		if runner.hit_count != seen_hits:
			seen_hits = runner.hit_count
			var near := nearest_hazard()
			print("HIT #%d at %.1f by %s %s lane %.1f speed %.1f stamina %d jump %.2f" % [seen_hits, runner.distance, near.get("kind", "-"), near.get("distance", 0), runner.lane_x, runner.speed, school.player.stamina, runner.jump_height])
		if frames_run % 600 == 0:
			print("t %ds m %d gap %.1f hp %d hits %d zone %d" % [frames_run / 60, runner.distance, runner.ghost_gap, school.player.health, runner.hit_count, runner.zone_at(runner.distance)])
	print("finished after %d s, %d hits, lowest health %d, distance %d, beats %d/%d" % [frames_run / 60, runner.hit_count, least, runner.distance, runner.scares.next_beat, runner.scares.BEATS.size()])
	check(runner.entering_room, "the autopilot reaches Lan's room alive")
	check(runner.scares.next_beat == runner.scares.BEATS.size(), "every scare beat played")
	check(runner.hazards.entries.all(func(e): return e.shifted), "every hazard sprang")
	print("RESULT / ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
