extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
const Humanoid = preload("res://scripts/humanoid_model.gd")
const Limbs = preload("res://scripts/combat_limbs.gd")
const Soul = preload("res://scripts/student_soul.gd")
var school: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS / ", description)
	else:
		failures += 1
		push_error(description)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shot(title: String) -> void:
	school._update_light_budget()
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + title + ".png")

func capture() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	school.smart_spawn_enabled = false
	root.add_child(school)
	current_scene = school
	await frames(25)
	root.grab_focus()
	await frames(30)
	school.set_process_unhandled_input(false)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	await frames(8)
	school.survival.set_physics_process(false)
	var p: CharacterBody3D = school.player
	var combat: Node = p.combat
	p.set_process_unhandled_input(false)
	p.set_physics_process(false)
	combat.set_physics_process(false)
	for enemy in school.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(54, 0.05, 65)
	var ghost: CharacterBody3D = school.enemies[0]
	p.position = Vector3(0, 0.05, 64)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	p.invulnerable_time = 0
	ghost.position = Vector3(0, 0.05, 62.6)
	ghost.look_at(p.position)
	ghost.cooldown = 0
	ghost.vision_clock = 10
	p.set_physics_process(true)
	ghost.set_physics_process(true)
	key(KEY_S, true)
	await frames(52)
	key(KEY_S, false)
	p.set_physics_process(false)
	ghost.set_physics_process(false)
	check(p.health < 100 and p.position.z > 65, "Actual held S movement does not prevent a nearby ghost from detecting and landing its swing")
	combat.reset()
	p.recover()
	p.position = Vector3(0, 0.05, 64)
	p.velocity = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	p.invulnerable_time = 0
	ghost.clear_pursuit()
	ghost.position = Vector3(0, 0.05, 62.6)
	ghost.look_at(p.position)
	p.take_damage(ghost.damage, ghost)
	p.invulnerable_time = 0
	p.take_damage(ghost.damage, ghost)
	p.invulnerable_time = 0
	key(KEY_SPACE, true) # Already held before the third attack: must not count.
	school.map_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ghost.start_attack()
	check(not school.map_panel.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "QTE closes an open map and restores captured controls on a real display")
	combat._physics_process(0.35)
	await frames(3)
	check(combat.mode == combat.Mode.QTE, "Holding Space before the attack does not automatically dodge")
	p.set_process_unhandled_input(true)
	school.set_process_unhandled_input(true)
	key(KEY_ESCAPE, true)
	await frames(2)
	key(KEY_ESCAPE, false)
	check(school.paused_by_user and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Actual Esc input during QTE pauses and releases the cursor")
	key(KEY_ESCAPE, true)
	await frames(2)
	key(KEY_ESCAPE, false)
	check(not school.paused_by_user and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Actual Esc resumes QTE and captures the cursor")
	p.set_process_unhandled_input(false)
	school.set_process_unhandled_input(false)
	await shot("qte-dodge-preview")
	key(KEY_SPACE, false)
	key(KEY_SPACE, true)
	await frames(2)
	check(combat.mode == combat.Mode.COUNTER and p.health == 72, "Actual fresh keyboard input wins the timed QTE before third damage")
	key(KEY_SPACE, false)
	combat._physics_process(0.10)
	await shot("counter-grab-preview")
	combat._physics_process(0.30)
	await shot("counter-punch-preview")
	combat._physics_process(0.37)
	for i in range(10):
		ghost._physics_process(1.0 / 60)
		await physics_frame
	await shot("counter-kick-preview")
	check(combat.kicked and combat.heartbeat.playing and ghost.stun_remaining > 2.7, "Rendered kick gives stun, heartbeat and adrenaline")
	combat._physics_process(0.4)
	await shot("adrenaline-escape-preview")
	# Compare real key-driven sprint consumption under the same scene and timing.
	var buff_remaining: float = combat.adrenaline_remaining
	combat.adrenaline_remaining = 0
	p.position = Vector3(0, 0.05, 64)
	p.rotation = Vector3.ZERO
	p.stamina = 130
	p.fear = 0
	p.invulnerable_time = 3
	p.set_physics_process(true)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(30)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	p.set_physics_process(false)
	var normal_used: float = 130 - p.stamina
	var moved: float = 64 - p.position.z
	combat.adrenaline_remaining = buff_remaining
	p.position = Vector3(0, 0.05, 64)
	p.stamina = 130
	p.sprint_exhausted = false
	p.set_physics_process(true)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await frames(30)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	p.set_physics_process(false)
	var buff_used: float = 130 - p.stamina
	check(moved > 1.5 and normal_used > 10, "Real W+Shift input physically sprints and consumes ordinary stamina")
	check(absf(buff_used * 2 - normal_used) < 0.6, "Adrenaline uses half the stamina over the same real sprint duration")
	print("Rendered combat validation: 9 checks, ", failures, " failures; normal drain ", normal_used, ", adrenaline drain ", buff_used)
	var file := FileAccess.open("res://docs/combat-rendered-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": 9, "failures": failures, "display": DisplayServer.get_name(), "normal_sprint_used": normal_used, "adrenaline_sprint_used": buff_used, "input": "fresh Space, held S, W+Shift, Esc pause/resume"}, "\t"))
	school.queue_free()
	await frames(4)
	Ghost.reshaped_meshes.clear()
	Humanoid.animation_libraries.clear()
	Humanoid.proportion_meshes.clear()
	Humanoid.faceless_mesh = null
	Limbs.meshes.clear()
	Soul.appearance_materials.clear()
	quit(0 if failures == 0 else 1)
