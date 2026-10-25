extends "res://line_practice_canvas.gd"
var visible_refs:Dictionary={}
var rendered_segments:Array=[]
var focus_refs:Array=[]

func resolve(ref:String)->Array:return board.task.refs.get(ref,[0,0])

func draw_known()->void:
	super.draw_known()
	visible_refs.clear();rendered_segments.clear()
	if known_progress>=1:
		for ref in board.task.known_points:visible_refs[ref]=true
	for guide in board.task.get("known_guides",[]):
		if known_progress>0:
			var a:=at(resolve(guide[0]));var b:=at(resolve(guide[1]))
			segment(a,a.lerp(b,known_progress),Color("8d9ba5"),.7)
	for id in board.task.known_lines:
		var bits:PackedStringArray=id.split("_");var ends:Array=board.task.lines[bits[0]]
		if known_progress>0:rendered_segments.append([ends[0]+"_"+bits[1],ends[1]+"_"+bits[1],known_progress])

func extra_label_lines()->Array:
	var result:=known_segments.duplicate()
	for item in primitives:
		if item.order>=progress or erased_fraction(item)>=1:continue
		if item.kind=="line":result.append([at(resolve(item.ar)),at(resolve(item.br))])
		elif item.kind=="transfer" and progress<item.order+1:
			for path in item.path_refs:result.append([at(resolve(path[0])),at(resolve(path[1]))])
	return result

func draw_teaching()->void:
	transfer_segments.clear();transfer_points.clear()
	for item in primitives:
		var amount:float=clampf(progress-item.order,0,1)
		if amount<=0 or erased_fraction(item)>=1:continue
		if item.kind=="line":
			var a:=at(resolve(item.ar));var b:=at(resolve(item.br));var erased:=erased_fraction(item)
			if item.get("dashed",false):dashed(a,b,INK,1.1,erased,amount)
			else:segment(a.lerp(b,erased),a.lerp(b,amount),INK,1.7)
			rendered_segments.append([item.ar,item.br,amount,item.get("dashed",false)])
		elif item.kind=="point":
			if amount>=item.get("threshold",0):dot(at(resolve(item.ref)),item.name);visible_refs[item.ref]=true
		elif item.kind=="space_point":
			if amount>=.78:dot(at(resolve(item.ref)),item.name);visible_refs[item.ref]=true
		elif item.kind=="transfer":
			var timing:Array=preload("res://line_transfer.gd").portions(amount);transfer_segments[item.ref]=[]
			for i in range(3):
				if timing[i][1]<=timing[i][0]:continue
				var a:=at(resolve(item.path_refs[i][0]));var b:=at(resolve(item.path_refs[i][1]))
				var ends:Array=[a.lerp(b,timing[i][0]),a.lerp(b,timing[i][1])]
				dashed(ends[0],ends[1],INK);transfer_segments[item.ref].append(ends)
			if amount>=preload("res://line_transfer.gd").POINT_TIME:
				dot(at(resolve(item.ref)),item.name);visible_refs[item.ref]=true;transfer_points[item.ref]=at(resolve(item.ref))
			var sweep:Array=preload("res://line_transfer.gd").eraser(amount)
			if not sweep.is_empty():
				var path:Array=item.path_refs[sweep[0]];var p:=at(resolve(path[0])).lerp(at(resolve(path[1])),sweep[1]);var z:=scale_factor()
				draw_style_box(preload("res://ui_style.gd").card("f1ece6","8796a0",3,1),Rect2(p-Vector2(10,6)/z,Vector2(20,12)/z))
