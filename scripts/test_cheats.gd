extends Node

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
	# Do not treat letters typed in An's TextEdit as a cheat command.
	if world.soul_quest.dialog.visible:
		return
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
	world.soul_quest.close()
	if world.survival.phase == world.survival.Phase.PREPARATION:
		world.survival.begin_midnight()
	enabled = true
	used_this_run = true
	world.player.recover()
	world.death_panel.hide()
	prepare_exploration()
	world.notify("TEST · Bất tử / nhanh ×3 / đủ ký ức · An chờ trên sân thượng")

func prepare_exploration() -> void:
	if not enabled or not world.soul_quest.night_active():
		return
	world.soul_quest.close()
	world.collect_master_key()
	world.progression.bypass_for_test()
	var quest: Node3D = world.soul_quest
	for i in range(quest.memories.size()):
		quest.found[i] = true
		quest.fragments[i].collected = true
		quest.fragments[i].hide()
		quest.fragments[i].get_node("Interaction").collision_layer = 0
	# Keep An's real dialogue available when the cheat chord is enabled.
	quest.accepted.clear()
	world.survival.soul_rescued = false
	quest.soul.released = false
	quest.soul.show()
	quest.soul.get_node("Interaction").collision_layer = 16

func complete_objectives() -> void:
	prepare_exploration()
	if not enabled or not world.soul_quest.night_active():
		return
	# Explicit finish-test bypass; never an AI score or a normal chord side effect.
	for i in range(world.soul_quest.memories.size()):
		world.soul_quest.accepted[i] = true
	world.survival.soul_rescued = true
	world.soul_quest.soul.released = true

func prepare_ai_test() -> void:
	if not enabled or world.survival.finished:
		return
	world.paused_by_user = false
	world.map_panel.hide()
	world.soul_quest.close()
	world.soul_quest.accepted.clear()
	world.survival.soul_rescued = false
	world.soul_quest.soul.released = false
	if world.player.is_hidden():
		world.player.hidden_spot.release()
		world.player.hidden_spot = null
	world.player.get_node("Collision").shape.height = 1.75
	world.player.get_node("Collision").position.y = 0.9
	world.player.camera.position = Vector3(0, 1.62, 0)
	world.player.velocity = Vector3.ZERO
	world.player.global_position = world.soul_quest.SOUL_APPROACH
	world.player.rotation = Vector3.ZERO
	world.player.camera.look_at(world.soul_quest.soul.global_position + Vector3(0, 1.1, 0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.notify("TEST AI · E nói chuyện với An · Cần API key thật")

func finish_night() -> void:
	if not enabled or world.survival.finished:
		return
	world.paused_by_user = false
	complete_objectives()
	world.survival.advance_clock(world.night_duration_seconds)
