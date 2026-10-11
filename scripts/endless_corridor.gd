extends Node3D

const ORIGIN := Vector3(220, 0, 0)
const LAN_AFTER_SECONDS := 75.0
const RUN_SPEED := 10.5
const WALK_SPEED := 6.0
const LANE_WIDTH := 1.8
const ROOM_DISTANCE := 820.0
const LAN_CORNER := 680.0
const PATH := [Vector3(0,0,0), Vector3(0,0,-160), Vector3(160,0,-160), Vector3(160,0,-340), Vector3(-20,0,-340), Vector3(-20,0,-480)]
var story: Node3D
var world: Node3D
var active := false
var elapsed := 0.0
var clock := 0.0
var distance := 0.0
var furthest_distance := 0.0
var lane := 1
var lane_x := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
var slide_remaining := 0.0
var slide_cooldown := 0.0
var speed := 0.0
var stumble_remaining := 0.0
var momentum := 0.0
var ghost_gap := 9.0
var ghost_distance := 3.0
var hit_count := 0
var obstacles: Array[Dictionary] = []
var ghosts: Array[Node3D] = []
var bodies: Array[PhysicsBody3D] = []
var built := false
var looking_back := false
var room_open := false
var entering_room := false
var room_hidden := false
var lan: Node3D
var lan_distance := 0.0
var lan_time := -1.0
var lan_entering := false
var refuge: Node3D
var table: Node3D
var hinge: Node3D
var door_body: StaticBody3D
var door_amount := 0.0
var room_hide_time := 0.0
var music: AudioStreamPlayer
var chase_steps: AudioStreamPlayer3D
var snarls: AudioStreamPlayer3D
var breathing: AudioStreamPlayer
var drag: AudioStreamPlayer3D
var last_snarl := 0.0
var attack_clock := 0.0
var obstacle_cooldown := 0.0
var held_keys := {}
var corridor_lights: Array[OmniLight3D] = []
var previous_flashlight := false
var junctions: Array[Dictionary] = []
var dead_ends: Array[Dictionary] = []
var trail: Array[Dictionary] = []
var travel_distance := 12.0
var previous_feet := Vector3.ZERO
var lan_running := false
var open_table_meshes := {}

func setup(owner_story: Node3D) -> void:
	story = owner_story
	world = story.world
	position = ORIGIN
	name = "EndlessCorridor"
	music = AudioStreamPlayer.new()
	music.stream = story.loop_wav("res://assets/audio/corridor_chase.wav")
	music.volume_db = -15
	add_child(music)
	chase_steps = make_loop("res://assets/audio/ghost_step.wav", -8)
	snarls = AudioStreamPlayer3D.new()
	snarls.stream = load("res://assets/audio/pursuer_snarl.wav")
	snarls.volume_db = -9
	snarls.unit_size = 12
	add_child(snarls)
	breathing = AudioStreamPlayer.new()
	breathing.stream = story.loop_wav("res://assets/audio/player_breath.wav")
	breathing.volume_db = -28
	add_child(breathing)
	drag = AudioStreamPlayer3D.new()
	drag.stream = load("res://assets/audio/chair_scrape.wav")
	drag.unit_size = 10
	drag.volume_db = -7
	add_child(drag)
	reset()

