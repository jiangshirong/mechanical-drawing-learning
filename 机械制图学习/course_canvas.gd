extends Control
signal point_selected(world:Array)
var scene:Dictionary={}
var state:Dictionary={}
var focus:Array=[]
var view_rects:Dictionary={}
var transforms:Dictionary={}
var label_rects:Array[Rect2]=[]
var image_cache:Dictionary={}
var ink_rect:=Rect2()
var pulse:=0.0
var zoom:=1.0
var pan:=Vector2.ZERO
var exploring:=false
var dragging:=false
var protected_segments:Array=[]
var marker:Array=[]
var marker_view:=""
var moving_marker:=false

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	resized.connect(queue_redraw)
func configure(value:Dictionary)->void:
	scene=value;zoom=1;pan=Vector2.ZERO;queue_redraw()
func update_state(value:Dictionary,selected:Array)->void:state=value;focus=selected;queue_redraw()
func point(value:Array)->Vector2:return Vector2(float(value[0]),float(value[1]))
func at(p:Array,view:String)->Vector2:
	var tr:Dictionary=transforms[view]
	return (point(p)-tr.centre)*tr.scale*zoom+tr.offset+pan
func layout_views()->void:
	transforms.clear();view_rects.clear()
	var views:Array=scene.get("views",["front"])
	var rows:=2 if "top" in views else 1
	var cols:=2 if "left" in views else 1
	var bounds_by_view:Dictionary={}
	for i in range(views.size()):
		var view:String=views[i]
		var col:=1 if view=="left" and cols==2 else 0
		var row:=1 if view=="top" and rows==2 else 0
		var cell:=Rect2(Vector2(col*size.x/cols,row*size.y/rows),Vector2(size.x/cols,size.y/rows)).grow(-18)
		if scene.get("view_layout",{}).has(view):
			var region:Array=scene.view_layout[view]
			cell=Rect2(Vector2(region[0]*size.x,region[1]*size.y),Vector2(region[2]*size.x,region[3]*size.y)).grow(-18)
		view_rects[view]=cell
		var bounds:=Rect2();var found:=false
		for e in scene.get("entities",{}).values():
			if e.has("brace") and e.brace.view==view:
				for p in [e.brace.a,e.brace.b]:
					if not found:bounds=Rect2(point(p),Vector2.ZERO);found=true
					else:bounds=bounds.expand(point(p))
			for line in e.get("paths",{}).get(view,[]):
				for p in line.points:
					if not found:bounds=Rect2(point(p),Vector2.ZERO);found=true
					else:bounds=bounds.expand(point(p))
			for lab in e.get("labels",[]):
				if lab.view==view:
					if not found:bounds=Rect2(point(lab.at),Vector2.ZERO);found=true
					else:bounds=bounds.expand(point(lab.at))
			if e.has("image") and e.get("view","front")==view:
				var box:Array=e.get("rect",[-50,-50,100,100])
				var r:=Rect2(box[0],box[1],box[2],box[3])
				bounds=bounds.merge(r) if found else r;found=true
		bounds=bounds.grow(5)
		if view=="front" and state.has("view_box"):
			var box:Array=state.view_box
			bounds=Rect2(box[0],box[1],box[2],box[3])
		bounds_by_view[view]=bounds
		var scale:=minf((cell.size.x-36)/maxf(bounds.size.x,1),(cell.size.y-42)/maxf(bounds.size.y,1))
		transforms[view]={"centre":bounds.get_center(),"offset":cell.get_center()+Vector2(0,8),"scale":scale}
	# Orthographic views retain identical metric scale. Drawing-only single views fit independently.
	if views.size()>1:
		# Shared horizontal and vertical ranges preserve projection correspondences.
		if bounds_by_view.has("front") and bounds_by_view.has("top"):
			var lo:=minf(bounds_by_view.front.position.x,bounds_by_view.top.position.x)
			var hi:=maxf(bounds_by_view.front.end.x,bounds_by_view.top.end.x)
			for v in ["front","top"]:
				transforms[v].centre.x=(lo+hi)*.5
				transforms[v].scale=minf(transforms[v].scale,(view_rects[v].size.x-36)/maxf(hi-lo,1))
		if bounds_by_view.has("front") and bounds_by_view.has("left") and not "left" in scene.get("independent_views",[]):
			var lo:=minf(bounds_by_view.front.position.y,bounds_by_view.left.position.y)
			var hi:=maxf(bounds_by_view.front.end.y,bounds_by_view.left.end.y)
			for v in ["front","left"]:
				transforms[v].centre.y=(lo+hi)*.5
				transforms[v].scale=minf(transforms[v].scale,(view_rects[v].size.y-42)/maxf(hi-lo,1))
		var common:=INF
		for v in transforms:
			if not v in scene.get("independent_views",[]):common=minf(common,transforms[v].scale)
		for v in transforms:
			if not v in scene.get("independent_views",[]):transforms[v].scale=common

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f3f2eb"))
	if scene.is_empty() or state.is_empty():return
	layout_views();label_rects.clear();protected_segments.clear()
	for e in scene.entities.values():
		for v in e.get("paths",{}):
			if not transforms.has(v):continue
			for line in e.paths[v]:
				for i in range(line.points.size()-1):protected_segments.append([at(line.points[i],v),at(line.points[i+1],v)])
	var font:=get_theme_default_font()
	for v in view_rects:
		if view_rects.size()>1:draw_string(font,view_rects[v].position+Vector2(3,17),scene.get("view_titles",{}).get(v,{"front":"正面","top":"水平","left":"侧面"}.get(v,v)),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("69747c"))
	var text_jobs:Array=[]
	for id in scene.entities:
		var e:Dictionary=scene.entities[id]
		var pose:Dictionary=state.parts.get(id,{"visibility":float(e.get("initial",1)),"draw":1.0})
		var alpha:float=pose.get("visibility",1.0)
		if alpha<.002:continue
		var selected:bool=id in focus
		var color:=Color("c26728") if selected else Color(e.get("ink","263747"))
		color.a=alpha
		if e.has("brace"):draw_brace(at(e.brace.a,e.brace.view),at(e.brace.b,e.brace.view),e.brace.label,color)
		if e.has("patch_rect"):
			var r:Array=e.patch_rect;var v:String=e.get("view","front")
			var p:=at([r[0],r[1]],v);var q:=at([r[0]+r[2],r[1]+r[3]],v)
			draw_rect(Rect2(p,q-p),Color(1,1,1,alpha))
		if e.has("image"):
			var path:String=e.image
			if not image_cache.has(path):image_cache[path]=load("res://"+path)
			var v:String=e.get("view","front");var r:Array=e.get("rect",[-50,-50,100,100])
			var p:=at([r[0],r[1]],v);var q:=at([r[0]+r[2],r[1]+r[3]],v)
			if image_cache[path]:draw_texture_rect(image_cache[path],Rect2(p,q-p),false,Color(1,1,1,alpha))
		for view in e.get("paths",{}):
			if not transforms.has(view):continue
			for line in e.paths[view]:
				var pts:PackedVector2Array=[]
				for p in line.points:pts.append(at(p,view))
				var fraction:float=pose.get("draw",1.0)
				draw_path(pts,line.get("style","solid"),color,fraction,float(line.get("width",2.4 if selected else 1.7)))
		for lab in e.get("labels",[]):text_jobs.append([lab,color,selected])
	for job in text_jobs:
		var lab:Dictionary=job[0];var v:String=lab.view
		if not transforms.has(v):continue
		var fs:int=roundi(float(lab.get("size",20))*(1.0+(.08*(.5+.5*sin(pulse*4.0)) if job[2] else 0)))
		var p:=at(lab.at,v)+Vector2(5,-6)
		var text_size:=font.get_string_size(lab.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)
		var reserved:=font.get_string_size(lab.text,HORIZONTAL_ALIGNMENT_LEFT,-1,ceili(float(lab.get("size",20))*1.08))
		if lab.has("rotation"):
			draw_set_transform(p,float(lab.rotation));draw_string(font,Vector2.ZERO,lab.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,job[1]);draw_set_transform(Vector2.ZERO);continue
		var r:=Rect2(p-Vector2(0,reserved.y*.8),reserved) if lab.get("fixed",false) else place_label(p-Vector2(0,reserved.y*.8),reserved)
		p=r.position+Vector2(0,text_size.y*.8)
		label_rects.append(r)
		draw_style_box(preload("res://ui_style.gd").card("f3f2eb","f3f2eb",2,0),r.grow(2))
		draw_string(font,p,lab.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,job[1])
	if exploring and marker.size()==3:
		for v in transforms:
			var p:Array=[marker[0],-marker[2]] if v=="front" else ([marker[0],marker[1]] if v=="top" else [-marker[1],-marker[2]])
			draw_circle(at(p,v),5,Color("dc7e32"),true,-1,true)

