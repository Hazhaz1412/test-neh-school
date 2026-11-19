extends Node3D
# Exterior 3D Telescope, Astronomy Guidebook, Key (`key_with_tag.glb`) & Secret Room Station.
# Places `telescope.glb`, `books.glb` on a wooden lectern with `key_with_tag.glb`,
# and an adjacent Secret Observatory Room (`SecretRoomInteractable`) that unlocks with `key_with_tag.glb`
# to provide the Next Clue (`next_clue`) to the player.

const TELESCOPE_GLB := "res://assets/models/telescope/telescope.glb"
const BOOKS_GLB := "res://assets/models/telescope/books.glb"
const KEY_GLB := "res://assets/models/telescope/key_with_tag.glb"
const TelescopeView := preload("res://scripts/telescope/telescope_view.gd")
const BookView := preload("res://scripts/telescope/telescope_book_view.gd")
const TelescopeEventBus := preload("res://scripts/telescope/telescope_event_bus.gd")

const TELESCOPE_OFFSET := Vector3.ZERO
const BOOK_OFFSET := Vector3(1.15, 0.0, 0.12)
const SECRET_ROOM_OFFSET := Vector3(-1.85, 0.0, -0.45)
const INTERACT_REACH := 2.5

var telescope_interactable: Node3D
var book_interactable: Node3D
var secret_room_interactable: Node3D
var key_model_node: Node3D
var door_key_node: Node3D
var secret_door_hinge: Node3D
var secret_room_light: OmniLight3D
var broken_indicator_node: Node3D
var installed_lens_node: Node3D
var requires_lens_repair := false
var interactive := true
var active_ui: Control
var ui_parent: Node
var player_ref: Node3D
var render_layer := 1
var saved_mouse_mode := Input.MOUSE_MODE_CAPTURED

class StationInteractable extends Node3D:
	var station: Node3D
	var kind := "telescope"
	var keep_interaction_text := true

	func interaction_text() -> String:
		if station != null and not station.interactive:
			return ""
		var bus := TelescopeEventBus.instance()
		if kind == "telescope":
			if station != null and station.is_broken():
				if bus.has_item(TelescopeEventBus.ITEM_LENS_CORE):
					return "E · Gắn Cục Thấu Kính Tinh Tú vào Kính Thiên Văn để sửa kính"
				return "E · Kính thiên văn đang bị hư (Tìm Cục Thấu Kính ở Khu vui chơi)"
			return "E · Nhìn vào kính thiên văn"
		if kind == "book":
			return "E · Đọc sách hướng dẫn thiên văn"
		if bus.is_secret_room_opened():
			return "E · Xem Manh mối tiếp theo trong Căn phòng bí mật"
		if bus.has_item(TelescopeEventBus.ITEM_ROOM_KEY):
			return "E · Dùng Chìa khóa (key_with_tag) mở Căn phòng bí mật"
		return "E · Cửa Căn phòng bí mật (Cần giải Kính Thiên Văn lấy Chìa khóa)"

	func interact(_actor: Node = null) -> bool:
		if station == null or not station.interactive:
			return false
		if kind == "telescope":
			station.open_telescope()
		elif kind == "book":
			station.open_book()
		else:
			station.open_secret_room()
		return true

