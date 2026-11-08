extends Control
# Viewfinder drawn while the player aims the camera (right click toggles it).
# Indicators sit below the clock and above the battery gauge of compact_hud
# so the two layers never overlap.

const MARGIN := 24.0
const LINE := 3.0
const INK := Color(1, 1, 1, 0.9)
const BATTERY_GREEN := Color(0.55, 0.78, 0.22)

var world: Node3D
var refresh := 0.0

func _process(delta: float) -> void:
	var p: CharacterBody3D = world.player
	var showing: bool = p.camera_aiming and p.held_visual.camera_raised() and p.selected_item() == "camera" and not p.is_hidden() and not world.survival.opening.playing and not world.survival.finished
	if showing != visible:
		visible = showing
	if not visible:
		return
	refresh -= delta
	if refresh <= 0:
		refresh = 0.25
		queue_redraw()

func _draw() -> void:
	var view := get_viewport_rect().size
	_draw_corners(Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2), Vector2(view.x * 0.155, view.y * 0.25))
	var focus := Rect2(view * Vector2(0.31, 0.32), view * Vector2(0.38, 0.345))
	_draw_corners(focus, Vector2(view.x * 0.06, view.y * 0.1))
	var center := view / 2
	draw_line(center - Vector2(11, 0), center + Vector2(11, 0), INK, LINE)
	draw_line(center - Vector2(0, 11), center + Vector2(0, 11), INK, LINE)
	_draw_indicators(Vector2(view.x - MARGIN - 32, 96))
	_draw_menu(Vector2(view.x - MARGIN - 32, view.y - 80))

func _draw_corners(rect: Rect2, arm: Vector2) -> void:
	var a := rect.position
	var b := rect.end
	for corner in [a, Vector2(b.x, a.y), Vector2(a.x, b.y), b]:
		var dir := Vector2(1 if corner.x == a.x else -1, 1 if corner.y == a.y else -1)
		draw_polyline(PackedVector2Array([corner + Vector2(arm.x * dir.x, 0), corner, corner + Vector2(0, arm.y * dir.y)]), INK, LINE)

# Right-aligned row: [HD] [4K] 25FPS  battery 99%
func _draw_indicators(right_top: Vector2) -> void:
	var font := get_theme_default_font()
	var percent: int = roundi(world.player.battery)
	var percent_text := "%d%%" % percent
	var x := right_top.x - font.get_string_size(percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(x, right_top.y + 15), percent_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	x -= 52
	var body := Rect2(Vector2(x, right_top.y + 2), Vector2(42, 16))
	draw_rect(Rect2(body.position + Vector2(-4, 5), Vector2(4, 6)), INK)
	draw_rect(body, INK, false, 1.5)
	var fill := Rect2(body.position + Vector2(3, 3), Vector2((body.size.x - 6) * percent / 100.0, body.size.y - 6))
	draw_rect(fill, BATTERY_GREEN)
	x -= 66
	draw_string(font, Vector2(x, right_top.y + 16), "25FPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	x -= 42
	draw_rect(Rect2(Vector2(x, right_top.y), Vector2(34, 20)), INK, false, 1.5)
	draw_string(font, Vector2(x + 7, right_top.y + 16), "4K", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	x -= 42
	draw_rect(Rect2(Vector2(x, right_top.y), Vector2(34, 20)), INK)
	draw_string(font, Vector2(x + 6, right_top.y + 16), "HD", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)

func _draw_menu(right_bottom: Vector2) -> void:
	var font := get_theme_default_font()
	var icon_x := right_bottom.x - 16
	for i in range(3):
		var y := right_bottom.y - 12 + i * 5
		draw_line(Vector2(icon_x + (0 if i == 1 else 4), y), Vector2(icon_x + 16, y), INK, 1.5)
		if i != 1:
			draw_line(Vector2(icon_x - 1, y), Vector2(icon_x + 2, y), INK, 1.5)
	var text_width := font.get_string_size("MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(icon_x - 6 - text_width, right_bottom.y), "MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
