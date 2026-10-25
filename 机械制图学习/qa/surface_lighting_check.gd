extends RefCounted
var r
var c
var h
var checks:Array=[]
var pictures:Array=[]
var suffix:="normal"
var stage:="after"
func frames(n:=4)->void:
	for i in range(n):await r.get_tree().process_frame
func check(label:String,ok:bool,detail=null)->void:
	checks.append({"check":label,"passed":ok,"detail":detail})
func shot(label:String)->Image:
	print("SURFACE_SHOT ",label)
	await frames(8);r.queue_redraw();c.paper.queue_redraw();await RenderingServer.frame_post_draw
	var file:="surface-lighting-"+stage+"-"+suffix+"-"+label
	var image:Image=c.space.viewport.get_texture().get_image()
	image.save_png("res://qa/"+file+"-model.png")
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+file+".png")
	pictures.append(file+".png")
	return Image.load_from_file("res://qa/"+file+"-model.png")
func orbit(delta:Vector2)->void:
	var p:Vector2=c.space.get_global_rect().get_center()
	var button:=InputEventMouseButton.new();button.position=p;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true
	r.get_viewport().push_input(button,true);await frames(1)
	var motion:=InputEventMouseMotion.new();motion.position=p+delta;motion.relative=delta;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	r.get_viewport().push_input(motion,true);await frames(2)
	button=InputEventMouseButton.new();button.position=p+delta;button.button_index=MOUSE_BUTTON_LEFT;button.pressed=false
	r.get_viewport().push_input(button,true);await frames(2)
func settle()->void:
	if c.player.phase in ["typing","playing"]:await h.key(KEY_D)
	if c.player.phase=="ready":await h.click(c.next);await h.key(KEY_D)
func mesh_checks()->void:
	var space=c.space
	for id in space.scene.entities:
		var entity:Dictionary=space.scene.entities[id]
		if not entity.has("triangles"):continue
		var node:Node3D=space.pools[space.active_scene].nodes[id].root
		var item:MeshInstance3D=node.get_child(0)
		var arrays:Array=item.mesh.surface_get_arrays(0)
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var same:bool=points.size()==entity.triangles.size();var winding:=true;var finite:=true
		for i in range(0,points.size(),3):
			for j in range(3):
				same=same and points[i+j].distance_to(space.xyz(entity.triangles[i+[0,2,1][j]]))<.0000001
				finite=finite and normals[i+j].is_finite() and absf(normals[i+j].length()-1)<.001
			var face:Vector3=(points[i+1]-points[i]).cross(points[i+2]-points[i])
			if face.length_squared()>1e-20:winding=winding and face.normalized().dot(normals[i])<-.97
		check(space.active_scene+"/"+id+" source positions preserved",same)
		check(space.active_scene+"/"+id+" outward normals and clockwise front",winding and finite)
		check(space.active_scene+"/"+id+" no outline mesh",node.get_child_count()==1+entity.get("world",[]).size() and item.mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES)
