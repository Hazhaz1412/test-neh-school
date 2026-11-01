extends SceneTree
# Look check: godot --path . --script tools/capture_town.gd --resolution 1600x900 -- [names]
const VIEWS := {
	"overview": [Vector3(-40, 120, 150), Vector3(-30, 0, -30)],
	"main": [Vector3(-46, 1.7, 2), Vector3(-120, 3, 5)],
	"junction": [Vector3(-60, 1.7, -5), Vector3(-82, 4, 0)],
	"alley": [Vector3(-31, 1.7, 12), Vector3(-33, 3, 40)],
	"river": [Vector3(66, 1.7, -30), Vector3(110, 1, -2)],
	"bridge": [Vector3(100, 5, -2), Vector3(200, 2, 12)],
	"school": [Vector3(232, 1.7, 26), Vector3(262, 3, 26)],
	"market": [Vector3(-82, 1.7, 48), Vector3(-104, 3, 48)],
	"curio": [Vector3.ZERO, Vector3.ONE],
}
var town: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	town = load("res://scenes/town.tscn").instantiate()
	root.add_child(town)
	current_scene = town
	var started := Time.get_ticks_msec()
	await process_frame
	print("load ms ", Time.get_ticks_msec() - started)
	town.hud.visible = false
	var camera := Camera3D.new()
	town.add_child(camera)
	camera.far = 1000.0
	camera.current = true
	var names: Array = OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else VIEWS.keys()
	for title in names:
		var lot: Dictionary = town.plan.place_lot("curio")
		var door := Vector3(lot.front.x, 1.7, lot.front.y)
		var street := Vector3(lot.normal.x, 0, lot.normal.y)
		var at: Array = [door - street * 1.0 + Vector3(lot.normal.y, 0, -lot.normal.x) * 2.8, door + street * 2.0] if title == "curio" else VIEWS[title]
		camera.look_at_from_position(at[0], at[1])
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/town-%s.png" % title)
		print(title, " draws ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " tris ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " fps ", Engine.get_frames_per_second())
	print("triangles ", town.builder.triangles)
	quit()
