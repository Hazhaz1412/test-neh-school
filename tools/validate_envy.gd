extends SceneTree
# A knows, B searches. Checks the wall between them and B's search in the real school.
var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func until(test: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if test.call():
			return true
	return false

func hide_in(spot: Node3D) -> void:
	spot.occupant = school.player
	school.player.begin_hide(spot)

func unhide() -> void:
	school.player.end_hide()

func run() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	for i in range(20): await physics_frame
	school.survival.start_run(false)
	school.progression.briefing_complete = true
	school.set_spirit_world(true, true)
	school.progression.set_physics_process(false)
	school.survival.set_physics_process(false)
	school.scares.enabled = false
	school.player.set_physics_process(false)
	school.player.global_position = Vector3(0, 0.05, 40)
	var director: Node = school.envy
	director.hunting_night = true
	var ready_now := await until(func(): return director.started, 3.0)
	check(ready_now, "the demon wakes after Lan's briefing")
	var demon: CharacterBody3D = director.demon
	demon.set_physics_process(false)
	check(demon.global_position.distance_to(school.player.global_position) > 20.0, "it starts far from the player: %d m" % demon.global_position.distance_to(school.player.global_position))
	var script_text := FileAccess.get_file_as_string("res://scripts/envy_demon.gd")
	check(not "player.global_position" in script_text.get_slice("func _next_search", 1).get_slice("func _head_for", 0), "B chooses where to search without reading the player's position")
	var exact := 0
	var outside := 0
	for i in range(200):
		var hint: Dictionary = director.make_hint()
		var gap: float = Vector2(hint.centre.x - school.player.global_position.x, hint.centre.z - school.player.global_position.z).length()
		if gap < 0.5:
			exact += 1
		if gap > hint.radius:
			outside += 1
	check(exact == 0, "A never hands over the exact position")
	check(outside == 0, "the player is always inside the hinted area")
	var wide: float = director.make_hint().radius
	director.quiet_time = director.PATIENCE
	check(director.make_hint().radius < wide * 0.5, "hiding longer narrows the hint")
	director.quiet_time = 0.0
	# The hint no longer depends on what the player carries (nothing is stolen any more).
	var kept: Array[String] = school.player.inventory.duplicate()
	school.player.inventory = kept
	demon.set_physics_process(true)
	director.set_physics_process(false)
	# A real hiding place, reached by real navigation.
	var spots: Array = school.get_tree().get_nodes_in_group("hiding_spots").filter(func(s): return s.global_position.y < 1.0 and s.kind == s.Kind.LOCKER and s.global_position.distance_to(demon.global_position) > 8.0)
	spots.sort_custom(func(a, b): return a.global_position.distance_to(demon.global_position) < b.global_position.distance_to(demon.global_position))
	var spot: Node3D = spots[0]
	school.player.global_position = spot.approach_position()
	hide_in(spot)
	demon.whisper(spot.global_position + Vector3(3, 0, 2), 6.0)
	check(demon.state == demon.State.SWEEP or demon.state == demon.State.LISTEN, "a whisper starts a search: " + demon.state_name())
	school.player.holding_breath = false
	var moved := demon.global_position
	var found := await until(func(): return not school.player.is_hidden(), 90.0)
	check(found, "B walks there, listens and drags the hider out")
	check(demon.global_position.distance_to(moved) > 3.0, "it really walked there")
	check(demon.state == demon.State.CHASE or demon.state == demon.State.STRIKE, "finding someone starts the chase")
	# Same place, this time holding breath.
	school.player.health = 100.0
	demon.fall_back(demon.global_position, 0.0)
	demon.checked.clear()
	await physics_frame
	hide_in(spot)
	school.player.holding_breath = true
	demon.state = demon.State.ROAM
	demon.whisper(spot.global_position, 3.0)
	var passed := await until(func(): return demon.checked.has(spot), 60.0)
	check(passed, "B still checks the spot")
	check(school.player.is_hidden(), "a held breath survives the check")
	unhide()
	school.player.holding_breath = false
	# Sight: plain view in front of it.
	school.player.flashlight.hide()
	demon.fall_back(demon.global_position, 0.0)
	await physics_frame
	await physics_frame
	# Open ground, so nothing but its senses decides the result.
	var map: RID = school.get_world_3d().navigation_map
	demon.global_position = NavigationServer3D.map_get_closest_point(map, Vector3(0, 0, 76)) + Vector3.UP * 0.05
	demon.rotation = Vector3.ZERO
	await physics_frame
	school.player.global_position = demon.global_position - demon.global_basis.z * 6.0
	demon.state = demon.State.ROAM
	demon.agent.target_position = school.player.global_position
	school.player.health = 100.0
	var item: String = school.player.selected_item()
	var seen := await until(func(): return demon.is_hunting(), 8.0)
	check(seen, "it notices a player in plain view")
	school.player.invulnerable_time = 0.0
	var struck := await until(func(): return school.player.health < 100.0, 10.0)
	# Nothing is stolen any more; without a team to free them (the spirit nights), a catch ends it.
	check(struck and school.player.health <= 0.0, "reaching the player ends the run")
	school.player.health = 100.0
	school.player.enabled = true
	school.death_panel.hide()
	# Left alone: A whispers, B hunts a hider holding their breath, nobody steers either.
	director.set_physics_process(true)
	demon.fall_back(demon.global_position, 0.0)
	demon.checked.clear()
	demon.global_position = NavigationServer3D.map_get_closest_point(map, Vector3(-30, 0, 64)) + Vector3.UP * 0.05
	school.player.health = 100.0
	school.player.global_position = spot.approach_position()
	hide_in(spot)
	school.player.holding_breath = true
	director.quiet_time = 60.0
	director.hint_clock = 0.0
	var start_at: Vector3 = demon.global_position
	var seen_states := {}
	var travelled := 0.0
	var last: Vector3 = start_at
	Engine.time_scale = 6.0
	var ticks := 0
	var visits := 0
	var was_listening := false
	while ticks < 7200:
		await physics_frame
		ticks += 1
		seen_states[demon.state_name()] = true
		var listening: bool = demon.state == demon.State.LISTEN
		if listening and not was_listening:
			visits += 1
		was_listening = listening
		travelled += demon.global_position.distance_to(last)
		last = demon.global_position
	Engine.time_scale = 1.0
	print("twelve game minutes alone: walked ", int(travelled), " m, checked ", demon.checked.size(), " places, states ", seen_states.keys(), " listens ", visits, " hint radius ", int(director.last_hint.get("radius", 0)))
	check(visits >= 8, "B keeps returning to hiding places")
	check(demon.checked.size() >= 3, "B searched several places on its own")
	check(travelled > 30.0, "B kept moving")
	check(seen_states.has("nghe trước chỗ trốn"), "B listened at hiding places")
	check(demon.global_position.y > -1.0, "B stayed on the map")
	print("failures ", failures)
	quit(failures)
