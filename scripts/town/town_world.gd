extends Node3D
# Day time: the neighbourhood around Peter's home, ridden between nights at the school.
const Plan := preload("res://scripts/town/town_plan.gd")
const Builder := preload("res://scripts/town/town_builder.gd")
const INTERACT_ON_FOOT := 2.8
const INTERACT_ON_BIKE := 6.0
const DAY_START := 7 * 60
const DAY_END := 22 * 60
# The clock barely moves on its own: a day is spent on what the player chooses to do.
const REAL_SECONDS_PER_MINUTE := 30.0
var plan: RefCounted
var builder: RefCounted
var sky: Node3D
var player: CharacterBody3D
var traffic: Node3D
var hud: Control
var story: Node
var interactions: Array = []
var current: Dictionary = {}
var last_street := -1
var street_audio: AudioStreamPlayer
var ending := false
var minutes := DAY_START
var life: Node
var idle_clock := 0.0
var click_sound: AudioStreamPlayer

func _ready() -> void:
	sky = preload("res://scripts/town/town_sky.gd").new()
	add_child(sky)
	plan = Plan.new()
	builder = Builder.new()
	builder.build(self, plan)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/town/town_hud.gd").new()
	layer.add_child(hud)
	hud.setup(self)
	_spawn_player()
	traffic = preload("res://scripts/town/town_traffic.gd").new()
	add_child(traffic)
	traffic.setup(plan, player, builder.scooter_mesh)
	life = preload("res://scripts/town/town_life.gd").new()
	add_child(life)
	life.setup(self)
	story = preload("res://scripts/town/town_story.gd").new()
	add_child(story)
	story.setup(self)
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = load("res://assets/audio/door_bang.wav")
	click_sound.volume_db = -26
	click_sound.pitch_scale = 3.0
	add_child(click_sound)
	var bridge := preload("res://scripts/arg_bridge.gd").new()
	bridge.name = "ArgBridge"
	bridge.world = self
	add_child(bridge)
	street_audio = AudioStreamPlayer.new()
	var bed: AudioStreamWAV = load("res://assets/audio/town_street.wav").duplicate()
	bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.loop_end = bed.data.size() / 2
	street_audio.stream = bed
	street_audio.volume_db = -14
	add_child(street_audio)
	street_audio.play()
	_opening()

func _spawn_player() -> void:
	var lot: Dictionary = plan.place_lot("home")
	var door: Vector2 = lot.front - lot.normal * 0.5
	player = preload("res://scripts/town/town_player.gd").new()
	player.world = self
	add_child(player)
	player.global_position = Vector3(door.x, 0, door.y)
	# Faces down the alley with the scooter at hand, so the first minute is already riding.
	var tangent := Vector2(-lot.normal.y, lot.normal.x)
	player.look_yaw = atan2(-tangent.x, -tangent.y)
	player.heading = player.look_yaw
	var holder := Node3D.new()
	holder.name = "Scooter"
	add_child(holder)
	var body := MultiMeshInstance3D.new()
	var single := MultiMesh.new()
	single.transform_format = MultiMesh.TRANSFORM_3D
	single.use_colors = true
	single.mesh = builder.scooter_mesh
	single.instance_count = 1
	single.set_instance_transform(0, Transform3D.IDENTITY)
	single.set_instance_color(0, Color(0.46, 0.08, 0.08))
	body.multimesh = single
	holder.add_child(body)
	var spot: Vector2 = door + tangent * 2.0
	holder.global_position = Vector3(spot.x, 0, spot.y)
	holder.rotation.y = player.heading
	player.bike = holder
	var rider: Node3D = preload("res://scripts/town/town_person.gd").new()
	rider.look = "Male_Adult_06"
	rider.motion = "sit"
	rider.position = Vector3(0, 0.46, 0.2)
	rider.rotation.y = PI
	rider.visible = false
	holder.add_child(rider)
	rider.hold_handlebars()
	player.rider = rider

