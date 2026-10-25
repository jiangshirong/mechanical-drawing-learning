extends RefCounted
const Canvas = preload("res://practice_canvas.gd")
var r
var h
var c
var b
var checks: Array = []

func check(name: String,value: bool,detail = null) -> void:
	checks.append({"check":name,"passed":value,"detail":detail})
	if not value: print("POINTS_FAILURE ",name," ",detail," doc=",b.document," selection=",b.selected," mode=",r.points_mode," tool=",b.tool," pending=",b.pending)

func local_mm(p: Array) -> Vector2:
	return b.view.pan+Canvas.at(p)*b.view.zoom

func click_mm(p: Array) -> void:
	await h.click(b.view.get_global_transform_with_canvas()*local_mm(p))

func button(node: Control) -> void:
	await h.click(node.get_global_transform_with_canvas()*(node.size*0.5))
	await h.wait_frames(4)

func type_name(value: String,submit := false) -> void:
	await button(b.name_field)
	for pressed in [true,false]:
		var e := InputEventKey.new()
		e.keycode = KEY_A
		e.ctrl_pressed = true
		e.pressed = pressed
		r.get_viewport().push_input(e,true)
	for i in range(value.length()):
		for pressed in [true,false]:
			var e := InputEventKey.new()
			e.unicode = value.unicode_at(i)
			e.pressed = pressed
			r.get_viewport().push_input(e,true)
	await h.wait_frames(3)
	if submit: await h.key(KEY_ENTER)

func wait_demo() -> void:
	var deadline := Time.get_ticks_msec()+12000
	while r.points_demo.busy and Time.get_ticks_msec() < deadline: await h.wait_frames(1)
	await h.wait_frames(3)

func snapshot(name: String) -> void:
	r.queue_redraw()
	b.canvas.queue_redraw()
	r.points_demo.space.request_render()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/points-"+name+".png")

