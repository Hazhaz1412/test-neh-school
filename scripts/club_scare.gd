extends Node3D

# Picking up the clubs: silence, a noise behind the player, then a lunge that
# fires only once the player has turned around by themselves. The camera is
# never rotated for them.
enum Beat { IDLE, SILENCE, WAIT_TURN, LUNGE, RECOVERY, AFTERMATH, DONE }
const SILENCE_SECONDS := 1.5
const TURN_DEGREES := 30.0
const REPEAT_SECONDS := 6.0
const LUNGE_SECONDS := 0.34
const FACE_HOLD_SECONDS := 0.12
const LOCK_SECONDS := 2.6
const LATCH_DELAY := 1.4
var story: Node3D
var world: Node3D
var beat := Beat.IDLE
var clock := 0.0
var wait := 0.0
var calls := 0
var threat_point := Vector3.ZERO
var next_heartbeat := 0.0
var ghost: Node3D
var behind: AudioStreamPlayer3D
var whisper: AudioStreamPlayer3D
var shriek: AudioStreamPlayer

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	name = "ClubJumpscare"
	ghost = preload("res://scripts/chase_apparition.gd").new()
	add_child(ghost)
	behind = AudioStreamPlayer3D.new()
	behind.stream = load("res://assets/audio/chair_scrape.wav")
	behind.unit_size = 5
	behind.max_distance = 30
	add_child(behind)
	whisper = AudioStreamPlayer3D.new()
	whisper.stream = load("res://assets/audio/whisper_chorus.wav")
	whisper.unit_size = 5
	whisper.max_distance = 30
	add_child(whisper)
	shriek = AudioStreamPlayer.new()
	shriek.stream = load("res://assets/audio/ghost_shriek.wav")
	shriek.volume_db = -2
	add_child(shriek)

func reset() -> void:
	beat = Beat.IDLE
	clock = 0
	wait = 0
	calls = 0
	for audio in [behind,whisper,shriek]:
		if audio != null: audio.stop()
	if ghost != null: ghost.vanish()

func start() -> void:
	reset()
	beat = Beat.SILENCE

func locks_player() -> bool:
	return beat in [Beat.LUNGE,Beat.RECOVERY]

func _point_behind() -> Vector3:
	var p: CharacterBody3D = world.player
	var back: Vector3 = p.camera.global_basis.z
	back.y = 0
	back = back.normalized()
	var head: Vector3 = p.global_position+Vector3.UP*1.3
	var query := PhysicsRayQueryParameters3D.create(head,head+back*4.0,5)
	query.exclude = [p.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	var reach := 4.0 if hit.is_empty() else maxf(1.5,head.distance_to(hit.position)-0.45)
	return p.global_position+back*reach

func _call() -> void:
	calls += 1
	wait = 0
	threat_point = _point_behind()
	behind.global_position = threat_point+Vector3.UP
	whisper.global_position = behind.global_position
	# The second noise is louder, and the name is whispered along with it.
	behind.volume_db = -14.0 if calls == 1 else -3.0
	behind.pitch_scale = 0.72 if calls == 1 else 0.6
	behind.play()
	if calls > 1:
		whisper.volume_db = -5
		whisper.play()

func facing_threat() -> bool:
	var p: CharacterBody3D = world.player
	var to: Vector3 = threat_point-p.global_position
	to.y = 0
	var forward: Vector3 = -p.camera.global_basis.z
	forward.y = 0
	if forward.length_squared() < 0.01 or rad_to_deg(forward.angle_to(to)) >= TURN_DEGREES: return false
	var query := PhysicsRayQueryParameters3D.create(p.camera.global_position,threat_point+Vector3.UP*1.3,5)
	query.exclude = [p.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _face_root() -> Vector3:
	var camera: Camera3D = world.player.camera
	var goal: Vector3 = camera.global_position-camera.global_basis.z*0.55-Vector3.UP*0.08
	return ghost.global_position+goal-ghost.face.global_position

func tick(delta: float) -> void:
	if beat in [Beat.IDLE,Beat.DONE] or not world.simulation_active(): return
	clock += delta
	match beat:
		Beat.SILENCE:
			if clock >= SILENCE_SECONDS:
				_call()
				clock = 0
				beat = Beat.WAIT_TURN
		Beat.WAIT_TURN:
			wait += delta
			if facing_threat():
				behind.stop()
				whisper.stop()
				ghost.appear(threat_point,world.player.camera.global_position)
				shriek.play()
				world.player.startle = 1
				clock = 0
				beat = Beat.LUNGE
			elif wait >= REPEAT_SECONDS: _call()
		Beat.LUNGE:
			var left := maxf(0.001,LUNGE_SECONDS-clock+delta)
			ghost.global_position = ghost.global_position.lerp(_face_root(),clampf(delta/left,0,1))
			ghost.look_at(Vector3(world.player.global_position.x,ghost.global_position.y,world.player.global_position.z))
			ghost.animate(delta,1)
			if clock >= LUNGE_SECONDS:
				clock = 0
				next_heartbeat = 0
				world.hit_flash = 0.7
				story.fear.red = 1
				beat = Beat.RECOVERY
		Beat.RECOVERY:
			if ghost.visible:
				ghost.global_position = _face_root()
				if clock >= FACE_HOLD_SECONDS: ghost.vanish()
			var progress := clampf(clock/LOCK_SECONDS,0,1)
			next_heartbeat -= delta
			if next_heartbeat <= 0:
				story.fear.beat(lerpf(-2,-13,progress))
				next_heartbeat = lerpf(0.38,1.05,progress)
			# The red drains with the slowing pulse and is gone as control returns.
			story.fear.red = pow(1-progress,1.4)
			world.player.startle = maxf(0,1-progress*1.6)
			if clock >= LOCK_SECONDS:
				clock = 0
				story.fear.clear()
				story.begin_uneasy_music()
				beat = Beat.AFTERMATH
		Beat.AFTERMATH:
			if clock >= LATCH_DELAY:
				beat = Beat.DONE
				story.release_stairs()

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [behind,whisper,shriek]: audio.stream_paused = paused
	if paused and ghost.visible: ghost.model.animation.speed_scale = 0

func _exit_tree() -> void:
	for audio in [behind,whisper,shriek]:
		if audio != null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
