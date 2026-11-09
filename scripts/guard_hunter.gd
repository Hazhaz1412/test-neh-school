extends CharacterBody3D
const Steer := preload("res://scripts/path_steer.gd")
# AI B, the hunter (Night 1: the guard). It holds no reference to where anyone is: it knows only
# what it sees, what it hears and the areas the director whispers. It searches rooms and hiding
# places itself. With a team (hunt_team.gd) a catch is not a kill: it drags the student off to a
# locked room and goes back to hunting the others.
enum State {ROAM, SWEEP, LISTEN, CHASE, STRIKE, REST, GRAB, STAGGER}
const NAMES := {State.ROAM: "đi lang thang", State.SWEEP: "tự lục soát", State.LISTEN: "nghe trước chỗ trốn", State.CHASE: "đuổi", State.STRIKE: "vồ", State.REST: "bị gọi lui", State.GRAB: "lôi người đi nhốt", State.STAGGER: "đau, mất dấu"}
const STALK_SPEED := 3.6
const SEARCH_SPEED := 3.2
# 5% faster than a student's sprint (5.2 m/s): on open ground he always closes in.
const CHASE_SPEED := 5.46
# The longer he runs unbroken the faster he gets; every climb or shelf he clears starts it over.
const RAGE_SPEED := 6.25
const RAGE_SECONDS := 20.0
const POUNCE_REACH := 3.0
const POUNCE_SPEED := 7.0
const POUNCE_SECONDS := 0.6
const POUNCE_REST := 8.0
const SIGHT_RANGE := 26.0
const TORCH_SIGHT_RANGE := 38.0
const SIGHT_CONE := 0.3
const SENSE_ALWAYS := 2.6
const NOTICE_SECONDS := 0.2
# Out of sight this long, with nothing heard, before he gives up the chase and searches.
const LOSE_SECONDS := 6.0
# For a moment after losing sight it still follows the footsteps.
const TRACK_SECONDS := 2.0
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
# The guard grabs the student by the collar at his own height, not up to a mouth.
const LIFT := 0.0
const HOLD_REACH := 0.75
const STAGGER_SECONDS := 3.0
# Dragging someone along, he walks; a vault takes him far longer than it takes a student.
const CARRY_SPEED := 3.2
const VAULT_SECONDS := 1.4
const LINGER_SECONDS := 2.0
const LUNGE_SPEED := 6.5
const LOW_EYE := 1.3
const BLIND_SECONDS := 10.0
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
# Items he took off a student; returned at the shop for half price.
var confiscated: Array[String] = []
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
var certain := false
var suspects: Array[Node3D] = []
var chase_time := 0.0
var pounce_left := 0.0
var pounce_clock := 0.0
var shout: Label
# Whoever it is after: the player or a teammate.
var target: CharacterBody3D
var team: Node
var jail_door: Node3D
var carried_layers := Vector2i.ZERO
var cross_time := 0.0
var sidestep_time := 0.0
var last_climbed: Node3D
# Nailing planks over a low gap he saw a student use.
const BOARD_SECONDS := 2.0
const BOARD_REACH := 3.0
var boarding: Node3D
var board_time := 0.0
var board_clock := 0.0
var climbed_at := 0
var sidestep_dir := Vector3.ZERO
# Dragging a fallen shelf out of a gap.
var clearing: Node3D
var clear_time := 0.0
# Knocked back by a falling shelf: a short stagger, then straight back to the chase.
var stunned := false
var cross_from := Vector3.ZERO
var cross_to := Vector3.ZERO