func add_interaction(at: Vector3, label: String, action: Callable) -> void:
	interactions.append({"position": at, "label": label, "action": action})

func interact() -> void:
	if not current.is_empty() and story != null and not story.talking_now():
		player.velocity = Vector3.ZERO
		if player.riding():
			player.speed = 0.0
		current.action.call()

func _opening() -> void:
	hud.banner.text = "Khu phố Bến Trầu · 07:00"
	await get_tree().create_timer(1.8).timeout
	var tween := create_tween()
	tween.tween_property(hud.fade, "modulate:a", 0.0, 1.2)
	tween.parallel().tween_property(hud.banner, "modulate:a", 0.0, 1.0)
	await tween.finished
	hud.banner.text = ""
	hud.banner.modulate.a = 1.0
	hud.hint_once("Tới cổng trường bất cứ lúc nào để bắt đầu đêm.")

# The gate is the only way into the night, whenever the player feels ready.
func enter_night() -> void:
	ending = true
	player.enabled = false
	hud.banner.modulate.a = 0.0
	hud.banner.text = "ĐÊM 1\n22:30"
	var tween := create_tween()
	tween.tween_property(hud.fade, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(hud.banner, "modulate:a", 1.0, 1.0)
	await tween.finished
	await get_tree().create_timer(1.2).timeout
	get_tree().set_meta("night_one", true)
	get_tree().change_scene_to_file("res://scenes/school_runtime.tscn")

func clock_text() -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func phase_for(time: int) -> int:
	return 0 if time < 11 * 60 else (1 if time < 15 * 60 else (2 if time < 18 * 60 else 3))

func spend(amount: int) -> void:
	minutes = mini(minutes + amount, DAY_END)
	sky.apply(phase_for(minutes))
	if minutes >= DAY_END and not ending and not story.talking_now():
		enter_night()

func street_click() -> void:
	click_sound.play()

func hub_state() -> Dictionary:
	return {"evidence": [], "stage": "DAY_FREE"}

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		if event is InputEventMouseButton and event.pressed and not ending and not story.talking_now():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	match event.keycode:
		KEY_M:
			if not ending and not story.talking_now():
				hud.map_open = not hud.map_open
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if story == null or player == null or ending:
		return
	if player.enabled and player.velocity.length() > 0.1:
		idle_clock += delta
		if idle_clock >= REAL_SECONDS_PER_MINUTE:
			idle_clock = 0.0
			spend(1)
	var goal: Dictionary = story.objective()
	hud.goal.text = goal.text
	hud.clock.text = "%s · %s · %d$" % [sky.PHASES[sky.phase].title, clock_text(), story.gear.money]
	hud.targets = [{"position": goal.position, "label": "", "color": Color(1.0, 0.82, 0.24), "distance": true}]
	if not player.riding() and player.global_position.distance_to(player.bike.global_position) > 12.0:
		hud.targets.append({"position": player.bike.global_position, "label": "Xe", "color": Color(0.70, 0.86, 1.0), "low": true})
	_pick_interaction()
	_street_name()

func _pick_interaction() -> void:
	var reach: float = INTERACT_ON_BIKE if player.riding() else INTERACT_ON_FOOT
	var best := reach
	current = {}
	if player.enabled:
		for entry in interactions:
			var distance: float = Vector2(entry.position.x - player.global_position.x, entry.position.z - player.global_position.z).length()
			if distance < best:
				best = distance
				current = entry
	var text := ""
	if not current.is_empty() and not story.talking_now():
		text = "E · %s" % current.label
	elif player.can_mount():
		text = "F · Lên xe"
	hud.prompt.text = text

func _street_name() -> void:
	var near: Dictionary = plan.nearest(Vector2(player.global_position.x, player.global_position.z))
	if near.is_empty() or near.distance > plan.roads[near.road].width * 0.5 + 1.0:
		return
	if near.road != last_street:
		last_street = near.road
		hud.announce_street(plan.roads[near.road].name)
