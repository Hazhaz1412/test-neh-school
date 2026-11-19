extends Control
# Telescope Eyepiece Minigame Controller & View.
# Features:
# 1. 3D Celestial Sphere: All 3 target constellations, decoy stars (identical color to real stars!),
#    and 1,500 background stars on a single continuous 3D hemisphere.
# 2. Optical Eyepiece (FOV = 30 deg): Green circular reticle, WASD / Arrow scanning of (psi, theta),
#    dot-product Frustum Culling P_i . F_cam >= cos(FOV/2), Gnomonic + Barrel Distortion, and Parallax clouds.
# 3. Auto-Focus Lock (<= 4 deg) & Spherical Subgraph Geodesic TSP (D_ij = arccos(P_i . P_j) on V_real).
# 4. Constellation Completion Replay & Animal Reveal: When a constellation is solved (eta >= 95%),
#    re-traces the light beam from the first star to the last star and materializes the constellation's
#    representative animal figure over the stars.
# 5. Two-Layer Unlock: Grants `key_with_tag.glb` (`room_key`) to open the Secret Room for the Next Clue.

signal closed

const DomeProjection := preload("res://scripts/telescope/dome_projection.gd")
const HybridTSPSolver := preload("res://scripts/telescope/hybrid_tsp_solver.gd")
const TelescopeEventBus := preload("res://scripts/telescope/telescope_event_bus.gd")
const BookView := preload("res://scripts/telescope/telescope_book_view.gd")
const LENS_SHADER := preload("res://assets/materials/telescope_lens.gdshader")

const LENS_CENTER := Vector2(440.0, 360.0)
const LENS_RADIUS := 296.0
const ROTATE_SPEED := 0.36
const STAR_CLICK_RADIUS := 22.0

var projection := DomeProjection.new()
var close_callback: Callable
var current_index := 0
var cam_theta := 0.0 # Azimuth psi (radians)
var cam_phi := 0.0   # Elevation theta (radians)
var dome_locked := false
var show_hint := false
var unlocked := false
var lock_anim := 0.0
var dragging_dome := false
var hover_star := -1
var lock_cooldown := 0.0

# Replay & Animal Figure Reveal state when a constellation is solved:
var replay_active := false
var replay_progress := 1.0 # 0.0 -> 1.0 traces from star #1 to #N_real
var animal_reveal_alpha := 0.0 # 0.0 -> 1.0 fades in the representative animal after replay

var projected_stars := PackedVector2Array()
var star_visible: Array[bool] = []
var dist_info := {}
var solver_result := {}
var player_path := PackedInt32Array()
var eval_result := {}
var solved_anomalies := {}

var lens_overlay: ColorRect
var lens_mat: ShaderMaterial
var title_label: Label
var algo_label: Label
var dome_status_label: Label
var stats_label: Label
var eta_label: Label
var drawer_status_label: Label
var safe_input: LineEdit
var safe_btn: Button
var reward_panel: PanelContainer
var reward_label: Label
var lock_btn: Button
var hint_btn: Button
var level_buttons: Array[Button] = []
var chime_player: AudioStreamPlayer

func setup(on_close: Callable, initial_constellation := 0) -> void:
	close_callback = on_close
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	select_constellation(initial_constellation)

