extends Node
# Night 1's team: Peter and three friends against the guard. A catch is not a death: the guard
# drags the student to a locked room, where only a teammate can let them out.
# Each student has LIFE seconds. A catch takes CAPTURE_COST at once and the rest drains while
# locked up: rescued twice at most, a third catch is the end of anyone. Everyone caught at the same time loses.
enum Status { FREE, CARRIED, JAILED, OUT }
const STATUS_TEXT := ["Tự do", "Đang bị lôi đi", "Bị nhốt", "Bị loại"]
const LIFE := 600.0
const CAPTURE_COST := 200.0
const RESCUE_SECONDS := 3.0
# Grace after being let out, so the guard standing outside cannot take them straight back.
const FREED_GRACE := 3.0
const RESCUE_REACH := 2.0
# Being dragged off: A and D in turn fight the grip. The bar sinks on its own, so only a long
# haul (caught far from every locked room) and fast hands get anyone loose.
const STRUGGLE_PRESS := 0.015
const STRUGGLE_DECAY := 0.09
# A friend's struggle, net of the decay: about as good as a quick player.
const BOT_STRUGGLE := 0.04
# Every escape on the way makes the next one harder, until a locked room resets it.
const STRUGGLE_HARDER := 1.5
# The rooms he locks people in: one in each wing of A, two in B.
const JAIL_ROOMS := [101, 108, 1101, 1105]
const FRIENDS := [["Ba Rô", "Male_Child_01"], ["Huna", "Female_Child_01"], ["Bơ Tồ", "Male_Adult_08"]]
const BEACON_COLOR := Color(1.0, 0.42, 0.3)

class Member:
	var title := ""
	var body: CharacterBody3D
	var life := LIFE
	var status := Status.FREE
	var jail: Node3D
	var captures := 0
	var struggle := 0.0
	var last_key := 0
	var escapes := 0
	var layer := 1

var world: Node3D
var members: Array[Member] = []
var jails: Array[Node3D] = []
var rescue := {}
var beacons := {}
var lost := false
var panel: Control
var progress_label: Label
var spectate_camera: Camera3D
var spectating: Member
var player_rescuing: Node3D

func setup(school: Node3D) -> void:
	world = school
	name = "HuntTeam"
	for door in world.get_tree().get_nodes_in_group("classroom_doors"):
		if int(door.get_meta("room_number", 0)) in JAIL_ROOMS:
			jails.append(door)
	var me := Member.new()
	me.title = "Bạn"
	me.body = world.player
	members.append(me)
	var spawn: Vector3 = world.player.global_position
	for i in range(FRIENDS.size()):
		var bot: CharacterBody3D = preload("res://scripts/teammate_bot.gd").new()
		bot.world = world
		bot.team = self
		bot.title = FRIENDS[i][0]
		bot.look = FRIENDS[i][1]
		bot.name = "Teammate%d" % i
		world.add_child(bot)
		# Beside the player on the open side of the gate, never inside the booth west of it.
		var map: RID = world.get_world_3d().navigation_map
		bot.global_position = NavigationServer3D.map_get_closest_point(map, spawn + Vector3(1.6 + i * 1.3, 0, -1.5 - (i % 2) * 0.8)) + Vector3.UP * 0.05
		var friend := Member.new()
		friend.title = FRIENDS[i][0]
		friend.body = bot
		members.append(friend)
	var ui: Control = world.get_node("HUD").get_child(0)
	panel = preload("res://scripts/hunt_team_panel.gd").new()
	panel.team = self
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)

func member(body: Node) -> Member:
	for entry in members:
		if entry.body == body:
			return entry
	return null

func is_free(body: Node) -> bool:
	var entry := member(body)
	return entry != null and entry.status == Status.FREE

func free_bodies() -> Array:
	var found := []
	for entry in members:
		if entry.status == Status.FREE:
			found.append(entry.body)
	return found

func standing() -> int:
	return members.filter(func(entry): return entry.status == Status.FREE).size()

func remaining() -> int:
	return members.filter(func(entry): return entry.status != Status.OUT).size()