func make_loop(path: String, volume: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = story.loop_wav(path)
	audio.volume_db = volume
	audio.max_distance = 45
	audio.unit_size = 12
	add_child(audio)
	return audio

func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.2
	return mat

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	parent.add_child(part)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		add_shape(body, Vector3.ZERO, dimensions)
		parent.add_child(body)
		bodies.append(body)
	return part

func add_shape(body: PhysicsBody3D, at: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)

func route_frame(meters: float) -> Transform3D:
	var remaining := meters
	for i in range(PATH.size()-1):
		var direction: Vector3 = (PATH[i+1]-PATH[i]).normalized()
		var length: float = PATH[i].distance_to(PATH[i+1])
		if remaining <= length or i == PATH.size()-2:
			return Transform3D(Basis(Vector3.UP, atan2(-direction.x, -direction.z)), PATH[i]+direction*remaining)
		remaining -= length
	return Transform3D.IDENTITY

func route_projection(at: Vector3) -> Vector2:
	var closest := INF
	var result := Vector2.ZERO
	var offset := 0.0
	at -= ORIGIN
	for i in range(PATH.size()-1):
		var axis: Vector3 = (PATH[i+1]-PATH[i]).normalized()
		var length: float = PATH[i].distance_to(PATH[i+1])
		var along := clampf((at-PATH[i]).dot(axis), 0, length)
		var center: Vector3 = PATH[i]+axis*along
		var separation: float = Vector2(at.x-center.x, at.z-center.z).length_squared()
		if separation < closest:
			closest = separation
			var right := axis.cross(Vector3.UP)
			result = Vector2(offset+along, (at-center).dot(right))
		offset += length
	return result

func prop(parent: Node3D, asset: String, at: Vector3, size: Vector3, rotation_y := 0.0) -> Node3D:
	var visual: Node3D = load("res://assets/kenney_furniture/"+asset+".glb").instantiate()
	visual.set_meta("source_asset","res://assets/kenney_furniture/"+asset+".glb")
	parent.add_child(visual)
	if asset=="table":
		for part in visual.find_children("*","MeshInstance3D",true,false): part.mesh = _open_table_mesh(part.mesh)
	var bounds := AABB()
	var started := false
	for part in visual.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (visual.global_transform.affine_inverse()*part.global_transform)*part.get_aabb()
		bounds = bounds.merge(local) if started else local
		started = true
	visual.scale = size/bounds.size
	visual.position = at-Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)*visual.scale
	var pivot := Node3D.new()
	parent.add_child(pivot)
	visual.reparent(pivot, false)
	pivot.rotation.y = rotation_y
	return pivot

func _open_table_mesh(source: ArrayMesh) -> ArrayMesh:
	if open_table_meshes.has(source): return open_table_meshes[source]
	var result := ArrayMesh.new()
	var bounds := source.get_aabb()
	var center := bounds.get_center().x
	# Keep the original CC0 GLB intact. Remove its low horizontal brace in
	# this runtime variant: it otherwise visually closes the sliding gap.
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for index in range(0,indices.size(),3):
			var a := vertices[indices[index]]
			var b := vertices[indices[index+1]]
			var c := vertices[indices[index+2]]
			var below := maxf(a.y,maxf(b.y,c.y))<bounds.position.y+bounds.size.y*.45
			var spans := minf(a.x,minf(b.x,c.x))<center-bounds.size.x*.25 and maxf(a.x,maxf(b.x,c.x))>center+bounds.size.x*.25
			if below and spans: continue
			kept.append_array(PackedInt32Array([indices[index],indices[index+1],indices[index+2]]))
		arrays[Mesh.ARRAY_INDEX] = kept
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,source.surface_get_material(surface))
	open_table_meshes[source] = result
	return result

