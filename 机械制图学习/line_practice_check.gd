extends RefCounted
var r
var b
var d
var checks:Array=[]
var suffix:="normal"
func check(name:String,value:bool,detail=null) -> void:
	checks.append({"check":name,"passed":value,"detail":detail})
	if not value:push_warning("LINE_PRACTICE_QA "+name+" "+str(detail))
func frames(n:=3) -> void:
	for i in range(n):await r.get_tree().process_frame
func click_at(p:Vector2) -> void:
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.position=p;r.get_viewport().push_input(e,true);await frames(1)
func click(node:Control) -> void:await click_at(node.get_global_rect().get_center())
func key(code:int,ctrl:=false,echo:=false) -> void:
	for pressed in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;e.ctrl_pressed=ctrl;e.echo=echo;r.get_viewport().push_input(e,true);await frames(1)
func at(p:Array) -> Vector2:return b.canvas.get_global_transform_with_canvas()*b.canvas.at(p)
func picture(name:String) -> void:
	await frames(4);r.queue_redraw();b.canvas.queue_redraw()
	if d.active:d.overlay.queue_redraw();d.sheet.canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/line-practice-"+name+"-"+suffix+".png")
func wait_seconds(seconds:float) -> void:await r.get_tree().create_timer(seconds).timeout
func vector(p:Array) -> Vector3:return Vector3(p[0],p[1],p[2])

