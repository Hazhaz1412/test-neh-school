extends CharacterBody3D
const Gear := preload("res://scripts/night_gear.gd")
# AI B, the demon. It holds no reference to where anyone is: it knows only what it sees, what
# it hears and the areas the director whispers. It searches rooms and hiding places itself.
enum State {ROAM, SWEEP, LISTEN, CHASE, STRIKE, REST, GRAB, STAGGER, ADMIRE}
const NAMES := {State.ROAM: "đi lang thang", State.SWEEP: "tự lục soát", State.LISTEN: "nghe trước chỗ trốn", State.CHASE: "đuổi", State.STRIKE: "vồ", State.REST: "bị gọi lui", State.GRAB: "chụp người chơi", State.STAGGER: "đau, mất dấu", State.ADMIRE: "ngắm chiến lợi phẩm"}
const STALK_SPEED := 3.6
const SEARCH_SPEED := 3.2
const CHASE_SPEED := 4.9
# A long chase winds it up until a sprint alone no longer outruns it.
const RAGE_SPEED := 5.75
const RAGE_SECONDS := 7.0
const POUNCE_REACH := 6.0
const POUNCE_SPEED := 8.0
const POUNCE_SECONDS := 0.6
const POUNCE_REST := 5.0
const SIGHT_RANGE := 26.0
const TORCH_SIGHT_RANGE := 38.0
const SIGHT_CONE := 0.3
const SENSE_ALWAYS := 2.6
const NOTICE_SECONDS := 0.2
const LOSE_SECONDS := 3.5
# For a moment after losing sight it still follows the footsteps.
const TRACK_SECONDS := 1.2
const LISTEN_SECONDS := 2.2
const YANK_SECONDS := 0.4
const LOST_RADIUS := 14.0
const SUSPECT_LIMIT := 4
const HIDER_EYE := 0.3
const SEARCH_EYE := 1.7
const BEHIND_WALL := 2.0
const COVER_DEPTH := 0.8
const HIDER_CLEARANCE := 1.6
const PREDICT_SECONDS := 1.0
const PREDICT_TRUST := 1.5
const LOOK_SECONDS := 1.5
const STRIKE_REACH := 1.9
const GRAB_SECONDS := 1.3
const GRAB_ARMED_SECONDS := 2.6
# The guard grabs the student by the collar at his own height, not up to a mouth.
const LIFT := 0.0
const HOLD_REACH := 0.75
const STAGGER_SECONDS := 3.0
const ADMIRE_SECONDS := 4.0
const LUNGE_SPEED := 6.5
const LOW_EYE := 1.3
const BLIND_SECONDS := 10.0
const THROW_REACH := 3.5
const ESCAPE_GRACE := 2.0
const MOUTH_PITCH := 0.12
const FORGET_SECONDS := 45.0
const STRIDE := 0.78
const RUN_STRIDE := 1.55
const EYE := 1.6
const STOOP := 0.64
const SHAKE_RANGE := 24.0
const STEP_LOUD := 0.0
const WALLS_DB := 9.0
const FLOOR_DB := 8.0
var world: Node3D
var director: Node
var player: CharacterBody3D
var state := State.ROAM
var area := Vector3.ZERO
var area_radius := 0.0
var has_area := false
var goal: Node3D
var goal_is_spot := false
var checked := {}
var last_seen := Vector3.ZERO
var witnessed: Node3D
var notice := 0.0
var unseen := 0.0
var wait := 0.0
var rest_left := 0.0
var sense_clock := 0.0
var door_clock := 0.0
var stride_left := STRIDE
var stuck_clock := 0.0
var stuck_from := Vector3.ZERO
var shake := 0.0
var stolen: Array[String] = []
var model: Node3D
var agent: NavigationAgent3D
var step_sound: AudioStreamPlayer3D
var clink_sound: AudioStreamPlayer3D
var rattle_sound: AudioStreamPlayer3D
var roar_sound: AudioStreamPlayer3D
var roam_point := Vector3.ZERO
var area_mark: Node3D
var pin_from := Vector3.ZERO
var pin_clock := 0.0
var area_visited := false
var grab_from := Vector3.ZERO
var grab_clock := 0.0
var armed := false
var certain := false
var suspects: Array[Node3D] = []
var chase_time := 0.0
var pounce_left := 0.0
var pounce_clock := 0.0
var shot_sound: AudioStreamPlayer3D
var shout: Label

