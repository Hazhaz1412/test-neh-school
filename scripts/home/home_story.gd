extends Node
# The first morning home: Lan explains, a stranger writes, and Gaaglu reaches the real desktop.
# Nothing is written outside the game unless the player agreed on the screen shown first.
const CONSENT_FILE := "user://external.cfg"
const LAN_TALK := [
	{"say": ["Về tới nhà chưa?"], "ask": ["Rồi. Cô thật sự là ai vậy?", "Vừa tới. Tay tôi còn run."]},
	{"say": ["Chuyện tôi là ai để sau.", "Cậu phải biết thứ này trước. Lời nguyền ở trường không phải một con ma.", "Có bảy thứ đang ngự trong đó. Mỗi thứ là một mối tội đã giết người ở ngôi trường ấy.", "Ghen Tị. Lười Biếng. Phẫn Nộ. Tham Ăn. Tham Lam. Si Mê. Kiêu Ngạo."], "ask": ["Bảy con quỷ?", "Thứ đuổi tôi đêm qua là gì?"]},
	{"say": ["Mỗi đêm một con thức dậy. Không giết được đâu, chỉ né, trốn và nhử.", "Con nào cũng có luật riêng. Biết luật thì sống.", "Con tiếp theo là Ghen Tị. Cao, đen, đeo đầy huy chương cướp được. Nó săn người có nhiều nhất."], "ask": ["Vậy tôi phải làm gì?"]},
	{"say": ["Mỗi con quỷ giam một linh hồn. Người đầu tiên là Nguyễn Bình An.", "Ban ngày đi tìm hiểu chuyện gì đã xảy ra với em ấy. Hiểu đủ thì mới giải thoát được.", "Giải thoát đủ bảy linh hồn, lời nguyền mới tan.", "Báo chí nói ít lắm. Chúng ta phải tự phanh phui."], "ask": ["Được. Bắt đầu từ đâu?"]},
	{"say": ["Ngủ đi đã. Sáng tôi nhắn.", "Và nhớ: đừng trả lời ai khác ngoài tôi."], "ask": []},
]
const GARBLED := [34, 12, 52]
const HUB_WAIT := 10.0
var world: Node3D
var step := "arrive"
var consent := false
var asked_consent := false
var panel: Control
var buzz: AudioStreamPlayer
var ding: AudioStreamPlayer
var installed_by_hub := false
var opened_gaaglu := false
var fallback_note: Control
var lan_beat := 0

func setup(home: Node3D) -> void:
	world = home
	buzz = _sound("res://assets/audio/phone_buzz.wav", -8.0)
	ding = _sound("res://assets/audio/phone_ding.wav", -12.0)
	world.phone.add_thread("team", "Nhóm điều tra", "Minh, Khoa", Color(0.42, 0.46, 0.52), "N")
	world.phone.threads["team"].log.append({"text": "Minh: Tối qua mày biến đi đâu vậy?", "mine": false, "garbled": false})
	world.phone.reply_chosen.connect(_on_reply)
	var saved := ConfigFile.new()
	asked_consent = saved.load(CONSENT_FILE) == OK and saved.has_section_key("external", "allowed")
	consent = saved.get_value("external", "allowed", false)
	world.player.enabled = false
	if OS.get_cmdline_args().has("--script"):
		world.fade.hide()
		return
	if asked_consent:
		_arrive()
	else:
		_ask_consent()

func step_name() -> String:
	return step

func blocking() -> bool:
	return panel != null or fallback_note != null