func build() -> void:
	if built: return
	built = true
	var wall := material(Color(0.38, 0.14, 0.12))
	wall.albedo_texture = load("res://assets/polyhaven_horror/rubble_diff_1k.jpg")
	wall.uv1_triplanar = true
	wall.uv1_scale = Vector3(0.45,0.45,0.45)
	var floor_mat := material(Color(0.26, 0.19, 0.17))
	var lamp_mat := material(Color(0.95, 0.08, 0.025), true)
	var door_mat := material(Color(0.13,0.05,0.035))
	var offset := 0.0
	for i in range(PATH.size()-1):
		var length: float = PATH[i].distance_to(PATH[i+1])
		var segment := Node3D.new()
		add_child(segment)
		segment.transform = route_frame(offset+0.01)
		segment.position = PATH[i]
		box(segment, Vector3(0,-0.12,-length/2), Vector3(7.4,0.2,length+7.4), floor_mat, true)
		box(segment, Vector3(0,3.5,-length/2), Vector3(7.4,0.2,length+7.4), wall)
		var from := 3.7 if i > 0 else -3.7
		var to := length-3.7
		for side in [-1,1]:
			if i == PATH.size()-2 and side == -1:
				to = length-4.1
			box(segment, Vector3(side*3.65,1.7,-(from+to)/2), Vector3(0.2,3.5,to-from), wall, true)
		for z in range(10, int(length)-5, 15):
			box(segment, Vector3(0,3.35,-z), Vector3(1.7,0.05,0.22), lamp_mat)
			for side in [-1,1]: box(segment, Vector3(side*3.52,1.35,-z-4), Vector3(0.08,2.7,1.8), door_mat)
		if i > 0:
			# Each corner is now a real junction: two blocked branches plus the
			# continuing path. Blood prints bend into the continuing corridor.
			var incoming: Vector3 = (PATH[i]-PATH[i-1]).normalized()
			var outgoing: Vector3 = (PATH[i+1]-PATH[i]).normalized()
			junctions.append({"position":PATH[i],"distance":offset,"correct":outgoing})
			for direction in [incoming, -outgoing]:
				_build_dead_end(PATH[i],direction,wall,floor_mat,lamp_mat)
			_build_route_marks(offset)
		offset += length
	for i in range(4):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0,0.14,0.085)
		lamp.light_energy = 3.8
		lamp.omni_range = 22
		add_child(lamp)
		corridor_lights.append(lamp)
	var at := 60.0
	var index := 0
	while at < 770:
		if [160.0,320.0,500.0,680.0].any(func(corner): return absf(at-corner)<18):
			at += 32
			continue
		build_obstacle(at, index)
		index += 1
		at += 32
	for i in range(5):
		var ghost := preload("res://scripts/chase_apparition.gd").new()
		add_child(ghost)
		ghosts.append(ghost)
	lan = preload("res://scripts/humanoid_model.gd").new()
	lan.variant = "Casual_Female"
	lan.target_height = 1.68
	lan.shirt_color = Color(0.38,0.29,0.48)
	add_child(lan)
	_build_room(wall, floor_mat)

func build_obstacle(at: float, index: int) -> void:
	var kind: String = ["lane_right","jump","slide","weave","lane_left","drop_gate","jump","slide"][index%8]
	if kind == "weave":
		_build_hazard(at-5,"lane_right",index,"weave")
		_build_hazard(at+9,"lane_left",index,"weave")
		return
	_build_hazard(at,"slide" if kind=="drop_gate" else kind,index,kind)

func _build_hazard(at: float, kind: String, index: int, challenge: String) -> void:
	var root := AnimatableBody3D.new()
	root.sync_to_physics = false
	root.collision_layer = 1
	root.collision_mask = 0
	root.set_meta("chase_hazard", index)
	add_child(root)
	root.transform = route_frame(at)
	bodies.append(root)
	var movable := kind.begins_with("lane") and index%3 == 0 and challenge!="weave"
	var entry := {"kind":kind,"initial_kind":kind,"challenge":challenge,"distance":at,"passed":false,"visual":root,"moving":movable or challenge=="drop_gate","shifted":false,"shift":0.0,"side":-1.0 if kind=="lane_right" else 1.0,"last_hit":-10.0}
	obstacles.append(entry)
	if kind.begins_with("lane"):
		# A solid, tall cabinet reads as a side detour. Its collision matches
		# the model's width rather than extending into the visible passage.
		prop(root,"bookcaseClosedWide",Vector3.ZERO,Vector3(4.5,2.3,1.0))
		add_shape(root,Vector3(0,1.15,0),Vector3(4.5,2.3,1.0))
		root.position += root.basis.x*entry.side*1.15
	elif kind == "jump":
		for x in [-2.2,0.0,2.2]: prop(root,"bench",Vector3(x,0,0),Vector3(2.15,0.7,0.8))
		add_shape(root,Vector3(0,0.35,0),Vector3(6.55,0.7,0.8))
	else:
		# This asset has four corner legs and NO apron, drawers or front panel.
		# One long table keeps the central passage completely open and visible.
		var table_top := 1.05
		var opening := .94
		prop(root,"table",Vector3.ZERO,Vector3(7.25,table_top,1.25))
		for side in [-1,1]: add_shape(root,Vector3(side*3.43,.47,0),Vector3(.38,.94,1.25))
		for x in [-2.35,0.0,2.35]:
			prop(root,"bookcaseOpen",Vector3(x,table_top,0),Vector3(2.30,2.30,1.1))
		add_shape(root,Vector3(0,(opening+3.35)/2,0),Vector3(7.25,3.35-opening,1.25))
		# A cold lamp beyond the gap contrasts with the red corridor. The
		# visible continuation and scraped floor communicate the low route.
		var chalk := material(Color(.62,.73,.73),true)
		for x in [-2.7,2.7]:
			box(root,Vector3(x,.025,0),Vector3(.055,.02,3.6),chalk)
		var gap_light := OmniLight3D.new()
		gap_light.position = Vector3(0,.48,-1.15)
		gap_light.light_color = Color(.6,.85,.9)
		gap_light.light_energy = .9
		gap_light.omni_range = 5.0
		root.add_child(gap_light)
		entry["gap_light"] = gap_light
		if challenge=="drop_gate": root.position.y = 3.4

