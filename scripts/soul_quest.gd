extends Node3D

var world: Node3D
var memories: Array = []
var found := {}
var accepted := {}
var fragments: Array[Node3D] = []
var soul: Node3D
var journal: PanelContainer
var dialog: PanelContainer
var journal_text: Label
var prompt: Label
var reply: TextEdit
var feedback: Label
var send_button: Button
var request: HTTPRequest
var pending := false
var request_id := ""
var selected_page := 0
var topic := 0
var generation := 0
var camera_rotation := Vector3.ZERO
const SOUL_POSITION := Vector3(15, 11.75, 5)
const SOUL_APPROACH := Vector3(15, 11.75, 7)

func setup(school: Node3D) -> void:
	world = school
	memories = JSON.parse_string(FileAccess.get_file_as_string("res://data/soul_memories.json"))
	for i in range(memories.size()):
		var fragment: Node3D = preload("res://scripts/soul_fragment.gd").new()
		fragment.quest = self
		fragment.index = i
		fragment.position = Vector3(memories[i].position[0], memories[i].position[1], memories[i].position[2])
		fragment.name = "Memory_" + memories[i].id
		add_child(fragment)
		fragments.append(fragment)
	soul = preload("res://scripts/student_soul.gd").new()
	soul.quest = self
	soul.position = SOUL_POSITION
	soul.name = "An"
	add_child(soul)
	_build_ui()
	request = HTTPRequest.new()
	request.timeout = 90
	add_child(request)
	request.request_completed.connect(_received)
	world.player.damaged.connect(func(_amount): close())

func panel_visible() -> bool:
	return journal.visible or dialog.visible

func night_active() -> bool:
	return world.simulation_active() and world.survival.active and world.survival.phase == world.survival.Phase.NIGHT and world.spirit_enabled

func collect(index: int, actor: CharacterBody3D) -> bool:
	if not night_active() or not world.has_master_key or not fragment_available(index) or actor != world.player or found.has(index) or actor.get_interaction_target() != fragments[index]:
		return false
	found[index] = true
	selected_page = index
	fragments[index].collected = true
	fragments[index].hide()
	fragments[index].get_node("Interaction").collision_layer = 0
	world.soundscape.cue("memory")
	world.notify(memories[index].title + " · J")
	if found.size() == 4:
		world.notify("4 ký ức · Tìm An trên sân thượng khu A")
	return true

func fragment_available(index: int) -> bool:
	return index not in [1, 2] or world.progression == null or world.progression.completed.has(1) or world.progression.completed.has(2)

func safe_to_talk() -> bool:
	if not night_active() or world.player.is_hidden() or world.player.global_position.distance_to(soul.global_position) > 2.8:
		return false
	if world.is_soul_sanctuary(world.player.global_position):
		return true
	if world.test_cheats != null and world.test_cheats.enabled:
		return true
	for enemy in world.enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(world.player.global_position) < 9 and enemy.state >= 2:
			return false
	return true

func begin_comfort(actor: CharacterBody3D) -> bool:
	if actor != world.player or actor.get_interaction_target() != soul or not safe_to_talk():
		world.notify("Chưa an toàn")
		return false
	if world.progression != null and not world.progression.ready_for_rescue():
		return false
	if found.size() < 4:
		world.notify("Ký ức còn thiếu · J")
		return false
	if world.survival.soul_rescued:
		return false
	journal.hide()
	camera_rotation = actor.camera.rotation
	actor.camera.look_at(soul.global_position + Vector3(0.65, 0.9, 0))
	dialog.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_next_topic()
	return true

func ready_for_rescue() -> bool:
	return found.size() == 4 and accepted.size() == 4 and night_active() and world.player.health > 0 and (world.progression == null or world.progression.ready_for_rescue())

func _next_topic() -> void:
	for i in range(4):
		if not accepted.has(i):
			topic = i
			prompt.text = "An · %d / 4\n“%s”" % [accepted.size() + 1, memories[i].feeling]
			reply.text = ""
			feedback.text = ""
			reply.grab_focus()
			return

