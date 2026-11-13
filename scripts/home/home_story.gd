extends Node
# Peter's house. The evening he moves in ends in sleep, and his first night at NEH is a dream.
# Waking, Gaaglu is installed (only if the player agreed on the screen shown first) and he heads
# out into the town. The chats and posts of the old story were cleared: the phone is ready for the
# rewritten story to add threads (phone.add_thread / receive) and posts (data/social_posts.json).
const CONSENT_FILE := "user://external.cfg"
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

func setup(home: Node3D) -> void:
	world = home
	prologue = get_tree().has_meta("prologue")
	buzz = _sound("res://assets/audio/phone_buzz.wav", -8.0)
	ding = _sound("res://assets/audio/phone_ding.wav", -12.0)
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
	world.phone.clock_label.text = "19:40"
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
	step = "hungry"
	world.phone.date_text = "Thứ Bảy, 15 tháng 11"
	world.phone.fake_new = world.phone.fake.post_count
	world.goal.text = "Xuống bếp kiếm gì ăn"
	_install()
	if OS.get_cmdline_args().has("--script"):
		return
	world.show_card("Thứ Bảy · 05:52")
	await get_tree().create_timer(1.8).timeout
	await create_tween().tween_property(world.fade, "modulate:a", 0.0, 1.2).finished
	world.fade.hide()
	world.player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.think("Ah... Sau ngần ấy năm thì giấc mơ đó vẫn luôn quay lại ám ảnh mình.", 5.0)
	await get_tree().create_timer(5.4).timeout
	if step == "hungry":
		world.think("Có lẽ là mình sẽ đi kiếm gì đó ăn vậy.")

# The first thing after waking is breakfast (home_kitchen.gd); only then does the street open up.
func start_cooking() -> void:
	step = "cooking"
	world.kitchen.begin()

func cooked() -> void:
	step = "carry"

func sat_down() -> void:
	step = "eating"

func ate() -> void:
	step = "go_out"
	world.goal.text = "Ra khỏi nhà · Tới khu phố"
	world.set_exit(_leave_for_town)

func toggle_phone() -> void:
	if blocking():
		return
	world.phone.toggle()
	var open: bool = world.phone.is_open()
	world.player.enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

# --- Gaaglu --------------------------------------------------------------------------------------

func _install() -> void:
	if not consent:
		return
	if not world.bridge.linked:
		_start_hub()
		var left := HUB_WAIT
		while left > 0.0 and not world.bridge.linked:
			await get_tree().create_timer(0.5).timeout
			left -= 0.5
	if world.bridge.linked:
		world.bridge.send_text(JSON.stringify({"type": "install_gaaglu", "consent": true}))
		installed_by_hub = true
		return
	# They said yes, so say why nothing reached their desktop instead of failing silently.
	var reason := hub_problem if not hub_problem.is_empty() else "no_link"
	push_warning("Gaaglu not installed on the desktop: " + reason)
	world.phone._show_banner("Không cài được Gaaglu lên máy bạn", HUB_PROBLEMS[reason], "settings")

func on_hub_message(message: Dictionary) -> void:
	match message.get("type"):
		"gaaglu_opened":
			if not opened_gaaglu:
				opened_gaaglu = true
				world.think("Gaaglu mở được rồi. Tìm thử về Trường NEH xem.")

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
	return panel != null or world.kitchen.busy

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
