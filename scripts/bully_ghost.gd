extends CharacterBody3D

# Quaternius supplies the skinned humanoid body and source animations.
# AI has separate patrol, investigation, pursuit and attack states.
enum State { PATROL, SEARCH, CHASE, ATTACK, STALK }
@export var patrol_speed := 1.65
@export var search_speed := 2.0
@export var close_chase_range := 4.5
@export var chase_speed := 4.65
@export var rush_speed := 6.4
@export var rush_duration := 1.1
@export var rush_recovery := 5.0
@export var detection_range := 18.0
@export var attack_range := 1.65
@export var damage := 14.0
@export var windup := 0.42
@export var attack_cooldown := 1.15
var world: Node3D
var player: CharacterBody3D
var squad_id := -1
var patrol_route: Array[Vector3] = []
var formation_offset := Vector3.ZERO
var state := State.PATROL
var active := true
var dormant := false
var sight_confirmation := 0.0
var banished_remaining := 0.0
var return_collision_layer := 2
var patrol_home := Vector3.ZERO
var last_known := Vector3.ZERO
var memory := 0.0
var path_clock := 0.0
var vision_clock := 0.0
var can_see := false
var cooldown := 0.0
var attack_time := 0.0
var strike_done := false
var animation: AnimationPlayer
var agent: NavigationAgent3D
var model: Node3D
var animation_names := {}
var head_node: MeshInstance3D
var torso_node: Node3D
var pose_clock := 0.0
var pose_phase := 0.0
var stalk_time := 0.0
var rush_time := 0.0
var rush_clock := 0.0
var snarl_clock := 0.0
var footstep_clock := 0.0
var patrol_index := 0
var patrol_stuck_time := 0.0
var patrol_last_position := Vector3.ZERO
var patrol_progress_clock := 0.0
var patrol_goal := Vector3.ZERO
var stun_remaining := 0.0
var restrained_remaining := 0.0
var restraint_goal := Vector3.ZERO
var knockback := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var hit_reaction := 0.0
var club_hand: Node3D
var search_index := 0
var search_wait := 0.0
var suspected_spot: Node3D
var snarl: AudioStreamPlayer3D
var footsteps: AudioStreamPlayer3D
var archetype := "bully"
static var reshaped_meshes := {}

func _ready() -> void:
	patrol_home = global_position
	patrol_last_position = global_position
	var nearest := INF
	for i in range(patrol_route.size()):
		var distance := global_position.distance_squared_to(patrol_route[i])
		if distance < nearest:
			nearest = distance
			patrol_index = i
	process_priority = 1 # Apply the crooked pose after AnimationPlayer updates.
	collision_layer = 2
	collision_mask = 7
	floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.45
	agent.target_desired_distance = 0.65
	agent.path_height_offset = 0.25
	add_child(agent)
	model = preload("res://scripts/humanoid_model.gd").new()
	model.variant = "Suit_Male"
	model.target_height = 2.6
	model.faceless = true
	model.name = "FacelessStudent"
	model.scale = Vector3.ONE * 0.80
	model.rotation.y = PI
	add_child(model)
	snarl = _sound("DetectionSnarl", "res://assets/audio/ghost_snarl.wav", -6)
	footsteps = _sound("ChaseSteps", "res://assets/audio/ghost_step.wav", -12)
	pose_phase = float((absi(String(name).hash()) * 37) % 100) * 0.17
	var head_frame: Node3D = model.bone_frame("Head", "FacelessHeadAnchor")
	head_node = MeshInstance3D.new()
	head_node.name = "head"
	var oval := SphereMesh.new()
	oval.radius = 2.2
	oval.height = 6.8
	oval.radial_segments = 20
	oval.rings = 12
	head_node.mesh = _reshape(oval, Vector3(1, 1, 0.86), Vector3(0, 3.4, 0), "faceless_oval")
	head_node.scale = Vector3.ONE * 0.075
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://assets/materials/ghost_skin.gdshader")
	head_node.material_override = mask
	head_frame.add_child(head_node)
	torso_node = Node3D.new()
	torso_node.name = "SchoolUniformDetails"
	model.add_child(torso_node)
	animation = model.animation
	for clip in ["idle", "walk", "sprint", "attack-melee-right"]:
		animation_names[clip] = clip
	_uniform_details()
	_attach_club()
	_play("walk")
	head_node.rotation.z = 0.34 * sin(pose_phase)
	head_node.rotation.x = -0.16
	if animation != null:
		animation.speed_scale = 0.88 + float(absi(String(name).hash()) % 13) * 0.025

