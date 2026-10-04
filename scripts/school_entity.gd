extends "res://scripts/bully_ghost.gd"

enum Kind { LISTENER, WHISPERER, BLOCKER }
@export var kind: Kind = Kind.LISTENER
var listening_memory := 0.0
var whisper_charge := 0.0
var light_charge := 0.0
var stun_time := 0.0
var stun_recovery := 0.0
var call_clock := 0.0
var whisper_audio: AudioStreamPlayer3D

func _ready() -> void:
	super._ready()
	squad_id = -1
	match kind:
		Kind.LISTENER:
			archetype = "listener"
			patrol_speed = 1.25
			search_speed = 1.85
			damage = 17
			model.scale = Vector3(0.70, 0.92, 0.70)
			model.find_child("WoodenClub", true, false).hide()
			_detail(head_node, "Blindfold", Vector3(0, 4.0, 1.8), Vector3(4.7, 1.0, 0.7), Color(0.09, 0.08, 0.075))
			for side in [-1, 1]:
				_detail(head_node, "ListeningEar", Vector3(side * 2.5, 3.5, 0), Vector3(0.8, 2.4, 1), Color(0.48, 0.44, 0.37))
		Kind.WHISPERER:
			archetype = "whisperer"
			patrol_speed = 0.95
			chase_speed = 2.5
			rush_speed = 3.1
			damage = 8
			detection_range = 14
			model.find_child("WoodenClub", true, false).hide()
			model.scale = Vector3(0.76, 0.86, 0.76)
			for side in [-1, 1]:
				var face := MeshInstance3D.new()
				face.name = "RumourMaskLeft" if side == -1 else "RumourMaskRight"
				face.mesh = head_node.mesh
				face.material_override = head_node.material_override
				face.position = Vector3(side * 3.8, -0.6, -0.4)
				face.scale = Vector3.ONE * 0.7
				face.rotation.z = side * 0.42
				head_node.add_child(face)
			_detail(head_node, "SealedMouth", Vector3(0, 2.6, 1.9), Vector3(3.2, 0.65, 0.35), Color(0.1, 0.025, 0.035))
			whisper_audio = _sound("RumourChorus", "res://assets/audio/whisper_chorus.wav", -13)
			var loop: AudioStreamWAV = whisper_audio.stream.duplicate()
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_end = loop.data.size() / 2
			whisper_audio.stream = loop
		Kind.BLOCKER:
			archetype = "blocker"
			model.scale = Vector3(1.07, 1.02, 1.07)
			patrol_speed = 0.85
			search_speed = 1.6
			chase_speed = 3.2
			rush_speed = 4.4
			rush_duration = 0.8
			damage = 24
			windup = 0.85
			attack_cooldown = 1.8
			attack_range = 2.0
			collision_layer = 6 # A physical obstacle for the player as well.
			var shape: CollisionShape3D = get_child(0)
			shape.shape.height = 2.35
			shape.shape.radius = 0.38
			shape.position.y = 1.2
			_detail(torso_node, "ConfiscatedSchoolbag", Vector3(0, 1.27, -0.23), Vector3(0.55, 0.65, 0.22), Color(0.18, 0.025, 0.03))
			for side in [-1, 1]:
				_detail(torso_node, "BagStrap", Vector3(side * 0.18, 1.32, 0.20), Vector3(0.06, 0.65, 0.035), Color(0.26, 0.035, 0.025))

func has_line_of_sight() -> bool:
	return false if kind == Kind.LISTENER else super.has_line_of_sight()

func can_strike_player() -> bool:
	if not active or crowd_controlled() or world.is_soul_sanctuary(player.global_position):
		return false
	if kind == Kind.LISTENER:
		return not player.is_hidden() and listening_memory > 0 and sees_point(player.global_position + Vector3.UP)
	return super.can_strike_player()

func recently_heard_close() -> bool:
	return kind == Kind.LISTENER and listening_memory > 7.4 and global_position.distance_to(last_known) <= close_chase_range

func holds_position() -> bool:
	return kind == Kind.WHISPERER and can_see and global_position.distance_to(player.global_position) > close_chase_range and global_position.distance_to(player.global_position) < 12