class SecretClueView extends Control:
	var close_callback: Callable
	var unlocked_flag := true

	func setup(on_close: Callable, is_unlocked: bool) -> void:
		close_callback = on_close
		unlocked_flag = is_unlocked
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build_ui()

	func _build_ui() -> void:
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.015, 0.025, 0.035, 0.86)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)

		var card := PanelContainer.new()
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		card.custom_minimum_size = Vector2(780, 460)
		card.offset_left = -390
		card.offset_right = 390
		card.offset_top = -230
		card.offset_bottom = 230
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.11, 0.09, 0.98) if unlocked_flag else Color(0.14, 0.08, 0.07, 0.98)
		style.border_color = Color(0.45, 0.96, 0.68, 1.0) if unlocked_flag else Color(0.88, 0.48, 0.36, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(10)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", style)
		add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		card.add_child(vbox)

		var title := Label.new()
		title.add_theme_font_size_override("font_size", 21)
		title.add_theme_color_override("font_color", Color(0.98, 0.90, 0.52))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title)

		var body := Label.new()
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", Color(0.90, 0.96, 0.92))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(body)

		if unlocked_flag:
			title.text = "🗝️ CĂN PHÒNG BÍ MẬT ĐÃ MỞ — MANH MỐI TIẾP THEO"
			body.text = (
				"Bạn đã tra chiếc Chìa khóa có thẻ (key_with_tag.glb) vào ổ khóa đồng của Căn Phòng Bí Mật cạnh Đài quan sát!\n\n" +
				"📜 NỘI DUNG MANH MỐI TIẾP THEO (HỒ SƠ MẬT THẤT THIÊN VĂN):\n" +
				"• Ba linh vật hiện hình trên vòm kính — Sư Tử Vàng (Leo · 59), Bọ Cạp Thiên Yết (Scorpius · 84) và Thủy Thần Bảo Bình (Aquarius · 18) — chính là 3 mốc canh giờ tuần tra ban đêm.\n" +
				"• Trên bàn gỗ bên trong căn phòng bí mật có lưu bản đồ dẫn xuống tầng hầm lưu trữ kèm chữ ký của người lập đài quan sát.\n" +
				"• Vật phẩm đã thu nhận qua EventBus:\n" +
				"    1. Chìa khóa có thẻ: key_with_tag (room_key)\n" +
				"    2. Manh mối tiếp theo: Hồ sơ Mật thất Đài quan sát (next_clue)\n" +
				"    3. La bàn Tinh tú (star_compass) & Thành tựu Người dẫn đường các vì sao (ach_star_guide)"
			)
		else:
			title.text = "🔒 CỬA CĂN PHÒNG BÍ MẬT ĐANG KHÓA"
			body.text = (
				"Cánh cửa gỗ dẫn vào Căn Phòng Bí Mật cạnh Đài quan sát đang khóa chặt bằng ổ khóa đồng.\n\n" +
				"• Để nhận được chiếc Chìa khóa có thẻ (key_with_tag.glb):\n" +
				"  1. Đọc Sách hướng dẫn thiên văn bên cạnh kính để xem hình dáng chòm sao ở nửa trên trang sách và thông tin sao thật (α, β, γ) ở nửa dưới.\n" +
				"  2. Nhìn vào Kính Thiên Văn (FOV = 30°), quét và giải đủ 3 Tọa độ Dị thường (loại bỏ các sao nhiễu cùng màu, nối đạt η ≥ 95%) để hiện hình 3 Linh vật đại diện.\n" +
				"  3. Khi giải xong, chiếc Chìa khóa (key_with_tag.glb) sẽ xuất hiện để bạn mở cánh cửa này!"
			)

		var close_btn := Button.new()
		close_btn.text = "Đóng · Esc"
		close_btn.custom_minimum_size = Vector2(200, 38)
		close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_btn.pressed.connect(close_view)
		vbox.add_child(close_btn)

	func close_view() -> void:
		if close_callback.is_valid():
			close_callback.call()
		queue_free()

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_view()
			get_viewport().set_input_as_handled()

