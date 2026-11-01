extends SceneTree
# Repaints the MIT Rocketbox Male_Child_01 textures into two ruined school uniforms with
# erased faces. Source TGAs are not kept in the repo:
# godot --headless --path . --script tools/build_student_textures.gd -- <folder with cm001_*.tga>
const OUTPUT := "res://assets/rocketbox/textures/"
const SIZE := 1024
const VARIANTS := {"a": {"seed": 11, "blood": 0.74, "shirt": Color(0.74, 0.74, 0.69)}, "b": {"seed": 47, "blood": 0.68, "shirt": Color(0.62, 0.64, 0.61)}}
# Regions in the 0-1 UV layout of the source body texture.
const LOGO := Rect2(0.43, 0.54, 0.17, 0.15)
const LOGO_SHIFT := 0.135
const FACE_CENTER := Vector2(0.5, 0.33)
const FACE_RADIUS := Vector2(0.20, 0.17)
const EYEBALLS := Rect2(0.0, 0.59, 0.37, 0.41)
const NORMAL_FLAT := Color(0.5, 0.5, 1.0)

func _initialize() -> void:
	var source: String = OS.get_cmdline_user_args()[0]
	var body := _load(source.path_join("cm001_body_color.tga"))
	var head := _load(source.path_join("cm001_head_color.tga"))
	var head_normal := _load(source.path_join("cm001_head_normal.tga"))
	_load(source.path_join("cm001_body_normal.tga")).save_jpg(ProjectSettings.globalize_path(OUTPUT + "student_body_normal.jpg"), 0.92)
	_flatten_face(head_normal).save_jpg(ProjectSettings.globalize_path(OUTPUT + "student_head_normal.jpg"), 0.92)
	var erased := _erase_face(head)
	for key in VARIANTS:
		var look: Dictionary = VARIANTS[key]
		_repaint_body(body, look).save_jpg(ProjectSettings.globalize_path(OUTPUT + "student_%s_body.jpg" % key), 0.92)
		_repaint_head(erased, look).save_jpg(ProjectSettings.globalize_path(OUTPUT + "student_%s_head.jpg" % key), 0.92)
	print("student textures written")
	quit()

func _load(path: String) -> Image:
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGB8)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return image

func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	return noise

func _face_mask(uv: Vector2) -> float:
	var distance := ((uv - FACE_CENTER) / FACE_RADIUS).length()
	return 1.0 - smoothstep(0.72, 1.0, distance)

func _repaint_body(source: Image, look: Dictionary) -> Image:
	var out := source.duplicate()
	var grime := _noise(look.seed, 0.012)
	var blood := _noise(look.seed + 3, 0.035)
	var shirt: Color = look.shirt
	for y in range(SIZE):
		for x in range(SIZE):
			var uv := Vector2(x, y) / float(SIZE)
			var from := Vector2i(x, y)
			if LOGO.has_point(uv):
				from.y += int(LOGO_SHIFT * SIZE)
			var color := source.get_pixelv(from)
			var dirt := 0.5 + grime.get_noise_2d(x, y) * 0.9
			var cloth := color.s > 0.25 and color.h > 0.50 and color.h < 0.70 and color.v > 0.12
			var logo := LOGO.has_point(uv)
			var trousers := uv.y < 0.44 and (uv.x < 0.31 or uv.x > 0.69)
			if trousers:
				# Denim wrinkles survive as shading on dark uniform trousers.
				var fold := color.get_luminance()
				color = Color(0.055, 0.065, 0.095).lerp(Color(0.16, 0.17, 0.21), fold) * (0.75 + dirt * 0.4)
			elif cloth or logo:
				var fold := clampf(color.v * 1.9, 0.35, 1.0)
				color = shirt * fold * (0.74 + dirt * 0.34)
				color = color.lerp(Color(0.34, 0.29, 0.20), clampf((dirt - 0.55) * 1.1, 0.0, 0.42))
				var stain := blood.get_noise_2d(x, y) + 0.34 + uv.y * 0.3
				if stain > look.blood:
					color = color.lerp(Color(0.16, 0.012, 0.012), clampf((stain - look.blood) * 3.5, 0.0, 0.8))
			else:
				var grey := color.get_luminance()
				color = color.lerp(Color(grey, grey, grey * 0.96), 0.72) * 0.72
			color.a = 1.0
			out.set_pixel(x, y, color)
	return out

func _erase_face(source: Image) -> Image:
	var blur := source.duplicate()
	blur.resize(40, 40, Image.INTERPOLATE_BILINEAR)
	blur.resize(SIZE, SIZE, Image.INTERPOLATE_CUBIC)
	var out := source.duplicate()
	for y in range(SIZE):
		for x in range(SIZE):
			var uv := Vector2(x, y) / float(SIZE)
			var mask := _face_mask(uv)
			if mask > 0.0:
				out.set_pixel(x, y, source.get_pixel(x, y).lerp(blur.get_pixel(x, y), mask))
			if EYEBALLS.has_point(uv):
				out.set_pixel(x, y, Color(0.006, 0.004, 0.004))
	return out

func _repaint_head(source: Image, look: Dictionary) -> Image:
	var out := source.duplicate()
	var bruise := _noise(look.seed + 7, 0.02)
	for y in range(SIZE):
		for x in range(SIZE):
			var uv := Vector2(x, y) / float(SIZE)
			var color := source.get_pixel(x, y)
			# Skin only: hair stays dark and the black eye region stays black.
			if color.v > 0.32 and color.h < 0.12 and color.s < 0.65:
				var dead := Color(0.60, 0.61, 0.55) * clampf(color.v * 1.05, 0.5, 1.0)
				color = color.lerp(dead, 0.84)
				color = color.lerp(Color(0.27, 0.20, 0.24), clampf(bruise.get_noise_2d(x, y) * 1.3, 0.0, 0.45))
			color.a = 1.0
			out.set_pixel(x, y, color)
	return out

func _flatten_face(source: Image) -> Image:
	var out := source.duplicate()
	for y in range(SIZE):
		for x in range(SIZE):
			var mask := _face_mask(Vector2(x, y) / float(SIZE))
			if mask > 0.0:
				out.set_pixel(x, y, source.get_pixel(x, y).lerp(NORMAL_FLAT, mask))
	return out
