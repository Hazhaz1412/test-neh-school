extends CanvasLayer

# Shared heartbeat, red wash and darkness for the jumpscare and the escape.
var red := 0.0
var darkness := 0.0
var fade := 0.0
var pulse := 0.0
var ring := -1.0
var rect: ColorRect
var material: ShaderMaterial
var marker: Control
var heart: AudioStreamPlayer

func _ready() -> void:
	layer = 20
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = preload("res://assets/materials/fear_vignette.gdshader")
	rect.material = material
	add_child(rect)
	marker = Control.new()
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.draw.connect(_draw_ring)
	add_child(marker)
	heart = AudioStreamPlayer.new()
	heart.stream = load("res://assets/audio/heartbeat_single.wav")
	add_child(heart)
	clear()

func clear() -> void:
	red = 0
	darkness = 0
	fade = 0
	pulse = 0
	ring = -1
	if heart != null: heart.stop()

func beat(volume := -4.0) -> void:
	pulse = 1
	heart.volume_db = volume
	heart.play()

func _process(delta: float) -> void:
	pulse = maxf(0,pulse-delta*3.2)
	rect.visible = red>0.001 or darkness>0.001 or fade>0.001 or pulse>0.001
	material.set_shader_parameter("red",red)
	material.set_shader_parameter("darkness",darkness)
	material.set_shader_parameter("fade",fade)
	material.set_shader_parameter("pulse",pulse)
	marker.visible = ring>=0
	if marker.visible: marker.queue_redraw()

# Closes on the centre dot exactly on the next beat, for players without audio.
func _draw_ring() -> void:
	var center := marker.size*Vector2(.5,.5)
	marker.draw_circle(center,5,Color(.86,.22,.18,.85))
	marker.draw_arc(center,16+ring*92,0,TAU,48,Color(.86,.22,.18,.55+.35*(1-ring)),2.5,true)

func _exit_tree() -> void:
	if heart != null:
		heart.stop()
		heart.stream = null
