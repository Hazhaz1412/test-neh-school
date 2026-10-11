extends Node

# The building suffocates the player. There is no chasing actor in the school;
# progress toward the gate eases this pressure, while lingering has real cost.
var story: Node3D
var world: Node3D
var active := false
var elapsed := 0.0
var pressure := 0.0
var best_gate_distance := 0.0
var last_feet := Vector3.ZERO
var impact_clock := 2.0
var damage_clock := 0.0
var pulse_clock := 0.0
var flashes := 0
var damage_events := 0
var overlay: ColorRect
var material: ShaderMaterial
var breathing: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var crack: AudioStreamPlayer3D
var flash: OmniLight3D

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	name = "SchoolSuffocation"
	breathing = AudioStreamPlayer.new()
	breathing.stream = story.loop_wav("res://assets/audio/player_breath.wav")
	add_child(breathing)
	heartbeat = AudioStreamPlayer.new()
	heartbeat.stream = story.loop_wav("res://assets/audio/threat_heartbeat.wav")
	add_child(heartbeat)
	crack = AudioStreamPlayer3D.new()
	crack.stream = load("res://assets/audio/lamp_pop.wav")
	crack.unit_size = 12
	add_child(crack)
	flash = OmniLight3D.new()
	flash.light_color = Color(.78,.83,1)
	flash.omni_range = 14
	flash.shadow_enabled = true
	add_child(flash)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/materials/escape_pressure.gdshader")
	overlay.material = material
	layer.add_child(overlay)
	reset()

func gate_distance(at: Vector3) -> float:
	return at.distance_to(Vector3(0,.05,77.72))

func start() -> void:
	reset()
	active = true
	last_feet = world.player.global_position
	best_gate_distance = gate_distance(last_feet)
	overlay.show()
	breathing.play()
	heartbeat.play()

func reset() -> void:
	active = false
	elapsed = 0
	pressure = 0
	impact_clock = 2
	damage_clock = 0
	pulse_clock = 0
	flashes = 0
	damage_events = 0
	for audio in [breathing,heartbeat,crack]:
		if audio!=null: audio.stop()
	if flash!=null: flash.light_energy = 0
	if overlay!=null: overlay.hide()

func tick(delta: float) -> void:
	if not active or not world.simulation_active(): return
	elapsed += delta
	pulse_clock += delta
	var p: CharacterBody3D = world.player
	var current := gate_distance(p.global_position)
	var improvement := maxf(0,best_gate_distance-current)
	var moving: bool = p.global_position.distance_to(last_feet)>delta*.6
	if improvement>0:
		pressure = maxf(0,pressure-improvement*.65)
		best_gate_distance = current
	else:
		pressure += delta*(.32 if moving else .9)
	# Walking in circles cannot postpone the collapse indefinitely. The
	# direct escape is comfortably shorter than this global grace period.
	pressure = clampf(maxf(pressure,maxf(0,elapsed-55)*.22),0,18)
	last_feet = p.global_position
	var intensity := clampf(pressure/12,0,1)
	material.set_shader_parameter("pressure",maxf(.10,intensity))
	material.set_shader_parameter("clock",pulse_clock)
	breathing.volume_db = lerpf(-29,-8,intensity)
	heartbeat.volume_db = lerpf(-32,-10,intensity)
	heartbeat.pitch_scale = lerpf(1.0,1.65,intensity)
	story.laugh.volume_db = lerpf(-13,-5,intensity)
	story.laughter_echo.volume_db = lerpf(-12,-4,intensity)
	p.startle = maxf(p.startle,intensity*.45)
	flash.light_energy = maxf(0,flash.light_energy-delta*35)
	impact_clock -= delta
	if impact_clock<=0:
		impact_clock = lerpf(4.5,1.7,intensity)
		var behind: Vector3 = p.global_position+p.global_basis.z*4+Vector3.UP*1.8
		world.soundscape.at("chair_impact",behind,lerpf(-14,-5,intensity))
		crack.global_position = behind
		crack.volume_db = -16+intensity*9
		crack.play()
		flash.global_position = p.global_position+Vector3.UP*2.4
		flash.light_energy = 3.2
		flashes += 1
		for door in world.get_tree().get_nodes_in_group("classroom_doors"):
			var separation: float = door.global_position.distance_to(p.global_position)
			if separation>5 and separation<15 and door.is_open: door.set_open(false)
	damage_clock = maxf(0,damage_clock-delta)
	# Ten seconds of sound/visual warning precede the first suffocation hit.
	if elapsed>=10 and pressure>=8 and damage_clock<=0:
		p.invulnerable_time = 0
		p.take_damage(lerpf(8,20,clampf((pressure-8)/8,0,1)))
		damage_events += 1
		damage_clock = 1.5
	elif pressure<8: damage_clock = 0

func _process(_delta: float) -> void:
	if world==null: return
	for audio in [breathing,heartbeat,crack]: audio.stream_paused = not world.simulation_active()

func _exit_tree() -> void:
	for audio in [breathing,heartbeat,crack]:
		if audio!=null:
			audio.stop()
			audio.stream = null