func _ready() -> void:
	player = world.player
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.98
	add_child(shape)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.8
	agent.path_height_offset = 0.25
	add_child(agent)
	model = preload("res://scripts/guard_hunter_model.gd").new()
	model.rotation.y = PI
	add_child(model)
	step_sound = _voice("res://assets/audio/footstep.wav", STEP_LOUD, 46.0, 6.0)
	step_sound.stream = preload("res://scripts/security_guard.gd").shoe_steps()
	clink_sound = _voice("res://assets/audio/guard_keys.wav", -12.0, 22.0, 5.0)
	rattle_sound = _voice("res://assets/audio/envy_rattle.wav", -3.0, 26.0, 6.0)
	roar_sound = _voice("res://assets/audio/guard_whistle.wav", 0.0, 60.0, 12.0)
	shot_sound = _voice("res://assets/audio/door_bang.wav", 6.0, 40.0, 8.0)
	var layer := CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	shout = Label.new()
	shout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	shout.offset_left = -500
	shout.offset_right = 500
	shout.offset_top = -230
	shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shout.add_theme_font_size_override("font_size", 44)
	preload("res://scripts/horror_type.gd").title(shout)
	shout.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	shout.add_theme_color_override("font_outline_color", Color.BLACK)
	shout.add_theme_constant_override("outline_size", 8)
	layer.add_child(shout)
	roam_point = global_position
	area_mark = Node3D.new()
	world.add_child(area_mark)
	step_sound.panning_strength = 1.6
	step_sound.attenuation_filter_cutoff_hz = 900.0
	step_sound.attenuation_filter_db = -30.0

func _voice(path: String, volume: float, reach: float, size: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(path)
	sound.volume_db = volume
	sound.max_distance = reach
	sound.unit_size = size
	sound.pitch_scale = 1.0
	sound.position.y = 1.0
	add_child(sound)
	return sound

func state_name() -> String:
	return NAMES[state]

func is_hunting() -> bool:
	return state in [State.CHASE, State.STRIKE, State.GRAB]

func is_resting() -> bool:
	return state in [State.REST, State.STAGGER, State.ADMIRE]

# The only way the director can reach the demon.
func whisper(centre: Vector3, radius: float) -> void:
	if centre.distance_to(area) > radius * 0.5 or not has_area:
		area_visited = false
	area = centre
	area_radius = radius
	has_area = true
	if state == State.ROAM:
		_next_search()

func hear(heard_at: Vector3, radius: float, source: String) -> void:
	if is_hunting() or is_resting() or global_position.distance_to(heard_at) > radius * 1.25:
		return
	if source == "breath" and global_position.distance_to(heard_at) > 4.0:
		return
	if state != State.LISTEN:
		whisper(heard_at, 5.0)
		_next_search()

# Seen climbing in: that spot is no longer a guess, and nothing else matters now.
func witness(spot: Node3D) -> void:
	if state != State.GRAB and not is_resting() and _can_see_player(false):
		_saw_hiding(spot)

func _saw_hiding(spot: Node3D) -> void:
	witnessed = spot
	roar_sound.play()
	_next_search()

func fall_back(point: Vector3, seconds: float) -> void:
	state = State.REST
	rest_left = seconds
	_forget()
	agent.target_position = point

func _forget() -> void:
	goal = null
	witnessed = null
	certain = false
	suspects.clear()
	has_area = false

func _player_exposed() -> bool:
	return not player.is_hidden() and not world.is_soul_sanctuary(player.global_position)

func _can_see_player(use_cone := true) -> bool:
	var eye := global_position + Vector3.UP * EYE
	var chest: Vector3 = player.sight_point()
	var offset := chest - eye
	var reach := TORCH_SIGHT_RANGE if player.flashlight.visible else SIGHT_RANGE
	if offset.length() > reach:
		return false
	var facing := -global_basis.z
	if use_cone and offset.length() > SENSE_ALWAYS and facing.dot(offset.normalized()) < SIGHT_CONE:
		return false
	# It towers over door frames, so a second look from chest height sees under them.
	for height in [eye, global_position + Vector3.UP * LOW_EYE]:
		var ray := PhysicsRayQueryParameters3D.create(height, chest, 5)
		ray.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider == player:
			return true
	return false

func _sense(delta: float) -> void:
	# While it rests, stumbles or gloats it notices nobody: that is the player's head start.
	if state == State.GRAB or is_resting():
		return
	sense_clock -= delta
	if sense_clock > 0.0:
		return
	sense_clock = 0.15
	var sees := _player_exposed() and _can_see_player()
	if sees:
		last_seen = player.global_position
		unseen = 0.0
		notice += 0.15
		if notice >= NOTICE_SECONDS and not is_hunting():
			state = State.CHASE
			chase_time = 0.0
			certain = false
			roar_sound.play()
			world.notify("ĐỨNG LẠI! · Bác bảo vệ thấy bạn rồi")
	elif not certain and _glimpses_hider():
		notice += 0.15
		if notice >= NOTICE_SECONDS:
			notice = 0.0
			_saw_hiding(player.hidden_spot)
	else:
		notice = maxf(0.0, notice - 0.15)
		if state == State.CHASE:
			unseen += 0.15

# A desk hides nobody from anything standing close, a cot only from what does not bend down.
func _glimpses_hider() -> bool:
	var spot: Node3D = player.hidden_spot
	if spot == null or spot.seen_from() <= 0.0:
		return false
	var offset: Vector3 = spot.global_position - global_position
	if offset.length() > spot.seen_from():
		return false
	if offset.length() > SENSE_ALWAYS and -global_basis.z.dot(offset.normalized()) < SIGHT_CONE:
		return false
	var low: Vector3 = spot.global_position + Vector3.UP * HIDER_EYE
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * LOW_EYE, low, 1)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to(low) < HIDER_CLEARANCE