func _build_dead_end(at: Vector3, direction: Vector3, wall: Material, floor_mat: Material, lamp_mat: Material) -> void:
	var branch := Node3D.new()
	add_child(branch)
	branch.position = at
	branch.rotation.y = atan2(-direction.x,-direction.z)
	box(branch,Vector3(0,-.12,-14),Vector3(7.4,.2,28),floor_mat,true)
	box(branch,Vector3(0,3.5,-14),Vector3(7.4,.2,28),wall)
	for side in [-1,1]: box(branch,Vector3(side*3.65,1.7,-15.35),Vector3(.2,3.5,23.3),wall,true)
	box(branch,Vector3(0,1.7,-27),Vector3(7.4,3.5,.2),wall,true)
	box(branch,Vector3(0,3.35,-11),Vector3(1.7,.05,.22),lamp_mat)
	# The barricade is visible before the end, and can be approached and
	# turned away from. It never kills or teleports the player remotely.
	var barricade := StaticBody3D.new()
	barricade.position = Vector3(0,0,-23)
	branch.add_child(barricade)
	bodies.append(barricade)
	for x in [-2.4,0.0,2.4]: prop(barricade,"bookcaseClosedWide",Vector3(x,0,0),Vector3(2.4,3.2,1.2))
	add_shape(barricade,Vector3(0,1.6,0),Vector3(7.2,3.2,1.2))
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.6,-17)
	light.light_color = Color(.8,.035,.02)
	light.light_energy = .9
	light.omni_range = 14
	branch.add_child(light)
	dead_ends.append({"node":branch,"origin":at,"direction":direction,"length":23.0})

func _build_route_marks(at: float) -> void:
	var blood := material(Color(.58,.035,.02))
	for step in range(-12,17,2):
		var frame := route_frame(at+step)
		for side in [-1,1]:
			var footprint := box(self,frame.origin+frame.basis.x*side*.22+Vector3(0,.012,0),Vector3(.16,.008,.36),blood)
			footprint.rotation.y = frame.basis.get_euler().y+side*.14
	# A torn cloth catches the light on the open route; blocked branches
	# have intact dusty floors and furniture piled across their far ends.
	var frame := route_frame(at+10)
	var rag := box(self,frame.origin+Vector3.UP*2.8,Vector3(.45,.65,.025),material(Color(.58,.33,.21)))
	rag.rotation.y = frame.basis.get_euler().y

func _trail_frame(meters: float) -> Transform3D:
	if trail.size()<2: return route_frame(meters)
	var low := 0
	var high := trail.size()-1
	while low+1<high:
		var middle := (low+high)/2
		if float(trail[middle].distance)<=meters: low = middle
		else: high = middle
	var from: Vector3 = trail[low].position
	var to: Vector3 = trail[high].position
	var weight := clampf((meters-float(trail[low].distance))/maxf(.001,float(trail[high].distance)-float(trail[low].distance)),0,1)
	var direction := (to-from).normalized()
	return Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),from.lerp(to,weight))

