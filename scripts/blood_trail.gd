extends Node3D

# What the teddy leaves behind: a pool wells up under the toy, then a single drag mark crawls out
# of the room and along the hall to the next door, with a red glow on its head to follow.
const FLOOR := 0.025
const PATH: Array[Vector3] = [Vector3(14.5,FLOOR,4.1),Vector3(14.5,FLOOR,6),Vector3(13.2,FLOOR,7.4),Vector3(-13.2,FLOOR,7.4),Vector3(-14.5,FLOOR,6),Vector3(-14.5,FLOOR,4.4)]
const SPACING := 0.42
const SPREAD_SECONDS := 4.5
const POOL_SECONDS := 0.9
const POOL_SIZE := Vector3(2.4,1,2.0)
var world: Node3D
var stains: MultiMesh
var points: Array[Vector3] = []
var glow: OmniLight3D
var clock := 0.0

func setup(school: Node3D) -> void:
	world = school
	name = "MysteriousBloodTrail"
	var random := RandomNumberGenerator.new()
	random.seed = 240903
	var marks: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(POOL_SIZE),PATH[0])]
	points.append(PATH[0])
	for i in range(PATH.size()-1):
		var along: Vector3 = PATH[i+1]-PATH[i]
		var across := along.normalized().cross(Vector3.UP)
		var steps := maxi(1,int(along.length()/SPACING))
		for step in range(steps):
			var at: Vector3 = PATH[i]+along*(step+random.randf_range(0,0.4))/steps+across*random.randf_range(-0.1,0.1)
			var size := Vector3(random.randf_range(0.55,0.95),1,random.randf_range(0.8,1.5))
			# Mostly dragged along the route, with the odd splash turned across it.
			var turn := atan2(along.x,along.z)+(random.randf_range(-0.35,0.35) if step%5 else random.randf_range(0,TAU))
			marks.append(Transform3D(Basis(Vector3.UP,turn).scaled(size),at))
			points.append(at)
	stains = MultiMesh.new()
	stains.transform_format = MultiMesh.TRANSFORM_3D
	var patch := PlaneMesh.new()
	patch.size = Vector2.ONE
	stains.mesh = patch
	stains.instance_count = marks.size()
	for i in range(marks.size()):
		stains.set_instance_transform(i,marks[i])
	var splatter: Texture2D = preload("res://assets/horror_props/blood_splatter.png")
	var material := StandardMaterial3D.new()
	material.albedo_texture = splatter
	material.albedo_color = Color(0.5,0.02,0.015)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.3
	# A faint glow of its own: the hall is dark and the player may not be holding the torch up.
	material.emission_enabled = true
	material.emission = Color(0.3,0.004,0.002)
	material.emission_energy_multiplier = 0.4
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = stains
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	glow = OmniLight3D.new()
	glow.light_color = Color(0.95,0.1,0.06)
	glow.light_energy = 1.0
	glow.omni_range = 3.4
	add_child(glow)
	hide()

func reveal() -> void:
	clock = 0
	show()
	_spread()

func _spread() -> void:
	var pool := smoothstep(0.0,POOL_SECONDS,clock)
	stains.set_instance_transform(0,Transform3D(Basis.IDENTITY.scaled(POOL_SIZE.lerp(Vector3(0.3,1,0.3),1-pool)),PATH[0]))
	var crawl := clampf((clock-POOL_SECONDS*0.5)/SPREAD_SECONDS,0,1)
	var head := int(crawl*(points.size()-1))
	stains.visible_instance_count = head+1
	glow.position = points[head]+Vector3.UP*0.35

func _process(delta: float) -> void:
	if not visible or not world.simulation_active() or clock > POOL_SECONDS+SPREAD_SECONDS: return
	clock += delta
	_spread()
