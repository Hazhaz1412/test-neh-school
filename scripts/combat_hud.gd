extends Control

var combat: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if combat.world.paused_by_user or not combat.player.enabled:
		return
	var font := ThemeDB.fallback_font
	if combat.mode == combat.Mode.QTE:
		var center := size * Vector2(0.5, 0.63)
		draw_circle(center, 60, Color(0.025, 0.035, 0.04, 0.90))
		draw_arc(center, 54, -PI / 2, TAU - PI / 2, 60, Color(0.40, 0.43, 0.44), 3, true)
		draw_arc(center, 54, -PI / 2 + TAU * combat.QTE_OPEN / combat.QTE_SECONDS, -PI / 2 + TAU * combat.QTE_CLOSE / combat.QTE_SECONDS, 36, Color(0.45, 0.85, 0.71), 7, true)
		var angle: float = -PI / 2 + TAU * combat.clock / combat.QTE_SECONDS
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 54, 7, Color(1, 0.95, 0.80))
		draw_string(font, center + Vector2(-36, 0), "SPACE", HORIZONTAL_ALIGNMENT_CENTER, 72, 21, Color.WHITE)
		draw_string(font, center + Vector2(-36, 23), "NÉ", HORIZONTAL_ALIGNMENT_CENTER, 72, 16, Color(0.63, 0.90, 0.80))
	elif combat.feedback_time > 0:
		var color := Color(0.62, 0.96, 0.80) if combat.feedback == "PHẢN CÔNG" else Color(0.98, 0.47, 0.39)
		draw_string(font, size * Vector2(0.5, 0.68) + Vector2(-80, 0), combat.feedback, HORIZONTAL_ALIGNMENT_CENTER, 160, 20, color)
	if combat.adrenaline_remaining > 0:
		var alpha := 0.75 + 0.2 * sin(combat.pulse * 9)
		var point := Vector2(size.x * 0.5, size.y - 100)
		draw_polyline(PackedVector2Array([point + Vector2(-45, 0), point + Vector2(-31, 0), point + Vector2(-25, -9), point + Vector2(-18, 8), point + Vector2(-12, -3), point]), Color(0.95, 0.72, 0.41, alpha), 2, true)
		draw_string(font, point + Vector2(9, 5), "%.0fs" % ceilf(combat.adrenaline_remaining), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.58, alpha))