func _build_room(wall: Material, floor_mat: Material) -> void:
	refuge = Node3D.new()
	add_child(refuge)
	refuge.transform = route_frame(ROOM_DISTANCE)
	for item in [[Vector3(-6.8,-0.12,0),Vector3(6.4,0.2,8)],[Vector3(-6.8,3.15,0),Vector3(6.4,0.2,8)],[Vector3(-10,1.5,0),Vector3(0.2,3.2,8)]]:
		box(refuge,item[0],item[1],floor_mat if item[0].y<0 else wall,true)
	for side in [-1,1]:
		box(refuge,Vector3(-6.8,1.5,side*4),Vector3(6.4,3.2,0.2),wall,true)
		box(refuge,Vector3(-3.5,1.5,side*2.7),Vector3(0.2,3.2,2.6),wall,true)
	hinge = Node3D.new()
	hinge.position = Vector3(-3.5,0,-1.4)
	refuge.add_child(hinge)
	box(hinge,Vector3(0,1.4,1.4),Vector3(0.13,2.8,2.8),material(Color(0.24,0.10,0.07)),true)
	door_body = bodies[-1]
	table = preload("res://scripts/story_table.gd").new()
	table.world = world
	table.story = story
	table.kind = 1
	table.position = Vector3(-7.7,0,-1.7)
	refuge.add_child(table)
	table.get_node("Cover/HideSign").hide()
	for body in table.find_children("*","StaticBody3D",true,false): bodies.append(body)
	var light := OmniLight3D.new()
	light.position = Vector3(-6.5,2.6,0)
	light.light_color = Color(1,0.35,0.18)
	light.light_energy = 2.5
	light.omni_range = 8
	refuge.add_child(light)

func in_refuge(at: Vector3) -> bool:
	if refuge == null: return false
	var p: Vector3 = refuge.to_local(at)
	return p.x < -4.0 and p.x > -9.7 and absf(p.z)<3.8 and p.y < 3.2

func start() -> void:
	build()
	reset()
	active = true
	show()
	for body in bodies: body.collision_layer = 1
	table.get_node("Interaction").collision_layer = 0
	world.player.global_position = ORIGIN+route_frame(12).origin+Vector3.UP*0.05
	world.player.rotation = Vector3.ZERO
	world.player.camera.rotation = Vector3.ZERO
	world.player.velocity = Vector3.ZERO
	world.player.stamina = world.player.MAX_STAMINA
	world.player.sprint_exhausted = false
	previous_flashlight = world.player.flashlight.visible
	world.player.flashlight.show()
	world.player.camera.far = 95
	distance = 12
	furthest_distance = 12
	travel_distance = 12
	previous_feet = world.player.position
	for i in range(13): trail.append({"distance":float(i),"position":route_frame(i).origin+Vector3.UP*.05})
	for i in range(ghosts.size()):
		var frame := route_frame(ghost_distance-i*0.95)
		ghosts[i].appear(ORIGIN+frame.origin+frame.basis.x*(i-2)*0.65+Vector3.UP*0.05,world.player.global_position)
	_update_lights()
	music.play()
	chase_steps.play()
	breathing.play()

func reset() -> void:
	active = false
	elapsed = 0
	clock = 0
	distance = 0
	furthest_distance = 0
	lane = 1
	lane_x = 0
	jump_height = 0
	jump_velocity = 0
	slide_remaining = 0
	slide_cooldown = 0
	speed = 0
	momentum = 0
	stumble_remaining = 0
	ghost_gap = 9
	ghost_distance = 3
	hit_count = 0
	looking_back = false
	room_open = false
	entering_room = false
	room_hidden = false
	door_amount = 0
	room_hide_time = 0
	last_snarl = 0
	attack_clock = 0
	obstacle_cooldown = 0
	lan_time = -1
	lan_entering = false
	lan_running = false
	trail.clear()
	travel_distance = 12
	held_keys.clear()
	for ghost in ghosts: ghost.vanish()
	for obstacle in obstacles:
		obstacle.passed = false
		obstacle.kind = obstacle.initial_kind
		obstacle.shifted = false
		obstacle.shift = 0
		obstacle.last_hit = -10
		obstacle.visual.transform = route_frame(obstacle.distance)
		if obstacle.kind.begins_with("lane"): obstacle.visual.position += obstacle.visual.basis.x*obstacle.side*1.15
		if obstacle.challenge=="drop_gate": obstacle.visual.position.y = 3.4
	for body in bodies: body.collision_layer = 0
	if lan != null: lan.hide()
	if hinge != null: hinge.rotation.y = 0
	if table != null: table.get_node("Interaction").collision_layer = 0
	for audio in [music,chase_steps,snarls,breathing,drag]:
		if audio != null: audio.stop()
	hide()