func nearest_world(position:Vector2,unlimited:=false)->Array:
	var found:Array=[];var best:float=INF
	for id in scene.get("entities",{}):
		if float(state.get("parts",{}).get(id,{}).get("visibility",1))<.5:continue
		var entity:Dictionary=scene.entities[id]
		for view in entity.get("paths",{}):
			if not transforms.has(view) or (unlimited and view!=marker_view):continue
			for line in entity.paths[view]:
				if not line.has("world_points") or line.world_points.size()!=line.points.size():continue
				for i in range(line.points.size()-1):
					var a:=at(line.points[i],view);var b:=at(line.points[i+1],view)
					var u:=clampf((position-a).dot(b-a)/maxf(a.distance_squared_to(b),.0001),0,1)
					var distance:=position.distance_to(a.lerp(b,u))
					if not unlimited and distance>11:continue
					var w:=Vector3(line.world_points[i][0],line.world_points[i][1],line.world_points[i][2]).lerp(Vector3(line.world_points[i+1][0],line.world_points[i+1][1],line.world_points[i+1][2]),u)
					var score:=distance
					if marker.size()==3:score+=minf(.25,w.distance_to(Vector3(marker[0],marker[1],marker[2]))*.002)
					if score<best:best=score;found=[w.x,w.y,w.z];marker_view=view
	return found

