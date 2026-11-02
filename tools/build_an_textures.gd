extends SceneTree
# Dresses the MIT Rocketbox Female_Child_01 as An: the magenta top becomes a white school shirt.
# godot --headless --path . --script tools/build_an_textures.gd
const FOLDER := "res://assets/rocketbox/townsfolk/"
const SHIRT := Color(0.86, 0.87, 0.84)

func _initialize() -> void:
	var body := Image.load_from_file(FOLDER + "textures/Female_Child_01_body.jpg")
	for y in range(body.get_height()):
		for x in range(body.get_width()):
			var ink := body.get_pixel(x, y)
			var magenta := ink.r - ink.g > 0.25 and ink.b - ink.g > 0.2
			if magenta:
				body.set_pixel(x, y, SHIRT * clampf(ink.v * 1.1, 0.3, 1.0))
	body.save_jpg(ProjectSettings.globalize_path(FOLDER + "textures/An_Student_body.jpg"), 0.9)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FOLDER + "textures/Female_Child_01_head.jpg"), ProjectSettings.globalize_path(FOLDER + "textures/An_Student_head.jpg"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FOLDER + "Female_Child_01.fbx"), ProjectSettings.globalize_path(FOLDER + "An_Student.fbx"))
	quit()