func submit() -> void:
	if pending or not dialog.visible or not safe_to_talk():
		return
	var words := reply.text.strip_edges()
	if words.length() < 3 or words.length() > 1000:
		feedback.text = "Viết lời anh muốn nói với An (tối đa 1000 ký tự)."
		return
	pending = true
	send_button.disabled = true
	reply.editable = false
	request_id = "%s-%s-%s" % [generation, topic, Time.get_ticks_usec()]
	feedback.text = "An đang lắng nghe…"
	var body := JSON.stringify({"memory_id": memories[topic].id, "text": words, "request_id": request_id})
	var error := request.request(world.comfort_ai_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		_failed()

func _failed(message := "Dịch vụ AI chưa sẵn sàng. Kiểm tra key trong ai.json rồi thử lại.") -> void:
	pending = false
	send_button.disabled = false
	reply.editable = true
	feedback.text = message

func ai_error_text(reason: String) -> String:
	return {
		"missing_api_key": "Chưa có API key. Điền api_key trong ai.json rồi thử lại.",
		"missing_model": "Chưa chọn model AI trong ai.json.",
		"invalid_api_key": "API key không hợp lệ. Kiểm tra lại key trong ai.json.",
		"api_access_denied": "API từ chối quyền truy cập. Kiểm tra key và quyền dùng model.",
		"quota_exceeded": "AI đã hết hạn mức hoặc đang bị giới hạn lượt. Thử lại sau.",
		"model_not_found": "API không tìm thấy model đã chọn. Kiểm tra model trong ai.json.",
		"unsupported_model": "Model trong ai.json chưa được cầu nối hỗ trợ.",
		"unsupported_provider": "Provider trong ai.json chưa được hỗ trợ.",
		"network_error": "Không kết nối được nhà cung cấp AI. Kiểm tra mạng rồi thử lại.",
		"timeout": "AI phản hồi quá lâu. Lời anh viết được giữ lại; thử lại sau.",
		"blocked_answer": "AI đã chặn phản hồi này. Anh có thể viết lại lời an ủi.",
		"incomplete_answer": "AI trả lời chưa hoàn chỉnh. Anh có thể thử lại.",
		"invalid_ai_response": "AI trả về đánh giá sai định dạng. Không tính điểm; thử lại.",
		"provider_request_invalid": "Nhà cung cấp từ chối yêu cầu chấm. Kiểm tra cấu hình cầu nối.",
		"provider_unavailable": "AI đang quá tải hoặc tạm gián đoạn. Chờ một chút rồi thử lại.",
	}.get(reason, "Dịch vụ AI tạm không chấm được. Anh có thể thử lại.")

func _received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not pending or not dialog.visible:
		return
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		var failure = null
		if result == HTTPRequest.RESULT_SUCCESS and not body.is_empty():
			var error_json := JSON.new()
			if error_json.parse(body.get_string_from_utf8()) == OK:
				failure = error_json.data
		if result == HTTPRequest.RESULT_TIMEOUT:
			_failed(ai_error_text("timeout"))
		elif result != HTTPRequest.RESULT_SUCCESS:
			_failed("Chưa kết nối được cầu nối AI. Mở lại game hoặc chạy soul_ai_server.py.")
		elif failure is Dictionary and failure.get("request_id") == request_id and failure.get("reason") is String:
			_failed(ai_error_text(failure.reason))
		else:
			_failed()
		return
	var decoded := JSON.new()
	if decoded.parse(body.get_string_from_utf8()) != OK:
		_failed(ai_error_text("invalid_ai_response"))
		return
	var value = decoded.data
	if not value is Dictionary or value.get("request_id") != request_id or value.get("source") != "ai":
		_failed()
		return
	var score = value.get("scores")
	if not score is Dictionary:
		_failed(ai_error_text("invalid_ai_response"))
		return
	for key in ["understanding", "validation", "support"]:
		if not score.has(key) or not (score[key] is float or score[key] is int) or score[key] != int(score[key]) or score[key] < 0 or score[key] > 2:
			_failed()
			return
	if not value.get("unsafe") is bool or not value.get("feedback") is String:
		_failed()
		return
	pending = false
	send_button.disabled = false
	reply.editable = true
	var passed: bool = not value.unsafe and score.understanding >= 1 and score.validation >= 1 and score.understanding + score.validation + score.support >= 4
	if memories[topic].id in ["rumour", "fear"]:
		passed = passed and score.support >= 1
	feedback.text = value.feedback.left(180)
	if not safe_to_talk():
		close()
		return
	if passed:
		accepted[topic] = true
		world.soundscape.cue("memory", -25)
		if ready_for_rescue() and world.survival.mark_soul_rescued():
			soul.released = true
			close()
			world.soundscape.cue("rescue", -13)
			world.notify("An đã được giải thoát · Sống sót tới 06:00")
		else:
			# Keep the AI feedback visible; the player decides when to continue.
			send_button.text = "Tiếp tục"
			reply.editable = false

func _send_pressed() -> void:
	if accepted.has(topic):
		send_button.text = "Nói với An"
		reply.editable = true
		_next_topic()
	else:
		submit()

func close() -> void:
	if dialog != null and dialog.visible:
		world.player.camera.rotation = camera_rotation
	if journal != null:
		journal.hide()
	if dialog != null:
		dialog.hide()
	if request != null:
		request.cancel_request()
	pending = false
	generation += 1
	if send_button != null:
		send_button.disabled = false
		send_button.text = "Nói với An"
		reply.editable = true
	if world != null and not world.paused_by_user and not world.map_panel.visible and world.player.health > 0 and not world.survival.finished:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func reset() -> void:
	close()
	found.clear()
	accepted.clear()
	for fragment in fragments:
		fragment.reset_fragment()
	soul.released = false

func toggle_journal() -> void:
	if dialog.visible:
		return
	if journal.visible:
		close()
		return
	if not world.simulation_active() or world.survival.opening.playing:
		return
	show_memory(selected_page)
	world.soundscape.cue("paper", -20)
	journal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_memory(index: int) -> void:
	selected_page = index
	var memory: Dictionary = memories[index]
	var heading := "KÝ ỨC CỦA AN · %d / 4\n\n" % (index + 1)
	var lead: String = world.progression.current_goal() + "\n\n" if world.progression != null else ""
	journal_text.text = heading + lead + memory.title + "\n" + memory.hint + "\n\n"
	if found.has(index):
		journal_text.text += memory.story + "\n\n“" + memory.feeling + "”"
	else:
		journal_text.text += "Ký ức còn thiếu…"

func _input(event: InputEvent) -> void:
	if world.player.combat.busy() or world.progression != null and world.progression.panel_visible():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if panel_visible() and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif not dialog.visible and event.keycode == KEY_J:
			toggle_journal()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if dialog != null and dialog.visible and not safe_to_talk():
		close()

func _panel(ui: Control, at: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.042, 0.05, 0.97)
	style.border_color = Color(0.26, 0.40, 0.43)
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	panel.hide()
	return panel

func _build_ui() -> void:
	var ui: Control = world.get_node("HUD").get_child(0)
	journal = _panel(ui, Vector2(295, 130), Vector2(690, 430))
	var pages := VBoxContainer.new()
	journal.add_child(pages)
	journal_text = Label.new()
	journal_text.custom_minimum_size = Vector2(640, 290)
	journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_text.add_theme_font_size_override("font_size", 17)
	var tabs := HBoxContainer.new()
	pages.add_child(tabs)
	for i in range(4):
		var tab := Button.new()
		tab.text = "%02d" % (i + 1)
		tab.pressed.connect(show_memory.bind(i))
		tabs.add_child(tab)
	pages.add_child(journal_text)
	var leave := Button.new()
	leave.text = "Đóng · J / Esc"
	leave.pressed.connect(close)
	pages.add_child(leave)
	dialog = _panel(ui, Vector2(650, 335), Vector2(590, 330))
	var stack := VBoxContainer.new()
	dialog.add_child(stack)
	prompt = Label.new()
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size.x = 540
	prompt.add_theme_font_size_override("font_size", 19)
	stack.add_child(prompt)
	reply = TextEdit.new()
	reply.custom_minimum_size = Vector2(540, 90)
	reply.placeholder_text = "Anh sẽ nói gì với An?"
	reply.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	stack.add_child(reply)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 15)
	stack.add_child(feedback)
	var buttons := HBoxContainer.new()
	stack.add_child(buttons)
	send_button = Button.new()
	send_button.text = "Nói với An"
	send_button.pressed.connect(_send_pressed)
	buttons.add_child(send_button)
	var exit := Button.new()
	exit.text = "Rời đi · Esc"
	exit.pressed.connect(close)
	buttons.add_child(exit)
