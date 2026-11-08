extends CharacterBody3D
# One of Peter's three friends on Night 1. It walks the school, runs from the guard round the
# kiting loops (vaulting windows and fallen shelves, tipping shelves behind it, as the player can) and goes to unlock a caught friend
# when the guard is far enough from the room. Later a networked player can take this seat.
enum Mode { ROAM, FLEE, RESCUE }
const Course := preload("res://scripts/kiting_course.gd")
const Steer := preload("res://scripts/path_steer.gd")
const WALK := 2.1
# The player's sprint.
const RUN := 5.2
const TIRED := 3.0
const MAX_STAMINA := 240.0
const SPRINT_DRAIN := 19.0
const STAMINA_BACK := 15.0
const RESTED := 60.0
const SEE_GUARD := 24.0
const HEAR_GUARD := 8.0
const DANGER := 13.0
const CALM_SECONDS := 3.0
const VAULT_SECONDS := 0.55
const DROP_BEHIND := 7.0
const FATIGUE_PER_SECOND := 1.0 / 80.0
const FATIGUE_PER_STAMINA := 1.0 / 450.0
const GRAVITY := 18.0
var world: Node3D
var team: Node
var title := ""
var look := "Male_Child_01"
var model: Node3D
var agent: NavigationAgent3D
var tag: Label3D
var mode := Mode.ROAM
var seized := false
var captive := false
var invulnerable_time := 0.0
var hidden_spot: Node3D = null
var holding_breath := false
var stamina := MAX_STAMINA
var exhausted := false
var think_clock := 0.0
var calm := 99.0
var last_guard := Vector3.INF
var pause := 0.0
var rescue_door: Node3D
var cross_time := 0.0
var cross_length := 0.0
var cross_from := Vector3.ZERO
var cross_to := Vector3.ZERO
var crawling := false
var fatigue := 0.0
var noise_clock := 0.0
var flee_clock := 0.0
var sidestep_time := 0.0
var crossed_at := 0
var sidestep_dir := Vector3.ZERO
const FLEE_COMMIT := 1.5
var pinned := 0.0
var pinned_at := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = hash(title)
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = 0.6
	agent.path_height_offset = 0.25
	add_child(agent)
	agent.navigation_layers = 1 | Course.STUDENT_LAYER
	agent.link_reached.connect(_on_link)
	model = preload("res://scripts/humanoid_model.gd").new()
	model.look = look
	model.target_height = 1.6
	model.rotation.y = PI
	add_child(model)
	tag = Label3D.new()
	tag.text = title
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.fixed_size = true
	tag.pixel_size = 0.0009
	tag.font_size = 26
	tag.outline_size = 8
	tag.modulate = Color(0.75, 0.9, 0.85)
	tag.position.y = 1.95
	add_child(tag)

# What the guard's eyes test, the same calls it makes on the player.
func sight_point() -> Vector3:
	return global_position + Vector3.UP * (0.6 if crawling else 1.2)

func is_hidden() -> bool:
	return false

func torch_lit() -> bool:
	return false

func test_invincible() -> bool:
	return false

# As for the player: 0.2 s into a climb (or under a low gap) the guard can no longer grab them.
func past_grab() -> bool:
	return cross_time > 0.0 and (crawling or cross_length - cross_time > 0.2)

func can_fit(_feet: Vector3, _height := 1.75) -> bool:
	return true

func end_hide() -> bool:
	return true

func _guard() -> CharacterBody3D:
	return world.envy.demon if world.envy != null else null

func _physics_process(delta: float) -> void:
	if not world.simulation_active() and not team._player_captive():
		return
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	tag.visible = global_position.distance_to(world.player.global_position) < 30.0
	if seized:
		crawling = false
		cross_time = 0.0
		velocity = Vector3.ZERO
		_animate("idle", 1.0)
		return
	if cross_time > 0.0:
		_cross(delta)
		return
	think_clock -= delta
	if think_clock <= 0.0:
		think_clock = 0.25
		_think()
	var speed := 0.0
	if mode == Mode.FLEE:
		speed = TIRED if exhausted else RUN
	elif mode == Mode.RESCUE and _at_rescue():
		speed = 0.0
		var door := rescue_door
		var face: Vector3 = door.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-8.0 * delta))
		team.work_rescue(door, self, delta)
	elif pause > 0.0:
		pause -= delta
	else:
		speed = RUN * 0.8 if mode == Mode.RESCUE else WALK
	var running := speed > TIRED + 0.1
	# Running feet are heard, as the player's are.
	noise_clock -= delta
	if running and noise_clock <= 0.0:
		noise_clock = 0.3
		world.emit_noise(global_position, 18.0, "steps")
	var regained := 0.0 if running else minf(STAMINA_BACK * (1.0 - fatigue * 0.85) * delta, MAX_STAMINA - stamina)
	stamina = clampf(stamina - (SPRINT_DRAIN * delta if running else -regained), 0.0, MAX_STAMINA)
	var guard := _guard()
	if guard != null and guard.target == self and guard.is_hunting():
		fatigue = minf(1.0, fatigue + delta * FATIGUE_PER_SECOND + regained * FATIGUE_PER_STAMINA)
	elif calm > CALM_SECONDS:
		fatigue = maxf(0.0, fatigue - delta * 0.5)
	if mode == Mode.FLEE:
		_tip_shelf_behind()
	if stamina <= 0.0:
		exhausted = true
	elif stamina >= RESTED:
		exhausted = false
	_walk(speed, delta)

