extends PanelContainer
# The settings card, used by the main menu and by the in-game overlay.
const Settings := preload("res://scripts/game_settings.gd")
const QUALITY := ["Nhẹ", "Cân bằng", "Cao"]
const SWATCHES := [0.02, 0.05, 0.1]
const PAPER := Color(0.92, 0.89, 0.82)
const FADED := Color(0.62, 0.59, 0.54)
signal closed
signal leave_game
var swatches: Array[ColorRect] = []
var brightness: HSlider
var volume: HSlider
var fullscreen: CheckBox
var quality: OptionButton

func setup(in_game: bool) -> void:
	custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.05, 0.97)
	style.border_color = Color(0.4, 0.1, 0.09)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(28)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(_text("Cài đặt", 28, Color(0.86, 0.2, 0.15)))
	column.add_child(_text("Độ sáng", 18, PAPER))
	brightness = _slider(Settings.BRIGHTNESS_MIN, Settings.BRIGHTNESS_MAX, Settings.read("brightness_value"), column)
	brightness.value_changed.connect(_brightness_changed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for i in range(SWATCHES.size()):
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(60, 40)
		row.add_child(swatch)
		swatches.append(swatch)
	row.add_child(_text("Chỉnh tới khi thấy rõ cả ba ô", 14, FADED))
	column.add_child(_text("Âm lượng", 18, PAPER))
	volume = _slider(0.0, 1.0, Settings.read("volume"), column)
	volume.value_changed.connect(Settings.set_volume)
	column.add_child(_text("Chất lượng đồ họa", 18, PAPER))
	quality = OptionButton.new()
	for title in QUALITY:
		quality.add_item(title)
	quality.selected = Settings.read("quality")
	quality.item_selected.connect(_quality_changed)
	column.add_child(quality)
	fullscreen = CheckBox.new()
	fullscreen.text = "Toàn màn hình"
	fullscreen.button_pressed = Settings.read("fullscreen")
	fullscreen.toggled.connect(Settings.set_fullscreen)
	column.add_child(fullscreen)
	if in_game:
		column.add_child(_button("Về menu chính", func(): leave_game.emit()))
	column.add_child(_button("Xong", func(): closed.emit()))
	_paint(brightness.value)

func _text(content: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label

func _slider(low: float, high: float, value: float, parent: Control) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.y = 26
	parent.add_child(slider)
	return slider

func _button(content: String, press: Callable) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(press)
	return button

func _brightness_changed(value: float) -> void:
	Settings.set_brightness(value)
	_paint(value)

func _paint(value: float) -> void:
	for i in range(swatches.size()):
		var level: float = SWATCHES[i] * value
		swatches[i].color = Color(level, level, level)

func _quality_changed(level: int) -> void:
	Settings.write("quality", level)
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("set_quality"):
		scene.set_quality(level)
