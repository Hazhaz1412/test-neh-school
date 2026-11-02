extends SceneTree
# The demon's grab, the salt gun and the back-alley shop, on the real scenes.
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
	var demon: Node = school.envy.demon
	var player: CharacterBody3D = school.player
	demon.fall_back(demon.global_position, 0.0)
	demon.state = demon.State.ROAM
	demon.stolen.clear()
	demon.global_position = player.global_position + Vector3(0, 0, 1.4)
	player.inventory.assign(bag)
	player.invulnerable_time = 0.0
	player.health = 100.0
	player.enabled = true
	demon._seize()
	return demon

func run() -> void:
	var backup := FileAccess.get_file_as_bytes(Gear.PATH)
	var state := Gear.fresh()
	check(Gear.buy(state, "salt_gun").is_empty() and state.money == Gear.START_MONEY - 180, "buying costs money")
	check(not Gear.buy(state, "salt_gun").is_empty(), "too poor for a second gun")
	state.money = 999
	for i in range(3): Gear.buy(state, "chalk")
	check(Gear.buy(state, "chalk") == "Túi đầy rồi.", "the bag has a limit")
	check(Gear.loadout(state)[0] == "crank" and Gear.loadout(state).size() == 6, "a light is always first, the hand torch by default")
	state.money = 300
	check(Gear.buy(state, "torch").is_empty() and state.money == 0 and state.bag.size() == Gear.BAG_ROOM, "the torch costs 300$ and no bag slot")
	check(Gear.loadout(state)[0] == "torch" and not Gear.buy(state, "torch").is_empty(), "it replaces the hand torch and sells once")
	state.torch = false
	state.money = 999
	Gear.finish_night(state, ["torch", "", "chalk", "", "", ""], ["camera"])
	check(not state.camera and state.pawned.has("camera"), "what it took shows up at the shop")
	var before: int = state.money
	check(Gear.redeem(state, "camera").is_empty() and state.camera and state.money == before - 50, "the camera is redeemed at half value")
	Gear.write(Gear.fresh().merged({"bag": ["salt_gun", "medal"]}, true))
	set_meta("night_one", true)
	var school: Node3D = load("res://scenes/school_runtime.tscn").instantiate()
	root.add_child(school)
	current_scene = school
	for i in range(40): await physics_frame
	check(school.player.inventory.has("salt_gun") and school.player.inventory.has("medal"), "the night starts with what was bought")
	await wait_for(func(): return school.envy.demon != null, 3.0)
	await physics_frame
	var player: CharacterBody3D = school.player
	check(player.selected_item() == "crank", "without the shop torch the night starts with the hand torch")
	check(absf(player.TORCH_ENERGY / 1.15 - 1.2) < 0.001 and absf(player.CRANK_ENERGY / 1.15 - 0.9) < 0.001, "brightness is 120% and 90% of the old torch")
	check(absf(100.0 / player.FLASHLIGHT_DRAIN - 296.3) < 0.1 and 100.0 / player.CRANK_DRAIN == 10.0, "the torch lasts twice as long, the hand torch 10 s")
	var lows := 100
	var highs := 0
	var heard_at := 0
	school.envy.set_physics_process(false)
	school.envy.demon.fall_back(school.envy.demon.global_position, 0.0)
	for i in range(60):
		player.crank_charge = 0.0
		player.invulnerable_time = 0.0
		player.pump_crank()
		lows = mini(lows, int(player.crank_charge))
		highs = maxi(highs, int(player.crank_charge))
	check(lows == 9 and highs == 14, "a squeeze charges 9 to 14%%: %d-%d" % [lows, highs])
	var demon_probe: Node = school.envy.demon
	demon_probe.state = demon_probe.State.ROAM
	demon_probe.has_area = false
	demon_probe.global_position = player.global_position + Vector3(6, 0, 0)
	player.pump_crank()
	check(demon_probe.area.distance_to(player.global_position) < 1.0, "the demon hears a squeeze close by")
	demon_probe.area = Vector3(999, 0, 0)
	demon_probe.state = demon_probe.State.ROAM
	demon_probe.global_position = player.global_position + Vector3(30, 0, 0)
	player.pump_crank()
	check(demon_probe.area.x == 999.0, "but not from across the school")
	player.select_item("crank")
	player.crank_charge = 100.0
	player.crank_on = false
	player.flashlight.hide()
	player.use_selected_item()
	check(player.flashlight.visible and player.flashlight.light_energy >= 1.0, "it switches on")
	for i in range(125): player.tick_survival(1.0 / 12.0, false)
	check(not player.flashlight.visible and player.crank_charge == 0.0, "it dies after 10 seconds")
	player.pump_crank()
	check(player.flashlight.visible and player.crank_charge >= 9.0, "a squeeze brings it back")
	player.use_selected_item()
	school.envy.set_physics_process(true)
	school.envy.set_physics_process(false)
	var demon: Node = grab(school, ["torch", "camera", "medal", "", "", ""])
	check(player.seized and demon.state == demon.State.GRAB, "it lifts the player")
	await wait_for(func(): return not player.seized, 3.0)
	check(demon.stolen == ["medal"] and player.health == 100.0, "it takes the dearest thing and lets go")
	check(demon.state == demon.State.ADMIRE, "then it stops to admire the prize")
	var stood := 0.0
	while demon.state == demon.State.ADMIRE and stood < 6.0:
		await physics_frame
		stood += 1.0 / 60.0
		if player.seized: break
	check(not player.seized and absf(stood - demon.ADMIRE_SECONDS) < 0.25, "for four seconds it ignores the player standing there: %.1f" % stood)
	check(demon.state != demon.State.REST and demon.state != demon.State.GRAB, "then it goes back to normal: " + demon.state_name())
	demon.global_position = player.global_position + Vector3(0, 0, -6)
	demon.rotation.y = 0.0
	demon.state = demon.State.ROAM
	demon.fall_back(demon.global_position, 0.0)
	demon.state = demon.State.CHASE
	demon.unseen = 0.0
	demon.last_seen = player.global_position
	school.envy.set_physics_process(true)
	school.envy.menace = 99.0
	var backing := 0.0
	var caught_backing := false
	var fled := false
	while backing < 7.0 and not caught_backing:
		await physics_frame
		backing += 1.0 / 60.0
		var away: Vector3 = (player.global_position - demon.global_position)
		away.y = 0.0
		player.global_position += away.normalized() * 3.0 / 60.0
		caught_backing = player.seized
		fled = fled or demon.is_resting()
	check(caught_backing and not fled, "backing away at walking speed gets the player caught, it never gives up: %.1f s" % backing)
	school.envy.set_physics_process(false)
	await wait_for(func(): return not player.seized, 4.0)
	player.health = 100.0
	player.enabled = true
	demon.fall_back(demon.global_position, 0.0)
	demon.model.stop_admiring()
	check(player.inventory.has("torch"), "the torch is never taken")
	demon = grab(school, ["torch", "salt_gun", "", "", "", ""])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(100, 100)
	for i in range(5): await physics_frame
	var hold: Vector3 = player.global_position
	root.push_input(click)
	await physics_frame
	check(demon.state == demon.State.STAGGER and not player.seized, "a real click fires the gun and it drops the player")
	check(not player.inventory.has("salt_gun"), "the shot is spent")
	check(player.global_position.distance_to(hold) > 0.5, "the player is thrown")
	check(player.combat.adrenaline_remaining > 7.5 and player.combat.sprint_multiplier() == 0.5, "adrenaline halves stamina drain for 8 s")
	check(demon.has_area == false and demon.last_seen != null and school.envy.hint_clock > 15.0, "A goes silent and the trail is lost")
	await wait_for(func(): return demon.state == demon.State.REST, 5.0)
	check(demon.state == demon.State.REST, "it limps away instead of chasing")
	demon.fall_back(demon.global_position, 0.0)
	demon = grab(school, ["torch", "", "", "", "", ""])
	await wait_for(func(): return player.health <= 0.0, 3.0)
	check(player.health <= 0.0, "with nothing to give, it eats the player")
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
	check(not town.plan.PLACES.filter(func(p): return p.id == "curio")[0].is_empty(), "the shop is on the plan")
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
