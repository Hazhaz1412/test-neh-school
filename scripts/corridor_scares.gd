extends Node
# Paces the fear of the corridor. Beats are tied to distance so every run escalates the same way;
# hazards and wrong turns add their own shocks on top.
const BEATS := [
	[22.0, "whisper"], [64.0, "doors"], [104.0, "scream"], [150.0, "hands"], [198.0, "text", "ĐỪNG NHÌN LẠI"],
	[232.0, "blackout"], [268.0, "lurch"], [312.0, "face"], [328.0, "blackout"], [362.0, "whisper"], [392.0, "doors"],
	[424.0, "hands"], [458.0, "text", "NÓ Ở SAU LƯNG"], [498.0, "scream"], [518.0, "lurch"], [552.0, "face"],
	[588.0, "doors"], [622.0, "blackout"], [660.0, "hands"], [704.0, "text", "TÊN EM ĐÂU RỒI"], [740.0, "lurch"],
	[774.0, "blackout"], [800.0, "face"], [828.0, "scream"], [866.0, "doors"],
]
const SHAKE_DECAY := 2.4
const FACE_SECONDS := 0.16
const FACE_AHEAD := 2.6
const BLACKOUT_SECONDS := 0.9
const LURCH_METRES := 3.0
const SPRITE_POOL := 10
var run: Node3D
var hits: Array[AudioStream] = []
var voices: Array[AudioStreamPlayer] = []
var spatial: Array[AudioStreamPlayer3D] = []
var slap: AudioStream
var shriek: AudioStream
var laugh: AudioStream
var bang: AudioStream
var pop: AudioStream
var next_beat := 0
var shake := 0.0
var dark_left := 0.0
var face_left := 0.0
var flash: ColorRect
var pressure: ColorRect
var shout: Label
var shout_left := 0.0
var prints: Array[Sprite3D] = []
var print_index := 0
var queue: Array = []
var heart_clock := 0.0
var dead_end_seen := {}

func setup(runner: Node3D) -> void:
	run = runner
	for i in range(6):
		hits.append(load("res://assets/audio/corridor/hit_%d.wav" % i))
	slap = load("res://assets/audio/chair_impact.wav")
	shriek = load("res://assets/audio/ghost_shriek.wav")
	laugh = load("res://assets/audio/haunting_laughter.wav")
	bang = load("res://assets/audio/door_bang.wav")
	pop = load("res://assets/audio/lamp_pop.wav")
	for i in range(3):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
		var at := AudioStreamPlayer3D.new()
		at.unit_size = 10.0
		at.max_distance = 60.0
		add_child(at)
		spatial.append(at)
	var layer := CanvasLayer.new()
	layer.layer = 32
	add_child(layer)
	pressure = ColorRect.new()
	pressure.color = Color(0.5, 0.0, 0.0, 0.0)
	pressure.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pressure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pressure)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	shout = Label.new()
	shout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shout.grow_vertical = Control.GROW_DIRECTION_BOTH
	shout.add_theme_font_size_override("font_size", 64)
	shout.add_theme_color_override("font_color", Color(0.95, 0.06, 0.04))
	shout.add_theme_color_override("font_outline_color", Color.BLACK)
	shout.add_theme_constant_override("outline_size", 12)
	layer.add_child(shout)
	var picture: Texture2D = load("res://assets/horror_props/blood_splatter.png")
	for i in range(SPRITE_POOL):
		var mark := Sprite3D.new()
		mark.texture = picture
		mark.pixel_size = 0.0035
		mark.modulate = Color(0.7, 0.04, 0.03)
		mark.hide()
		run.add_child(mark)
		prints.append(mark)

func reset() -> void:
	next_beat = 0
	shake = 0.0
	dark_left = 0.0
	face_left = 0.0
	shout_left = 0.0
	queue.clear()
	dead_end_seen.clear()
	flash.color.a = 0.0
	pressure.color.a = 0.0
	shout.text = ""
	for mark in prints:
		mark.hide()

func _hit(index: int, volume := -6.0) -> void:
	_voice(hits[index], volume)

func _voice(sound: AudioStream, volume: float, pitch := 1.0) -> void:
	for voice in voices:
		if not voice.playing:
			voice.stream = sound
			voice.volume_db = volume
			voice.pitch_scale = pitch
			voice.play()
			return

func _at(sound: AudioStream, where: Vector3, volume: float) -> void:
	for player in spatial:
		if not player.playing:
			player.stream = sound
			player.volume_db = volume
			player.global_position = where
			player.play()
			return

func _flash(color: Color) -> void:
	flash.color = color
	run.story.fear.beat(-8.0)

