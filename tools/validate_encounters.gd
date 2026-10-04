extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
const Humanoid = preload("res://scripts/humanoid_model.gd")
const Limbs = preload("res://scripts/combat_limbs.gd")
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
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	await frames(25)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	await frames(4)
	school.survival.set_physics_process(false)
	var p: CharacterBody3D = school.player
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	p.combat.set_physics_process(false)
	var director: Node = school.encounters
	director.set_physics_process(false)
	for enemy in school.enemies:
		enemy.set_physics_process(false)
	var kinds := {}
	for enemy in school.enemies:
		kinds[enemy.archetype] = int(kinds.get(enemy.archetype, 0)) + 1
	check(school.enemy_count == 3 and school.special_enemy_count == 3 and school.enemies.size() == 6, "Default roster is reduced from thirteen to six cached actors")
	check(kinds.get("bully") == 3 and kinds.get("listener") == 1 and kinds.get("whisperer") == 1 and kinds.get("blocker") == 1, "Reduced roster still includes every school threat archetype")
	check(director.reserved_count() == 1, "Midnight begins with one distant presence rather than a crowd")
	var waking: CharacterBody3D = school.enemies.filter(func(e): return not e.dormant)[0]
	check(waking.active and waking.position.distance_to(p.position) >= 14 and not director.visible_to_player(waking.position), "First actor materializes outside the player's view and beyond fourteen metres")
	check(school.enemies.filter(func(e): return e.dormant).all(func(e): return not e.active and not e.visible and e.collision_layer == 0 and not e.animation.is_playing()), "Sleeping pool has no rendering, collision, animation, hearing or attacks")
	# Move into the central forecourt: the entry corner may only offer one safe angle.
	p.position = Vector3(0, 0.05, 64)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	director.prepare()
	director._physics_process(12.1)
	check(director.reserved_count() == 2, "A second presence appears after the opening twelve-second breathing space")
	director._physics_process(24)
	check(director.reserved_count() == 2, "Normal exploration is limited to two active encounters")
	school.survival.trigger_hunt()
	director._physics_process(1)
	check(director.reserved_count() == 3 and director.nearby_count() <= 2, "Hunt bell can add a third presence while respecting the local density budget")
	check(not director.wake_one() and director.reserved_count() == 3, "The hard active cap prevents additional spawning")
	check(not director.safe_spawn(p.position + Vector3(0, 0, -16), school.enemies[5]), "No spawn is allowed directly in the camera's open view")
	check(not director.safe_spawn(p.position + Vector3(0, 0, 5), school.enemies[5]), "No spawn is allowed near the player even behind the camera")
	check(not director.safe_spawn(Vector3(12, 3.95, 7.5), school.enemies[5]), "Spawn cannot silently move a threat to the wrong floor")
	var heavy: CharacterBody3D = school.enemies.filter(func(e): return e.archetype == "blocker")[0]
	check(heavy.dormant and heavy.return_collision_layer == 6, "Dormant heavy actor preserves its physical blocker collision for its next encounter")
	var live: Array[CharacterBody3D] = []
	live.assign(school.enemies.filter(func(e): return not e.dormant))
	p.select_item("camera")
	p.battery = 100
	check(p.take_photo() and live.all(func(e): return e.banished_remaining == 6), "Camera still removes every currently active enemy for six seconds")
	check(school.enemies.filter(func(e): return e.dormant).all(func(e): return e.banished_remaining == 0), "Camera does not accidentally reactivate or banish the sleeping pool")
	director._physics_process(3)
	check(director.reserved_count() == 3 and director.rest_remaining > 4 and live.all(func(e): return not e.active), "No replacement wave spawns during the photo escape window")
	for enemy in live:
		enemy._physics_process(6.1)
	check(live.all(func(e): return e.active) and director.reserved_count() == 3, "Only the same reserved actors return after flash, preserving the encounter cap")
	# Recycle an actor only where the player cannot see it disappear.
	var old := live[0]
	old.position = Vector3(-18, 3.95, -40.5)
	old.clear_pursuit()
	director._physics_process(1)
	check(old.dormant and director.reserved_count() == 2, "An unseen distant actor on an irrelevant floor quietly returns to the pool")
	var visible := live[1]
	visible.position = Vector3(0, 0.05, 47)
	visible.clear_pursuit()
	director.ages[visible] = 200
	director._physics_process(1)
	check(not visible.dormant and visible.visible, "Visible actors never disappear merely because their encounter age expired")
	for enemy in school.enemies:
		enemy.set_dormant(true)
	director.spawn_clock = 0
	director.rest_remaining = 0
	director.next_actor = 0
	director.give_break(8)
	director._physics_process(4)
	check(director.reserved_count() == 0 and director.rest_remaining == 4, "Successful counterattack can reserve a genuine eight-second break from replacement spawns")
	school.paused_by_user = true
	var rest: float = director.rest_remaining
	director._physics_process(5)
	check(director.rest_remaining == rest, "Esc pauses encounter and escape-window clocks")
	school.paused_by_user = false
	p.position = school.soul_quest.SOUL_POSITION
	director.rest_remaining = 0
	director._physics_process(10)
	check(director.reserved_count() == 0 and not director.wake_one(), "Rooftop sanctuary never becomes a spawn site or requests an encounter")
	p.position = Vector3(-18, 3.95, 7.5)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	director.spawn_clock = 0
	director._physics_process(3)
	var upstairs: Array = school.enemies.filter(func(e): return not e.dormant)
	check(not upstairs.is_empty() and upstairs.all(func(e): return absf(e.position.y - p.position.y) < 0.7 and not director.visible_to_player(e.position)), "When player explores upstairs, encounters use reachable unseen points on that floor")
	# Persistent visibility should feel decisive, but corners remain an escape.
	for enemy in school.enemies:
		enemy.set_dormant(true)
	var hunter: CharacterBody3D = school.enemies[0]
	hunter.position = Vector3(0, 0.05, 52)
	hunter.set_dormant(false)
	p.position = Vector3(0, 0.05, 64)
	hunter.look_at(p.position)
	hunter.vision_clock = 0
	hunter.clear_pursuit()
	hunter._physics_process(0.2)
	hunter._physics_process(0.45)
	check(hunter.state == Ghost.State.SEARCH and hunter.rush_time == 0, "A brief glimpse still produces suspicion and slow investigation")
	hunter._physics_process(0.7)
	check(hunter.state == Ghost.State.CHASE and hunter.rush_time > 0, "One point two five seconds of clear sight confirms the player and commits to an aggressive rush")
	var remembered: Vector3 = hunter.last_known
	hunter.position = Vector3(32, 0.05, 32.8)
	p.position = Vector3(32, 0.05, 31.2)
	hunter.vision_clock = 0
	hunter._physics_process(0.2)
	check(hunter.state == Ghost.State.SEARCH and hunter.rush_time == 0 and hunter.last_known == remembered, "Even a confirmed hunter slows down and stops tracking after a wall breaks visibility")
	hunter.position = Vector3(0, 0.05, 61)
	p.position = Vector3(0, 0.05, 64)
	hunter.rotation = Vector3.ZERO # Looking away: close distance must override view cone.
	hunter.clear_pursuit()
	hunter.vision_clock = 10
	hunter.cooldown = 0
	hunter.rush_clock = 0
	hunter._physics_process(1.0 / 60)
	check(hunter.state == Ghost.State.CHASE and hunter.can_see and hunter.rush_time > 0, "Within three metres, even a freshly reset vision timer and turned back react on the very next physics step")
	hunter.clear_pursuit()
	hunter.position = Vector3(0, 0.05, 62.8)
	hunter.vision_clock = 10
	hunter.cooldown = 0
	hunter._physics_process(1.0 / 60)
	check(hunter.state == Ghost.State.ATTACK, "A student standing within striking reach immediately starts a readable swing")
	var listener: CharacterBody3D = school.enemies.filter(func(e): return e.archetype == "listener")[0]
	hunter.set_dormant(true)
	listener.position = Vector3(0, 0.05, 62)
	listener.set_dormant(false)
	listener.clear_pursuit()
	listener.vision_clock = 10
	listener._physics_process(1.0 / 60)
	check(listener.listening_memory > 0 and listener.state == Ghost.State.CHASE and listener.rush_time > 0, "A silent player within two metres is recognized by the blind listener through immediate contact")
	listener.set_dormant(true)
	var whisperer: CharacterBody3D = school.enemies.filter(func(e): return e.archetype == "whisperer")[0]
	whisperer.position = Vector3(0, 0.05, 61)
	whisperer.set_dormant(false)
	whisperer.clear_pursuit()
	whisperer.vision_clock = 10
	p.flashlight.hide()
	whisperer._physics_process(1.0 / 60)
	check(whisperer.state == Ghost.State.CHASE and Vector2(whisperer.velocity.x, whisperer.velocity.z).length() > 2, "Rumour entity stops holding position and lunges when player stands close")
	whisperer.position = Vector3(32, 0.05, 32.8)
	p.position = Vector3(32, 0.05, 31.2)
	whisperer.clear_pursuit()
	whisperer.vision_clock = 10
	whisperer._physics_process(1.0 / 60)
	check(not whisperer.can_see and whisperer.state == Ghost.State.PATROL, "Immediate close detection still respects a separating wall")
	print("Encounter validation: ", checks, " checks, ", failures, " failures")
	var report := {"checks": checks, "failures": failures, "roster": 6, "normal_active": 2, "hard_cap": 3, "minimum_spawn_distance": 14, "interval_seconds": 22, "confirmation_seconds": 1.25}
	var file := FileAccess.open("res://docs/encounter-validation.json", FileAccess.WRITE)
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