func _at_rescue() -> bool:
	return rescue_door != null and Vector2(global_position.x - team.rescue_spot(rescue_door).x, global_position.z - team.rescue_spot(rescue_door).z).length() < 1.0

func _think() -> void:
	calm += 0.25
	var guard := _guard()
	var danger := false
	if guard != null and guard.visible:
		var gap := global_position.distance_to(guard.global_position)
		var chased: bool = guard.target == self and guard.is_hunting()
		if chased or gap < HEAR_GUARD or gap < SEE_GUARD and _sees(guard):
			last_guard = guard.global_position
			danger = chased or gap < DANGER
	if danger:
		calm = 0.0
	if danger or mode == Mode.FLEE and calm < CALM_SECONDS:
		# Near a loop: take whichever spot leaves him the longest walk for its own, which is
		# how the windows, shelves and low gaps get used.
		var loop := _loop_near()
		if loop != null and guard != null:
			safe_clock -= 0.25
			if mode != Mode.FLEE or safe_clock <= 0.0 or agent.is_navigation_finished():
				agent.target_position = _safest_point(loop, guard.global_position)
				safe_clock = SAFE_COMMIT
			mode = Mode.FLEE
			rescue_door = null
			return
		# Hold a line for a while: changing mind every step is how runners get caught.
		flee_clock -= 0.25
		if mode != Mode.FLEE or agent.is_navigation_finished() or flee_clock <= 0.0 or _running_at(last_guard):
			_flee_from(last_guard)
			flee_clock = FLEE_COMMIT
		mode = Mode.FLEE
		rescue_door = null
		return
	var job: Node3D = team.rescue_job_for(self)
	if job != null:
		if rescue_door != job:
			rescue_door = job
			agent.target_position = team.rescue_spot(job)
		mode = Mode.RESCUE
		return
	rescue_door = null
	if mode != Mode.ROAM or agent.is_navigation_finished() and pause <= 0.0:
		if mode == Mode.ROAM:
			pause = rng.randf_range(1.5, 4.5)
		mode = Mode.ROAM
		agent.target_position = _wander_point()

const LOOP_REACH := 16.0
const SAFE_COMMIT := 0.5
var safe_clock := 0.0
const VAULT_WHEN := 4.0
var circling: Node3D
var loop_dir := 0.0
# The loop's running line round its crates, local metres (an ellipse through the corridor).
const RING := Vector2(4.4, 1.85)

func _loop_near() -> Node3D:
	if world.kiting == null:
		return null
	for loop in world.kiting.get_children():
		if loop.global_position.distance_to(global_position) < LOOP_REACH:
			return loop
	return null

# The next point round the ring, keeping one direction of travel: it only turns back when he
# comes round the crates the other way and stands in front. Close behind it, a window takes it out.
func _round_loop(loop: Node3D, threat: Vector3) -> Vector3:
	var mine: Vector3 = loop.to_local(global_position)
	var his: Vector3 = loop.to_local(threat)
	if threat.distance_to(global_position) < VAULT_WHEN:
		var window: Node3D = _window_between(loop, threat)
		if window != null:
			return Course.low_far_side(window, global_position) if window.is_in_group("kiting_low") else Course.far_side(window, global_position)
	var me_angle := atan2(mine.z / RING.y, mine.x / RING.x)
	var him_angle := atan2(his.z / RING.y, his.x / RING.x)
	var apart := wrapf(him_angle - me_angle, -PI, PI)
	if loop != circling or loop_dir == 0.0:
		circling = loop
		loop_dir = -1.0 if apart > 0.0 else 1.0
	elif apart * loop_dir > 0.0 and absf(apart) < PI * 0.6:
		loop_dir = -loop_dir
	var at := me_angle + loop_dir * PI * 0.4
	return loop.to_global(Vector3(cos(at) * RING.x, 0.05, sin(at) * RING.y))