func _build_ui() -> void:
	lens_mat = ShaderMaterial.new()
	lens_mat.shader = LENS_SHADER
	lens_mat.set_shader_parameter("viewport_size", Vector2(1280.0, 720.0))
	lens_mat.set_shader_parameter("lens_center", LENS_CENTER)
	lens_mat.set_shader_parameter("lens_radius", LENS_RADIUS)
	lens_mat.set_shader_parameter("locked", 0.0)

	lens_overlay = ColorRect.new()
	lens_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens_overlay.material = lens_mat
	lens_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lens_overlay)

	var panel := PanelContainer.new()
	panel.position = Vector2(772, 14)
	panel.size = Vector2(492, 692)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.04, 0.08, 0.07, 0.95)
	pstyle.border_color = Color(0.26, 0.78, 0.48, 0.9)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(10)
	pstyle.content_margin_left = 14
	pstyle.content_margin_right = 14
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var header := _make_label(vbox, 17, Color(0.46, 0.98, 0.68))
	header.text = "🔭 ĐÀI QUAN SÁT MẶT CẦU THIÊN VĂN 3D (FOV = 30°)"

	var level_caption := _make_label(vbox, 12, Color(0.74, 0.90, 0.82))
	level_caption.text = "3 Tọa Độ Dị Thường (Gợi ý vùng phương vị ψ, θ để lia kính tìm):"
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 3)
	vbox.add_child(level_box)

	level_buttons.clear()
	for i in range(projection.constellations.size()):
		var c: Dictionary = projection.constellations[i]
		var btn := _make_button("📡 " + str(c.anomaly_title), select_constellation.bind(i))
		btn.custom_minimum_size.y = 25
		level_box.add_child(btn)
		level_buttons.append(btn)

	_add_divider(vbox)

	title_label = _make_label(vbox, 14, Color(0.94, 0.98, 0.90))
	algo_label = _make_label(vbox, 12, Color(0.56, 0.92, 0.78))
	dome_status_label = _make_label(vbox, 13, Color(0.95, 0.84, 0.46))
	stats_label = _make_label(vbox, 12, Color(0.86, 0.92, 0.90))
	eta_label = _make_label(vbox, 14, Color(0.55, 0.98, 0.72))

	_add_divider(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)
	lock_btn = _make_button("🎯 Khóa tiêu cự (≤ 4°)", _toggle_or_snap_lock)
	lock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(lock_btn)

	hint_btn = _make_button("💡 Bật Gợi ý lộ trình", toggle_hint)
	hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(hint_btn)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)
	var undo_btn := _make_button("↩ Gỡ bước cuối", undo_last_star)
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(undo_btn)

	var reset_btn := _make_button("🔄 Nối lại từ đầu", clear_player_path)
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(reset_btn)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	vbox.add_child(row3)
	var book_btn := _make_button("■ Đọc Sách hướng dẫn (12 Cung)", _open_guidebook)
	book_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(book_btn)

	var auto_btn := _make_button("⚡ Nối chuẩn V_real", apply_optimal_solution)
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(auto_btn)

	_add_divider(vbox)

	var lock2_header := _make_label(vbox, 13, Color(0.98, 0.88, 0.52))
	lock2_header.text = "🗝️ CHÌA KHÓA PHÒNG BÍ MẬT & KÉT SẮT 6 SỐ"

	drawer_status_label = _make_label(vbox, 12, Color(0.84, 0.92, 0.88))

	var safe_row := HBoxContainer.new()
	safe_row.add_theme_constant_override("separation", 6)
	vbox.add_child(safe_row)

	safe_input = LineEdit.new()
	safe_input.placeholder_text = "Nhập mật mã 6 số (Dị thường #1→#2→#3)..."
	safe_input.max_length = 6
	safe_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe_input.custom_minimum_size.y = 28
	safe_input.add_theme_font_size_override("font_size", 13)
	safe_input.text_submitted.connect(_on_safe_code_submitted)
	safe_row.add_child(safe_input)

	safe_btn = _make_button("🔓 Mở Két Sắt", _on_safe_unlock_pressed)
	safe_btn.custom_minimum_size = Vector2(128, 28)
	safe_row.add_child(safe_btn)

	reward_panel = PanelContainer.new()
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.08, 0.24, 0.16, 0.96)
	rstyle.border_color = Color(0.42, 0.96, 0.66, 1.0)
	rstyle.set_border_width_all(2)
	rstyle.set_corner_radius_all(6)
	rstyle.content_margin_left = 10
	rstyle.content_margin_right = 10
	rstyle.content_margin_top = 6
	rstyle.content_margin_bottom = 6
	reward_panel.add_theme_stylebox_override("panel", rstyle)
	vbox.add_child(reward_panel)
	reward_label = _make_label(reward_panel, 12, Color(0.92, 1.0, 0.94))
	reward_panel.hide()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var help_lbl := _make_label(vbox, 11, Color(0.68, 0.82, 0.74))
	help_lbl.text = "WASD / Mũi tên: Quét bầu trời (ψ, θ) · Chuột trái: Nối sao · Chuột phải: Gỡ bước"

	var exit_btn := _make_button("Rời Kính Thiên Văn · Esc", close_telescope)
	exit_btn.custom_minimum_size.y = 32
	vbox.add_child(exit_btn)

	if ResourceLoader.exists("res://assets/audio/memory.wav"):
		chime_player = AudioStreamPlayer.new()
		chime_player.stream = load("res://assets/audio/memory.wav")
		chime_player.volume_db = -12.0
		add_child(chime_player)

func _make_label(parent: Control, font_px: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_px)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl

func _make_button(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 26
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(cb)
	return btn

func _add_divider(parent: Control) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.32, 0.68, 0.48, 0.35)
	parent.add_child(line)

