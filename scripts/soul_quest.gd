extends Node3D

var world: Node3D
var memories: Array = []
var found := {}
var accepted := {}
var fragments: Array[Node3D] = []
var soul: Node3D
var journal: PanelContainer
var dialog: Control
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
var dialogue_data: Dictionary
var dialogue_phase := "hub"
const SOUL_POSITION := Vector3(15, 11.75, 5)
const SOUL_APPROACH := Vector3(15, 11.75, 7)

func setup(school: Node3D) -> void:
	world = school
	dialogue_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/night1_dialogue.json"))
	memories = JSON.parse_string(FileAccess.get_file_as_string("res://data/soul_memories.json"))
	for i in range(memories.size()):
		if memories[i].get("source", "") == "opening":
			continue
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
	if not night_active() or not world.has_master_key or not fragment_available(index) or actor != world.player or found.has(index) or index >= fragments.size() or actor.get_interaction_target() != fragments[index]:
		return false
	found[index] = true
	selected_page = index
	fragments[index].collected = true
	fragments[index].hide()
	fragments[index].get_node("Interaction").collision_layer = 0
	world.soundscape.cue("memory")
	world.notify(memories[index].title + " · J")
	if found.size() == memories.size():
		world.notify("Đủ manh mối · Tìm An trên sân thượng khu A")
	return true

func fragment_available(index: int) -> bool:
	return index >= 0 and index < memories.size() and memories[index].get("source", "") != "opening" and (world.progression == null or world.progression.briefing_complete)

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
	if dialog.visible or actor != world.player or actor.get_interaction_target() != soul or not safe_to_talk():
		world.notify("Chưa an toàn")
		return false
	if world.progression != null and not world.progression.ready_for_rescue():
		return false
	if found.size() < memories.size():
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
	return found.size() == memories.size() and accepted.size() == memories.size() and night_active() and world.player.health > 0 and (world.progression == null or world.progression.ready_for_rescue())

func _next_topic() -> void:
	if accepted.size()==memories.size():
		dialogue_phase = "farewell"
		dialog.show_line("An",dialogue_data.an.farewell,[{"text":"Tạm biệt An.","action":_finish_conversation}])
		return
	for i in range(memories.size()):
		if not accepted.has(i):
			topic = i
			break
	dialogue_phase = "hub"
	reply.text = ""
	feedback.text = ""
	var items: Array = []
	for i in range(memories.size()):
		items.append({"text":_topic_data(i).question,"action":ask_topic.bind(i)})
	items.append({"text":dialogue_data.an.identity_question,"action":ask_identity})
	dialog.show_line("An",dialogue_data.an.intro if accepted.is_empty() else "Anh còn muốn hỏi em điều gì?",items)

func _topic_data(index: int) -> Dictionary:
	for entry in dialogue_data.an.topics:
		if entry.id==memories[index].id: return entry
	return {}

func ask_identity() -> void:
	if pending or not dialog.visible or not safe_to_talk(): return
	dialogue_phase = "question"
	dialog.show_line("Bạn",dialogue_data.an.identity_question,[{"text":"Nghe An trả lời","action":answer_identity}])

func answer_identity() -> void:
	if pending or not dialog.visible or not safe_to_talk(): return
	dialogue_phase = "answer"
	dialog.show_line("An",dialogue_data.an.identity_answer,[{"text":"Hỏi chuyện khác","action":_next_topic}])

func ask_topic(index: int) -> void:
	if pending or not dialog.visible or not safe_to_talk() or index<0 or index>=memories.size(): return
	topic = index
	dialogue_phase = "question"
	dialog.show_line("Bạn",_topic_data(topic).question,[{"text":"Nghe An trả lời","action":_show_response_choices}])

func _show_response_choices() -> void:
	if pending or not dialog.visible or not safe_to_talk(): return
	dialogue_phase = "answers"
	var entry := _topic_data(topic)
	var items: Array = []
	if not accepted.has(topic):
		for i in range(entry.replies.size()): items.append({"text":entry.replies[i],"action":choose_reply.bind(i)})
	items.append({"text":"Hỏi chuyện khác","action":_next_topic})
	dialog.show_line("An",entry.answer,items)

func choose_reply(index: int) -> void:
	var entry := _topic_data(topic)
	if pending or not dialog.visible or not safe_to_talk() or accepted.has(topic) or index<0 or index>=entry.replies.size(): return
	reply.text = entry.replies[index]
	dialogue_phase = "player_reply"
	dialog.show_line("Bạn",reply.text,[{"text":"Nói với An","action":submit}])

