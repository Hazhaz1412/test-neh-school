extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
var school: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	await frames(20)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	await frames(8)
	var p: CharacterBody3D = school.player
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	school.camera_flash.set_process(false)
	var layers := {}
	var kinds := {}
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		layers[ghost] = ghost.collision_layer
		kinds[ghost.archetype] = true
	check(school.enemies.size() == 13 and kinds.size() == 4, "Real midnight spawns all thirteen enemies and four archetypes")
	check(p.inventory.size() == 6 and p.inventory.count("") == 1 and p.chalk == 3, "Six non-stacking slots begin with flashlight, camera and three chalks")
	check(p.add_item("battery") and not p.add_item("medicine") and not p.add_item("camera"), "Sixth item fits; seventh and duplicate camera cannot enter bag")
	p.battery = 100
	p.select_item("battery")
	check(not p.use_selected_item() and p.inventory.has("battery"), "Full energy does not waste a stored battery")
	p.battery = 70
	check(p.use_selected_item() and p.battery == 100 and not p.inventory.has("battery"), "Using a battery charges the shared pool by up to fifty and frees its slot")
	p.add_item("medicine")
	p.select_item("medicine")
	p.health = 100
	check(not p.use_selected_item() and p.inventory.has("medicine"), "Full health does not waste a stored first-aid item")
	p.health = 50
	check(p.use_selected_item() and p.health == 80, "First aid heals thirty HP only when selected and used")
	p.select_item("torch")
	p.flashlight.show()
	p.tick_survival(10, false)
	check(is_equal_approx(p.battery, 93.25), "Flashlight drains six point seven five percent per ten seconds, doubling its runtime")
	p.select_item("camera")
	check(not p.flashlight.visible, "Switching to camera stops flashlight consumption")
	var environment: Environment = school.get_node("Atmosphere/MoonlitEnvironment").environment
	var ambient := environment.ambient_light_energy
	var fog := environment.fog_density
	var moon_energy: float = school.get_node("Atmosphere/Moonlight").light_energy
	p.battery = 100
	for ghost in school.enemies:
		ghost.state = Ghost.State.ATTACK
		ghost.memory = 8
		ghost.suspected_spot = school.get_node("HidingSpots/HallA_0")
		if ghost.archetype == "listener":
			ghost.listening_memory = 8
		if ghost.archetype == "whisperer":
			ghost.whisper_charge = 3
	check(p.take_photo() and p.battery == 80, "A camera shot costs exactly twenty percentage points")
	check(environment.ambient_light_energy > ambient * 3 and environment.fog_density < fog and school.get_node("Atmosphere/Moonlight").light_energy > moon_energy, "Flash really brightens global 3D illumination and enclosed rooms")
	var all_banished := true
	for ghost in school.enemies:
		all_banished = all_banished and not ghost.visible and not ghost.active and ghost.collision_layer == 0 and ghost.velocity == Vector3.ZERO and ghost.banished_remaining == 6 and not ghost.has_line_of_sight() and not ghost.can_strike_player() and ghost.suspected_spot == null and ghost.memory == 0
		ghost.hear_noise(p.position, 999, "steps")
		ghost.alert(p.position)
		all_banished = all_banished and ghost.memory == 0 and not ghost.snarl.playing and not ghost.footsteps.playing
		if ghost.archetype == "whisperer":
			all_banished = all_banished and ghost.whisper_charge == 0 and not ghost.whisper_audio.playing
	check(all_banished, "Every ghost disappears on all floors: no collision, attack, hearing, squad memory or chorus")
	check(not p.take_photo() and p.battery == 80, "Holding or spamming shutter cannot bypass camera cooldown")
	school.paused_by_user = true
	school.camera_flash._process(2)
	for ghost in school.enemies:
		ghost._physics_process(2)
	check(school.enemies[0].banished_remaining == 6 and school.camera_flash.cooldown == 1.5 and school.camera_flash.intensity == 1 and not p.take_photo() and p.battery == 80, "Esc freezes banishment, flash and cooldown and forbids firing")
	school.paused_by_user = false
	school.camera_flash._process(0.7)
	check(is_equal_approx(environment.ambient_light_energy, ambient) and is_equal_approx(environment.fog_density, fog) and is_equal_approx(school.get_node("Atmosphere/Moonlight").light_energy, moon_energy), "Pulse restores exact spirit lighting and fog after half a second")
	for ghost in school.enemies:
		ghost._physics_process(5.9)
	check(not school.enemies[0].active, "Ghosts stay absent throughout the six-second escape window")
	for ghost in school.enemies:
		ghost._physics_process(0.2)
	var restored := true
	for ghost in school.enemies:
		restored = restored and ghost.active and ghost.visible and ghost.collision_layer == layers[ghost] and ghost.cooldown == 1
	check(restored and school.enemies.size() == 13, "Same thirteen ghosts return with original collision layers, including heavy blocker, and attack grace")
	var blocker: CharacterBody3D
	for ghost in school.enemies:
		if ghost.archetype == "blocker":
			blocker = ghost
	var blocker_position := blocker.position
	blocker.position = p.position
	blocker.banish(1)
	blocker._physics_process(1.1)
	check(not blocker.active and blocker.collision_layer == 0, "Heavy ghost cannot rematerialize its collider inside a player occupying the return spot")
	blocker.position = blocker_position
	blocker._physics_process(0.2)
	check(blocker.active and blocker.collision_layer == 6, "Heavy ghost restores its real collider once the return spot is clear")
	# Four more photos exhaust a full charge; no free shot at nineteen percent.
	for i in range(4):
		school.camera_flash._process(2)
		check(p.take_photo() and p.battery == 60 - i * 20, "Finite camera shot %d consumes twenty percent" % (i + 2))
	school.camera_flash._process(2)
	check(not p.take_photo() and p.battery == 0, "Exactly five photos exhaust a full shared battery")
	p.battery = 19.99
	check(not p.take_photo() and p.battery == 19.99, "Below twenty percent cannot fire or grant a flash")
	p.battery = 100
	school.map_panel.show()
	check(not p.take_photo() and p.battery == 100, "Opening the map prevents using held items without pausing survival")
	school.map_panel.hide()
	p.enabled = false
	check(not p.take_photo(), "Opening or disabled player cannot fire")
	p.enabled = true
	p.health = 0
	check(not p.take_photo(), "Dead player cannot fire")
	p.health = 100
	var cover: Node3D = school.get_node("HidingSpots/HallA_0")
	p.begin_hide(cover)
	check(not p.take_photo() and not p.drop_selected_item() and p.battery == 100, "Hiding forbids photographing and dropping through cabinet walls")
	p.hidden_spot = null
	p.reset_survival()
	p.position = Vector3(0, 0.05, 64)
	p.select_item("camera")
	await frames(3)
	# GPU rendering can run several physics ticks before the next visual frame.
	await process_frame
	await process_frame
	check(p.held_visual.models.camera.visible and not p.held_visual.models.torch.visible, "Equipping camera actually changes the visible held 3D model")
	p.add_item("battery")
	var finite_item: Node3D = school.survival.items[0]
	p.position = finite_item.position + Vector3(0, -0.1, 1)
	p.camera.look_at(finite_item.global_position)
	await frames(3)
	check(p.get_interaction_target() == finite_item and not finite_item.interact(p) and not finite_item.collected and finite_item.visible, "A full bag leaves a real reachable supply on the floor")
	p.battery = 60
	p.select_item("battery")
	p.use_selected_item()
	check(finite_item.interact(p) and finite_item.collected and p.battery == 100 and p.inventory.has("battery"), "Real pickup stores a finite battery; picking it up does not recharge automatically")
	check(not finite_item.interact(p), "A stored finite pickup cannot duplicate itself")
	p.position = Vector3(0, 0.05, 64)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	await frames(3)
	check(p.drop_selected_item() and not p.inventory.has("battery"), "Dropping a carried item frees exactly one slot")
	var dropped: Node3D
	for node in school.survival.get_children():
		if node.get("dropped") == true:
			dropped = node
	check(dropped != null and dropped.kind == "battery", "Drop creates one real physical-ray pickup on the school floor")
	if dropped != null:
		p.camera.look_at(dropped.global_position)
		await frames(3)
		check(p.get_interaction_target() == dropped and dropped.interact(p) and p.inventory.count("battery") == 1, "Dropped item can be recovered by real interaction without duplication")
		await frames(2)
		check(not is_instance_valid(dropped), "Recovered dynamic drop is removed rather than becoming a refill source")
	# Numeric and wheel inputs run through the actual input dispatcher on display.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var event := InputEventKey.new()
		event.keycode = KEY_2
		event.pressed = true
		p._unhandled_input(event)
		check(p.selected_item() == "camera", "Number two equips the camera through the real input handler")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		p._unhandled_input(wheel)
		check(p.selected_item() == "chalk", "Mouse wheel cycles carried items through the real input handler")
		p.select_item("camera")
		p.battery = 100
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		p._unhandled_input(click)
		check(p.battery == 80, "Left click fires the equipped camera through the real input handler")
		p._unhandled_input(click)
		check(p.battery == 80, "Repeated click cannot spend energy during cooldown")
	check(not school.has_master_key and school.master_key.visible and school.soul_quest.found.is_empty(), "Survival tools cannot bypass the master key or soul quest")
	if school.camera_flash.intensity == 0:
		p.select_item("camera")
		p.battery = 100
		p.take_photo()
	school.set_spirit_world(false, true)
	check(school.camera_flash.intensity == 0 and is_equal_approx(environment.ambient_light_energy, ambient), "Changing realm clears active flash without leaking illumination")
	p.reset_survival()
	check(p.inventory == ["torch", "camera", "chalk", "chalk", "chalk", ""] and p.battery == 100 and school.camera_flash.cooldown == 0, "New run restores six slots and clears weapon state")
	p.add_item("battery")
	p.select_item("battery")
	p.drop_selected_item()
	school.survival.finished = true
	school.survival.start_run(false)
	await frames(3)
	var leftovers := 0
	for node in school.survival.get_children():
		if node.get("dropped") == true:
			leftovers += 1
	check(leftovers == 0 and not school.survival.items[0].collected and p.inventory.count("battery") == 0, "Fresh night removes old dynamic drops and restores finite map supplies exactly once")
	print("Camera/inventory validation: ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(4)
	Ghost.reshaped_meshes.clear()
	quit(0 if failures == 0 else 1)
