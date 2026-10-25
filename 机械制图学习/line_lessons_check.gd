extends RefCounted
var r
var h
var checks:Array=[]
func check(name:String,value:bool) -> void:
	checks.append({"check":name,"passed":value})
	if not value:push_warning("LINE_LESSONS "+name)
func frames(n:=3) -> void:await h.frames(n)
func picture(name:String) -> void:
	await frames(4);r.queue_redraw();await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/line-lessons-"+name+".png")
func run(root) -> void:
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	var suffix:="minimum" if "--qa-lessons-minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720));await frames(6)
	r.open_map_example("line");await frames(4)
	var w=r.line_workspace;var d=r.line_solution
	var camera:Dictionary=r.observer.get_state();var marker:String=r.selected
	var saved:Dictionary={}
	for task in w.config.tasks:
		var path:String="user://qa-line-task-"+task.id+".json"
		saved[path]=FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	check("no_practice_entry",r.line_tabs.find_child("LineMode_practice",true,false)==null)
	await h.click(r.line_tabs.get_node("LineMode_lessons"));await frames()
	check("list_entry",w.visible and w.lesson_list.visible and not w.practice_content.visible and not r.free_shell.visible)
	check("seven_tasks",w.lesson_buttons.size()==7)
	check("draft_not_loaded",w.board.task.is_empty())
	for button in w.lesson_buttons:check("list_bounds_"+button.name,r.get_global_rect().encloses(button.get_global_rect()))
	await picture("list-"+suffix)
	for i in range(w.lesson_buttons.size()):
		await h.click(w.lesson_buttons[i]);await frames()
		check("chosen_"+str(i),d.active and d.task.id==w.config.tasks[i].id and d.current_beat==0 and not w.visible)
		check("no_student_board_"+str(i),not w.board.is_visible_in_tree() and d.sheet.readonly)
		for j in range(d.beats.size()):
			check("beat_"+str(i)+"_"+str(j),d.current_beat==j)
			await h.key(KEY_D)
			if d.phase=="ready":await h.key(KEY_D);await h.key(KEY_D)
			check("result_"+str(i)+"_"+str(j),is_equal_approx(d.sheet.canvas.progress,d.after_states[j]))
			if j<d.beats.size()-1:await h.key(KEY_D)
		check("final_"+str(i),d.phase=="complete" and d.next.disabled)
		d.exit();await frames()
		check("return_to_list_"+str(i),w.visible and w.lesson_list.visible and not w.practice_content.visible)
		await h.click(w.lesson_buttons[i]);await frames();check("restart_from_first_"+str(i),d.current_beat==0)
		d.exit();await frames()
	check("observation_kept",r.observer.get_state()==camera and r.selected==marker)
	for path in saved:
		check("draft_kept_"+path,FileAccess.get_file_as_string(path)==saved[path] if saved[path]!=null else not FileAccess.file_exists(path))
	await h.click(w.lesson_list.get_child(0).get_node("Nav_concept"));await frames()
	check("knowledge_entry_from_list",r.line_demo.active and not w.visible)
	r.line_demo.exit();await frames();check("knowledge_returns_to_list",w.visible and w.lesson_list.visible)
	await h.click(w.lesson_list.get_child(0).get_child(1));await frames()
	check("return_observe",r.free_shell.visible and not w.visible and r.observer.interaction_enabled and r.paper.picking_enabled)
	await h.click(r.line_tabs.get_node("LineMode_lessons"));await frames()
	await h.click(w.lesson_list.get_child(0).get_child(0));await frames()
	check("return_map",r.map_active and not w.visible)
	check("isolated",r.save_path=="user://qa-line-practice-observation.json")
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	var file:=FileAccess.open("res://qa/line-lessons-"+suffix+".json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	print("LINE_LESSONS ",checks.size()," checks")