func run(root,flag:String) -> void:
	if "--qa-line-lessons" in OS.get_cmdline_user_args():
		await load("res://line_lessons_check.gd").new().run(root);return
	r=root;suffix="minimum" if "--qa-line-practice-minimum" in OS.get_cmdline_user_args() else "normal"
	if suffix=="minimum":DisplayServer.window_set_size(Vector2i(1060,720));await frames(6)
	r.open_map_example("line");await frames(4)
	await click(r.line_tabs.get_node("LineMode_practice"));await frames(6)
	b=r.line_workspace.board;d=r.line_solution
	check("real_practice_entry",r.line_workspace.visible and not r.free_shell.visible)
	check("seven_tasks",r.line_workspace.config.tasks.size()==7)
	if flag=="--qa-line-practice-reopen":
		for i in range(7):
			r.line_workspace.choose(i);await frames()
			check("reopen_"+b.task.id,b.document.lines.size()>0 and b.document.points.size()>0)
		finish("line-practice-reopen.json");return
	var asset_camera:Dictionary=r.observer.get_state();var user_selection:String=r.selected
	for i in range(7):
		r.line_workspace.choose(i);await frames(5)
		print("LINE_PRACTICE_TASK ",i)
		# Start this QA document without touching any production file.
		b.document={"lines":[],"points":{}};b.undo_stack.clear();b.clear_selection();b.blocked_save=false
		var t:Dictionary=b.task;var known_before:Dictionary=t.duplicate(true)
		check(t.id+"_isolated",b.save_path.begins_with("user://qa-line-task-"))
		# A click on a known point may start a stroke, but must not edit the known graph.
		if not t.known_points.is_empty():
			await key(KEY_P);await click_at(at(t.refs[t.known_points[0]]));await key(KEY_D)
			check(t.id+"_known_immutable",t==known_before)
		# Complete a reference construction with internal input only. Final student
		# coordinates are verified independently from teaching playback state.
		b.document={"lines":[],"points":{}};b.clear_selection();b.undo_stack.clear();await key(KEY_L)
		var expected_lines:Array=[];var expected_points:Array=[]
		for group in t.groups:
			for beat in group.beats:
				var a:Dictionary=beat.action
				if a.type=="line":expected_lines.append(a)
				elif a.type=="point":expected_points.append(a)
				elif a.type=="side_point":
					expected_points.append({"p":a.side})
					for ends in [[a.front,a.height],[a.top,a.diagonal],[a.diagonal,a.side]]:expected_lines.append({"a":ends[0],"b":ends[1]})
		# Constructing exact endpoints by helper is separately exercised below;
		# here use normal point/line event paths at visible geometry coordinates.
		for a in expected_lines:
			await click_at(at(t.refs[a.a]));await click_at(at(t.refs[a.b]));b.cancel_pending()
		await key(KEY_P)
		if expected_points.is_empty():expected_points.append({"p":"T_front"})
		for a in expected_points:await click_at(at(t.refs[a.p]))
		check(t.id+"_student_lines",b.document.lines.size()>0)
		check(t.id+"_student_points",b.document.points.size()>0)
		b.save_draft();check(t.id+"_file",FileAccess.file_exists(b.save_path))
		await picture(t.id+"-draft")
		var snapshot:Dictionary=b.snapshot();var hash:String=FileAccess.get_file_as_string(b.save_path).sha256_text()
		d.enter(t);await frames(6)
		check(t.id+"_teaching_entry",d.active and d.sheet.visible and not r.line_workspace.visible)
		var count:int=d.get_child_count()
		for item in d.sheet.canvas.primitives:
			if item.kind=="transfer":await transfer_check(item)
		d.current_beat=0;d.prepare();await frames()
		for j in range(d.beats.size()):
			check(t.id+"_beat_"+str(j),d.current_beat==j)
			check(t.id+"_before_"+str(j),is_equal_approx(d.sheet.canvas.progress,d.before_states[j]) or (j==0 and d.preparing))
			await key(KEY_D)
			check(t.id+"_written_"+str(j),d.overlay.label.visible_characters==-1 or d.overlay.label.visible_characters==d.overlay.label.text.length())
			var o=d.overlay
			check(t.id+"_copy_bounds_"+str(j),o.content_rect.encloses(o.box_rect))
			check(t.id+"_copy_labels_"+str(j),o.protected.all(func(rect):return not rect.intersects(o.box_rect)))
			check(t.id+"_copy_ink_"+str(j),o.protected_segments.all(func(s):return not o.segment_hits(o.box_rect,s[0],s[1])))
			if d.phase=="ready":
				await click(d.next);check(t.id+"_playing_"+str(j),d.phase=="playing")
				await key(KEY_D)
			check(t.id+"_after_"+str(j),is_equal_approx(d.sheet.canvas.progress,d.after_states[j]))
			var pos:int=d.current_beat;await key(KEY_D,false,true);check(t.id+"_repeat_"+str(j),pos==d.current_beat)
			if j==0:await picture(t.id+"-question")
			if j<d.beats.size()-1:await click(d.next)
		check(t.id+"_last_disabled",d.next.disabled and d.phase=="complete")
		check(t.id+"_pooled",d.get_child_count()==count)
		await picture(t.id+"-result")
		await key(KEY_A);check(t.id+"_retreat",d.current_beat==d.beats.size()-2 and d.phase=="typing")
		await click(d.progress.nodes[0]);check(t.id+"_jump",d.current_beat==0)
		d.exit();await frames(5)
		check(t.id+"_draft_kept",b.document==snapshot.document and b.selection==snapshot.selection and b.view.get_view_state()==snapshot.view)
		check(t.id+"_file_kept",FileAccess.get_file_as_string(b.save_path).sha256_text()==hash)
		check(t.id+"_exit",not d.active and r.line_workspace.visible)
		check(t.id+"_known_after",t==known_before)
	# Exact helpers, including angle/length and ratio, operate on user-chosen coordinates.
	r.line_workspace.choose(0);await frames(4);await key(KEY_L)
	var h=b.helper
	h.start("fixed");h.fields.length[1].value=30;h.fields.angle[1].value=30
	await click_at(at([-2,-2]));await click_at(at([-20,-20]));await frames()
	check("fixed_preview",h.preview_ready and not h.endpoint.is_empty())
	var before:int=b.document.lines.size();await click(h.confirm)
	check("fixed_commit",b.document.lines.size()==before+1)
	var made:Dictionary=b.document.lines[-1];var delta:=Vector2(made.b[0]-made.a[0],made.b[1]-made.a[1])
	check("fixed_30mm_30deg",absf(delta.length()-30)<.00001 and absf(rad_to_deg(atan2(absf(delta.y),absf(delta.x)))-30)<.00001)
	await key(KEY_Z,true);check("helper_single_undo",b.document.lines.size()==before)
	h.start("ratio");await click_at(at([1,8]));await click_at(at([21,18]));await frames();check("ratio_preview",h.preview_ready)
	var count_points:int=b.document.points.size();await click(h.confirm);check("ratio_commit",b.document.points.size()==count_points+1)
	h.start("measure");await click_at(at([-2,-2]));await click_at(at([8,8]));var doc:Dictionary=b.document.duplicate(true);check("measure_transient",not h.result.text.is_empty());h.cancel();check("measure_no_document",b.document==doc)
	h.start("parallel");await click_at(at([-5,0]));await click_at(at([-6,10]));await click_at(at([-20,11]));await frames();check("parallel_preview",h.preview_ready);await click(h.confirm)
	check("parallel_direction",is_equal_approx(b.document.lines[-1].a[1],b.document.lines[-1].b[1]))
	b.styles.button_pressed=true;await key(KEY_L);await click_at(at([8,4]));await click_at(at([14,8]));b.cancel_pending();check("dashed_saved",b.document.lines[-1].get("dashed",false));b.save_draft()
	await picture("helpers")
	# Panel is visible in the render and its controls remain inside the viewport.
	h.start("fixed");await picture("helper-panel");check("helper_panel_in_window",r.get_global_rect().encloses(h.panel.get_global_rect()));h.cancel()
	# The original question window uses the same pan/zoom surface and exact archive image.
	r.line_workspace.show_source();await frames(4);check("original_question",r.source_image.texture!=null and r.source_window.visible);r.hide_source()
	# Native naming through the actual modal, with document shortcut isolation.
	await key(KEY_P);await click_at(at([12,20]));var new_id:String=b.selected.id
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.double_click=true;e.position=at([12,20]);r.get_viewport().push_input(e,true);e=e.duplicate();e.pressed=false;r.get_viewport().push_input(e,true);await frames()
	check("naming_modal",b.naming_dialog.visible)
	b.name_field.text="测试点′";await key(KEY_ENTER);await frames();check("native_name",b.point_label(new_id)=="测试点′")
	b.save_draft()
	# Genuine natural writing/action and interruption paths.
	d.enter(b.task);await frames();await wait_seconds(2.6);check("natural_writing",d.overlay.label.visible_characters>0)
	if d.phase=="typing":await key(KEY_D)
	await key(KEY_D);await key(KEY_D);check("natural_ready",d.phase=="ready")
	await key(KEY_D);await wait_seconds(1.3);check("natural_animation",d.phase=="settled")
	# Native selection and clipboard copy through the explanation control.
	var clipboard:String=DisplayServer.clipboard_get();var copy=d.overlay.label
	var event:=InputEventMouseButton.new();event.position=copy.global_position+Vector2(16,12);event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.double_click=true
	r.get_viewport().push_input(event,true);event=event.duplicate();event.pressed=false;r.get_viewport().push_input(event,true);await frames();await key(KEY_C,true)
	check("native_copy",not copy.get_selected_text().is_empty() and DisplayServer.clipboard_get()==copy.get_selected_text());DisplayServer.clipboard_set(clipboard)
	d.exit();await frames()
	for stage in ["typing","playing","settled"]:
		d.enter(b.task);await frames()
		if stage!="typing":
			await key(KEY_D);await key(KEY_D);await key(KEY_D);await key(KEY_D)
			if stage=="settled":await key(KEY_D)
		var saved_doc:Dictionary=b.document.duplicate(true);d.exit();await wait_seconds(1.3)
		check("exit_"+stage,not d.active and b.document==saved_doc)
	# Generic precision snapping is derived from visible geometry, not answers.
	var p0:Dictionary=b.document.duplicate(true)
	b.add_result([1,1],[9,9]);b.add_result([1,9],[9,1]);var snap:Array=b.exact_snap(b.canvas.at([5.05,5.02]));check("exact_visible_intersection",snap==[5.0,5.0]);b.document=p0;b.canvas.queue_redraw()
	# Broken QA files remain blocked even after task switches within this run.
	var corrupt:Dictionary=r.line_workspace.config.tasks[1];var path:String="user://qa-line-task-"+corrupt.id+".json"
	var original:String=FileAccess.get_file_as_string(path);var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken-test-file");file.close()
	b.memory.erase(corrupt.id);b.activate(corrupt);check("corrupt_blocked",b.blocked_save);b.save_draft();check("corrupt_preserved",FileAccess.get_file_as_string(path)=="broken-test-file")
	b.activate(r.line_workspace.config.tasks[0]);b.activate(corrupt);b.save_draft();check("corrupt_stays_blocked",b.blocked_save and FileAccess.get_file_as_string(path)=="broken-test-file")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(original);file.close();b.memory.erase(corrupt.id)
	b.blocked_save=true;b.activate(r.line_workspace.config.tasks[0])
	check("observation_kept",r.observer.get_state()==asset_camera and r.selected==user_selection)
	check("qa_only",r.save_path=="user://qa-line-practice-observation.json")
	finish("line-practice-check-"+suffix+".json")