# The locked room a short walk from where he caught them.
func jail_for(from: Vector3) -> Node3D:
	var map: RID = world.get_world_3d().navigation_map
	var best: Node3D = jails[0]
	var shortest := INF
	for door in jails:
		var path := NavigationServer3D.map_get_path(map, from, inside(door), true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if path.size() > 1 and length < shortest:
			shortest = length
			best = door
	return best

func _broke_free(entry: Member) -> bool:
	if entry.status != Status.CARRIED or entry.struggle < 1.0:
		return false
	entry.struggle = 0.0
	entry.escapes += 1
	world.envy.demon.break_free()
	world.notify("Bạn vùng thoát khỏi tay bác bảo vệ · Chạy!" if entry.body == world.player else "%s vùng thoát được!" % entry.title)
	return true

# How much harder this student's struggle is after escaping him already.
func grip(entry: Member) -> float:
	return pow(STRUGGLE_HARDER, entry.escapes)

func _swing(door: Node3D) -> float:
	return float(door.get_meta("swing_side", 1.0))

func inside(door: Node3D, slot := 0) -> Vector3:
	return door.to_global(Vector3((slot - 1.5) * 0.8, 0.05, _swing(door) * 3.2))

func outside(door: Node3D) -> Vector3:
	return door.to_global(Vector3(0, 0.05, -_swing(door) * 1.3))

# Where a friend can actually stand to work the lock: the walkable point nearest the door's outside.
func rescue_spot(door: Node3D) -> Vector3:
	return NavigationServer3D.map_get_closest_point(world.get_world_3d().navigation_map, outside(door))

func prisoners(door: Node3D) -> Array[Member]:
	var found: Array[Member] = []
	for entry in members:
		if entry.status == Status.JAILED and entry.jail == door:
			found.append(entry)
	return found

func door_jailed(number: int) -> bool:
	for door in jails:
		if int(door.get_meta("room_number", 0)) == number and not prisoners(door).is_empty():
			return true
	return false

func seize(body: Node) -> void:
	var entry := member(body)
	if entry == null:
		return
	entry.status = Status.CARRIED
	entry.captures += 1
	entry.struggle = 0.0
	entry.last_key = 0
	body.set("captive", true)
	# Caught: the chase is over, and so is its fatigue.
	body.set("fatigue", 0.0)
	if body == world.player:
		world.notify("Bác bảo vệ tóm được bạn · Chờ đồng đội cứu")
	else:
		world.notify("%s bị bác bảo vệ tóm!" % entry.title)
	_check_wipe()

func imprison(body: Node, door: Node3D) -> void:
	var entry := member(body)
	if entry == null or entry.status != Status.CARRIED:
		return
	entry.life -= CAPTURE_COST
	if entry.life <= 0.0:
		_eliminate(entry)
		return
	entry.status = Status.JAILED
	entry.jail = door
	entry.escapes = 0
	body.global_position = inside(door, prisoners(door).size())
	body.velocity = Vector3.ZERO
	body.set("captive", true)
	# The player may pace the room; only the locked door keeps them in. Nobody can be used to
	# wedge the guard in, so they pass through each other.
	if body == world.player:
		body.seized = false
		body.set("captive", false)
		entry.layer = body.collision_layer
		body.collision_layer = 0
	var room: String = door.room_label.replace("\n", " ")
	world.notify(("Bạn bị nhốt trong %s · Còn %d giây" % [room, int(entry.life)]) if body == world.player else ("%s bị nhốt trong %s · Đi cứu!" % [entry.title, room]))
	_update_beacon(door)
	_check_wipe()

# He dropped them or they broke free on the way: back on their feet where they are.
func release(body: Node) -> void:
	var entry := member(body)
	if entry != null and entry.status == Status.CARRIED:
		entry.status = Status.FREE
		body.set("captive", false)

func work_rescue(door: Node3D, rescuer: Node, delta: float) -> bool:
	if prisoners(door).is_empty() or not is_free(rescuer):
		return false
	rescue[door] = float(rescue.get(door, 0.0)) + delta
	if rescue[door] >= RESCUE_SECONDS:
		_free_jail(door, rescuer)
		return true
	return false

func rescue_fraction(door: Node3D) -> float:
	return clampf(float(rescue.get(door, 0.0)) / RESCUE_SECONDS, 0.0, 1.0)

func _free_jail(door: Node3D, rescuer: Node) -> void:
	rescue[door] = 0.0
	var names := []
	for entry in prisoners(door):
		entry.status = Status.FREE
		entry.jail = null
		entry.body.seized = false
		entry.body.set("captive", false)
		entry.body.invulnerable_time = FREED_GRACE
		if entry.body == world.player:
			entry.body.collision_layer = entry.layer
		names.append("bạn" if entry.body == world.player else entry.title)
	door.snap(true)
	_update_beacon(door)
	var who: String = "Bạn" if rescuer == world.player else member(rescuer).title
	world.notify("%s đã mở khóa cứu %s · Chạy!" % [who, ", ".join(names)])

func _eliminate(entry: Member) -> void:
	var door := entry.jail
	entry.status = Status.OUT
	entry.jail = null
	entry.life = 0.0
	entry.body.seized = true
	entry.body.hide()
	entry.body.collision_layer = 0
	entry.body.collision_mask = 0
	entry.body.global_position = Vector3(0, -50, 0)
	if door != null:
		_update_beacon(door)
	if entry.body == world.player:
		world.player.flashlight.hide()
		world.notify("Bạn đã bị loại · Xem đồng đội · TAB đổi người")
		_spectate_next()
	else:
		world.notify("%s đã bị loại" % entry.title)
	_check_wipe()

func _check_wipe() -> void:
	if lost or standing() > 0:
		return
	lost = true
	world.survival.team_lost()

func _update_beacon(door: Node3D) -> void:
	var held := prisoners(door)
	if held.is_empty():
		if beacons.has(door):
			beacons[door].queue_free()
			beacons.erase(door)
		return
	if not beacons.has(door):
		var beacon := Label3D.new()
		beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon.no_depth_test = true
		beacon.fixed_size = true
		beacon.pixel_size = 0.0011
		beacon.font_size = 30
		beacon.outline_size = 10
		beacon.modulate = BEACON_COLOR
		beacon.outline_modulate = Color(0, 0, 0, 0.85)
		world.add_child(beacon)
		beacon.global_position = outside(door) + Vector3.UP * 2.6
		beacons[door] = beacon

func _physics_process(delta: float) -> void:
	if world == null or lost or world.survival.finished:
		return
	if not world.simulation_active() and not _player_captive():
		return
	for entry in members:
		if entry.status == Status.CARRIED:
			if entry.body != world.player:
				entry.struggle += (BOT_STRUGGLE + STRUGGLE_DECAY) / grip(entry) * delta
			if not _broke_free(entry):
				entry.struggle = maxf(0.0, entry.struggle - STRUGGLE_DECAY * delta)
		if entry.status == Status.JAILED:
			entry.life -= delta
			if entry.life <= 0.0:
				_eliminate(entry)
	for door in jails:
		if prisoners(door).is_empty():
			continue
		# He locks up behind himself once the doorway is clear.
		var guard: Node3D = world.envy.demon
		if door.is_open and guard.global_position.distance_to(door.global_position) > 2.0 and guard.global_position.distance_to(inside(door)) > 3.6:
			door.set_open(false)
		var beacon: Label3D = beacons.get(door)
		if beacon != null:
			# Locked in that room yourself, its marker would only hang in front of your face.
			beacon.visible = member(world.player).jail != door
			var titles := prisoners(door).map(func(entry): return "BẠN" if entry.body == world.player else entry.title)
			beacon.text = "⚠ %s · %d m" % [" · ".join(titles), int(world.player.global_position.distance_to(door.global_position))]
	_keep_in_room()
	_tick_player_rescue(delta)
	_tick_spectate()

# Locked in, the player walks about the room but never out through its doorway, even while
# the door still stands open behind the guard.
func _keep_in_room() -> void:
	var me := member(world.player)
	if me == null or me.status != Status.JAILED:
		return
	var door := me.jail
	var local: Vector3 = door.to_local(world.player.global_position)
	var swing := _swing(door)
	if local.z * swing < 0.45 and absf(local.x) < 1.6:
		local.z = swing * 0.45
		world.player.global_position = door.to_global(local)
		world.player.velocity = Vector3.ZERO

func _player_captive() -> bool:
	var me := member(world.player)
	return me != null and me.status != Status.FREE and not world.paused_by_user

# The nearest free friend goes for a locked room, once the guard has left it.
func rescue_job_for(bot: Node3D) -> Node3D:
	var demon: Node3D = world.envy.demon if world.envy != null else null
	var best: Node3D = null
	var best_gap := INF
	for door in jails:
		if prisoners(door).is_empty():
			continue
		if demon != null and demon.global_position.distance_to(door.global_position) < 14.0:
			continue
		var nearest: Node3D = null
		var gap := INF
		for entry in members:
			if entry.status == Status.FREE and entry.body != world.player:
				var d: float = entry.body.global_position.distance_to(door.global_position)
				if d < gap:
					gap = d
					nearest = entry.body
		if nearest == bot and gap < best_gap:
			best = door
			best_gap = gap
	return best

func rescue_door_near(feet: Vector3) -> Node3D:
	for door in jails:
		if not prisoners(door).is_empty() and Vector2(feet.x - outside(door).x, feet.z - outside(door).z).length() < RESCUE_REACH and absf(feet.y - door.global_position.y) < 1.5:
			return door
	return null

# Hold E outside a locked room to let everyone in it out.
func _tick_player_rescue(delta: float) -> void:
	player_rescuing = null
	if not is_free(world.player) or world.player.is_hidden():
		return
	var door := rescue_door_near(world.player.global_position)
	if door == null:
		return
	if Input.is_physical_key_pressed(KEY_E):
		player_rescuing = door
		if not work_rescue(door, world.player, delta):
			world.emit_noise(world.player.global_position, 6.0, "lock")
	else:
		rescue[door] = maxf(0.0, float(rescue.get(door, 0.0)) - delta)

func prompt() -> String:
	var door := rescue_door_near(world.player.global_position) if is_free(world.player) else null
	if door == null:
		return ""
	var titles := prisoners(door).map(func(entry): return entry.title)
	return "Giữ E · Mở khóa cứu %s" % ", ".join(titles)

func _spectate_next() -> void:
	var start := members.find(spectating)
	for step in range(1, members.size() + 1):
		var entry: Member = members[(start + step) % members.size()]
		if entry.body != world.player and entry.status != Status.OUT:
			spectating = entry
			break
	if spectate_camera == null:
		spectate_camera = Camera3D.new()
		spectate_camera.fov = 70
		world.add_child(spectate_camera)
	spectate_camera.current = true

func _tick_spectate() -> void:
	if spectate_camera == null:
		return
	if spectating == null or spectating.status == Status.OUT:
		_spectate_next()
		if spectating == null:
			return
	var body: Node3D = spectating.body
	var behind: Vector3 = body.global_basis.z * 3.2 + Vector3.UP * 2.1
	spectate_camera.global_position = spectate_camera.global_position.lerp(body.global_position + behind, 0.12)
	spectate_camera.look_at(body.global_position + Vector3.UP * 1.3)

func _unhandled_key_input(event: InputEvent) -> void:
	var me := member(world.player)
	if me != null and me.status == Status.CARRIED and event.pressed and not event.echo and event.physical_keycode in [KEY_A, KEY_D]:
		# Only A then D then A counts: holding or hammering one key does nothing.
		if event.physical_keycode != me.last_key:
			me.struggle = minf(1.0, me.struggle + STRUGGLE_PRESS / grip(me))
			_broke_free(me)
			me.last_key = event.physical_keycode
		get_viewport().set_input_as_handled()
		return
	if spectate_camera != null and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_spectate_next()
