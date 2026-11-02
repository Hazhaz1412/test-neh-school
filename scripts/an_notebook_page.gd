extends Control

const PEN := {
	"A":"0,1 .4,0 .8,1|.15,.58 .65,.58", "B":"0,1 0,0 .5,0 .75,.18 .6,.45 0,.48|.5,.48 .8,.7 .65,1 0,1",
	"C":".8,.15 .55,0 .18,.08 0,.45 .12,.86 .5,1 .8,.88", "D":"0,1 0,0 .4,0 .75,.25 .8,.65 .55,.95 0,1",
	"E":".75,0 0,0 0,1 .8,1|0,.48 .6,.48", "G":".8,.2 .6,0 .2,.05 0,.4 .1,.85 .5,1 .8,.8 .8,.55 .45,.55",
	"H":"0,0 0,1|.75,0 .75,1|0,.5 .75,.5", "I":".15,0 .65,0|.4,0 .4,1|.1,1 .7,1",
	"K":"0,0 0,1|.75,0 0,.55 .8,1", "L":"0,0 0,1 .75,1", "M":"0,1 0,0 .4,.6 .8,0 .8,1",
	"N":"0,1 0,0 .8,1 .8,0", "O":".4,0 .1,.1 0,.5 .12,.9 .45,1 .75,.8 .8,.4 .65,.08 .4,0",
	"P":"0,1 0,0 .55,0 .8,.2 .65,.45 0,.5", "R":"0,1 0,0 .5,0 .75,.2 .6,.45 0,.5|.35,.5 .8,1",
	"S":".8,.1 .55,0 .15,.1 0,.35 .65,.6 .8,.8 .6,1 .2,1 0,.85", "T":"0,0 .8,0|.4,0 .4,1",
	"U":"0,0 0,.7 .18,1 .6,1 .8,.7 .8,0", "V":"0,0 .4,1 .8,0", "Y":"0,0 .4,.5 .8,0|.4,.5 .4,1"
}

func _pen_word(word: String, at: Vector2, angle: float, height: float, rng: RandomNumberGenerator, ink: Color, scale_by: Vector2) -> void:
	draw_set_transform(at,angle,scale_by)
	var offset := 0.0
	for letter in word.to_upper():
		var base := letter
		for pair in [["Đ","D"],["Ừ","U"],["Ỏ","O"],["Ô","O"],["À","A"],["Ì","I"],["Ả","A"],["Ử","U"],["Ề","E"],["Ó","O"]]: base = base.replace(pair[0],pair[1])
		if not PEN.has(base):
			offset += height*.45
			continue
		var baseline := rng.randf_range(-.08,.08)*height
		for line in PEN[base].split("|"):
			var stroke := PackedVector2Array()
			for coordinate in line.split(" "):
				var xy: PackedStringArray = coordinate.split(",")
				stroke.append(Vector2(offset+float(xy[0])*height*.66+rng.randf_range(-1,1),baseline+float(xy[1])*height+rng.randf_range(-1,1)))
			draw_polyline(stroke,ink,rng.randf_range(.8,1.5),true)
		if letter!=base: draw_line(Vector2(offset+height*.15,baseline-3),Vector2(offset+height*.35,baseline-7),ink,1.1,true)
		offset += height*rng.randf_range(.60,.75)

# A drawn page, rather than a text description of the writing. The legible
# ownership line survives the crossed-out, overlapping handwriting below it.
func _draw() -> void:
	var scale_by := size / Vector2(680,410)
	draw_set_transform(Vector2.ZERO,0,scale_by)
	draw_rect(Rect2(0,0,680,410),Color(0.74,0.68,0.51))
	var font: Font = preload("res://scripts/horror_type.gd").WALL
	var ink := Color(0.10,0.075,0.07)
	var blood := Color(0.30,0.035,0.025,0.7)
	for line in range(35,410,19): draw_line(Vector2(14,line),Vector2(666,line),Color(0.26,0.32,0.33,0.25))
	draw_line(Vector2(52,8),Vector2(52,402),Color(0.46,0.10,0.07,0.4))
	var random := RandomNumberGenerator.new()
	random.seed = 205103
	var phrases := ["đừng bỏ tôi", "tôi không làm gì", "IM ĐI", "đừng nhìn", "An", "ai ở ngoài cửa?", "không phải tôi", "về nhà"]
	for i in range(52):
		var at := Vector2(random.randf_range(60,520),random.randf_range(65,385))
		var angle := random.randf_range(-.38,.38)
		_pen_word(phrases[i%phrases.size()],at,angle,random.randf_range(12,25),random,ink if i%5 else blood,scale_by)
	draw_set_transform(Vector2.ZERO,0,scale_by)
	for i in range(105):
		var from := Vector2(random.randf_range(62,630),random.randf_range(50,395))
		var points := PackedVector2Array([from])
		for j in range(random.randi_range(4,10)):
			points.append(points[-1]+Vector2(random.randf_range(-22,25),random.randf_range(-12,12)))
		draw_polyline(points,ink if i%6 else blood,random.randf_range(.7,2.3),true)
	# Repeated eyes, ink pressed into the paper, and torn edges.
	for eye in [Vector2(350,245),Vector2(425,242)]:
		draw_arc(eye,25,0,TAU,28,ink,1.8,true)
		draw_circle(eye,7,ink)
	# The crying eye, pressed in so hard it stands out from every other mark.
	var sigil := PackedVector2Array()
	for point in preload("res://scripts/seal_trace.gd").STROKE: sigil.append(Vector2(555,270)+point*78)
	draw_polyline(sigil,Color(0.42,0.02,0.015),5,true)
	for i in range(16):
		var y := i*26.0
		draw_colored_polygon(PackedVector2Array([Vector2(680,y),Vector2(668,y+5),Vector2(680,y+13)]),Color(0.18,.13,.1))
	draw_rect(Rect2(55,0,610,43),Color(.74,.68,.51))
	draw_line(Vector2(55,35),Vector2(665,35),Color(.26,.32,.33,.25))
	draw_string(font,Vector2(75,32),"Nguyễn Bình An",HORIZONTAL_ALIGNMENT_LEFT,-1,25,ink)
	draw_set_transform(Vector2.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()
