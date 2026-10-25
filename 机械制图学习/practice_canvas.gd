extends Control
# The sole coordinate conversion for practice and both presentations.
const INK = Color("263747")
const ACTIVE = Color("d06d35")
const EMPHASIS = Color("ffdfa5")
const UNIT = 10.0
const ORIGIN = Vector2(300,300)
var board
var student_label_rects: Array[Rect2] = []
var student_label_placements: Dictionary = {}
var teacher := false
var primitives: Array = []
var progress := 0.0
var focused_step := 0
var pointer := Vector2(INF,INF)
var concept_focus := false
var last_measure_geometry: Dictionary = {}
var eraser_position := Vector2(INF,INF)

static func at(p: Array) -> Vector2:
	return ORIGIN + Vector2(float(p[0]),-float(p[1]))*UNIT

static func mm(p: Vector2) -> Vector2:
	return Vector2((p.x-ORIGIN.x)/UNIT,(ORIGIN.y-p.y)/UNIT)

func scale_factor() -> float:
	return maxf(board.view.zoom,0.01)

func text_at(text: String, p: Vector2, color := INK, offset := Vector2(8,-9), fs := 18) -> void:
	var z := scale_factor()
	var font: Font = get_theme_default_font()
	# Text is laid out in screen-sized space, retaining a clean native font at every zoom.
	draw_set_transform(p,0,Vector2.ONE/z)
	draw_string(font,offset,text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func segment(a: Vector2,b: Vector2,color: Color,width := 1.3) -> void:
	draw_line(a,b,color,width/scale_factor(),true)

func dot(p: Vector2,name: String,color := INK) -> void:
	draw_circle(p,4.0/scale_factor(),color,true,-1,true)
	var offset := Vector2(8,-9)
	if not teacher and not name.is_empty(): offset=student_name_offset(p,name)
	text_at(name,p,color,offset)

func _draw() -> void:
	if not board: return
	student_label_rects.clear()
	student_label_placements.clear()
	var z := scale_factor()
	var lo: Vector2 = -board.view.pan/z
	var hi: Vector2 = (board.view.size-board.view.pan)/z
	var minmm := mm(Vector2(lo.x,hi.y))
	var maxmm := mm(Vector2(hi.x,lo.y))
	var pitch := 5 if z*UNIT >= 3 else 10
	for x in range(int(floor(minmm.x/pitch))*pitch,int(ceil(maxmm.x/pitch))*pitch+1,pitch):
		segment(at([x,minmm.y]),at([x,maxmm.y]),Color("e1e7eb"),0.65)
	for y in range(int(floor(minmm.y/pitch))*pitch,int(ceil(maxmm.y/pitch))*pitch+1,pitch):
		segment(at([minmm.x,y]),at([maxmm.x,y]),Color("e1e7eb"),0.65)
	draw_axes(lo,hi,maxmm)
	draw_known()
	if teacher:
		draw_teaching()
		return
	draw_students(z)

func draw_axes(lo: Vector2,hi: Vector2,maxmm: Vector2) -> void:
	var z := scale_factor()
	segment(Vector2(lo.x,ORIGIN.y),Vector2(hi.x,ORIGIN.y),INK)
	segment(Vector2(ORIGIN.x,lo.y),Vector2(ORIGIN.x,hi.y),INK)
	var reach: float = maxf(maxmm.x,-mm(Vector2(lo.x,hi.y)).y)
	segment(ORIGIN,at([reach,-reach]),Color("7c8e9c"),1.0)
	text_at("O",ORIGIN,INK,Vector2(-20,22))
	text_at("X",Vector2(lo.x+28/z,ORIGIN.y),INK,Vector2(0,-12))
	text_at("Y_W",Vector2(hi.x-58/z,ORIGIN.y),INK,Vector2(0,-12))
	text_at("Z",Vector2(ORIGIN.x,lo.y+28/z),INK,Vector2(10,0))
	text_at("Y_H",Vector2(ORIGIN.x,hi.y-22/z),INK,Vector2(10,0))
func draw_known() -> void:
	pass

func draw_students(z: float) -> void:
	for line in board.document.lines:
		if line.get("dashed",false): dashed(at(line.a),at(line.b),INK,1.8)
		else: segment(at(line.a),at(line.b),INK,1.8)
	for key in board.document.points:
		dot(at(board.document.points[key]),board.point_label(key))
	for item in board.current_selection():
		if item.kind == "line":
			var line: Dictionary = board.find_line(item.id)
			if not line.is_empty():
				for key in ["a","b"]: draw_circle(at(line[key]),6/z,ACTIVE,false,1.6/z,true)
		elif item.kind == "point" and board.document.points.has(item.id):
			draw_circle(at(board.document.points[item.id]),7/z,ACTIVE,false,1.6/z,true)
	if board.pending != null and board.hover != null:
		segment(at(board.pending),at(board.hover),ACTIVE,1.8)
		dot(at(board.pending),"",ACTIVE)
		dot(at(board.hover),"",ACTIVE)
	last_measure_geometry = {}
	if board.marquee != null:
		var rect: Rect2 = board.marquee
		draw_rect(rect,Color(ACTIVE,0.08))
		draw_rect(rect,ACTIVE,false,1.3/z,true)
	elif board.measuring and not board.naming_dialog.visible:
		if board.cursor != null: draw_measure(board.cursor)

func draw_measure(p: Array) -> void:
	var q := at(p)
	var z := scale_factor()
	var horizontal_foot := Vector2(q.x,ORIGIN.y)
	var vertical_foot := Vector2(ORIGIN.x,q.y)
	var outside_x := Vector2(-1 if p[0] < 0 else 1,0)
	var outside_y := Vector2(0,-1 if p[1] > 0 else 1)
	dashed(q,horizontal_foot)
	dashed(q,vertical_foot)
	var x_label := brace(q+outside_y*18/z,vertical_foot+outside_y*18/z,outside_y)
	var y_label := brace(q+outside_x*18/z,horizontal_foot+outside_x*18/z,outside_x)
	var font := get_theme_default_font()
	var x_width := font.get_string_size(measure_text(p[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var y_width := font.get_string_size(measure_text(p[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	x_label += outside_y*maxf(0,x_width*0.5-2)/z
	y_label += outside_x*maxf(0,y_width*0.5-2)/z
	if is_zero_approx(p[0]): x_label.x += 16/z
	if is_zero_approx(p[1]): y_label.y -= 16/z
	number_at(measure_text(p[0]),x_label)
	number_at(measure_text(p[1]),y_label)
	last_measure_geometry = {"point":p.duplicate(),"horizontal_foot":horizontal_foot,"vertical_foot":vertical_foot,"x_mm":absf(p[0]),"y_mm":absf(p[1]),"x_label":x_label,"y_label":y_label,"coordinate_visible":false}

func measure_text(value:float) -> String:
	return str(int(absf(value)))
func dashed(a: Vector2,b: Vector2,color := ACTIVE,width := 1.1,from_fraction := 0.0,to_fraction := 1.0) -> void:
	var length := a.distance_to(b)
	if length < 0.001: return
	var direction := (b-a)/length
	var dash := 5.0/scale_factor()
	var gap := 3.0/scale_factor()
	for i in range(ceili(length/(dash+gap))):
		var start := i*(dash+gap)
		var lo := maxf(start,length*from_fraction)
		var hi := minf(minf(start+dash,length),length*to_fraction)
		if hi > lo: segment(a+direction*lo,a+direction*hi,color,width)

func brace(a: Vector2,b: Vector2,outwards: Vector2) -> Vector2:
	var v := b-a
	var length := v.length()
	var z := scale_factor()
	if length < 0.001: return a+outwards*12/z
	var w := minf(5.0/z,length*0.2)
	var middle := a+v*0.5+outwards*w*2
	curve(a,a+outwards*w,a+v*0.25+outwards*w,a+v*0.4+outwards*w)
	curve(a+v*0.4+outwards*w,a+v*0.5+outwards*w,middle,middle)
	curve(middle,middle,a+v*0.5+outwards*w,a+v*0.6+outwards*w)
	curve(a+v*0.6+outwards*w,a+v*0.75+outwards*w,b+outwards*w,b)
	return middle+outwards*12/z

func curve(a: Vector2,c1: Vector2,c2: Vector2,b: Vector2) -> void:
	var points := PackedVector2Array()
	for i in range(13):
		var t := float(i)/12
		var u := 1-t
		points.append(a*u*u*u+c1*3*u*u*t+c2*3*u*t*t+b*t*t*t)
	draw_polyline(points,ACTIVE,1.3/scale_factor(),true)

func number_at(value: String,p: Vector2) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	draw_set_transform(p,0,Vector2.ONE/scale_factor())
	draw_rect(Rect2(Vector2(-width/2-4,-12),Vector2(width+8,24)),Color("f5f7f9"))
	draw_string(font,Vector2(-width/2,6),value,HORIZONTAL_ALIGNMENT_LEFT,-1,18,ACTIVE)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func erased_fraction(item: Dictionary) -> float:
	if not item.has("erase_order"): return 0.0
	return clampf((progress-float(item.erase_order))*float(item.erase_count)-float(item.erase_index),0,1)

func draw_teaching() -> void:
	var cursor := Vector2(INF,INF)
	eraser_position = Vector2(INF,INF)
	for item in primitives:
		var amount := clampf(progress-float(item.order),0,1)
		if amount <= 0 or item.kind == "erase": continue
		var focus: bool = int(item.step) == focused_step or focused_step == 8
		var color := INK
		if concept_focus: color = ACTIVE
		if item.kind == "line":
			var a := at(item.a)
			var b := at(item.b)
			var erased := erased_fraction(item)
			if erased >= 1: continue
			if item.get("dashed",false): dashed(a,b,color,1.1,erased,amount)
			else: segment(a.lerp(b,erased),a.lerp(b,amount),color,1.4)
			if erased > 0 and erased < 1: eraser_position = a.lerp(b,erased)
			if amount < 1: cursor = a.lerp(b,amount)
			if item.get("label","") != "" and amount >= 1 and (focus or concept_focus):
				var offset: Array = item.get("offset",[7,-8])
				text_at(item.label,(a+b)*0.5,color,Vector2(offset[0],offset[1]),16)
		elif item.kind == "point":
			dot(at(item.p),item.name,INK)
			if amount < 1: cursor = at(item.p)
	# Local yellow wash focuses a named point, leaving previous constructions legible but quiet.
	if eraser_position.is_finite():
		# Screen-sized eraser sweeps the actual guide; remaining ink is clipped at its position.
		draw_set_transform(eraser_position,-0.3,Vector2.ONE/scale_factor())
		draw_style_box(preload("res://ui_style.gd").card("f1ece6","8796a0",3,1),Rect2(-11,-7,22,14))
		draw_line(Vector2(3,-6),Vector2(3,6),Color("c3b9af"),1,true)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		pointer = mm(eraser_position)
	elif cursor.is_finite():
		draw_circle(cursor,10/scale_factor(),Color(EMPHASIS,0.4),true,-1,true)
		segment(cursor+Vector2(0,-8)/scale_factor(),cursor+Vector2(0,8)/scale_factor(),ACTIVE,1.7)
		segment(cursor+Vector2(-8,0)/scale_factor(),cursor+Vector2(8,0)/scale_factor(),ACTIVE,1.7)
		pointer = mm(cursor)
	else: pointer = Vector2(INF,INF)


func line_hits_rect(rect: Rect2,a: Vector2,b: Vector2) -> bool:
	if rect.has_point(a) or rect.has_point(b): return true
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return true
	return false

func student_name_offset(p: Vector2,value: String) -> Vector2:
	var z := scale_factor()
	var width := get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var viewport_rect := Rect2(-board.view.pan/z,board.view.size/z)
	var lines: Array = []
	for line in board.document.lines: lines.append([at(line.a),at(line.b)])
	lines.append_array(extra_label_lines())
	if board.pending!=null and board.hover!=null: lines.append([at(board.pending),at(board.hover)])
	lines.append([Vector2(viewport_rect.position.x,ORIGIN.y),Vector2(viewport_rect.end.x,ORIGIN.y)])
	lines.append([Vector2(ORIGIN.x,viewport_rect.position.y),Vector2(ORIGIN.x,viewport_rect.end.y)])
	lines.append([ORIGIN,ORIGIN+Vector2(1,1)*maxf(viewport_rect.size.x,viewport_rect.size.y)*2])
	var axis_names: Array[Rect2] = [Rect2(ORIGIN+Vector2(-23,1)/z,Vector2(23,27)/z)]
	axis_names.append_array(extra_label_rects())
	var best := Vector2(8,-9)
	var best_rect := Rect2()
	var score := INF
	for radius in [0,16,32,48,64,80]:
		for base in [Vector2(8,-9),Vector2(8,25),Vector2(-width-8,-9),Vector2(-width-8,25),Vector2(-width*.5,-15),Vector2(-width*.5,31)]:
			var direction: Vector2 = (base+Vector2(width*.5,-8)).normalized()
			var delta: Vector2 = base+direction*radius
			var rect := Rect2(p+(delta-Vector2(3,21))/z,Vector2(width+6,27)/z)
			var cost := float(radius)+delta.length()*.1
			if not viewport_rect.encloses(rect): cost+=1000000
			for axis_name in axis_names:
				if rect.grow(3/z).intersects(axis_name): cost+=100000
			for old in student_label_rects:
				if rect.grow(3/z).intersects(old): cost+=100000
			for line in lines:
				if line_hits_rect(rect.grow(3/z),line[0],line[1]): cost+=100000
			for point in board.document.points.values():
				if rect.grow(6/z).has_point(at(point)): cost+=100000
			if cost<score: score=cost; best=delta; best_rect=rect
	student_label_rects.append(best_rect)
	student_label_placements[value]={"rect":best_rect,"offset":best,"penalty":score}
	return best

func extra_label_lines() -> Array:
	return []

func extra_label_rects() -> Array[Rect2]:
	return []