func held(code: int) -> bool:
	return held_keys.get(code,Input.is_physical_key_pressed(code))

func jump() -> bool:
	if not world.player.is_on_floor() or slide_remaining>0 or entering_room: return false
	world.player.velocity.y = 8.6
	return true

func slide() -> bool:
	if momentum<0.35 or speed<7.5 or not world.player.is_on_floor() or slide_remaining>0 or slide_cooldown>0 or entering_room: return false
	slide_remaining = 0.95
	slide_cooldown = 1.15
	world.soundscape.cue("paper",-18)
	return true

func obstacle_hit() -> void:
	if obstacle_cooldown>0: return
	hit_count += 1
	obstacle_cooldown = 0.9
	stumble_remaining = 0.55
	momentum = 0
	world.player.invulnerable_time = 0
	world.player.take_damage(8)
	world.player.startle = 0.85
	world.soundscape.cue("chair_impact",-9)

func restore_pose() -> void:
	var p: CharacterBody3D = world.player
	p.get_node("Collision").shape.height = 1.75
	p.get_node("Collision").position.y = 0.9
	p.camera.position = Vector3(0,1.62,0)
	p.camera.fov = 73
	p.camera.far = 400
	p.camera.rotation = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.velocity = Vector3.ZERO

func _furniture(delta: float) -> void:
	for obstacle in obstacles:
		if distance>float(obstacle.distance)+2: obstacle.passed = true
		if not obstacle.moving or obstacle.passed: continue
		var lead: float = obstacle.distance-distance
		if not obstacle.shifted and lead>0 and lead<22:
			obstacle.shifted = true
			drag.global_position = obstacle.visual.global_position
			drag.play()
		if obstacle.shifted and obstacle.shift<1:
			obstacle.shift = minf(1.0,obstacle.shift+delta*(1.8 if obstacle.challenge=="drop_gate" else 1.3))
			if obstacle.challenge=="drop_gate":
				obstacle.visual.position.y = lerpf(3.4,0,smoothstep(0,1,obstacle.shift))
				continue
			var offset: float = lerpf(obstacle.side*1.15,-obstacle.side*1.15,smoothstep(0.0,1.0,obstacle.shift))
			obstacle.visual.transform = route_frame(obstacle.distance)
			obstacle.visual.position += obstacle.visual.basis.x*offset
			if obstacle.shift>0.5: obstacle.kind = "lane_left" if obstacle.initial_kind=="lane_right" else "lane_right"

