extends CanvasLayer
# Always loaded. Applies saved settings at launch and opens the settings card over any scene.
const Settings := preload("res://scripts/game_settings.gd")
const Progress := preload("res://scripts/game_progress.gd")
const SettingsCard := preload("res://scripts/settings_panel.gd")
const MENU := "res://scenes/main_menu.tscn"
var veil: ColorRect
var card: PanelContainer
var mouse_before := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 90
	preload("res://scripts/horror_type.gd").prepare()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.apply_volume(Settings.read("volume"))
	if not OS.get_cmdline_args().has("--script"):
		Settings.apply_fullscreen(Settings.read("fullscreen"))

func opened() -> bool:
	return card != null

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_F4:
		if opened():
			close()
		elif get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MENU:
			open()

func open() -> void:
	mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	veil = ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	card = SettingsCard.new()
	veil.add_child(card)
	card.setup(true)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.closed.connect(close)
	card.leave_game.connect(_leave)

func close() -> void:
	veil.queue_free()
	veil = null
	card = null
	get_tree().paused = false
	Input.mouse_mode = mouse_before

func _leave() -> void:
	mouse_before = Input.MOUSE_MODE_VISIBLE
	close()
	for meta in Progress.METAS:
		if get_tree().has_meta(meta):
			get_tree().remove_meta(meta)
	get_tree().change_scene_to_file(MENU)
