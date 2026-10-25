extends RefCounted
var r
var h
var checks:Array=[]
func check(name:String,value:bool) -> void:
	checks.append({"check":name,"passed":value})
	if not value:push_warning("NAVIGATION_DEV "+name)
func frames(n:=3) -> void:await h.frames(n)
func keys(codes:Array,ctrl:=false,echo:=false) -> void:
	for code in codes:await h.key(code,ctrl,echo)
func picture(name:String) -> void:
	await frames(4);r.queue_redraw();await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/navigation-dev-"+name+".png")
func nav_checks(row:HBoxContainer,name:String,lecture:=true) -> void:
	check(name+"_count",row.get_child_count()==(4 if lecture else 3))
	var labels:Array=["知识图谱","观察","题目","讲解"]
	for i in range(row.get_child_count()):
		var button:Button=row.get_child(i)
		check(name+"_text_"+str(i),button.text==labels[i])
		check(name+"_icon_"+str(i),button.icon!=null and button.icon.get_size()==Vector2(20,20))
		check(name+"_icon_room_"+str(i),not button.expand_icon and button.get_combined_minimum_size().x>=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x+28)
		check(name+"_bounds_"+str(i),r.get_global_rect().encloses(button.get_global_rect()))
	check(name+"_current",row.get_node("Nav_lessons").button_pressed)
func run(root) -> void:
	r=root;h=load("res://line_practice_check.gd").new();h.r=r
	var suffix:="minimum" if "--qa-lessons-minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720));await frames(6)
	check("developer_default_off",not r.developer_mode and r.developer_buttons.all(func(b):return not b.visible))
	r.open_map_example("points");await frames()
	var tabs=r.points_tabs
	check("point_header_names",tabs.get_child(1).text=="题目" and tabs.get_child(2).text=="讲解")
	check("point_header_icons",tabs.get_children().all(func(b):return b.icon!=null) and r.free_shell.find_child("MapEntry",true,false).icon!=null)
	await keys([KEY_Q,KEY_W,KEY_E,KEY_R]);check("outside_map_no_unlock",not r.developer_mode)
	await h.click(tabs.get_node("Mode_lessons"));await frames()
	var menu=r.chapter_lessons;var row:HBoxContainer=menu.column.get_child(0)
	nav_checks(row,"point")
	var item:Button=menu.buttons[0]
	await h.click(row.get_node("Nav_lessons"));check("point_current_stays",menu.visible and menu.buttons[0]==item and not r.points_demo.active)
	await picture("point-list-"+suffix)
	await h.click(row.get_node("Nav_concept"));await frames();check("point_lecture_works",r.points_demo.active and r.points_demo.kind=="concept")
	r.points_demo.exit();await frames();check("point_lecture_returns",menu.visible)
	await h.click(menu.column.get_child(0).get_node("Nav_map"));await frames()
	await keys([KEY_Q,KEY_W,KEY_R]);check("wrong_sequence",not r.developer_mode)
	await keys([KEY_Q,KEY_W,KEY_E,KEY_R],true);check("combination_ignored",not r.developer_mode)
	await keys([KEY_Q],false,true);await keys([KEY_W,KEY_E,KEY_R]);check("repeat_ignored",not r.developer_mode)
	await keys([KEY_Q,KEY_W]);r.open_map_example("points");r.show_knowledge_map();await keys([KEY_E,KEY_R]);check("leaving_map_resets",not r.developer_mode)
	await keys([KEY_Q,KEY_W,KEY_E,KEY_R]);check("map_unlock",r.developer_mode and r.developer_buttons.all(func(b):return b.visible))
	r.open_map_example("points");await frames()
	await picture("developer-observe-"+suffix)
	for id in ["SourceButton","AnswerButton"]:
		var b:Button=r.free_shell.find_child(id,true,false)
		check("developer_visible_"+id,b.is_visible_in_tree())
		await h.click(b);await frames();check("developer_source_opens_"+id,r.source_window.visible and r.source_image.texture!=null);r.hide_source()
	r.open_map_example("line");await frames()
	check("line_header_names",r.line_tabs.get_child(1).text=="题目" and r.line_tabs.get_child(2).text=="讲解")
	check("line_header_icons",r.line_tabs.get_children().all(func(b):return b.icon!=null))
	await h.click(r.line_tabs.get_node("LineMode_lessons"));await frames()
	row=r.line_workspace.lesson_list.get_child(0);nav_checks(row,"line")
	await h.click(row.get_node("Nav_lessons"));check("line_current_stays",r.line_workspace.visible and not r.line_solution.active)
	await picture("line-list-"+suffix)
	await h.click(row.get_node("Nav_concept"));await frames();check("line_lecture_works",r.line_demo.active)
	r.line_demo.exit();await frames();check("line_lecture_returns",r.line_workspace.visible)
	await h.click(row.get_node("Nav_map"));await frames();r.open_map_example("section");await frames()
	check("section_header",r.guide_button.text=="题目" and r.guide_button.icon!=null)
	await h.click(r.guide_button);await frames();nav_checks(menu.column.get_child(0),"section",false)
	await picture("section-list-"+suffix)
	await h.click(menu.column.get_child(0).get_node("Nav_map"));await frames();r.open_map_example("plane");await frames()
	check("developer_kept_across_chapters",r.developer_mode and r.free_shell.find_child("SourceButton",true,false).is_visible_in_tree())
	check("developer_not_saved",r.states.values().all(func(s):return not s.has("developer_mode")))
	check("qa_only",r.save_path=="user://qa-chapter-lessons-observation.json")
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	var f:=FileAccess.open("res://qa/navigation-dev-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	print("NAVIGATION_DEV ",checks.size()," checks")
