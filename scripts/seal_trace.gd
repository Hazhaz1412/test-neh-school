extends Control

# The final escape puzzle: redraw the crying eye from An's notebook on a chalk
# board. The stroke is shown faintly, so the pressure is speed, not memory.
signal completed
signal slipped
const STROKE: Array[Vector2] = [Vector2(-1,0),Vector2(-.55,-.5),Vector2(0,-.68),Vector2(.55,-.5),Vector2(1,0),Vector2(.55,.5),Vector2(0,.68),Vector2(-.55,.5),Vector2(-1,0),Vector2(0,0),Vector2(0,1.25)]
const CENTER := Vector2(640,330)
const RADIUS := 175.0
const NODE_SPACING := 20.0
const REACH := 34.0
const SLIP_DISTANCE := 78.0
const SLIP_ROLLBACK := 6
var world: Node3D
var nodes := PackedVector2Array()
var index := 0
var drawing := false
var pointer := CENTER
var tolerance := REACH
var slips := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(STROKE.size()-1):
		var from: Vector2 = CENTER+STROKE[i]*RADIUS
		var to: Vector2 = CENTER+STROKE[i+1]*RADIUS
		var steps: int = maxi(1,roundi(from.distance_to(to)/NODE_SPACING))
		for step in range(steps): nodes.append(from.lerp(to,float(step)/steps))
	nodes.append(CENTER+STROKE[-1]*RADIUS)
	hide()

func begin(assist: int) -> void:
	index = 0
	slips = 0
	drawing = false
	tolerance = REACH+assist*10
	show()

func _step_to(at: Vector2) -> void:
	pointer = at
	for i in range(index,mini(index+4,nodes.size())):
		if nodes[i].distance_to(at) <= tolerance: index = i+1
	if index >= nodes.size():
		drawing = false
		hide()
		completed.emit()
	elif nodes[index].distance_to(at) > SLIP_DISTANCE:
		drawing = false
		index = maxi(0,index-SLIP_ROLLBACK)
		slips += 1
		slipped.emit()

func _input(event: InputEvent) -> void:
	if not visible or not world.simulation_active(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.position
		# Lifting the chalk is allowed; it must come back down on the line.
		drawing = event.pressed and nodes[mini(index,nodes.size()-1)].distance_to(pointer) <= tolerance*1.6
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var from := pointer
		var moved := from.distance_to(event.position)
		if drawing:
			# A fast flick still has to pass along the stroke point by point.
			for i in range(1,ceili(moved/8.0)+1):
				if drawing: _step_to(from.lerp(event.position,minf(1,i*8.0/moved)))
		pointer = event.position
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(CENTER-Vector2(300,260),Vector2(600,520)),Color(.05,.03,.02,.96))
	draw_rect(Rect2(CENTER-Vector2(286,246),Vector2(572,492)),Color(.045,.085,.07,.97))
	draw_polyline(nodes,Color(.72,.78,.72,.22),9,true)
	if index > 1: draw_polyline(nodes.slice(0,index),Color(.93,.95,.86),5,true)
	draw_circle(nodes[mini(index,nodes.size()-1)],9,Color(.93,.3,.2,.9))
	draw_arc(pointer,12,0,TAU,24,Color(.93,.95,.86,.8 if drawing else .4),2,true)
