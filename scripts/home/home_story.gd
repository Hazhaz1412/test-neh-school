extends Node
# Peter's house. The evening he moves in ends in sleep, and his first night at NEH is a dream.
# Waking, he finds pieces of that dream in strangers' posts. A friend points him to Gaaglu; through
# Sợi Chỉ, or on his own if there is no hub, Bảy Rô writes and sets a game of caro at Góc Cờ.
# Nothing is written outside the game unless the player agreed on the screen shown first.
const CONSENT_FILE := "user://external.cfg"
const Gear := preload("res://scripts/night_gear.gd")
const HUB_WAIT := 10.0
# Shown when the player allowed the desktop part but the hub could not deliver it.
const HUB_PROBLEMS := {
	"missing": "Thiếu phần hub. Chạy npm ci trong thư mục hub rồi chơi lại đoạn này.",
	"failed": "Hub không khởi động được. Xem log của game để biết lỗi.",
	"no_link": "Hub không kết nối được với game. Thử mở lại game.",
}
const BED := Vector3(1.0, 4.0, 2.6)
const DESK := Vector3(4.0, 4.4, 1.5)
const WAKE_SPOT := Vector3(2.0, 2.95, 2.8)
const WAKE_ASK := ["Tối qua tao mơ thấy mình lẻn vào Trường NEH.", "Tụi mày đọc mấy bài về NEH trên Fake chưa?"]
const WAKE_REPLY := [
	"Bơ Tồ: Sáu giờ sáng mà nhắn chuyện mơ hả mày.",
	"Huna: Mấy bài đó tao đọc rồi. Đăng lên Fake là bị gỡ, muốn đào sâu phải vô chỗ khác.",
	"Huna: Tải Gaaglu đi. App đó vào được mấy web mà tìm kiếm thường không ra. Có Sợi Chỉ, học sinh NEH hay lên đó xả.",
	"Ba Rô: Toàn web đen đó. Cẩn thận.",
]
const BAYRO_FIRST := {true: "Cậu là người nhắn tôi trên Sợi Chỉ?", false: "Nghe nói cậu đang hỏi chuyện Trường NEH."}
const BAYRO_TALK := [
	"Chuyện ở trường đó tôi biết nhiều hơn mấy bài trên mạng.",
	"Nhưng tôi không kể cho người lạ. Góc Cờ, chợ Bến Trầu. Ngồi xuống đánh với tôi một ván caro.",
	"Thắng thì tôi kể. Bảy Rô không bao giờ nuốt lời.",
]
const BAYRO_ASK := ["Được. Sáng nay tôi qua.", "Sao phải đánh cờ?"]
const BAYRO_END := "Muốn biết sự thật thì phải chịu ngồi xuống đã. Tôi đợi."
const MUOI_GIO_TALK := [
	"Cần dây với đồ mở khóa hả.",
	"Hẻm 8, cái khe giữa hai căn nhà. Ban ngày tôi đứng đó.",
	"Bẻ khóa 90, dây thừng 60. Không trả giá, không hỏi để làm gì.",
]
# Without the hub he writes on his own; with it, he still writes if the player never finds him.
const BAYRO_SELF_WAIT := 8.0
const BAYRO_HUB_WAIT := 180.0
var world: Node3D
var step := "arrive"
var consent := false
var asked_consent := false
var panel: Control
var buzz: AudioStreamPlayer
var ding: AudioStreamPlayer
var installed_by_hub := false
var opened_gaaglu := false
var prologue := false
var hub_problem := ""
var team_started := false
var bayro_started := false

func setup(home: Node3D) -> void:
	world = home
	prologue = get_tree().has_meta("prologue")
	buzz = _sound("res://assets/audio/phone_buzz.wav", -8.0)
	ding = _sound("res://assets/audio/phone_ding.wav", -12.0)
	world.phone.add_thread("team", "Nhóm điều tra", "Bơ Tồ, Ba Rô, Huna", Color(0.42, 0.46, 0.52), "N")
	world.phone.reply_chosen.connect(_on_reply)
	world.phone.thread_opened.connect(_on_thread_opened)
	world.phone.feed_read.connect(_feed_done)
	world._add_touch(BED, "Nằm xuống giường", _bed)
	world._add_touch(DESK, "Ngồi vào máy tính", _desk)
	if prologue:
		world.player.enabled = false
		if OS.get_cmdline_args().has("--script"):
			world.fade.hide()
		else:
			begin_prologue()
		return
	var saved := ConfigFile.new()
	asked_consent = saved.load(CONSENT_FILE) == OK and saved.has_section_key("external", "allowed")
	consent = saved.get_value("external", "allowed", false)
	world.player.enabled = false
	if OS.get_cmdline_args().has("--script"):
		world.fade.hide()
		return
	if asked_consent:
		wake()
	else:
		_ask_consent()

