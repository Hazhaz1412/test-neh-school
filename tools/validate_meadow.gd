extends SceneTree
# godot --headless --path . --script tools/validate_meadow.gd
# The meadow dream after Night 1: it opens dark, the ground the player stands on is the ground
# that is drawn, the walk to the one bright place is on real physics over the hills, reaching it
# turns the day and brings the fish and bubbles, the field turns you back at its edge. Lying on
# the bed, the eyes blink shut and fairground music opens them on night; the meadow is now the
# floor of a box of meadow, and it is walked round for real, gravity turning with it: up the wall
# through the fairground, round the top corner and along the ceiling to the house, whose door
# leads on to the next morning. Up is checked all the way round the box. Also: Night 1's chapter
# leads here.
var failures := 0
var meadow: Node3D
var p: CharacterBody3D

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: failures += 1

func _initialize() -> void:
	preload("res://scripts/game_progress.gd").recording = false
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n): await physics_frame

# Head for a point; true once within `near` metres of it. Steers in the player's own gravity frame.
func walk_to(target: Vector3, near: float, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		var to: Vector3 = p.frame.transposed() * (target - p.global_position)
		to.y = 0
		if to.length() < near:
			p.drive = Vector2.ZERO
			return true
		p.yaw = atan2(-to.x, -to.z)
		p.drive = Vector2(0, -1)
		left -= 1.0 / 60.0
		await physics_frame
	p.drive = Vector2.ZERO
	return false

# Walk on through a doorway (the way into it, -Z of its frame) until the world changes to `to`.
func go_through(door: Node3D, to: String) -> bool:
	var left := 8.0
	while left > 0.0:
		if meadow.where == to:
			p.drive = Vector2.ZERO
			return true
		var target: Vector3 = door.to_global(Vector3(0, 0, -2.0))
		var to_local: Vector3 = p.frame.transposed() * (target - p.global_position)
		to_local.y = 0
		var ahead: Vector3 = p.frame.transposed() * -door.global_basis.z
		var aim := to_local if door.to_local(p.global_position).z > 0.6 else ahead
		p.yaw = atan2(-aim.x, -aim.z)
		p.drive = Vector2(0, -1)
		left -= 1.0 / 60.0
		await physics_frame
	p.drive = Vector2.ZERO
	print("     stuck at %s (%s)" % [p.global_position, meadow.where])
	return false

func run() -> void:
	var progress := preload("res://scripts/game_progress.gd")
	var night := progress.index_of("night1")
	check(progress.index_of("meadow") == night + 1, "the meadow is the chapter after Night 1")
	var world_source: String = (load("res://scripts/world.gd") as GDScript).source_code
	check(world_source.contains("res://scenes/dream_meadow.tscn"), "winning Night 1 goes home to sleep, into the meadow")
	change_scene_to_file("res://scenes/dream_meadow.tscn")
	await frames(3)
	meadow = current_scene
	p = meadow.player
	check(meadow.state == "wake" and not p.enabled and meadow.bright == 0.0, "opens in the dark, eyes still closed")
	check(meadow.sky_material.get_shader_parameter("bright") == 0.0, "the sky starts dark")
	await create_timer(3.4).timeout
	check(meadow.state == "walk" and p.enabled, "then the player can walk")
	# Stand still a moment: the feet rest on the drawn ground.
	await frames(30)
	var drawn: float = meadow.ground_height(p.global_position.x, p.global_position.z)
	check(absf(p.global_position.y - drawn) < 0.15, "standing on the ground that is drawn (%.2f vs %.2f)" % [p.global_position.y, drawn])
	for spot in [Vector2(40, 40), Vector2(-60, 20), Vector2(25, -70)]:
		var space := p.get_world_3d().direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(Vector3(spot.x, 80, spot.y), Vector3(spot.x, -40, spot.y))
		var hit := space.intersect_ray(ray)
		var want: float = meadow.ground_height(spot.x, spot.y)
		check(not hit.is_empty() and absf(hit.position.y - want) < 0.25, "collider and drawn ground agree at %s (%.2f vs %.2f)" % [spot, hit.get("position", Vector3.ZERO).y, want])
	check(not meadow.fishes[0].node.visible, "no fish yet")
	# The walk over the hills to the bright place.
	check(await walk_to(Vector3.ZERO, meadow.LIGHT_RADIUS - 1.0, 60.0), "walked over the hills into the light (at %s)" % p.global_position)
	await frames(5)
	check(meadow.lit, "reaching the light starts the change")
	await create_timer(meadow.BRIGHTEN_TIME + 1.5).timeout
	check(meadow.bright >= 1.0 and meadow.sky_material.get_shader_parameter("bright") > 0.99, "the sky has cleared")
	var shown := 0
	for fish in meadow.fishes:
		if fish.node.visible: shown += 1
	check(shown == meadow.fishes.size(), "the fish are swimming in the air (%d)" % shown)
	check(meadow.bubbles.get_shader_parameter("appear") > 0.9, "bubbles drift up")
	var before: Vector3 = meadow.fishes[0].node.position
	await frames(30)
	check(meadow.fishes[0].node.position.distance_to(before) > 0.2, "and they move")
	# The edge of the dream.
	p.global_position = meadow.on_ground(0, meadow.WALK_LIMIT + 5.0) + Vector3(0, 0.2, 0)
	await frames(5)
	p.yaw = PI
	p.drive = Vector2(0, -1)
	await create_timer(4.0).timeout
	p.drive = Vector2.ZERO
	var out := Vector2(p.global_position.x, p.global_position.z).length()
	check(out < meadow.WALK_LIMIT + 6.0 and out > meadow.WALK_LIMIT - 10.0, "the meadow holds the player at its edge, gently (%.1f m out)" % out)
	# The bed.
	var next_scene: String = meadow.NEXT_SCENE
	var bed: Node3D = meadow.bed
	p.global_position = bed.global_position + Vector3(1.4, 0.3, 1.4)
	await frames(10)
	check(meadow.near_bed(), "beside the bed: E to lie down")
	meadow.lie_down()
	check(meadow.state == "lie" and not p.enabled, "lying down")
	await create_timer(5.5).timeout
	check(meadow.state == "blink", "the eyes close")
	await create_timer(1.8).timeout
	check(meadow.lids.get_shader_parameter("open") < 0.05, "shut")
	await create_timer(1.0).timeout
	check(meadow.night and meadow.sky_material.get_shader_parameter("night") == 1.0, "and it is night behind them")
	var fold: Node3D = meadow.fold
	check(fold.visible and meadow.fishes.is_empty(), "the meadow has folded up, the fish are gone")
	check(fold.music.playing and fold.music.volume_db > -20.0, "fairground music is playing")
	while meadow.state != "walk":
		await physics_frame
	check(p.enabled and meadow.lids.get_shader_parameter("open") > 0.95, "eyes open, up off the bed")
	# Up is smooth all the way round the box, and matches each face.
	var worst := 0.0
	var k := 0.0
	while k < fold.around:
		var on: Vector3 = fold.point(5.0, k) + fold.up_of(k) * 0.4
		worst = maxf(worst, rad_to_deg((fold.up_at(on) as Vector3).angle_to(fold.up_of(k))))
		k += 0.5
	check(worst < 3.0, "gravity follows the box all the way round (worst %.1f°)" % worst)
	var start := p.global_position
	var steepest := 0.0
	var steepest_at := Vector3.ZERO
	var behind_is_ground := false
	var timer := 0.0
	# Over the corner and up the wall into the fair, then along the path to the house.
	var route: Array[Vector3] = []
	var s := 0.0
	while s < fold.fair_s + fold.PLAZA + 1.0:
		route.append(fold.point(3.0, s))
		s += 4.0
	s = fold.fair_s + fold.PLAZA + 1.0
	while s < fold.house_s - 4.0:
		route.append(fold.point(0.0, s))
		s += 4.0
	var reached := true
	p.drive_run = true
	for target in route:
		var left := 12.0
		while left > 0.0:
			var to: Vector3 = p.frame.transposed() * (target - p.global_position)
			to.y = 0
			if to.length() < 1.6:
				break
			p.yaw = atan2(-to.x, -to.z)
			p.drive = Vector2(0, -1)
			if p.is_on_floor():
				var slope := rad_to_deg(p.get_floor_normal().angle_to(p.frame.y))
				if slope > steepest:
					steepest = slope
					steepest_at = p.global_position
			if not behind_is_ground and p.frame.y.dot(Vector3(0, 0, 1)) > 0.99 and p.global_position.y > 40.0:
				var eye: Vector3 = p.camera.global_position
				var ray := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, -1, 0.15).normalized() * 200.0)
				ray.exclude = [p.get_rid()]
				var hit := p.get_world_3d().direct_space_state.intersect_ray(ray)
				behind_is_ground = not hit.is_empty() and hit.position.y < 6.0
			left -= 1.0 / 60.0
			timer += 1.0 / 60.0
			await physics_frame
		if left <= 0.0:
			reached = false
			print("     stuck going to %s, at %s" % [target, p.global_position])
			break
	p.drive = Vector2.ZERO
	p.drive_run = false
	check(reached and fold.told_fair, "walked over the corner, up the wall and through the fairground")
	check(reached and fold.told_house, "and round the top corner along the path to the house (%.0f s from the bed, running)" % timer)
	check(timer < 50.0, "and running there is not long")
	check(steepest < 8.0, "the ground never felt like a slope underfoot (steepest %.1f° at %s)" % [steepest, steepest_at])
	check(behind_is_ground, "on the wall, looking back down: the meadow stands like a wall")
	check(p.frame.y.dot(Vector3.DOWN) > 0.99 and p.is_on_floor(), "standing on the ceiling, up is down now")
	var eye: Vector3 = p.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + p.frame.y * 400.0)
	ray.exclude = [p.get_rid()]
	var overhead := p.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not overhead.is_empty() and absf(overhead.position.y - meadow.ground_height(overhead.position.x, overhead.position.z)) < 0.5, "looking up from the ceiling, the meadow with the bed is overhead")
	for marker in ["GameStall1", "GameStall2", "GameStall3", "GameStriker", "GameCarousel"]:
		check(fold.fair.has_node(marker), "a place kept for a game: " + marker)
	check(fold.house.has_node("Inside"), "a place kept for the inside of the house")
	var door: Vector3 = fold.house.to_global(Vector3(-0.9, 0.0, 3.6))
	check(await walk_to(door, 0.6, 15.0), "up to the door")
	await frames(3)
	check(fold.near_door(p.global_position), "E · open the door")
	meadow.open_house()
	await create_timer(1.5).timeout
	check(fold.door_hinge.rotation.y > 0.5, "the door swings in")
	var inside: Node3D = meadow.inside
	check(inside.portal_out.open > 0.9, "and the doorway already shows the inside")
	p.yaw = atan2(-(p.frame.transposed() * -fold.door_frame.global_basis.z).x, -(p.frame.transposed() * -fold.door_frame.global_basis.z).z)
	p.pitch = 0.0
	await frames(3)
	check(inside.portal_out.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "drawn while looked at")
	check(await go_through(inside.portal_out, "room"), "walked through the door into the house")
	check(p.frame.y.dot(Vector3.UP) > 0.99, "the room's floor is down")
	await frames(20)
	check(p.is_on_floor() and p.global_position.distance_to(inside.portal_room.global_position) < 3.0, "standing just inside the little door")
	var eye_in: Vector3 = p.camera.global_position
	var up_ray := PhysicsRayQueryParameters3D.create(eye_in, eye_in + Vector3.UP * 100.0)
	up_ray.exclude = [p.get_rid()]
	var ceiling := p.get_world_3d().direct_space_state.intersect_ray(up_ray)
	check(not ceiling.is_empty() and ceiling.position.y - eye_in.y > 35.0, "and the ceiling is forty metres up (%.0f m)" % (ceiling.get("position", eye_in).y - eye_in.y))
	check(p.camera.environment == inside.room_environment, "the room's own light")
	# Back out the same door, and in again.
	check(await go_through(inside.portal_room, "box"), "back out through the little door")
	check(p.frame.y.dot(Vector3.DOWN) > 0.99 and p.global_position.distance_to(fold.door_frame.global_position) < 2.5, "out on the step, on the ceiling again")
	await frames(20)
	check(await go_through(inside.portal_out, "room"), "and in again")
	# Up the book stairs onto the table.
	var room_at: Vector3 = inside.ROOM_AT
	var foot: Vector3 = room_at + inside.stair_step(0)
	var outward := Vector3(foot.x - room_at.x - inside.TABLE_AT.x, 0, foot.z - room_at.z - inside.TABLE_AT.z).normalized()
	check(await walk_to(foot + outward * 3.5, 1.0, 40.0), "across the room to the books (%s)" % (p.global_position - room_at))
	var climbed := true
	for i in range(inside.stair_count):
		if not await walk_to(room_at + inside.stair_step(i), 0.7, 6.0):
			climbed = false
			print("     stuck on book %d at %s" % [i, p.global_position - room_at])
			break
	check(climbed, "up the spiral of books")
	var globe: Vector3 = inside.globe_centre()
	var flat := Vector3(p.global_position.x - globe.x, 0, p.global_position.z - globe.z).normalized()
	check(await walk_to(globe + flat * 3.3, 0.5, 10.0), "onto the table, beside the glass ball (%s from the ball)" % (p.global_position - globe))
	await frames(5)
	check(inside.near_globe(p.global_position), "E · touch the ball")
	meadow.touch_globe()
	await create_timer(inside.ZOOM_OVER + inside.ZOOM_DOWN * 0.5).timeout
	check(p.camera.global_position.distance_to(globe) < inside.GLOBE_R, "falling into the glass")
	await create_timer(inside.ZOOM_DOWN * 0.5 + 0.5).timeout
	check(meadow.state == "walk" and meadow.where == "planet", "standing on the tiny planet")
	await frames(30)
	check(p.is_on_floor() and absf(p.global_position.distance_to(inside.PLANET_AT) - inside.PLANET_R) < 0.3, "on its ground")
	var house_door: Vector3 = inside.planet_house.to_global(Vector3(fold.DOOR_X, 0, fold.HOUSE_D / 2 + 1.1))
	var on_planet_from: Vector3 = p.global_position - inside.PLANET_AT
	check(await walk_to(house_door, 0.4, 20.0), "over the curve to the little house (from %s, at %s, door %s)" % [on_planet_from, p.global_position - inside.PLANET_AT, house_door - inside.PLANET_AT])
	var radial: Vector3 = (p.global_position - inside.PLANET_AT).normalized()
	check(p.frame.y.dot(radial) > 0.995, "gravity pulls to the planet's middle")
	await frames(3)
	check(inside.near_planet_door(p.global_position), "E · open its door")
	inside.open_planet_door()
	await create_timer(1.6).timeout
	var house_way: Node3D = inside.portal_planet
	check(house_way.hand_over and house_way.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "its doorway shows the meadow as it first was")
	var old := meadow
	var left := 8.0
	while left > 0.0 and current_scene == old:
		var aim: Vector3 = p.frame.transposed() * -house_way.global_basis.z
		p.yaw = atan2(-aim.x, -aim.z)
		p.drive = Vector2(0, -1)
		left -= 1.0 / 60.0
		await physics_frame
	check(current_scene != old, "stepped through it")
	meadow = current_scene
	await frames(5)
	p = meadow.player
	check(meadow.again and not meadow.night and not meadow.lit and meadow.state == "walk" and p.enabled, "the dark meadow from the start, again")
	var start_at: Vector3 = meadow.on_ground(meadow.START.x, meadow.START.z)
	check(Vector2(p.global_position.x - start_at.x, p.global_position.z - start_at.z).length() < 3.0, "standing where the dream began (%s)" % p.global_position)
	await frames(30)
	check(p.is_on_floor() and absf(p.global_position.y - meadow.ground_height(p.global_position.x, p.global_position.z)) < 0.15, "on its ground")
	check(not is_instance_valid(old), "the box, the room and the planet are gone")
	check(await walk_to(Vector3.ZERO, meadow.LIGHT_RADIUS - 1.0, 60.0), "back over the hills into the light")
	await frames(5)
	check(meadow.lit, "it turns day again")
	var bed2: Node3D = meadow.bed
	check(await walk_to(bed2.global_position + Vector3(1.4, 0, 1.4), 0.4, 15.0), "to the bed")
	await frames(5)
	check(meadow.near_bed(), "E to lie down")
	meadow.lie_down()
	await create_timer(5.5 + meadow.NIGHT_AT + 5.0).timeout
	check(current_scene != null and current_scene.scene_file_path == next_scene, "and this time sleeping there wakes the player up (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	print("failures: %d" % failures)
	quit(failures)