func _reshape(source: Mesh, stretch: Vector3, offset: Vector3, key: String) -> ArrayMesh:
	if reshaped_meshes.has(key):
		return reshaped_meshes[key]
	var mesh := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(vertices.size()):
			vertices[i] = vertices[i] * stretch + offset
			if not normals.is_empty():
				normals[i] = (normals[i] / stretch).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	reshaped_meshes[key] = mesh
	return mesh

func _detail(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	node.material_override = mat
	parent.add_child(node)
	return node

func _uniform_details() -> void:
	for side in [-1, 1]:
		var collar := _detail(torso_node, "ShirtCollar", Vector3(side * 0.10, 1.58, 0.15), Vector3(0.15, 0.06, 0.045), Color(0.61, 0.63, 0.54))
		collar.rotation.z = side * 0.40
	_detail(torso_node, "SchoolTie", Vector3(0, 1.39, 0.18), Vector3(0.065, 0.30, 0.035), Color(0.30, 0.025, 0.04))
	_detail(torso_node, "StudentBadge", Vector3(0.15, 1.37, 0.18), Vector3(0.08, 0.065, 0.025), Color(0.62, 0.59, 0.38))
	var hair := SphereMesh.new()
	hair.radius = 2.25
	hair.height = 2.8
	hair.radial_segments = 16
	hair.rings = 8
	var cap := MeshInstance3D.new()
	cap.name = "MattedHair"
	cap.mesh = hair
	cap.position = Vector3(0, 5.9, -0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.025, 0.029, 0.026)
	cap.material_override = mat
	head_node.add_child(cap)

func _process(delta: float) -> void:
	if not active or not is_instance_valid(world) or not world.simulation_active():
		return
	pose_clock += delta
	hit_reaction = maxf(0, hit_reaction - delta * 3)
	if crowd_controlled():
		model.rotation.x = -0.20 - hit_reaction * 0.30
		model.rotation.z = sin(pose_clock * 12) * 0.06
		head_node.rotation.x = -hit_reaction * 0.6
		return
	# Deliberate head cant and uneven gait replace the mannequin-like pose.
	head_node.rotation.z = 0.34 * sin(pose_phase) + 0.12 * sin(pose_clock * 1.3 + pose_phase)
	head_node.rotation.x = -0.16 + 0.10 * sin(pose_clock * 0.8)
	model.rotation.z = (0.075 if rush_time > 0 else 0.025) * sin(pose_clock * 9 + pose_phase)
	model.rotation.x = 0.26 if rush_time > 0 else (0.14 if state == State.CHASE or state == State.ATTACK else -0.025)
	if state == State.STALK:
		head_node.rotation.z = 0.55 * sin(pose_phase + 1)
	if animation != null and state != State.ATTACK:
		animation.speed_scale = 1.55 if rush_time > 0 else (1.15 if state == State.CHASE else 0.95)

func _sound(label: String, path: String, volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = label
	sound.stream = load(path)
	sound.volume_db = volume
	sound.max_distance = 24
	sound.unit_size = 4
	sound.position.y = 1.3
	add_child(sound)
	return sound

func _attach_club() -> void:
	var hand: Node3D = model.bone_frame("Fist.R", "ClubHand")
	if hand == null:
		return
	club_hand = hand
	var grip := Node3D.new()
	grip.name = "WoodenClub"
	grip.position = Vector3(0, 0, 0)
	hand.add_child(grip)
	var mesh := MeshInstance3D.new()
	var club := CylinderMesh.new()
	club.bottom_radius = 0.045
	club.top_radius = 0.09
	club.height = 1.4
	club.radial_segments = 8
	mesh.mesh = club
	mesh.position.z = 0.55
	mesh.rotation.x = PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.15, 0.09)
	mat.roughness = 1.0
	mesh.material_override = mat
	grip.add_child(mesh)

func _play(name: String) -> void:
	if animation != null and animation_names.has(name):
		var key: String = animation_names[name]
		if animation.current_animation != key or not animation.is_playing():
			animation.play(key, 0.12)

func has_line_of_sight() -> bool:
	if not active or crowd_controlled() or not is_instance_valid(player) or player.is_hidden() or world.is_soul_sanctuary(player.global_position):
		return false
	return sees_point(player.global_position + Vector3(0, 1.2, 0))

func can_strike_player() -> bool:
	return has_line_of_sight()

func recently_heard_close() -> bool:
	return false

func holds_position() -> bool:
	return false

func audible(position_heard: Vector3, radius: float) -> bool:
	if not active or crowd_controlled() or not world.spirit_enabled or world.is_soul_sanctuary(position_heard) or absf(position_heard.y - global_position.y) > 1.6:
		return false
	var attenuation := 1.0 if sees_point(position_heard + Vector3.UP) else 0.4
	return global_position.distance_to(position_heard) < radius * attenuation * world.survival.hearing_multiplier()

func hear_noise(position_heard: Vector3, radius: float, source: String) -> void:
	if source == "breath" or source == "cough" or not audible(position_heard, radius):
		return
	if state == State.PATROL or state == State.SEARCH:
		alert(position_heard)

func lit_by_player() -> bool:
	if player.is_hidden() or world.is_soul_sanctuary(player.global_position) or not player.flashlight.visible:
		return false
	var to_head: Vector3 = global_position + Vector3(0, 1.7, 0) - player.camera.global_position
	if to_head.length() > 11 or -player.camera.global_basis.z.dot(to_head.normalized()) < 0.965:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, global_position + Vector3(0, 1.7, 0), 5)
	ray.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func sees_point(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.45, 0), point, 5)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player

