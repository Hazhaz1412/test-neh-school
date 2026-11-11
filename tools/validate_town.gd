extends SceneTree
# Drives the real town: map sanity, the ride from home to school, dialogue, the full day.
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var town: Node3D = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await process_frame
	await process_frame
	var plan: RefCounted = town.plan
	check(plan.lots.size() > 400, "lots placed: %d" % plan.lots.size())
	var blocked := 0
	for lot in plan.lots:
		if plan.in_corridor(lot.centre, 0.0):
			blocked += 1
	check(blocked == 0, "no house sits on a road (%d)" % blocked)
	for place in plan.places:
		check(not plan.place_lot(place.id).is_empty(), "place exists: " + place.id)
	var player: CharacterBody3D = town.player
	check(player.can_mount(), "scooter is within reach at the door")
	player.toggle_bike()
	check(player.riding(), "mounting works")
	# Ride a real route with the real controller: alley, main road, bridge, salt road.
	var route := _route(plan, ["Hẻm 31", "Hẻm 27", "Đường Cổ Đằng", "Cầu Mây", "Đường Đồng Muối"])
	var started := Time.get_ticks_msec()
	var reached := await _ride(town, route)
	print("ride ", snappedf(reached[1], 0.1), " s of game time, real ms ", Time.get_ticks_msec() - started)
	check(reached[0], "rode from home to the school gate")
	check(reached[1] < 75.0, "home to school under 75 s")
	check(reached[2] < 2.0, "never stuck against a wall for 2 s (%.1f)" % reached[2])
	check(absf(player.global_position.y) < 0.3, "ends on the ground")
	player.speed = 0.0
	var story: Node = town.story
	story.talk("sau")
	check(story.talking_now(), "people still talk")
	story.close()
	check(player.enabled, "controls return after talking")
	var state: Dictionary = town.get_node("ArgBridge")._story_state()
	check(state.type == "state" and state.stage == "DAY_FREE", "web receives the free morning")
	# The real save may already hold a win; this check sets its own state and puts it back.
	var caro_won: bool = story.gear.caro_won
	story.gear.caro_won = false
	check(story.caro_table != null and story.objective().text.contains("Bảy Rô"), "Day 1 sends the player to Bảy Rô first")
	story._gate()
	await process_frame
	check(current_scene == town and not story.finished_day, "the school gate waits until Bảy Rô is beaten")
	story.gear.caro_won = true
	story._gate()
	story.gear.caro_won = caro_won
	var moved := false
	for i in range(420):
		await process_frame
		if current_scene != town and current_scene != null:
			moved = true
			break
	check(moved and has_meta("night_one"), "the school gate opens Night 1")
	print("failures ", failures)
	quit(failures)

func _route(plan: RefCounted, names: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var cuts := {"Hẻm 31": [Vector2(14, 58), Vector2(-19, 60)], "Hẻm 27": [Vector2(-18, 60), Vector2(-30, -2)], "Đường Cổ Đằng": [Vector2(-30, -2), Vector2(70, -2)], "Cầu Mây": [Vector2(70, -2), Vector2(130, -2)], "Đường Đồng Muối": [Vector2(130, -2), Vector2(259, 26)]}
	for title in names:
		var road: Dictionary = plan.road_named(title)
		var from: int = plan._closest_index(road, cuts[title][0])
		var to: int = plan._closest_index(road, cuts[title][1])
		var step := 1 if to >= from else -1
		var i := from
		while i != to:
			points.append(road.path[i])
			i += step
	return points

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

# Rides by holding the same keys a player does, steering at a point on the road ahead.
func _ride(town: Node3D, route: PackedVector2Array) -> Array:
	var player: CharacterBody3D = town.player
	var plan: RefCounted = town.plan
	player.scripted = true
	var index := 0
	var time := 0.0
	var worst := 0.0
	var last := Vector2.INF
	var still := 0.0
	player.heading = atan2(-(route[6] - route[0]).x, -(route[6] - route[0]).y)
	while time < 120.0 and index < route.size() - 2:
		await physics_frame
		var step := 1.0 / Engine.physics_ticks_per_second
		time += step
		var at := Vector2(player.global_position.x, player.global_position.z)
		var near: Dictionary = plan.nearest(at)
		var alley: bool = near.is_empty() or plan.roads[near.road].kind == "alley"
		var reach := 3.5 if alley else 7.0
		while index < route.size() - 1 and at.distance_to(route[index]) < reach:
			index += 1
		var goal := route[mini(index, route.size() - 1)]
		var turn := angle_difference(player.heading, atan2(-(goal - at).x, -(goal - at).y))
		_key(KEY_A, turn > 0.05)
		_key(KEY_D, turn < -0.05)
		var limit: float = 8.0 if alley or absf(turn) > 0.5 else player.TOP_SPEED
		_key(KEY_W, player.speed < limit)
		_key(KEY_SPACE, player.speed > limit + 1.0)
		if OS.has_environment("NEH_TOWN_TRACE") and fmod(time, 3.0) < step:
			print(snappedf(time, 0.1), " at ", player.global_position, " speed ", snappedf(player.speed, 0.1), " goal ", goal, " index ", index, "/", route.size())
		still = still + step if at.distance_to(last) < 0.02 else 0.0
		worst = maxf(worst, still)
		last = at
	for code in [KEY_W, KEY_A, KEY_D, KEY_SPACE]:
		_key(code, false)
	player.scripted = false
	return [index >= route.size() - 2, time, worst]
