extends Control
# First screen of the game: carry on, start over, pick a chapter, change settings.
const Progress := preload("res://scripts/game_progress.gd")
const SettingsCard := preload("res://scripts/settings_panel.gd")
const Gear := preload("res://scripts/night_gear.gd")
const INK := Color(0.92, 0.89, 0.82)
const BLOOD := Color(0.86, 0.14, 0.1)
var column: VBoxContainer
var music: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(preload("res://scripts/menu_scene.gd").new())
	# Darkens only the side the buttons sit on, so the room stays in view.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0, 0.88))
	ramp.set_color(1, Color(0, 0, 0, 0))
	var fill := GradientTexture2D.new()
	fill.gradient = ramp
	var shade := TextureRect.new()
	shade.texture = fill
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 860
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 80
	column.offset_right = 620
	column.offset_top = 90
	column.offset_bottom = -40
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	music = AudioStreamPlayer.new()
	var loop: AudioStreamOggVorbis = load("res://assets/music/dark_ambience_gabovitch.ogg").duplicate()
	loop.loop = true
	music.stream = loop
	music.volume_db = -14
	add_child(music)
	if not OS.get_cmdline_args().has("--script"):
		music.play()
	show_main()
	# Testing a build: NEH-School -- --chapter home
	var asked := OS.get_cmdline_user_args()
	if asked.size() == 2 and asked[0] == "--chapter" and Progress.index_of(asked[1]) >= 0:
		Progress.enter.call_deferred(get_tree(), Progress.index_of(asked[1]))

func _clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func _title(content: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	if size_px >= 40:
		preload("res://scripts/horror_type.gd").title(label)
	column.add_child(label)
	return label

func _button(content: String, press: Callable, enabled := true) -> Button:
	var button := Button.new()
	button.text = content
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 20)
	button.disabled = not enabled
	button.pressed.connect(press)
	column.add_child(button)
	return button

func show_main() -> void:
	_clear()
	_title("NEH SCHOOL", 72, BLOOD)
	_title("Những người chưa trở về", 20, INK)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	column.add_child(spacer)
	var latest: int = Progress.latest()
	if latest >= 0:
		_button("Tiếp tục · " + Progress.CHAPTERS[latest].title, Progress.enter.bind(get_tree(), latest))
	_button("Chơi mới", _ask_new_game)
	_button("Chọn chương", show_chapters)
	_button("Cài đặt", show_settings)
	_button("Thoát", get_tree().quit)

func _ask_new_game() -> void:
	if Progress.furthest() < 0:
		start_new_game()
		return
	_clear()
	_title("Chơi lại từ đầu?", 40, BLOOD)
	_title("Tiến trình, tiền và đồ đã mua sẽ bị xóa.", 18, INK)
	_button("Xóa và chơi mới", start_new_game)
	_button("Thôi", show_main)

func start_new_game() -> void:
	Progress.wipe()
	Gear.write(Gear.fresh())
	Progress.enter(get_tree(), 0)

func show_chapters() -> void:
	_clear()
	_title("Chọn chương", 44, BLOOD)
	for i in range(Progress.CHAPTERS.size()):
		var chapter: Dictionary = Progress.CHAPTERS[i]
		var open: bool = Progress.unlocked(i)
		_button("%s · %s" % [chapter.title, chapter.text] if open else "Chưa mở khóa", Progress.enter.bind(get_tree(), i), open)
	_button("Quay lại", show_main)

func show_settings() -> void:
	_clear()
	var card: PanelContainer = SettingsCard.new()
	column.add_child(card)
	card.setup(false)
	card.closed.connect(show_main)
