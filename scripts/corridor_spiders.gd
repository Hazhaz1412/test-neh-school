extends Node3D
# Spiders crawl up the body and over the face, inside the camera's view. Only hard side-to-side
# shakes of the mouse throw them off, and those same shakes knock the slide off its line.
const POOL := 7
const PLANE := -0.26
const SPAN := 0.16
const CRAWL := 0.14
const FACE := Vector2(0.09, 0.05)
const STROKE := 70.0
const BITE_AFTER := 4.0
const BITE_EVERY := 1.5
const BITE_DAMAGE := 3.0
const THROW := 1.6
const THROWN_SECONDS := 0.4
var run: Node3D
var crawlers: Array[Dictionary] = []
var stroke := 0.0
var bite_clock := 0.0
var scuttle: AudioStreamPlayer
var slap: AudioStream

func setup(runner: Node3D) -> void:
	run = runner
	var camera: Camera3D = run.world.player.camera
	reparent.call_deferred(camera, false)
	scuttle = AudioStreamPlayer.new()
	scuttle.stream = run.story.loop_wav("res://assets/audio/paper.wav")
	scuttle.pitch_scale = 2.6
	scuttle.volume_db = -11
	add_child(scuttle)
	slap = load("res://assets/audio/chair_impact.wav")
	var hide_paint := StandardMaterial3D.new()
	hide_paint.albedo_texture = load("res://assets/opengameart_spider/spider.png")
	# This close the torch would burn them white.
	hide_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(POOL):
		var model: Node3D = load("res://assets/opengameart_spider/spider.glb").instantiate()
		add_child(model)
		for part in model.find_children("*", "MeshInstance3D", true, false):
			part.material_override = hide_paint
		var animation: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var clip: Animation = animation.get_animation("WALK")
		clip.loop_mode = Animation.LOOP_LINEAR
		animation.play("WALK")
		animation.speed_scale = 2.5
		animation.seek(i * 0.11)
		model.hide()
		crawlers.append({"model": model, "state": "off", "at": Vector2.ZERO, "aim": Vector2.ZERO, "drift": Vector2.ZERO, "left": 0.0, "fit": 1.0})
	_fit_models()

# The source model is 17 units across and has no unit of its own.
func _fit_models() -> void:
	for crawler in crawlers:
		var bounds := AABB()
		var first := true
		for part in crawler.model.find_children("*", "MeshInstance3D", true, false):
			var piece: AABB = part.get_aabb()
			bounds = piece if first else bounds.merge(piece)
			first = false
		crawler.fit = SPAN / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))

func crawling() -> bool:
	return crawlers.any(func(c): return c.state == "crawl")

func swarm(count: int) -> void:
	bite_clock = BITE_AFTER
	stroke = 0.0
	for i in range(mini(count, POOL)):
		var crawler: Dictionary = crawlers[i]
		crawler.state = "crawl"
		crawler.at = Vector2(randf_range(-0.2, 0.2), -0.24 - i * 0.035)
		crawler.aim = Vector2(randf_range(-FACE.x, FACE.x), randf_range(-FACE.y, FACE.y))
		crawler.model.show()
	scuttle.play()
	run.fx._voice(run.fx.shriek, -14.0, 1.6)

func clear() -> void:
	for crawler in crawlers:
		crawler.state = "off"
		crawler.model.hide()
	if scuttle != null:
		scuttle.stop()

# Counts strokes that reverse direction; a slow sway never adds up to one.
func shake(sideways: float) -> void:
	if not crawling() or sideways == 0.0:
		return
	if signf(sideways) != signf(stroke) and stroke != 0.0:
		if absf(stroke) >= STROKE:
			_throw_one(signf(stroke))
		stroke = 0.0
	stroke += sideways

func _throw_one(direction: float) -> void:
	for crawler in crawlers:
		if crawler.state == "crawl":
			crawler.state = "thrown"
			crawler.left = THROWN_SECONDS
			crawler.drift = Vector2(direction * THROW, randf_range(-0.4, 0.6))
			run.fx._voice(slap, -16.0, 1.8)
			if not crawling():
				scuttle.stop()
			return

func tick(delta: float) -> void:
	for crawler in crawlers:
		if crawler.state == "crawl":
			crawler.at = crawler.at.move_toward(crawler.aim, CRAWL * delta)
			if crawler.at.distance_to(crawler.aim) < 0.01:
				crawler.aim = Vector2(randf_range(-FACE.x, FACE.x), randf_range(-FACE.y, FACE.y))
			_pose(crawler, crawler.aim - crawler.at)
		elif crawler.state == "thrown":
			crawler.left -= delta
			crawler.at += crawler.drift * delta
			_pose(crawler, crawler.drift)
			if crawler.left <= 0.0:
				crawler.state = "off"
				crawler.model.hide()
	if crawling():
		bite_clock -= delta
		if bite_clock <= 0.0:
			bite_clock = BITE_EVERY
			var p: CharacterBody3D = run.world.player
			p.invulnerable_time = 0.0
			p.take_damage(BITE_DAMAGE)
			run.fx._flash(Color(0.5, 0.02, 0.0, 0.3))

func _pose(crawler: Dictionary, heading: Vector2) -> void:
	var facing := heading.normalized() if heading.length() > 0.001 else Vector2.UP
	var forward := Vector3(facing.x, facing.y, 0)
	var back := Vector3.BACK
	var side := back.cross(forward)
	crawler.model.transform = Transform3D(Basis(side, back, -forward).scaled(Vector3.ONE * crawler.fit), Vector3(crawler.at.x, crawler.at.y, PLANE))