func tick(delta: float) -> void:
	if not active or not world.simulation_active(): return
	clock += delta
	slide_cooldown = maxf(0,slide_cooldown-delta)
	slide_remaining = maxf(0,slide_remaining-delta)
	stumble_remaining = maxf(0,stumble_remaining-delta)
	obstacle_cooldown = maxf(0,obstacle_cooldown-delta)
	attack_clock = maxf(0,attack_clock-delta)
	var p: CharacterBody3D = world.player
	if held(KEY_CTRL) and slide_remaining<=0 and slide_cooldown<=0: slide()
	var direction := Vector2(float(held(KEY_D))-float(held(KEY_A)),float(held(KEY_S))-float(held(KEY_W)))
	var moving := direction.length()>0
	if p.stamina<=0.1: p.sprint_exhausted = true
	if p.stamina>30: p.sprint_exhausted = false
	var sprinting: bool = held(KEY_SHIFT) and moving and not p.sprint_exhausted and not entering_room
	p.stamina = clampf(p.stamina+(-9.0 if sprinting else 11.0)*delta,0,p.MAX_STAMINA)
	var wanted := RUN_SPEED if sprinting else WALK_SPEED
	if entering_room: wanted = 4.5
	if slide_remaining>0: wanted = maxf(wanted,10)
	if stumble_remaining>0: wanted *= 0.22
	var vector := p.basis*Vector3(direction.x,0,direction.y).normalized()*wanted
	p.velocity.x = move_toward(p.velocity.x,vector.x,delta*26)
	p.velocity.z = move_toward(p.velocity.z,vector.z,delta*26)
	if not p.is_on_floor(): p.velocity.y -= 22*delta
	elif p.velocity.y<0: p.velocity.y = -0.5
	var capsule: CollisionShape3D = p.get_node("Collision")
	if slide_remaining<=0 and capsule.shape.height<1 and not p.can_fit(p.global_position): slide_remaining = 0.05
	capsule.shape.height = 0.68 if slide_remaining>0 else 1.75
	capsule.position.y = 0.36 if slide_remaining>0 else 0.9
	_furniture(delta)
	p.move_and_slide()
	var step := Vector2(p.position.x-previous_feet.x,p.position.z-previous_feet.z).length()
	if step>.001:
		travel_distance += step
		trail.append({"distance":travel_distance,"position":Vector3(p.position.x-ORIGIN.x,.05,p.position.z-ORIGIN.z)})
	previous_feet = p.position
	speed = Vector2(p.velocity.x,p.velocity.z).length()
	if speed>1: elapsed += delta
	momentum = momentum+delta if speed>=7.5 else 0.0
	var projected := route_projection(p.global_position)
	distance = projected.x
	furthest_distance = maxf(furthest_distance,distance)
	lane_x = projected.y
	lane = clampi(roundi(lane_x/LANE_WIDTH)+1,0,2)
	jump_height = maxf(0,p.position.y-0.05)
	jump_velocity = p.velocity.y
	for i in range(p.get_slide_collision_count()):
		var collision: KinematicCollision3D = p.get_slide_collision(i)
		var body: Object = collision.get_collider()
		if body is Node and body.has_meta("chase_hazard") and collision.get_normal().y < 0.65: obstacle_hit()
	p.camera.position.y = 0.52 if slide_remaining>0 else 1.62+sin(clock*17)*minf(1,speed/10)*0.035
	p.camera.fov = move_toward(p.camera.fov,85 if sprinting else 75,delta*22)
	p.startle = maxf(0,p.startle-delta*1.5)
	if elapsed>=LAN_AFTER_SECONDS and distance>=LAN_CORNER and story.stage==story.Stage.CORRIDOR_RUN:
		story.stage = story.Stage.FOLLOW_LAN
		lan_time = elapsed
		lan_distance = distance+9
		lan.transform = route_frame(lan_distance)
		lan.position += Vector3.UP*.05
		lan.rotate_y(PI)
		lan.show()
		lan.animation.play("sprint")
		lan.animation.speed_scale = 1.7
		world.notify("Lan: Nhanh lên! Theo tôi!")
	_tick_lan(delta)
	_tick_ghosts(delta)
	_update_lights()
	chase_steps.position = _trail_frame(ghost_distance).origin+Vector3.UP*1.2
	chase_steps.pitch_scale = clampf(1.4+(14-ghost_gap)*0.02,.75,1.8)
	chase_steps.volume_db = lerpf(-16,-4,clampf(1-ghost_gap/18,0,1))
	snarls.position = chase_steps.position
	last_snarl -= delta
	if last_snarl<=0 and not room_hidden:
		last_snarl = lerpf(2.2,5.5,clampf(ghost_gap/16,0,1))
		snarls.play()
	breathing.volume_db = lerpf(-28,-13,1-p.stamina/p.MAX_STAMINA)
	music.volume_db = lerpf(-16,-10,clampf(1-ghost_gap/16,0,1))

func _update_lights() -> void:
	for obstacle in obstacles:
		if obstacle.has("gap_light"): obstacle.gap_light.visible = active and absf(obstacle.distance-distance)<24
	for i in range(corridor_lights.size()):
		var frame := route_frame(distance+[-16.0,0.0,16.0,30.0][i])
		corridor_lights[i].position = frame.origin+Vector3.UP*2.8
		corridor_lights[i].light_energy = 3.5+sin(clock*13+i)*0.25

