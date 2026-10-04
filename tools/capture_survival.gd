extends SceneTree

var school: Node3D

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func shot(filename: String) -> void:
	school._update_light_budget()
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + filename + ".png")

func place(pos: Vector3, focus: Vector3) -> void:
	school.player.position = pos
	school.player.rotation = Vector3.ZERO
	school.player.camera.rotation = Vector3.ZERO
	school.player.camera.look_at(focus)
	await frames(3)

func e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	school.player._unhandled_input(event)

func capture() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	school.set_process_unhandled_input(false)
	current_scene = school
	await frames(25)
	school.survival.start_run(false)
	school.survival.begin_midnight()
	school.player.set_physics_process(false)
	school.player.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	await frames(8)
	var selected := {}
	for enemy in school.enemies:
		enemy.set_physics_process(false)
		enemy._play("idle")
		if enemy.archetype != "bully" and not selected.has(enemy.archetype):
			selected[enemy.archetype] = enemy
	await place(Vector3(0, 0.05, 64), Vector3(0, 4, 10))
	await shot("survival-start-preview")
	school.notice_time = 0
	for enemy in school.enemies:
		enemy.hide()
		enemy.collision_layer = 0
	for entry in [["listener", -2.5], ["whisperer", 0.0], ["blocker", 2.5]]:
		var enemy: CharacterBody3D = selected[entry[0]]
		enemy.position = Vector3(entry[1], 0.05, 44)
		enemy.show()
		enemy.look_at(Vector3(0, 0.05, 49))
	await place(Vector3(0, 0.05, 49), Vector3(0, 1.7, 44))
	await shot("survival-entities-preview")
	for enemy in selected.values():
		enemy.hide()
	var listener: CharacterBody3D = selected.listener
	listener.position = Vector3(18.2, 0.05, 8.2)
	listener.show()
	listener.look_at(Vector3(19, 0.05, 6.75))
	var cover: Node3D = school.get_node("HidingSpots/HallA_0")
	await place(cover.approach_position(), cover.to_global(Vector3(0, 1.1, 0.72)))
	e()
	assert(school.player.is_hidden())
	school.player.fear = 82
	school.player.tick_survival(0.5, true)
	school.survival.warn("Kẻ Dò Tiếng ở ngoài · nín thở và chờ nó đi qua", 5)
	school.notice_time = 0
	await shot("survival-hiding-preview")
	e()
	listener.hide()
	listener.position = Vector3(50, 0.05, 65)
	var whisperer: CharacterBody3D = selected.whisperer
	whisperer.position = Vector3(18, 0.05, 7.5)
	whisperer.show()
	school.player.fear = 35
	school.player.battery = 78
	await place(Vector3(14, 0.05, 7.5), Vector3(18, 1.7, 7.5))
	school.player.flashlight.show()
	whisperer.look_at(school.player.position)
	whisperer.vision_clock = 0
	whisperer.set_physics_process(true)
	await frames(48)
	assert(whisperer.stun_time > 0)
	whisperer.set_physics_process(false)
	await shot("survival-light-counter-preview")
	whisperer.hide()
	whisperer.position = Vector3(50, 0.05, 65)
	school.survival.warning_time = 0
	school.player.fear = 0
	await place(Vector3(-45, 0.05, -54.5), school.master_key.global_position)
	e()
	assert(school.has_master_key)
	await place(Vector3(0, 0.05, 76), school.survival.gate.global_position)
	e()
	assert(not school.survival.won)
	await shot("survival-sealed-gate-preview")
	school.queue_free()
	await frames(3)
	quit()
