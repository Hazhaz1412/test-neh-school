extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
const Entity = preload("res://scripts/school_entity.gd")
var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS / ", description)
	else:
		push_error(description)
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	school._unhandled_input(event)

func interact(target: Node3D) -> bool:
	if DisplayServer.get_name() == "headless":
		return target.interact(school.player)
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	school.player._unhandled_input(event)
	return true

func aim(pos: Vector3, target: Vector3) -> void:
	school.player.global_position = pos
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(target)
	await frames(3)

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	school.set_process_unhandled_input(false)
	current_scene = school
	await frames(25)
	key(KEY_N)
	school.survival.opening.finish()
	school.survival.begin_midnight()
	await frames(8)
	var player: CharacterBody3D = school.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false) # Ignore desktop mouse motion while scripting camera poses.
	school.survival.set_physics_process(false)
	check(school.survival.active and school.spirit_enabled and school.enemies.size() == 13, "N opening reaches midnight with thirteen entities")
	var listeners: Array[CharacterBody3D] = []
	var whisperers: Array[CharacterBody3D] = []
	var blocker: CharacterBody3D
	for enemy in school.enemies:
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.position = Vector3(54, 0.05, 65)
		match enemy.archetype:
			"listener": listeners.append(enemy)
			"whisperer": whisperers.append(enemy)
			"blocker": blocker = enemy
	check(listeners.size() == 2 and whisperers.size() == 2 and blocker != null, "New entities comprise two blind listeners, two rumour choruses and one blocker")
	check(listeners[0].model.find_child("Blindfold", true, false) != null and whisperers[0].model.find_children("RumourMask*", "", true, false).size() == 2 and blocker.model.find_child("ConfiscatedSchoolbag", true, false) != null, "Each archetype has distinct school-related visual details")
	player.health = 51
	key(KEY_B)
	check(school.spirit_enabled and player.health == 51, "B cannot heal or leave an active survival run")
	key(KEY_N)
	check(player.health == 51, "Repeated N cannot reset resources during a live run")
	key(KEY_M)
	check(school.map_panel.visible and school.simulation_active(), "The map leaves survival threats active")
	key(KEY_M)
	key(KEY_ESCAPE)
	check(not school.simulation_active(), "Esc still pauses a single-player survival run")
	key(KEY_ESCAPE)
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var listener := listeners[0]
	listener.position = Vector3(19, 0.05, 7.5)
	await aim(Vector3(11, 0.05, 7.5), Vector3(19, 1.4, 7.5))
	check(not listener.has_line_of_sight(), "Blind listener never detects a silent player by vision")
	school.emit_noise(player.position, player.movement_noise(false, true), "steps")
	check(listener.memory == 0, "Ctrl movement is quiet enough to pass at eight metres")
	school.emit_noise(player.position, player.movement_noise(true, false), "steps")
	check(listener.state == Ghost.State.SEARCH and listener.last_known.distance_to(player.position) < 0.01, "Sprint noise creates a remembered investigation location")
	listener.memory = 0
	listener.state = Ghost.State.PATROL
	school.emit_noise(Vector3(19, 3.95, 7.5), 30, "steps")
	check(listener.memory == 0, "Noise cannot identify a player on another floor")
	# Wall attenuation prevents all-campus sound tracking.
	listener.position = Vector3(32, 0.05, 31.2)
	school.emit_noise(Vector3(32, 0.05, 36), 6, "steps")
	check(listener.memory == 0, "A classroom wall attenuates quiet steps")
	var cabinet: Node3D = school.get_node("HidingSpots/HallA_0")
	listener.position = Vector3(16, 0.05, 7.5)
	await aim(cabinet.approach_position(), cabinet.to_global(Vector3(0, 1.1, 0.72)))
	interact(cabinet)
	check(player.is_hidden(), "A blind-listener encounter still permits a physical cabinet entry")
	player.fear = 85
	player.breath = 100
	player.breathing_clock = 0
	listener.suspected_spot = null
	player.tick_survival(0.2, true)
	check(player.holding_breath and listener.suspected_spot == null, "Holding Space suppresses a panicked hidden breath")
	player.tick_survival(0.2, false)
	check(listener.suspected_spot == cabinet, "Nearby listener hears a panicked breath and remembers the actual cabinet")
	player.fear = 0
	listener.set_physics_process(true)
	await frames(180)
	check(not player.is_hidden(), "A listener physically approaches and checks the heard hiding place")
	listener.set_physics_process(false)
	player.breath = 1
	player.breath_exhausted = false
	await aim(cabinet.approach_position(), cabinet.to_global(Vector3(0, 1.1, 0.72)))
	interact(cabinet)
	player.tick_survival(0.1, true)
	check(player.breath_exhausted and not player.holding_breath, "Breath capacity is finite and exhaustion causes a cough")
	listener.position = Vector3(54, 0.05, 65)
	player.end_hide()
	# Finite, one-shot consumables, real interaction rays and walls.
	var battery: Node3D = school.survival.items[0]
	player.battery = 0
	player.flashlight.show()
	player.tick_survival(0.1, false)
	check(not player.flashlight.visible, "An exhausted battery actually extinguishes the flashlight")
	check(not battery.interact(player), "A battery cannot be collected remotely")
	await aim(battery.position + Vector3(0, -0.1, 1), battery.global_position)
	interact(battery)
	check(player.battery == 0 and player.inventory.has("battery"), "A battery pickup is stored rather than automatically spent")
	player.select_item("battery")
	player.use_selected_item()
	check(player.battery == 50 and battery.collected, "A nearby E pickup replenishes one battery exactly once")
	check(not battery.interact(player) and player.battery == 50, "A used battery cannot be farmed")
	var medicine: Node3D = school.survival.items[5]
	player.health = 40
	await aim(medicine.position + Vector3(0.6, -0.1, 0.8), medicine.global_position)
	interact(medicine)
	player.select_item("medicine")
	player.use_selected_item()
	check(player.health == 70 and medicine.collected, "First-aid restores thirty HP from a real finite pickup")
	# Rumour entity channels only through LOS and is interrupted by focused light.
	var whisperer := whisperers[0]
	whisperer.position = Vector3(14, 0.05, 7.5)
	await aim(Vector3(18, 0.05, 7.5), Vector3(14, 1.7, 7.5))
	player.flashlight.hide()
	player.fear = 0
	whisperer.look_at(player.position)
	whisperer.vision_clock = 0
	whisperer.set_physics_process(true)
	await frames(130)
	check(player.fear > 15 and whisperer.whisper_audio.playing, "Visible Rumour Chorus produces spatial sound and rising panic after a warning")
	player.flashlight.show()
	check(whisperer.lit_by_player(), "A focused flashlight has a clear physical ray to the chorus")
	await frames(48)
	check(whisperer.stun_time > 0 and not whisperer.whisper_audio.playing, "Sustained light interrupts the chorus and grants an escape window")
	whisperer.set_physics_process(false)
	whisperer.stun_time = 0
	whisperer.position = Vector3(32, 0.05, 32.8)
	await aim(Vector3(32, 0.05, 31.2), Vector3(32, 1.7, 32.8))
	check(not whisperer.lit_by_player() and not whisperer.has_line_of_sight(), "Neither a light stun nor a rumour chant passes through a classroom wall")
	whisperer.position = Vector3(54, 0.05, 65)
	# Heavy enemy physically blocks the route; its slow windup remains dodgeable.
	blocker.collision_layer = 6
	blocker.position = Vector3(18, 0.05, 7.5)
	await aim(Vector3(16, 0.05, 7.5), Vector3(18, 1.7, 7.5))
	for i in range(90):
		player.velocity = Vector3(3, 0, 0)
		player.move_and_slide()
		await physics_frame
	check(player.position.x < 17.4, "Player CharacterBody cannot walk through the heavy blocker")
	player.health = 100
	player.invulnerable_time = 0
	blocker.look_at(player.position)
	blocker.vision_clock = 0
	blocker.set_physics_process(true)
	await frames(30)
	check(player.health == 100, "Heavy club has a readable warning before damage")
	await frames(65)
	check(player.health == 76, "The heavy enemy delivers one real twenty-four HP melee hit")
	blocker.set_physics_process(false)
	blocker.collision_layer = 0
	blocker.position = Vector3(54, 0.05, 65)
	# Decoy collides with the real school floor and redirects a listener.
	listener.position = Vector3(4, 0.05, 65)
	listener.suspected_spot = cabinet
	player.chalk = 3
	await aim(Vector3(0, 0.05, 64), Vector3(0, 0, 71))
	check(player.throw_chalk() and player.chalk == 2, "Throwing a chalk decoy consumes one finite item")
	await frames(90)
	check(listener.suspected_spot == null and listener.last_known.z > 64 and listener.memory > 0, "Actual chalk-floor impact redirects the listener away from a suspected cover")
	# The key opens the school rooms; returning to the gate cannot skip the night.
	player.health = 100
	player.invulnerable_time = 0
	await aim(Vector3(-45, 0.05, -54.5), school.master_key.global_position)
	check(player.get_interaction_target() == school.master_key, "Survival supplies do not occlude the original key interaction")
	interact(school.master_key)
	check(school.has_master_key and school.survival.hunt_remaining > 0 and school.survival.bell.playing, "Taking the key opens exploration and rings the hunt bell")
	await aim(Vector3(0, 0.05, 76), school.survival.gate.global_position)
	check(player.get_interaction_target() == school.survival.gate, "The original physical campus gate has a reachable sealed-gate interaction")
	interact(school.survival.gate)
	check(not school.survival.won and not school.survival.finished, "Returning with the key and pressing E cannot bypass time or soul rescue")
	school.survival.advance_clock(720)
	check(school.survival.finished and not school.survival.won, "Dawn without a rescued soul does not complete night one")
	key(KEY_N)
	await frames(4)
	check(school.survival.active and not school.survival.won and not school.has_master_key and player.health == 100 and player.battery == 100 and player.chalk == 3, "A fresh night resets victory, inventory and finite survival resources")
	key(KEY_R)
	await frames(30)
	school = current_scene
	check(school.survival.active and school.survival.opening.playing and not school.has_master_key, "R restarts the story opening rather than silently returning to preview")
	print("Survival validation failures: ", failures)
	school.queue_free()
	await frames(3)
	Ghost.reshaped_meshes.clear()
	quit(0 if failures == 0 else 1)