func witness_hiding(spot: Node3D) -> void:
	var offset := player.global_position - global_position
	var flat := Vector3(offset.x, 0, offset.z).normalized()
	var in_view := -global_basis.z.dot(flat) > -0.1 or offset.length() < 4 or state == State.CHASE or state == State.ATTACK
	if not active or offset.length() > detection_range or not in_view or not has_line_of_sight():
		return
	suspected_spot = spot
	last_known = spot.approach_position()
	state = State.SEARCH
	memory = 12
	can_see = false
	search_index = 0
	path_clock = 0

func _begin_pursuit() -> void:
	state = State.STALK
	stalk_time = 0.4
	rush_time = 0
	search_index = 0
	suspected_spot = null
	world.alert_squad(squad_id, last_known, self)

func commit_chase() -> void:
	state = State.CHASE
	if snarl_clock <= 0:
		snarl.pitch_scale = 0.85 + pose_phase * 0.015
		snarl.play()
		snarl_clock = 8
		world.on_ghost_spotted(self)

func alert(position_seen: Vector3) -> void:
	if not active or crowd_controlled() or world.is_soul_sanctuary(position_seen):
		return
	if state == State.PATROL or state == State.SEARCH:
		last_known = position_seen
		memory = 14.0
		state = State.SEARCH
		search_index = 0
		path_clock = 0.0

func banish(duration: float) -> void:
	if banished_remaining <= 0:
		return_collision_layer = collision_layer
	banished_remaining = maxf(banished_remaining, duration)
	active = false
	collision_layer = 0
	hide()
	velocity = Vector3.ZERO
	state = State.PATROL
	can_see = false
	memory = 0
	suspected_spot = null
	attack_time = 0
	strike_done = true
	rush_time = 0
	stalk_time = 0
	stun_remaining = 0
	restrained_remaining = 0
	knockback = Vector3.ZERO
	model.melee_swing = -1
	path_clock = 0
	snarl.stop()
	footsteps.stop()
	if animation != null:
		animation.pause()