# --- The evening he moves in ---------------------------------------------------------------------

# Peter came to Bến Trầu for the school. Nobody has told him whose house this was.
func begin_prologue() -> void:
	preload("res://scripts/game_progress.gd").mark("prologue")
	step = "settle"
	get_tree().remove_meta("prologue")
	world.phone.add_thread("sau", "Bà Sáu (chủ nhà)", "Hẻm 31", Color(0.72, 0.42, 0.20), "S")
	world.phone.threads["sau"].log.append({"text": "Nhà số 14 Hẻm 31 nha con. Số 14. Khóa để dưới chậu.", "mine": false, "garbled": false})
	world.phone.threads["sau"].log.append({"text": "Đừng hỏi người ta sao căn này rẻ.", "mine": false, "garbled": false})
	world.phone.clock_label.text = "19:40"
	world.phone._refresh_list()
	world.goal.text = "Lên lầu đi ngủ"
	if OS.get_cmdline_args().has("--script"):
		return
	world.show_card("Số 14, Hẻm 31 · Khu phố Bến Trầu\nThứ Sáu · 19:40")
	await get_tree().create_timer(2.6).timeout
	await create_tween().tween_property(world.fade, "modulate:a", 0.0, 1.2).finished
	world.fade.hide()
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.think("Tuần đầu ở căn nhà này. Mai mới bắt đầu tìm hiểu Trường NEH.")

# The night at the school that follows is a dream; it opens as Night 0 always has.
func _sleep_into_dream() -> void:
	step = "dreaming"
	world.player.enabled = false
	world.fade.show()
	world.fade.modulate.a = 0.0
	await create_tween().tween_property(world.fade, "modulate:a", 1.0, 1.4).finished
	world.show_card("Đêm đầu tiên ở căn nhà mới")
	await get_tree().create_timer(2.2).timeout
	get_tree().change_scene_to_file("res://scenes/school_runtime.tscn")

# --- Waking from the dream -----------------------------------------------------------------------

func wake() -> void:
	preload("res://scripts/game_progress.gd").mark("home")
	if consent:
		_start_hub()
	world.player.global_position = WAKE_SPOT
	step = "wake"
	world.phone.fake_new = world.phone.fake.post_count
	world.goal.text = "Mở điện thoại · Tab · Lướt Fake"
	if OS.get_cmdline_args().has("--script"):
		return
	world.show_card("Thứ Bảy · 05:52")
	await get_tree().create_timer(1.8).timeout
	await create_tween().tween_property(world.fade, "modulate:a", 0.0, 1.2).finished
	world.fade.hide()
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.think("Chỉ là mơ... Nhưng sao rõ tới vậy?")

func _feed_done() -> void:
	if step != "wake":
		return
	step = "ask"
	world.think("Phòng 103 sáng đèn, con gấu bông, cái ký hiệu con mắt... y như trong mơ.")
	world.goal.text = "Hỏi nhóm điều tra trên Tili"

func _on_thread_opened(id: String) -> void:
	if id == "team" and step == "ask" and not team_started:
		team_started = true
		world.phone.offer_replies(WAKE_ASK)
	elif id == "bayro" and step == "bayro" and not bayro_started:
		bayro_started = true
		world.goal.text = ""
		for line in BAYRO_TALK:
			await _type_line("bayro", line)
		world.phone.offer_replies(BAYRO_ASK)

func _on_reply(index: int) -> void:
	world.phone.clear_replies()
	if step == "ask":
		world.phone.send_mine("team", WAKE_ASK[index])
		step = "asked"
		for line in WAKE_REPLY:
			await _type_line("team", line)
		_install()
	elif step == "bayro":
		world.phone.send_mine("bayro", BAYRO_ASK[index])
		await _type_line("bayro", BAYRO_END)
		step = "go_out"
		world.goal.text = "Ra khỏi nhà · Tới Góc Cờ"
		world.set_exit(_leave_for_town)

func _type_line(id: String, text: String) -> void:
	await get_tree().create_timer(0.5).timeout
	world.phone.set_typing(true)
	await get_tree().create_timer(minf(0.5 + text.length() * 0.018, 1.8)).timeout
	world.phone.set_typing(false)
	world.phone.receive(id, text)
	ding.play()