# How far it really is on foot. A locker behind a wall may be close, but it is not near.
func _walk_distance(from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, from, to, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length if path.size() > 1 else INF

# No wall between them: the room they vanished in gets emptied before the corridor outside.
func _same_space(from: Vector3, spot: Node3D) -> bool:
	var target: Vector3 = spot.global_position + Vector3.UP * SEARCH_EYE
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * SEARCH_EYE, target, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or spot.is_ancestor_of(hit.collider) or hit.position.distance_to(target) < COVER_DEPTH

# Lost them: the hiding places a short walk from the last sighting come first, checked or not.
func _lost_sight() -> void:
	area = last_seen
	area_radius = LOST_RADIUS
	has_area = true
	area_visited = false
	var ranked := []
	for spot in _spots_nearby():
		var walk := _walk_distance(last_seen, spot.approach_position())
		ranked.append([walk if _same_space(last_seen, spot) else walk * BEHIND_WALL, spot])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	suspects.clear()
	for entry in ranked.slice(0, SUSPECT_LIMIT):
		suspects.append(entry[1])
	_next_search()

func _spots_nearby() -> Array:
	var found := []
	for spot in get_tree().get_nodes_in_group("hiding_spots"):
		if spot.visible and _in_area(spot.global_position):
			found.append(spot)
	return found

func _in_area(point: Vector3) -> bool:
	return absf(point.y - area.y) < 2.6 and Vector2(point.x - area.x, point.z - area.z).length() < area_radius

func _fresh(place: Node3D) -> bool:
	return Time.get_ticks_msec() - checked.get(place, -1000000.0) > FORGET_SECONDS * 1000.0 / Engine.time_scale

# Nearest unchecked hiding place or classroom in the suspected area. Neither is chosen by
# whether anyone is there; that would be cheating.
func _next_search() -> void:
	certain = false
	if witnessed != null:
		goal = witnessed
		goal_is_spot = true
		witnessed = null
		certain = true
		suspects.clear()
		_head_for(goal)
		return
	if not suspects.is_empty():
		goal = suspects.pop_front()
		goal_is_spot = true
		_head_for(goal)
		return
	var places := []
	if has_area:
		for spot in _spots_nearby():
			if _fresh(spot):
				places.append([spot, true])
		for door in get_tree().get_nodes_in_group("classroom_doors"):
			if _in_area(door.global_position) and _fresh(door) and not door.is_locked():
				places.append([door, false])
	var best := INF
	goal = null
	for place in places:
		var target: Vector3 = place[0].approach_position() if place[1] else place[0].global_position
		var distance: float = _walk_distance(global_position, target) * randf_range(0.9, 1.1)
		if distance < best:
			best = distance
			goal = place[0]
			goal_is_spot = place[1]
	# Nothing to open here: it still goes and looks, an empty corridor hides nobody.
	if goal == null and has_area and not area_visited:
		area_visited = true
		area_mark.global_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, area)
		goal = area_mark
		goal_is_spot = false
	if goal == null:
		has_area = false
		state = State.ROAM
		agent.target_position = _prowl_point()
		return
	_head_for(goal)