class BrokenTelescopeView extends Control:
	var close_callback: Callable

	func setup(on_close: Callable) -> void:
		close_callback = on_close
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build_ui()

	func _build_ui() -> void:
		var backdrop := ColorRect.new()
		backdrop.color = Color(0.02, 0.015, 0.025, 0.86)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)

		var card := PanelContainer.new()
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		card.custom_minimum_size = Vector2(740, 410)
		card.offset_left = -370
		card.offset_right = 370
		card.offset_top = -205
		card.offset_bottom = 205
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.14, 0.07, 0.06, 0.98)
		style.border_color = Color(0.95, 0.52, 0.34, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(10)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 18
		style.content_margin_bottom = 18
		card.add_theme_stylebox_override("panel", style)
		add_child(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		card.add_child(vbox)

		var title := Label.new()
		title.text = "⚠️ KÍNH THIÊN VĂN ĐANG BỊ HƯ — THIẾU CỤC THẤU KÍNH TINH TÚ"
		title.add_theme_font_size_override("font_size", 21)
		title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title)

		var body := Label.new()
		body.text = (
			"Ổ gắn thị kính của chiếc Kính Thiên Văn bên cạnh gốc cây đang trống rỗng — Cục Thấu Kính Tinh Tú (Lõi Thấu Kính Quang Học) đã bị rơi mất nên không thể nhìn thấy bầu trời sao!\n\n" +
			"🔧 HƯỚNG DẪN SỬA KÍNH THIÊN VĂN:\n" +
			"1. Hãy lại chiếc giường cạnh gốc cây và nằm ngủ (nhấn E) để tiến vào Khu vui chơi ban đêm.\n" +
			"2. Tại quảng trường Khu vui chơi (gần lối vào, bên cạnh trụ Búa đập High Striker), tìm chiếc Bệ Đồng phát sáng màu ngọc lục bảo và nhặt [Cục Thấu Kính Tinh Tú].\n" +
			"3. Sau khi cầm Cục Thấu Kính Tinh Tú, hãy quay lại chiếc Kính Thiên Văn này và nhấn E để gắn vào ổ kính và kích hoạt hệ thống ngắm thiên văn!"
		)
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", Color(0.94, 0.92, 0.90))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(body)

		var close_btn := Button.new()
		close_btn.text = "Đã hiểu · Esc"
		close_btn.custom_minimum_size = Vector2(200, 38)
		close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_btn.pressed.connect(close_view)
		vbox.add_child(close_btn)

	func close_view() -> void:
		if close_callback.is_valid():
			close_callback.call()
		queue_free()

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			close_view()
			get_viewport().set_input_as_handled()

func setup(hud_parent: Node, player_node: Node3D, visual_layer := 1) -> void:
	ui_parent = hud_parent
	player_ref = player_node
	render_layer = visual_layer
	_build_visuals()
	var bus := TelescopeEventBus.instance()
	bus.observatory_drawer_opened.connect(_on_drawer_opened)
	bus.secret_room_opened.connect(_on_secret_room_opened)
	bus.lens_core_picked_up.connect(_on_lens_state_changed)
	bus.lens_core_installed.connect(_on_lens_state_changed)
	_sync_key_and_door_state()

func is_broken() -> bool:
	if not requires_lens_repair:
		return false
	return not TelescopeEventBus.instance().is_lens_installed()

func _build_visuals() -> void:
	# 1. Telescope (`telescope.glb`) with tripod stand & interaction area.
	telescope_interactable = StationInteractable.new()
	telescope_interactable.name = "TelescopeInteractable"
	telescope_interactable.station = self
	telescope_interactable.kind = "telescope"
	telescope_interactable.position = TELESCOPE_OFFSET
	add_child(telescope_interactable)

	var tele_model := _place_normalized_glb(TELESCOPE_GLB, telescope_interactable, Vector3.ZERO, 1.56, 0.35)
	if tele_model != null:
		tele_model.name = "TelescopeModel"
	if interactive:
		_build_lens_socket_visuals(telescope_interactable)
	_add_interaction_box(telescope_interactable, Vector3(0, 0.85, 0), Vector3(1.05, 1.75, 1.15), true)

	# 2. Book (`books.glb`): on a wooden pedestal with `key_with_tag.glb` when interactive (Dream Meadow),
	# or lying directly on the ground beside the telescope when non-interactive (School Rooftop).
	book_interactable = StationInteractable.new()
	book_interactable.name = "BookInteractable"
	book_interactable.station = self
	book_interactable.kind = "book"
	book_interactable.position = BOOK_OFFSET if interactive else Vector3(0.68, 0.0, 0.18)
	add_child(book_interactable)

	if interactive:
		_build_book_pedestal(book_interactable)
		var books_model := _place_normalized_glb(BOOKS_GLB, book_interactable, Vector3(-0.08, 0.86, 0), 0.32, -0.4)
		if books_model != null:
			books_model.name = "BooksModel"

		# Place the user-supplied `key_with_tag.glb` on the brass side tray of the book pedestal!
		key_model_node = _place_normalized_glb(KEY_GLB, book_interactable, Vector3(0.20, 0.87, 0.08), 0.30, 0.65, true)
		if key_model_node != null:
			key_model_node.name = "KeyModel"

		_add_interaction_box(book_interactable, Vector3(0, 0.65, 0), Vector3(0.85, 1.35, 0.85), true)
	else:
		var ground_books := _place_normalized_glb(BOOKS_GLB, book_interactable, Vector3.ZERO, 0.32, -0.45)
		if ground_books != null:
			ground_books.name = "BooksModel"

	# 3. Secret Observatory Room (`SecretRoomInteractable`) unlocked by `key_with_tag.glb` (only when interactive).
	if interactive:
		secret_room_interactable = StationInteractable.new()
		secret_room_interactable.name = "SecretRoomInteractable"
		secret_room_interactable.station = self
		secret_room_interactable.kind = "secret_room"
		secret_room_interactable.position = SECRET_ROOM_OFFSET
		secret_room_interactable.rotation_degrees.y = 22.0
		add_child(secret_room_interactable)

		_build_secret_room(secret_room_interactable)
		_add_interaction_box(secret_room_interactable, Vector3(0, 1.0, 0.4), Vector3(1.3, 2.0, 1.1), false)

	# Warm lantern light above the telescope and guidebook.
	var lamp := OmniLight3D.new()
	lamp.name = "StationLight"
	lamp.position = Vector3(0.55, 1.85, 0.35)
	lamp.light_color = Color(1.0, 0.86, 0.58)
	lamp.light_energy = 1.35
	lamp.omni_range = 6.5
	add_child(lamp)

	if render_layer != 1:
		for vis: VisualInstance3D in find_children("*", "VisualInstance3D", true, false):
			if not (vis is Light3D):
				vis.layers = render_layer

func _build_secret_room(parent: Node3D) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.24, 0.27)
	stone.roughness = 0.85

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.28, 0.17, 0.10)
	wood.roughness = 0.65

	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.66, 0.32)
	brass.metallic = 0.88
	brass.roughness = 0.28

	var clue_mat := StandardMaterial3D.new()
	clue_mat.albedo_color = Color(0.95, 0.90, 0.74)
	clue_mat.emission_enabled = true
	clue_mat.emission = Color(0.95, 0.82, 0.45)
	clue_mat.emission_energy_multiplier = 0.65

	# Chamber back wall, left wall, right wall, and roof cap.
	var back_wall := MeshInstance3D.new()
	var bw_mesh := BoxMesh.new()
	bw_mesh.size = Vector3(1.35, 2.05, 0.10)
	back_wall.mesh = bw_mesh
	back_wall.material_override = stone
	back_wall.position = Vector3(0, 1.025, -0.55)
	parent.add_child(back_wall)

	for side in [-1.0, 1.0]:
		var sw := MeshInstance3D.new()
		var sw_mesh := BoxMesh.new()
		sw_mesh.size = Vector3(0.10, 2.05, 1.15)
		sw.mesh = sw_mesh
		sw.material_override = stone
		sw.position = Vector3(side * 0.625, 1.025, 0.0)
		parent.add_child(sw)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.48, 0.12, 1.28)
	roof.mesh = roof_mesh
	roof.material_override = wood
	roof.position = Vector3(0, 2.08, 0.0)
	parent.add_child(roof)

	# Interior Clue Table & Next Clue Dossier inside the Secret Room.
	var table := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(0.75, 0.76, 0.46)
	table.mesh = t_mesh
	table.material_override = wood
	table.position = Vector3(0, 0.38, -0.18)
	parent.add_child(table)

	var clue_sheet := MeshInstance3D.new()
	clue_sheet.name = "NextClueDossier"
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(0.42, 0.02, 0.30)
	clue_sheet.mesh = c_mesh
	clue_sheet.material_override = clue_mat
	clue_sheet.position = Vector3(0, 0.78, -0.16)
	parent.add_child(clue_sheet)

	# Hinged Secret Room Door at the front (+Z = 0.55).
	secret_door_hinge = Node3D.new()
	secret_door_hinge.name = "SecretDoorHinge"
	secret_door_hinge.position = Vector3(-0.56, 0.0, 0.55)
	parent.add_child(secret_door_hinge)

	var door_leaf := MeshInstance3D.new()
	door_leaf.name = "SecretDoorLeaf"
	var dl_mesh := BoxMesh.new()
	dl_mesh.size = Vector3(1.12, 1.98, 0.07)
	door_leaf.mesh = dl_mesh
	door_leaf.material_override = wood
	door_leaf.position = Vector3(0.56, 0.99, 0.0)
	secret_door_hinge.add_child(door_leaf)

	var lock_plate := MeshInstance3D.new()
	var lp_mesh := BoxMesh.new()
	lp_mesh.size = Vector3(0.12, 0.22, 0.09)
	lock_plate.mesh = lp_mesh
	lock_plate.material_override = brass
	lock_plate.position = Vector3(0.98, 0.98, 0.02)
	secret_door_hinge.add_child(lock_plate)

	# `key_with_tag.glb` inserted into the secret room door lock!
	door_key_node = _place_normalized_glb(KEY_GLB, secret_door_hinge, Vector3(0.98, 0.96, 0.08), 0.26, 0.0, true)
	if door_key_node != null:
		door_key_node.name = "DoorKeyModel"

	secret_room_light = OmniLight3D.new()
	secret_room_light.name = "SecretRoomLight"
	secret_room_light.position = Vector3(0, 1.65, -0.10)
	secret_room_light.light_color = Color(0.48, 0.98, 0.72)
	secret_room_light.light_energy = 1.4
	secret_room_light.omni_range = 4.2
	parent.add_child(secret_room_light)