func hear_noise(position_heard: Vector3, radius: float, source: String) -> void:
	if kind != Kind.LISTENER:
		super.hear_noise(position_heard, radius, source)
		return
	if not audible(position_heard, radius * 1.35):
		return
	listening_memory = 8
	if source == "steps" and snarl_clock <= 0:
		snarl.pitch_scale = 0.6
		snarl.play()
		snarl_clock = 3
	if state != State.ATTACK:
		state = State.SEARCH
	last_known = position_heard
	memory = 14
	if state != State.ATTACK and recently_heard_close():
		commit_chase()
	search_index = 0
	path_clock = 0
	if (source == "breath" or source == "cough") and player.is_hidden():
		suspected_spot = player.hidden_spot
		last_known = suspected_spot.approach_position()
		world.survival.warn("Nó nghe thấy hơi thở · giữ SPACE khi nấp", 2.5)
	elif source == "decoy":
		suspected_spot = null

func _physics_process(delta: float) -> void:
	if active and world.simulation_active() and world.spirit_enabled and guard_sanctuary():
		return
	if not world.simulation_active() or not world.spirit_enabled or not active:
		if whisper_audio != null:
			whisper_audio.stream_paused = true
		super._physics_process(delta)
		return
	if crowd_controlled():
		super._physics_process(delta)
		return
	listening_memory = maxf(0, listening_memory - delta)
	# Blind students retain their sound-based identity at range, but a person
	# breathing within arm's reach is contact, even while standing still.
	if kind == Kind.LISTENER and not player.is_hidden() and absf(player.global_position.y - global_position.y) < 1.3 and global_position.distance_to(player.global_position) <= 2.2 and sees_point(player.global_position + Vector3.UP):
		listening_memory = 8
		memory = 14
		last_known = player.global_position
		suspected_spot = null
		if state != State.ATTACK:
			commit_chase()
			if rush_clock <= 0 and global_position.distance_to(player.global_position) > attack_range:
				rush_time = rush_duration
				rush_clock = rush_duration + rush_recovery
	stun_recovery = maxf(0, stun_recovery - delta)
	call_clock = maxf(0, call_clock - delta)
	if kind == Kind.WHISPERER:
		whisper_audio.stream_paused = false
		if stun_recovery <= 0 and lit_by_player():
			light_charge += delta
		else:
			light_charge = maxf(0, light_charge - delta * 2)
		if light_charge >= 0.7:
			stun_time = 2.4
			stun_recovery = 8
			light_charge = 0
			whisper_charge = 0
			whisper_audio.stop()
			world.survival.warn("Tiếng rỉ tai đứt quãng · tranh thủ cắt đường nhìn", 2.4)
		if stun_time > 0:
			stun_time -= delta
			velocity = Vector3(0, velocity.y - 18 * delta, 0)
			_play("idle")
			move_and_slide()
			return
	if kind == Kind.LISTENER and state != State.ATTACK and cooldown <= 0 and global_position.distance_to(player.global_position) < attack_range and can_strike_player():
		start_attack()
	super._physics_process(delta)
	if kind == Kind.WHISPERER and not crowd_controlled():
		var chanting := can_see and global_position.distance_to(player.global_position) < 12 and absf(global_position.y - player.global_position.y) < 1.5
		if chanting:
			if not whisper_audio.playing:
				whisper_audio.play()
			whisper_charge += delta
			world.survival.warn("Kẻ Rỉ Tai đang gọi chúng tới · khuất tường hoặc rọi đèn vào mặt", 0.35)
			if whisper_charge >= 1.0:
				player.fear = minf(100, player.fear + 22 * delta)
				if call_clock <= 0:
					world.emit_noise(player.global_position, 20, "rumour")
					call_clock = 7
		else:
			whisper_charge = 0
			whisper_audio.stop()

func _process(delta: float) -> void:
	super._process(delta)
	if not active or not world.simulation_active() or crowd_controlled():
		return
	if kind == Kind.LISTENER:
		head_node.rotation.z = 0.5 * sin(pose_clock * 1.7)
		model.rotation.x = 0.18
	elif kind == Kind.WHISPERER:
		head_node.rotation.y = 0.4 * sin(pose_clock * 2.1)
	elif kind == Kind.BLOCKER:
		model.rotation.z = 0.04 * sin(pose_clock * 2)

func banish(duration: float) -> void:
	super.banish(duration)
	listening_memory = 0
	whisper_charge = 0
	light_charge = 0
	stun_time = 0
	if whisper_audio != null:
		whisper_audio.stop()

func clear_pursuit() -> void:
	super.clear_pursuit()
	listening_memory = 0
	whisper_charge = 0
	light_charge = 0
	if whisper_audio != null:
		whisper_audio.stop()