# Between hints it lingers around the last suspicion instead of crossing the school.
func _prowl_point() -> Vector3:
	var route: Array = world.campus_patrol_route(0)
	route.sort_custom(func(a, b): return a.distance_squared_to(area) < b.distance_squared_to(area))
	var map: RID = get_world_3d().navigation_map
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(4.0, 12.0)
	var near_area := NavigationServer3D.map_get_closest_point(map, area + Vector3(offset.x, 0, offset.y))
	return near_area if absf(near_area.y - area.y) < 1.5 else route[randi() % mini(4, route.size())]

func _head_for(place: Node3D) -> void:
	state = State.SWEEP
	stuck_clock = 0.0
	stuck_from = global_position
	agent.target_position = place.approach_position() if goal_is_spot else place.global_position

func _physics_process(delta: float) -> void:
	if not world.simulation_active():
		return
	_sense(delta)
	match state:
		State.ROAM:
			_walk(STALK_SPEED, delta)
			if agent.is_navigation_finished():
				_next_search()
		State.SWEEP:
			_sweep(delta)
		State.LISTEN:
			_listen(delta)
		State.CHASE:
			_chase(delta)
		State.STRIKE:
			_strike(delta)
		State.GRAB:
			_hold(delta)
		State.STAGGER:
			_stagger(delta)
		State.ADMIRE:
			_admire(delta)
		State.REST:
			rest_left -= delta
			_walk(STALK_SPEED, delta)
			if rest_left <= 0.0:
				state = State.ROAM
				_next_search()
	_open_doors(delta)
	_stoop(delta)

func _sweep(delta: float) -> void:
	if goal == null:
		_next_search()
		return
	if wait > 0.0:
		wait -= delta
		rotate_y(sin(wait * 3.0) * delta * 1.6)
		model.move("idle", 1.0)
		if wait <= 0.0:
			checked[goal] = Time.get_ticks_msec()
			_next_search()
		return
	_walk(CHASE_SPEED if certain else SEARCH_SPEED, delta)
	stuck_clock += delta
	if stuck_clock > 3.0:
		if global_position.distance_to(stuck_from) < 0.6:
			checked[goal] = Time.get_ticks_msec()
			_next_search()
			return
		stuck_clock = 0.0
		stuck_from = global_position
	if agent.is_navigation_finished():
		if goal_is_spot:
			state = State.LISTEN
			wait = YANK_SECONDS if certain else LISTEN_SECONDS
			rattle_sound.play()
			model.move("idle", 0.6)
		else:
			wait = LOOK_SECONDS

# It stands at the locker and listens. A held breath fools it, unless it saw you climb in.
func _listen(delta: float) -> void:
	wait -= delta
	var face: Vector3 = goal.global_position - global_position
	if Vector2(face.x, face.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-6.0 * delta))
	if wait > 0.0:
		return
	var hider: CharacterBody3D = goal.occupant
	checked[goal] = Time.get_ticks_msec()
	if hider != null and (certain or not hider.holding_breath):
		certain = false
		hider.end_hide()
		last_seen = hider.global_position
		state = State.CHASE
		chase_time = 0.0
		unseen = 0.0
		roar_sound.play()
		return
	_next_search()