func _build_lens_socket_visuals(parent: Node3D) -> void:
	# Broken socket indicator (amber-red warning ring where the missing lens core belongs).
	broken_indicator_node = Node3D.new()
	broken_indicator_node.name = "BrokenIndicator"
	broken_indicator_node.position = Vector3(0.0, 1.26, 0.14)
	parent.add_child(broken_indicator_node)

	var broken_mat := StandardMaterial3D.new()
	broken_mat.albedo_color = Color(0.95, 0.32, 0.20)
	broken_mat.emission_enabled = true
	broken_mat.emission = Color(1.0, 0.36, 0.18)
	broken_mat.emission_energy_multiplier = 1.6

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.065
	ring_mesh.outer_radius = 0.095
	var broken_ring := MeshInstance3D.new()
	broken_ring.mesh = ring_mesh
	broken_ring.material_override = broken_mat
	broken_ring.rotation_degrees.x = 65.0
	broken_indicator_node.add_child(broken_ring)

	# Installed Lens Core visual (glowing emerald-cyan crystal sphere inside a brass gimbal ring).
	installed_lens_node = Node3D.new()
	installed_lens_node.name = "InstalledLensCore"
	installed_lens_node.position = Vector3(0.0, 1.26, 0.14)
	parent.add_child(installed_lens_node)

	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.35, 0.98, 0.78, 0.92)
	lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.32, 0.96, 0.76)
	lens_mat.emission_energy_multiplier = 2.0
	lens_mat.roughness = 0.08
	lens_mat.metallic = 0.25

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.85, 0.68, 0.34)
	brass_mat.metallic = 0.9
	brass_mat.roughness = 0.25

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.075
	orb_mesh.height = 0.15
	var orb := MeshInstance3D.new()
	orb.mesh = orb_mesh
	orb.material_override = lens_mat
	installed_lens_node.add_child(orb)

	var mount_ring := MeshInstance3D.new()
	mount_ring.mesh = ring_mesh
	mount_ring.material_override = brass_mat
	mount_ring.rotation_degrees.x = 65.0
	installed_lens_node.add_child(mount_ring)

