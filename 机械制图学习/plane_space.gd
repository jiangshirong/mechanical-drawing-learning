extends Control
# One persistent mesh pool; scene interpolation uses intrinsic coordinates on one plane.
var demo
var observer
var face:MeshInstance3D
var strokes:MeshInstance3D
var projection_strokes:MeshInstance3D
var balls:Dictionary={}
var offsets:Dictionary={}
var frame_points:Dictionary={}
var names:Array=[]
var projected_lines:Array=[]
var interior_segments:Array=[]
var projection_rays:Array=[]

func setup(value)->void:
	demo=value;observer=demo.space;mouse_filter=Control.MOUSE_FILTER_IGNORE
	face=MeshInstance3D.new();face.material_override=observer.material(Color("4d94b2"),.48);observer.world.add_child(face)
	strokes=MeshInstance3D.new();var mat:StandardMaterial3D=observer.material(Color("29465b"));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;strokes.material_override=mat;observer.world.add_child(strokes)
	projection_strokes=MeshInstance3D.new();var ray_mat:StandardMaterial3D=observer.material(Color("d88a38"));ray_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;projection_strokes.material_override=ray_mat;observer.world.add_child(projection_strokes)
	for n in ["A","B","C","D","E","M","N","P","F","G"]:
		for v in ["space","front","top","left"]:
			var ball:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.00085;mesh.height=.0017;ball.mesh=mesh;ball.material_override=observer.material(Color("b86b37") if v=="space" else Color("29465b"));observer.world.add_child(ball);balls[n+"_"+v]=ball;ball.hide()
	for item in [["H",Vector3(-.027,0,.023),Vector3(-90,0,0)],["V",Vector3(-.027,.025,0),Vector3.ZERO],["W",Vector3(0,.025,.023),Vector3(0,90,0)]]:
		var plane:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(.07,.062);plane.mesh=mesh;plane.position=item[1];plane.rotation_degrees=Vector3.ZERO if item[0]=="H" else Vector3(90,0,0) if item[0]=="V" else Vector3(0,0,90);plane.material_override=observer.material(Color("b9c8d0"),.12);observer.world.add_child(plane)
		var label:=Label3D.new();label.text=item[0];label.position=item[1]+(Vector3(-.016,.014,0) if item[0]=="V" else Vector3.ZERO);label.rotation_degrees=item[2];label.font_size=28;label.pixel_size=.00012;label.no_depth_test=false;observer.world.add_child(label)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func vec(p:Array)->Vector3:return Vector3(p[0],p[1],p[2])
static func arr(p:Vector3)->Array:return [p.x,p.y,p.z]
static func frame(points:Dictionary,vertices:Array)->Dictionary:
	var origin:=vec(points[vertices[0]]);var x:Vector3=(vec(points[vertices[1]])-origin).normalized()
	var n:Vector3=x.cross(vec(points[vertices[-1]])-origin).normalized();var y:=n.cross(x).normalized()
	return {"origin":origin,"basis":Basis(x,y,n)}

static func morph(source:Dictionary,target:Dictionary,t:float)->Dictionary:
	if source.is_empty() or t>=1:return target.points.duplicate(true)
	var a:=frame(source.points,source.vertices);var b:=frame(target.points,target.vertices)
	var basis:=Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(),t));var origin:Vector3=a.origin.lerp(b.origin,t);var result:Dictionary={}
	for n in target.points:
		var end:Vector3=b.basis.inverse()*(vec(target.points[n])-b.origin)
		var start:Vector3=a.basis.inverse()*(vec(source.points.get(n,source.points[source.vertices[0]]))-a.origin)
		start.z=0;end.z=0;result[n]=arr(origin+basis*start.lerp(end,t))
	return result

func screen(p:Array)->Vector2:return observer.camera.unproject_position(observer.g(p))*observer.size/Vector2(observer.viewport.size)

