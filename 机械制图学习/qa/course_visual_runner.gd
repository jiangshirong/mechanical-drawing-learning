extends RefCounted
var checks:Array=[]
var shots:Array=[]
var r
var h
var suffix:="normal"
var root:Window
func frames(n:=4)->void:
	for i in range(n):await r.get_tree().process_frame
func check(label:String,passed:bool)->void:checks.append({"check":label,"passed":passed})
func picture(name:String)->void:
	await frames();r.queue_redraw();r.course_workspace.paper.queue_redraw();await RenderingServer.frame_post_draw
	var file:="course-extra-"+name+"-"+suffix+".png"
	root.get_texture().get_image().save_png("res://qa/"+file);shots.append(file)
func run(main)->void:
	print("EXTRA_RUN_START")
	r=main;root=r.get_tree().root
	suffix="minimum" if "--minimum" in OS.get_cmdline_user_args() else "normal"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-6000,-6000))
	DisplayServer.window_set_size(Vector2i(1060,720) if suffix=="minimum" else Vector2i(1440,900))
	await frames(8)
	print("EXTRA_FRAMES_READY")
	r.save_path="user://qa-course-visual.json";r.states={};r.save_blocked=false
	h=load("res://line_practice_check.gd").new();h.r=r
	var c=r.course_workspace
	r.show_knowledge_map();await frames()
	check("sixteen chapter map visible",r.map_active and r.knowledge_map.is_visible_in_tree() and r.knowledge_map.buttons.size()==16)
	await picture("knowledge-map")
	r.knowledge_map.view.center_on(Vector2(520,1240));await frames()
	await picture("knowledge-map-lower")
	await h.click(r.knowledge_map.buttons.threads);await frames()
	check("map card opens actual chapter",c.visible and c.chapter.id=="threads" and not r.map_active)
	c.leave_to_map();await frames()
	for id in ["threads","gears","section","part_drawing"]:
		print("EXTRA_CHAPTER ",id)
		r.open_map_example(id);await frames();await h.click(c.nav.get_node("CourseNav_lessons"));await frames()
		print("EXTRA_CHAPTER_READY ",id)
		check(id+" all navigation stays visible",c.nav.get_node("CourseNav_lessons").is_visible_in_tree())
		for b in c.task_grid.get_children():check(id+" task within list "+b.name,r.get_global_rect().encloses(b.get_global_rect()))
		await picture(id+"-list")
		var tid:String={"threads":"stud-connect","gears":"gear-pair","section":"section-combined","part_drawing":"read-lid"}[id]
		await h.click(c.task_grid.get_node("CourseTask_"+tid));await frames();await h.key(KEY_D);await frames()
		check(id+" full problem text",c.copy.visible_characters<0 or c.copy.visible_characters==c.copy.text.length())
		check(id+" problem card contained",r.get_global_rect().encloses(c.caption.get_global_rect()))
		check(id+" question avoids text",not c.question.button.get_global_rect().intersects(c.copy.get_global_rect()))
		check(id+" footer contained",r.get_global_rect().encloses(c.footer.get_global_rect()))
		await picture(tid+"-problem")
		await h.click(c.footer.get_node("CourseExit"));c.leave_to_map();await frames()
	# Actual intermediate, not only stable endpoints, for both rotation variants.
	for kind in ["rotated","combined"]:
		r.open_map_example("section");c.start_task("section-"+kind);await frames()
		for i in range(c.player.beats.size()):
			if c.player.beats[i].id.ends_with(":unfold"):
				c.player.current=i;c.player.prepare();await h.key(KEY_D);await h.click(c.next);await h.wait_seconds(.8)
				check(kind+" intermediate rotation",c.player.state.parts.rotating_arm.angle<0 and c.player.state.parts.rotating_arm.angle>-30)
				await picture(kind+"-rotation");break
		c.exit_lesson();c.leave_to_map();await frames()
	# Focused follow-up after comparing the full-section outline with the DOC.
	# Run the entire section again: final rear contours and all normal playback.
	r.open_map_example("section");c.start_concept();await frames();c.player.current=0;c.player.prepare()
	for i in range(c.player.beats.size()):
		if c.player.phase in ["typing","playing"]:await h.key(KEY_D)
		if c.player.phase=="ready":await h.click(c.next);await h.key(KEY_D)
		check("section follow-up beat "+str(i),c.player.state==c.player.after[i] and c.player.phase in ["settled","complete"])
		if i<c.player.beats.size()-1:await h.key(KEY_D)
	c.exit_lesson();c.show_tasks();c.start_task("section-full");await frames()
	for i in range(c.player.beats.size()):
		if c.player.phase in ["typing","playing"]:await h.key(KEY_D)
		if c.player.phase=="ready":await h.click(c.next);await h.key(KEY_D)
		check("full section follow-up task "+str(i),c.player.state==c.player.after[i])
		if i<c.player.beats.size()-1:await h.key(KEY_D)
	await picture("full-section-final");c.exit_lesson();c.leave_to_map()
	r.save_states();await frames()
	FileAccess.open("res://qa/course-extra-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"screenshots":shots,"window_size":str(DisplayServer.window_get_size()),"viewport_size":str(root.get_visible_rect().size),"offscreen":DisplayServer.window_get_position().x<0,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"\t"))