func _sync_key_and_door_state() -> void:
	var bus := TelescopeEventBus.instance()
	var has_key: bool = bus.has_item(TelescopeEventBus.ITEM_ROOM_KEY)
	var room_open: bool = bus.is_secret_room_opened()
	var broken := is_broken()
	if secret_door_hinge != null:
		secret_door_hinge.rotation_degrees.y = -96.0 if room_open else 0.0
	if door_key_node != null:
		door_key_node.visible = has_key or room_open
	if secret_room_light != null:
		secret_room_light.light_energy = 1.8 if room_open else 0.6
	if broken_indicator_node != null:
		broken_indicator_node.visible = broken
	if installed_lens_node != null:
		installed_lens_node.visible = not broken

func _on_lens_state_changed(_payload: Dictionary) -> void:
	_sync_key_and_door_state()

func _on_drawer_opened(_payload: Dictionary) -> void:
	_sync_key_and_door_state()

func _on_secret_room_opened(_payload: Dictionary) -> void:
	_sync_key_and_door_state()

func _build_book_pedestal(parent: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.20, 0.12)
	wood.roughness = 0.68

	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.76, 0.60, 0.32)
	brass.metallic = 0.85
	brass.roughness = 0.32

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.24
	base_mesh.bottom_radius = 0.28
	base_mesh.height = 0.08
	base.mesh = base_mesh
	base.material_override = wood
	base.position = Vector3(0, 0.04, 0)
	parent.add_child(base)

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 0.74
	post.mesh = post_mesh
	post.material_override = wood
	post.position = Vector3(0, 0.43, 0)
	parent.add_child(post)

	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.68, 0.06, 0.50)
	top.mesh = top_mesh
	top.material_override = wood
	top.position = Vector3(0, 0.83, 0)
	parent.add_child(top)

	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(0.70, 0.025, 0.52)
	rim.mesh = rim_mesh
	rim.material_override = brass
	rim.position = Vector3(0, 0.85, 0)
	parent.add_child(rim)

