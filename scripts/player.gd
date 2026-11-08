extends CharacterBody3D

const WALK_SPEED := 3.0
const RUN_SPEED := 5.2
const LOOK_SENSITIVITY := 0.0022
const MAX_STAMINA := 130.0
const FLASHLIGHT_DRAIN := 0.3375
const TORCH_ENERGY := 1.38
const CRANK_ENERGY := 1.035
const CRANK_DRAIN := 10.0
const CRANK_PUMP_MIN := 9
const CRANK_PUMP_MAX := 14
# The price of free light: every squeeze can be heard, so it cannot be spammed beside the demon.
const CRANK_NOISE := 9.0
const CRANK_LOW := 20.0
const GRAVITY := 18.0
const STAND_HEIGHT := 1.75
const STAND_EYE := 1.62
# Crouching (hold C) lowers the body for real: low cover hides the chest the
# ghosts look for, and the capsule fits under things a standing one cannot.
const CROUCH_HEIGHT := 1.1
const CROUCH_EYE := 1.0
const CROUCH_SPEED := 1.5
const CROUCH_SIGHT := 0.7
const STAND_SIGHT := 1.2
# A low hop (~0.45 m at GRAVITY): clears low clutter but not desks or gates.
const JUMP_VELOCITY := 4.0
const JUMP_STAMINA := 12.0
# Stamina spent per second of sprinting: a full bar lasts about 6.8 s.
const SPRINT_DRAIN := 19.0
const LANDING_NOISE := 8.0
# Head motion at full sprint; walking and crouching scale it down by speed.
# The head dips on every footfall but sways sideways once per stride (left foot,
# right foot), rolling slightly with the sway.
const BOB_HEIGHT := 0.06
const BOB_SWAY := 0.035
const BOB_ROLL := 0.02
# Z / X lean the head out to the left or right: round a pillar, a doorway, a corner. The body
# stays behind cover; let go and the head comes back.
const LEAN_REACH := 0.6
const LEAN_ROLL := 0.17
const LEAN_SPEED := 5.0
signal damaged(amount: float)
signal died
var health := 100.0
var invulnerable_time := 0.0
var stamina := MAX_STAMINA
var enabled := true
var step_time := 0.0
var bob_amount := 0.0 # 0 standing still .. 1 at full sprint.
var door_target: Node3D
var hidden_spot: Node3D
var saved_flashlight := false
var startle := 0.0
var battery := 100.0
var fear := 0.0
var breath := 100.0
const BAG_SIZE := 6
const PHOTO_COST := 20.0
const BATTERY_RECHARGE := 50.0
const CHALK_CHARGE_SECONDS := 1.5
const CHALK_MAX_RANGE_MULTIPLIER := 5.0
const ITEM_NAMES := {"torch": "Đèn pin", "crank": "Đèn bấm tay", "camera": "Máy ảnh", "battery": "Pin", "medicine": "Sơ cứu", "chalk": "Phấn", "salt_gun": "Súng muối", "medal": "Huy chương mạ"}
var inventory: Array[String] = ["torch", "camera", "chalk", "chalk", "chalk", ""]
var selected_slot := 0
# selected_slot while nothing is in hand (item put away with its number key).
const EMPTY_HANDS := -1
var chalk_charging := false
var chalk_charge_time := 0.0
var chalk_charge_source := ""
# Compatibility for the decoy systems; all chalk is physically in the six slots.
var chalk: int:
	get:
		return inventory.count("chalk")
	set(value):
		for i in range(BAG_SIZE):
			if inventory[i] == "chalk":
				inventory[i] = ""
		for i in range(clampi(value, 0, BAG_SIZE)):
			add_item("chalk")
var combat: Node
var held_visual: Node3D
var holding_breath := false
var seized := false
var crank_charge := 100.0
var crank_on := false
var crank_kick := 0.0
var stamina_care := 1.0
var breath_exhausted := false
var sprint_exhausted := false
var noise_clock := 0.0
var breathing_clock := 0.0
var crouching := false
var crouch_blend := 0.0 # Eases the camera between standing (0) and crouched (1).
var lean := 0.0
var lean_offset := 0.0
var jump_held := false # Jump on the press only, not while Space stays down after a QTE.
var airborne_time := 0.0
@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight

func _ready() -> void:
	collision_mask = 5
	$Collision.shape = $Collision.shape.duplicate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	held_visual = preload("res://scripts/held_item.gd").new()
	held_visual.name = "HeldItem"
	held_visual.player = self
	camera.add_child(held_visual)
	flashlight.light_energy = TORCH_ENERGY
	combat = preload("res://scripts/player_combat.gd").new()
	combat.name = "Combat"
	add_child(combat)

func selected_item() -> String:
	# inventory[-1] would quietly return the last slot.
	return "" if selected_slot == EMPTY_HANDS else inventory[selected_slot]

func add_item(kind: String) -> bool:
	if not ITEM_NAMES.has(kind):
		return false
	if kind in ["torch", "crank", "camera"] and inventory.has(kind):
		return false
	var slot := inventory.find("")
	if slot < 0:
		return false
	inventory[slot] = kind
	return true

func select_slot(slot: int) -> void:
	if slot < EMPTY_HANDS or slot >= BAG_SIZE:
		return
	if slot != selected_slot:
		cancel_chalk_charge()
		flashlight.hide()
		saved_flashlight = false
		crank_on = false
	selected_slot = slot

# Number keys: pick a slot, or press the held slot's number again to put the
# item away. Only the keys toggle; select_slot() itself never puts things away,
# so F on an already-held torch still switches it on.
func press_slot(slot: int) -> void:
	if slot == selected_slot and not selected_item().is_empty():
		select_slot(EMPTY_HANDS)
	else:
		select_slot(slot)

func select_item(kind: String) -> bool:
	var slot := inventory.find(kind)
	if slot < 0:
		return false
	select_slot(slot)
	return true

func cycle_item(step: int) -> void:
	for offset in range(1, BAG_SIZE + 1):
		var slot := posmod(selected_slot + offset * step, BAG_SIZE)
		if not inventory[slot].is_empty():
			select_slot(slot)
			return

func can_use_item() -> bool:
	var world: Node3D = get_parent()
	return enabled and not seized and health > 0 and not combat.busy() and world.simulation_active() and not world.map_panel.visible and (world.soul_quest == null or not world.soul_quest.panel_visible()) and (world.progression == null or not world.progression.panel_visible() and not world.progression.controls_player())

func use_selected_item() -> bool:
	if not can_use_item():
		return false
	match selected_item():
		"torch":
			if is_hidden() or battery <= 0:
				return false
			flashlight.visible = not flashlight.visible
			get_parent().soundscape.cue("torch", -22)
			return true
		"crank":
			if is_hidden():
				return false
			crank_on = not crank_on
			flashlight.visible = crank_on and crank_charge > 0
			get_parent().soundscape.cue("torch", -22)
			return true
		"camera":
			return take_photo()
		"chalk":
			return begin_chalk_charge("mouse")
		"battery":
			if battery >= 100:
				get_parent().notify("Pin đang đầy")
				return false
			battery = minf(100, battery + BATTERY_RECHARGE)
		"medicine":
			if health >= 100:
				get_parent().notify("Chưa cần sơ cứu")
				return false
			health = minf(100, health + 30)
		_:
			return false
	inventory[selected_slot] = ""
	get_parent().soundscape.cue("pickup", -22)
	return true

func pump_crank() -> bool:
	if not can_use_item() or selected_item() != "crank" or is_hidden():
		return false
	crank_charge = minf(100.0, crank_charge + randi_range(CRANK_PUMP_MIN, CRANK_PUMP_MAX))
	crank_kick = 1.0
	if crank_on:
		flashlight.show()
	get_parent().soundscape.at("crank", global_position, -14)
	get_parent().emit_noise(global_position, CRANK_NOISE, "crank")
	return true

func take_photo() -> bool:
	if not can_use_item() or selected_item() != "camera" or is_hidden():
		return false
	if battery < PHOTO_COST:
		get_parent().notify("Máy ảnh cần 20% pin")
		return false
	if not get_parent().camera_flash.trigger():
		return false
	battery -= PHOTO_COST
	flashlight.hide()
	if get_parent().get("progression") != null:
		get_parent().progression.photo_taken()
	return true