func _chase(delta: float) -> void:
	chase_time += delta
	pounce_clock -= delta
	pounce_left -= delta
	if unseen <= TRACK_SECONDS:
		last_seen = player.global_position
	agent.target_position = _intercept() if unseen <= 0.0 else last_seen
	var gap: float = global_position.distance_to(player.global_position)
	if unseen <= 0.0 and pounce_clock <= 0.0 and gap < POUNCE_REACH and gap > STRIKE_REACH:
		pounce_clock = POUNCE_REST
		pounce_left = POUNCE_SECONDS
		roar_sound.play()
	var speed := lerpf(CHASE_SPEED, RAGE_SPEED, clampf(chase_time / RAGE_SECONDS, 0.0, 1.0))
	_walk(POUNCE_SPEED if pounce_left > 0.0 else speed, delta)
	if _player_exposed() and gap < STRIKE_REACH:
		state = State.STRIKE
		wait = 0.45
		model.move("idle", 1.4)
		return
	if unseen > LOSE_SECONDS:
		_lost_sight()

# Runs for where the prey is going, unless that is somewhere it could not walk to.
func _intercept() -> Vector3:
	var ahead: Vector3 = player.global_position + player.velocity * Vector3(1, 0, 1) * minf(global_position.distance_to(player.global_position) / CHASE_SPEED, PREDICT_SECONDS)
	var walkable := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, ahead)
	return walkable if walkable.distance_to(ahead) < PREDICT_TRUST else player.global_position

# The reach is a lunge, not a pause: stepping backwards must not outrun the wind-up.
func _strike(delta: float) -> void:
	wait -= delta
	var flat := player.global_position - global_position
	flat.y = 0.0
	if flat.length() > 0.9:
		velocity = flat.normalized() * LUNGE_SPEED
		velocity.y = -0.5
		move_and_slide()
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-12.0 * delta))
	if wait > 0.0:
		return
	if _player_exposed() and global_position.distance_to(player.global_position) < STRIKE_REACH + 0.6 and not player.test_invincible():
		_seize()
	else:
		state = State.CHASE

# Every catch is a grab: the player hangs in front of its mouth while the choice runs out.
func _seize() -> void:
	state = State.GRAB
	armed = player.inventory.has("salt_gun")
	wait = GRAB_ARMED_SECONDS if armed else GRAB_SECONDS
	grab_clock = 0.0
	grab_from = player.global_position
	player.seized = true
	player.cancel_chalk_charge()
	player.flashlight.hide()
	roar_sound.play()
	world.progression.fear.beat()
	shout.text = "CHUỘT TRÁI · BẮN SÚNG MUỐI" if armed else ""

func _hold(delta: float) -> void:
	grab_clock += delta
	wait -= delta
	var mouth := global_position - global_basis.z * HOLD_REACH + Vector3.UP * LIFT
	player.global_position = grab_from.lerp(mouth, clampf(grab_clock * 4.0, 0.0, 1.0))
	var face := global_position - player.global_position
	player.rotation.y = atan2(-face.x, -face.z)
	player.camera.rotation.x = lerpf(player.camera.rotation.x, MOUTH_PITCH, 1.0 - exp(-8.0 * delta))
	model.move("idle", 1.4)
	if wait <= 0.0:
		_decide()

func _unhandled_input(event: InputEvent) -> void:
	if state == State.GRAB and armed and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		fire_salt()

# It wants prizes more than meat: the dearest thing buys the player's life.
func _dearest() -> String:
	var best := ""
	for item in player.inventory:
		if Gear.VALUE.get(item, 0) > Gear.VALUE.get(best, 0):
			best = item
	return best

func _decide() -> void:
	var prize := _dearest()
	if prize.is_empty():
		_release(0.0)
		player.invulnerable_time = 0.0
		player.take_damage(player.health + 1.0, self)
		return
	player.inventory[player.inventory.find(prize)] = ""
	stolen.append(prize)
	world.notify("Bác bảo vệ giật mất %s rồi mải xem · Chạy đi!" % player.ITEM_NAMES[prize])
	_release(0.0)
	state = State.ADMIRE
	wait = ADMIRE_SECONDS
	velocity = Vector3.ZERO
	_forget()
	notice = 0.0
	model.admire(prize)
	director.caught_someone()

# It turns the prize over in its claws, medals chiming, and forgets the world for a moment.
func _admire(delta: float) -> void:
	wait -= delta
	model.move("idle", 0.5)
	rotate_y(sin(wait * 1.7) * delta * 0.5)
	if int(wait * 0.8) != int((wait + delta) * 0.8):
		clink_sound.play()
	if wait <= 0.0:
		model.stop_admiring()
		state = State.ROAM
		_next_search()

