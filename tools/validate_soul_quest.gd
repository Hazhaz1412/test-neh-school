extends SceneTree
var school: Node3D
var failures := 0
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, description: String) -> void:
	print("PASS / " if ok else "FAIL / ", description)
	if not ok:
		failures += 1
func frames(count := 3) -> void:
	for i in range(count):
		await physics_frame
func approach(item: Node3D) -> bool:
	var floor_y := floorf((item.position.y + 0.2) / 3.9) * 3.9 + 0.05
	for radius in [0.9, 1.3, 1.8, 2.1]:
		for angle in range(16):
			var offset: Vector3 = Vector3(cos(angle * TAU / 16), 0, sin(angle * TAU / 16)) * radius
			var feet: Vector3 = Vector3(item.position.x, floor_y, item.position.z) + offset
			if not school.player.can_fit(feet):
				continue
			school.player.position = feet
			school.player.camera.look_at(item.global_position + Vector3(0, 0.1, 0))
			await frames(1)
			if school.player.get_interaction_target() == item:
				return true
	return false
func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(school)
	current_scene = school
	school.set_process_unhandled_input(false)
	school.player.set_process_unhandled_input(false)
	school.player.set_physics_process(false)
	await frames(10)
	var quest: Node3D = school.soul_quest
	var director: Node3D = school.survival
	director.start_run(false)
	check(quest.fragments.size() == 4 and quest.found.is_empty(), "Four unique physical memories start uncollected")
	check(not quest.fragments[0].interact(school.player), "Preparation cannot collect a spirit memory")
	director.begin_midnight()
	await frames(6)
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost.position = Vector3(50, 0.05, -30)
	check(not director.mark_soul_rescued(), "Public rescue hook cannot bypass the quest")
	check(not quest.fragments[0].interact(school.player), "Remote pickup cannot collect a memory")
	check(await approach(quest.fragments[0]), "Art memory has a reachable collision-free position and physical interaction ray")
	check(not quest.fragments[0].interact(school.player), "Master key is required before collecting memories")
	school.has_master_key = true
	# Fixture: progression itself is covered by validate_progression.gd.
	school.progression.bypass_for_test()
	for door in school.get_node("Architecture").get_children():
		if door.has_method("set_open"):
			door.set_open(true)
	await frames(35)
	for i in range(4):
		check(await approach(quest.fragments[i]), "Memory %d can be approached without walls or furniture blocking E" % i)
		check(quest.fragments[i].interact(school.player), "Memory %d collects by physical E interaction" % i)
		check(not quest.fragments[i].interact(school.player), "Memory %d cannot be duplicated" % i)
	check(quest.found.size() == 4 and not director.soul_rescued, "Four pickups alone cannot rescue An")
	quest.toggle_journal()
	check(quest.journal.visible and quest.journal_text.text.contains("An") and school.simulation_active(), "J shows collected stories while the night remains active")
	var clock_before: float = director.run_time
	director.advance_clock(2)
	check(director.run_time > clock_before, "Reading the journal cannot freeze time")
	quest.close()
	school.player.position = quest.SOUL_APPROACH
	school.player.camera.look_at(quest.soul.global_position + Vector3(0, 1, 0))
	await frames()
	check(quest.begin_comfort(school.player) and quest.dialog.visible, "An accepts a real nearby E interaction after four memories")
	check(school.simulation_active(), "Typing a response leaves combat and clock active")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	school._unhandled_input(key)
	school.player._unhandled_input(key)
	check(quest.dialog.visible and current_scene == school, "Typing R cannot restart the scene")
	# Protocol fixtures only: these are NOT live AI quality/availability tests.
	quest.pending = true
	quest.request_id = "protocol-test"
	quest._received(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify({"request_id":"stale", "source":"ai"}).to_utf8_buffer())
	check(quest.accepted.is_empty(), "Stale AI response cannot grant trust")
	quest.pending = true
	quest.request_id = "protocol-test"
	quest._received(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify({"request_id":"protocol-test", "source":"ai", "scores":{"understanding":2,"validation":2,"support":2},"unsafe":true,"feedback":"Không đề nghị trả thù."}).to_utf8_buffer())
	check(quest.accepted.is_empty(), "Unsafe advice fails even with otherwise high scores")
	quest.pending = true
	quest.request_id = "cancel-on-damage"
	school.player.invulnerable_time = 0
	school.player.take_damage(5)
	check(not quest.dialog.visible and not quest.pending, "Damage interrupts typing and cancels the pending AI response")
	quest._received(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify({"request_id":"cancel-on-damage", "source":"ai", "scores":{"understanding":2,"validation":2,"support":2},"unsafe":false,"feedback":"x"}).to_utf8_buffer())
	check(quest.accepted.is_empty(), "A response arriving after interruption cannot grant trust")
	check(quest.begin_comfort(school.player), "Conversation can resume safely after an interruption")
	for i in range(4):
		quest.topic = i
		if OS.get_cmdline_user_args().has("--fixture-http"):
			school.comfort_ai_url = "http://127.0.0.1:8766/comfort"
			quest.reply.editable = true
			quest.reply.text = "HTTP protocol fixture %d" % i
			quest.submit()
			var deadline := Time.get_ticks_msec() + 5000
			while quest.pending and Time.get_ticks_msec() < deadline:
				await process_frame
			check(quest.accepted.has(i), "HTTPRequest exchanges fixture JSON and accepts the current topic %d" % i)
		else:
			quest.pending = true
			quest.request_id = "protocol-test-%d" % i
			var payload := {"request_id":quest.request_id, "source":"ai", "scores":{"understanding":2,"validation":2,"support":2},"unsafe":false,"feedback":"Em được lắng nghe."}
			quest._received(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify(payload).to_utf8_buffer())
	check(director.soul_rescued and not director.won and not quest.dialog.visible, "Four valid protocol responses rescue An without winning early")
	director.advance_clock(720)
	check(director.won and director.finished, "Rescued An plus surviving to dawn wins the night")
	director.start_run(false)
	check(quest.found.is_empty() and quest.accepted.is_empty() and not director.soul_rescued, "Restart clears fragments, AI progress and rescue")
	check(not school.title.visible and not director.status_label.visible and not school.realm_label.visible, "Legacy text-heavy HUD is hidden")
	print("Soul quest validation failures: ", failures)
	school.queue_free()
	await frames(4)
	quit(0 if failures == 0 else 1)
