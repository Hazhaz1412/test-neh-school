extends Node

# Screen and sound effects of the tunnel run: camera shake, a full-screen flash and a few voices
# for impacts. The drain slide (corridor_chute.gd) and its spiders use the same calls.
const SHAKE_DECAY := 2.4
var run: Node3D
var hits: Array[AudioStream] = []
var voices: Array[AudioStreamPlayer] = []
var spatial: Array[AudioStreamPlayer3D] = []
var shriek: AudioStream
var bang: AudioStream
var shake := 0.0
var flash: ColorRect

func setup(runner: Node3D) -> void:
	run = runner
	for i in range(6):
		hits.append(load("res://assets/audio/corridor/hit_%d.wav" % i))
	shriek = load("res://assets/audio/insect_burst.wav")
	bang = load("res://assets/audio/door_bang.wav")
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
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)

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
	_voice(hits[1 if kind == "topple" else 0], -9.0)
	run.world.player.startle = maxf(run.world.player.startle, 0.5)

func tick(delta: float) -> void:
	flash.color.a = maxf(0.0, flash.color.a - delta * 3.0)
	shake = maxf(0.0, shake - delta * SHAKE_DECAY)
	var camera: Camera3D = run.world.player.camera
	camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.05
	camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.05

func hide_all() -> void:
	shake = 0.0
	flash.color.a = 0.0
	var camera: Camera3D = run.world.player.camera
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	for voice in voices: voice.stop()
	for player in spatial: player.stop()
