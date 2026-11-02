extends SceneTree
# Main menu, chapters, progress and settings on the real scenes.
const Progress := preload("res://scripts/game_progress.gd")
const Settings := preload("res://scripts/game_settings.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func labels(menu: Control) -> Array:
	return menu.column.get_children().filter(func(c): return c is Button).map(func(c): return c.text)

func run() -> void:
	Progress.path = "user://test_progress.cfg"
	Progress.wipe()
	var old: float = Settings.read("brightness_value")
	check(load(ProjectSettings.get_setting("application/run/main_scene")).instantiate() is Control, "the game opens on the menu")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(not labels(menu).any(func(t): return t.begins_with("Tiếp tục")), "a first launch offers no Continue")
	await create_timer(0.8).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/menu-main.png")
	menu.show_chapters()
	var open: Array = menu.column.get_children().filter(func(c): return c is Button and not c.disabled)
	check(open.size() == 2, "only the first chapter and Back are open")
	Progress.mark("corridor")
	Progress.mark("prologue")
	check(Progress.furthest() == 2 and Progress.latest() == 0, "going back keeps what was unlocked")
	Progress.mark("corridor")
	menu.show_main()
	await process_frame
	check(labels(menu)[0].contains("Hành lang đỏ"), "Continue names where the player stopped: " + labels(menu)[0])
	menu.show_chapters()
	open = menu.column.get_children().filter(func(c): return c is Button and not c.disabled)
	check(open.size() == 4, "reached chapters are open")
	menu.show_settings()
	await process_frame
	var environment := Environment.new()
	Settings.track(environment)
	var card: PanelContainer = menu.column.get_child(0)
	card.brightness.value = 2.0
	check(is_equal_approx(environment.adjustment_brightness, 2.0) and is_equal_approx(Settings.read("brightness_value"), 2.0), "the slider changes the picture and is saved")
	card.brightness.value = old
	menu.queue_free()
	await process_frame
	Progress.recording = false
	Progress.enter(self, 2)
	await create_timer(4.0).timeout
	var school: Node = current_scene
	check(school.name != "MainMenu" and school.progression.runner.active, "the corridor chapter starts in the corridor")
	print("spirit ", school.spirit_enabled, " stage ", school.progression.stage, " want ", school.progression.Stage.CORRIDOR_RUN)
	check(school.spirit_enabled and school.progression.stage == school.progression.Stage.CORRIDOR_RUN, "with the story in the right state")
	var shell: Node = root.get_node("GameShell")
	shell.open()
	check(paused and shell.opened(), "the settings overlay pauses any scene")
	shell.close()
	check(not paused, "and closing resumes")
	school.progression.runner.skip_to_refuge()
	await process_frame
	check(school.progression.stage == school.progression.Stage.LAN_DIALOGUE, "the corridor chapter still reaches Lan")
	Progress.enter(self, 4)
	await create_timer(1.0).timeout
	check(current_scene.has_method("spend"), "the day chapter opens the town")
	Progress.wipe()
	print("failures ", failures)
	quit(failures)
