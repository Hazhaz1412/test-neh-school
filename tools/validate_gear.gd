extends SceneTree
# The guard's grab and the back-alley shop, on the real scenes.
const Gear := preload("res://scripts/night_gear.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func wait_for(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0 and not condition.call():
		await physics_frame
		left -= 1.0 / 60.0
	return condition.call()

func grab(school: Node3D, bag: Array) -> Node:
	var hunter: Node = school.hunt.hunter
	var player: CharacterBody3D = school.player
	hunter.fall_back(hunter.global_position, 0.0)
	hunter.state = hunter.State.ROAM
	hunter.target = player
	hunter.global_position = player.global_position + Vector3(0, 0, 1.4)
	player.inventory.assign(bag)
	player.invulnerable_time = 0.0
	player.health = 100.0
	player.enabled = true
	hunter._seize()
	return hunter

func run() -> void:
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	var state := Gear.fresh()
	check(Gear.buy(state, "medicine").is_empty() and state.money == Gear.START_MONEY - 40, "buying costs money")
	state.money = 10
	check(not Gear.buy(state, "battery").is_empty(), "too poor for a battery")
	check(Gear.STOCK.all(func(entry): return entry.kind != "salt_gun"), "the shop sells nothing against ghosts")
	state = Gear.fresh()
	state.money = 999
	for i in range(4): Gear.buy(state, "chalk")
	check(Gear.buy(state, "chalk") == "Túi đầy rồi.", "the bag has a limit")
	check(Gear.loadout(state)[0] == "torch" and Gear.loadout(state).size() == 6, "the Night 0 torch is always first; there is no hand torch")
	check(Gear.STOCK.all(func(entry): return not entry.kind in ["torch", "medal"]), "the shop no longer sells a torch or a medal")
	state.torch = false
	state.money = 999
	Gear.finish_night(state, ["torch", "", "chalk", "", "", ""], ["camera"])
	check(not state.camera and state.pawned.has("camera"), "what it took shows up at the shop")
	var before: int = state.money
	check(Gear.redeem(state, "camera").is_empty() and state.camera and state.money == before - 50, "the camera is redeemed at half value")
	Gear.write(Gear.fresh().merged({"bag": ["medicine", "battery"]}, true))
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(40): await physics_frame
	check(school.player.inventory.has("medicine") and school.player.inventory.has("battery"), "the night starts with what was bought")
	await wait_for(func(): return school.hunt.hunter != null, 3.0)
	await physics_frame
	var player: CharacterBody3D = school.player
	check(player.selected_item() == "torch", "the night starts with the torch in hand")
	check(absf(100.0 / player.FLASHLIGHT_DRAIN - 296.3) < 0.1, "the torch lasts about five minutes")
	school.hunt.set_physics_process(false)
	var hunter: Node = grab(school, ["torch", "camera", "", "", "", ""])
	check(player.seized and hunter.state == hunter.State.GRAB and school.team.member(player).status == school.team.Status.CARRIED, "a catch drags the player off")
	check(player.inventory.has("torch") and player.inventory.has("camera"), "nothing is taken from the bag")
	hunter.break_free()
	await physics_frame
	check(hunter.state == hunter.State.STAGGER and not player.seized, "struggling free drops the player and he staggers")
	check(school.team.member(player).status == school.team.Status.FREE, "and the player is back on their feet")
	school.queue_free()
	remove_meta("night_one")
	await process_frame
	var town: Node3D = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(0.5).timeout
	var door: Dictionary = {}
	for entry in town.interactions:
		if entry.label == "Vào tiệm":
			door = entry
	check(not door.is_empty(), "the shop can be entered")
	check(not town.plan.places.filter(func(p): return p.id == "curio")[0].is_empty(), "the shop is on the plan")
	var feet: Vector3 = door.position + Vector3.UP * 0.2
	var near: Dictionary = town.plan.nearest(Vector2(feet.x, feet.z))
	var hit: Dictionary = town.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(town.plan.roads[near.road].path[near.at].x, 1, town.plan.roads[near.road].path[near.at].y), feet + Vector3.UP * 0.8))
	check(hit.is_empty(), "nothing blocks the way from the alley to the counter")
	town.player.global_position = door.position
	await process_frame
	town._pick_interaction()
	check(town.current.get("label", "") == "Vào tiệm", "standing there offers the shop")
	town.interact()
	await process_frame
	check(town.story.talking_now() and not town.player.enabled, "the shop opens and holds the player")
	town.story.view._buy("battery")
	check(town.story.gear.bag.has("battery"), "the panel buys")
	town.story.close()
	check(town.player.enabled, "leaving frees the player")
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Gear.PATH))
	else:
		FileAccess.open(Gear.PATH, FileAccess.WRITE).store_buffer(backup)
	print("failures ", failures)
	quit(failures)