func select_constellation(index: int) -> void:
	current_index = clampi(index, 0, projection.constellations.size() - 1)
	var c: Dictionary = projection.constellations[current_index]
	cam_theta = float(c.initial_theta)
	cam_phi = float(c.initial_phi)
	dome_locked = false
	unlocked = solved_anomalies.has(current_index)
	replay_active = false
	replay_progress = 1.0 if unlocked else 0.0
	animal_reveal_alpha = 1.0 if unlocked else 0.0
	show_hint = false
	player_path.clear()
	dist_info.clear()
	solver_result.clear()
	eval_result.clear()
	if hint_btn != null:
		hint_btn.text = "💡 Bật Gợi ý lộ trình"
	_update_projected_stars()
	_refresh_labels()
	queue_redraw()

func _toggle_or_snap_lock() -> void:
	if dome_locked:
		dome_locked = false
		lock_cooldown = 0.65
		player_path.clear()
		_refresh_labels()
		queue_redraw()
	else:
		lock_dome_immediately()

func _update_projected_stars() -> void:
	var c: Dictionary = projection.constellations[current_index]
	var stars: Array = c.stars
	projected_stars.resize(stars.size())
	star_visible.resize(stars.size())
	var f_cam := DomeProjection.camera_forward(cam_theta, cam_phi)
	for i in range(stars.size()):
		var st: Dictionary = stars[i]
		var p3: Vector3 = st.get("pos_3d", DomeProjection.spherical_to_cartesian(float(st.alpha), float(st.delta)))
		if not DomeProjection.frustum_cull(p3, f_cam):
			projected_stars[i] = LENS_CENTER
			star_visible[i] = false
			continue
		var proj := DomeProjection.project_point_3d(p3, cam_theta, cam_phi, LENS_RADIUS, LENS_CENTER)
		projected_stars[i] = proj.pos
		star_visible[i] = bool(proj.visible)

func lock_dome_immediately() -> void:
	var c: Dictionary = projection.constellations[current_index]
	cam_theta = float(c.lock_alpha)
	cam_phi = float(c.lock_delta)
	_engage_lock_for_constellation(current_index)

func _engage_lock_for_constellation(idx: int) -> void:
	current_index = idx
	var c: Dictionary = projection.constellations[current_index]
	_update_projected_stars()
	if not dome_locked:
		dome_locked = true
		unlocked = solved_anomalies.has(current_index)
		dist_info = DomeProjection.compute_spherical_distance_matrix(c.stars)
		solver_result = HybridTSPSolver.solve(dist_info.flat, dist_info.n)
		TelescopeEventBus.instance().notify_dome_locked(str(c.id), dist_info.n)
		_evaluate_progress()
	_refresh_labels()
	queue_redraw()

func toggle_hint() -> void:
	if not dome_locked:
		lock_dome_immediately()
	show_hint = not show_hint
	hint_btn.text = "💡 Ẩn Gợi ý lộ trình" if show_hint else "💡 Bật Gợi ý lộ trình"
	queue_redraw()

func clear_player_path() -> void:
	player_path.clear()
	unlocked = solved_anomalies.has(current_index)
	replay_active = false
	animal_reveal_alpha = 1.0 if unlocked else 0.0
	if dome_locked:
		_evaluate_progress()
	_refresh_labels()
	queue_redraw()

func undo_last_star() -> void:
	if player_path.size() > 0:
		player_path.resize(player_path.size() - 1)
		unlocked = solved_anomalies.has(current_index)
		if dome_locked:
			_evaluate_progress()
		_refresh_labels()
		queue_redraw()

func apply_optimal_solution() -> void:
	if not dome_locked:
		lock_dome_immediately()
	if solver_result.has("optimal_path") and dist_info.has("real_indices"):
		var opt_real_path: PackedInt32Array = solver_result.optimal_path
		var real_indices: PackedInt32Array = dist_info.real_indices
		player_path.clear()
		for r_idx in opt_real_path:
			if r_idx >= 0 and r_idx < real_indices.size():
				player_path.append(real_indices[r_idx])
		_evaluate_progress()
		_refresh_labels()
		queue_redraw()

func click_star(star_index: int) -> void:
	if not dome_locked:
		return
	var c: Dictionary = projection.constellations[current_index]
	var stars: Array = c.stars
	if star_index < 0 or star_index >= stars.size():
		return
	if player_path.size() > 0 and player_path[player_path.size() - 1] == star_index:
		undo_last_star()
		return
	if player_path.has(star_index):
		return
	player_path.append(star_index)
	_evaluate_progress()
	_refresh_labels()
	queue_redraw()