func _ready() -> void:
	player = world.player
	target = player
	team = world.get("team")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	# Thinner than the 0.375 m Night 1's map keeps from every wall, so no corner snags him.
	capsule.radius = 0.3
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.98
	add_child(shape)
	agent = NavigationAgent3D.new()
	# Turn at the corner, not half a metre before it: cutting corners snags on wall ends.
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = 0.8
	agent.path_height_offset = 0.25
	add_child(agent)
	agent.link_reached.connect(_on_link)
	model = preload("res://scripts/guard_hunter_model.gd").new()
	model.rotation.y = PI
	add_child(model)
	step_sound = _voice("res://assets/audio/footstep.wav", STEP_LOUD, 46.0, 6.0)
	step_sound.stream = preload("res://scripts/security_guard.gd").shoe_steps()
	clink_sound = _voice("res://assets/audio/guard_keys.wav", -12.0, 22.0, 5.0)
	rattle_sound = _voice("res://assets/audio/guard_rattle.wav", -3.0, 26.0, 6.0)
	roar_sound = _voice("res://assets/audio/guard_whistle.wav", 0.0, 60.0, 12.0)
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
	return state in [State.REST, State.STAGGER]

# The only way the director can reach the hunter.
func whisper(centre: Vector3, radius: float) -> void:
	if centre.distance_to(area) > radius * 0.5 or not has_area:
		area_visited = false
	area = centre
	area_radius = radius
	has_area = true
	if state == State.ROAM:
		_next_search()

func hear(heard_at: Vector3, radius: float, source: String) -> void:
	# Mid-chase, the quarry's own running feet and vaults keep him on the trail: only going
	# quiet out of sight shakes him off.
	if state == State.CHASE and target != null and global_position.distance_to(heard_at) <= radius * 1.25 and heard_at.distance_to(target.global_position) < 3.0:
		last_seen = heard_at
		unseen = minf(unseen, TRACK_SECONDS * 0.5)
		return
	if is_hunting() or is_resting() or global_position.distance_to(heard_at) > radius * 1.25:
		return
	if source == "breath" and global_position.distance_to(heard_at) > 4.0:
		return
	if state != State.LISTEN:
		whisper(heard_at, 5.0)
		_next_search()

# Seen climbing in: that spot is no longer a guess, and nothing else matters now.
func witness(spot: Node3D) -> void:
	if state != State.GRAB and not is_resting() and _can_see(player, false):
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
	return _exposed(target)

func _exposed(body: CharacterBody3D) -> bool:
	if body == null or body.is_hidden():
		return false
	return team == null or team.is_free(body) and body.invulnerable_time <= 0.0

func _bodies() -> Array:
	return team.free_bodies() if team != null else [player]

func _lit(body: CharacterBody3D) -> bool:
	return body.flashlight.visible if body == player else body.torch_lit()

func _can_see_player(use_cone := true) -> bool:
	return _can_see(target, use_cone)

func _can_see(body: CharacterBody3D, use_cone := true) -> bool:
	var eye := global_position + Vector3.UP * EYE
	var chest: Vector3 = body.sight_point()
	var offset := chest - eye
	var reach := TORCH_SIGHT_RANGE if _lit(body) else SIGHT_RANGE
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
		if hit.is_empty() or hit.collider == body:
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
	var seen := _spot_someone()
	var sees := seen != null
	if sees:
		target = seen
		last_seen = target.global_position
		unseen = 0.0
		notice += 0.15
		if notice >= NOTICE_SECONDS and not is_hunting():
			state = State.CHASE
			chase_time = 0.0
			certain = false
			roar_sound.play()
			if target == player:
				world.notify("ĐỨNG LẠI! · Bác bảo vệ thấy bạn rồi")
	elif not certain and _glimpses_hider():
		notice += 0.15
		if notice >= NOTICE_SECONDS:
			notice = 0.0
			target = player
			_saw_hiding(player.hidden_spot)
	else:
		notice = maxf(0.0, notice - 0.15)
		if state == State.CHASE:
			unseen += 0.15

