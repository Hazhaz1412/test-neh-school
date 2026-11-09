extends Control

var speaker: Label
var speech: RichTextLabel
var choices: VBoxContainer
var status: Label
var hint: Label
var portrait: TextureRect
var portrait_viewport: SubViewport
var actor: Node3D
var accent := Color(.67,.77,.76)
var letters := 0.0
var callbacks: Array[Callable] = []
var locked_choices: Array[bool] = []
var leave: Callable

func style(color: Color, border: Color, padding := 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box

# Town NPCs bring their own avatar; without one a plain townsperson stands in.
func setup(ui: Control, character: String, close_action: Callable, custom_actor: Node3D = null) -> void:
	name = character+"Dialogue"
	z_index = 40
	leave = close_action
	accent = Color(.46,.76,.76)
	ui.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(.005,.012,.018,.43)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_portrait(character, custom_actor)
	var box := PanelContainer.new()
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 38
	box.offset_right = -38
	box.offset_top = -196
	box.offset_bottom = -22
	box.add_theme_stylebox_override("panel",style(Color(.018,.028,.033,1),accent))
	box.gui_input.connect(_box_input)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",8)
	box.add_child(stack)
	speaker = Label.new()
	speaker.add_theme_color_override("font_color",accent)
	speaker.add_theme_font_size_override("font_size",26)
	speaker.add_theme_font_override("font",preload("res://scripts/horror_type.gd").TITLE)
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(speaker)
	speech = RichTextLabel.new()
	speech.bbcode_enabled = false
	speech.scroll_active = false
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech.add_theme_font_size_override("normal_font_size",21)
	speech.add_theme_color_override("default_color",Color(.93,.91,.85))
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(speech)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color(.59,.64,.64))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(hint)
	var options_box := MarginContainer.new()
	add_child(options_box)
	options_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	options_box.offset_left = -760
	options_box.offset_right = -38
	options_box.offset_top = -560
	options_box.offset_bottom = -208
	var options_stack := VBoxContainer.new()
	options_stack.alignment = BoxContainer.ALIGNMENT_END
	options_stack.add_theme_constant_override("separation",8)
	options_box.add_child(options_stack)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color",accent)
	status.add_theme_font_size_override("font_size",15)
	options_stack.add_child(status)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	options_stack.add_child(choices)
	var exit := Button.new()
	exit.text = "Rời cuộc trò chuyện · Esc"
	exit.add_theme_font_size_override("font_size",14)
	exit.add_theme_stylebox_override("normal",style(Color(.025,.04,.045,.88),Color(.22,.28,.28),9))
	exit.pressed.connect(close_action)
	add_child(exit)
	exit.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	exit.offset_left = -278
	exit.offset_right = -38
	exit.offset_top = 82
	exit.offset_bottom = 116
	hide()
	visibility_changed.connect(_visibility_changed)
	_visibility_changed()

func _build_portrait(character: String, custom_actor: Node3D) -> void:
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(360,480)
	portrait_viewport.own_world_3d = true
	portrait_viewport.transparent_bg = true
	add_child(portrait_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.72,.77,.80)
	environment.environment.ambient_light_energy = .8
	portrait_viewport.add_child(environment)
	actor = custom_actor
	if actor == null:
		actor = preload("res://scripts/humanoid_model.gd").new()
		actor.look = "Female_Adult_11"
		actor.target_height = 1.68
		actor.head_pitch = .08
	portrait_viewport.add_child(actor)
	actor.rotation.y = -.12
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-35,0)
	light.light_color = Color(.94,.82,.73)
	light.light_energy = 1.4
	portrait_viewport.add_child(light)
	var camera := Camera3D.new()
	portrait_viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.5
	camera.position = Vector3(0,1.17,3)
	camera.look_at(Vector3(0,camera.position.y,0))
	camera.current = true
	portrait = TextureRect.new()
	portrait.texture = portrait_viewport.get_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	portrait.offset_left = 38
	portrait.offset_right = 350
	portrait.offset_top = -648
	portrait.offset_bottom = -196

func show_line(who: String, text: String, items: Array, message := "") -> void:
	speaker.text = who
	speech.text = text
	speech.visible_characters = 0
	letters = 0
	portrait.modulate = Color(.58,.62,.65) if who=="Bạn" else Color.WHITE
	status.text = message
	callbacks.clear()
	locked_choices.clear()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for item in items:
		var index := callbacks.size()
		callbacks.append(item.action)
		locked_choices.append(item.get("disabled",false))
		var button := Button.new()
		button.text = "%d.  %s" % [index+1,item.text]
		button.custom_minimum_size.y = 43
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",17)
		button.add_theme_stylebox_override("normal",style(Color(.022,.035,.041,.96),Color(.26,.35,.36),12))
		button.add_theme_stylebox_override("hover",style(Color(.09,.14,.15,.99),accent,12))
		button.add_theme_stylebox_override("focus",style(Color(.07,.12,.13,.99),accent,12))
		button.disabled = true
		button.pressed.connect(select_choice.bind(index))
		choices.add_child(button)
	show()
	_update_hint()

func reveal() -> void:
	speech.visible_characters = -1
	letters = speech.get_total_character_count()
	for i in range(choices.get_child_count()): choices.get_child(i).disabled = locked_choices[i]
	_update_hint()

func is_typing() -> bool:
	return speech.visible_characters>=0 and speech.visible_characters<speech.get_total_character_count()

func select_choice(index: int) -> void:
	if not visible or is_typing() or index<0 or index>=callbacks.size() or locked_choices[index]: return
	var action := callbacks[index]
	# Lock immediately: a double click must never start two requests/transitions.
	for button in choices.get_children(): button.disabled = true
	callbacks.clear()
	if action.is_valid(): action.call()

func _update_hint() -> void:
	hint.text = "Space / Enter / Nhấp · Hiện hết câu" if is_typing() else ("1–%d · Chọn câu thoại" % callbacks.size() if not callbacks.is_empty() else "")

func _box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and is_typing():
		reveal()
		accept_event()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	# A choice can end the scene, and this node has no viewport left once it does.
	var viewport := get_viewport()
	if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
		if is_typing(): reveal()
		elif callbacks.size()==1: select_choice(0)
		else: return
	elif event.keycode>=KEY_1 and event.keycode<=KEY_9:
		if is_typing(): reveal()
		else: select_choice(event.keycode-KEY_1)
	else: return
	viewport.set_input_as_handled()

func _process(delta: float) -> void:
	if not visible: return
	if is_typing():
		letters += delta*42
		speech.visible_characters = int(letters)
		if not is_typing(): reveal()

func _visibility_changed() -> void:
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if visible else SubViewport.UPDATE_DISABLED
	if actor!=null:
		actor.set_process(visible)
		if actor.animation!=null:
			actor.animation.active = visible
			actor.animation.speed_scale = .4 if visible else 0
