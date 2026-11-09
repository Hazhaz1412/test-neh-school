extends Node
# The group's case notebook (J): what happened tonight, and each piece of evidence found.
# Evidence is recorded by the story (school_progression.gd); this only keeps and shows it.
var world: Node3D
var entries: Array = []
var found := {}
var selected_page := -1
var journal: PanelContainer
var journal_text: Label

func setup(school: Node3D) -> void:
	world = school
	entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/evidence.json"))
	_build_ui()
	world.player.damaged.connect(func(_amount): close())

func record(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	found[index] = true
	selected_page = index

func panel_visible() -> bool:
	return journal != null and journal.visible

func close() -> void:
	if journal != null:
		journal.hide()
	if world != null and not world.paused_by_user and not world.map_panel.visible and world.player.health > 0 and not world.survival.finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func reset() -> void:
	close()
	found.clear()
	selected_page = -1

func toggle_journal() -> void:
	if journal.visible:
		close()
		return
	if not world.simulation_active() or world.survival.opening.playing or world.progression.controls_player():
		return
	if selected_page >= 0 and found.has(selected_page):
		show_entry(selected_page)
	else:
		show_context()
	world.soundscape.cue("paper", -20)
	journal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_context() -> void:
	journal_text.text = world.progression.journal_context()

func show_entry(index: int) -> void:
	selected_page = index
	var entry: Dictionary = entries[index]
	var heading := "BẰNG CHỨNG · %d / %d\n\n" % [index + 1, entries.size()]
	if found.has(index):
		journal_text.text = heading + entry.title + "\n" + entry.where + "\n\n" + entry.note
	else:
		journal_text.text = heading + "Chưa tìm thấy."

func _input(event: InputEvent) -> void:
	if world.progression != null and (world.progression.panel_visible() or world.progression.controls_player()):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if panel_visible() and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_J:
			toggle_journal()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var ui: Control = world.get_node("HUD").get_child(0)
	journal = PanelContainer.new()
	journal.position = Vector2(295, 130)
	journal.size = Vector2(690, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.042, 0.05, 0.97)
	style.border_color = Color(0.26, 0.40, 0.43)
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	journal.add_theme_stylebox_override("panel", style)
	ui.add_child(journal)
	journal.hide()
	var pages := VBoxContainer.new()
	journal.add_child(pages)
	var tabs := HBoxContainer.new()
	pages.add_child(tabs)
	var context_tab := Button.new()
	context_tab.text = "Diễn biến"
	context_tab.pressed.connect(show_context)
	tabs.add_child(context_tab)
	for i in range(entries.size()):
		var tab := Button.new()
		tab.text = "Bằng chứng %d" % (i + 1)
		tab.pressed.connect(show_entry.bind(i))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(scroll)
	journal_text = Label.new()
	journal_text.custom_minimum_size = Vector2(640, 290)
	journal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_text.add_theme_font_size_override("font_size", 17)
	scroll.add_child(journal_text)
	var leave := Button.new()
	leave.text = "Đóng · J / Esc"
	leave.pressed.connect(close)
	pages.add_child(leave)
