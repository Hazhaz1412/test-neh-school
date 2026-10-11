extends SceneTree

var school: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS / " if ok else "FAIL / ", description)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func place(feet: Vector3, target: Vector3) -> void:
	school.player.position = feet
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(target)
	school._update_light_budget()

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.player.set_physics_process(false)
	await frames(25)
	var s: Node3D = school.scares
	s.set_process(false)
	school.encounters.set_physics_process(false)
	check(s.apparition.find_children("*", "CollisionObject3D", true, false).is_empty(), "Laughing student has no physical hitbox, damage controller or blocking body")
	check(school.realm_scenery.decor.find_children("*", "Label3D", true, false).is_empty(), "Spirit manifestations contain no normal-font threat labels")
	check(school.realm_scenery.decor.has_node("CrumblingPlaster") and school.realm_scenery.decor.has_node("OverturnedChairs0"), "Licensed rubble and instanced abandoned-school props are in the actual map")
	check(not s.try_start(s.Kind.LAUGHING_STUDENT), "No supernatural scares in the normal world")
	school.set_spirit_world(true)
	for enemy in school.enemies:
		enemy.set_dormant(true)
		enemy.set_physics_process(false)
	place(Vector3(-23.5, 0.05, 49), Vector3(-23.5, 1.6, 30))
	await frames(3)
	var health: float = school.player.health
	var energy: float = school.player.battery
	var fear: float = school.player.fear
	var enemy_count: int = school.enemies.size()
	check(s.try_start(s.Kind.LAUGHING_STUDENT), "A clear corridor stages a laughing apparition in real line of sight")
	check(s.apparition.visible and s.sound.playing and not s.try_start(s.Kind.THROWN_CHAIR), "Student giggles spatially and events never overlap")
	var initial: Vector3 = s.apparition.global_position
	s._process(0.9)
	check(s.apparition.global_position.distance_to(initial) > 0.2 and s.apparition.model.animation.current_animation == "sprint", "The apparition animates and darts away after laughing")
	s._process(2)
	check(not s.apparition.visible and s.active_kind == -1, "The apparition vanishes and releases its cached scene")
	check(school.player.health == health and school.player.battery == energy and school.player.fear == fear and school.enemies.size() == enemy_count, "A full apparition encounter causes no damage, resource penalty, panic or extra combat enemy")
	check(not s.try_start(s.Kind.LAUGHING_STUDENT) and s.wait >= s.interval_min, "Global recovery and local cooldown prevent repeated jump scares in one corner")
	s.reset()
	check(s.try_start(s.Kind.THROWN_CHAIR), "A moving chair uses a collision-tested route on the current floor")
	var floor_y: float = s.from.y
	s._process(0.45)
	check(s.chair.visible and s.chair.global_position.distance_to(s.to) < 0.1 and absf(s.to.y - floor_y) < 0.18, "Chair traverses quickly and lands without moving any map collision")
	s.cancel()
	check(not s.chair.visible, "Chair pool hides cleanly after interruption")
	s.reset()
	var original_lights := {}
	for light in school.local_lights:
		original_lights[light] = light.light_energy
	check(s.try_start(s.Kind.BLACKOUT), "Blackout selects visible local lamps rather than darkening the whole map")
	var affected: Array = s.selected_lights.duplicate()
	s._process(0.5)
	var dimmed := affected.size() > 0 and affected.size() <= 3
	for light in affected:
		dimmed = dimmed and light.light_energy < original_lights[light] * 0.1
	check(dimmed, "Only up to three nearby lamps go dark; player torch and moon are unchanged")
	school.paused_by_user = true
	var time_before: float = s.clock
	s._process(10)
	s.set_process(true)
	await frames(2)
	s.set_process(false)
	check(s.clock == time_before and (not s.sound.playing or s.sound.stream_paused), "Pause freezes scare timing and any active spatial sound")
	school.paused_by_user = false
	school.camera_flash.trigger()
	var restored := true
	for light in affected:
		restored = restored and is_equal_approx(light.light_energy, original_lights[light])
	check(restored and s.active_kind == -1, "Camera dispels the event and restores each local lamp before its flash")
	school.camera_flash.reset()
	s.reset()
	check(s.try_start(s.Kind.LAMP_POP), "A lamp can short out with the dedicated crackle and pop")
	s._process(0.3)
	check(s.sparks.visible and s.sparks.emitting and s.hit_played, "Lamp failure emits a bounded burst of sparks without a new light")
	school.set_spirit_world(false)
	check(s.active_kind == -1 and not s.sparks.visible and not s.sound.playing, "Changing worlds cancels light, particle and sound state")
	school.set_spirit_world(true)
	for enemy in school.enemies:
		enemy.set_dormant(true)
		enemy.set_physics_process(false)
	place(Vector3(15, 11.75, 7), Vector3(15, 13.4, 5))
	await frames(3)
	check(not s.try_start(s.Kind.LAUGHING_STUDENT), "An's rooftop sanctuary never receives jump scares")
	place(Vector3(-23.5, 0.05, 49), Vector3(-23.5, 1.6, 30))
	await frames(3)
	s.reset()
	school.soul_quest.journal.show()
	check(not s.try_start(s.Kind.LAUGHING_STUDENT), "Evidence reading and consolation block all random scares")
	school.soul_quest.journal.hide()
	school.progression.panel.show()
	check(not s.try_start(s.Kind.LAMP_POP), "Technical puzzle UI blocks scare events")
	school.progression.panel.hide()
	school.player.combat.mode = school.player.combat.Mode.QTE
	check(not s.try_start(s.Kind.LAUGHING_STUDENT), "An active counter QTE cannot be interrupted by the trickster")
	school.player.combat.mode = school.player.combat.Mode.IDLE
	school.map_panel.show()
	check(not s.try_start(s.Kind.THROWN_CHAIR), "Reading the map blocks random scares")
	school.map_panel.hide()
	# A closed classroom wall must not become an apparition spawn surface.
	place(Vector3(-23.5, 0.05, 35), Vector3(-35, 1.6, 35))
	await frames(3)
	check(s._find_stage().is_empty(), "Line-of-sight and capsule clearance reject a spawn behind a closed classroom wall")
	place(Vector3(-23.5, 0.05, 49), Vector3(-23.5, 1.6, 30))
	await frames(3)
	s.reset()
	s.wait = 0
	s._process(60)
	check(s.active_kind == -1, "Standing still does not generate a stream of jump scares")
	s.travelled = 6
	s._process(0.1)
	check(s.active_kind >= 0, "Random scheduler starts a viable event once recovery and exploration are satisfied")
	s.cancel()
	check(school.player.health == health, "No scare type reduces player health")
	print("Scare validation: ", checks, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