func _evaluate_progress() -> void:
	if not dome_locked or solver_result.is_empty():
		return
	var c: Dictionary = projection.constellations[current_index]
	var opt_len: float = float(solver_result.optimal_length)
	var flat_dist: PackedFloat32Array = dist_info.flat
	var real_indices: PackedInt32Array = dist_info.real_indices
	eval_result = HybridTSPSolver.evaluate_spherical_subgraph_route(
		player_path,
		c.stars,
		opt_len,
		flat_dist,
		real_indices
	)
	if bool(eval_result.unlocked) and not unlocked:
		unlocked = true
		solved_anomalies[current_index] = true
		# Start the "re-connect from the beginning -> reveal constellation animal" sequence!
		replay_active = true
		replay_progress = 0.0
		animal_reveal_alpha = 0.0
		if chime_player != null:
			chime_player.play()
		var bus := TelescopeEventBus.instance()
		var payload: Dictionary = bus.dispatch_lock_opened(
			str(c.id),
			float(eval_result.eta),
			opt_len,
			float(eval_result.player_length),
			str(solver_result.algorithm),
			str(c.passcode_digits)
		)
		reward_panel.show()
		var animal_title := str(c.get("animal_name", c.name))
		var msg := (
			"✦ KHỚP CHÒM SAO (η = %.1f%% ≥ 95%%) · HIỆN HÌNH LINH VẬT: %s!\n" % [float(payload.eta) * 100.0, animal_title.to_upper()] +
			"• Đang nối lại tia sáng từ đầu và hiện hình linh vật đại diện trên vòm kính."
		)
		if bus.is_drawer_opened():
			msg += "\n🗝️ ĐÃ NHẬN CHÌA KHÓA CÓ THẺ (key_with_tag): Hãy dùng chìa khóa mở Căn Phòng Bí Mật bên cạnh để lấy Manh mối tiếp theo!"
		reward_label.text = msg
		_update_anomaly_buttons()

func _update_anomaly_buttons() -> void:
	for i in range(level_buttons.size()):
		var c: Dictionary = projection.constellations[i]
		var prefix := "✓ " if solved_anomalies.has(i) else "📡 "
		level_buttons[i].text = prefix + str(c.anomaly_title)

func _on_safe_code_submitted(_text: String) -> void:
	_on_safe_unlock_pressed()

func _on_safe_unlock_pressed() -> void:
	var bus := TelescopeEventBus.instance()
	var code := safe_input.text if safe_input != null else ""
	var res: Dictionary = bus.attempt_safe_unlock(code)
	reward_panel.show()
	if bool(res.unlocked):
		if chime_player != null:
			chime_player.play()
		reward_label.text = (
			"🔓 MỞ KÉT SẮT & NHẬN CHÌA KHÓA PHÒNG BÍ MẬT (Mã: %s)!\n" % str(res.passcode) +
			"• Bạn đã có Chìa khóa có thẻ (key_with_tag.glb) + Chứng cứ mới (new_evidence).\n" +
			"• Hãy bước sang Cửa Căn Phòng Bí Mật cạnh đài quan sát và bấm E để mở phòng lấy Manh mối tiếp theo!"
		)
	else:
		reward_label.text = "⚠ " + str(res.message)
	_refresh_labels()