func drop_selected_item() -> bool:
	if not can_use_item() or is_hidden() or selected_item().is_empty():
		return false
	# A floor ray keeps dropped items reachable and out of walls/closed doors.
	var forward := -global_basis.z
	var head := global_position + Vector3(0, 1.2, 0)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(head, head + forward * 0.8, 5)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var offset := forward * 0.65 if hit.is_empty() else Vector3.ZERO
	query.from = head + offset
	query.to = global_position + offset - Vector3.UP * 1.3
	hit = space.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.65:
		return false
	var item: Node3D = preload("res://scripts/survival_item.gd").new()
	item.world = get_parent()
	item.kind = selected_item()
	item.dropped = true
	item.position = hit.position + Vector3.UP * 0.16
	get_parent().survival.add_child(item)
	inventory[selected_slot] = ""
	cancel_chalk_charge()
	flashlight.hide()
	saved_flashlight = false
	get_parent().soundscape.cue("paper", -24)
	return true

# Things E picks up into the hand, as opposed to doors, hiding spots or people:
# only these play the grab.
func is_pickup(target: Node3D) -> bool:
	var script: Script = target.get_script()
	if script == preload("res://scripts/survival_item.gd"):
		return target.kind != "gate"
	if script == preload("res://scripts/night_story_interactable.gd"):
		return target.kind != "lan"
	return script in [preload("res://scripts/master_key.gd"), preload("res://scripts/soul_fragment.gd")]

func get_interaction_target() -> Node3D:
	if get_parent().get("progression") != null and get_parent().progression.controls_player():
		return null
	if get_parent().get("progression") != null and get_parent().progression.panel_visible():
		return null
	if not enabled or combat.busy():
		return null
	if is_hidden():
		return hidden_spot
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 2.6, 29)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var parent: Node = hit.collider.get_parent()
		if parent.has_method("interact"):
			return parent as Node3D
	return null

func get_door_target() -> Node3D:
	var target := get_interaction_target()
	return target if target != null and target.has_method("request_toggle") else null