func impact(where: Vector3, kind: String) -> void:
	shake = maxf(shake, 0.55)
	_at(bang, where, 2.0)
	_hit(1 if kind == "topple" else 0, -9.0)
	run.world.player.startle = maxf(run.world.player.startle, 0.5)

func fire(beat: Array) -> void:
	match beat[1]:
		"whisper":
			_at(laugh, run.world.player.global_position - run.world.player.global_basis.z * -6.0, 0.0)
		"scream":
			_voice(shriek, -5.0)
			_hit(3, -8.0)
			_flash(Color(0.7, 0.02, 0.0, 0.5))
			shake = 0.8
		"doors":
			for i in range(6):
				queue.append({"time": i * 0.22, "kind": "door", "ahead": 6.0 + i * 5.0, "side": 1.0 if i % 2 == 0 else -1.0})
		"hands":
			for i in range(8):
				queue.append({"time": i * 0.13, "kind": "hand", "ahead": 4.0 + i * 2.4, "side": 1.0 if i % 2 == 0 else -1.0})
		"text":
			shout.text = beat[2]
			shout_left = 0.8
			_hit(2, -7.0)
		"blackout":
			dark_left = BLACKOUT_SECONDS
			_voice(pop, -6.0)
			_hit(0, -10.0)
		"lurch":
			run.ghost_distance = minf(run.travel_distance - 2.0, run.ghost_distance + LURCH_METRES)
			_voice(shriek, -9.0, 0.7)
			shake = 0.7
		"face":
			face_left = FACE_SECONDS
			var frame: Transform3D = run.route_frame(run.distance + FACE_AHEAD)
			var ghost: Node3D = run.hazards.ambusher
			ghost.owner_entry = null
			ghost.appear(run.ORIGIN + frame.origin + Vector3.UP * 0.05, run.world.player.global_position)
			_voice(shriek, -3.0, 1.2)
			_hit(5, -4.0)
			_flash(Color(1, 1, 1, 0.55))
			shake = 1.0

func _do_queued(item: Dictionary) -> void:
	var frame: Transform3D = run.route_frame(run.distance + item.ahead)
	var wall: Vector3 = run.ORIGIN + frame.origin + frame.basis.x * item.side * 3.5 + Vector3.UP * 1.5
	if item.kind == "door":
		_at(bang, wall, 0.0)
		shake = maxf(shake, 0.25)
		return
	var mark: Sprite3D = prints[print_index]
	print_index = (print_index + 1) % prints.size()
	mark.global_transform = Transform3D(frame.basis * Basis(Vector3.UP, -item.side * PI * 0.5), wall)
	mark.show()
	_at(slap, wall, -8.0)

func _dead_ends() -> void:
	var feet: Vector3 = run.world.player.position - run.ORIGIN
	for i in range(run.dead_ends.size()):
		var branch: Dictionary = run.dead_ends[i]
		var along: float = (feet - branch.origin).dot(branch.direction)
		var off: float = (feet - branch.origin - branch.direction * along).length()
		if along > 10.0 and off < 4.0 and not dead_end_seen.has(i):
			dead_end_seen[i] = true
			fire([0, "scream"])
			run.ghost_distance = minf(run.travel_distance - 3.0, run.ghost_distance + 1.5)

func tick(delta: float) -> void:
	while next_beat < BEATS.size() and run.distance >= BEATS[next_beat][0]:
		fire(BEATS[next_beat])
		next_beat += 1
	_dead_ends()
	for item in queue.duplicate():
		item.time -= delta
		if item.time <= 0.0:
			queue.erase(item)
			_do_queued(item)
	if face_left > 0.0:
		face_left -= delta
		if face_left <= 0.0:
			run.hazards.ambusher.vanish()
	dark_left = maxf(0.0, dark_left - delta)
	shout_left = maxf(0.0, shout_left - delta)
	if shout_left <= 0.0:
		shout.text = ""
	flash.color.a = maxf(0.0, flash.color.a - delta * 3.0)
	var danger: float = clampf(1.0 - run.ghost_gap / 12.0, 0.0, 1.0)
	pressure.color.a = danger * danger * 0.28 + sin(run.clock * 9.0) * danger * 0.04
	heart_clock -= delta
	if heart_clock <= 0.0 and danger > 0.35:
		heart_clock = lerpf(0.9, 0.42, danger)
		run.story.fear.beat(-14.0)
	shake = maxf(0.0, shake - delta * SHAKE_DECAY)
	var camera: Camera3D = run.world.player.camera
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.05
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.05

func hide_all() -> void:
	reset()
	var camera: Camera3D = run.world.player.camera
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	for voice in voices:
		voice.stop()
	for player in spatial:
		player.stop()