func _tick_banish(delta: float) -> void:
	if not is_instance_valid(world) or not world.spirit_enabled or not world.simulation_active():
		return
	banished_remaining = maxf(0, banished_remaining - delta)
	if banished_remaining > 0:
		return
	if world.is_soul_sanctuary(global_position):
		global_position = patrol_home
	# Never rematerialize the heavy body's collision inside a passing player.
	if absf(global_position.y - player.global_position.y) < 2.4 and Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length() < 1.1:
		banished_remaining = 0.1
		return
	active = true
	collision_layer = return_collision_layer
	cooldown = 1.0
	vision_clock = 0.35
	can_see = false
	show()
	_play("idle")

func clear_pursuit() -> void:
	state = State.PATROL
	can_see = false
	memory = 0
	sight_confirmation = 0
	suspected_spot = null
	rush_time = 0
	stalk_time = 0
	attack_time = 0
	strike_done = true
	path_clock = 0
	velocity = Vector3.ZERO
	model.melee_swing = -1
	snarl.stop()
	footsteps.stop()

func crowd_controlled() -> bool:
	return stun_remaining > 0 or restrained_remaining > 0

func restrain(duration: float, goal: Vector3) -> void:
	clear_pursuit()
	restrained_remaining = duration
	restraint_goal = goal
	model.aim_hand(player.camera.global_position - player.camera.global_basis.z * 0.9 + Vector3(0, -0.12, 0))
	animation.speed_scale = 0
	animation.pause()

func react_to_punch() -> void:
	hit_reaction = 1

func counter_stun(direction: Vector3, duration := 3.0, force := 8.0) -> void:
	clear_pursuit()
	restrained_remaining = 0
	stun_remaining = maxf(stun_remaining, duration)
	knockback = Vector3(direction.x, 0, direction.z).normalized() * force
	hit_reaction = 1
	animation.speed_scale = 0
	animation.pause()

func _tick_control(delta: float) -> void:
	if restrained_remaining > 0:
		restrained_remaining = maxf(0, restrained_remaining - delta)
		var pull := restraint_goal - global_position
		pull.y = 0
		var speed := minf(2.8, pull.length() / maxf(delta, 0.001))
		velocity.x = pull.normalized().x * speed
		velocity.z = pull.normalized().z * speed
	else:
		stun_remaining = maxf(0, stun_remaining - delta)
		velocity.x = knockback.x
		velocity.z = knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, delta * 18)
	velocity.y = 0 if is_on_floor() else velocity.y - 18 * delta
	move_and_slide()
	if not crowd_controlled():
		animation.speed_scale = 1
		_play("idle")
		vision_clock = 0
		cooldown = maxf(cooldown, 0.4)

func start_attack() -> void:
	state = State.ATTACK
	attack_time = 0
	strike_done = false
	attack_direction = (player.global_position - global_position).normalized()
	attack_direction.y = 0
	attack_direction = attack_direction.normalized()
	_play("attack-melee-right")
	animation.speed_scale = 1
	player.combat.offer_qte(self)

func _tick_attack(delta: float) -> void:
	attack_time += delta
	model.melee_swing = clampf(attack_time / (windup + 0.28), 0, 1)
	var offset := player.global_position - global_position
	velocity.x = 0
	velocity.z = 0
	# Commit the direction before contact. Track briefly so ordinary movement
	# isn't perfect immunity; range, walls and a late sidestep can still evade it.
	if attack_time < windup * 0.65 and can_strike_player():
		var flat := Vector3(offset.x, 0, offset.z).normalized()
		attack_direction = flat
		_face(flat, delta)
		if offset.length() > 0.9:
			velocity.x = flat.x * minf(chase_speed + 0.8, rush_speed)
			velocity.z = flat.z * minf(chase_speed + 0.8, rush_speed)
	if not strike_done and attack_time >= windup and attack_time <= windup + 0.28:
		var flat := Vector3(offset.x, 0, offset.z).normalized()
		if offset.length() <= attack_range + 0.65 and absf(offset.y) < 1.15 and flat.dot(attack_direction) > 0.15 and can_strike_player():
			# A swing may have started during the previous hit's grace period.
			# Intercept here too, before a third eligible contact can deal damage.
			if player.combat.offer_qte(self):
				return
			strike_done = true
			player.take_damage(damage, self)
	if attack_time >= windup + 0.45 and not crowd_controlled():
		state = State.CHASE if can_see else State.SEARCH
		cooldown = attack_cooldown
		model.melee_swing = -1

