extends CharacterBody3D

const WALK_SPEED := 3.0
const RUN_SPEED := 5.2
const LOOK_SENSITIVITY := 0.0022
const MAX_STAMINA := 130.0
const FLASHLIGHT_DRAIN := 0.675
signal damaged(amount: float)
signal died
var health := 100.0
var invulnerable_time := 0.0
var stamina := MAX_STAMINA
var enabled := true
var step_time := 0.0
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
const ITEM_NAMES := {"torch": "Đèn pin", "camera": "Máy ảnh", "battery": "Pin", "medicine": "Sơ cứu", "chalk": "Phấn"}
var inventory: Array[String] = ["torch", "camera", "chalk", "chalk", "chalk", ""]
var selected_slot := 0
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
var breath_exhausted := false
var sprint_exhausted := false
var noise_clock := 0.0
var breathing_clock := 0.0
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
	combat = preload("res://scripts/player_combat.gd").new()
	combat.name = "Combat"
	add_child(combat)

func selected_item() -> String:
	return inventory[selected_slot]

func add_item(kind: String) -> bool:
	if not ITEM_NAMES.has(kind):
		return false
	if kind in ["torch", "camera"] and inventory.has(kind):
		return false
	var slot := inventory.find("")
	if slot < 0:
		return false
	inventory[slot] = kind
	return true

func select_slot(slot: int) -> void:
	if slot < 0 or slot >= BAG_SIZE:
		return
	if slot != selected_slot:
		cancel_chalk_charge()
		flashlight.hide()
		saved_flashlight = false
	selected_slot = slot

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
	return enabled and health > 0 and not combat.busy() and world.simulation_active() and not world.map_panel.visible and (world.soul_quest == null or not world.soul_quest.panel_visible()) and (world.progression == null or not world.progression.panel_visible())

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

func get_interaction_target() -> Node3D:
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		rotation.y -= event.relative.x * LOOK_SENSITIVITY
		if is_hidden():
			var forward: float = hidden_spot.rotation.y + PI
			rotation.y = forward + clampf(wrapf(rotation.y - forward, -PI, PI), -0.65, 0.65)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK_SENSITIVITY, -1.35, 1.35)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_use_item():
		if event.button_index == MOUSE_BUTTON_LEFT:
			use_selected_item()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_item(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_item(1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_chalk_charge()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		if can_use_item() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.keycode >= KEY_1 and event.keycode <= KEY_6:
				select_slot(event.keycode - KEY_1)
			if event.keycode == KEY_F and not is_hidden():
				if select_item("torch"):
					use_selected_item()
			if event.keycode == KEY_G:
				if select_item("chalk"):
					begin_chalk_charge("key")
			if event.keycode == KEY_Q:
				drop_selected_item()
		if event.keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if not get_parent().simulation_active():
				return
			if is_hidden():
				end_hide()
				return
			var target := get_interaction_target()
			if target != null:
				target.interact(self)

func _physics_process(delta: float) -> void:
	tick_chalk_charge(delta)
	if not get_parent().simulation_active():
		velocity = Vector3.ZERO
		return
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
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
	if stamina <= 1:
		sprint_exhausted = true
	if stamina > 22:
		sprint_exhausted = false
	var running := Input.is_physical_key_pressed(KEY_SHIFT) and moving and not quiet and not sprint_exhausted
	stamina = clampf(stamina + (-23.0 * combat.sprint_multiplier() if running else 15.0 * (1 - fear * 0.005)) * delta, 0.0, MAX_STAMINA)
	var target := transform.basis * Vector3(direction.x, 0, direction.y).normalized()
	var speed := 1.35 if quiet else (RUN_SPEED if running else WALK_SPEED)
	speed *= test_speed_multiplier()
	velocity.x = move_toward(velocity.x, target.x * speed, delta * 18.0)
	velocity.z = move_toward(velocity.z, target.z * speed, delta * 18.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	noise_clock -= delta
	if moving and noise_clock <= 0:
		noise_clock = 0.28 if running else 0.5
		get_parent().emit_noise(global_position, movement_noise(running, quiet), "steps")
		if is_on_floor():
			get_parent().soundscape.at("footstep", global_position, -30 if quiet else (-18 if running else -25))
	step_time += delta * (10.0 if running else 6.0) if moving else 0.0
	camera.position.y = 1.62 + sin(step_time) * (0.035 if moving else 0.0)
	startle = maxf(0, startle - delta * 1.7)
	camera.position.x = sin(startle * 51) * startle * 0.015
	camera.fov = lerpf(camera.fov, (79.0 if running else 73.0) + startle * 4 + (3.0 if combat.adrenaline_remaining > 0 else 0.0), delta * 5.0)

func is_hidden() -> bool:
	return is_instance_valid(hidden_spot)

func movement_noise(running: bool, quiet: bool) -> float:
	return 2.0 if quiet else (18.0 if running else 6.0)

func tick_survival(delta: float, wants_hold: bool) -> void:
	if flashlight.visible:
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

func chalk_charge_fraction() -> float:
	return clampf(chalk_charge_time / CHALK_CHARGE_SECONDS, 0, 1)

func cancel_chalk_charge() -> void:
	chalk_charging = false
	chalk_charge_time = 0
	chalk_charge_source = ""

func begin_chalk_charge(source: String) -> bool:
	if chalk_charging or selected_item() != "chalk" or not can_use_item() or is_hidden() or not get_parent().spirit_enabled:
		return false
	chalk_charging = true
	chalk_charge_source = source
	chalk_charge_time = 0
	return true

func tick_chalk_charge(delta: float) -> void:
	if not chalk_charging:
		return
	if selected_item() != "chalk" or not can_use_item() or is_hidden() or not get_parent().spirit_enabled:
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
	if chalk <= 0 or is_hidden() or not get_parent().spirit_enabled or not can_use_item():
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
	$Collision.shape.height = 1.75
	$Collision.position.y = 0.9
	velocity = Vector3.ZERO
	recover()
	stamina = MAX_STAMINA
	battery = 100
	fear = 0
	breath = 100
	inventory.assign(["torch", "camera", "chalk", "chalk", "chalk", ""])
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
	hidden_spot = spot
	saved_flashlight = flashlight.visible
	flashlight.hide()
	global_position = spot.hide_position()
	rotation.y = spot.rotation.y + PI
	camera.rotation = Vector3.ZERO
	camera.position = Vector3(0, 0.52 if spot.kind == 1 else 1.58, 0)
	camera.fov = 66
	$Collision.shape.height = 0.68 if spot.kind == 1 else 1.75
	$Collision.position.y = 0.36 if spot.kind == 1 else 0.9
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
		flashlight.visible = saved_flashlight and battery > 0 and selected_item() == "torch"
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
