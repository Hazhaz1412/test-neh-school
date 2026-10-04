extends Node

enum Mode { IDLE, QTE, COUNTER }
const QTE_SECONDS := 0.9
const QTE_OPEN := 0.18
const QTE_CLOSE := 0.73
const COMBO_WINDOW := 7.0
const COUNTER_SECONDS := 1.15
const ADRENALINE_SECONDS := 8.0
var player: CharacterBody3D
var world: Node3D
var mode := Mode.IDLE
var clock := 0.0
var consecutive_hits := 0
var combo_remaining := 0.0
var adrenaline_remaining := 0.0
var attacker: CharacterBody3D
var punched := false
var kicked := false
var pulse := 0.0
var feedback := ""
var feedback_time := 0.0
var saved_pitch := 0.0
var limbs: Node3D
var heartbeat: AudioStreamPlayer

func _ready() -> void:
	player = get_parent()
	world = player.get_parent()
	process_priority = 20
	limbs = preload("res://scripts/combat_limbs.gd").new()
	limbs.name = "CounterLimbs"
	player.camera.add_child(limbs)
	heartbeat = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = preload("res://assets/audio/threat_heartbeat.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	heartbeat.stream = stream
	heartbeat.volume_db = -10
	heartbeat.pitch_scale = 1.5
	add_child(heartbeat)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var hud := preload("res://scripts/combat_hud.gd").new()
	hud.combat = self
	layer.add_child(hud)

func busy() -> bool:
	return mode != Mode.IDLE

func sprint_multiplier() -> float:
	return 0.5 if adrenaline_remaining > 0 else 1.0

func record_hit(source: CharacterBody3D) -> void:
	if source == null or player.is_hidden() or busy():
		return
	consecutive_hits = mini(2, consecutive_hits + 1)
	combo_remaining = COMBO_WINDOW

func offer_qte(source: CharacterBody3D) -> bool:
	if consecutive_hits < 2 or busy() or player.invulnerable_time > 0 or player.test_invincible() or player.is_hidden() or not world.simulation_active() or not source.can_strike_player():
		return false
	if player.global_position.distance_to(source.global_position) > source.attack_range + 0.65:
		return false
	attacker = source
	mode = Mode.QTE
	clock = 0
	consecutive_hits = 0
	combo_remaining = 0
	saved_pitch = player.camera.rotation.x
	player.cancel_chalk_charge()
	world.map_panel.hide()
	world.soul_quest.close()
	if world.progression != null:
		world.progression.close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.velocity = Vector3.ZERO
	player.invulnerable_time = QTE_SECONDS + 0.12
	_face_attacker()
	# The attacker holds its raised arm. Other enemies continue their simulation.
	attacker.restrain(QTE_SECONDS + 0.2, attacker.global_position)
	return true

func _input(event: InputEvent) -> void:
	if mode != Mode.QTE or not world.simulation_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE):
		respond()
		get_viewport().set_input_as_handled()

func respond() -> bool:
	if mode != Mode.QTE or not world.simulation_active():
		return false
	if clock < QTE_OPEN or clock > QTE_CLOSE:
		_fail_qte()
		return false
	mode = Mode.COUNTER
	clock = 0
	punched = false
	kicked = false
	player.invulnerable_time = COUNTER_SECONDS + 0.35
	var direction := (attacker.global_position - player.global_position).normalized()
	direction.y = 0
	attacker.restrain(COUNTER_SECONDS + 0.2, player.global_position + direction.normalized() * 1.15)
	world.soundscape.cue("counter_grab", -15)
	feedback = "PHẢN CÔNG"
	feedback_time = 0.65
	limbs.show()
	return true

func _fail_qte() -> void:
	var source := attacker
	_release()
	player.invulnerable_time = 0
	if is_instance_valid(source) and source.active:
		source.restrained_remaining = 0
		source.animation.speed_scale = 1
		source.animation.play("idle")
		source.cooldown = source.attack_cooldown
		source.alert(player.global_position)
		player.take_damage(source.damage, source)
	consecutive_hits = 0
	combo_remaining = 0
	feedback = "HỤT"
	feedback_time = 0.75