func _tick_ghosts(delta: float) -> void:
	var p: CharacterBody3D = world.player
	if clock>2.5 and not entering_room:
		ghost_distance = minf(travel_distance-0.8,ghost_distance+(9.3 if ghost_gap>15 else 7.4)*delta)
	ghost_gap = travel_distance-ghost_distance
	for i in range(ghosts.size()):
		var frame := _trail_frame(ghost_distance-i*0.95)
		ghosts[i].transform = frame
		ghosts[i].position += frame.basis.x*((i-2)*0.65+sin(clock*3+i)*0.16)+Vector3.UP*0.05
		ghosts[i].look_at(Vector3(p.position.x,0.05,p.position.z))
		ghosts[i].animate(delta,clampf(1-ghost_gap/16,0,1))
	if ghosts[0].global_position.distance_to(p.global_position)<1.7 and not entering_room and attack_clock<=0:
		p.invulnerable_time = 0
		p.take_damage(35)
		p.startle = 1
		attack_clock = 1.0

func _tick_lan(delta: float) -> void:
	if not lan.visible: return
	var p: CharacterBody3D = world.player
	var before := lan.position
	lan_distance = move_toward(lan_distance,minf(ROOM_DISTANCE,maxf(lan_distance,distance+9)),delta*11)
	if not lan_entering:
		lan.transform = route_frame(lan_distance)
		lan.position += Vector3.UP*0.05
		lan.rotate_y(PI)
	if distance>=ROOM_DISTANCE-18 and not room_hidden:
		room_open = true
		door_amount = minf(1,door_amount+delta*2)
		hinge.rotation.y = door_amount*PI/2
		if door_amount>0.8: door_body.collision_layer = 0
	if room_open and lan_distance >= ROOM_DISTANCE-3:
		lan_entering = true
	if lan_entering:
		lan.global_position = lan.global_position.move_toward(refuge.to_global(Vector3(-7,0.05,1.7)),delta*6)
	var movement := lan.position-before
	lan_running = movement.length()>.005
	if lan_running:
		# This rig faces +Z. look_at faces -Z, so compensate after facing the
		# real movement direction (also works while turning into the room).
		lan.look_at(lan.global_position+movement.normalized())
		lan.rotate_y(PI)
	var clip := "sprint" if lan_running else "idle"
	if lan.animation.current_animation!=clip: lan.animation.play(clip)
	if in_refuge(p.global_position):
		entering_room = true
		room_hidden = true
		door_amount = maxf(0,door_amount-delta*3)
		hinge.rotation.y = door_amount*PI/2
		if door_amount==0:
			door_body.collision_layer = 1
			room_hide_time += delta
			story.stage = story.Stage.ROOM_HIDE
			if music.playing:
				music.stop()
				world.soundscape.cue("door",-8)
			if room_hide_time>=2.5:
				active = false
				restore_pose()
				for audio in [chase_steps,snarls,breathing]: audio.stop()
				story.enter_lan_room()

func _process(_delta: float) -> void:
	var paused: bool = not world.simulation_active()
	for audio in [music,chase_steps,snarls,breathing,drag]: audio.stream_paused = paused
	if paused:
		for ghost in ghosts: ghost.model.animation.speed_scale = 0
		if lan != null: lan.animation.speed_scale = 0
	elif lan != null: lan.animation.speed_scale = 1.7 if lan_running else .4

func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey and not event.pressed:
		var released: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		held_keys[released] = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		looking_back = false
		world.player.camera.rotation.y = 0
	if not world.simulation_active(): return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SHIFT,KEY_SPACE,KEY_CTRL]:
			held_keys[code] = event.pressed
			if event.pressed and not event.echo:
				if code==KEY_SPACE: jump()
				if code==KEY_CTRL: slide()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		looking_back = event.pressed
		world.player.camera.rotation.y = PI if looking_back else 0
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
		get_viewport().set_input_as_handled()

func look(relative: Vector2) -> void:
	world.player.rotation.y -= relative.x*world.player.LOOK_SENSITIVITY
	world.player.camera.rotation.x = clampf(world.player.camera.rotation.x-relative.y*world.player.LOOK_SENSITIVITY,-1.35,1.35)

func _exit_tree() -> void:
	for audio in [music,chase_steps,snarls,breathing,drag]:
		if audio!=null:
			audio.stream_paused = false
			audio.stop()
			audio.stream = null
