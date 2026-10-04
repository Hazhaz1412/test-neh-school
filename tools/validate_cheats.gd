extends SceneTree

const Ghost = preload("res://scripts/bully_ghost.gd")
var school: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS / " if ok else "FAIL / ", message)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func key(code: int, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	# Dispatch through the real scene input chain, including cinematic and UI.
	Input.parse_input_event(event)
	Input.flush_buffered_events()

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
	await frames(10)
	if DisplayServer.get_name() != "headless":
		# Wait for the window manager before dispatching a held keyboard chord.
		root.grab_focus()
		await frames(30)
	var cheats: Node = school.test_cheats
	var quest: Node3D = school.soul_quest
	var director: Node3D = school.survival
	var p: CharacterBody3D = school.player
	check(not cheats.enabled and not cheats.used_this_run and not p.test_invincible(), "Cheats default off on the actual game scene")
	check(p.stamina == 130 and school.stamina_bar.max_value == 130, "Player starts with thirty percent more stamina and the HUD uses its new capacity")
	director.start_run()
	director.set_physics_process(false)
	key(KEY_H)
	await frames(2)
	check(not cheats.enabled and director.opening.playing, "H alone does not enable cheats or skip the cinematic")
	key(KEY_P)
	await frames(8)
	check(cheats.enabled and cheats.used_this_run and not director.opening.playing and director.phase == director.Phase.NIGHT, "Actual H plus P input enables test mode and skips straight to the real night")
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost.position = Vector3(54, 0.05, 65)
	check(school.has_master_key and quest.found.size() == 4 and quest.accepted.is_empty() and not director.soul_rescued and not quest.soul.released and quest.soul.visible, "H plus P grants key and memories but keeps An visible and waiting for actual dialogue")
	check(not director.finished and not director.won and school.enemies.size() == 13, "Night remains playable for enemy and movement testing after objectives complete")
	check(quest.fragments.all(func(fragment): return not fragment.visible and fragment.get_node("Interaction").collision_layer == 0), "Auto-completed physical memories cannot be collected again")
	var damage_events := [0]
	p.damaged.connect(func(_amount): damage_events[0] += 1)
	p.health = 47
	p.invulnerable_time = 0
	p.take_damage(999)
	check(p.health == 47 and damage_events[0] == 0 and p.enabled, "Immortality blocks actual lethal damage and damage interruption signals")
	check(p.test_speed_multiplier() == 3, "Test movement uses three times normal walk, run and quiet speed")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		p.position = Vector3(0, 0.05, 74)
		p.rotation = Vector3.ZERO
		p.camera.rotation = Vector3.ZERO
		p.velocity = Vector3.ZERO
		key(KEY_W)
		for i in range(60):
			await physics_frame
			p._physics_process(1.0 / 60)
		check(absf(p.velocity.z + 9) < 0.1 and p.position.z < 70, "Real W input accelerates the player capsule to nine m/s and moves through the courtyard")
		key(KEY_SHIFT)
		for i in range(30):
			await physics_frame
			p._physics_process(1.0 / 60)
		check(absf(p.velocity.z + 15.6) < 0.1, "Real Shift input runs at fifteen point six m/s in test mode")
		check(is_equal_approx(p.stamina, 118.5), "A real half-second sprint consumes eleven point five from the new full stamina of 130")
		key(KEY_W, false)
		key(KEY_SHIFT, false)
		for i in range(60):
			await physics_frame
			p._physics_process(1.0 / 60)
		check(p.stamina == 130, "Resting restores stamina to 130 without the old one hundred cap")
	key(KEY_P, true, true)
	await frames(2)
	check(cheats.enabled, "Key auto-repeat cannot repeatedly toggle a held chord")
	key(KEY_P, false)
	key(KEY_P)
	await frames(2)
	check(not cheats.enabled and cheats.used_this_run and p.test_speed_multiplier() == 1, "A fresh chord toggles powers off while keeping the test-run marker")
	p.invulnerable_time = 0
	p.take_damage(5)
	check(p.health == 42 and damage_events[0] == 1, "Damage works normally again after cheats are turned off")
	key(KEY_H, false)
	key(KEY_P, false)
	key(KEY_P)
	check(not cheats.enabled, "P alone cannot toggle cheats")
	key(KEY_H)
	await frames(2)
	check(cheats.enabled, "Chord accepts either key order")
	key(KEY_H, false)
	key(KEY_P, false)
	school.paused_by_user = true
	await process_frame
	await process_frame
	check(school.cheat_ai_button.visible and school.cheat_finish_button.visible, "Esc exposes explicit AI-test and finish-night buttons only in test mode")
	school.cheat_ai_button.pressed.emit()
	await frames(3)
	check(not school.paused_by_user and quest.found.size() == 4 and quest.accepted.is_empty() and not director.soul_rescued and not quest.soul.released, "AI-test button preserves exploration objectives but resets all real comfort progress")
	check(p.get_interaction_target() == quest.soul and p.can_fit(p.position), "AI-test button places a collision-free player within the actual E ray to An")
	check(quest.begin_comfort(p), "An can be approached and spoken to after AI-test preparation")
	quest.reply.text = "Em không có lỗi. Anh sẽ lắng nghe em."
	key(KEY_H)
	key(KEY_P)
	await frames(2)
	check(cheats.enabled and quest.dialog.visible, "Typing H and P in An's dialogue cannot activate or deactivate cheats")
	key(KEY_H, false)
	key(KEY_P, false)
	for reason in ["missing_api_key", "invalid_api_key", "quota_exceeded", "network_error", "blocked_answer", "incomplete_answer", "invalid_ai_response", "provider_unavailable"]:
		quest.pending = true
		quest.request_id = "error-" + reason
		quest.send_button.disabled = true
		quest.reply.editable = false
		quest._received(HTTPRequest.RESULT_SUCCESS, 503, [], JSON.stringify({"error": "ai_unavailable", "reason": reason, "request_id": quest.request_id}).to_utf8_buffer())
		check(not quest.pending and not quest.send_button.disabled and quest.reply.editable and quest.feedback.text == quest.ai_error_text(reason) and quest.accepted.is_empty() and quest.reply.text.begins_with("Em không có lỗi"), "AI failure %s is specific, preserves writing, enables retry and grants no trust" % reason)
	quest.pending = true
	quest._received(HTTPRequest.RESULT_TIMEOUT, 0, [], PackedByteArray())
	check(quest.feedback.text == quest.ai_error_text("timeout") and not quest.pending, "Transport timeout gives the specific retry message")
	quest.pending = true
	quest._received(HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray())
	check(quest.feedback.text.contains("cầu nối AI") and not quest.pending, "Unavailable local bridge is distinguished from a missing provider key")
	quest.close()
	var cover: Node3D = school.get_node("HidingSpots/HallA_0")
	p.begin_hide(cover)
	cheats.prepare_ai_test()
	check(not p.is_hidden() and is_equal_approx(p.get_node("Collision").shape.height, 1.75) and is_equal_approx(p.camera.position.y, 1.62), "AI-test teleport restores standing state even from a hiding spot")
	director.soul_rescued = true
	quest.soul.released = true
	quest.soul.hide()
	cheats.prepare_exploration()
	await frames(2)
	check(quest.soul.visible and not quest.soul.released and not director.soul_rescued and quest.accepted.is_empty(), "Preparing test objectives also restores An when an earlier test already rescued and hid her")
	school.paused_by_user = true
	school.cheat_finish_button.pressed.emit()
	check(director.finished and director.won and director.clock_text() == "06:00" and director.end_text.text.contains("TEST"), "Finish-test button completes every objective and the dawn outcome with an explicit test marker")
	director.start_run(false)
	check(not cheats.enabled and not cheats.used_this_run and quest.found.is_empty() and quest.accepted.is_empty() and not school.has_master_key and p.stamina == 130, "New run clears cheats and every bypassed objective and restores the increased stamina")
	print("Cheat / AI diagnostics validation: ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(4)
	Ghost.reshaped_meshes.clear()
	quit(0 if failures == 0 else 1)