func _physics_process(delta: float) -> void:
	if world.get("survival") == null:
		return
	if not world.spirit_enabled or player.health <= 0 or world.survival.finished:
		reset()
		return
	heartbeat.stream_paused = not world.simulation_active()
	if not world.simulation_active():
		return
	pulse += delta
	feedback_time = maxf(0, feedback_time - delta)
	combo_remaining = maxf(0, combo_remaining - delta)
	if combo_remaining <= 0:
		consecutive_hits = 0
	adrenaline_remaining = maxf(0, adrenaline_remaining - delta)
	if adrenaline_remaining <= 0:
		heartbeat.stop()
	if not busy():
		return
	if not is_instance_valid(attacker) or not attacker.active or world.is_soul_sanctuary(player.global_position):
		_release()
		return
	clock += delta
	if mode == Mode.QTE:
		if clock >= QTE_SECONDS:
			_fail_qte()
		return
	if clock >= 0.40 and not punched:
		punched = true
		attacker.react_to_punch()
		world.soundscape.cue("counter_punch", -12)
		_impact(attacker.global_position + Vector3.UP * 1.7)
	if clock >= 0.76 and not kicked:
		kicked = true
		var direction := attacker.global_position - player.global_position
		attacker.counter_stun(direction)
		# A local opening to escape, including other archetypes; no through-wall stun.
		for enemy in world.enemies:
			if enemy == attacker or not enemy.active or absf(enemy.global_position.y - player.global_position.y) > 1.5:
				continue
			if enemy.global_position.distance_to(player.global_position) < 4.5 and enemy.sees_point(player.global_position + Vector3.UP):
				enemy.counter_stun(enemy.global_position - player.global_position, 3.0, 4.0)
		world.soundscape.cue("counter_kick", -10)
		_impact(attacker.global_position + Vector3.UP)
		adrenaline_remaining = ADRENALINE_SECONDS
		world.encounters.give_break(ADRENALINE_SECONDS)
		heartbeat.play()
	if clock >= COUNTER_SECONDS:
		_release()

func _process(_delta: float) -> void:
	if mode != Mode.COUNTER or not is_instance_valid(attacker):
		return
	var grip := Vector3(-0.12, -0.10, -0.85)
	if is_instance_valid(attacker.club_hand):
		grip = player.camera.to_local(attacker.club_hand.global_position)
		grip = Vector3(clampf(grip.x, -0.3, 0.25), clampf(grip.y, -0.3, 0.1), clampf(grip.z, -1.15, -0.55))
	var punch := _strike_curve(clock, 0.25, 0.40, 0.61)
	var kick := _strike_curve(clock, 0.60, 0.76, 1.10)
	limbs.pose(grip, punch, kick)
	player.camera.position = Vector3(-0.13 * sin(minf(clock / 0.28, 1) * PI), 1.62 - 0.09 * kick, 0.03 * punch)
	player.camera.rotation.z = -0.055 * punch + 0.045 * kick

func _strike_curve(time: float, start: float, peak: float, end: float) -> float:
	if time < start or time > end:
		return 0
	return smoothstep(start, peak, time) if time < peak else 1 - smoothstep(peak, end, time)

func _face_attacker() -> void:
	var offset := attacker.global_position - player.global_position
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.camera.rotation = Vector3.ZERO
	player.camera.look_at(attacker.global_position + Vector3.UP * 1.65)

func _impact(location: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 0.32
	particles.one_shot = true
	particles.explosiveness = 1
	particles.direction = Vector3.UP
	particles.spread = 100
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.035
	particles.color = Color(0.48, 0.75, 0.78, 0.5)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	world.add_child(particles)
	particles.global_position = location
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

func _release() -> void:
	if is_instance_valid(attacker) and attacker.restrained_remaining > 0:
		attacker.restrained_remaining = 0
		attacker.animation.speed_scale = 1
		attacker.animation.play("idle")
		attacker.cooldown = maxf(attacker.cooldown, 0.5)
	mode = Mode.IDLE
	attacker = null
	limbs.hide()
	player.camera.rotation.x = saved_pitch
	player.camera.rotation.z = 0
	player.camera.position = Vector3(0, 1.62, 0)

func reset() -> void:
	if busy():
		_release()
	consecutive_hits = 0
	combo_remaining = 0
	adrenaline_remaining = 0
	feedback_time = 0
	heartbeat.stop()
