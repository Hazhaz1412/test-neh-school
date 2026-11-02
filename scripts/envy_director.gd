extends Node
# AI A, the director. It always knows where every player is and never tells the demon:
# it may only whisper an area. Keeping the two apart is what makes the demon's search fair.
const FIRST_HINT := 4.0
const SLOW_HINT := 8.0
const FAST_HINT := 4.0
const WIDE_AREA := 18.0
const TIGHT_AREA := 5.0
const PATIENCE := 35.0
const MENACE_LIMIT := 170.0
const MENACE_NEAR := 13.0
const REST_SECONDS := 12.0
var world: Node3D
var demon: CharacterBody3D
var started := false
var hint_clock := FIRST_HINT
var quiet_time := 0.0
var menace := 0.0
var last_hint := {}
var rng := RandomNumberGenerator.new()
var debug_label: Label
var hunting_night := false

func setup(school: Node3D) -> void:
	world = school
	rng.randomize()
	debug_label = Label.new()
	debug_label.position = Vector2(24, 96)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 4)
	debug_label.hide()
	world.get_node("HUD").add_child(debug_label)

func players() -> Array:
	return [world.player]

func _ready_to_hunt() -> bool:
	# Night 1 now ends with Lan; the demon hunts from the next night on.
	return world.envy_enabled and hunting_night and world.spirit_enabled and world.progression.briefing_complete and world.simulation_active()

func start() -> void:
	started = true
	world.smart_spawn_enabled = false
	for enemy in world.enemies:
		enemy.set_dormant(true)
	demon = preload("res://scripts/envy_demon.gd").new()
	demon.world = world
	demon.director = self
	world.add_child(demon)
	demon.global_position = _far_point(world.player.global_position)

func _far_point(from: Vector3) -> Vector3:
	var best := from
	var reach := -1.0
	var map: RID = world.get_world_3d().navigation_map
	for point in world.campus_patrol_route(0):
		var distance: float = point.distance_to(from)
		if distance > reach and absf(point.y) < 1.0:
			reach = distance
			best = point
	return NavigationServer3D.map_get_closest_point(map, best) + Vector3.UP * 0.05

# Envy goes for whoever has the most.
func prey() -> CharacterBody3D:
	var richest: CharacterBody3D = null
	var most := -1
	for player in players():
		var owned: int = player.inventory.filter(func(item): return not item.is_empty()).size()
		if owned > most and player.health > 0:
			most = owned
			richest = player
	return richest

func pressure() -> float:
	return clampf(quiet_time / PATIENCE, 0.0, 1.0)

func make_hint() -> Dictionary:
	var target := prey()
	var owned: int = target.inventory.filter(func(item): return not item.is_empty()).size()
	var radius := lerpf(WIDE_AREA, TIGHT_AREA, pressure()) * (1.15 - owned * 0.05)
	radius = maxf(radius, TIGHT_AREA * 0.75)
	# The true position is somewhere inside, never the centre: B still has to search.
	var drift := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.35, 0.8)
	return {"centre": target.global_position + Vector3(drift.x, 0, drift.y), "radius": radius}

func _physics_process(delta: float) -> void:
	if not started:
		if _ready_to_hunt():
			start()
		return
	debug_label.text = _debug_text()
	# Entering the spirit realm wakes the old ghosts; this night belongs to the demon alone.
	for enemy in world.enemies:
		enemy.set_dormant(true)
	if not world.simulation_active():
		return
	var target := prey()
	if target == null or demon == null:
		return
	var distance: float = demon.global_position.distance_to(target.global_position)
	if demon.is_hunting():
		quiet_time = 0.0
		menace += delta * 9.0
	elif distance < MENACE_NEAR:
		menace += delta * 3.0
	else:
		menace = maxf(0.0, menace - delta * 4.0)
		quiet_time += delta
	# Never called off mid-chase: it only backs away once it has lost sight of its prey.
	if menace >= MENACE_LIMIT and not demon.is_resting() and not demon.is_hunting():
		menace = 45.0
		demon.fall_back(_far_point(target.global_position), REST_SECONDS)
		return
	hint_clock -= delta
	if hint_clock <= 0.0 and not demon.is_hunting() and not demon.is_resting():
		hint_clock = lerpf(SLOW_HINT, FAST_HINT, pressure())
		last_hint = make_hint()
		demon.whisper(last_hint.centre, last_hint.radius)

func caught_someone() -> void:
	menace = 45.0
	quiet_time = 0.0
	hint_clock = SLOW_HINT

# A salt shot blinds it: A goes silent for a while, so the player truly gets away.
func driven_off(seconds: float) -> void:
	menace = 0.0
	quiet_time = 0.0
	hint_clock = seconds
	last_hint = {}

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_F9:
		debug_label.visible = not debug_label.visible
	if event.pressed and not event.echo and event.keycode == KEY_F8:
		hunting_night = true
		world.progression.briefing_complete = true

func _debug_text() -> String:
	if demon == null:
		return ""
	return "A · áp lực %d · lặng %ds · vùng gợi ý %d m\nB · %s · cách người chơi %d m" % [menace, quiet_time, last_hint.get("radius", 0), demon.state_name(), demon.global_position.distance_to(world.player.global_position)]