# Who it can see right now: whoever it is already after, otherwise the nearest.
func _spot_someone() -> CharacterBody3D:
	if state == State.CHASE and _exposed(target) and _can_see(target):
		return target
	var found: CharacterBody3D = null
	var nearest := INF
	for body in _bodies():
		if _exposed(body) and _can_see(body):
			var gap: float = global_position.distance_to(body.global_position)
			if gap < nearest:
				nearest = gap
				found = body
	return found

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
	if cross_time > 0.0:
		_cross(delta)
		return
	if clear_time > 0.0:
		_sense(delta)
		_clear(delta)
		return
	if board_time > 0.0:
		_sense(delta)
		_board(delta)
		return
	_sense(delta)
	_look_for_gap_to_board(delta)
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
		target = hider
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
	if not _exposed(target) and unseen <= 0.0:
		unseen = 0.15
	if unseen <= TRACK_SECONDS:
		last_seen = target.global_position
	agent.target_position = _intercept() if unseen <= 0.0 else last_seen
	var gap: float = global_position.distance_to(target.global_position)
	if unseen <= 0.0 and pounce_clock <= 0.0 and gap < POUNCE_REACH and gap > STRIKE_REACH:
		pounce_clock = POUNCE_REST
		pounce_left = POUNCE_SECONDS
		roar_sound.play()
	var speed := lerpf(CHASE_SPEED, RAGE_SPEED, clampf(chase_time / RAGE_SECONDS, 0.0, 1.0))
	_walk(POUNCE_SPEED if pounce_left > 0.0 else speed, delta)
	if _player_exposed() and gap < STRIKE_REACH and not _out_of_reach(target):
		state = State.STRIKE
		wait = 0.45
		model.move("idle", 1.4)
		return
	if unseen > LOSE_SECONDS:
		_lost_sight()

# Once a student is 0.2 s into a climb they are over: too late to grab.
func _out_of_reach(body: CharacterBody3D) -> bool:
	return body.has_method("past_grab") and body.past_grab()

# Runs for where the prey is going, unless that is somewhere it could not walk to.
func _intercept() -> Vector3:
	var ahead: Vector3 = target.global_position + target.velocity * Vector3(1, 0, 1) * minf(global_position.distance_to(target.global_position) / CHASE_SPEED, PREDICT_SECONDS)
	var walkable := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, ahead)
	return walkable if walkable.distance_to(ahead) < PREDICT_TRUST else target.global_position

# The reach is a lunge, not a pause: stepping backwards must not outrun the wind-up.
func _strike(delta: float) -> void:
	wait -= delta
	var flat := target.global_position - global_position
	flat.y = 0.0
	if flat.length() > 0.9:
		velocity = flat.normalized() * LUNGE_SPEED
		velocity.y = -0.5
		move_and_slide()
	if flat.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-12.0 * delta))
	if wait > 0.0:
		return
	if _player_exposed() and global_position.distance_to(target.global_position) < STRIKE_REACH + 0.6 and not target.test_invincible() and not _out_of_reach(target):
		_seize()
	else:
		state = State.CHASE

# A catch: he takes them by the arm and drags them to the nearest room he can lock.
# Without a team a catch is the end.
func _seize() -> void:
	if team == null:
		player.invulnerable_time = 0.0
		player.take_damage(player.health + 1.0, self)
		state = State.ROAM
		_next_search()
		return
	state = State.GRAB
	grab_clock = 0.0
	grab_from = target.global_position
	target.seized = true
	carried_layers = Vector2i(target.collision_layer, target.collision_mask)
	target.collision_layer = 0
	target.collision_mask = 0
	if target == player:
		player.cancel_chalk_charge()
		player.flashlight.hide()
		player.end_hide()
		# Facing where he is marching them, so they see which room it is.
		player.rotation.y = rotation.y
		player.camera.rotation.x = 0.0
	roar_sound.play()
	if target == player:
		world.progression.fear.beat()
	shout.text = ""
	team.seize(target)
	jail_door = team.jail_for(global_position)
	agent.target_position = team.inside(jail_door, 3)
	_forget()
	notice = 0.0