func _unhandled_input(event: InputEvent) -> void:
	if get_parent().get("survival") == null:
		return
	if get_parent().get("progression") != null and get_parent().progression.controls_player():
		return
	if combat.busy():
		if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		return
	if get_parent().survival.opening.playing or get_parent().soul_quest != null and get_parent().soul_quest.panel_visible() or get_parent().progression != null and get_parent().progression.panel_visible():
		cancel_chalk_charge()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release_chalk_charge("mouse")
		return
	if event is InputEventKey and event.keycode == KEY_G and not event.pressed:
		release_chalk_charge("key")
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled and not seized:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		if is_hidden():
			var forward: float = hidden_spot.rotation.y + PI
			rotation.y = forward + clampf(wrapf(rotation.y - forward, -PI, PI), -0.65, 0.65)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_use_item():
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not held_visual.fire_finger_gun():
				use_selected_item()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_item().is_empty() and not is_hidden():
				held_visual.push_both_hands()
			else:
				pump_crank()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_item(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_item(1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_chalk_charge()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if can_use_item() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.keycode == KEY_1 and event.ctrl_pressed and not is_hidden():
				held_visual.toggle_finger_gun()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
				press_slot(event.keycode - KEY_1)
			if event.keycode == KEY_F and not is_hidden():
				if select_item("torch") or select_item("crank"):
					use_selected_item()
			if event.keycode == KEY_G:
				if select_item("chalk"):
					begin_chalk_charge("key")
			if event.keycode == KEY_Q:
				drop_selected_item()
		if event.keycode == KEY_E and not seized and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if not get_parent().simulation_active():
				return
			if is_hidden():
				end_hide()
				return
			var target := get_interaction_target()
			if target != null:
				var pickup := is_pickup(target)
				if target.interact(self) and pickup:
					held_visual.grab_with_right_hand()

func _physics_process(delta: float) -> void:
	tick_chalk_charge(delta)
	if not get_parent().simulation_active():
		velocity = Vector3.ZERO
		return
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if get_parent().progression != null and get_parent().progression.controls_player():
		# Scripted runs drive the camera and expect a standing capsule.
		lean = 0.0
		lean_offset = 0.0
		if crouching:
			set_crouching(false, true)
		get_parent().progression.tick_player(delta)
		return
	if seized:
		velocity = Vector3.ZERO
		return
	if health <= 0.0 or not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		return
	if combat.busy():
		invulnerable_time = maxf(invulnerable_time, 0.1)
		velocity.x = 0
		velocity.z = 0
		velocity.y = 0 if is_on_floor() else velocity.y - 18 * delta
		move_and_slide()
		return
	if is_hidden():
		velocity = Vector3.ZERO
		stamina = minf(MAX_STAMINA, stamina + 12 * delta)
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var moving := direction.length() > 0.0
	var quiet := Input.is_physical_key_pressed(KEY_CTRL)
	var wants_crouch := Input.is_physical_key_pressed(KEY_C)
	if wants_crouch != crouching and is_on_floor():
		set_crouching(wants_crouch)
	if stamina <= 1:
		sprint_exhausted = true
	if stamina > 22:
		sprint_exhausted = false
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and moving and not quiet and not crouching and not sprint_exhausted
	stamina = clampf(stamina + (-SPRINT_DRAIN * combat.sprint_multiplier() * stamina_care if running else 15.0 * (1 - fear * 0.005)) * delta, 0.0, MAX_STAMINA)
	var target := transform.basis * Vector3(direction.x, 0, direction.y).normalized()
	_tick_lean(delta)
	var speed := CROUCH_SPEED if crouching else (1.35 if quiet else (RUN_SPEED if running else WALK_SPEED))
	if absf(lean) > 0.2: speed = minf(speed, CROUCH_SPEED)
	speed *= test_speed_multiplier()
	velocity.x = move_toward(velocity.x, target.x * speed, delta * 18.0)
	velocity.z = move_toward(velocity.z, target.z * speed, delta * 18.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var jump_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	# Space holds the breath while the guard searches the stalls, so it must not jump too.
	var breath_beat: bool = get_parent().get("progression") != null and get_parent().progression.guard_part != null and get_parent().progression.guard_part.blocks_jump()
	if jump_pressed and not jump_held and is_on_floor() and not crouching and stamina >= JUMP_STAMINA and not breath_beat:
		velocity.y = JUMP_VELOCITY
		stamina -= JUMP_STAMINA
	jump_held = jump_pressed
	move_and_slide()
	if is_on_floor():
		# A real landing (not a stair step) is heard like a short sprint.
		if airborne_time > 0.2:
			get_parent().emit_noise(global_position, LANDING_NOISE, "steps")
			get_parent().soundscape.at("footstep", global_position, -20)
		airborne_time = 0.0
	else:
		airborne_time += delta
	noise_clock -= delta
	if moving and noise_clock <= 0:
		noise_clock = 0.28 if running else 0.5
		get_parent().emit_noise(global_position, movement_noise(running, quiet or crouching), "steps")
		if is_on_floor():
			get_parent().soundscape.at("footstep", global_position, -30 if quiet or crouching else (-18 if running else -25))
	step_time += delta * (10.0 if running else 6.0) if moving else 0.0
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * 6.0)
	# Follow actual ground speed so the bob fades in and out instead of snapping,
	# and stops in the air or when pressed against a wall.
	var bob_target := clampf(Vector2(velocity.x, velocity.z).length() / RUN_SPEED, 0.0, 1.0) if is_on_floor() else 0.0
	bob_amount = move_toward(bob_amount, bob_target, delta * 4.0)
	camera.position.y = lerpf(STAND_EYE, CROUCH_EYE, crouch_blend) - absf(sin(step_time)) * BOB_HEIGHT * bob_amount
	startle = maxf(0, startle - delta * 1.7)
	camera.position.x = sin(startle * 51) * startle * 0.015 + sin(step_time) * BOB_SWAY * bob_amount + lean_offset
	camera.rotation.z = -sin(step_time) * BOB_ROLL * bob_amount - lean * LEAN_ROLL
	camera.fov = lerpf(camera.fov, (79.0 if running else 73.0) + startle * 4 + (3.0 if combat.adrenaline_remaining > 0 else 0.0), delta * 5.0)

# Crouch or stand. Standing up needs headroom unless `force` (scripted moves).
func set_crouching(value: bool, force := false) -> bool:
	if not value and not force and not can_fit(global_position, STAND_HEIGHT):
		return false
	crouching = value
	var height := CROUCH_HEIGHT if value else STAND_HEIGHT
	$Collision.shape.height = height
	$Collision.position.y = height * 0.5 + 0.025
	if force:
		crouch_blend = 1.0 if value else 0.0
	return true

# Where a ghost looks to see the player: the chest, lower while crouched. Leaning out round
# cover, only the head shows, so that is what has to be seen.
func sight_point() -> Vector3:
	if absf(lean_offset) > 0.15:
		return camera.global_position - Vector3.UP * 0.08
	return global_position + Vector3.UP * (CROUCH_SIGHT if crouching else STAND_SIGHT)

func _tick_lean(delta: float) -> void:
	var wanted := 0.0
	if is_on_floor() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		wanted = float(Input.is_physical_key_pressed(KEY_X)) - float(Input.is_physical_key_pressed(KEY_Z))
	lean = move_toward(lean, wanted, delta * LEAN_SPEED)
	var reach := LEAN_REACH
	if absf(lean) > 0.01:
		# Never put the head through a wall.
		var from := global_position + Vector3.UP * (camera.position.y - 0.05)
		var query := PhysicsRayQueryParameters3D.create(from, from + global_basis.x * signf(lean) * (LEAN_REACH + 0.25), 1)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): reach = maxf(0.0, from.distance_to(hit.position) - 0.25)
	lean_offset = move_toward(lean_offset, lean * reach, delta * 3.0)

func is_hidden() -> bool:
	return is_instance_valid(hidden_spot)

func movement_noise(running: bool, quiet: bool) -> float:
	return 2.0 if quiet else (18.0 if running else 6.0)

func tick_survival(delta: float, wants_hold: bool) -> void:
	crank_kick = maxf(0.0, crank_kick - delta * 6.0)
	if selected_item() == "crank":
		_tick_crank(delta)
	elif flashlight.visible and not get_parent().progression.runner.active:
		flashlight.light_energy = TORCH_ENERGY
		battery = maxf(0, battery - delta * FLASHLIGHT_DRAIN)
		if battery <= 0:
			flashlight.hide()
			get_parent().notify("Đèn pin hết pin. Tìm pin dự phòng; tường và chỗ nấp vẫn nhìn được bằng ánh trăng.")
	if breath > 40:
		breath_exhausted = false
	holding_breath = is_hidden() and wants_hold and not breath_exhausted
	breath = clampf(breath + (-24.0 if holding_breath else 17.0) * delta, 0, 100)
	breathing_clock -= delta
	if holding_breath and breath <= 0:
		breath_exhausted = true
		holding_breath = false
		get_parent().emit_noise(global_position, 13, "cough")
		get_parent().survival.warn("Hết hơi · ho có thể lộ chỗ nấp. Thả SPACE để hồi hơi.", 3)
	elif is_hidden() and not holding_breath and fear > 35 and breathing_clock <= 0:
		breathing_clock = 1.25
		get_parent().emit_noise(global_position, 5 + fear * 0.045, "breath")

func _tick_crank(delta: float) -> void:
	if not flashlight.visible:
		return
	crank_charge = maxf(0.0, crank_charge - delta * CRANK_DRAIN)
	# A dying dynamo browns out before it quits, which is the cue to squeeze again.
	var strength := 1.0 if crank_charge >= CRANK_LOW else lerpf(0.35, 1.0, crank_charge / CRANK_LOW) * randf_range(0.8, 1.0)
	flashlight.light_energy = CRANK_ENERGY * strength
	if crank_charge <= 0.0:
		flashlight.hide()

func chalk_charge_fraction() -> float:
	return clampf(chalk_charge_time / CHALK_CHARGE_SECONDS, 0, 1)

func cancel_chalk_charge() -> void:
	chalk_charging = false
	chalk_charge_time = 0
	chalk_charge_source = ""

func begin_chalk_charge(source: String) -> bool:
	if get_parent().progression != null and get_parent().progression.tutorial_active():
		return false
	if chalk_charging or selected_item() != "chalk" or not can_use_item() or is_hidden() or not get_parent().night_hunt():
		return false
	chalk_charging = true
	chalk_charge_source = source
	chalk_charge_time = 0
	return true

func tick_chalk_charge(delta: float) -> void:
	if not chalk_charging:
		return
	if selected_item() != "chalk" or not can_use_item() or is_hidden() or not get_parent().night_hunt():
		cancel_chalk_charge()
		return
	chalk_charge_time = minf(CHALK_CHARGE_SECONDS, chalk_charge_time + delta)

func release_chalk_charge(source: String) -> bool:
	if not chalk_charging or source != chalk_charge_source:
		return false
	var charge := chalk_charge_fraction()
	cancel_chalk_charge()
	return throw_chalk(charge)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_chalk_charge()

func throw_chalk(charge := 0.0) -> bool:
	if get_parent().progression != null and get_parent().progression.tutorial_active():
		return false
	if chalk <= 0 or is_hidden() or not get_parent().night_hunt() or not can_use_item():
		return false
	var decoy: CharacterBody3D = preload("res://scripts/chalk_decoy.gd").new()
	decoy.world = get_parent()
	# Start at the camera; continuous motion resolves the first wall impact.
	decoy.position = camera.global_position
	var initial := -camera.global_basis.z * 10 + Vector3.UP * 2
	var multiplier := lerpf(1, CHALK_MAX_RANGE_MULTIPLIER, clampf(charge, 0, 1))
	# Keep the vertical arc/airtime at a given aim; horizontal reach grows up to 5x.
	decoy.velocity = Vector3(initial.x * multiplier, initial.y, initial.z * multiplier)
	get_parent().survival.add_child(decoy)
	var slot := selected_slot if selected_item() == "chalk" else inventory.find("chalk")
	inventory[slot] = ""
	cancel_chalk_charge()
	return true

func reset_survival() -> void:
	combat.reset()
	cancel_chalk_charge()
	if is_hidden():
		hidden_spot.release()
		hidden_spot = null
	global_position = Vector3(0, 0.05, 64)
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 73
	startle = 0
	set_crouching(false, true)
	jump_held = false
	airborne_time = 0.0
	bob_amount = 0.0
	velocity = Vector3.ZERO
	recover()
	stamina = MAX_STAMINA
	battery = 100
	crank_charge = 100.0
	crank_on = false
	flashlight.light_energy = TORCH_ENERGY
	fear = 0
	breath = 100
	inventory.assign(["torch", "camera", "chalk", "chalk", "chalk", ""])
	seized = false
	selected_slot = 0
	saved_flashlight = false
	get_parent().camera_flash.reset()
	breath_exhausted = false
	sprint_exhausted = false
	holding_breath = false
	breathing_clock = 0
	noise_clock = 0
	flashlight.show()
	invulnerable_time = 3

func can_fit(feet: Vector3, height := 1.75) -> bool:
	var capsule: CapsuleShape3D = $Collision.shape.duplicate()
	capsule.height = height - 0.04
	capsule.radius = 0.265
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 7
	query.exclude = [get_rid()]
	query.transform = Transform3D(Basis(), feet + Vector3(0, 0.36 if height < 1 else 0.9, 0))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func begin_hide(spot: Node3D) -> void:
	cancel_chalk_charge()
	lean = 0.0
	lean_offset = 0.0
	hidden_spot = spot
	# The spot sets its own capsule and eye height; leave the hiding place standing.
	crouching = false
	crouch_blend = 0.0
	bob_amount = 0.0
	saved_flashlight = flashlight.visible
	flashlight.hide()
	global_position = spot.hide_position()
	rotation.y = spot.rotation.y + PI
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0, spot.eye_height(), 0)
	camera.fov = 66
	$Collision.shape.height = spot.body_height()
	$Collision.position.y = 0.36 if spot.body_height() < 1.0 else 0.9
	velocity = Vector3.ZERO
	get_parent().soundscape.cue("paper", -26)