func _refresh_labels() -> void:
	var c: Dictionary = projection.constellations[current_index]
	var n_real: int = int(c.get("real_count", 8))
	var n_decoy: int = int(c.get("decoy_count", 3))
	var psi_deg := wrapf(rad_to_deg(cam_theta), 0.0, 360.0)
	var theta_deg := rad_to_deg(cam_phi)

	if dome_locked:
		title_label.text = "Dị thường #%d · Sao thật |V_real| = %d (+%d sao nhiễu cùng màu)" % [current_index + 1, n_real, n_decoy]
	else:
		title_label.text = "Đang quét bầu trời 3D · Mục tiêu gợi ý: Dị thường #%d" % (current_index + 1)

	algo_label.text = "Phép chiếu: Gnomonic + Barrel Distortion · D_ij = arccos(P_i·P_j) trên V_real"

	var err_deg := rad_to_deg(DomeProjection.angular_error(cam_theta, cam_phi, float(c.lock_alpha), float(c.lock_delta)))
	if dome_locked:
		dome_status_label.text = "🔒 VÒM KÍNH ĐÃ KHỚP KHÓA (ψ = %.1f°, θ = %.1f° · Lệch %.1f° ≤ 4°)" % [psi_deg, theta_deg, err_deg]
		dome_status_label.add_theme_color_override("font_color", Color(0.45, 0.98, 0.68))
		lock_btn.text = "🔓 Mở khóa tiêu cự để quét tiếp"
	else:
		dome_status_label.text = "🔄 Đang lia kính (ψ = %.1f°, θ = %.1f°) · Cách tâm dị thường: %.1f° (Khóa ở ≤ 4°)" % [psi_deg, theta_deg, err_deg]
		dome_status_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.45))
		lock_btn.text = "🎯 Căn tâm khóa tiêu cự (≤ 4°)"

	if dome_locked and not solver_result.is_empty():
		var opt_len: float = float(solver_result.optimal_length)
		var player_len: float = float(eval_result.get("player_length", 0.0))
		var visited_cnt: int = int(eval_result.get("visited_count", 0))
		var decoy_cnt: int = int(eval_result.get("decoy_count", 0))
		stats_label.text = "Sao thật đã nối: %d / %d · Sao nhiễu dính phải: %d\nKhoảng cách trắc địa L_opt: %.3f rad · L_player: %.3f rad" % [visited_cnt, n_real, decoy_cnt, opt_len, player_len]
		if decoy_cnt > 0:
			eta_label.text = "⚠ Lộ trình đang đi qua %d Sao Nhiễu! Hãy mở Sách hướng dẫn đối chiếu hình dáng để gỡ sao nhiễu." % decoy_cnt
			eta_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.42))
		elif visited_cnt < 2:
			eta_label.text = "Hiệu suất η = L_optimal / L_player: — (Nối đủ %d sao thật V_real, η ≥ 95%%)" % n_real
			eta_label.add_theme_color_override("font_color", Color(0.82, 0.90, 0.86))
		else:
			var eta_pct: float = float(eval_result.get("eta", 0.0)) * 100.0
			var status_tag := ""
			if visited_cnt == n_real:
				status_tag = " · HIỆN HÌNH LINH VẬT: %s!" % str(c.get("animal_name", "")).to_upper() if unlocked else " · Chưa đạt η ≥ 95% (Hãy gỡ dây cắt chéo)"
			else:
				status_tag = " · Đang nối (%d/%d sao thật)..." % [visited_cnt, n_real]
			eta_label.text = "Hiệu suất η = %.1f%%%s" % [eta_pct, status_tag]
			eta_label.add_theme_color_override("font_color", Color(0.42, 0.98, 0.68) if eta_pct >= 95.0 else Color(0.98, 0.64, 0.42))
	else:
		stats_label.text = "Dùng WASD / Phím mũi tên lia thị kính (FOV = 30°) đến khi lệch tâm ≤ 4° để tự động khóa tiêu cự."
		eta_label.text = "Đối chiếu ký hiệu (α, β, γ) với Sách hướng dẫn 12 cung, loại bỏ sao nhiễu & đạt η ≥ 95%."

	var bus := TelescopeEventBus.instance()
	var solved_cnt: int = maxi(solved_anomalies.size(), bus.completed_count())
	if bus.is_safe_opened():
		drawer_status_label.text = "✅ Đã nhận Chìa khóa (key_with_tag) & mở Két sắt! Hãy dùng Chìa khóa mở Căn Phòng Bí Mật bên ngoài."
		drawer_status_label.add_theme_color_override("font_color", Color(0.46, 0.98, 0.68))
	elif bus.is_drawer_opened():
		drawer_status_label.text = "🗝️ ĐÃ NHẬN CHÌA KHÓA CÓ THẺ (key_with_tag) mở Căn Phòng Bí Mật! Nhập tiếp mật mã 6 số cho Két sắt:"
		drawer_status_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.48))
	else:
		drawer_status_label.text = "Tiến độ Chìa khóa phòng bí mật (key_with_tag): Đã giải %d / 3 chòm sao" % solved_cnt
		drawer_status_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.84))

func _process(delta: float) -> void:
	lock_anim += delta
	if lock_cooldown > 0.0:
		lock_cooldown = maxf(0.0, lock_cooldown - delta)
	if lens_mat != null:
		lens_mat.set_shader_parameter("locked", 1.0 if dome_locked else 0.0)
		lens_mat.set_shader_parameter("lock_pulse", lock_anim)

	# Advance the "re-connect from the start -> reveal constellation animal" animation!
	if unlocked:
		if replay_active:
			replay_progress = minf(1.0, replay_progress + delta * 3.2)
			if replay_progress >= 1.0:
				replay_active = false
		if not replay_active and animal_reveal_alpha < 1.0:
			animal_reveal_alpha = minf(1.0, animal_reveal_alpha + delta * 3.5)

	var move := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	)
	if move.length_squared() > 0.001:
		if dome_locked and unlocked:
			dome_locked = false
			lock_cooldown = 0.45
			player_path.clear()
		if not dome_locked:
			_rotate_dome(move.normalized() * ROTATE_SPEED * delta)
	elif not dome_locked and lock_cooldown <= 0.0:
		var hit_idx := projection.find_locked_constellation(cam_theta, cam_phi)
		if hit_idx >= 0:
			_engage_lock_for_constellation(hit_idx)
	queue_redraw()

