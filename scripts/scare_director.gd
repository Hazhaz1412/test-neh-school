extends Node3D

# One cached visual event at a time, separate from the dangerous enemy pool.
enum Kind { BLACKOUT, LAMP_POP, THROWN_CHAIR, LAUGHING_STUDENT }
@export var enabled := true
@export var interval_min := 32.0
@export var interval_max := 62.0
@export var zone_cooldown := 100.0
var world: Node3D
var rng := RandomNumberGenerator.new()
var wait := 25.0
var age := 0.0
var travelled := 0.0
var last_feet := Vector3.ZERO
var last_kind := -1
var active_kind := -1
var clock := 0.0
var duration := 0.0
var zones := {}
var selected_lights: Array[OmniLight3D] = []
var saved_energies := {}
var lamp_tubes := {}
var dark_tubes: Array[MeshInstance3D] = []
var from := Vector3.ZERO
var to := Vector3.ZERO
var apparition: Node3D
var chair: Node3D
var sound: AudioStreamPlayer3D
var sparks: CPUParticles3D
var hit_played := false
var capsule := CapsuleShape3D.new()

func setup(school: Node3D) -> void:
	world = school
	name = "ScareDirector"
	process_priority = 30 # Apply the light envelope after world's ordinary flicker.
	rng.randomize()
	capsule.radius = 0.38
	capsule.height = 1.8
	apparition = preload("res://scripts/teasing_apparition.gd").new()
	add_child(apparition)
	chair = Node3D.new()
	chair.name = "PoltergeistChair"
	add_child(chair)
	var source: Node3D = preload("res://assets/kenney_furniture/chair.glb").instantiate()
	chair.add_child(source)
	var bounds := AABB()
	var first := true
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = source.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
		mesh.material_override = world.realm_scenery.cursed_material(null, 2)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scale_by := 0.85 / bounds.size.y
	source.scale = Vector3.ONE * scale_by
	source.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_by
	chair.hide()
	sound = AudioStreamPlayer3D.new()
	sound.max_distance = 22
	sound.unit_size = 4
	sound.volume_db = -12
	add_child(sound)
	sparks = CPUParticles3D.new()
	sparks.amount = 14
	sparks.one_shot = true
	sparks.lifetime = 0.45
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.DOWN
	sparks.spread = 65
	sparks.gravity = Vector3(0, -7, 0)
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 3.5
	sparks.scale_amount_min = 0.015
	sparks.scale_amount_max = 0.035
	sparks.mesh = SphereMesh.new()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.72, 0.25)
	sparks.material_override = glow
	sparks.emitting = false
	add_child(sparks)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.035, 0.045, 0.045)
	for index in range(3):
		var tube := MeshInstance3D.new()
		tube.mesh = BoxMesh.new()
		tube.material_override = dark
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tube)
		tube.hide()
		dark_tubes.append(tube)
	reset()

func cache_lamp_tubes() -> void:
	# Only touch the individual emissive tube, never its whole shared batch.
	# Persisted placements also work with the headless renderer's empty buffers.
	if not world.has_node("RuntimeGeometry"):
		return
	for batch in world.get_node("RuntimeGeometry").get_children():
		if not batch.multimesh.mesh is BoxMesh:
			continue
		for index in range(batch.multimesh.placements.size()):
			var pose: Transform3D = batch.multimesh.placements[index]
			if not pose.basis.get_scale().is_equal_approx(Vector3(0.2, 0.035, 1.4)):
				continue
			var global_pose: Transform3D = batch.global_transform * pose
			for light in world.local_lights:
				if global_pose.origin.distance_to(light.global_position + Vector3.UP * 0.24) < 0.03:
					lamp_tubes[light] = {"batch": batch, "index": index, "pose": pose, "global_pose": global_pose}
					break

func reset() -> void:
	cancel()
	wait = rng.randf_range(20, 32)
	age = 0
	travelled = 0
	last_kind = -1
	zones.clear()
	last_feet = world.player.global_position

func protected_moment() -> bool:
	if world.progression.tutorial_active() or not world.simulation_active() or world.map_panel.visible or world.player.is_hidden() or world.player.combat.busy():
		return true
	if world.is_soul_sanctuary(world.player.global_position) or world.soul_quest.panel_visible() or world.progression.panel_visible():
		return true
	if world.camera_flash.remaining > 0 or world.player.combat.adrenaline_remaining > 0:
		return true
	for enemy in world.enemies:
		if not enemy.active or enemy.dormant or enemy.banished_remaining > 0:
			continue
		var distance: float = enemy.global_position.distance_to(world.player.global_position)
		if distance < 5 or distance < 15 and enemy.state in [2, 3, 4]:
			return true
	return false

