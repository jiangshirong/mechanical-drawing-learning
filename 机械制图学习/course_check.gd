extends RefCounted
var r
var h
var checks:Array=[]
var suffix:="normal"
func check(label:String,value:bool)->void:
	checks.append({"check":label,"passed":value})
	if not value:push_warning("COURSE_QA "+label)
func frames(n:=2)->void:await h.frames(n)
func picture(label:String)->void:
	await frames(3);r.queue_redraw();r.course_workspace.paper.queue_redraw();await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/course-"+label+"-"+suffix+".png")
func settle(c)->void:
	if c.player.phase in ["typing","playing"]:await h.key(KEY_D)
	if c.player.phase=="ready":await h.click(c.next);await h.key(KEY_D)
	if c.player.phase=="playing":await h.key(KEY_D)
func phase_paths(c,id:String)->void:
	c.player.current=0;c.player.prepare();await frames()
	var index:int=c.player.current;var navigation_count:=[0]
	var on_navigation:=func():navigation_count[0]+=1
	c.player.navigation_requested.connect(on_navigation)
	await h.key(KEY_D,true);await h.key(KEY_D,false,true)
	check(id+"_modifier_echo_filtered",c.player.current==index and navigation_count[0]==0)
	c.player.navigation_requested.disconnect(on_navigation)
	var press:=InputEventKey.new();press.keycode=KEY_D;press.physical_keycode=KEY_D;press.pressed=true
	r.get_viewport().push_input(press,true);await frames()
	var phase:String=c.player.phase
	r.get_viewport().push_input(press,true);await frames();check(id+"_held_filtered",c.player.current==index and c.player.phase==phase)
	press=press.duplicate();press.pressed=false;r.get_viewport().push_input(press,true);await frames()
	c.player.current=0;c.player.prepare();await frames();c.exit_lesson();var cancelled:int=c.player.epoch;await h.wait_seconds(.12)
	check(id+"_exit_typing_cancelled",not c.active and c.player.epoch==cancelled and c.player.phase=="idle")
	c.start_concept();await frames();check(id+"_resume_before",c.player.current==0 and c.player.phase=="typing")
	var action_index:=-1
	for i in range(c.player.beats.size()):
		c.player.current=i
		if c.player.has_action() and not c.player.prepares_with_text():action_index=i;break
	if action_index>=0:
		c.player.current=action_index;c.player.prepare();await h.key(KEY_D)
		check(id+"_ready_phase",c.player.phase=="ready")
		await h.click(c.next);await h.wait_seconds(.16)
		check(id+"_mid_animation",c.player.phase=="playing" and c.player.state!=c.player.after[action_index])
		await h.key(KEY_A);check(id+"_busy_A_finishes",c.player.current==action_index and c.player.state==c.player.after[action_index])
		await h.key(KEY_A);check(id+"_A_retreat",c.player.current==action_index-1)
		c.player.current=action_index;c.player.prepare();await h.key(KEY_D);await h.click(c.next);c.exit_lesson();await h.wait_seconds(.12)
		check(id+"_exit_animation_cancelled",not c.active and c.player.phase=="idle")
		c.start_concept();await frames();check(id+"_resume_target",c.player.current==action_index and c.player.phase=="typing" and c.player.state==c.player.before[action_index])
	# Observe camera and view are kept outside the lesson player.
	c.exit_lesson();c.observe();c.space.yaw=.9;c.space.pitch=.31;c.paper.zoom=1.3;c.paper.pan=Vector2(14,-8);c.space.update_camera()
	c.start_concept();await frames()
	check(id+"_lesson_starts_default_view",is_equal_approx(c.space.yaw,.65) and is_equal_approx(c.paper.zoom,1) and c.paper.pan==Vector2.ZERO)
	c.exit_lesson();await frames()
	check(id+"_observation_restored",is_equal_approx(c.space.yaw,.9) and is_equal_approx(c.space.pitch,.31) and is_equal_approx(c.paper.zoom,1.3) and c.paper.pan==Vector2(14,-8))
	c.start_concept();c.player.current=0;c.player.prepare();await frames()
func run(root)->void:
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	suffix="minimum" if "--minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720))
	await frames(6)
	var c=r.course_workspace
	check("isolated",r.save_path=="user://qa-course-observation.json")
	check("offscreen",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	check("sixteen_chapters",r.knowledge_map.buttons.size()==16)
	await picture("map")
	for id in c.registry.chapters:
		if c.registry.chapters[id].legacy:continue
		print("COURSE_OPEN ",id)
		r.open_map_example(id);await frames(5)
		print("COURSE_OPENED ",id)
		check(id+"_entry",c.visible and c.chapter.id==id and not r.free_shell.visible)
		await h.click(c.nav.get_node("CourseNav_concept"));await frames(4)
		print("COURSE_STARTED ",id)
		check(id+"_concept",c.active and c.copy.selection_enabled)
		await phase_paths(c,id)
		c.player.current=0;c.player.prepare();await frames()
		for i in range(c.player.beats.size()):
			check(id+"_order_"+str(i),c.player.current==i)
			await settle(c)
			check(id+"_settled_"+str(i),c.player.phase in ["settled","complete"])
			check(id+"_state_"+str(i),c.player.state==c.player.after[i])
			check(id+"_text_bounds_"+str(i),r.get_global_rect().encloses(c.caption.get_global_rect()))
			check(id+"_caption_visible_"+str(i),c.caption.is_visible_in_tree())
			check(id+"_footer_bounds_"+str(i),r.get_global_rect().encloses(c.footer.get_global_rect()))
			if i==0 or i==c.player.beats.size()-1 or c.player.beats[i].id.split(":")[-1] in ["curve","connect","unfold","mesh","correct"]:await picture(id+"-"+str(i))
			if i<c.player.beats.size()-1:await h.key(KEY_D)
		check(id+"_last_disabled",c.next.disabled)
		await h.click(c.progress.nodes[0]);await frames();check(id+"_jump",c.player.current==0)
		await h.click(c.footer.get_node("CourseExit"));await frames();check(id+"_exit",not c.active)
		if not "--smoke" in OS.get_cmdline_user_args():
			await h.click(c.nav.get_node("CourseNav_lessons"));await frames()
			for task in c.course.tasks:
				await h.click(c.task_grid.get_node("CourseTask_"+task.id));await frames(3)
				check(task.id+"_start",c.active and c.player.current==0)
				for i in range(c.player.beats.size()):
					await settle(c);check(task.id+"_step_"+str(i),c.player.phase in ["settled","complete"])
					check(task.id+"_state_"+str(i),c.player.state==c.player.after[i])
					if i<c.player.beats.size()-1:await h.key(KEY_D)
				await picture(task.id+"-result");await h.click(c.footer.get_node("CourseExit"));await frames()
				check(task.id+"_return",c.tasks.visible and not c.active)
		c.leave_to_map();await frames()
	r.save_states();await frames()
	FileAccess.open("res://qa/course-check-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
