extends SceneTree
# godot --headless --path . --script tools/validate_meadow.gd
# The meadow dream after Night 1: it opens dark, the ground the player stands on is the ground
# that is drawn, the walk to the one bright place is on real physics over the hills, reaching it
# turns the day and brings the fish and bubbles, the field turns you back at its edge, and lying
# on the bed ends the dream in the next morning. Also: Night 1's chapter leads here.
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

# Head for a point on the ground; true once within `near` metres of it.
func walk_to(target: Vector3, near: float, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		var to := target - p.global_position
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
	await create_timer(9.5).timeout
	check(meadow.state == "leave", "falling asleep in the dream")
	await create_timer(4.5).timeout
	check(current_scene != null and current_scene.scene_file_path == next_scene, "and it is the next morning (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	print("failures: %d" % failures)
	quit(failures)
