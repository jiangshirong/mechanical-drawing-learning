extends "res://practice_canvas.gd"
var known_rects: Array[Rect2] = []
var known_segments: Array = []
var known_progress := 1.0
var tick_points: Array = []
var tick_direction := Vector2.ZERO
var transfer_segments: Dictionary = {}
var transfer_points: Dictionary = {}

func measure_text(value:float) -> String:
	return ("%.1f" % absf(value)).trim_suffix(".0")

func draw_axes(lo: Vector2,hi: Vector2,maxmm: Vector2) -> void:
	if board.task.is_empty() or board.task.views.has("left"):
		super.draw_axes(lo,hi,maxmm)
	else:
		var z := scale_factor()
		segment(Vector2(lo.x,ORIGIN.y),Vector2(hi.x,ORIGIN.y),INK)
		text_at("X",Vector2(lo.x+28/z,ORIGIN.y),INK,Vector2(0,-12))
		text_at("O",ORIGIN,INK,Vector2(10,-12))

func extra_label_lines() -> Array:
	var result := known_segments.duplicate()
	if teacher:
		for item in primitives:
			if item.kind=="line" and progress>=item.order and erased_fraction(item)<1: result.append([at(item.a),at(item.b)])
			elif item.kind=="transfer" and progress>item.order and progress<item.order+1:
				for path in item.paths:result.append([at(path[0]),at(path[1])])
	return result

func extra_label_rects() -> Array[Rect2]:
	return known_rects

func dot(p: Vector2,name: String,color := INK) -> void:
	draw_circle(p,4/scale_factor(),color,true,-1,true)
	if not name.is_empty(): text_at(name,p,color,student_name_offset(p,name))

func draw_known() -> void:
	known_segments.clear(); known_rects.clear()
	if board.task.is_empty(): return
	for id in board.task.known_lines:
		var parts: PackedStringArray = id.split("_")
		var ends: Array = board.task.lines[parts[0]]
		var a := at(board.task.refs[ends[0]+"_"+parts[1]])
		var b := at(board.task.refs[ends[1]+"_"+parts[1]])
		if a.distance_to(b)>.01 and known_progress>0:
			known_segments.append([a,b]); segment(a,a.lerp(b,known_progress),INK,1.8)
	if known_progress>=1:
		var merged: Dictionary = {}
		for id in board.task.known_points:
			var p: Array = board.task.refs[id]
			var key := "%.6f,%.6f" % [p[0],p[1]]
			var bits: PackedStringArray = id.split("_")
			var name := bits[0].to_lower()+("′" if bits[1]=="front" else "″" if bits[1]=="left" else "")
			if merged.has(key): merged[key].name+="("+name+")"
			else: merged[key]={"p":p,"name":name}
		for item in merged.values(): dot(at(item.p),item.name)
	known_rects.assign(student_label_rects)

func draw_teaching() -> void:
	super.draw_teaching()
	transfer_segments.clear();transfer_points.clear()
	for item in primitives:
		if item.kind!="transfer" or progress<=item.order:continue
		var t:=clampf(progress-item.order,0,1);var timing:Array=preload("res://line_transfer.gd").portions(t)
		transfer_segments[item.name]=[]
		for i in range(3):
			if timing[i][1]<=timing[i][0]:continue
			var a:=at(item.paths[i][0]);var b:=at(item.paths[i][1])
			var ends:Array=[a.lerp(b,timing[i][0]),a.lerp(b,timing[i][1])]
			transfer_segments[item.name].append(ends);dashed(ends[0],ends[1],INK)
		if t>=preload("res://line_transfer.gd").POINT_TIME:
			dot(at(item.p),item.name);transfer_points[item.name]=at(item.p)
		var sweep:Array=preload("res://line_transfer.gd").eraser(t)
		if not sweep.is_empty():
			var atp:=at(item.paths[sweep[0]][0]).lerp(at(item.paths[sweep[0]][1]),sweep[1]);var z:=scale_factor()
			draw_style_box(preload("res://ui_style.gd").card("f1ece6","8796a0",3,1),Rect2(atp-Vector2(10,6)/z,Vector2(20,12)/z))
	for p in tick_points:
		var atp := at(p); var normal := tick_direction.orthogonal().normalized()*5/scale_factor()
		segment(atp-normal,atp+normal,INK,1.5)

func _draw() -> void:
	super._draw()
	if not teacher and board.helper!=null: board.helper.draw_preview(self)