# Dragged at his side, on foot: the captive can only look on.
func _hold(delta: float) -> void:
	grab_clock += delta
	_walk(CARRY_SPEED, delta)
	_carry_pose()
	var goal: Vector3 = team.inside(jail_door, 3)
	var arrived: bool = grab_clock > 0.5 and (global_position.distance_to(goal) < 1.0 or agent.is_navigation_finished() and global_position.distance_to(goal) < 3.0)
	# Stuck for long on the way: he gets there anyway, nobody is left hanging.
	if arrived or grab_clock > 60.0:
		_lock_up()

func _carry_pose() -> void:
	if target == null or state != State.GRAB:
		return
	# Marched ahead of him by the collar, inside his own width: never pushed into a wall or door frame.
	var ahead := global_position - global_basis.z * 0.45
	target.global_position = target.global_position.lerp(ahead, clampf(grab_clock * 4.0, 0.0, 1.0)) if grab_clock < 0.25 else ahead
	if target != player:
		target.rotation.y = rotation.y
	else:
		# The camera rides at the student's eye, ahead of his face: keep his body out of view.
		player.camera.rotation.x = clampf(player.camera.rotation.x, -0.6, 0.6)

func _lock_up() -> void:
	shout.text = ""
	target.collision_layer = carried_layers.x
	target.collision_mask = carried_layers.y
	team.imprison(target, jail_door)
	director.caught_someone()
	# A moment at the door, then off to find the others.
	fall_back(team.outside(jail_door), LINGER_SECONDS)
	target = player

# The captive fought loose (hunt_team.gd, the struggle bar): he drops them and staggers.
func break_free() -> void:
	if state != State.GRAB or target == null:
		return
	var body := target
	body.collision_layer = carried_layers.x
	body.collision_mask = carried_layers.y
	var map: RID = get_world_3d().navigation_map
	body.global_position = NavigationServer3D.map_get_closest_point(map, global_position + global_basis.x * 1.1) + Vector3.UP * 0.05
	body.seized = false
	body.invulnerable_time = ESCAPE_GRACE
	team.release(body)
	if body == player:
		player.camera.rotation.x = 0.0
	shout.text = ""
	roar_sound.play()
	stunned = true
	state = State.STAGGER
	wait = 1.5
	last_seen = body.global_position

func _stagger(delta: float) -> void:
	wait -= delta
	rotate_y(sin(wait * 9.0) * delta * 3.0)
	model.move("idle", 1.8)
	if wait <= 0.0 and stunned:
		stunned = false
		state = State.CHASE
		unseen = 0.0 if _exposed(target) and _can_see(target, false) else LOSE_SECONDS * 0.5
		return
	if wait <= 0.0:
		roar_sound.pitch_scale = 1.0
		fall_back(director._far_point(player.global_position), BLIND_SECONDS)

# He hauls the fallen shelf aside: the student it was dropped on gains a few seconds.
func _clear(delta: float) -> void:
	clear_time -= delta
	velocity = Vector3.ZERO
	var face: Vector3 = clearing.global_position - global_position
	face.y = 0.0
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-8.0 * delta))
	model.move("idle", 1.6)
	_carry_pose()
	if clear_time <= 0.0:
		clear_time = 0.0
		clearing.clear()
		clearing = null

# Passing a low gap he saw a student slip through, and not running anyone down right now:
# he boards it up.
func _look_for_gap_to_board(delta: float) -> void:
	board_clock -= delta
	var course: Node3D = world.get("kiting")
	if board_clock > 0.0 or course == null or state == State.GRAB or state == State.STRIKE or state == State.CHASE and unseen <= 0.0:
		return
	board_clock = 0.3
	for gap in get_tree().get_nodes_in_group("kiting_low"):
		if course.wants_boarding(gap) and gap.global_position.distance_to(global_position) < BOARD_REACH:
			boarding = gap
			board_time = BOARD_SECONDS
			chase_time = 0.0
			return

