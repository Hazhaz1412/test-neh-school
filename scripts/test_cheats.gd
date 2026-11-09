extends Node
# H + P together: a test chord. Invulnerable, three times as fast, and the night can be finished
# from the pause menu. A run that used it says so on the end screen.
var world: Node3D
var enabled := false
var used_this_run := false
var h_down := false
var p_down := false
var latched := false
const SPEED_MULTIPLIER := 3.0

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_H:
		h_down = event.pressed
	elif code == KEY_P:
		p_down = event.pressed
	else:
		return
	if not h_down or not p_down:
		latched = false
		return
	if latched:
		return
	latched = true
	toggle()
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		h_down = false
		p_down = false
		latched = false

func reset_run() -> void:
	enabled = false
	used_this_run = false

func toggle() -> void:
	if enabled:
		enabled = false
		world.notify("TEST tắt · R bắt đầu lượt sạch")
		return
	# Activate only after a possible fresh-run reset, which clears cheats.
	if not world.survival.active or world.survival.finished or world.player.health <= 0:
		world.survival.start_run(false)
	if world.survival.opening.playing:
		world.survival.opening.finish()
	world.paused_by_user = false
	world.map_panel.hide()
	world.journal.close()
	world.progression.close()
	enabled = true
	used_this_run = true
	world.progression.bypass_for_test()
	for i in range(world.journal.entries.size()):
		world.journal.record(i)
	if world.survival.phase == world.survival.Phase.PREPARATION:
		world.survival.begin_midnight()
	world.collect_master_key()
	world.player.recover()
	world.death_panel.hide()
	world.notify("TEST · Bất tử / nhanh ×3")

func finish_night() -> void:
	if not enabled or world.survival.finished:
		return
	world.paused_by_user = false
	world.survival.advance_clock(world.night_duration_seconds * 1.25)