func finish(filename:String) -> void:
	var f:=FileAccess.open("res://qa/"+filename,FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	print("LINE_PRACTICE_QA ",filename," ",checks.size()," checks")

func transfer_check(item:Dictionary) -> void:
	var name:String=b.task.id+"_"+item.name
	d.current_beat=item.step;d.prepare();await frames();await key(KEY_D)
	check(name+"_one_short_instruction",d.beats[item.step].text.length()<15 and d.beats[item.step].action.type=="side_point")
	var doc:Dictionary=b.document.duplicate(true)
	await click(d.next)
	for threshold in [.15,.45,.7,.86]:
		while d.phase=="playing" and d.sheet.canvas.progress-item.order<threshold:await frames(1)
		await frames(2)
		var canvas=d.sheet.canvas
		var drawn:Array=canvas.transfer_segments.get(item.name,[])
		check(name+"_concurrent_"+str(threshold),drawn.size()==(2 if threshold<.32 else 3 if threshold<.76 else 2))
		check(name+"_point_"+str(threshold),canvas.transfer_points.has(item.name)==(threshold>=.64))
		if threshold==.45:
			check(name+"_both_branches",drawn[0][1].distance_to(drawn[0][0])>0 and drawn[2][1].distance_to(drawn[2][0])>0)
			await picture("continuous-"+name)
		if threshold==.7:check(name+"_true_endpoint",drawn[2][1].distance_to(canvas.at(item.p))<.01)
	while d.phase=="playing":await frames(1)
	await frames()
	check(name+"_settled",d.phase in ["settled","complete"] and d.current_beat==item.step)
	check(name+"_clean_result",d.sheet.canvas.transfer_segments[item.name].is_empty() and d.sheet.canvas.transfer_points.has(item.name))
	if item.step<d.beats.size()-1:
		await key(KEY_D);await key(KEY_A);await key(KEY_A)
	else:
		await key(KEY_A);await key(KEY_D);await key(KEY_D);await key(KEY_D);await key(KEY_D)
	await frames()
	check(name+"_back_before",d.current_beat==item.step and is_equal_approx(d.sheet.canvas.progress,item.order) and not d.sheet.canvas.transfer_points.has(item.name))
	await key(KEY_D);await key(KEY_D);await key(KEY_A);await frames()
	check(name+"_busy_A_finishes",d.current_beat==item.step and d.phase in ["settled","complete"] and d.sheet.canvas.transfer_segments[item.name].is_empty())
	for threshold in [.2,.85]:
		d.current_beat=item.step;d.prepare();await frames();await key(KEY_D);await key(KEY_D)
		while d.phase=="playing" and d.sheet.canvas.progress-item.order<threshold:await frames(1)
		d.exit();await wait_seconds(.3)
		check(name+"_exit_"+str(threshold),not d.active and b.document==doc)
		d.enter(b.task);await frames()
