extends SceneTree
# The title cards between scenes: godot --path . --resolution 1280x720 --script tools/capture_cards.gd -- <folder>
var out := ""

func shot(title: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("card_" + title + ".png"))

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var home: Node3D = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	current_scene = home
	await wait(0.3)
	var story: Node = home.story
	home.fade.show()
	home.fade.modulate.a = 1.0
	story.consent = false
	story._arrive()
	await wait(0.6)
	await shot("arrive")
	await wait(3.0)
	story.step = "gaaglu"
	story.opened_gaaglu = true
	story._bed()
	await wait(2.2)
	await shot("sleep")
	var cards := 0
	for child in home.fade.get_children():
		if child is Label:
			cards += 1
	print(("PASS  " if cards == 1 else "FAIL  ") + "one card over the black: %d" % cards)
	await wait(2.0)
	var town: Node3D = current_scene
	print("now in ", town.name)
	await wait(0.6)
	await shot("town")
	await wait(4.0)
	town.enter_night()
	await wait(1.4)
	await shot("night")
	quit()
