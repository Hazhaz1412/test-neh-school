extends Node3D

# After the notebook: one blow on the door, then a growing beating, sobbing that
# comes closer down the hall, and the whole school's power failing.
const FIRST_BANG := 1.4
const SECOND_BANG := 3.2
const FLICKER_AT := 7.2
const BURST_AT := 9.0
const SOB_START := Vector3(-23.5,8.6,55.5)
const SOB_END := Vector3(-23.9,8.6,49.2)
var story: Node3D
var world: Node3D
var door: Node3D
var active := false
var burst := false
var clock := 0.0
var bangs := 0
var next_bang := 0.0
var flicker_clock := 0.0
var rattle := 0.0
var bang: AudioStreamPlayer3D
var sob: AudioStreamPlayer3D
var crash: AudioStreamPlayer
var flash: OmniLight3D

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	name = "DoorSiege"
	door = world.get_node("Architecture/ClassroomDoor306")
	bang = AudioStreamPlayer3D.new()
	bang.stream = load("res://assets/audio/door_bang.wav")
	bang.unit_size = 14
	bang.max_distance = 45
	add_child(bang)
	sob = AudioStreamPlayer3D.new()
	var cry: AudioStream = load("res://assets/audio/an_cry.ogg").duplicate()
	cry.loop = true
	sob.stream = cry
	sob.unit_size = 7
	sob.max_distance = 30
	add_child(sob)
	crash = AudioStreamPlayer.new()
	crash.stream = load("res://assets/audio/ghost_shriek.wav")
	crash.volume_db = -3
	add_child(crash)
	flash = OmniLight3D.new()
	flash.light_color = Color(.78,.83,1)
	flash.omni_range = 16
	flash.light_energy = 0
	add_child(flash)

func reset() -> void:
	active = false
	burst = false
	clock = 0
	bangs = 0
	next_bang = FIRST_BANG
	flicker_clock = 0
	rattle = 0
	for audio in [bang,sob,crash]:
		if audio != null: audio.stop()
	if flash != null: flash.light_energy = 0
	door.leaf.position.z = 0
	door.slide_duration = 0.45

func start() -> void:
	reset()
	active = true

func _strike() -> void:
	bangs += 1
	bang.global_position = door.global_position+Vector3.UP*1.4
	bang.pitch_scale = randf_range(.92,1.05)
	bang.play()
	rattle = 1
	world.player.startle = maxf(world.player.startle,.55)
	if bangs == 1:
		next_bang = SECOND_BANG
		return
	if bangs == 2: sob.play()
	next_bang = clock+lerpf(1.05,.26,clampf((clock-SECOND_BANG)/(FLICKER_AT-SECOND_BANG),0,1))

func _flicker(delta: float) -> void:
	flicker_clock -= delta
	flash.global_position = world.player.global_position+Vector3.UP*2.4
	flash.light_energy = maxf(0,flash.light_energy-delta*30)
	if flicker_clock > 0: return
	flicker_clock = randf_range(.07,.2)
	story.blackout = not story.blackout
	story.power_surge = not story.blackout
	world._update_light_budget()
	if story.power_surge: flash.light_energy = 2.6

func _burst() -> void:
	burst = true
	active = false
	sob.stop()
	flash.light_energy = 0
	story.blackout = true
	story.power_surge = false
	world._update_light_budget()
	door.leaf.position.z = 0
	door.slide_duration = 0.07
	door.set_open(true)
	world.player.startle = 1
	world.hit_flash = .5
	crash.play()
	story.begin_escape()

func tick(delta: float) -> void:
	if not active or not world.simulation_active(): return
	clock += delta
	if clock >= next_bang: _strike()
	rattle = maxf(0,rattle-delta*7)
	door.leaf.position.z = sin(clock*60)*rattle*.035
	var near := clampf((clock-SECOND_BANG)/(BURST_AT-SECOND_BANG),0,1)
	sob.global_position = SOB_START.lerp(SOB_END,near)
	sob.volume_db = lerpf(-20,-2,near)
	if clock >= FLICKER_AT: _flicker(delta)
	if clock >= BURST_AT: _burst()

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [bang,sob,crash]: audio.stream_paused = paused
	if not active and burst and door.slide >= 1: door.slide_duration = 0.45

func _exit_tree() -> void:
	for audio in [bang,sob,crash]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