func _board(delta: float) -> void:
	board_time -= delta
	velocity = Vector3.ZERO
	var face: Vector3 = boarding.global_position - global_position
	face.y = 0.0
	if face.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-8.0 * delta))
	model.move("idle", 1.8)
	if int(board_time * 3.0) != int((board_time + delta) * 3.0):
		world.soundscape.at("door", boarding.global_position, -12)
	if board_time <= 0.0:
		board_time = 0.0
		world.kiting.board(boarding)
		boarding = null

# A shelf fell on him.
func knock_back(seconds: float, _shelf: Node3D) -> void:
	if state == State.GRAB or cross_time > 0.0:
		return
	clear_time = 0.0
	clearing = null
	board_time = 0.0
	boarding = null
	chase_time = 0.0
	stunned = true
	state = State.STAGGER
	wait = seconds
	roar_sound.play()

# A window on his path: he climbs over, slowly.
func _on_link(details: Dictionary) -> void:
	var link = details.get("owner")
	if link is NavigationLink3D and cross_time <= 0.0:
		_climb(link.get_parent())

func _climb(window: Node3D) -> void:
	chase_time = 0.0
	last_climbed = window
	climbed_at = Time.get_ticks_msec()
	cross_from = global_position
	cross_to = preload("res://scripts/kiting_course.gd").far_side(window, global_position)
	cross_to.y = global_position.y
	cross_time = VAULT_SECONDS

func _cross(delta: float) -> void:
	cross_time = maxf(0.0, cross_time - delta)
	var t := 1.0 - cross_time / VAULT_SECONDS
	# Up onto the sill, a pause astride it, then down the far side.
	var along := smoothstep(0.0, 0.35, t) * 0.5 + smoothstep(0.6, 1.0, t) * 0.5
	global_position = cross_from.lerp(cross_to, along) + Vector3.UP * (0.9 * clampf(sin(t * PI) * 1.6, 0.0, 1.0))
	var flat := cross_to - cross_from
	if flat.length() > 0.05:
		rotation.y = atan2(-flat.x, -flat.z)
	model.move("idle", 1.0)
	velocity = Vector3.ZERO
	_carry_pose()
	if cross_time <= 0.0:
		_step(STRIDE)
		Steer.repath(agent)

func _walk(speed: float, delta: float) -> void:
	var next := Steer.point(agent, global_position)
	var flat := next - global_position
	flat.y = 0.0
	var direction := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	if direction != Vector3.ZERO and sidestep_time <= 0.0:
		var window: Node3D = preload("res://scripts/kiting_course.gd").crossing_ahead(world, global_position, next)
		if window != null and (window != last_climbed or Time.get_ticks_msec() - climbed_at > 1000):
			_climb(window)
			return
	if sidestep_time > 0.0:
		sidestep_time -= delta
		direction = sidestep_dir
	elif direction != Vector3.ZERO:
		var shelf: Node3D = preload("res://scripts/kiting_course.gd").blocking_pallet(world, global_position, direction)
		if shelf != null:
			clearing = shelf
			clear_time = shelf.CLEAR_SECONDS
			chase_time = 0.0
			velocity = Vector3.ZERO
			return
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	# Up a stair: step onto the tread in front (never a rail or a wall).
	var up := Steer.step_up(self, direction)
	if Steer.lost_level(agent, global_position):
		Steer.repath(agent)
	if up > 0.0:
		velocity.y = up
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
	# Caught on a corner: never through the wall. Back off sideways for a moment, then a fresh path.
	if pin_clock > 0.5:
		pin_clock = 0.0
		pin_from = global_position
		sidestep_dir = Steer.safe_side(self, direction, 1.0 if randf() < 0.5 else -1.0)
		sidestep_time = 0.35 if sidestep_dir != Vector3.ZERO else 0.0
		agent.target_position = agent.target_position

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
