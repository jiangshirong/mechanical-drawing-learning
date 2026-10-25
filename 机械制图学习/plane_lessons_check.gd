extends RefCounted
var r
var h
var checks:Array=[]
var suffix:="normal"
func check(name:String,value:bool)->void:
	checks.append({"check":name,"passed":value})
	if not value:push_warning("PLANE_QA "+name)
func frames(n:=3)->void:await h.frames(n)
func picture(name:String)->void:
	await frames(4);r.queue_redraw();await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/plane-"+name+"-"+suffix+".png")
func settle(d)->void:
	if d.phase in ["typing","playing"]:await h.key(KEY_D)
	if d.phase=="ready":await h.click(d.next);await frames(2);await h.key(KEY_D)
	await frames(3)
func coplanar(points:Dictionary,verts:Array)->bool:
	var a:=Vector3(points[verts[0]][0],points[verts[0]][1],points[verts[0]][2]);var b:=Vector3(points[verts[1]][0],points[verts[1]][1],points[verts[1]][2]);var c:=Vector3(points[verts[-1]][0],points[verts[-1]][1],points[verts[-1]][2]);var normal:=(b-a).cross(c-a).normalized()
	for p in points.values():
		if absf(normal.dot(Vector3(p[0],p[1],p[2])-a))>.001:return false
	return true
