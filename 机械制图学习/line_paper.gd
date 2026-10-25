extends Control
const Geometry = preload("res://line_geometry.gd")
const Canvas = preload("res://practice_canvas.gd")
const INK = Color("263747")
const ACTIVE = Color("d06d35")
var demo
var zoom := 1.0
var offset := Vector2.ZERO
var label_rects: Array[Rect2] = []
var ink_rects: Array[Rect2] = []
var ink_segments: Array = []
var point_label_rects: Dictionary = {}
var side_guide_segments: Dictionary = {}
var merged_labels: Array = []
var degenerate_lines: Array = []
var fit_bounds := Rect2()
var ratio_marks:Array=[]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)

func fit() -> void:
	if demo.state.is_empty(): return
	# Use the whole lesson's real endpoints so axes do not move when AB moves.
	if not fit_bounds.has_area():
		fit_bounds=Rect2(Vector2(-8,-8),Vector2(16,16))
		for spec in demo.geometry.scenes.values():
			for p in spec.resolved.values():
				for view in ["front","top","left"]:
					var uv: Vector2 = Geometry.project(p,view)
					fit_bounds=fit_bounds.expand(Vector2(uv.x,-uv.y)*Canvas.UNIT)
		fit_bounds=fit_bounds.grow(66)
	var bounds: Rect2 = fit_bounds
	zoom = minf((size.x-34)/bounds.size.x,(size.y-50)/bounds.size.y)
	offset = size*.5-bounds.get_center()*zoom

func at(uv: Vector2) -> Vector2:
	# Reuse the practice millimetre conversion, with a stage-local origin.
	return offset+(Canvas.at([uv.x,uv.y])-Canvas.ORIGIN)*zoom

func point_at(key: String,view: String) -> Vector2:
	return at(Geometry.project(demo.geometry.point(demo.state,key),view))

func text(value: String,p: Vector2,color := INK,fs := 18) -> void:
	var font := get_theme_default_font()
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	label_rects.append(Rect2(p-Vector2(3,fs+3),Vector2(width+6,fs+9)))

func dashed(a: Vector2,b: Vector2,color := INK) -> void:
	var length := a.distance_to(b)
	if length<.1: return
	var dir := a.direction_to(b)
	for i in range(ceili(length/8)):
		var start := float(i)*8
		draw_line(a+dir*start,a+dir*minf(start+5,length),color,1.1,true)

static func segment_hits_rect(rect: Rect2,a: Vector2,b: Vector2) -> bool:
	if rect.has_point(a) or rect.has_point(b): return true
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return true
	return false