func fire_salt() -> void:
	player.inventory[player.inventory.find("salt_gun")] = ""
	shot_sound.play()
	roar_sound.pitch_scale = 1.4
	roar_sound.play()
	_release(THROW_REACH)
	player.stamina = player.MAX_STAMINA
	player.combat.adrenaline_remaining = player.combat.ADRENALINE_SECONDS
	player.combat.heartbeat.play()
	world.notify("Bác bảo vệ kêu lên rồi buông bạn ra · Chạy mau!")
	state = State.STAGGER
	wait = STAGGER_SECONDS
	_forget()
	notice = 0.0
	director.driven_off(STAGGER_SECONDS + BLIND_SECONDS)

func _stagger(delta: float) -> void:
	wait -= delta
	rotate_y(sin(wait * 9.0) * delta * 3.0)
	model.move("idle", 1.8)
	if wait <= 0.0:
		roar_sound.pitch_scale = 1.0
		fall_back(director._far_point(player.global_position), BLIND_SECONDS)

func _release(reach: float) -> void:
	var away := player.global_position - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else global_basis.z
	var landing := grab_from
	for distance in [reach, reach * 0.6, reach * 0.3]:
		var spot: Vector3 = global_position + away * distance
		spot.y = grab_from.y
		if reach > 0.0 and player.can_fit(spot):
			landing = spot
			break
	player.global_position = landing
	player.seized = false
	shout.text = ""
	player.camera.rotation.x = 0.0
	player.invulnerable_time = ESCAPE_GRACE

func _walk(speed: float, delta: float) -> void:
	var next := agent.get_next_path_position()
	var flat := next - global_position
	flat.y = 0.0
	var direction := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var climb := next.y - global_position.y
	# Stairs catch the capsule from some angles, so it lifts itself along the rising path.
	if climb > 0.12:
		velocity.y = minf(climb * 7.0, 4.0)
	else:
		velocity.y = -6.0 if not is_on_floor() else -0.5
	move_and_slide()
	_unstick(direction, delta)
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-7.0 * delta))
		model.move("stalk", speed / 1.5)
		_step(speed * delta)
	else:
		model.move("idle", 1.0)

# Furniture corners can pin the capsule. The search must never just stop.
func _unstick(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO or global_position.distance_to(pin_from) > 0.5:
		pin_from = global_position
		pin_clock = 0.0
		return
	pin_clock += delta
	if pin_clock > 1.2:
		pin_clock = 0.0
		global_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + direction * 0.9) + Vector3.UP * 0.05

func _step(moved: float) -> void:
	stride_left -= moved
	if stride_left > 0.0:
		return
	stride_left = RUN_STRIDE if Vector2(velocity.x, velocity.z).length() > 4.0 else STRIDE
	step_sound.volume_db = STEP_LOUD - _muffled()
	step_sound.play()
	if randf() < 0.3:
		clink_sound.pitch_scale = randf_range(0.9, 1.2)
		clink_sound.play()
	shake = (1.0 - clampf(global_position.distance_to(player.global_position) / SHAKE_RANGE, 0.0, 1.0)) * (0.35 if _muffled() > 0.0 else 1.0)

# Footfalls must say where it is: dull through walls, duller through floors.
func _muffled() -> float:
	var loss := 0.0
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, player.camera.global_position, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		loss += WALLS_DB
	if absf(global_position.y - player.global_position.y) > 2.5:
		loss += FLOOR_DB
	return loss

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 3.5)
	player.camera.v_offset = sin(Time.get_ticks_msec() * 0.06) * shake * shake * 0.05
	player.camera.h_offset = cos(Time.get_ticks_msec() * 0.047) * shake * shake * 0.025

func _open_doors(delta: float) -> void:
	door_clock -= delta
	if door_clock > 0.0:
		return
	door_clock = 0.25
	for door in get_tree().get_nodes_in_group("classroom_doors"):
		if not door.is_open and door.global_position.distance_to(global_position) < 2.3:
			# Story locks stop the player, not this: navigation runs through every doorway.
			if not door.set_open(true):
				door.is_open = true
				door.toggled.emit(true)
				world.soundscape.at("door", door.global_position, -6)

func _stoop(_delta: float) -> void:
	# The guard is a man of 1.7 m: door frames never make him fold down.
	model.scale = Vector3.ONE
