extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
const Humanoid = preload("res://scripts/humanoid_model.gd")
const Limbs = preload("res://scripts/combat_limbs.gd")
const Soul = preload("res://scripts/student_soul.gd")
var school: Node3D
var p: CharacterBody3D
var g: CharacterBody3D
var combat: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("validate")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func encounter() -> void:
	combat.reset()
	p.recover()
	p.invulnerable_time = 0
	p.position = Vector3(0, 0.05, 64)
	p.velocity = Vector3.ZERO
	p.rotation = Vector3.ZERO
	for enemy in school.enemies:
		enemy.stun_remaining = 0
		enemy.restrained_remaining = 0
		enemy.clear_pursuit()
		enemy.position = Vector3(54, 0.05, 65)
	g.position = Vector3(0, 0.05, 62.6)
	g.cooldown = 0
	g.look_at(p.position)
	g.vision_clock = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func two_hits() -> void:
	p.take_damage(g.damage, g)
	p.invulnerable_time = 0
	p.take_damage(g.damage, g)
	p.invulnerable_time = 0

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.enemy_count = 8
	school.special_enemy_count = 5
	school.smart_spawn_enabled = false
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	await frames(25)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	# Fixture: progression itself is covered by validate_progression.gd.
	school.progression.bypass_for_test()
	await frames(8)
	p = school.player
	g = school.enemies[0]
	combat = p.combat
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	combat.set_physics_process(false)
	school.survival.set_physics_process(false)
	for enemy in school.enemies:
		enemy.set_physics_process(false)
	check(school.enemies.size() == 13, "All thirteen enemies participate in revised hunting")
	var route_ok := true
	var map: RID = school.get_world_3d().navigation_map
	var route: Array[Vector3] = school.campus_patrol_route(0)
	for i in range(route.size()):
		var start := NavigationServer3D.map_get_closest_point(map, route[i])
		var finish := NavigationServer3D.map_get_closest_point(map, route[(i + 1) % route.size()])
		var path := NavigationServer3D.map_get_path(map, start, finish, true)
		route_ok = route_ok and not path.is_empty() and path[-1].distance_to(finish) < 0.2 and absf(start.y - route[i].y) < 0.7 and not school.is_soul_sanctuary(start)
		if not route_ok:
			print("Route diagnostic ", i, ": ", route[i], " -> ", start, " end ", finish, " points ", path.size())
	check(route_ok, "Every campus checkpoint connects through navigation on the intended floor, excluding roofs")
	check(school.enemies.all(func(e): return e.patrol_route.size() >= 20), "Every archetype patrols courtyard, both wings, B and three floors")
	check(school.campus_patrol_route(1)[0] == route[-1], "Separate groups circulate in opposite directions")
	encounter()
	g.position = Vector3(0, 0.05, 59)
	g.patrol_route.assign([Vector3(0, 0, 54), Vector3(8, 0, 54)])
	g.patrol_index = 0
	g.detection_range = 0
	g._physics_process(0.016)
	school.elapsed += 200
	g.path_clock = 0
	g._physics_process(0.016)
	check(g.patrol_index == 0 and g.agent.target_position.distance_to(Vector3(0, 0, 54)) < 1, "Elapsed time never reverses an unfinished patrol checkpoint")
	for i in range(380):
		g._physics_process(1.0 / 60)
		await physics_frame
		if g.patrol_index == 1:
			break
	check(g.patrol_index == 1 and g.position.distance_to(Vector3(0, 0, 54)) < 1.5, "A real moving ghost advances its route only after arriving")
	g.detection_range = 18
	encounter()
	g.position = Vector3(0, 0.05, 54)
	g.look_at(p.position)
	g._physics_process(0.016)
	check(g.state == Ghost.State.STALK, "A distant first sight triggers a brief suspicion rather than an immediate rush")
	g._physics_process(0.45)
	check(g.state == Ghost.State.SEARCH and g.rush_time == 0, "Distant sight becomes slow investigation of the observed position")
	var remembered: Vector3 = g.last_known
	g.position = Vector3(32, 0.05, 32.8)
	p.position = Vector3(32, 0.05, 31.2)
	g.vision_clock = 0
	g._physics_process(0.016)
	check(not g.can_see and g.last_known == remembered and g.state == Ghost.State.SEARCH, "After the player cuts behind a classroom wall, the ghost retains only the last seen point")
	check(Vector2(g.velocity.x, g.velocity.z).length() <= g.search_speed + 0.01, "Investigation moves slowly after losing sight")
	encounter()
	g.position = Vector3(0, 0.05, 61)
	g._physics_process(0.016)
	check(g.state == Ghost.State.CHASE, "Visible contact inside close range commits to chase")
	encounter()
	g.start_attack()
	for i in range(51):
		p.velocity = Vector3(0, 0, 3)
		p.move_and_slide()
		g._physics_process(1.0 / 60)
		await physics_frame
	check(p.health == 86, "Continuous walking with a real moving capsule no longer makes the player immune to a swing")
	encounter()
	g.start_attack()
	p.position.z = 70
	g._tick_attack(g.windup)
	check(p.health == 100, "Escaping actual melee reach still avoids damage")
	encounter()
	g.position = Vector3(32, 0.05, 32.8)
	p.position = Vector3(32, 0.05, 31.2)
	g.start_attack()
	g._tick_attack(g.windup)
	check(p.health == 100, "Attack contact cannot pass through a classroom wall")
	encounter()
	p.take_damage(14)
	check(combat.consecutive_hits == 0, "Panic or environmental damage does not arm melee QTE")
	p.invulnerable_time = 0
	p.take_damage(14, g)
	p.take_damage(14, g)
	check(combat.consecutive_hits == 1, "Rejected invulnerable hits do not count towards the streak")
	combat._physics_process(7.1)
	check(combat.consecutive_hits == 0, "Seven seconds without a landed melee hit breaks the consecutive streak")
	encounter()
	two_hits()
	check(p.health == 72 and not combat.busy() and combat.consecutive_hits == 2, "Two landed hits prepare an opportunity without automatic counterattack or buff")
	g.start_attack()
	check(combat.mode == combat.Mode.QTE and p.health == 72 and g.restrained_remaining > 0, "The third attack offers QTE before applying damage and holds the raised weapon")
	combat._physics_process(0.10)
	check(not combat.respond() and p.health == 58 and combat.adrenaline_remaining == 0, "Pressing too early takes the third hit and grants no escape buff")
	encounter()
	two_hits()
	p.invulnerable_time = 0.15
	g.start_attack()
	check(not combat.busy(), "A swing starting during hit grace does not prematurely arm QTE")
	p.invulnerable_time = 0
	g._tick_attack(g.windup)
	check(combat.mode == combat.Mode.QTE and p.health == 72, "An eligible third contact is intercepted even when its windup began during hit grace")
	encounter()
	two_hits()
	g.start_attack()
	combat._physics_process(0.91)
	check(not combat.busy() and p.health == 58 and combat.adrenaline_remaining == 0, "Missing the QTE deadline applies exactly one third hit")
	encounter()
	two_hits()
	school.map_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	g.start_attack()
	check(combat.mode == combat.Mode.QTE and not school.map_panel.visible and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "A third attack closes the map and restores captured controls for the dodge and escape")
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_ESCAPE
	pause_key.pressed = true
	p._unhandled_input(pause_key)
	school._unhandled_input(pause_key)
	check(school.paused_by_user and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc during QTE exposes the cursor and pause menu")
	p._unhandled_input(pause_key)
	school._unhandled_input(pause_key)
	check(not school.paused_by_user and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "Esc resumes QTE with movement controls captured")
	encounter()
	two_hits()
	g.start_attack()
	combat._physics_process(0.20)
	var before: float = combat.clock
	school.paused_by_user = true
	combat._physics_process(3)
	check(combat.clock == before and not combat.respond(), "Esc pauses QTE timing and cannot submit a dodge")
	school.paused_by_user = false
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	event.echo = true
	combat._input(event)
	check(combat.mode == combat.Mode.QTE, "A held key repeat cannot complete QTE")
	event.echo = false
	combat._input(event)
	check(combat.mode == combat.Mode.COUNTER and p.health == 72 and combat.limbs.visible, "A fresh Space press in the green interval dodges and starts the visible grab")
	check(not p.can_use_item() and p.get_interaction_target() == null, "Weapons and interaction cannot interrupt the short grapple")
	var mesh_ok := true
	for mesh in Limbs.meshes.values():
		mesh_ok = mesh_ok and mesh.get_surface_count() > 0
	check(mesh_ok and Limbs.meshes.size() == 3, "Hands and boot are extracted from the existing CC0 character asset")
	var near: Array[CharacterBody3D] = []
	var types := {}
	for enemy in school.enemies:
		if enemy != g and not types.has(enemy.archetype):
			types[enemy.archetype] = true
			near.append(enemy)
			enemy.position = Vector3(2.4, 0.05, 64 - near.size() * 0.35)
	var far: CharacterBody3D = school.enemies[2]
	far.position = Vector3(0, 0.05, 54)
	combat._physics_process(0.41)
	check(combat.punched and not combat.kicked and g.hit_reaction == 1, "The punch lands first with facial recoil and impact particles")
	combat._physics_process(0.36)
	check(combat.kicked and g.stun_remaining == 3 and near.all(func(e): return e.stun_remaining == 3), "The kick stuns the attacker and nearby bullies, listener, whisperer and blocker for three seconds")
	check(far.stun_remaining == 0, "A distant ghost is not stunned across the campus")
	check(combat.adrenaline_remaining == 8 and combat.sprint_multiplier() == 0.5 and combat.heartbeat.playing, "Only a successful kick grants eight seconds of heartbeat and half sprint drain")
	var old_known: Vector3 = g.last_known
	g.hear_noise(p.position, 30, "steps")
	check(not g.can_strike_player() and g.last_known == old_known, "A stunned ghost neither strikes nor follows fresh noise")
	var listener: CharacterBody3D = near.filter(func(e): return e.archetype == "listener")[0]
	listener.listening_memory = 0
	listener.hear_noise(p.position, 30, "steps")
	listener._physics_process(0.1)
	check(listener.listening_memory == 0 and not listener.can_strike_player(), "Shared stun also disables the blind listener's independent hearing and melee logic")
	var kicked_from := g.position
	for i in range(24):
		g._physics_process(1.0 / 60)
		await physics_frame
	check(g.position.distance_to(kicked_from) > 1 and g.position.z < kicked_from.z, "Kick physically throws the ghost away using collision-aware movement")
	combat._physics_process(0.4)
	check(not combat.busy() and not combat.limbs.visible and g.stun_remaining > 2, "Player regains movement while the stunned enemy is still recovering")
	var stamina: float = p.stamina
	check(p.MAX_STAMINA == 130 and combat.sprint_multiplier() * 23 == 11.5 and p.stamina == stamina, "Adrenaline halves consumption without refilling stamina or increasing its capacity")
	combat._physics_process(8.1)
	check(combat.sprint_multiplier() == 1 and not combat.heartbeat.playing, "Adrenaline expires and returns sprint drain to normal")
	g._physics_process(3)
	check(not g.crowd_controlled() and g.animation.speed_scale == 1, "Enemies resume animation and investigation after stun expires")
	encounter()
	p.position = Vector3(32, 0.05, 31.2)
	g.position = Vector3(33, 0.05, 31.2)
	two_hits()
	var blocked: CharacterBody3D = school.enemies[2]
	blocked.position = Vector3(32, 0.05, 32.8)
	var upstairs: CharacterBody3D = school.enemies[3]
	upstairs.position = Vector3(32, 3.95, 31.2)
	g.start_attack()
	combat._physics_process(0.25)
	combat.respond()
	combat._physics_process(0.77)
	check(g.stun_remaining == 3 and blocked.stun_remaining == 0 and upstairs.stun_remaining == 0, "Counterattack cannot stun through a classroom wall or onto another floor")
	encounter()
	two_hits()
	school.test_cheats.enabled = true
	g.start_attack()
	check(not combat.busy(), "Invincibility cheat does not fabricate a dodge opportunity")
	school.test_cheats.enabled = false
	encounter()
	two_hits()
	g.start_attack()
	combat._physics_process(0.25)
	combat.respond()
	g.banish(6)
	combat._physics_process(0.1)
	check(not combat.busy() and combat.adrenaline_remaining == 0, "A banished attacker cancels the grapple without granting a fake kick buff")
	combat.adrenaline_remaining = 5
	p.reset_survival()
	check(not combat.busy() and combat.adrenaline_remaining == 0 and combat.consecutive_hits == 0 and p.camera.rotation.z == 0, "Restart clears QTE, adrenaline, streak and camera pose")
	print("Hunt/QTE validation: ", checks, " checks, ", failures, " failures")
	var report := {"checks": checks, "failures": failures, "date": "2026-10-04", "qte": "two landed hits, third attack, fresh Space press inside green interval", "stun_seconds": 3, "adrenaline_seconds": 8, "sprint_multiplier": 0.5}
	var file := FileAccess.open("res://docs/hunt-combat-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	school.queue_free()
	await frames(4)
	Ghost.reshaped_meshes.clear()
	Humanoid.animation_libraries.clear()
	Humanoid.proportion_meshes.clear()
	Humanoid.faceless_mesh = null
	Limbs.meshes.clear()
	Soul.appearance_materials.clear()
	quit(0 if failures == 0 else 1)