func _sound(path: String, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.stream = load(path)
	sound.volume_db = volume
	add_child(sound)
	return sound

func _ask_consent() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel = _card("Trước khi tiếp tục", "NEH School có phần chơi diễn ra ngoài cửa sổ game. Nếu bạn cho phép, trong lúc chơi game có thể gửi thông báo hệ thống và tạo một lối tắt cùng một tệp ghi chú trên màn hình nền.\n\nKhông có gì khác bị thay đổi, không có tệp nào của bạn bị đọc hay sửa. Bạn gỡ được bất cứ lúc nào bằng npm run remove-desktop trong thư mục hub.\n\nNếu không cho phép, mọi thứ sẽ diễn ra ngay trong game.", [["Cho phép", _set_consent.bind(true)], ["Chỉ chơi trong game", _set_consent.bind(false)]])

func _card(title: String, body: String, buttons: Array) -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.012, 0.016, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.fade.get_parent().add_child(veil)
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.965, 0.97, 0.97)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(30)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 26
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(620, 0)
	veil.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	card.add_child(stack)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 26)
	head.add_theme_color_override("font_color", Color(0.09, 0.11, 0.13))
	stack.add_child(head)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", Color(0.28, 0.31, 0.33))
	stack.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	stack.add_child(row)
	for i in range(buttons.size()):
		var button := Button.new()
		button.text = "  %s  " % buttons[i][0]
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 16)
		var chip := StyleBoxFlat.new()
		chip.bg_color = Color(0.11, 0.62, 0.66) if i == 0 else Color(0.87, 0.89, 0.90)
		chip.set_corner_radius_all(10)
		chip.content_margin_left = 14
		chip.content_margin_right = 14
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, chip)
		var ink := Color.WHITE if i == 0 else Color(0.14, 0.16, 0.18)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, ink)
		button.pressed.connect(buttons[i][1])
		row.add_child(button)
	return veil

func _set_consent(allowed: bool) -> void:
	consent = allowed
	var saved := ConfigFile.new()
	saved.set_value("external", "allowed", allowed)
	saved.save(CONSENT_FILE)
	panel.queue_free()
	panel = null
	_arrive()

func _arrive() -> void:
	if consent:
		_start_hub()
	var banner: Label = world._label(world.fade, 40, Color(0.97, 0.94, 0.86))
	banner.text = "Về nhà · 01:06"
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	await get_tree().create_timer(1.8).timeout
	await create_tween().tween_property(world.fade, "modulate:a", 0.0, 1.2).finished
	world.fade.hide()
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	step = "upstairs"
	world.goal.text = "Lên phòng ngủ trên lầu"
	world.think("Về tới nhà rồi. Không ai biết mình vừa ở đâu.")
	world._add_touch(Vector3(4.0, 4.4, 1.5), "Ngồi vào máy tính", _desk)
	world._add_touch(Vector3(1.0, 4.0, 2.6), "Nằm xuống giường", _bed)

# Starts the Electron binary itself: the npm wrapper needs node, which a launcher's PATH may lack.
func _start_hub() -> void:
	if not OS.get_environment("NEH_HUB_SESSION").is_empty() or world.bridge.linked:
		return
	var binary := ProjectSettings.globalize_path("res://hub/node_modules/electron/dist/" + ("electron.exe" if OS.has_feature("windows") else "electron"))
	if not FileAccess.file_exists(binary):
		push_warning("Hub not found: " + binary)
		return
	var hub := ProjectSettings.globalize_path("res://hub")
	var started := OS.create_process("/usr/bin/env", ["-u", "ELECTRON_RUN_AS_NODE", binary, hub, "--background"]) if not OS.has_feature("windows") else OS.create_process(binary, [hub, "--background"])
	if started < 0:
		push_warning("Hub did not start")

func _physics_process(_delta: float) -> void:
	if step == "upstairs" and world.player.global_position.y > 2.4:
		step = "waiting"
		world.goal.text = ""
		_lan_writes()

func _lan_writes() -> void:
	await get_tree().create_timer(5.0).timeout
	buzz.play()
	world.phone.add_thread("lan", "Lan", "Vừa truy cập", Color(0.55, 0.38, 0.62), "L")
	world.phone.receive("lan", LAN_TALK[0].say[0])
	step = "lan"
	world.goal.text = "Mở điện thoại · Tab"

func toggle_phone() -> void:
	if blocking():
		return
	world.phone.toggle()
	var open: bool = world.phone.is_open()
	world.player.enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open and step == "lan":
		step = "reading"
		world.phone.open_thread("lan")
		world.goal.text = ""
		_lan_beat(0, true)

func _on_reply(index: int) -> void:
	var beat: Dictionary = LAN_TALK[lan_beat]
	world.phone.clear_replies()
	world.phone.send_mine("lan", beat.ask[index])
	_lan_beat(lan_beat + 1, false)