func _process(delta: float) -> void:
	if not enabled or not world.spirit_enabled or world.player.health <= 0 or world.survival.finished or world.survival.opening.playing:
		cancel()
		last_feet = world.player.global_position
		return
	if world.paused_by_user:
		sound.stream_paused = true
		apparition.model.animation.speed_scale = 0
		sparks.speed_scale = 0
		_apply_lighting()
		return
	sound.stream_paused = false
	sparks.speed_scale = 1
	if protected_moment():
		if active_kind >= 0:
			cancel()
		last_feet = world.player.global_position
		return
	age += delta
	travelled += minf(2, world.player.global_position.distance_to(last_feet))
	last_feet = world.player.global_position
	if active_kind >= 0:
		clock += delta
		_update_event()
		return
	wait = maxf(0, wait - delta)
	if wait > 0 or travelled < 6:
		return
	var choices := [Kind.BLACKOUT, Kind.LAMP_POP, Kind.THROWN_CHAIR, Kind.LAUGHING_STUDENT]
	choices.erase(last_kind)
	var chosen: int = choices[rng.randi_range(0, choices.size() - 1)]
	if not try_start(chosen):
		wait = 3 # A blocked corridor is not permission to put a face inside a wall.

func _zone(feet: Vector3) -> String:
	return "%d/%d/%d" % [floori(feet.x / 18), floori(feet.z / 18), roundi(feet.y / 3.9)]

func try_start(kind: int) -> bool:
	if not enabled or not world.spirit_enabled or active_kind >= 0 or protected_moment():
		return false
	var zone := _zone(world.player.global_position)
	if float(zones.get(zone, -1000)) + zone_cooldown > age:
		return false
	if kind in [Kind.BLACKOUT, Kind.LAMP_POP]:
		if not _select_lights(1 if kind == Kind.LAMP_POP else 3):
			return false
	else:
		var stage := _find_stage()
		if stage.is_empty():
			return false
		from = stage[0]
		to = stage[1]
	active_kind = kind
	last_kind = kind
	zones[zone] = age
	clock = 0
	hit_played = false
	travelled = 0
	wait = rng.randf_range(interval_min, interval_max)
	duration = [1.65, 2.0, 2.1, 2.5][kind]
	if kind == Kind.LAUGHING_STUDENT:
		apparition.appear(from, world.player.global_position)
		world.player.startle = maxf(world.player.startle, 0.38)
		_play(preload("res://assets/audio/teasing_giggle.ogg"), from + Vector3.UP * 1.5, 0.94)
	elif kind == Kind.THROWN_CHAIR:
		chair.global_position = from
		chair.rotation = Vector3(0.12, rng.randf_range(-PI, PI), 0.1)
		chair.show()
		_play(preload("res://assets/audio/chair_scrape.wav"), from, 1.0)
	else:
		_play(preload("res://assets/audio/lamp_crackle.wav"), selected_lights[0].global_position, 1.0)
	return true

func _play(stream: AudioStream, at: Vector3, pitch: float) -> void:
	sound.stream = stream
	sound.global_position = at
	sound.pitch_scale = pitch
	sound.play()

func _update_event() -> void:
	_apply_lighting()
	match active_kind:
		Kind.LAMP_POP:
			if clock >= 0.22 and not hit_played:
				hit_played = true
				sparks.global_position = selected_lights[0].global_position + Vector3.UP * 0.22
				sparks.show()
				sparks.restart()
				sparks.emitting = true
				_play(preload("res://assets/audio/lamp_pop.wav"), sparks.global_position, 1)
				world.player.startle = maxf(world.player.startle, 0.45)
		Kind.THROWN_CHAIR:
			var progress := clampf((clock - 0.12) / 0.28, 0, 1)
			chair.global_position = from.lerp(to, progress) + Vector3.UP * sin(progress * PI) * 0.25
			chair.rotation.z = progress * 1.3
			sound.global_position = chair.global_position
			if progress >= 1 and not hit_played:
				hit_played = true
				_play(preload("res://assets/audio/chair_impact.wav"), to, 1)
				world.player.startle = maxf(world.player.startle, 0.30)
		Kind.LAUGHING_STUDENT:
			if clock > 0.75:
				if not hit_played:
					hit_played = true
					apparition.retreat((to - from).normalized())
				apparition.model.animation.speed_scale = 2.6
				apparition.global_position = from.lerp(to, clampf((clock - 0.75) / 0.4, 0, 1))
			else:
				apparition.model.animation.speed_scale = 0.8
				apparition.face.rotation.z = -0.4 + sin(clock * 16) * 0.07
			sound.global_position = apparition.global_position + Vector3.UP * 1.5
			if clock > 1.35:
				apparition.vanish()
	if clock >= duration:
		cancel()