func place_label(origin:Vector2,extent:Vector2)->Rect2:
	var chosen:=Rect2(origin,extent);var best:=INF
	for offset in [Vector2.ZERO,Vector2(0,-24),Vector2(10,24),Vector2(-extent.x-10,-24),Vector2(18,-48),Vector2(-extent.x-18,36),Vector2(0,58)]:
		var candidate:=Rect2((origin+offset).clamp(Vector2(6,6),size-extent-Vector2(6,6)),extent);var score:float=candidate.position.distance_to(origin)*.1
		for previous in label_rects:
			if candidate.grow(3).intersects(previous):score+=2000
		var box:=candidate.grow(3)
		for segment in protected_segments:
			if box.has_point(segment[0]) or box.has_point(segment[1]):score+=500;continue
			var corners:=[box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
			for i in range(4):
				if Geometry2D.segment_intersects_segment(segment[0],segment[1],corners[i],corners[(i+1)%4])!=null:score+=500;break
		if score<best:best=score;chosen=candidate
	return chosen

func draw_path(points:PackedVector2Array,style:String,color:Color,fraction:float,width:float)->void:
	if points.size()<2:return
	var length:=0.0
	for i in range(points.size()-1):length+=points[i].distance_to(points[i+1])
	var available:=length*clampf(fraction,0,1);var distance:=0.0
	for i in range(points.size()-1):
		var a:=points[i];var b:=points[i+1];var span:=a.distance_to(b)
		var remaining:=available-distance
		if remaining<=0:break
		if span>remaining:b=a.lerp(b,remaining/maxf(span,.001));span=remaining
		if style in ["dashed","axis"]:
			var at_distance:=0.0
			while at_distance<span:
				var period:=19.6 if style=="axis" else 9.0
				var phase:=fposmod(distance+at_distance,period)
				var ends:Array=[12.0,15.0,16.6,19.6] if style=="axis" else [5.5,9.0]
				var slot:=0
				while slot<ends.size()-1 and phase>=ends[slot]:slot+=1
				var jump:=minf(span-at_distance,float(ends[slot])-phase)
				if slot%2==0:draw_line(a.lerp(b,at_distance/maxf(span,.001)),a.lerp(b,(at_distance+jump)/maxf(span,.001)),color,1.1,true)
				at_distance+=maxf(jump,.01)
		else:draw_line(a,b,color,width if style!="thin" else 1.0,true)
		distance+=span

func draw_brace(a:Vector2,b:Vector2,value:String,color:Color)->void:
	var along:Vector2=(b-a).normalized();var out:=Vector2(-along.y,along.x)
	var middle:Vector2=(a+b)*.5
	var points:=PackedVector2Array()
	for i in range(65):
		var t:float=i/64.0
		var lift:float=10.0*sin(PI*t)+6.0*pow(maxf(0,1.0-absf(2*t-1.0)*7),2)
		points.append(a.lerp(b,t)+out*lift)
	draw_polyline(points,color,1.7,true)
	var font:=get_theme_default_font();var width:float=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	var p:Vector2=middle+out*34
	var box:=Rect2(p-Vector2(width*.5+4,13),Vector2(width+8,26))
	draw_rect(box,Color("f3f2eb"));draw_string(font,p+Vector2(-width*.5,6),value,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)

func _gui_input(event:InputEvent)->void:
	if not exploring:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				var point:Array=nearest_world(event.position)
				moving_marker=not point.is_empty();dragging=not moving_marker
				if moving_marker:marker=point;point_selected.emit(marker);queue_redraw()
			else:dragging=false;moving_marker=false
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor:=1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12
			var old:=zoom;zoom=clampf(zoom*factor,.5,5)
			pan=(pan-event.position+size*.5)*(zoom/old)+event.position-size*.5;queue_redraw()
	if event is InputEventMouseMotion and dragging:pan+=event.relative;pan=pan.clamp(-size*.8,size*.8);queue_redraw()
	if event is InputEventMouseMotion and moving_marker:
		var point:Array=nearest_world(event.position,true)
		if not point.is_empty():marker=point;point_selected.emit(marker);queue_redraw()