func _rotate_dome(delta_angles: Vector2) -> void:
	if dome_locked:
		return
	cam_theta = wrapf(cam_theta + delta_angles.x, 0.0, TAU)
	cam_phi = clampf(cam_phi + delta_angles.y, 0.06, 1.35)
	_update_projected_stars()
	if lock_cooldown <= 0.0:
		var hit_idx := projection.find_locked_constellation(cam_theta, cam_phi)
		if hit_idx >= 0:
			_engage_lock_for_constellation(hit_idx)
			return
	_refresh_labels()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close_telescope()
			get_viewport().set_input_as_handled()
			return
		if safe_input != null and safe_input.has_focus():
			return
		if event.keycode == KEY_H:
			toggle_hint()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE and not dome_locked:
			lock_dome_immediately()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mpos: Vector2 = event.position * Vector2(1280.0, 720.0) / size
		var in_lens := mpos.distance_to(LENS_CENTER) <= LENS_RADIUS
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and in_lens:
				if dome_locked:
					var hit := _star_at_position(mpos)
					if hit >= 0:
						click_star(hit)
				else:
					dragging_dome = true
			else:
				dragging_dome = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and in_lens:
			if dome_locked:
				undo_last_star()

	elif event is InputEventMouseMotion:
		var mpos: Vector2 = event.position * Vector2(1280.0, 720.0) / size
		if dragging_dome and not dome_locked:
			_rotate_dome(Vector2(-event.relative.x, event.relative.y) * 0.0022)
		hover_star = _star_at_position(mpos) if dome_locked else -1

