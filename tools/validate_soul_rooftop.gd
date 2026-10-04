extends SceneTree

const Limbs = preload("res://scripts/combat_limbs.gd")
const Ghost = preload("res://scripts/bully_ghost.gd")
const Humanoid = preload("res://scripts/humanoid_model.gd")
const Soul = preload("res://scripts/student_soul.gd")
var school: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS / " if ok else "FAIL / ", description)
	if not ok:
		failures += 1

func walk_to(target: Vector2, speed := 3.0) -> bool:
	var p: CharacterBody3D = school.player
	for i in range(900):
		await physics_frame
		var distance := target - Vector2(p.position.x, p.position.z)
		if distance.length() < 0.13:
			p.velocity = Vector3.ZERO
			return true
		var direction := distance.normalized()
		p.velocity = Vector3(direction.x * speed, 0 if p.is_on_floor() else p.velocity.y - 0.3, direction.y * speed)
		p.move_and_slide()
	print("Walk blocked at ", p.position, " towards ", target)
	for i in range(p.get_slide_collision_count()):
		print("Blocking collider: ", p.get_slide_collision(i).get_collider().name)
		var collision: KinematicCollision3D = p.get_slide_collision(i)
		var shape: CollisionShape3D = collision.get_collider_shape()
		print("Blocking shape: ", shape.global_transform, " / ", shape.shape, " / ", collision.get_normal())
	return false

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	school.player.set_process_unhandled_input(false)
	school.player.set_physics_process(false)
	await frames(12)
	school.set_spirit_world(true)
	await frames(3)
	check(school.soul_quest.soul.visible, "B spirit-world preview also shows An before starting a survival run")
	school.set_spirit_world(false)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	# Fixture: progression itself is covered by validate_progression.gd.
	school.progression.bypass_for_test()
	school.survival.set_physics_process(false)
	await frames(10)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
	var p: CharacterBody3D = school.player
	var quest: Node3D = school.soul_quest
	check(not school.test_cheats.enabled and not p.test_invincible(), "Sanctuary is tested without cheat or invulnerability")
	check(school.is_soul_sanctuary(Vector3(-12, 11.75, 5)) and school.is_soul_sanctuary(Vector3(-28, 11.75, 40)) and school.is_soul_sanctuary(Vector3(28, 11.75, 40)), "All three A rooftop wings are safe")
	check(not school.is_soul_sanctuary(Vector3(-12, 7.85, 5)) and not school.is_soul_sanctuary(Vector3(0, 11.75, 25)) and not school.is_soul_sanctuary(Vector3(0, 11.75, -40)), "Floor three, courtyard void and B remain outside the sanctuary")
	var route := NavigationServer3D.map_get_path(school.get_world_3d().navigation_map, Vector3(0, 7.8, -40.5), quest.SOUL_APPROACH, true)
	check(not route.is_empty() and route[-1].distance_to(quest.SOUL_APPROACH) < 0.6, "Existing stairs and rooftop navigation still connect B floor three to An")
	p.position = Vector3(-4.8, 7.85, 7.2)
	check(await walk_to(Vector2(-4.8, -3)), "Real player capsule climbs the final stair flight")
	check(p.position.y > 11.5 and await walk_to(Vector2(0, -3)) and await walk_to(Vector2(12, -3)), "Real player exits the stair enclosure at rooftop height")
	check(await walk_to(Vector2(12, 7)) and await walk_to(Vector2(quest.SOUL_APPROACH.x, quest.SOUL_APPROACH.z)), "Real player walks from the east stair exit to An without teleporting through walls")
	check(p.position.y > 11.5 and p.can_fit(p.position) and quest.soul.visible and quest.soul.global_position == quest.SOUL_POSITION, "An and the standing player fit on the physical rooftop")
	# The player must also be able to explore the other half of the same roof.
	check(await walk_to(Vector2(12, -6), 5.2) and await walk_to(Vector2(-12, -6), 5.2), "Actual capsule crosses the flattened connector roof seam from east to west")
	check(await walk_to(Vector2(-25, -6), 5.2) and await walk_to(Vector2(-25, 45), 5.2), "Player can explore the west rooftop wing without being trapped on the east half")
	check(await walk_to(Vector2(-25, -6), 5.2) and await walk_to(Vector2(-12, -6), 5.2) and await walk_to(Vector2(12, -6), 5.2) and await walk_to(Vector2(quest.SOUL_APPROACH.x, quest.SOUL_APPROACH.z), 5.2), "Player crosses the seam in reverse and returns to An")
	check(quest.soul.get_node("SoulHalo").visible and quest.soul.get_node("SoulHalo").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "An has a visible spectral marker without an extra shadow-casting light")
	p.camera.look_at(quest.soul.global_position + Vector3.UP)
	await frames(3)
	# Physical pickups are validated separately; unlock dialogue to test this location.
	for i in range(4):
		quest.found[i] = true
	var all_clear := true
	var all_safe := true
	var all_relocated := true
	for ghost in school.enemies:
		ghost.position = quest.SOUL_POSITION - Vector3(0, 3.9, 0)
		ghost.state = Ghost.State.CHASE
		ghost.memory = 8
		ghost.can_see = true
		ghost.last_known = p.position
		if ghost.archetype != "bully":
			ghost.listening_memory = 8
			ghost.whisper_charge = 2
		ghost._physics_process(1.0 / 60)
		all_clear = all_clear and ghost.state == Ghost.State.PATROL and ghost.memory == 0 and not ghost.can_see
		all_safe = all_safe and not ghost.has_line_of_sight() and not ghost.can_strike_player() and not ghost.audible(p.position, 200)
		if ghost.archetype != "bully":
			all_clear = all_clear and ghost.listening_memory == 0 and ghost.whisper_charge == 0
		ghost.position = quest.SOUL_POSITION
		ghost.state = Ghost.State.ATTACK
		ghost.strike_done = false
		ghost.attack_time = ghost.windup
		ghost._physics_process(1.0 / 60)
		all_relocated = all_relocated and ghost.position == ghost.patrol_home and not school.is_soul_sanctuary(ghost.position)
	check(all_clear, "All thirteen enemies, including listener and whisperer, abandon pursuit and special attacks")
	check(all_safe, "Rooftop player cannot be seen, heard or struck by any enemy archetype")
	check(all_relocated and p.health == 100, "Enemies that enter the sanctuary return to their patrol home before dealing damage")
	school.emit_noise(p.position, 200, "steps")
	school.emit_noise(p.position, 200, "decoy")
	school.survival.trigger_hunt()
	check(school.enemies.all(func(g): return g.memory == 0), "Steps, decoys and hunt bell cannot lure enemies onto the rooftop")
	check(p.get_interaction_target() == quest.soul and quest.begin_comfort(p), "Actual E ray opens An's dialogue without cheats on the rooftop")
	quest.close()
	p.fear = 100
	p.invulnerable_time = 0
	school.survival.panic_damage_clock = 2
	var clock_before: float = school.survival.run_time
	var battery_before: float = p.battery
	p.flashlight.show()
	school.survival._physics_process(1)
	check(p.health == 100 and p.fear < 100 and school.survival.fear_pressure == 0, "Sanctuary calms fear and prevents panic damage without immortality")
	check(school.survival.run_time > clock_before and p.battery < battery_before, "Clock and flashlight battery still advance in the safe zone")
	var ghost: CharacterBody3D = school.enemies[0]
	ghost.position = quest.SOUL_POSITION
	ghost.banish(0.01)
	ghost._physics_process(0.02)
	check(ghost.active and ghost.visible and ghost.position == ghost.patrol_home, "Banished enemy returns below the roof, never beside An")
	print("Soul rooftop validation: ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(4)
	Limbs.meshes.clear()
	Ghost.reshaped_meshes.clear()
	Soul.appearance_materials.clear()
	Humanoid.animation_libraries.clear()
	Humanoid.proportion_meshes.clear()
	Humanoid.faceless_mesh = null
	quit(0 if failures == 0 else 1)