func run(root,flag:String)->void:
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	suffix="minimum" if "--qa-plane-minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720));await frames(6)
	r.open_map_example("plane");await frames(6)
	check("isolated",r.save_path=="user://qa-plane-observation.json" and r.practice.save_path=="user://qa-plane-practice.json")
	check("offscreen",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	var camera:Dictionary=r.observer.get_state();var draft:Dictionary=r.practice.document.duplicate(true);var marker:String=r.selected
	if flag=="--qa-plane-reopen":
		var saved:String=r.plane_step_id;r.plane_demo.enter();await frames(6)
		check("selected_task_resume",r.plane_questions.current_task==7)
		var expected:String=r.plane_demo.lesson.get("knowledge_resume_aliases",{}).get(saved,saved)
		check("resume_id",r.plane_demo.beats[r.plane_demo.current_beat].id==expected)
		check("resume_before",is_equal_approx(r.plane_demo.sheet.canvas.progress,r.plane_demo.before_states[r.plane_demo.current_beat]) or r.plane_demo.preparing)
		r.plane_demo.exit();r.plane_step_id="invalid";r.plane_demo.enter();await frames();check("invalid_first",r.plane_demo.current_beat==0);r.plane_demo.exit();finish("plane-reopen.json");return
	await h.click(r.plane_tabs.get_node("PlaneMode_lessons"));await frames()
	var menu=r.plane_questions;check("eight_tasks",menu.visible and menu.lesson_buttons.size()==8)
	var nav:HBoxContainer=menu.get_child(0).get_child(0)
	check("four_nav",nav.get_child_count()==4 and nav.get_node("Nav_lessons").button_pressed)
	await h.click(nav.get_node("Nav_lessons"));check("current_stays",menu.visible)
	for button in menu.lesson_buttons:check("list_bounds_"+button.name,r.get_global_rect().encloses(button.get_global_rect()))
	await picture("list")
	for i in range(8):
		await h.click(menu.lesson_buttons[i]);await frames(6)
		var d=r.plane_solution;check("task_start_"+str(i),d.active and not d.space.visible and d.current_beat==0 and not menu.visible)
		check("problem_concurrent_"+str(i),d.preparing and d.phase=="typing")
		for j in range(d.beats.size()):
			check("order_%d_%d"%[i,j],d.current_beat==j)
			if j==1:
				await h.key(KEY_D,true);await h.key(KEY_D,false,true);check("filtered_%d"%i,d.current_beat==j and d.phase=="typing")
				var e:=InputEventKey.new();e.keycode=KEY_D;e.physical_keycode=KEY_D;e.pressed=true;r.get_viewport().push_input(e,true);await frames()
				r.get_viewport().push_input(e,true);await frames();check("held_no_repeat_%d"%i,d.current_beat==j and d.phase!="typing");e.pressed=false;r.get_viewport().push_input(e,true);await frames()
			await settle(d)
			check("settled_%d_%d"%[i,j],d.phase in ["settled","complete"] and is_equal_approx(d.sheet.canvas.progress,d.after_states[j]))
			check("card_bounds_%d_%d"%[i,j],r.get_global_rect().encloses(d.overlay.panel.get_global_rect()))
			if j==0 or j==d.beats.size()-1:await picture("task%d-step%d"%[i,j])
			if i==0 and j==0:
				var label:RichTextLabel=d.overlay.label
				# Offscreen events cannot replace the native cursor sampled by drag timers.
				# Verify native hit-tested selection and copying without touching that cursor.
				for x in range(8,140,12):
					var atp:Vector2=label.global_position+Vector2(x,18)
					for pressed in [true,false]:
						var e:=InputEventMouseButton.new();e.position=atp;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.double_click=pressed;r.get_viewport().push_input(e,true);await frames(2)
					if not label.get_selected_text().is_empty():break
				check("native_mouse_selection",not label.get_selected_text().is_empty())
				var clipboard:String=DisplayServer.clipboard_get();await h.key(KEY_C,true);check("native_copy",DisplayServer.clipboard_get()==label.get_selected_text());DisplayServer.clipboard_set(clipboard);label.deselect()
				await h.click(d.question.button);await frames();check("question_statement",d.question.label.text==d.task.statement and d.question.panel.visible);d.question.reset()
			if d.beats[j].action.type=="project_points":
				d.apply_state(d.before_states[j]+.45);await frames();check("guides_%d_%d"%[i,j],not d.sheet.canvas.transfer_segments.is_empty());d.apply_state(d.after_states[j]);await frames();check("guides_removed_%d_%d"%[i,j],d.sheet.canvas.transfer_segments.values().all(func(x):return x.is_empty()))
			if j<d.beats.size()-1:await h.click(d.next)
		check("last_disabled_"+str(i),d.phase=="complete" and d.next.disabled)
		await h.key(KEY_A);check("back_"+str(i),d.current_beat==d.beats.size()-2 and d.phase=="typing")
		await h.click(d.progress.nodes[0]);await frames();check("jump_"+str(i),d.current_beat==0)
		d.exit();await frames();check("exit_list_"+str(i),menu.visible and not d.active)
		await h.click(menu.lesson_buttons[i]);await frames();check("restart_"+str(i),d.current_beat==0);d.exit()
	await h.click(nav.get_node("Nav_concept"));await frames(8)
	var d=r.plane_demo;check("lecture_columns",d.active and d.space.visible and d.groups.size()==4)
	d.current_beat=0;d.prepare();await frames(6)
	# Natural typing and action use the actual timer; no fabricated elapsed time.
	await r.get_tree().create_timer(d.beats[0].text.length()/16.0+1.0).timeout;check("natural_typing",d.phase=="settled")
	await h.key(KEY_D);await h.key(KEY_D);check("next_real_ready",d.phase=="ready")
	await h.key(KEY_D)
	var natural_deadline:=Time.get_ticks_msec()+int((float(d.beats[d.current_beat].action.get("duration",1.1))+2.0)*1000)
	while d.phase=="playing" and Time.get_ticks_msec()<natural_deadline:await frames(1)
	if d.phase!="settled":print("PLANE_NATURAL_DIAGNOSTIC ",d.current_beat," ",d.beats[d.current_beat]," phase=",d.phase," progress=",d.sheet.canvas.progress)
	check("natural_animation",d.phase=="settled")
	d.current_beat=0;d.prepare();await frames()
	for j in range(d.beats.size()):
		check("concept_order_"+str(j),d.current_beat==j)
		if d.beats[j].action.type=="prepare":
			for t in [.1,.3,.5,.7,.9]:d.apply_state(t);check("coplanar_%d_%s"%[j,t],coplanar(d.task.points,d.task.vertices))
			d.apply_state(d.before_states[j])
		await settle(d);check("concept_stable_"+str(j),d.phase in ["settled","complete"])
		if d.beats[j].id=="in-point:level":
			check("known_method_continuous",d.beats[j].action.type=="sequence" and d.beats[j].action.actions.size()==4)
			check("space_auxiliary_sync",d.spatial.interior_segments.any(func(x):return x[0]=="M" and x[1]=="N"))
		var box:Rect2=d.overlay.panel.get_global_rect()
		if box.intersects(d.space.get_global_rect()):
			for item in d.spatial.names:
				if not d.spatial.offsets.has(item[0]):continue
				var pos:Vector2=d.space.global_position+d.spatial.screen(item[2])+d.spatial.offsets[item[0]]
				var width:float=d.get_theme_default_font().get_string_size(item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
				check("space_copy_label_%d"%j,not box.intersects(Rect2(pos-Vector2(3,20),Vector2(width+6,25))))
		if box.intersects(d.sheet.view.get_global_rect()):
			var tr:Transform2D=d.sheet.canvas.get_global_transform_with_canvas()
			for label_rect in d.sheet.canvas.student_label_rects:
				check("concept_copy_label_%d"%j,not box.intersects(Rect2(tr*label_rect.position,label_rect.size*d.sheet.view.zoom)))
			for segment in d.protected_lines(Vector2.ZERO):check("concept_copy_ink_%d"%j,not d.overlay.segment_hits(box,segment[0],segment[1]))
		if j in [0,3,11,19,30,32,35]:await picture("concept"+str(j))
		if j==3:
			var rect:Rect2=d.overlay.panel.get_global_rect();var pos:Vector2=d.space.get_global_rect().get_center();var yaw:float=d.space.yaw
			var down:=InputEventMouseButton.new();down.position=pos;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;r.get_viewport().push_input(down,true);await frames()
			var move:=InputEventMouseMotion.new();move.position=pos+Vector2(55,20);move.relative=Vector2(55,20);move.button_mask=MOUSE_BUTTON_MASK_LEFT;r.get_viewport().push_input(move,true);await frames()
			down.pressed=false;down.position=move.position;r.get_viewport().push_input(down,true);await frames()
			check("rotation",not is_equal_approx(yaw,d.space.yaw));check("copy_stable",d.overlay.panel.get_global_rect()==rect)
		if j<d.beats.size()-1:
			await h.key(KEY_D)
			if j==3:check("camera_reset",is_equal_approx(d.space.yaw,-.48) and is_equal_approx(d.space.pitch,.38))
	check("lecture_last",d.phase=="complete" and d.next.disabled)
	var nodes:int=d.space.world.get_child_count();d.exit();r.plane_demo.enter();await frames();check("no_node_growth",d.space.world.get_child_count()==nodes);d.exit()
	for phase_name in ["typing","playing","settled"]:
		r.plane_solution.enter(menu.config.tasks[0]);await frames();var exiting=r.plane_solution
		if phase_name!="typing":await settle(exiting)
		if phase_name=="playing":await h.key(KEY_D);await h.key(KEY_D);await h.key(KEY_D)
		check("exit_phase_"+phase_name,exiting.phase==phase_name);var captured:int=exiting.epoch;exiting.exit();await r.get_tree().create_timer(.12).timeout;check("cancelled_"+phase_name,not exiting.active and exiting.epoch>captured and exiting.phase=="idle")
	await h.click(nav.get_node("Nav_observe"));check("observer_restore",r.observer.get_state()==camera and r.selected==marker and r.free_shell.visible)
	check("draft_safe",r.practice.document==draft)
	# Save a stable ordinary target for a separate process to reopen.
	r.plane_step_id="in-point:intersections";r.save_states()
	finish("plane-"+suffix+".json")
func finish(name:String)->void:
	var f:=FileAccess.open("res://qa/"+name,FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close();print("PLANE_QA ",checks.size()," checks")

