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
	check(fold.door_hinge.rotation.y < -0.5, "the door swings open")
	await create_timer(6.0).timeout
	check(current_scene != null and current_scene.scene_file_path == next_scene, "and it is the next morning (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	print("failures: %d" % failures)
	quit(failures)