func submit() -> void:
	if pending or not dialog.visible or not safe_to_talk():
		return
	var words := reply.text.strip_edges()
	if words.length() < 3 or words.length() > 1000:
		feedback.text = "Hãy chọn câu anh muốn nói với An."
		return
	pending = true
	send_button.disabled = true
	reply.editable = false
	request_id = "%s-%s-%s" % [generation, topic, Time.get_ticks_usec()]
	feedback.text = "An đang lắng nghe…"
	dialogue_phase = "waiting"
	dialog.show_line("An","…",[],"An đang lắng nghe…")
	var body := JSON.stringify({"memory_id": memories[topic].id, "text": words, "request_id": request_id})
	var error := request.request(world.comfort_ai_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	if error != OK:
		_failed()

func _failed(message := "Dịch vụ AI chưa sẵn sàng. Kiểm tra key trong ai.json rồi thử lại.") -> void:
	request.cancel_request()
	pending = false
	send_button.disabled = false
	reply.editable = true
	feedback.text = message
	dialogue_phase = "error"
	if dialog.visible:
		dialog.show_line("An","…",[{"text":"Thử nói lại câu vừa chọn","action":submit},{"text":"Chọn lời khác","action":_show_response_choices}],message)

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
		"timeout": "AI phản hồi quá lâu. Câu đã chọn được giữ lại; thử lại sau.",
		"blocked_answer": "AI đã chặn phản hồi này. Anh có thể chọn lời đáp khác.",
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
		send_button.text = "Tiếp tục"
		reply.editable = false
	dialogue_phase = "reaction"
	var entry := _topic_data(topic)
	var items: Array = [{"text":"Nghe tiếp","action":_next_topic}] if passed else [{"text":"Để anh nói lại","action":_show_response_choices},{"text":"Hỏi chuyện khác","action":_next_topic}]
	dialog.show_line("An",entry.accepted_line if passed else entry.retry_line,items)

func _finish_conversation() -> void:
	if not dialog.visible or pending or not ready_for_rescue(): return
	if world.survival.mark_soul_rescued():
		soul.released = true
		close()
		world.soundscape.cue("rescue", -13)
		world.notify("An đã được giải thoát · Sống sót tới 06:00")

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
	dialogue_phase = "hub"
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
	if not world.simulation_active() or world.survival.opening.playing or world.progression.controls_player():
		return
	show_memory(selected_page)
	world.soundscape.cue("paper", -20)
	journal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_context() -> void:
	journal_text.text = world.progression.journal_context()

func show_memory(index: int) -> void:
	selected_page = index
	var memory: Dictionary = memories[index]
	var heading := "MANH MỐI VỀ AN · %d / %d\n\n" % [index + 1, memories.size()]
	var lead: String = world.progression.current_goal() + "\n\n" if world.progression != null else ""
	if world.progression != null and not world.progression.briefing_complete:
		journal_text.text = world.progression.journal_context()
		return
	journal_text.text = heading + lead + memory.title + "\n" + memory.hint + "\n\n"
	if found.has(index):
		journal_text.text += memory.story + "\n\n“" + memory.feeling + "”"
	else:
		journal_text.text += "Ký ức còn thiếu…"

func _input(event: InputEvent) -> void:
	if world.player.combat.busy() or world.progression != null and (world.progression.panel_visible() or world.progression.controls_player()):
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
	var context_tab := Button.new()
	context_tab.text = "Điều tra / Lan"
	context_tab.pressed.connect(show_context)
	tabs.add_child(context_tab)
	for i in range(memories.size()):
		var tab := Button.new()
		tab.text = "%02d" % (i + 1)
		tab.pressed.connect(show_memory.bind(i))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(scroll)
	scroll.add_child(journal_text)
	var leave := Button.new()
	leave.text = "Đóng · J / Esc"
	leave.pressed.connect(close)
	pages.add_child(leave)
	dialog = preload("res://scripts/visual_novel_dialogue.gd").new()
	dialog.setup(ui,"An",close)
	# Keep the transport/diagnostic controls private; the visible UI uses
	# authored questions and reply choices, never a text-entry form.
	prompt = Label.new()
	dialog.add_child(prompt)
	prompt.hide()
	reply = TextEdit.new()
	dialog.add_child(reply)
	reply.hide()
	feedback = Label.new()
	dialog.add_child(feedback)
	feedback.hide()
	send_button = Button.new()
	send_button.text = "Nói với An"
	send_button.pressed.connect(_send_pressed)
	dialog.add_child(send_button)
	send_button.hide()
