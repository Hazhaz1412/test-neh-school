extends SceneTree

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

func newest_decoy() -> CharacterBody3D:
	var result: CharacterBody3D
	for node in school.survival.get_children():
		if node is CharacterBody3D and node.get("landed") != null:
			result = node
	return result

func land(decoy: CharacterBody3D) -> void:
	for i in range(150):
		if decoy.landed:
			return
		await physics_frame

func validate() -> void:
	school = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
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
	for ghost in school.enemies:
		ghost.set_physics_process(false)
		ghost.collision_layer = 0
		ghost.position = Vector3(54, 0.05, 65)
	p.flashlight.hide()
	p.battery = 0
	p.add_item("battery")
	p.select_item("battery")
	check(p.use_selected_item() and p.battery == 50, "One stored battery charges an empty shared battery to exactly fifty percent")
	p.add_item("battery")
	p.select_item("battery")
	p.battery = 20
	check(p.use_selected_item() and p.battery == 70, "Battery adds fifty percentage points rather than fifty percent of remaining energy")
	p.add_item("battery")
	p.select_item("battery")
	check(p.use_selected_item() and p.battery == 100, "Battery recharge caps at one hundred percent")
	p.position = Vector3(0, 0.05, 74)
	p.rotation = Vector3.ZERO
	p.camera.rotation = Vector3.ZERO
	p.camera.position = Vector3(0, 1.62, 0)
	p.select_item("chalk")
	await frames(3)
	var origin: Vector3 = p.camera.global_position
	var count: int = p.chalk
	check(p.begin_chalk_charge("key") and p.chalk == count and newest_decoy() == null, "Pressing throw starts charge without spending or launching chalk")
	check(p.release_chalk_charge("key") and p.chalk == count - 1, "A quick tap releases exactly one chalk at the original strength")
	var quick := newest_decoy()
	check(is_equal_approx(Vector2(quick.velocity.x, quick.velocity.z).length(), 10) and quick.velocity.y == 2, "Quick throw retains original ten m/s speed and upward impulse")
	await land(quick)
	var quick_distance := Vector2(quick.position.x - origin.x, quick.position.z - origin.z).length()
	check(quick.landed and quick_distance > 4, "Quick throw physically lands on the real courtyard floor")
	p.select_item("chalk")
	check(p.begin_chalk_charge("key"), "Another carried chalk can be charged after throwing")
	p.tick_chalk_charge(0.75)
	check(is_equal_approx(p.chalk_charge_fraction(), 0.5) and p.chalk == count - 1, "Holding for three quarters of a second gives half charge without consuming an item")
	p.tick_chalk_charge(10)
	check(p.chalk_charge_fraction() == 1 and p.chalk_charge_time == 1.5, "Full charge takes one and a half seconds and cannot overcharge")
	check(not p.release_chalk_charge("mouse") and p.chalk_charging, "Releasing a different input cannot accidentally launch a held G charge")
	check(p.release_chalk_charge("key") and p.chalk == count - 2, "Releasing full charge consumes one chalk")
	var strong := newest_decoy()
	check(is_equal_approx(Vector2(strong.velocity.x, strong.velocity.z).length(), 50) and strong.velocity.y == 2, "Full charge increases horizontal speed fivefold while preserving the upward launch arc")
	await land(strong)
	var strong_distance := Vector2(strong.position.x - origin.x, strong.position.z - origin.z).length()
	check(strong.landed and absf(strong_distance / quick_distance - 5) < 0.15, "Full charged throw travels approximately five times the measured original distance on the actual map")
	print("Measured chalk reach: quick=", quick_distance, " m; full=", strong_distance, " m; ratio=", strong_distance / quick_distance)
	p.chalk = 3
	p.select_item("chalk")
	p.begin_chalk_charge("mouse")
	p.tick_chalk_charge(0.75)
	p.release_chalk_charge("mouse")
	var middle := newest_decoy()
	check(is_equal_approx(Vector2(middle.velocity.x, middle.velocity.z).length(), 30), "Half charge gives a smooth intermediate threefold throw")
	# A sweep at fifty m/s must still collide with a nearby solid wall.
	p.chalk = 3
	p.position = Vector3(32, 0.05, 31.2)
	p.camera.look_at(Vector3(32, 1.67, 34))
	await frames(3)
	p.select_item("chalk")
	check(p.throw_chalk(1), "Full-strength throw launches toward a real classroom wall")
	var blocked := newest_decoy()
	await land(blocked)
	check(blocked.landed and blocked.position.distance_to(p.camera.global_position) < 3, "Charged chalk collides with the thin classroom wall instead of tunnelling through it")
	p.chalk = 3
	p.select_item("chalk")
	p.begin_chalk_charge("key")
	p.tick_chalk_charge(0.8)
	p.select_item("camera")
	check(not p.chalk_charging and not p.release_chalk_charge("key") and p.chalk == 3, "Switching equipment cancels charged throw without spending chalk")
	p.select_item("chalk")
	p.begin_chalk_charge("key")
	school.paused_by_user = true
	p.tick_chalk_charge(1)
	check(not p.chalk_charging and not p.release_chalk_charge("key") and p.chalk == 3, "Pausing cancels charge; release cannot throw during pause")
	school.paused_by_user = false
	p.begin_chalk_charge("key")
	school.map_panel.show()
	p.tick_chalk_charge(1)
	check(not p.chalk_charging and p.chalk == 3, "Opening map cancels charge without consuming a slot")
	school.map_panel.hide()
	p.begin_chalk_charge("key")
	school.soul_quest.journal.show()
	p.tick_chalk_charge(1)
	check(not p.chalk_charging and p.chalk == 3, "Journal and comfort UI block charging without pausing or spending supplies")
	school.soul_quest.journal.hide()
	p.begin_chalk_charge("key")
	p._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not p.chalk_charging and p.chalk == 3, "Losing window focus cancels charge instead of leaving a stuck throw")
	p.begin_chalk_charge("key")
	var cover: Node3D = school.get_node("HidingSpots/HallA_0")
	p.begin_hide(cover)
	check(not p.chalk_charging and not p.begin_chalk_charge("key") and p.chalk == 3, "Entering a hiding spot cancels charge and prevents throwing through the cabinet")
	p.end_hide()
	p.position = Vector3(0, 0.05, 74)
	p.camera.rotation = Vector3.ZERO
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		p.select_item("camera")
		var press := InputEventKey.new()
		press.keycode = KEY_G
		press.pressed = true
		p._unhandled_input(press)
		check(p.selected_item() == "chalk" and p.chalk_charging and p.chalk == 3, "Real G press equips chalk and begins charging rather than throwing instantly")
		p.tick_chalk_charge(1.5)
		press.pressed = false
		p._unhandled_input(press)
		check(not p.chalk_charging and p.chalk == 2 and is_equal_approx(newest_decoy().velocity.length(), Vector3(0, 2, 50).length()), "Real G release launches a fully charged chalk and consumes one item")
		p.select_item("chalk")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		p._unhandled_input(mouse)
		check(p.chalk_charging and p.chalk == 2, "Real left mouse press begins charge when chalk is equipped")
		p.tick_chalk_charge(0.75)
		mouse.pressed = false
		p._unhandled_input(mouse)
		check(not p.chalk_charging and p.chalk == 1 and is_equal_approx(Vector2(newest_decoy().velocity.x, newest_decoy().velocity.z).length(), 30), "Real mouse release launches the chosen charge strength exactly once")
	p.chalk = 0
	check(not p.begin_chalk_charge("key") and not p.throw_chalk(1), "Empty inventory cannot charge or spawn free chalk")
	p.reset_survival()
	check(not p.chalk_charging and p.chalk_charge_time == 0 and p.chalk == 3, "Restart clears pending charge and restores starting chalk")
	print("Charged chalk/recharge validation: ", checks, " checks, ", failures, " failures")
	school.queue_free()
	await frames(4)
	quit(0 if failures == 0 else 1)