func end_hide() -> bool:
	if not is_hidden():
		return false
	for candidate in hidden_spot.exit_candidates():
		if not can_fit(candidate):
			continue
		global_position = candidate
		$Collision.shape.height = 1.75
		$Collision.position.y = 0.9
		camera.position = Vector3(0, 1.62, 0)
		camera.fov = 73
		flashlight.visible = saved_flashlight and (battery > 0 and selected_item() == "torch" or crank_charge > 0 and selected_item() == "crank")
		hidden_spot.release()
		hidden_spot = null
		velocity = Vector3.ZERO
		return true
	get_parent().notify("Lối ra đang bị chắn. Chờ một chút rồi nhấn E.")
	return false

func take_damage(amount: float, attacker: CharacterBody3D = null) -> bool:
	if test_invincible() or health <= 0 or invulnerable_time > 0:
		return false
	health = maxf(0, health - amount)
	invulnerable_time = 0.75
	damaged.emit(amount)
	if health <= 0:
		cancel_chalk_charge()
		enabled = false
		velocity = Vector3.ZERO
		combat.reset()
		died.emit()
	else:
		combat.record_hit(attacker)
	return true

func recover() -> void:
	combat.reset()
	health = 100.0
	invulnerable_time = 0.0
	enabled = true

func test_invincible() -> bool:
	var cheats: Node = get_parent().get("test_cheats")
	return cheats != null and cheats.enabled

func test_speed_multiplier() -> float:
	return 3.0 if test_invincible() else 1.0