func run(root,flag: String) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	c = load("res://canvas_check.gd").new()
	c.r = r
	c.h = h
	b = r.practice
	await h.wait_frames(18)
	check("startup_knowledge_map",r.map_active and not r.points_demo.active)
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	await h.choose(0)
	check("point_entry_observe",r.free_shell.visible and r.points_tabs.visible and not r.practice_shell.visible)
	if flag == "--qa-points-fresh-guide":
		r.points_step_id = ""
		await button(r.free_shell.find_child("Mode_concept",true,false))
		await wait_demo()
		check("concept_direct_entry",r.points_demo.active and r.points_demo.current_step==0)
		for i in range(4):
			await button(r.points_demo.next)
			await wait_demo()
		var d = r.points_demo
		check("first_concept_paper_fitted",absf(d.sheet.view.zoom-minf(d.sheet.view.size.x-32,d.sheet.view.size.y-32)/600)<0.01)
		await snapshot("fresh-concept")
		await button(d.leave)
		check("single_active_observe_tab",r.points_tabs.get_child(0).button_pressed and not r.points_tabs.get_child(1).button_pressed and not r.points_tabs.get_child(2).button_pressed)
		await button(r.free_shell.find_child("Mode_practice",true,false))
		await button(r.practice_shell.find_child("Teaching",true,false))
		await wait_demo()
		check("teacher_after_concept_resets_focus",not d.sheet.canvas.concept_focus and d.sheet.canvas.progress==0)
		await button(d.next)
		await h.wait_frames(12)
		check("animated_pen_visible",d.sheet.canvas.progress>0 and d.sheet.canvas.progress<3 and d.busy)
		await snapshot("moving-pen")
		await button(d.leave)
		finish("points-fresh-guide.json")
		return
	await button(r.free_shell.find_child("Mode_practice",true,false))
	check("practice_entry",r.practice_shell.visible and not r.free_shell.visible and not r.points_demo.active)
	check("practice_no_answer_no_3d",b.document.points.is_empty() if flag != "--qa-points-reopen" else true)
	if flag == "--qa-points-reopen":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/points-expected.json"))
		check("draft_reopened",b.document == expected.document)
		var state: Dictionary = b.view.get_view_state()
		check("view_reopened",is_equal_approx(state.zoom,expected.zoom) and state.center.distance_to(Vector2(expected.center[0.0],expected.center[1.0]))<0.1)
		check("undo_not_saved",b.undo_stack.is_empty() and b.redo_stack.is_empty())
		await button(r.practice_shell.find_child("Mode_concept",true,false))
		await wait_demo()
		check("concept_target_reopened",r.points_demo.current_step == 3 and is_equal_approx(r.points_demo.planes[1.0].rotation.x,PI/2))
		await button(r.points_demo.leave)
		check("reopen_returns_practice",r.practice_shell.visible)
		finish("points-reopen.json")
		return
	if flag == "--qa-points-corrupt":
		var original := FileAccess.get_file_as_string(b.save_path)
		check("corrupt_notice",b.blocked_save and b.error_label.visible and not b.error_text.is_empty())
		await click_mm([2.0,2.0])
		await click_mm([4.0,4.0])
		b.save_draft()
		check("corrupt_preserved",FileAccess.get_file_as_string(b.save_path)==original)
		check("corrupt_memory_edit_allowed",b.document.lines.size()==1)
		finish("points-corrupt.json")
		return
	check("empty_draft",b.document.lines.is_empty() and b.document.points.is_empty() and b.tool == "line")
	check("no_sliders",not c.contains_slider(r.practice_shell))
	var old: Dictionary = b.view.get_view_state()
	var minsize: float = minf(b.view.size.x,b.view.size.y)
	check("initial_30mm_coverage",60*Canvas.UNIT*b.view.zoom<=minsize+1)
	await click_mm([-8.2,3.1])
	check("first_click_preview",b.pending==[-8.0,3.0] and b.document.lines.is_empty())
	c.move(b.view,local_mm([11.3,3.8]),Vector2.ZERO)
	await h.wait_frames(2)
	check("direction_assist_horizontal",b.hover==[11.0,3.0],b.hover)
	check("measurement_two_axes_mm",b.measure==[11.0,3.0])
	await snapshot("drawing-distance")
	await click_mm([11.3,3.8])
	check("second_click_commits_line",b.document.lines.size()==1 and b.document.lines[0.0].a==[-8.0,3.0] and b.document.lines[0.0].b==[11.0,3.0])
	check("completed_no_preview",b.pending==null and b.measure==null)
	await click_mm([0.0,0.0])
	await click_mm([0.0,0.0])
	check("zero_length_discarded",b.document.lines.size()==1)
	await click_mm([1.0,1.0])
	c.mouse_button(b.view,local_mm([3.0,4.0]),MOUSE_BUTTON_RIGHT,true)
	c.mouse_button(b.view,local_mm([3.0,4.0]),MOUSE_BUTTON_RIGHT,false)
	await h.wait_frames(2)
	check("right_cancel",b.pending==null and b.document.lines.size()==1)
	await c.drag(b.view,local_mm([20.0,-20.0]),local_mm([20.0,-20.0])+Vector2(40,35),true)
	check("pan_return_no_line",b.pending==null and b.document.lines.size()==1)
	var pivot: Vector2 = b.view.size*0.5
	var before_world: Vector2 = (pivot-b.view.pan)/b.view.zoom
	await c.wheel(b.view,pivot,true,3)
	check("zoom_anchor",((pivot-b.view.pan)/b.view.zoom).distance_to(before_world)<0.001)
	await click_mm([-2.3,-4.6])
	check("vertical_start_snap",b.pending==[-2.0,-5.0],{"pending":b.pending,"pan":b.view.pan,"zoom":b.view.zoom})
	await click_mm([-2.8,8.0])
	check("vertical_snap_mm_after_zoom",b.document.lines[1.0].a==[-2.0,-5.0] and b.document.lines[1.0].b==[-2.0,8.0])
	await button(b.tools.point)
	await type_name("a′")
	await click_mm([0.0,0.0])
	check("mark_origin",b.document.points.get("a′")==[0.0,0.0])
	await click_mm([7.0,-6.0])
	check("same_name_moves",b.document.points.size()==1 and b.document.points["a′"]==[7.0,-6.0])
	await type_name("a")
	await click_mm([5.0,7.0])
	check("wrong_quadrant_allowed",b.document.points.a==[5.0,7.0])
	await button(b.tools.select)
	await click_mm([0.0,3.0])
	check("select_line_endpoints",b.selected.kind=="line" and b.selected.end=="a" and b.measure==[-8.0,3.0])
	var line_id: String = b.selected.id
	var history: int = b.undo_stack.size()
	await c.drag(b.view,local_mm([-8.0,3.0]),local_mm([-10.0,-8.0]))
	check("endpoint_drag",b.find_line(line_id).get("a")==[-10.0,-8.0] and b.find_line(line_id).get("b")==[11.0,3.0])
	check("drag_one_undo",b.undo_stack.size()==history+1)
	await button(b.tools.undo)
	check("undo_drag",b.find_line(line_id).get("a")==[-8.0,3.0])
	await button(b.tools.redo)
	check("redo_drag",b.find_line(line_id).get("a")==[-10.0,-8.0])
	await c.drag(b.view,local_mm([7.0,-6.0]),local_mm([-7.0,6.0]))
	check("named_point_drag",b.document.points["a′"]==[-7.0,6.0])
	await button(b.tools.delete)
	check("delete_student_point",not b.document.points.has("a′") and b.document.points.has("a"))
	await button(b.tools.undo)
	check("undo_delete",b.document.points.has("a′"))
	await button(b.tools.line)
	await click_mm([21.0,21.0])
	await click_mm([23.0,22.0])
	check("new_action_clears_redo",b.redo_stack.is_empty())
	var count: int = b.document.lines.size()
	await button(b.tools.select)
	await click_mm([22,21.5])
	var deletion_id: String = b.selected.id
	await button(b.tools.delete)
	check("delete_student_line",b.document.lines.size()==count-1 and b.find_line(deletion_id).is_empty())
	await button(b.tools.undo)
	check("undo_line_deletion",b.document.lines.size()==count and not b.find_line(deletion_id).is_empty())
	await click_mm([26.0,0.0])
	await button(b.tools.delete)
	check("axes_not_deletable",b.document.lines.size()==count and b.selected.kind.is_empty())
	var old_pan: Vector2 = b.view.pan
	await c.drag(b.view,b.view.size*Vector2(0.75,0.70),b.view.size*Vector2(0.75,0.70)+Vector2(30,20))
	check("empty_pan",b.view.pan.distance_to(old_pan+Vector2(30,20))<0.1)
	var start: Vector2 = b.view.size*Vector2(0.8,0.85)
	c.mouse_button(b.view,start,MOUSE_BUTTON_LEFT,true)
	c.move(b.view,start+Vector2(25,15),Vector2(25,15))
	await h.wait_frames(2)
	await c.wheel(b.view,start+Vector2(25,15),true)
	var rebased: Vector2 = b.view.pan
	c.move(b.view,start+Vector2(35,25),Vector2(10,10))
	c.mouse_button(b.view,start+Vector2(35,25),MOUSE_BUTTON_LEFT,false)
	await h.wait_frames(2)
	check("pan_zoom_continuous",b.view.pan.distance_to(rebased+Vector2(10,10))<0.1)
	check("pan_zoom_no_draw",b.document.lines.size()==count)
	# Four quadrants, zero distance, independent object editing and overlapping handles.
	await button(b.tools.point)
	await type_name("b″")
	await click_mm([-2.0,8.0])
	await button(b.tools.select)
	await click_mm([-2.0,8.0])
	check("overlap_named_point_priority",b.selected.kind=="point" and b.selected.id=="b″")
	await c.drag(b.view,local_mm([-2.0,8.0]),local_mm([0.0,8.0]))
	check("overlap_edit_only_object",b.document.points["b″"]==[0.0,8.0] and b.document.lines[1.0].b==[-2.0,8.0])
	check("zero_distance_measurement",b.measure==[0.0,8.0])
	await snapshot("practice")
	await button(b.tools.line)
	await click_mm([4.0,4.0])
	await button(r.practice_shell.find_child("Mode_observe",true,false))
	check("mode_switch_cancel_preview",b.pending==null and r.free_shell.visible,{"pending":b.pending,"free":r.free_shell.visible,"mode":r.points_mode})
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var picked: Array = r.data.parameters.points_mm.B
	r.select_feature("B",picked)
	await button(r.free_shell.find_child("Mode_practice",true,false))
	await button(b.tools.select)
	await click_mm([0.0,8.0])
	var draft: Dictionary = b.snapshot()
	await button(r.practice_shell.find_child("Teaching",true,false))
	var d = r.points_demo
	check("solution_fullscreen_shell",d.active and not r.free_shell.visible and not r.practice_shell.visible and not d.space.visible)
	check("solution_three_controls",d.find_children("*","BaseButton",true,false).filter(func(n): return n.is_visible_in_tree()).size()==3)
	check("animation_locks_nav",d.busy and d.previous.disabled and d.next.disabled and not d.leave.disabled)
	await button(d.next)
	check("busy_click_ignored",d.current_step==0)
	await wait_demo()
	check("solution_read_no_answers",d.sheet.canvas.progress==0)
	for i in range(1,9):
		await button(d.next)
		check("solution_busy_"+str(i),d.busy and d.next.disabled and d.previous.disabled)
		await wait_demo()
		check("solution_step_"+str(i),d.current_step==i and not d.busy)
		for item in d.sheet.canvas.primitives:
			if item.kind == "point" and item.order < d.sheet.canvas.progress: check("no_future_answer_"+str(i)+item.name,item.step<=i)
		if i in [3,8]: await snapshot("solution-"+str(i+1))
	var expected := {"a′":[-10.0,12.0],"a":[-10.0,-15.0],"a″":[15.0,12.0],"b′":[-15.0,20.0],"b":[-15.0,-5.0],"b″":[5.0,20.0]}
	var actual: Dictionary = {}
	for item in d.sheet.canvas.primitives:
		if item.kind == "point": actual[item.name] = item.p
	check("six_reference_points",actual == expected,actual)
	await button(d.previous)
	await wait_demo()
	check("solution_backward",d.current_step==7)
	await button(d.next)
	await wait_demo()
	check("solution_no_duplicate_objects",d.sheet.canvas.primitives.size()==22)
	await button(d.leave)
	check("teacher_draft_unchanged",b.document==draft.document and b.selected==draft.selected and b.view.get_view_state()==draft.view)
	check("teacher_observation_unchanged",r.observer.get_state()==camera and r.observer.picked_world==picked)
	await button(r.practice_shell.find_child("Teaching",true,false))
	check("teacher_restarts",d.current_step==0)
	await button(d.leave)
	check("teacher_mid_animation_exit",not d.active and r.practice_shell.visible and b.document==draft.document)
	await button(r.practice_shell.find_child("Mode_concept",true,false))
	await wait_demo()
	check("concept_scene_reuses_glb",d.space.model!=null and d.builds==1)
	var mesh_count: int = d.scene.get_child_count()
	for i in range(1,5):
		await button(d.next)
		check("concept_busy_"+str(i),d.busy and d.previous.disabled and d.next.disabled)
		var before: Dictionary = d.space.get_state()
		await c.drag(d.space,d.space.size*0.5,d.space.size*0.5+Vector2(40,30))
		check("concept_drag_disabled_"+str(i),not d.space.interaction_enabled and not d.space.dragging)
		await wait_demo()
		check("concept_step_"+str(i),d.current_step==i and not d.busy)
		check("persistent_concept_nodes_"+str(i),d.scene.get_child_count()==mesh_count and d.builds==1)
		if i in [1,3,4]: await snapshot("concept-"+str(i+1))
	check("continuous_plane_unfold",is_equal_approx(d.planes[1.0].rotation.x,PI/2) and is_equal_approx(d.planes[2.0].rotation.y,PI/2))
	await button(d.previous)
	await wait_demo()
	await button(d.previous)
	await wait_demo()
	check("reverse_unfold",d.concept_value.z==0 and is_zero_approx(d.planes[1.0].rotation.x))
	await button(d.next)
	await h.wait_frames(5)
	await button(d.leave)
	check("concept_exit_mid_unfold",not d.active and r.practice_shell.visible and b.document==draft.document)
	check("concept_did_not_change_observation",r.observer.get_state()==camera and r.observer.picked_world==picked)
	await button(r.practice_shell.find_child("Mode_concept",true,false))
	await wait_demo()
	check("concept_resumes_target",d.current_step==3 and is_equal_approx(d.planes[1.0].rotation.x,PI/2))
	check("concept_no_rebuild",d.builds==1)
	await button(d.leave)
	# Small-window layout and mm hit precision use real window resizing, without native fullscreen.
	DisplayServer.window_set_size(Vector2i(1060,720))
	await h.wait_frames(15)
	await snapshot("minimum-window")
	await button(b.tools.point)
	await type_name("a″")
	await click_mm([-11.0,-12.0])
	check("minimum_window_hit_mm",b.document.points["a″"]==[-11.0,-12.0])
	DisplayServer.window_set_size(Vector2i(1440,900))
	await h.wait_frames(15)
	for i in range(1,r.catalog.size()):
		await h.choose(i)
		check("other_chapter_no_empty_pages_"+str(i),not r.points_tabs.visible and not r.practice_shell.visible and r.free_shell.visible)
	await h.choose(0)
	check("chapter_return_observe",r.free_shell.visible and not r.practice_shell.visible)
	await button(r.free_shell.find_child("Mode_practice",true,false))
	check("chapter_return_retains_draft",b.document.lines.size()==count and b.document.points.has("a″"))
	b.save_draft()
	var final_view: Dictionary = b.view.get_view_state()
	FileAccess.open("res://qa/points-expected.json",FileAccess.WRITE).store_string(JSON.stringify({"document":b.document,"zoom":final_view.zoom,"center":[final_view.center.x,final_view.center.y]}))
	r.save_states()
	finish("points-learning-check.json")

func finish(filename: String) -> void:
	FileAccess.open("res://qa/"+filename,FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	print("POINTS_CHECKS ",checks.size())