func toggle_phone() -> void:
	if blocking():
		return
	world.phone.toggle()
	var open: bool = world.phone.is_open()
	world.player.enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open and step == "bayro" and not bayro_started:
		world.goal.text = "Bấm vào tin nhắn của Bảy Rô"

# --- Gaaglu and Bảy Rô ---------------------------------------------------------------------------

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
		world.goal.text = "Mở Gaaglu trên máy tính của bạn · Tìm trên Sợi Chỉ"
		await get_tree().create_timer(BAYRO_HUB_WAIT).timeout
		bayro_writes(false)
		return
	if consent:
		# They said yes, so say why nothing reached their desktop instead of failing silently.
		var reason := hub_problem if not hub_problem.is_empty() else "no_link"
		push_warning("Gaaglu not installed on the desktop: " + reason)
		world.phone._show_banner("Không cài được Gaaglu lên máy bạn", HUB_PROBLEMS[reason], "settings")
	world.goal.text = ""
	await get_tree().create_timer(BAYRO_SELF_WAIT).timeout
	bayro_writes(false)

# Bảy Rô's first message; the rest comes once his chat is opened.
func bayro_writes(from_soichi: bool) -> void:
	if step != "gaaglu":
		return
	step = "bayro"
	buzz.play()
	world.phone.add_thread("bayro", "Bảy Rô", "Vừa truy cập", Color(0.93, 0.70, 0.16), "B")
	world.phone.receive("bayro", BAYRO_FIRST[from_soichi])
	world.goal.text = "Bảy Rô vừa nhắn · Mở điện thoại"

func on_hub_message(message: Dictionary) -> void:
	match message.get("type"):
		"gaaglu_opened":
			if step == "gaaglu" and not opened_gaaglu:
				opened_gaaglu = true
				world.think("Hai thẻ: một trang tìm kiếm, một trang tên Sợi Chỉ.")
		"contact":
			match message.get("id"):
				"bayro":
					bayro_writes(true)
				"muoigio":
					muoi_gio_writes()

# Answering his reply on Sợi Chỉ: he gives the place and prices, and the town remembers him.
func muoi_gio_writes() -> void:
	if world.phone.threads.has("muoigio"):
		return
	var gear := Gear.read()
	gear.muoi_gio_known = true
	Gear.write(gear)
	buzz.play()
	world.phone.add_thread("muoigio", "Mười Gió", "Vừa truy cập", Color(0.22, 0.27, 0.32), "M")
	for line in MUOI_GIO_TALK:
		world.phone.receive("muoigio", line)

func _leave_for_town() -> void:
	world.player.enabled = false
	world.fade.show()
	world.fade.modulate.a = 0.0
	await create_tween().tween_property(world.fade, "modulate:a", 1.0, 1.2).finished
	world.show_card("Ngày 1 · Khu phố Bến Trầu")
	await get_tree().create_timer(1.8).timeout
	get_tree().change_scene_to_file("res://scenes/town.tscn")

func _bed() -> void:
	if step == "settle":
		_sleep_into_dream()
	else:
		world.think("Không ngủ lại được nữa.")

func _desk() -> void:
	if installed_by_hub:
		world.think("Không phải trên máy này. Là cái máy bạn đang dùng.")
	else:
		world.think("Máy vẫn mở từ tối qua. Chưa có gì mới.")

# --- Consent and the hub -------------------------------------------------------------------------

func step_name() -> String:
	return step

func blocking() -> bool:
	return panel != null

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
	wake()

# A build carries the hub beside the executable: nothing inside the pack can be run as a program.
static func hub_folder() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://hub")
	return OS.get_executable_path().get_base_dir().path_join("hub")

# Starts the Electron binary itself: the npm wrapper needs node, which a launcher's PATH may lack.
func _start_hub() -> void:
	if not OS.get_environment("NEH_HUB_SESSION").is_empty() or world.bridge.linked:
		return
	var hub: String = hub_folder()
	var binary := hub.path_join("node_modules/electron/dist/" + ("electron.exe" if OS.has_feature("windows") else "electron"))
	if not FileAccess.file_exists(binary):
		push_warning("Hub not found: " + binary)
		hub_problem = "missing"
		return
	var started := OS.create_process("/usr/bin/env", ["-u", "ELECTRON_RUN_AS_NODE", binary, hub, "--background"]) if not OS.has_feature("windows") else OS.create_process(binary, [hub, "--background"])
	if started < 0:
		push_warning("Hub did not start")
		hub_problem = "failed"
