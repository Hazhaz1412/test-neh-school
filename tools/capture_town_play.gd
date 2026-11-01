extends SceneTree
# Gameplay look check: godot --path . --script tools/capture_town_play.gd --resolution 1600x900
var town: Node3D

func _initialize() -> void:
	call_deferred("run")

func shot(title: String) -> void:
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/town-play-%s.png" % title)
	print(title, " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " tris ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " fps ", Engine.get_frames_per_second())

func place(at: Vector2, heading: float) -> void:
	var player: CharacterBody3D = town.player
	player.global_position = Vector3(at.x, town.plan.ground(at), at.y)
	player.heading = heading
	player.look_yaw = heading
	player.bike.global_position = player.global_position

func run() -> void:
	town = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	await create_timer(3.6).timeout
	var player: CharacterBody3D = town.player
	await shot("start")
	player.toggle_bike()
	player.scripted = true
	place(Vector2(-60, 2), PI * 0.5)
	await shot("ride-main")
	place(Vector2(-31, 16), PI)
	await shot("ride-alley")
	place(Vector2(100, -4), -PI * 0.5)
	await shot("ride-bridge")
	town.hud.map_open = true
	await shot("map")
	town.hud.map_open = false
	var shop: Vector3 = town.story.people["sau"].global_position
	place(Vector2(shop.x + 3.0, shop.z), PI * 0.5)
	await shot("near-shop")
	player.first_person = false
	var keeper: Node3D = town.story.people["sau"]
	var spare := Camera3D.new()
	town.add_child(spare)
	spare.current = true
	var lot: Dictionary = town.plan.place_lot("shop")
	var front: Vector3 = keeper.global_position - Vector3(lot.normal.x, 0, lot.normal.y) * 2.2 + Vector3.UP * 1.3
	spare.look_at_from_position(front, keeper.global_position + Vector3.UP * 0.8)
	await shot("seated")
	spare.global_position = player.global_position + Vector3(2.4, 1.2, 0.6)
	spare.look_at(player.global_position + Vector3.UP * 0.7)
	await shot("rider-side")
	spare.global_position = player.global_position + player.forward() * 2.8 + Vector3.UP * 1.2
	spare.look_at(player.global_position + Vector3.UP * 0.8)
	await shot("rider-front")
	player.camera.make_current()
	spare.queue_free()
	quit()