func label_position(p: Vector2,value: String,fs: int,balls: Array[Rect2]) -> Vector2:
	var width := get_theme_default_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var best := p+Vector2(8,-9)
	var score := INF
	for radius in [0,12,24,40,60,84]:
		for base in [Vector2(8,-9),Vector2(8,fs+6),Vector2(-width-8,-9),Vector2(-width-8,fs+6),Vector2(-width*.5,-12),Vector2(-width*.5,fs+12)]:
			var delta: Vector2 = base+(base+Vector2(width*.5,-fs*.5)).normalized()*radius
			var baseline: Vector2 = p+delta
			var rect := Rect2(baseline-Vector2(3,fs+3),Vector2(width+6,fs+9))
			var cost: float = delta.length()
			if not Rect2(Vector2.ZERO,size).encloses(rect): cost+=1000000
			for avoid in label_rects:
				if rect.grow(3).intersects(avoid): cost+=100000
			for ball in balls:
				if rect.intersects(ball): cost+=100000
			for segment in ink_segments:
				if segment_hits_rect(rect.grow(3),segment[0],segment[1]): cost+=100000
			if cost<score: score=cost; best=baseline
	point_label_rects[value]=Rect2(best-Vector2(3,fs+3),Vector2(width+6,fs+9))
	return best

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f5f7f9"))
	if not demo or not demo.active or demo.state.is_empty(): return
	fit()
	label_rects.clear(); ink_rects.clear(); ink_segments.clear(); point_label_rects.clear(); side_guide_segments.clear(); merged_labels.clear(); degenerate_lines.clear()
	var origin := at(Vector2.ZERO)
	ink_segments.append([Vector2(0,origin.y),Vector2(size.x,origin.y)])
	ink_segments.append([Vector2(origin.x,0),Vector2(origin.x,size.y)])
	for i in range(-14,15):
		var p := at(Vector2(i*5,0))
		if p.x>=0 and p.x<=size.x: draw_line(Vector2(p.x,0),Vector2(p.x,size.y),Color("e1e7eb"),.65,true)
		p = at(Vector2(0,i*5))
		if p.y>=0 and p.y<=size.y: draw_line(Vector2(0,p.y),Vector2(size.x,p.y),Color("e1e7eb"),.65,true)
	draw_line(Vector2(0,origin.y),Vector2(size.x,origin.y),INK,1.3,true)
	draw_line(Vector2(origin.x,0),Vector2(origin.x,size.y),INK,1.3,true)
	var reach := minf(size.x-origin.x,size.y-origin.y)/zoom/Canvas.UNIT
	draw_line(origin,at(Vector2(reach,-reach)),Color("7c8e9c"),1,true)
	ink_segments.append([origin,at(Vector2(reach,-reach))])
	for item in [["X",Vector2(18,origin.y-12)],["Z",Vector2(origin.x+10,26)],["Y_W",Vector2(size.x-55,origin.y-12)],["Y_H",Vector2(origin.x+10,size.y-18)],["O",origin+Vector2(-22,22)]]:
		var selected: bool = item[0] in demo.beats[demo.current_beat].get("label_focus",[])
		text(item[0],item[1],ACTIVE if selected else INK,roundi(18*demo.emphasis_scale()) if selected else 18)
	var spec: Dictionary = demo.geometry.scenes[demo.state.scene]
	for key in demo.state.lines:
		var ends: Array[Vector3] = demo.geometry.ends(demo.state,key)
		for view in ["front","top","left"]:
			var amount: float = demo.state.lines[key][view]
			if amount<=0: continue
			var a := at(Geometry.project(ends[0],view))
			var b := at(Geometry.project(ends[0].lerp(ends[1],amount),view))
			if a.distance_to(b)<.01:
				degenerate_lines.append(view+":"+key)
				continue
			if key=="guide": dashed(a,b)
			else: draw_line(a,b,INK,1.6,true)
			ink_rects.append(Rect2(a,b-a).abs().grow(4))
			ink_segments.append([a,b])
	if demo.state.scene=="third": draw_side_guides()
	ratio_marks.clear()
	if float(demo.state.ticks)>.5:
		var ends: Array[Vector3] = demo.geometry.ends(demo.state,"AB")
		for view in ["front","top","left"]:
			var a := at(Geometry.project(ends[0],view))
			var b := at(Geometry.project(ends[1],view))
			var cross := Vector2(-(b-a).y,(b-a).x).normalized()*5
			for i in range(1,5):
				if .5+float(i)/8>float(demo.state.ticks): continue
				var p := a.lerp(b,float(i)/5)
				draw_line(p-cross,p+cross,ACTIVE,1.5,true)
				ink_segments.append([p-cross,p+cross])
				ratio_marks.append({"view":view,"fraction":float(i)/5,"at":p})
	var balls: Array[Rect2] = []
	for key in demo.state.points:
		for view in ["front","top","left"]:
			if float(demo.state.points[key][view])>.001 and not (not demo.state.has("morph_target") and demo.state.scene=="third" and view=="left" and float(demo.state.points[key][view])<preload("res://line_transfer.gd").POINT_TIME):
				balls.append(Rect2(point_at(key,view)-Vector2(5,5),Vector2(10,10)))
	for view in ["front","top","left"]:
		var entries: Array = []
		for key in demo.state.points:
			if float(demo.state.points[key][view])<=.001: continue
			if not demo.state.has("morph_target") and demo.state.scene=="third" and view=="left" and float(demo.state.points[key][view])<preload("res://line_transfer.gd").POINT_TIME: continue
			var p := point_at(key,view)
			var label: String = str(key).to_lower()+{"front":"′","top":"","left":"″"}[view]
			var same: Array = entries.filter(func(item):return item.p.distance_to(p)<.01)
			if same.is_empty(): entries.append({"p":p,"labels":[label],"amount":float(demo.state.points[key][view])})
			else: same[0].labels.append(label)
		for entry in entries:
			var value: String = entry.labels[0]
			if entry.labels.size()>1:
				value += "("+", ".join(entry.labels.slice(1))+")"
				merged_labels.append(value)
			var focused: bool = demo.beats[demo.current_beat].focus.any(func(ref):return ref.begins_with(view+":") and not demo.geometry.scenes[demo.state.scene].lines.has(ref.split(":")[1]) and point_at(ref.split(":")[1],view).distance_to(entry.p)<.01)
			var amount: float = 1.0
			if demo.state.has("morph_target"):
				amount=entry.amount
			draw_circle(entry.p,3.5*amount,ACTIVE if focused else INK,true,-1,true)
			if amount<.3: continue
			var selected: bool = entry.labels.any(func(name):return name in demo.beats[demo.current_beat].get("label_focus",[]))
			var fs := roundi(18*demo.emphasis_scale()) if selected else 18
			text(value,label_position(entry.p,value,25 if selected else fs,balls),ACTIVE if selected else INK,fs)

func draw_side_guides() -> void:
	for key in ["A","B"]:
		var amount: float = float(demo.state.side_guides[key])
		if amount<=0: continue
		var path: Array = demo.geometry.side_projection_guides(demo.state,key)
		var portions:Array=preload("res://line_transfer.gd").portions(amount)
		var rendered: Array = []
		for i in range(path.size()):
			if portions[i][1]<=portions[i][0]:continue
			var start := at(path[i][0].lerp(path[i][1],portions[i][0]))
			var end := at(path[i][0].lerp(path[i][1],portions[i][1]))
			dashed(start,end,ACTIVE)
			ink_segments.append([start,end])
			ink_rects.append(Rect2(start,end-start).abs().grow(4))
			rendered.append([start,end])
		side_guide_segments[key]=rendered
		var sweep:Array=preload("res://line_transfer.gd").eraser(amount)
		if not sweep.is_empty():
			var p:=at(path[sweep[0]][0].lerp(path[sweep[0]][1],sweep[1]))
			draw_style_box(preload("res://ui_style.gd").card("f1ece6","8796a0",3,1),Rect2(p-Vector2(10,6),Vector2(20,12)))