func _place_normalized_glb(path: String, parent: Node3D, base_pos: Vector3, target_size: float, yaw: float, use_longest_axis := false) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var wrapper := Node3D.new()
	parent.add_child(wrapper)
	var model: Node3D = packed.instantiate()
	wrapper.add_child(model)

	var bounds := AABB()
	var has_bounds := false
	for mesh_inst: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh_inst.mesh == null:
			continue
		var rel_xform := wrapper.global_transform.affine_inverse() * mesh_inst.global_transform
		var piece := rel_xform * mesh_inst.mesh.get_aabb()
		bounds = piece if not has_bounds else bounds.merge(piece)
		has_bounds = true

	var ref_dim := bounds.get_longest_axis_size() if use_longest_axis else bounds.size.y
	if has_bounds and ref_dim > 0.0001:
		var scale_factor := target_size / ref_dim
		model.scale *= scale_factor
		var center_xz := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z) * scale_factor
		var bottom_y := bounds.position.y * scale_factor
		model.position -= center_xz + Vector3(0, bottom_y, 0)

	wrapper.position = base_pos
	wrapper.rotation.y = yaw
	return wrapper

func _add_interaction_box(parent: Node3D, center: Vector3, box_size: Vector3, add_solid: bool) -> void:
	if interactive:
		var area := Area3D.new()
		area.name = "InteractionArea"
		area.collision_layer = 16
		area.collision_mask = 0
		var cshape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		cshape.shape = box
		cshape.position = center
		area.add_child(cshape)
		parent.add_child(area)

	if add_solid:
		var body := StaticBody3D.new()
		body.name = "SolidBody"
		var bshape := CollisionShape3D.new()
		var sbox := BoxShape3D.new()
		sbox.size = Vector3(box_size.x * 0.55, box_size.y * 0.85, box_size.z * 0.55)
		bshape.shape = sbox
		bshape.position = center
		body.add_child(bshape)
		parent.add_child(body)

func is_open() -> bool:
	return is_instance_valid(active_ui)

func telescope_world_position() -> Vector3:
	return telescope_interactable.global_position if telescope_interactable != null else global_position

func book_world_position() -> Vector3:
	return book_interactable.global_position if book_interactable != null else global_position + BOOK_OFFSET

func secret_room_world_position() -> Vector3:
	return secret_room_interactable.global_position if secret_room_interactable != null else global_position + SECRET_ROOM_OFFSET

