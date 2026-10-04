extends Node

# Six cached actors, usually two encounters, three only during the hunt bell.
# Move a sleeping actor only outside the player's view and on reachable circulation.
var world: Node3D
var check_clock := 0.0
var spawn_clock := 0.0
var rest_remaining := 0.0
var next_actor := 0
var ages := {}

func reset() -> void:
	check_clock = 0
	spawn_clock = 0
	rest_remaining = 0
	next_actor = 0
	ages.clear()

func prepare() -> void:
	reset()
	if not world.smart_spawn_enabled:
		return
	for enemy in world.enemies:
		enemy.set_dormant(true)
	# Start with one distant presence, then let the player settle before the next.
	wake_one()
	spawn_clock = 12

func give_break(seconds: float) -> void:
	rest_remaining = maxf(rest_remaining, seconds)
	spawn_clock = maxf(spawn_clock, seconds)

func reserved_count() -> int:
	return world.enemies.filter(func(e): return not e.dormant).size()

func nearby_count() -> int:
	return world.enemies.filter(func(e): return not e.dormant and absf(e.global_position.y - world.player.global_position.y) < 1.6 and e.global_position.distance_to(world.player.global_position) < 20).size()

func _physics_process(delta: float) -> void:
	if not world.smart_spawn_enabled or not world.spirit_enabled or not world.simulation_active():
		return
	check_clock -= delta
	spawn_clock = maxf(0, spawn_clock - delta)
	rest_remaining = maxf(0, rest_remaining - delta)
	if check_clock > 0:
		return
	check_clock = 0.5
	var player: CharacterBody3D = world.player
	for enemy in world.enemies:
		if enemy.dormant:
			continue
		ages[enemy] = float(ages.get(enemy, 0)) + 0.5
		var distance: float = enemy.global_position.distance_to(player.global_position)
		var other_floor := absf(enemy.global_position.y - player.global_position.y) > 2.5
		var expired: bool = float(ages[enemy]) > 75 and enemy.state == enemy.State.PATROL
		if not enemy.crowd_controlled() and enemy.banished_remaining <= 0 and not visible_to_player(enemy.global_position):
			if distance > 45 or other_floor and distance > 14 or expired and distance > 22:
				enemy.set_dormant(true)
				ages.erase(enemy)
	if player.is_hidden() or player.combat.busy() or world.is_soul_sanctuary(player.global_position) or rest_remaining > 0:
		return
	var target := mini(world.max_active_ghosts, 3 if world.survival.hunt_remaining > 0 else 2)
	if spawn_clock <= 0 and reserved_count() < target and nearby_count() < 2:
		if wake_one():
			spawn_clock = world.encounter_interval_seconds
		else:
			spawn_clock = 2 # Wait for a safe angle instead of forcing a visible spawn.

func visible_to_player(feet: Vector3) -> bool:
	var camera: Camera3D = world.player.camera
	var head := feet + Vector3.UP * 1.6
	var offset := head - camera.global_position
	if offset.length() < 3:
		return true
	# Include a margin around the horizontal field of view for the whole body.
	var aspect := camera.get_viewport().get_visible_rect().size.aspect()
	var half_angle := atan(tan(deg_to_rad(camera.fov * 0.5)) * aspect) + deg_to_rad(7)
	if -camera.global_basis.z.dot(offset.normalized()) < cos(half_angle):
		return false
	for height in [0.6, 1.6, 2.4]:
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, feet + Vector3.UP * height, 5)
		ray.exclude = [world.player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return true
	return false

func safe_spawn(feet: Vector3, enemy: CharacterBody3D) -> bool:
	if world.progression != null and not world.progression.sector_accessible(feet):
		return false
	var p: CharacterBody3D = world.player
	var distance := feet.distance_to(p.global_position)
	if distance < 14 or distance > 38 or absf(feet.y - p.global_position.y) > 0.7 or world.is_soul_sanctuary(feet) or visible_to_player(feet):
		return false
	for other in world.enemies:
		if other != enemy and not other.dormant and feet.distance_to(other.global_position) < 7:
			return false
	var map: RID = world.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, p.global_position, feet, true)
	if path.is_empty() or path[-1].distance_to(feet) > 0.7:
		return false
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	if length > 60:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.40
	capsule.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 7
	query.exclude = [enemy.get_rid()]
	query.transform.origin = feet + Vector3.UP * 1.25
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func wake_one() -> bool:
	if world.enemies.is_empty() or world.player.is_hidden() or world.player.combat.busy() or world.is_soul_sanctuary(world.player.global_position) or rest_remaining > 0 or reserved_count() >= world.max_active_ghosts:
		return false
	var map: RID = world.get_world_3d().navigation_map
	var candidates: Array[Vector3] = world.campus_patrol_route(0)
	candidates.append_array([Vector3(-30, 0, 64), Vector3(30, 0, 64), Vector3(0, 0, 76), Vector3(-23.5, 0, 54), Vector3(23.5, 0, 54)])
	# Alternate students and specialized actors instead of exhausting all bullies first.
	var bullies: Array = world.enemies.filter(func(e): return e.archetype == "bully")
	var specials: Array = world.enemies.filter(func(e): return e.archetype != "bully")
	var ordered: Array[CharacterBody3D] = []
	for i in range(maxi(bullies.size(), specials.size())):
		if i < bullies.size():
			ordered.append(bullies[i])
		if i < specials.size():
			ordered.append(specials[i])
	for step in range(ordered.size()):
		var index := (next_actor + step) % ordered.size()
		var enemy: CharacterBody3D = ordered[index]
		if not enemy.dormant:
			continue
		for candidate in candidates:
			var feet := NavigationServer3D.map_get_closest_point(map, candidate) + Vector3.UP * 0.05
			if not safe_spawn(feet, enemy):
				continue
			enemy.global_position = feet
			enemy.patrol_home = feet
			enemy.patrol_last_position = feet
			enemy.patrol_stuck_time = 0
			enemy.path_clock = 0
			var nearest := INF
			for i in range(enemy.patrol_route.size()):
				var distance := feet.distance_squared_to(enemy.patrol_route[i])
				if distance < nearest:
					nearest = distance
					enemy.patrol_index = i
			enemy.set_dormant(false)
			ages[enemy] = 0
			next_actor = (index + 1) % ordered.size()
			return true
	return false
