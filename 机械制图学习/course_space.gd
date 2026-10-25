extends SubViewportContainer
const SurfaceNormals=preload("res://surface_normals.gd")
signal point_selected(world:Array)
var viewport:SubViewport
var world:Node3D
var camera:Camera3D
var pools:Dictionary={}
var active_scene:=""
var yaw:=.65
var pitch:=.42
var radius:=.15
var centre:=Vector3.ZERO
var dragging:=false
var enabled:=true
var state:Dictionary={}
var scene:Dictionary={}
var focus:Array=[]
var marker:MeshInstance3D
var picking_enabled:=false
var drag_distance:=0.0
var environment:Environment
var light_rig:Node3D
var key_light:DirectionalLight3D

func _ready()->void:
	stretch=true;mouse_filter=Control.MOUSE_FILTER_STOP
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;add_child(viewport)
	world=Node3D.new();viewport.add_child(world)
	var env:=WorldEnvironment.new();environment=Environment.new()
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("172a37")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.32
	environment.ssao_enabled=true;environment.ssao_intensity=.4;environment.ssao_power=.7
	environment.ssao_detail=0.0;environment.ssao_horizon=.2;environment.ssao_light_affect=.05;environment.ssao_sharpness=.95
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH,false,.5,4,50,300)
	env.environment=environment;world.add_child(env)
	# Camera-relative studio light keeps every orbit readable. Local ambient
	# occlusion adds soft cavity shading without shadow-map acne on millimetre solids.
	light_rig=Node3D.new();world.add_child(light_rig)
	key_light=DirectionalLight3D.new();key_light.rotation_degrees=Vector3(-35,-35,0);key_light.light_energy=.7;light_rig.add_child(key_light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(10,50,0);fill.light_energy=.22;light_rig.add_child(fill)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.0001;camera.far=20;world.add_child(camera)
	marker=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.0018;ball.height=.0036;marker.mesh=ball;marker.material_override=material("df8438",1,true);world.add_child(marker);marker.hide()
	resized.connect(update_camera)
func xyz(p:Array)->Vector3:return Vector3(p[0],p[2],-p[1])*.001
func material(color:String,alpha:=1.0,unshaded:=false)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.albedo_color.a=alpha;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.roughness=.72;m.metallic_specular=.25
	if unshaded:m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha<1:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
func configure(value:Dictionary)->void:
	scene=value;active_scene=value.id
	for id in pools:pools[id].root.visible=id==active_scene
	if not pools.has(active_scene):
		var root:=Node3D.new();world.add_child(root);var nodes:Dictionary={};var positions:Array[Vector3]=[]
		for id in value.entities:
			var e:Dictionary=value.entities[id];var entity:=Node3D.new();root.add_child(entity);var draws:Array=[]
			var fit_subject:bool=float(e.get("opacity",1))>=.5 and e.get("role","")!="attention"
			if e.has("model"):
				var packed=load("res://"+e.model)
				if packed:
					var model=packed.instantiate();entity.add_child(model)
					# Exported original GLBs already use engine metres.
					if fit_subject:collect_bounds(model,positions)
			if e.has("triangles"):
				var vertices:=PackedVector3Array()
				for p in e.triangles:
					vertices.append(xyz(p))
					if fit_subject:positions.append(xyz(p))
				var arrays:Array=SurfaceNormals.arrays(vertices)
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				var item:=MeshInstance3D.new();item.mesh=mesh;item.material_override=material(e.get("color","6d9cba"));entity.add_child(item)
			for line in e.get("world",[]):
				var vertices:=PackedVector3Array()
				for p in line.points:
					vertices.append(xyz(p))
					if fit_subject:positions.append(xyz(p))
				if vertices.size()<2:continue
				var immediate:=ImmediateMesh.new();var item:=MeshInstance3D.new();item.mesh=immediate;item.material_override=material(e.get("color","c78341"),1,true);entity.add_child(item);draws.append({"mesh":immediate,"vertices":vertices,"last":-1.0})
			var materials:Array=[]
			collect_materials(entity,materials,e.get("color","6d9cba"))
			var faces:=PackedVector3Array();collect_faces(entity,faces)
			nodes[id]={"root":entity,"draws":draws,"materials":materials,"faces":faces}
		var box:=AABB(Vector3.ZERO,Vector3.ZERO)
		if not positions.is_empty():
			box=AABB(positions[0],Vector3.ZERO)
			for p in positions:box=box.expand(p)
		pools[active_scene]={"root":root,"nodes":nodes,"bounds":box}
	var bounds:AABB=pools[active_scene].bounds;centre=bounds.get_center();radius=maxf(bounds.size.length()*.55,.04)
	# Authored dimensions are millimetres; AO range must follow model scale.
	environment.ssao_radius=radius*.5
	reset_camera()
func collect_bounds(node:Node,points:Array[Vector3])->void:
	if node is MeshInstance3D:
		var box:AABB=node.get_aabb()
		for i in range(8):points.append(node.global_transform*box.get_endpoint(i))
	for child in node.get_children():collect_bounds(child,points)
func collect_faces(node:Node,points:PackedVector3Array)->void:
	if node is MeshInstance3D:
		for p in node.mesh.get_faces():points.append(node.global_transform*p)
	for child in node.get_children():collect_faces(child,points)
func collect_materials(node:Node,out:Array,color:String)->void:
	if node is MeshInstance3D:
		if not node.material_override:node.material_override=material(color)
		out.append(node.material_override)
	for child in node.get_children():collect_materials(child,out,color)
func set_marker(value:Array)->void:
	marker.visible=picking_enabled and value.size()==3
	if value.size()==3:marker.position=xyz(value)
func pick(position:Vector2)->void:
	if not picking_enabled or not pools.has(active_scene):return
	var origin:=camera.project_ray_origin(position);var direction:=camera.project_ray_normal(position)
	var hit:Variant=null;var distance:=INF
	for node in pools[active_scene].nodes.values():
		if not node.root.visible:continue
		var inverse:Transform3D=node.root.global_transform.affine_inverse()
		var local_origin:Vector3=inverse*origin;var local_direction:Vector3=inverse.basis*direction
		var faces:PackedVector3Array=node.faces
		for i in range(0,faces.size(),3):
			var p=Geometry3D.ray_intersects_triangle(local_origin,local_direction,faces[i],faces[i+1],faces[i+2])
			if p==null:continue
			p=node.root.global_transform*p
			if origin.distance_to(p)<distance:distance=origin.distance_to(p);hit=p
	if hit!=null:point_selected.emit([hit.x*1000,-hit.z*1000,hit.y*1000])
func reset_camera()->void:
	yaw=.65;pitch=.42;update_camera()
func update_camera()->void:
	if not camera:return
	camera.position=centre+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*radius*4
	camera.look_at(centre,Vector3.UP);camera.size=radius*2.25*maxf(1.0,size.y/maxf(size.x,1))
	camera.near=maxf(radius*.02,.0001);camera.far=radius*9
	light_rig.basis=camera.global_basis
func update_state(value:Dictionary,selected:Array)->void:
	state=value;focus=selected
	if not pools.has(active_scene):return
	for id in pools[active_scene].nodes:
		var node:Dictionary=pools[active_scene].nodes[id];var pose:Dictionary=value.parts.get(id,{"visibility":float(scene.entities[id].get("initial",1)),"draw":1.0})
		node.root.visible=float(pose.get("visibility",1))>.001
		node.root.position=xyz(pose.get("move",[0,0,0]));node.root.rotation.y=deg_to_rad(float(pose.get("angle",0)))
		var amount:float=pose.get("draw",1)
		for line in node.draws:
			if is_equal_approx(line.last,amount):continue
			line.last=amount;line.mesh.clear_surfaces()
			if amount<=0:continue
			var vertices:PackedVector3Array=line.vertices
			var last:=int((vertices.size()-1)*amount)
			line.mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for i in range(mini(last+1,vertices.size())):line.mesh.surface_add_vertex(vertices[i])
			if last<vertices.size()-1:line.mesh.surface_add_vertex(vertices[last].lerp(vertices[last+1],fposmod((vertices.size()-1)*amount,1)))
			line.mesh.surface_end()
		for m in node.materials:
			m.albedo_color=Color("d49651") if id in selected else Color(scene.entities[id].get("color","6d9cba"))
			m.albedo_color.a=float(pose.get("visibility",1))*float(scene.entities[id].get("opacity",1))
			m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if m.albedo_color.a<.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
func _gui_input(event:InputEvent)->void:
	if not enabled:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:drag_distance=0
		elif dragging and drag_distance<6:pick(event.position)
		dragging=event.pressed
	if event is InputEventMouseMotion and dragging:
		drag_distance+=event.relative.length()
		yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.008,-1.3,1.3);update_camera()
		accept_event()