func guard_sanctuary() -> bool:
	if world.is_soul_sanctuary(global_position):
		global_position = patrol_home
		clear_pursuit()
		agent.target_position = patrol_home
		return true
	if world.is_soul_sanctuary(player.global_position) and (state != State.PATROL or memory > 0 or can_see or suspected_spot != null):
		clear_pursuit()
	return false

func _physics_process(delta: float) -> void:
	if dormant:
		return
	if banished_remaining > 0:
		_tick_banish(delta)
		return
	if not active or not is_instance_valid(world) or not world.spirit_enabled:
		return
	if not world.simulation_active():
		velocity = Vector3.ZERO
		if animation != null:
			animation.pause()
		snarl.stream_paused = true
		footsteps.stream_paused = true
		return
	if guard_sanctuary():
		return
	if crowd_controlled():
		_tick_control(delta)
		return
	snarl.stream_paused = false
	footsteps.stream_paused = false
	if animation != null and not animation.is_playing() and not animation.current_animation.is_empty():
		animation.play()
	cooldown = maxf(0, cooldown - delta)
	memory = maxf(0, memory - delta)
	path_clock -= delta
	vision_clock -= delta
	rush_time = maxf(0, rush_time - delta)
	rush_clock = maxf(0, rush_clock - delta)
	snarl_clock = maxf(0, snarl_clock - delta)
	footstep_clock -= delta
	var offset := player.global_position - global_position
	var distance := offset.length()
	if player.is_hidden():
		can_see = false
	# Nearby contact must react on this physics step, even if the slower
	# long-range observation timer was just reset. Walls still block detection.
	if distance <= close_chase_range:
		vision_clock = 0
	if vision_clock <= 0:
		vision_clock = 0.15
		var flat := Vector3(offset.x, 0, offset.z).normalized()
		var in_view := -global_basis.z.dot(flat) > -0.1 or distance < 4.0 or state == State.CHASE or state == State.ATTACK or state == State.STALK
		can_see = distance <= detection_range and in_view and has_line_of_sight()
		if can_see:
			last_known = player.global_position
			memory = 14.0
			search_index = 0
			if state == State.PATROL:
				_begin_pursuit()
			if distance <= close_chase_range and state != State.ATTACK:
				commit_chase()
				if rush_clock <= 0 and distance > attack_range:
					rush_time = rush_duration
					rush_clock = rush_duration + rush_recovery
		elif state == State.CHASE and not recently_heard_close():
			state = State.SEARCH
			rush_time = 0
			path_clock = 0
	sight_confirmation = minf(1.3, sight_confirmation + delta) if can_see else maxf(0, sight_confirmation - delta * 2)
	# Brief sight is suspicion; sustained clear sight confirms a target.
	# Losing visibility still switches immediately to slow last-position search.
	if can_see and sight_confirmation >= 1.25 and (state == State.SEARCH or state == State.STALK):
		commit_chase()
	if state == State.STALK:
		velocity.x = 0
		velocity.z = 0
		_face(last_known - global_position, delta)
		_play("idle")
		stalk_time -= delta
		if stalk_time <= 0:
			state = State.SEARCH
	elif state == State.ATTACK:
		_tick_attack(delta)
	else:
		if memory <= 0 and not can_see:
			state = State.PATROL
			suspected_spot = null
			search_index = 0
		elif state != State.CHASE:
			state = State.SEARCH
		if state == State.CHASE and rush_clock <= 0 and distance > attack_range + 1:
			rush_time = rush_duration
			rush_clock = rush_duration + rush_recovery
		if can_see and distance <= attack_range and absf(offset.y) < 1.15 and cooldown <= 0:
			velocity.x = 0
			velocity.z = 0
			start_attack()
		else:
			if holds_position():
				velocity.x = 0
				velocity.z = 0
				_face(offset, delta)
				_play("idle")
			else:
				_move_on_path(delta)
	if crowd_controlled():
		return
	if state == State.SEARCH and is_instance_valid(suspected_spot) and global_position.distance_to(suspected_spot.approach_position()) < 1.65 and sees_point(suspected_spot.approach_position() + Vector3.UP):
		velocity.x = 0
		velocity.z = 0
		_face(suspected_spot.hide_position() - global_position, delta)
		_play("idle")
		if suspected_spot.inspect_by(self, delta):
			suspected_spot = null
			vision_clock = 0
	if Vector2(velocity.x, velocity.z).length() > 0.25 and footstep_clock <= 0:
		footstep_clock = 0.23 if rush_time > 0 else (0.34 if state == State.CHASE else 0.65)
		footsteps.volume_db = -12 if state == State.CHASE else -20
		footsteps.pitch_scale = 0.9 + float(search_index % 3) * 0.07
		if archetype == "blocker":
			footstep_clock = 0.8
			footsteps.pitch_scale = 0.6
			footsteps.volume_db = -13
		footsteps.play()
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 8))