func run(main)->void:
	print("SURFACE_START")
	r=main;c=r.course_workspace;h=load("res://line_practice_check.gd").new();h.r=r
	stage="before" if "--before" in OS.get_cmdline_user_args() else "after"
	suffix="minimum" if "--minimum" in OS.get_cmdline_user_args() else "normal"
	DisplayServer.window_set_size(Vector2i(1060,720) if suffix=="minimum" else Vector2i(1440,900))
	await frames(8);r.states={};r.save_blocked=false;r.show_knowledge_map()
	r.knowledge_map.view.center_on(r.knowledge_map.canvas.cards.intersection_solids.get_rect().get_center());await frames()
	await h.click(r.knowledge_map.buttons.intersection_solids);await frames()
	print("SURFACE_ENTRY ",c.visible)
	check("actual map entry",c.visible and c.chapter.id=="intersection_solids")
	for id in ["inner","shell"]:
		await h.click(c.scene_tabs.get_node("Scene_"+id));await frames()
		c.space.reset_camera();var with_ao:Image=await shot(id)
		if stage=="after":
			mesh_checks()
			var paper_rect:=Rect2i(c.paper.get_global_rect())
			var paper_before:Image=r.get_viewport().get_texture().get_image().get_region(paper_rect)
			c.space.environment.ssao_enabled=false
			var without_ao:Image=await shot(id+"-without-ao")
			var paper_after:Image=r.get_viewport().get_texture().get_image().get_region(paper_rect)
			check(id+" lighting leaves 2D projection unchanged",paper_before.get_data()==paper_after.get_data())
			var changed:=0;var max_delta:=0.0
			var background:Color=without_ao.get_pixel(0,0)
			var background_delta:Color=with_ao.get_pixel(0,0)-background
			for y in range(with_ao.get_height()):
				for x in range(with_ao.get_width()):
					var a:Color=with_ao.get_pixel(x,y);var b:Color=without_ao.get_pixel(x,y)
					if absf(b.r-background.r)+absf(b.g-background.g)+absf(b.b-background.b)<.12:continue
					var delta:float=absf(a.r-b.r-background_delta.r)+absf(a.g-b.g-background_delta.g)+absf(a.b-b.b-background_delta.b)
					if delta>.015:changed+=1
					max_delta=maxf(max_delta,delta)
			check(id+" AO affects rendered pixels",changed>100,{"pixels":changed,"max_delta":max_delta})
			c.space.environment.ssao_enabled=true
		var state_before:Dictionary=c.space.state.duplicate(true)
		var old_yaw:float=c.space.yaw
		await orbit(Vector2(85,32));check(id+" actual orbit",not is_equal_approx(old_yaw,c.space.yaw))
		check(id+" orbit keeps geometry state",state_before==c.space.state)
		await shot(id+"-rotated")
		await orbit(Vector2(-160,-48));await shot(id+"-opposite")
		c.space.reset_camera()
		var observe_yaw:float=c.space.yaw
		await h.click(c.nav.get_node("CourseNav_concept"));await frames()
		for i in range(c.player.beats.size()):
			if c.player.beats[i].id=="intersection_solids:"+id+":visible":c.player.current=i;c.player.prepare();break
		await settle();await shot(id+"-lesson")
		check(id+" lesson stable",c.player.state==c.player.after[c.player.current])
		await orbit(Vector2(65,15));await shot(id+"-lesson-rotated")
		await h.click(c.footer.get_node("CourseExit"));await frames()
		check(id+" exit restores camera",is_equal_approx(c.space.yaw,observe_yaw))
		if stage=="after":
			var count:int=c.space.world.get_child_count()
			await h.click(c.nav.get_node("CourseNav_concept"));await h.click(c.footer.get_node("CourseExit"));await frames()
			check(id+" reused scene nodes",c.space.world.get_child_count()==count)
			# Triangle winding also feeds ray picking; exercise the actual click path.
			c.paper.marker=[];c.space.set_marker([])
			await h.click(c.space);await frames()
			check(id+" surface click still links 3D and 2D",c.paper.marker.size()==3 and c.space.marker.visible)
			if c.paper.marker.size()==3:
				var projected:Vector2=c.space.camera.unproject_position(c.space.xyz(c.paper.marker))
				check(id+" picked surface stays under pointer",projected.distance_to(c.space.size*.5)<1)
	if stage=="after":
		c.leave_to_map()
		for chapter in ["basic_solids","intersection_plane","combination","section","removed_section","threads","gears","bearings"]:
			r.open_map_example(chapter);await frames();mesh_checks();await shot("regression-"+chapter)
			var saved_scene:Dictionary=c.space.scene.duplicate(true)
			await orbit(Vector2(55,20));check(chapter+" rotation keeps source",saved_scene==c.space.scene)
			await h.click(c.nav.get_node("CourseNav_concept"));await settle()
			if chapter in ["section","threads"]:await shot("regression-"+chapter+"-lesson")
			await h.click(c.footer.get_node("CourseExit"));c.leave_to_map();await frames()
	check("offscreen",DisplayServer.window_get_position().x<0)
	check("no focus",DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	check("isolated save",r.save_path=="user://qa-surface-lighting.json")
	check("native content size",r.get_viewport().get_visible_rect().size==Vector2(DisplayServer.window_get_size()))
	r.save_states()
	FileAccess.open("res://qa/surface-lighting-"+stage+"-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"screenshots":pictures,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method()},"\t"))