func _walk_length(from: Vector3, to: Vector3, layers: int) -> float:
	var path := NavigationServer3D.map_get_path(_map(), from, to, true, layers)
	if path.size() < 2:
		return INF
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total + Vector2(path[-1].x - to.x, path[-1].z - to.z).length() * 4.0

# Candidates round the loop and beyond each of its crossings; the winner is where his walk most
# exceeds its own. A spot it cannot reach first is never chosen.
func _safest_point(loop: Node3D, threat: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	for i in range(8):
		var at := TAU * i / 8.0
		candidates.append(loop.to_global(Vector3(cos(at) * RING.x, 0.05, sin(at) * RING.y)))
	for group in ["kiting_low", "kiting_vault", "kiting_pallet"]:
		for crossing in get_tree().get_nodes_in_group(group):
			if not loop.is_ancestor_of(crossing):
				continue
			var beyond: Vector3 = Course.low_far_side(crossing, global_position) if group == "kiting_low" else Course.far_side(crossing, global_position)
			candidates.append(beyond)
			candidates.append(beyond + (beyond - crossing.global_position).normalized() * 3.0)
	for i in range(6):
		var offset := Vector2.from_angle(TAU * i / 6.0) * 10.0
		candidates.append(global_position + Vector3(offset.x, 0, offset.y))
	var best := global_position
	var score := -INF
	for raw in candidates:
		var point := NavigationServer3D.map_get_closest_point(_map(), raw)
		var mine := _walk_length(global_position, point, 1 | Course.STUDENT_LAYER)
		if mine > 18.0 or mine < 1.5:
			continue
		var his := _walk_length(threat, point, 1)
		if his <= mine:
			continue
		var value := his - mine * 1.1
		if value > score:
			score = value
			best = point
	if score == -INF:
		return _round_loop(loop, threat)
	return best

# A low gap (best: he cannot follow) or a window close by, whose far side puts the wall between
# it and him.
func _window_between(loop: Node3D, threat: Vector3) -> Node3D:
	for group in ["kiting_low", "kiting_vault"]:
		for window in get_tree().get_nodes_in_group(group):
			if not loop.is_ancestor_of(window) or window.global_position.distance_to(global_position) > 3.0:
				continue
			if signf(window.to_local(global_position).z) == signf(window.to_local(threat).z):
				return window
	return null

# The way it is heading now leads at him.
func _running_at(threat: Vector3) -> bool:
	if threat == Vector3.INF:
		return false
	var heading := Steer.point(agent, global_position) - global_position
	var toward := threat - global_position
	heading.y = 0.0
	toward.y = 0.0
	return heading.length() > 0.1 and toward.length() < 10.0 and heading.normalized().dot(toward.normalized()) > 0.5

func _sees(guard: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, guard.global_position + Vector3.UP * 1.3, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _map() -> RID:
	return get_world_3d().navigation_map

# Somewhere new on this floor, away from where the guard was last heard.
func _wander_point() -> Vector3:
	var best := global_position
	var score := -INF
	for i in range(8):
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 26.0)
		var point := NavigationServer3D.map_get_closest_point(_map(), global_position + Vector3(offset.x, 0, offset.y))
		if absf(point.y - global_position.y) > 1.5:
			continue
		var value := rng.randf() * 4.0
		if last_guard != Vector3.INF:
			value += minf(point.distance_to(last_guard), 30.0)
		if value > score:
			score = value
			best = point
	return best

# Away from him, and through a window or shelf gap when one is close: he is slower there.
func _flee_from(threat: Vector3) -> void:
	if threat == Vector3.INF:
		return
	var away := global_position - threat
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var best := global_position + away * 10.0
	var score := -INF
	var candidates: Array[Vector3] = []
	for i in range(14):
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(9.0, 22.0)
		candidates.append(global_position + Vector3(offset.x, 0, offset.y))
	for group in ["kiting_vault", "kiting_pallet", "kiting_low"]:
		for crossing in get_tree().get_nodes_in_group(group):
			if crossing.global_position.distance_to(global_position) < 26.0:
				var beyond := Course.low_far_side(crossing, threat) if group == "kiting_low" else Course.far_side(crossing, threat)
				candidates.append(beyond + (beyond - crossing.global_position).normalized() * 4.0)
	for raw in candidates:
		var point := NavigationServer3D.map_get_closest_point(_map(), raw)
		if absf(point.y - global_position.y) > 1.5:
			continue
		var heading := (point - global_position)
		heading.y = 0.0
		var value := point.distance_to(threat) - heading.length() * 0.35
		if heading.length() > 0.1 and heading.normalized().dot(-away) > 0.3:
			value -= 25.0
		if value > score:
			score = value
			best = point
	agent.target_position = best

func _on_link(details: Dictionary) -> void:
	var link = details.get("owner")
	if not link is NavigationLink3D or cross_time > 0.0:
		return
	if link.get_parent().is_in_group("kiting_low"):
		_slide_under(link.get_parent())
	else:
		_vault(link.get_parent())

func _vault(crossing: Node3D) -> void:
	crawling = false
	cross_from = global_position
	cross_to = Course.far_side(crossing, global_position)
	cross_to.y = global_position.y
	cross_length = VAULT_SECONDS
	cross_time = cross_length
	world.emit_noise(global_position, 10.0, "vault")

const SLIDE_UNDER_SECONDS := 0.7
func _slide_under(gap: Node3D) -> void:
	crawling = true
	cross_from = global_position
	cross_to = Course.low_far_side(gap, global_position)
	cross_to.y = global_position.y
	cross_length = SLIDE_UNDER_SECONDS
	cross_time = cross_length
	world.emit_noise(global_position, 9.0, "slide")
	if world.kiting != null:
		world.kiting.note_use(gap, self)

# Through a shelf gap with him close behind: tip the shelf into it.
func _tip_shelf_behind() -> void:
	var guard := _guard()
	if guard == null or guard.global_position.distance_to(global_position) > DROP_BEHIND:
		return
	var shelf: Node3D = Course.pallet_near(world, global_position, 2.2)
	if shelf == null:
		return
	var mine: float = shelf.to_local(global_position).z
	var his: float = shelf.to_local(guard.global_position).z
	if absf(mine) > 0.5 and signf(mine) != signf(his):
		shelf.drop(self)

func _cross(delta: float) -> void:
	cross_time = maxf(0.0, cross_time - delta)
	var t := 1.0 - cross_time / cross_length
	global_position = cross_from.lerp(cross_to, t) + Vector3.UP * (0.0 if crawling else sin(t * PI) * 0.75)
	var flat := cross_to - cross_from
	rotation.y = atan2(-flat.x, -flat.z)
	_animate("crouch" if crawling else "sprint", 1.0)
	if cross_time <= 0.0:
		crawling = false
		velocity = Vector3.ZERO
		Steer.repath(agent)
		crossed_at = Time.get_ticks_msec()

func _walk(speed: float, delta: float) -> void:
	var direction := Vector3.ZERO
	if speed > 0.0 and not agent.is_navigation_finished():
		var flat := Steer.point(agent, global_position) - global_position
		flat.y = 0.0
		if flat.length() > 0.05:
			direction = flat.normalized()
	if direction != Vector3.ZERO and sidestep_time <= 0.0 and Time.get_ticks_msec() - crossed_at > 400:
		var ahead := Steer.point(agent, global_position)
		var window: Node3D = Course.crossing_ahead(world, global_position, ahead)
		if window != null:
			_vault(window)
			return
		var low: Node3D = Course.low_near(world, global_position, 0.6)
		if low != null and not world.kiting.is_boarded(low) and signf(low.to_local(global_position).z) != signf(low.to_local(ahead).z):
			_slide_under(low)
			return
	if sidestep_time > 0.0:
		sidestep_time -= delta
		direction = sidestep_dir
	# A fallen shelf across the path: over it.
	elif direction != Vector3.ZERO:
		var shelf: Node3D = Course.blocking_pallet(world, global_position, direction, 1.0)
		if shelf != null:
			_vault(shelf)
			return
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	# As the guard: step onto the stair tread in front, never up a rail or a wall.
	var up := Steer.step_up(self, direction)
	if Steer.lost_level(agent, global_position):
		Steer.repath(agent)
	if up > 0.0:
		velocity.y = up
	move_and_slide()
	if direction != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))
		_animate("sprint" if speed > TIRED + 0.1 else "walk", speed / (5.0 if speed > TIRED + 0.1 else 1.3))
		# A corner can pin the capsule: back off sideways for a moment, then a fresh path.
		# Never through the wall.
		if global_position.distance_to(pinned_at) < 0.15:
			pinned += delta
			if pinned > 0.3:
				pinned = 0.0
				sidestep_dir = Steer.safe_side(self, direction, 1.0 if rng.randf() < 0.5 else -1.0)
				sidestep_time = 0.3 if sidestep_dir != Vector3.ZERO else 0.0
				agent.target_position = agent.target_position
		else:
			pinned = 0.0
			pinned_at = global_position
	else:
		_animate("idle", 1.0)

func _animate(clip: String, pace: float) -> void:
	if model == null or model.animation == null:
		return
	if model.animation.current_animation != clip:
		model.animation.play(clip, 0.2)
	model.animation.speed_scale = pace