func _move_on_path(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) == 0:
		return
	if path_clock <= 0:
		path_clock = 0.16 if state == State.CHASE else 0.45
		var goal := last_known
		if state == State.PATROL and not patrol_route.is_empty():
			goal = patrol_route[patrol_index] + formation_offset
			patrol_goal = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, goal)
			goal = patrol_goal
		elif state == State.SEARCH and not is_instance_valid(suspected_spot) and search_index > 0:
			var angle := float(search_index) * 2.4 + pose_phase
			var candidate := last_known + Vector3(cos(angle), 0, sin(angle)) * 2.2
			var projected := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, candidate)
			if absf(projected.y - last_known.y) < 0.65:
				goal = projected
		agent.target_position = goal
	var next := agent.get_next_path_position()
	if world.is_soul_sanctuary(next):
		clear_pursuit()
		_play("idle")
		return
	var direction := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if agent.is_navigation_finished() or direction.length() < 0.10:
		velocity.x = 0
		velocity.z = 0
		_play("idle")
		if state == State.PATROL and not patrol_route.is_empty():
			advance_patrol()
		if state == State.SEARCH and not is_instance_valid(suspected_spot):
			search_wait += delta
			rotation.y += delta * 0.8
			if search_wait > 1.0:
				search_wait = 0
				search_index += 1
				path_clock = 0
		return
	if state == State.PATROL:
		patrol_progress_clock += delta
		if patrol_progress_clock >= 0.5:
			patrol_stuck_time = patrol_stuck_time + patrol_progress_clock if global_position.distance_to(patrol_last_position) < 0.12 else 0.0
			patrol_last_position = global_position
			patrol_progress_clock = 0
			# Only abandon a checkpoint after being physically blocked for eight seconds.
			if patrol_stuck_time >= 8:
				advance_patrol()
				return
	direction = direction.normalized()
	var separation := Vector3.ZERO
	for ally in world.enemies:
		if is_instance_valid(ally) and ally.active and ally != self:
			var away: Vector3 = global_position - ally.global_position
			away.y = 0
			if away.length() < 0.85 and away.length() > 0.01:
				separation += away.normalized() * (0.85 - away.length())
	direction = (direction + separation * 0.25).normalized()
	var speed := patrol_speed if state == State.PATROL else (search_speed if state == State.SEARCH else (rush_speed if rush_time > 0 else chase_speed))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(direction, delta)
	_play("sprint" if state == State.CHASE else "walk")

func advance_patrol() -> void:
	patrol_index = (patrol_index + 1) % patrol_route.size()
	if world.progression != null:
		for _step in range(patrol_route.size()):
			if world.progression.sector_accessible(patrol_route[patrol_index]):
				break
			patrol_index = (patrol_index + 1) % patrol_route.size()
	patrol_stuck_time = 0
	patrol_progress_clock = 0
	patrol_last_position = global_position
	path_clock = 0

func set_dormant(sleeping: bool) -> void:
	if dormant == sleeping:
		return
	if sleeping:
		if banished_remaining <= 0:
			return_collision_layer = collision_layer
		clear_pursuit()
		animation.pause()
		active = false
		collision_layer = 0
		hide()
	else:
		banished_remaining = 0
		active = true
		collision_layer = return_collision_layer
		cooldown = 0.8
		vision_clock = 0.25
		animation.speed_scale = 1
		_play("walk")
		show()
	dormant = sleeping