func nearest_part(at: Vector3) -> String:
	if not interactive or is_open():
		return ""
	if absf(at.y - global_position.y) > 2.2:
		return ""
	var t_pos := telescope_world_position()
	var b_pos := book_world_position()
	var d_tele := Vector2(at.x - t_pos.x, at.z - t_pos.z).length()
	var d_book := Vector2(at.x - b_pos.x, at.z - b_pos.z).length()
	var d_sec := INF
	if secret_room_interactable != null:
		var s_pos := secret_room_world_position()
		d_sec = Vector2(at.x - s_pos.x, at.z - s_pos.z).length()
	var best_d := minf(d_tele, minf(d_book, d_sec))
	if best_d > INTERACT_REACH:
		return ""
	if best_d == d_book:
		return "book"
	if best_d == d_sec:
		return "secret_room"
	return "telescope"

func prompt_for(at: Vector3) -> String:
	match nearest_part(at):
		"telescope":
			return (telescope_interactable as StationInteractable).interaction_text()
		"book":
			return "E · Đọc sách hướng dẫn thiên văn"
		"secret_room":
			return (secret_room_interactable as StationInteractable).interaction_text()
	return ""

func interact_nearest(at: Vector3) -> bool:
	match nearest_part(at):
		"telescope":
			open_telescope()
			return true
		"book":
			open_book()
			return true
		"secret_room":
			open_secret_room()
			return true
	return false

# Convenience helper to pick up + install the lens core and open the eyepiece immediately.
func repair_and_open_telescope() -> void:
	var bus := TelescopeEventBus.instance()
	if not bus.has_item(TelescopeEventBus.ITEM_LENS_CORE):
		bus.pickup_lens_core()
	bus.install_lens_core()
	_sync_key_and_door_state()
	open_telescope()

func open_telescope() -> void:
	if is_open():
		active_ui.queue_free()
		active_ui = null
	var bus := TelescopeEventBus.instance()
	if is_broken():
		if bus.has_item(TelescopeEventBus.ITEM_LENS_CORE):
			bus.install_lens_core()
			_sync_key_and_door_state()
		else:
			_lock_player(true)
			var broken_ui := BrokenTelescopeView.new()
			broken_ui.name = "BrokenTelescopeView"
			_mount_ui(broken_ui)
			broken_ui.setup(_on_ui_closed)
			active_ui = broken_ui
			return
	_lock_player(true)
	var view := TelescopeView.new()
	view.name = "TelescopeView"
	_mount_ui(view)
	view.setup(_on_ui_closed)
	active_ui = view

func open_book() -> void:
	if is_open():
		active_ui.queue_free()
		active_ui = null
	_lock_player(true)
	var book := BookView.new()
	book.name = "TelescopeBookView"
	_mount_ui(book)
	book.setup(_on_ui_closed, open_telescope)
	active_ui = book

func open_secret_room() -> void:
	if is_open():
		active_ui.queue_free()
		active_ui = null
	var bus := TelescopeEventBus.instance()
	var res: Dictionary = bus.unlock_secret_room()
	_sync_key_and_door_state()
	_lock_player(true)
	var clue_ui := SecretClueView.new()
	clue_ui.name = "SecretClueView"
	_mount_ui(clue_ui)
	clue_ui.setup(_on_ui_closed, bool(res.unlocked))
	active_ui = clue_ui

func _mount_ui(control: Control) -> void:
	if ui_parent != null and is_instance_valid(ui_parent):
		ui_parent.add_child(control)
	else:
		get_tree().current_scene.add_child(control)

func _lock_player(locked: bool) -> void:
	if locked:
		saved_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if player_ref != null and is_instance_valid(player_ref):
			player_ref.set("enabled", false)
			if player_ref is CharacterBody3D:
				(player_ref as CharacterBody3D).velocity = Vector3.ZERO
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player_ref != null and is_instance_valid(player_ref):
			player_ref.set("enabled", true)
	_sync_key_and_door_state()

func _on_ui_closed() -> void:
	active_ui = null
	_lock_player(false)