func update_geometry()->void:
	if not demo.active or demo.task.is_empty():return
	frame_points=demo.task.points;names.clear();projected_lines.clear();interior_segments.clear();projection_rays.clear()
	for ball in balls.values():ball.hide()
	var verts:Array=demo.task.vertices;var available:Array=[]
	for n in verts:
		var count:=0
		for v in ["front","top","left"]:
			if demo.sheet.canvas.visible_refs.has(n+"_"+v) or n+"_"+v in demo.task.known_points:count+=1
		if count>=2 or demo.scene_id=="intro":available.append(n)
	var mesh:=ImmediateMesh.new()
	if available.size()>=3:
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1,available.size()-1):
			for n in [available[0],available[i],available[i+1]]:mesh.surface_add_vertex(observer.g(frame_points[n]))
		mesh.surface_end()
	face.mesh=mesh
	var lines:=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES);var line_count:=0
	for i in range(available.size()):
		var n:String=available[i];var m:String=available[(i+1)%available.size()]
		lines.surface_add_vertex(observer.g(frame_points[n]));lines.surface_add_vertex(observer.g(frame_points[m]));projected_lines.append([screen(frame_points[n]),screen(frame_points[m])]);line_count+=1
	for n in available:
		balls[n+"_space"].position=observer.g(frame_points[n]);balls[n+"_space"].show();names.append([n,n,frame_points[n]])
	var ray_mesh:=ImmediateMesh.new();var ray_count:=0
	for item in demo.sheet.canvas.primitives:
		if item.kind!="space_point":continue
		var amount:float=clampf(demo.sheet.canvas.progress-item.order,0,1)
		if amount<=0 or demo.sheet.canvas.progress>item.ray_end_order+.00001:continue
		var a:Array=frame_points[item.vertex];var b:Array=a.duplicate()
		b[1 if item.view=="front" else 2 if item.view=="top" else 0]=0
		var end:Vector3=observer.g(a).lerp(observer.g(b),clampf(amount/.78,0,1))
		if ray_count==0:ray_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		ray_count+=add_segment(ray_mesh,observer.g(a),end,1.,true)
		projection_rays.append({"vertex":item.vertex,"view":item.view,"from":a.duplicate(),"foot":b,"amount":amount})
	if ray_count>0:ray_mesh.surface_end();projection_strokes.mesh=ray_mesh
	else:projection_strokes.mesh=null
	for n in frame_points:
		if n in verts:continue
		var count:=0
		for v in ["front","top","left"]:
			if demo.sheet.canvas.visible_refs.has(n+"_"+v):count+=1
		if count>=2 and balls.has(n+"_space"):
			balls[n+"_space"].position=observer.g(frame_points[n]);balls[n+"_space"].show();names.append([n,n,frame_points[n]])
	for ref in demo.sheet.canvas.visible_refs:
		if not balls.has(ref):continue
		var bits:PackedStringArray=ref.split("_");var p:Array=frame_points[bits[0]].duplicate();var suffix:=""
		if bits[1]=="front":p[1]=0;suffix="′"
		elif bits[1]=="top":p[2]=0
		else:p[0]=0;suffix="″"
		balls[ref].position=observer.g(p);balls[ref].show()
		# Projection point labels are kept on the 2D paper; space labels name actual vertices.
	for seg in demo.sheet.canvas.rendered_segments:
		var bits:PackedStringArray=seg[0].split("_");var other:PackedStringArray=seg[1].split("_")
		if not frame_points.has(bits[0]) or not frame_points.has(other[0]):continue
		var a:Array=frame_points[bits[0]].duplicate();var b:Array=frame_points[other[0]].duplicate()
		if bits[1]=="front":a[1]=0;b[1]=0
		elif bits[1]=="top":a[2]=0;b[2]=0
		else:a[0]=0;b[0]=0
		if balls.has(bits[0]+"_space") and balls[bits[0]+"_space"].visible and balls.has(other[0]+"_space") and balls[other[0]+"_space"].visible and (bits[0] not in verts or other[0] not in verts):
			interior_segments.append([bits[0],other[0],frame_points[bits[0]],frame_points[other[0]]])
			line_count+=add_segment(lines,observer.g(frame_points[bits[0]]),observer.g(frame_points[other[0]]),seg[2],seg.size()>3 and seg[3])
		if observer.g(a).distance_to(observer.g(b))>.000001:
			projected_lines.append([screen(a),screen(b)])
			line_count+=add_segment(lines,observer.g(a),observer.g(b),seg[2],seg.size()>3 and seg[3])
	if line_count>0:lines.surface_end();strokes.mesh=lines
	observer.request_render();queue_redraw()

func add_segment(mesh:ImmediateMesh,a:Vector3,b:Vector3,amount:float,dashed:bool)->int:
	if a.distance_to(b)<.000001 or amount<=0:return 0
	if not dashed:mesh.surface_add_vertex(a);mesh.surface_add_vertex(a.lerp(b,amount));return 1
	var count:=0
	for i in range(12):
		var start:=float(i)/12;var end:=minf((float(i)+.6)/12,amount)
		if end>start:mesh.surface_add_vertex(a.lerp(b,start));mesh.surface_add_vertex(a.lerp(b,end));count+=1
	return count

func _draw()->void:
	if not demo or not demo.active:return
	var font:=get_theme_default_font();var used:Array=[]
	for item in names:
		var p:=screen(item[2]);var width:=font.get_string_size(item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		if not offsets.has(item[0]):
			var best:=Vector2(9,-10);var cost:=INF
			for radius in [0,15,30,45,60]:
				for base in [Vector2(9,-12),Vector2(-width-10,-12),Vector2(9,27),Vector2(-width-10,27),Vector2(-width*.5,-20)]:
					var delta:Vector2=base+(base+Vector2(width*.5,-7)).normalized()*radius
					var rect:=Rect2(p+delta-Vector2(3,20),Vector2(width+6,25));var score:=float(radius)
					if not Rect2(Vector2.ZERO,size).encloses(rect):score+=100000
					for line in projected_lines:
						if demo.overlay.segment_hits(rect.grow(3),line[0],line[1]):score+=100000
					for old in used:
						if rect.grow(3).intersects(old):score+=100000
					if score<cost:cost=score;best=delta
				offsets[item[0]]=best
		var atp:Vector2=p+offsets[item[0]];used.append(Rect2(atp-Vector2(3,20),Vector2(width+6,25)))
		draw_string(font,atp+Vector2.ONE,item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("102432"))
		draw_string(font,atp,item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e0e9ee"))