func _star_at_position(pos: Vector2) -> int:
	var best_idx := -1
	var best_dist := STAR_CLICK_RADIUS
	for i in range(projected_stars.size()):
		if i < star_visible.size() and not star_visible[i]:
			continue
		var d := pos.distance_to(projected_stars[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func _open_guidebook() -> void:
	var book := BookView.new()
	add_child(book)
	book.setup(Callable())

func close_telescope() -> void:
	closed.emit()
	if close_callback.is_valid():
		close_callback.call()
	queue_free()

func _draw() -> void:
	# 1. Deep night sky dome background inside the circular optical aperture (FOV = 30 deg).
	draw_circle(LENS_CENTER, LENS_RADIUS - 2.0, Color(0.015, 0.032, 0.055, 1.0))
	draw_circle(LENS_CENTER + Vector2(-34, -26), LENS_RADIUS * 0.68, Color(0.04, 0.12, 0.14, 0.32))

	# 2. Frustum Culling (P_i . F_cam >= cos(FOV/2)) + Gnomonic + Barrel Distortion on all 1,500 background stars.
	var f_cam := DomeProjection.camera_forward(cam_theta, cam_phi)
	var bg_list: Array[Dictionary] = projection.background_stars
	for i in range(bg_list.size()):
		var bg: Dictionary = bg_list[i]
		var p_bg: Vector3 = bg.pos_3d
		if not DomeProjection.frustum_cull(p_bg, f_cam):
			continue
		var proj := DomeProjection.project_point_3d(p_bg, cam_theta, cam_phi, LENS_RADIUS, LENS_CENTER)
		if bool(proj.visible):
			var flicker := 0.72 + 0.28 * sin(lock_anim * 2.1 + float(bg.twinkle))
			draw_circle(proj.pos, float(bg.size), Color(0.80, 0.94, 0.88, float(bg.brightness) * flicker))

	# 3. Also project any non-active target constellations that fall inside the current 30-deg FOV cone.
	for c_idx in range(projection.constellations.size()):
		if c_idx == current_index:
			continue
		var other_c: Dictionary = projection.constellations[c_idx]
		for st_other in other_c.stars:
			var p_other: Vector3 = st_other.pos_3d
			if DomeProjection.frustum_cull(p_other, f_cam):
				var pr := DomeProjection.project_point_3d(p_other, cam_theta, cam_phi, LENS_RADIUS, LENS_CENTER)
				if bool(pr.visible):
					draw_circle(pr.pos, 3.8, Color(0.76, 0.95, 0.84, 0.82))

	# 4. Parallax drifting cloud layer inside the lens aperture.
	for cloud in projection.parallax_clouds:
		var par: float = float(cloud.parallax)
		var cx := wrapf(float(cloud.base_x) - cam_theta * 380.0 * par + lock_anim * float(cloud.drift_speed), -LENS_RADIUS, LENS_RADIUS)
		var cy := wrapf(float(cloud.base_y) + cam_phi * 320.0 * par + sin(lock_anim * 0.4 + par * 5.0) * 14.0, -LENS_RADIUS, LENS_RADIUS)
		var cpos := LENS_CENTER + Vector2(cx, cy)
		var r_cloud: float = float(cloud.radius)
		var dist_center := cpos.distance_to(LENS_CENTER)
		if dist_center + r_cloud * 0.4 < LENS_RADIUS - 10.0:
			draw_circle(cpos, r_cloud, Color(0.16, 0.38, 0.32, float(cloud.alpha)))

	# 5. Green optical reticle rings & crosshairs ("Khung tròn xanh lá · FOV = 30°").
	var grid_col := Color(0.28, 0.92, 0.56, 0.22)
	for r_frac in [0.27, 0.54, 0.82]:
		draw_arc(LENS_CENTER, LENS_RADIUS * r_frac, 0.0, TAU, 72, grid_col, 1.2, true)
	var lock_ring_r := LENS_RADIUS * (tan(DomeProjection.LOCK_TOLERANCE) / DomeProjection.TAN_HALF_FOV)
	var lock_ring_col := Color(0.38, 1.0, 0.66, 0.68) if dome_locked else Color(0.32, 0.95, 0.56, 0.42)
	draw_arc(LENS_CENTER, lock_ring_r, 0.0, TAU, 48, lock_ring_col, 1.8, true)
	draw_line(LENS_CENTER - Vector2(LENS_RADIUS - 12, 0), LENS_CENTER + Vector2(LENS_RADIUS - 12, 0), grid_col, 1.0)
	draw_line(LENS_CENTER - Vector2(0, LENS_RADIUS - 12), LENS_CENTER + Vector2(0, LENS_RADIUS - 12), grid_col, 1.0)

	# 6. Target anomaly center marker.
	var c: Dictionary = projection.constellations[current_index]
	var center_p3: Vector3 = c.center_3d
	var lock_proj := DomeProjection.project_point_3d(center_p3, cam_theta, cam_phi, LENS_RADIUS, LENS_CENTER)
	if bool(lock_proj.visible):
		var ring_col := Color(0.38, 1.0, 0.68, 0.72) if dome_locked else Color(0.98, 0.84, 0.36, 0.78)
		draw_arc(lock_proj.pos, 22.0, 0.0, TAU, 48, ring_col, 2.0, true)
		if not dome_locked:
			draw_line(LENS_CENTER, lock_proj.pos, Color(0.98, 0.84, 0.36, 0.38), 1.5)

	# 7. Constellation Animal Figure Reveal (fades in after the re-connect trace completes!).
	if dome_locked and unlocked and animal_reveal_alpha > 0.01:
		var animal_scale := Vector2(LENS_RADIUS / DomeProjection.TAN_HALF_FOV, LENS_RADIUS / DomeProjection.TAN_HALF_FOV)
		DomeProjection.draw_constellation_animal(self, str(c.id), lock_proj.pos, animal_scale, animal_reveal_alpha)
		var font_a := ThemeDB.fallback_font
		if font_a != null:
			var banner_str := "✦ LINH VẬT HIỆN HÌNH: %s (MÃ SỐ: %s) ✦" % [str(c.get("animal_name", c.name)).to_upper(), str(c.passcode_digits)]
			draw_string(font_a, LENS_CENTER + Vector2(-175, -LENS_RADIUS + 42), banner_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.92, 0.46, animal_reveal_alpha))

	# 8. Visual Hint Path (reconstructed from Bitmask DP over V_real).
	if dome_locked and show_hint and solver_result.has("optimal_path") and dist_info.has("real_indices"):
		var opt_path: PackedInt32Array = solver_result.optimal_path
		var real_indices: PackedInt32Array = dist_info.real_indices
		for k in range(opt_path.size() - 1):
			var u := real_indices[opt_path[k]]
			var v := real_indices[opt_path[k + 1]]
			if star_visible[u] and star_visible[v]:
				_draw_dashed_line(projected_stars[u], projected_stars[v], Color(0.38, 0.98, 0.78, 0.58), 2.2, 8.0)

	# 9. Player's connected light strings (with animated "re-connect from the start" when solved!).
	var seg_count := player_path.size() - 1
	if seg_count > 0:
		var max_seg_float := float(seg_count) * (replay_progress if unlocked else 1.0)
		var full_segs := int(floor(max_seg_float))
		var frac_seg := max_seg_float - float(full_segs)
		var beam_col := Color(1.0, 0.92, 0.48, 0.96) if unlocked else Color(0.46, 0.98, 0.74, 0.92)

		for k in range(mini(full_segs, seg_count)):
			var u := player_path[k]
			var v := player_path[k + 1]
			var p1 := projected_stars[u]
			var p2 := projected_stars[v]
			draw_line(p1, p2, Color(beam_col.r, beam_col.g, beam_col.b, 0.28), 7.0, true)
			draw_line(p1, p2, beam_col, 2.6, true)

		if full_segs < seg_count and frac_seg > 0.01:
			var u := player_path[full_segs]
			var v := player_path[full_segs + 1]
			var p1 := projected_stars[u]
			var p2 := projected_stars[u].lerp(projected_stars[v], frac_seg)
			draw_line(p1, p2, Color(beam_col.r, beam_col.g, beam_col.b, 0.34), 8.0, true)
			draw_line(p1, p2, beam_col, 3.0, true)
			draw_circle(p2, 6.5, Color(1.0, 0.98, 0.78, 0.95))

	# 10. Active constellation real stars and decoy stars — IDENTICAL color & glow so decoys cannot be guessed by color!
	var stars: Array = c.stars
	var font := ThemeDB.fallback_font
	var opt_order := {}
	if dome_locked and show_hint and solver_result.has("optimal_path") and dist_info.has("real_indices"):
		var op: PackedInt32Array = solver_result.optimal_path
		var r_ind: PackedInt32Array = dist_info.real_indices
		for idx in range(op.size()):
			opt_order[r_ind[op[idx]]] = idx + 1

	for i in range(projected_stars.size()):
		if i < star_visible.size() and not star_visible[i]:
			continue
		var pos := projected_stars[i]
		var st: Dictionary = stars[i]
		var mag: float = float(st.get("mag", 3.0))
		var base_r := clampf(7.2 - mag * 0.72, 4.2, 6.8)
		var is_visited := player_path.has(i)
		var is_last := player_path.size() > 0 and player_path[player_path.size() - 1] == i
		var is_hovered := (i == hover_star)

		# Both real stars and decoy stars share the exact same glow and core colors!
		var glow_col := Color(1.0, 0.88, 0.36, 0.44) if is_visited else Color(0.46, 0.96, 0.74, 0.34)
		draw_circle(pos, base_r * 2.5, glow_col)
		if is_last or is_hovered:
			draw_arc(pos, base_r + 7.5, 0.0, TAU, 32, Color(1.0, 0.92, 0.50, 0.9), 2.0, true)

		var core_col := Color(1.0, 0.96, 0.74) if is_visited else Color(0.92, 0.98, 0.94)
		draw_circle(pos, base_r, core_col)

		if font != null:
			var sym := str(st.get("symbol", ""))
			if opt_order.has(i):
				draw_string(font, pos + Vector2(-6, -base_r - 8), "#%d (%s)" % [int(opt_order[i]), sym], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.98, 0.85, 0.96))
			elif sym in ["α", "β", "γ"]:
				draw_string(font, pos + Vector2(base_r + 5, 4), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.98, 0.88, 0.46, 0.95))
			elif is_hovered:
				draw_string(font, pos + Vector2(base_r + 5, 4), "Tinh tú", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.84, 0.94, 0.88, 0.88))

	# 11. Optical HUD readout inside the bottom of the green eyepiece ring.
	if font != null:
		var hud_str := "FOV: 30.0° · ψ = %05.1f° · θ = %04.1f° · Sao nền: 1500" % [wrapf(rad_to_deg(cam_theta), 0.0, 360.0), rad_to_deg(cam_phi)]
		draw_string(font, LENS_CENTER + Vector2(-148, LENS_RADIUS - 22), hud_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.48, 0.98, 0.68, 0.88))

func _draw_dashed_line(from: Vector2, to: Vector2, col: Color, width: float, dash_len: float) -> void:
	var total := from.distance_to(to)
	if total < 1.0:
		return
	var dir := (to - from) / total
	var d := 0.0
	while d < total:
		var seg_end := minf(d + dash_len, total)
		draw_line(from + dir * d, from + dir * seg_end, col, width, true)
		d += dash_len * 1.8
