extends RefCounted
var r
var h
var c
var checks:Array=[]
var pictures:Array=[]
var suffix:String
func check(name:String,ok:bool)->void:
	checks.append({"check":name,"passed":ok})
	if not ok:push_warning("METHOD_REVIEW "+name)
func snap(id:String,stage:String,text:String)->void:
	await h.frames(3);r.queue_redraw();await RenderingServer.frame_post_draw
	var file:String="method-"+id.replace(":","_")+"-"+stage+"-"+suffix+".png"
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+file)
	pictures.append({"beat":id,"stage":stage,"file":file,"text":text})
func plane(id:String)->void:
	r.plane_step_id=id;r.plane_demo.enter();await h.frames(4)
	var d=r.plane_demo;check(id+" target",d.beats[d.current_beat].id==id)
	await h.key(KEY_D);await snap("plane:"+id,"before",d.overlay.label.text)
	if d.phase=="ready":
		await h.click(d.next)
		if d.beats[d.current_beat].action.type=="space_project":
			await h.wait_seconds(.65);await snap("plane:"+id,"first-ray",d.overlay.label.text)
			check(id+" real space ray before first foot",d.spatial.projection_rays.size()==1 and d.spatial.projection_rays[0].amount<.78)
			check(id+" boundary not drawn before vertices",d.sheet.canvas.rendered_segments.is_empty() if id=="projection:front" else not d.sheet.canvas.rendered_segments.any(func(x):return x[0].ends_with("_"+d.beats[d.current_beat].action.view)))
			for ray in d.spatial.projection_rays:
				var foot_pixel:Vector2=d.space.global_position+d.spatial.screen(ray.foot)
				check(id+" caption leaves actual foot clear",not d.overlay.panel.get_global_rect().grow(8).has_point(foot_pixel))
				var axis:int=1 if ray.view=="front" else 2 if ray.view=="top" else 0
				check(id+" ray perpendicular foot",is_zero_approx(ray.foot[axis]))
				for k in range(3):
					if k!=axis:check(id+" ray preserves component "+str(k),is_equal_approx(ray.from[k],ray.foot[k]))
			await h.wait_seconds(1.65);await snap("plane:"+id,"more-vertices",d.overlay.label.text)
			await h.wait_seconds(2.7)
		else:
			await h.wait_seconds(float(d.beats[d.current_beat].action.get("duration",1.1))*.48)
			await snap("plane:"+id,"during",d.overlay.label.text)
			await h.wait_seconds(float(d.beats[d.current_beat].action.get("duration",1.1))*.6+.1)
	check(id+" natural result",d.phase in ["settled","complete"])
	await snap("plane:"+id,"after",d.overlay.label.text)
	if d.beats[d.current_beat].action.type=="space_project":
		for n in d.task.vertices:check(id+" visible projected "+n,d.sheet.canvas.visible_refs.has(n+"_"+d.beats[d.current_beat].action.view))
	var count:int=d.space.world.get_child_count();d.exit();r.plane_demo.enter();await h.frames(3)
	check(id+" stable resume before action",d.current_beat>=0 and (is_equal_approx(d.sheet.canvas.progress,d.before_states[d.current_beat]) or d.preparing))
	check(id+" node pool reused",d.space.world.get_child_count()==count);d.exit();await h.frames(3)
func course(chapter:String,ids:Array)->void:
	r.open_map_example(chapter);await h.frames(4);await h.click(c.nav.get_node("CourseNav_concept"))
	for id in ids:
		c.player.open(c.course.concept,id);await h.frames(3);await h.key(KEY_D)
		await snap(id,"before",c.copy.text)
		if c.player.phase=="ready":
			await h.click(c.next);await h.wait_seconds(float(c.current_beat.action.get("duration",1.8))*.48)
			await snap(id,"during",c.copy.text)
			await h.wait_seconds(float(c.current_beat.action.get("duration",1.8))*.6+.1)
		check(id+" finishes",c.player.phase in ["settled","complete"])
		await snap(id,"after",c.copy.text)
	c.exit_lesson();c.leave_to_map();await h.frames(3)
func division()->void:
	r.open_map_example("line");await h.frames(3);r.line_step_id="division:parts";r.course_host.enter("line");await h.frames(4)
	var d=r.course_host.controller();await h.key(KEY_D);await h.click(d.next);await h.wait_seconds(.95)
	check("division shows space partition first",d.space_tick_points.size()>0 and d.paper.ratio_marks.is_empty())
	await snap("line:division:parts","space-first",d.copy.text);await h.wait_seconds(1.9)
	check("division five equal pieces shown",d.space_tick_points.size()==4 and d.paper.ratio_marks.size()==12)
	var ends:Array=d.geometry.ends(d.state,"AB")
	for i in range(4):check("space division fraction "+str(i),d.space_tick_points[i].distance_to(ends[0].lerp(ends[1],float(i+1)/5))<.000001)
	await snap("line:division:parts","projections",d.copy.text);r.course_host.leave();r.show_knowledge_map();await h.frames(3)
func run(main,window_suffix:String)->void:
	r=main;c=r.course_workspace;suffix=window_suffix;h=load("res://line_practice_check.gd").new();h.r=r
	r.open_map_example("plane");await h.frames(4)
	for id in ["projection:surface","projection:front","projection:front-boundary","projection:other","projection:top-boundary","projection:side-points","projection:side-boundary","complete:third-endpoints","complete:third-remaining","complete:parallel-context","complete:parallel-c-distance","complete:parallel-c","complete:parallel-ab","complete:parallel-b","complete:parallel-complete"]:await plane(id)
	r.show_knowledge_map();await h.frames(3)
	await division()
	await course("basic_solids",["basic_solids:cylinder:given","basic_solids:cylinder:height","basic_solids:cylinder:point","basic_solids:cone:given","basic_solids:cone:point","basic_solids:sphere:given","basic_solids:sphere:level","basic_solids:sphere:point"])
	await course("intersection_solids",["intersection_solids:inner:special","intersection_solids:inner:middle","intersection_solids:shell:outer-points","intersection_solids:shell:inner-points","intersection_solids:shell:connect"])
	await course("combination",["combination:slope:point-height","combination:slope:point-depth","combination:slope:outer"])
	check("isolated save",r.save_path=="user://qa-course-beginner.json")
	check("offscreen no focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	FileAccess.open("res://qa/course-method-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"pictures":pictures},"\t"))
