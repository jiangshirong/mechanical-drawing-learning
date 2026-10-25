extends RefCounted
var r
var h
var checks:Array=[]
func check(name:String,value:bool) -> void:
	checks.append({"check":name,"passed":value})
	if not value:push_warning("CHAPTER_LESSONS "+name)
func frames(n:=3) -> void:await h.frames(n)
func picture(name:String) -> void:
	await frames(4);r.queue_redraw();await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/chapter-lessons-"+name+".png")
func run(root) -> void:
	if "--qa-navigation-dev" in OS.get_cmdline_user_args():
		await load("res://navigation_dev_check.gd").new().run(root);return
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	var suffix:="minimum" if "--qa-lessons-minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720));await frames(6)
	check("qa_save",r.save_path=="user://qa-chapter-lessons-observation.json" and r.practice.save_path=="user://qa-chapter-lessons-practice.json")
	check("offscreen",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	r.open_map_example("points");await frames(6)
	var camera:Dictionary=r.observer.get_state();var doc:Dictionary=r.practice.document.duplicate(true);var selection:Array=r.practice.selection.duplicate(true)
	check("point_no_practice_tab",r.points_tabs.find_child("Mode_practice",true,false)==null)
	await h.click(r.points_tabs.get_node("Mode_lessons"));await frames()
	var menu=r.chapter_lessons
	check("point_list",menu.visible and menu.buttons.size()==1 and not r.practice_shell.visible and not r.free_shell.visible)
	check("point_bounds",r.get_global_rect().encloses(menu.buttons[0].get_global_rect()))
	await picture("points-list-"+suffix)
	await h.click(menu.buttons[0]);await frames()
	var demo=r.points_demo
	check("point_start",demo.active and demo.kind=="solution" and demo.current_beat==0 and not menu.visible)
	for i in range(demo.beats.size()):
		check("point_beat_"+str(i),demo.current_beat==i)
		await h.key(KEY_D)
		if demo.phase=="ready":await h.key(KEY_D);await h.key(KEY_D)
		if i<demo.beats.size()-1:await h.key(KEY_D)
	check("point_finished",demo.phase=="complete")
	demo.exit();await frames()
	check("point_returns_list",menu.visible and not r.practice_shell.visible and not r.free_shell.visible)
	await h.click(menu.buttons[0]);await frames();check("point_restart",demo.current_beat==0)
	demo.exit();await frames()
	await h.click(menu.column.get_child(0).get_node("Nav_concept"));await frames()
	check("point_knowledge",demo.active and demo.kind=="concept")
	demo.exit();await frames();check("point_knowledge_returns_list",menu.visible and not r.free_shell.visible)
	check("point_draft_preserved",r.practice.document==doc and r.practice.selection==selection)
	await h.click(menu.column.get_child(0).get_child(1));await frames()
	check("point_observation_preserved",r.free_shell.visible and r.observer.get_state()==camera and not menu.visible)
	r.open_map_example("section");await frames(6)
	camera=r.observer.get_state();var marker:String=r.selected;var section:bool=r.section_enabled
	check("section_named_entry",r.guide_button.visible and r.guide_button.text=="题目")
	await h.click(r.guide_button);await frames()
	check("section_list",menu.visible and menu.buttons.size()==1 and not r.free_shell.visible)
	await picture("section-list-"+suffix)
	await h.click(menu.buttons[0]);await frames()
	check("section_start",r.guide.active and r.guide.current_step==0 and not menu.visible)
	for i in range(r.data.guide.steps.size()):
		while r.guide.busy:await frames(1)
		check("section_step_"+str(i),r.guide.current_step==i)
		if i<r.data.guide.steps.size()-1:await h.click(r.guide_next)
	r.guide.exit();await frames()
	check("section_returns_list",menu.visible and not r.free_shell.visible)
	await h.click(menu.buttons[0]);await frames();check("section_restart",r.guide.current_step==0)
	r.guide.exit();await frames()
	check("section_observation_preserved",r.observer.get_state()==camera and r.selected==marker and r.section_enabled==section)
	await h.click(menu.column.get_child(0).get_child(0));await frames();check("section_map",r.map_active and not menu.visible)
	for id in ["slope","base","bracket"]:
		r.open_map_example(id);await frames()
		check("observe_only_"+id,not r.points_tabs.visible and not r.line_tabs.visible and not r.guide_button.visible and not menu.visible and r.free_shell.visible)
	r.open_map_example("line");await frames()
	await h.click(r.line_tabs.get_node("LineMode_lessons"));await frames()
	check("line_list_kept",r.line_workspace.visible and r.line_workspace.lesson_buttons.size()==7 and not menu.visible)
	await h.click(r.line_workspace.lesson_buttons[0]);await frames();check("line_teaching_kept",r.line_solution.active)
	r.line_solution.exit();await frames();check("line_returns_list",r.line_workspace.visible)
	await h.click(r.line_workspace.lesson_list.get_child(0).get_child(0));await frames();check("line_map",r.map_active)
	var f:=FileAccess.open("res://qa/chapter-lessons-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	print("CHAPTER_LESSONS ",checks.size()," checks")
