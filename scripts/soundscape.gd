extends Node
var world: Node3D
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var pool: Array[AudioStreamPlayer3D] = []
var sounds := {}
var next_voice := 0
func setup(school: Node3D) -> void:
	world = school
	music = AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = preload("res://assets/music/lost.ogg").duplicate()
	stream.loop = true
	music.stream = stream
	music.volume_db = -30
	add_child(music)
	music.play()
	voice = AudioStreamPlayer.new()
	add_child(voice)
	for title in ["footstep", "torch", "door", "lock", "pickup", "paper", "hurt", "memory", "rescue", "camera", "counter_grab", "counter_punch", "counter_kick"]:
		sounds[title] = load("res://assets/audio/%s.wav" % title)
	for i in range(4):
		var sound := AudioStreamPlayer3D.new()
		sound.max_distance = 24
		sound.unit_size = 4
		add_child(sound)
		pool.append(sound)
func cue(title: String, volume := -18.0) -> void:
	voice.stream = sounds[title]
	voice.volume_db = volume
	voice.pitch_scale = 1
	voice.play()
func at(title: String, location: Vector3, volume := -18.0) -> void:
	var sound := pool[next_voice]
	next_voice = (next_voice + 1) % pool.size()
	sound.position = location
	sound.stream = sounds[title]
	sound.volume_db = volume
	sound.pitch_scale = randf_range(0.93, 1.07)
	sound.play()
func _process(delta: float) -> void:
	if world == null:
		return
	var target := -30.0
	if world.survival.phase == world.survival.Phase.NIGHT:
		target = -25 + world.threat * 4
	if world.survival.soul_rescued:
		target = -34
	music.volume_db = move_toward(music.volume_db, target, delta * 3)
	music.stream_paused = world.paused_by_user
	voice.stream_paused = world.paused_by_user
	for sound in pool:
		sound.stream_paused = world.paused_by_user
	world.realm_audio.stream_paused = world.paused_by_user
	world.threat_audio.stream_paused = world.paused_by_user

func _exit_tree() -> void:
	if music != null:
		music.stop()
	if voice != null:
		voice.stop()
	for sound in pool:
		sound.stop()