func _lan_beat(index: int, first_shown: bool) -> void:
	lan_beat = index
	var beat: Dictionary = LAN_TALK[index]
	for line_index in range(beat.say.size()):
		if first_shown and line_index == 0:
			continue
		await _type_line("lan", beat.say[line_index])
	if beat.ask.is_empty():
		_stranger()
	else:
		world.phone.offer_replies(beat.ask)

func _type_line(id: String, text: String) -> void:
	await get_tree().create_timer(0.5).timeout
	world.phone.set_typing(true)
	await get_tree().create_timer(minf(0.5 + text.length() * 0.018, 1.8)).timeout
	world.phone.set_typing(false)
	world.phone.receive(id, text)
	ding.play()

func _stranger() -> void:
	step = "stranger"
	world.phone.threads["lan"].status = "Hoạt động 1 phút trước"
	world.phone.status_label.text = "Hoạt động 1 phút trước"
	await get_tree().create_timer(5.0).timeout
	buzz.play()
	world.phone.add_thread("unknown", " ", " ", Color(0.70, 0.72, 0.74), "")
	world.phone.receive("unknown", "x".repeat(GARBLED[0]), true)
	await get_tree().create_timer(1.6).timeout
	buzz.play()
	world.phone.receive("unknown", "x".repeat(GARBLED[1]), true)
	await get_tree().create_timer(1.4).timeout
	buzz.play()
	world.phone.receive("unknown", "x".repeat(GARBLED[2]), true)
	await get_tree().create_timer(3.5).timeout
	_install()

func _install() -> void:
	step = "gaaglu"
	if consent and not world.bridge.linked:
		_start_hub()
		var left := HUB_WAIT
		while left > 0.0 and not world.bridge.linked:
			await get_tree().create_timer(0.5).timeout
			left -= 0.5
	if consent and world.bridge.linked:
		world.bridge.send_text(JSON.stringify({"type": "install_gaaglu", "consent": true}))
		installed_by_hub = true
		world.goal.text = "Có gì đó vừa xuất hiện trên máy tính của bạn"
	else:
		_in_game_notice()

# Same beat for players who said no or have no hub: it happens on Peter's computer instead.
func _in_game_notice() -> void:
	world.phone._show_banner("Gaaglu đã được cài đặt", "Xem ghi chú trên máy tính của bạn.")
	buzz.play()
	world.goal.text = "Xem máy tính ở bàn làm việc"

func _desk() -> void:
	if step != "gaaglu":
		world.think("Máy vẫn mở từ tối qua. Chưa có gì mới.")
		return
	if installed_by_hub:
		world.think("Không phải trên máy này. Là cái máy bạn đang dùng.")
		return
	_show_note()

func _show_note() -> void:
	world.player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fallback_note = _card("Ghi chú.txt", "Chỉ khi kết nối với thế giới bên kia, mới có thể tìm thấy sự thật.", [["Đóng", _close_note]])

func _close_note() -> void:
	fallback_note.queue_free()
	fallback_note = null
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	opened_gaaglu = true
	_ready_to_sleep()

func on_hub_message(message: Dictionary) -> void:
	if message.get("type") == "gaaglu_opened" and step == "gaaglu":
		opened_gaaglu = true
		_ready_to_sleep()

func _ready_to_sleep() -> void:
	world.goal.text = "Đi ngủ · Mới 1 giờ đêm"
	world.think("Ai đã cài thứ này? Hỏi Lan sau. Giờ phải ngủ đã.")

func _bed() -> void:
	if step != "gaaglu" or not opened_gaaglu and not installed_by_hub:
		world.think("Chưa ngủ được. Điện thoại cứ làm mình không yên.")
		return
	world.player.enabled = false
	world.fade.show()
	world.fade.modulate.a = 0.0
	await create_tween().tween_property(world.fade, "modulate:a", 1.0, 1.4).finished
	var morning: Label = world._label(world.fade, 40, Color(0.97, 0.94, 0.86))
	morning.text = "Ngủ tới 07:00 · Ngày 1"
	morning.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	morning.grow_horizontal = Control.GROW_DIRECTION_BOTH
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file("res://scenes/town.tscn")