func _apply_lighting() -> void:
	if active_kind not in [Kind.BLACKOUT, Kind.LAMP_POP]:
		return
	var factor := 1.0
	if active_kind == Kind.BLACKOUT:
		factor = 0.04 if clock > 0.15 and clock < 1.25 else (0.25 if sin(clock * 55) > 0 else 0.8)
	else:
		factor = 0.05 if clock > 0.22 and clock < 1.45 else (0.18 if sin(clock * 70) > 0 else 0.9)
	if clock > duration - 0.3:
		factor = lerpf(0.04, 1.0, clampf((clock - duration + 0.3) / 0.3, 0, 1))
	for index in range(selected_lights.size()):
		var light: OmniLight3D = selected_lights[index]
		if is_instance_valid(light):
			# World's flicker rewrites its base every frame; ordinary lights don't.
			var base: float = world.flicker_energy(light) if light.has_meta("flicker") else saved_energies[light]
			light.light_energy = base * factor
			if lamp_tubes.has(light):
				var entry: Dictionary = lamp_tubes[light]
				var pose: Transform3D = entry.pose
				if factor < 0.4:
					pose.basis = Basis().scaled(Vector3.ZERO)
					dark_tubes[index].global_transform = entry.global_pose
				entry.batch.multimesh.set_instance_transform(entry.index, pose)
				dark_tubes[index].visible = factor < 0.4

func _select_lights(limit: int) -> bool:
	selected_lights.clear()
	saved_energies.clear()
	for light in world.local_lights:
		if light.visible and absf(light.global_position.y - world.player.global_position.y - 2.4) < 1.8 and light.global_position.distance_to(world.player.global_position) < 12:
			var ray := PhysicsRayQueryParameters3D.create(world.player.camera.global_position, light.global_position - Vector3.UP * 0.15, 5)
			if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				selected_lights.append(light)
				saved_energies[light] = light.light_energy
				if selected_lights.size() == limit:
					break
	return not selected_lights.is_empty()

func _clear_at(feet: Vector3) -> bool:
	if world.is_soul_sanctuary(feet) or not world.progression.sector_accessible(feet):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 5
	query.exclude = [world.player.get_rid()]
	query.transform.origin = feet + Vector3.UP * 0.95
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _floor_at(feet: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.6, feet - Vector3.UP * 0.7, 5)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85:
		return Vector3.INF
	return hit.position + Vector3.UP * 0.05

func _find_stage() -> Array[Vector3]:
	var p: CharacterBody3D = world.player
	var ahead: Vector3 = -p.camera.global_basis.z
	ahead.y = 0
	if ahead.length_squared() < 0.1:
		return []
	ahead = ahead.normalized()
	var right := ahead.cross(Vector3.UP)
	for distance in [4.2, 5.5, 7.5]:
		for offset in [0.0, -0.5, 0.5]:
			var point := _floor_at(p.global_position + ahead * distance + right * offset)
			if not point.is_finite() or absf(point.y - p.global_position.y) > 0.22 or not _clear_at(point):
				continue
			var ray := PhysicsRayQueryParameters3D.create(p.camera.global_position, point + Vector3.UP * 1.3, 5)
			if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			for direction in [right, -right, ahead]:
				var end := _floor_at(point + direction * 1.8)
				if not end.is_finite() or absf(end.y - point.y) > 0.18:
					continue
				var clear := true
				for step in range(7):
					clear = clear and _clear_at(point.lerp(end, step / 6.0))
				if clear:
					return [point, end]
	return []

func cancel() -> void:
	for light in selected_lights:
		if is_instance_valid(light):
			light.light_energy = saved_energies[light]
			if lamp_tubes.has(light):
				var entry: Dictionary = lamp_tubes[light]
				entry.batch.multimesh.set_instance_transform(entry.index, entry.pose)
	for tube in dark_tubes:
		tube.hide()
	selected_lights.clear()
	saved_energies.clear()
	active_kind = -1
	if apparition != null:
		apparition.vanish()
	if chair != null:
		chair.hide()
	if sound != null:
		sound.stop()
	if sparks != null:
		sparks.emitting = false
		sparks.hide()
	clock = 0
