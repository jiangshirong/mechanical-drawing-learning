extends RefCounted
const Geometry = preload("res://line_geometry.gd")
var r
var h
var d
var checks: Array = []

func check(name: String,value: bool,detail = null) -> void:
	checks.append({"check":name,"passed":value,"detail":detail})
	if not value: print("LINE_FAILURE ",name," ",detail)

func button(node: Control) -> void:
	await h.click(node.get_global_rect().get_center())
	await h.wait_frames(2)

func event(code: Key,pressed: bool,echo := false,ctrl := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode=code; e.keycode=code; e.pressed=pressed; e.echo=echo; e.ctrl_pressed=ctrl
	r.get_viewport().push_input(e,true)

func key(code: Key) -> void:
	event(code,true); event(code,false)
	await h.wait_frames(2)

func idle() -> void:
	var deadline := Time.get_ticks_msec()+7000
	while d.busy and Time.get_ticks_msec()<deadline:
		await h.wait_frames(1)
	check("idle_"+str(checks.size()),not d.busy,d.phase)
	await h.wait_frames(3)

func snap(name: String) -> void:
	await h.wait_frames(3)
	r.queue_redraw(); d.space.request_render(); d.paper.queue_redraw(); d.overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/line-"+name+".png")

func layout(name: String,check_labels := true) -> void:
	var o = d.overlay
	check(name+"_copy_in_stage",o.content_rect.encloses(o.box_rect),o.box_rect)
	check(name+"_copy_avoids_labels",o.protected.all(func(rect):return not o.box_rect.intersects(rect)),o.box_rect)
	check(name+"_no_exam_copy",not "套" in d.copy.text and not "题" in d.copy.text and not "x_B" in d.copy.text and not "{" in d.copy.text,d.copy.text)
	check(name+"_six_nodes",d.progress.nodes.size()==6)
	for node in d.progress.nodes: check(name+"_footer_"+node.name,d.get_global_rect().encloses(node.get_global_rect()) and not node.get_global_rect().intersects(d.next.get_global_rect()))
	if check_labels: label_line_checks(name)
	for rect in d.paper.label_rects: check(name+"_paper_label_visible_"+str(checks.size()),Rect2(Vector2.ZERO,d.paper.size).encloses(rect),rect)

func math_checks() -> void:
	var g = d.geometry
	var s: Dictionary = g.initial("horizontal")
	var ends: Array[Vector3] = g.ends(s,"AB")
	check("horizontal_source_30_mm",is_equal_approx(ends[0].distance_to(ends[1]),30))
	check("horizontal_true_top",is_equal_approx(Geometry.project(ends[0],"top").distance_to(Geometry.project(ends[1],"top")),30))
	check("horizontal_angle_30",is_equal_approx(rad_to_deg(asin(absf((ends[1]-ends[0]).normalized().y))),30))
	check("horizontal_equal_height",is_equal_approx(ends[0].z,ends[1].z))
	s=g.initial("frontal"); ends=g.ends(s,"AB")
	check("frontal_equal_depth",is_equal_approx(ends[0].y,ends[1].y))
	check("frontal_true_length",is_equal_approx(Geometry.project(ends[0],"front").distance_to(Geometry.project(ends[1],"front")),ends[0].distance_to(ends[1])))
	for pair in [["normal_H","top"],["normal_V","front"]]:
		s=g.initial(pair[0]); ends=g.ends(s,"AB")
		check(pair[0]+"_point_projection",Geometry.project(ends[0],pair[1]).is_equal_approx(Geometry.project(ends[1],pair[1])))
		for view in ["front","top","left"]:
			if view!=pair[1]: check(pair[0]+"_length_"+view,is_equal_approx(Geometry.project(ends[0],view).distance_to(Geometry.project(ends[1],view)),ends[0].distance_to(ends[1])))
	for pair in [["height",2,25.0],["distance_V",1,-10.0]]:
		s=g.initial(pair[0]); ends=g.ends(s,"AB")
		var c: Vector3 = g.point(s,"C")
		check(pair[0]+"_face_condition",is_equal_approx(c[pair[1]],pair[2]))
		check(pair[0]+"_point_on_line",(c-ends[0]).cross(ends[1]-ends[0]).length()<.00001)
	s=g.initial("ratio"); ends=g.ends(s,"AB")
	for t in [.4,.6]:
		s.fraction=t
		var c: Vector3 = g.point(s,"C")
		check("space_ratio_"+str(t),is_equal_approx(ends[0].distance_to(c)/ends[0].distance_to(ends[1]),t))
		for view in ["front","top","left"]:
			check("projected_ratio_"+view+str(t),is_equal_approx(Geometry.project(ends[0],view).distance_to(Geometry.project(c,view))/Geometry.project(ends[0],view).distance_to(Geometry.project(ends[1],view)),t))
	s=g.initial("parallel")
	var ab: Array[Vector3] = g.ends(s,"AB"); var ef: Array[Vector3] = g.ends(s,"EF")
	check("parallel_through_point",ab[0]==g.point(s,"A") and (ab[1]-ab[0]).cross(ef[1]-ef[0]).length()<.00001)
	s=g.initial("parallelogram")
	check("parallelogram_opposite_sides",(g.point(s,"B")-g.point(s,"A")).is_equal_approx(g.point(s,"C")-g.point(s,"D")))
	s=g.initial("parallel_false"); ab=g.ends(s,"AB"); ef=g.ends(s,"EF")
	check("parallel_false_front_matches",absf(Geometry.project(ab[1]-ab[0],"front").cross(Geometry.project(ef[1]-ef[0],"front")))<.00001)
	check("parallel_false_space_differs",(ab[1]-ab[0]).cross(ef[1]-ef[0]).length()>1)
	s=g.initial("intersection"); ab=g.ends(s,"AB"); ef=g.ends(s,"EF")
	var c: Vector3 = g.point(s,"C")
	check("true_common_intersection",(c-ab[0]).cross(ab[1]-ab[0]).length()<.00001 and (c-ef[0]).cross(ef[1]-ef[0]).length()<.00001)
	s=g.initial("apparent")
	var p: Vector3 = g.point(s,"P"); var q: Vector3 = g.point(s,"Q")
	check("apparent_same_front",Geometry.project(p,"front").is_equal_approx(Geometry.project(q,"front")))
	check("apparent_distinct_space",p.distance_to(q)>1 and absf(p.y-q.y)>1)
	ab=g.ends(s,"AB"); ef=g.ends(s,"EF")
	check("apparent_skew_no_common_point",absf((ef[0]-ab[0]).dot((ab[1]-ab[0]).cross(ef[1]-ef[0])))>1)
	s=g.initial("through"); ef=g.ends(s,"EF")
	check("specified_intersection_V",is_equal_approx(g.point(s,"B").y,-10) and (g.point(s,"B")-ef[0]).cross(ef[1]-ef[0]).length()<.00001)
	s=g.initial("both"); ab=g.ends(s,"AB")
	var mn: Array[Vector3] = g.ends(s,"MN")
	check("transversal_parallel",(mn[1]-mn[0]).normalized().cross((ab[1]-ab[0]).normalized()).length()<.00001,[mn,ab])
	for item in [[0,"CD"],[1,"EF"]]:
		var line: Array[Vector3] = g.ends(s,item[1])
		var hit: Vector3 = mn[item[0]]
		var t: float = (hit-line[0]).dot(line[1]-line[0])/(line[1]-line[0]).length_squared()
		check("transversal_meets_"+item[1],(hit-line[0]).cross(line[1]-line[0]).length()<.00001 and t>=0 and t<=1)

func run(root,flag: String) -> void:
	r=root; h=load("res://interaction_check.gd").new(); h.r=r; d=r.line_demo
	await h.wait_frames(15)
	check("map_default",r.map_active and not d.active)
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	check("isolated_paths",r.save_path=="user://qa-line-observation.json" and r.practice.save_path=="user://qa-line-practice.json")
	await h.choose(1)
	check("line_modes_alongside_map",r.line_tabs.visible and r.line_tabs.get_child_count()==3 and not r.points_tabs.visible)
	await button(r.line_tabs.get_node("LineMode_observe"))
	check("observe_remains_current",r.line_tabs.get_node("LineMode_observe").button_pressed and not d.active)
	if "--qa-problem-cards" in OS.get_cmdline_user_args():
		if "--qa-problem-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await problem_card_checks()
		finish("line-problem-cards-check.json"); return
	if "--qa-line-morph" in OS.get_cmdline_user_args():
		if "--qa-morph-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await morph_checks()
		finish("line-morph-check.json"); return
	if "--qa-side-projection" in OS.get_cmdline_user_args():
		if "--qa-side-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await side_projection_checks()
		finish("line-side-projection-check.json"); return
	if "--qa-label-motion" in OS.get_cmdline_user_args():
		if "--qa-label-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await label_motion_checks()
		finish("line-label-motion-check.json"); return
	if "--qa-context-layout" in OS.get_cmdline_user_args():
		if "--qa-context-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await context_layout_checks()
		finish("line-context-layout-check.json"); return
	if "--qa-refine-only" in OS.get_cmdline_user_args():
		if "--qa-refine-minimum" in OS.get_cmdline_user_args():
			DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(8)
		await refine_checks()
		finish("lesson-refine-check.json"); return
	if "--qa-copy-only" in OS.get_cmdline_user_args():
		await copy_checks()
		finish("copy-selection-check.json"); return
	if flag=="--qa-line-reopen":
		check("reopen_observe",r.free_shell.visible and not d.active)
		await button(r.line_tabs.find_child("LineMode_concept",true,false))
		await idle()
		check("reopen_target",d.beats[d.current_beat].id=="division:2-3" and d.phase=="ready")
		check("reopen_before_motion",is_equal_approx(d.state.fraction,.4))
		check("reopen_before_C",not d.point_nodes.C.space.ball.visible and d.state.points.C.space==0)
		await button(d.leave)
		finish("line-learning-reopen.json"); return
	r.line_step_id=""
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var draft: Dictionary = r.practice.snapshot()
	r.select_feature("AB",r.data.parameters.A)
	var picked: Array = r.observer.picked_world.duplicate()
	await button(r.line_tabs.find_child("LineMode_concept",true,false))
	check("entry_typing",d.active and d.phase=="typing" and not r.free_shell.visible)
	check("reviewed_method_51_beats",d.beats.size()==51 and d.beats[0].id=="projection:purpose" and d.beats.any(func(b):return b.id=="intersection:both-clue"))
	check("no_removed_beats",d.beats.all(func(beat):return beat.id not in ["parallel_plane:H","parallel_plane:V","normal_plane:H","normal_plane:V","normal_plane:H-dot","normal_plane:V-dot","division:3-2","division:rule","point_on_line:V-guide-context","point_on_line:V-guide","point_on_line:V-point","point_on_line:V-transfer"]))
	check("no_free_interaction",d.space.interaction_enabled and d.space.rotation_only and not d.space.picking_enabled and not r.observer.interaction_enabled and not r.paper.picking_enabled)
	await snap("typing")
	var count: int = d.scene.get_child_count()
	math_checks()
	var original: int = d.current_beat
	event(KEY_D,true,false,true); event(KEY_D,false)
	check("modifier_D_ignored",d.current_beat==original and d.phase=="typing")
	event(KEY_A,true)
	check("A_finishes_first_text",d.phase==d.text_complete_phase() and d.copy.visible_characters==d.copy.text.length() and d.previous.disabled)
	event(KEY_A,true,true); event(KEY_A,true); event(KEY_A,false)
	check("held_A_stays_first",d.current_beat==0 and d.phase==d.text_complete_phase())
	await key(KEY_D)
	check("pure_introduction_has_no_empty_action",d.current_beat==1 and d.phase=="typing")
	await key(KEY_D);await key(KEY_D)
	check("D_starts_real_action",d.phase=="playing")
	await button(d.next)
	check("mouse_finishes_keyboard_action",d.phase=="settled" and d.current_beat==1 and d.state==d.after_states[1])
	await button(d.progress.nodes[0])
	check("jump_while_typing",d.current_beat==0 and d.phase=="typing")
	await key(KEY_D); await key(KEY_D);await key(KEY_D);await key(KEY_D)
	check("playing_before_jump",d.phase=="playing")
	await button(d.progress.nodes[2]); await idle(); await h.wait_frames(30)
	check("jump_cancels_old_tween",d.current_step==2 and d.state==d.before_states[d.current_beat] and d.phase=="ready")
	await button(d.progress.nodes[0])
	Engine.time_scale=5
	for i in range(d.beats.size()):
		await idle()
		var id: String = d.beats[i].id
		check("ready_"+id,d.current_beat==i and d.phase==d.text_complete_phase())
		layout(id)
		check("node_pool_"+id,d.scene.get_child_count()==count and d.builds==1)
		for line_id in d.state.lines:
			var ends: Array[Vector3] = d.geometry.ends(d.state,line_id)
			for view in Geometry.VIEWS:
				var node: MeshInstance3D = d.line_nodes[line_id][view]
				if not node.visible: continue
				var expected: Vector3 = Geometry.world(d.on_plane(ends[0].lerp(ends[1],float(d.state.lines[line_id][view])),view))
				check("rendered_endpoint_"+id+line_id+view,node.to_global(Vector3(0,0,.001)).distance_to(expected)<.000001)
		if d.beats[i].action.type=="scene":
			check("context_scene_order_"+id,d.state.scene==(d.beats[i].action.scene if d.prepares_with_question() else d.beats[i].scene) and d.after_states[i].scene==d.beats[i].action.scene)
			if id in ["projection:third-A-context","parallel_plane:H-context","point_on_line:height-guide-context","division:parts-context"]: await snap("context-before-"+id.replace(":","-"))
		if d.has_action():
			if not d.prepares_with_question():
				if i%2==0: await key(KEY_D)
				else: await button(d.next)
			if d.phase=="playing" and i%3!=0:
				var before: Dictionary = d.state.duplicate(true)
				event(KEY_A,true)
				check("snap_finishes_"+id,d.phase in ["settled","complete"] and d.state==d.after_states[i])
				event(KEY_A,true,true); event(KEY_A,true)
				check("hold_does_not_queue_"+id,d.current_beat==i)
				event(KEY_A,false)
			await idle()
			check("action_result_"+id,d.current_beat==i and d.state==d.after_states[i] and d.phase in ["settled","complete"])
			label_line_checks("result_"+id)
			if d.beats[i].action.type=="scene" and d.beats[i].action.scene=="third":
				check("third_given_only_two_views",d.state.lines.AB.front==1 and d.state.lines.AB.top==1 and d.state.lines.AB.left==0 and d.state.points.A.left==0 and d.state.points.B.left==0)
		else: check("no_empty_action_"+id,d.before_states[i]==d.after_states[i])
		if id in ["projection:connect","projection:third-line","parallel_plane:H-context","parallel_plane:V-context","parallel_plane:H-angle","parallel_plane:H-length","parallel_plane:V-length","normal_plane:H-context","normal_plane:V-context","point_on_line:height-transfer","division:2-3","parallel:through","parallel:rule","parallel:complete-lines","parallel:complete-point","parallel:compare","intersection:check","intersection:through","intersection:both-space"]:
			await snap(id.replace(":","-"))
		if id=="parallel_plane:H-angle": check("visible_angle_30",d.overlay.angle_label=="30°")
		if id in ["normal_plane:H-context","normal_plane:V-context"]:
			var view: String = "top" if id=="normal_plane:H-context" else "front"
			check("degenerate_no_short_line_"+view,view+":AB" in d.rendered_degenerate and not d.line_nodes.AB[view].visible)
			check("degenerate_merged_names_"+view,not d.paper.merged_labels.is_empty())
			check("degenerate_highlight_"+view,view+":AB" in d.beats[i].focus)
		if id=="division:2-3":
			check("only_ratio_example_2_3",is_equal_approx(d.state.fraction,.4) and d.beats[i+1].id=="parallel:through-context")
		if i==d.beats.size()-1: break
		await key(KEY_D)
		check("next_text_or_question_preparation_"+id,d.current_beat==i+1 and (d.prepares_with_question() or d.state==d.before_states[i+1]) and d.phase in ["typing","ready","complete","settled","playing"])
		if d.phase=="typing":
			event(KEY_D,true); event(KEY_D,true,true); event(KEY_D,true)
			check("typing_snap_no_extra_step_"+id,d.current_beat==i+1 and d.copy.visible_characters==d.copy.text.length() and d.phase in ["ready","complete","settled"])
			event(KEY_D,false)
	check("final_disabled",d.next.disabled and not d.leave.disabled)
	await key(KEY_A); await idle()
	check("previous_stable_state",d.state==d.before_states[d.current_beat])
	for i in range(d.steps.size()):
		await button(d.progress.nodes[i]); await idle()
		check("chapter_first_"+str(i),d.current_step==i and d.beats[d.current_beat].id==d.steps[i].beats[0].id and d.state==(d.after_states[d.current_beat] if d.prepares_with_question() else d.before_states[d.current_beat]))
	await button(d.leave)
	check("exit_preserves_free",r.observer.get_state()==camera and r.observer.picked_world==picked and r.practice.snapshot()==draft and r.free_shell.visible)
	var saved_targets := {"bad-id":"projection:purpose","division":"division:parts-context","parallel_plane:H":"parallel_plane:H-context","parallel_plane:V":"parallel_plane:V-context","normal_plane:H":"normal_plane:H-context","normal_plane:V":"normal_plane:V-context","normal_plane:H-dot":"normal_plane:H-context","normal_plane:V-dot":"normal_plane:V-context","division:3-2":"division:2-3","division:rule":"division:2-3","point_on_line:V-guide-context":"point_on_line:height-guide-context","point_on_line:V-guide":"point_on_line:height-guide","point_on_line:V-point":"point_on_line:height-point","point_on_line:V-transfer":"point_on_line:height-transfer"}
	for id in saved_targets:
		r.line_step_id=id
		await button(r.line_tabs.find_child("LineMode_concept",true,false)); await idle()
		check("saved_target_"+id,d.beats[d.current_beat].id==saved_targets[id] and d.state==(d.after_states[d.current_beat] if d.prepares_with_question() else d.before_states[d.current_beat]))
		if saved_targets[id]=="division:2-3": check("saved_ratio_before_C_"+id,is_equal_approx(d.state.fraction,.4) and not d.point_nodes.C.space.ball.visible)
		await button(d.leave)
	# Exit during each kind of phase and prove old callbacks cannot change the next entry.
	for target in ["typing","ready","playing","settled"]:
		r.line_step_id="projection:connect"
		await button(r.line_tabs.find_child("LineMode_concept",true,false))
		if target!="typing": await key(KEY_D)
		if target in ["playing","settled"]: await key(KEY_D)
		if target=="settled": await idle()
		check("exit_source_phase_"+target,d.phase==target,d.phase)
		await button(d.leave); await h.wait_frames(12)
		check("exit_phase_"+target,not d.active and r.practice.snapshot()==draft and r.observer.get_state()==camera)
	# Minimum window renders use real rendered pixels, without native fullscreen.
	DisplayServer.window_set_size(Vector2i(1060,720)); await h.wait_frames(12)
	for id in ["parallel_plane:H-context","parallel_plane:V-context","normal_plane:H-context","normal_plane:V-context","parallel_plane:H-angle","division:2-3","intersection:both-space"]:
		r.line_step_id=id
		await button(r.line_tabs.find_child("LineMode_concept",true,false)); await idle()
		if d.has_action(): await key(KEY_D); await idle()
		layout("minimum_"+id)
		await snap("minimum-"+id.replace(":","-"))
		await button(d.leave)
	check("formal_controls_restored",r.line_tabs.find_child("LineMode_concept",true,false).disabled==false and r.observer.interaction_enabled)
	for i in [0,2,6]:
		await h.choose(i)
		check("other_mode_"+str(i),not r.line_tabs.visible and not d.active)
	await copy_checks()
	await h.choose(1)
	r.line_step_id="division:3-2"; r.save_states()
	Engine.time_scale=1
	finish("line-learning-check.json")

func finish(name: String) -> void:
	FileAccess.open("res://qa/"+name,FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	print("LINE_QA ",name," ",checks.size()," checks")

func problem_layout(name: String) -> void:
	# Moving names keep their existing smooth avoidance. The problem card's
	# separation from those names and all moving ink is checked every phase;
	# label-to-line clearance is checked after the geometry settles.
	layout(name,d.phase!="playing" and not d.problem_preparing)
	var o = d.overlay
	check(name+"_title",o.callout_kind=="problem" and o.problem_title.visible and o.problem_title.text=="问题")
	check(name+"_font",d.copy.get_theme_font_size("normal_font_size")==20)
	check(name+"_full_body_fits",d.copy.get_content_height()<=d.copy.size.y+1,[d.copy.size,d.copy.get_content_height()])
	check(name+"_panel_matches",o.panel.get_rect().is_equal_approx(o.box_rect),[o.panel.get_rect(),o.box_rect])
	check(name+"_avoids_ink",o.protected_segments.all(func(segment):return not o.segment_hits(o.box_rect.grow(4),segment[0],segment[1])),o.box_rect)
	check(name+"_blue_gray",o.panel.get_theme_stylebox("panel").bg_color==Color("a9bdcd") and o.problem_style.border_width_left==3)

func problem_card_checks() -> void:
	Engine.time_scale=1
	var suffix := "-minimum" if "--qa-problem-minimum" in OS.get_cmdline_user_args() else "-normal"
	var tasks := ["projection:third-A-context","point_on_line:height-guide-context","parallel:through-context","parallel:complete-lines-context","intersection:distance-context","intersection:both-front-context"]
	var tagged: Array = []
	for group in d.config.concept:
		for beat in group.beats:
			if beat.get("callout_kind","")=="problem": tagged.append(beat.id)
	check("exact_six_problem_entries",tagged==tasks,tagged)
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var draft: Dictionary = r.practice.snapshot()
	for target in tasks:
		r.line_step_id=target; d.enter()
		check(target+"_starts_from_before",d.state==d.before_states[d.current_beat] and d.problem_preparing)
		await h.wait_frames(8)
		check(target+"_typing_and_preparing",d.phase=="typing" and d.copy.visible_characters<d.copy.text.length() and d.problem_preparing and d.hint_progress>0)
		if target==tasks[0]: check("side_removed_with_question",d.state.lines.AB.left<1 and d.state.lines.AB.front==1 and d.state.lines.AB.top==1)
		problem_layout(target+"_before")
		await snap("problem-"+target.replace(":","-")+suffix)
		if target==tasks[1]:
			check("two_condition_kinds", "给定点C离某面的距离" in d.copy.text and "给定AC和CB的长度比例" in d.copy.text)
		var fixed: Rect2 = d.overlay.box_rect
		for threshold in [.25,.6]:
			while d.problem_preparing and d.hint_progress<threshold: await h.wait_frames(1)
			await h.wait_frames(3)
			problem_layout(target+"_during_"+str(threshold))
			check(target+"_card_stays_still_"+str(threshold),d.overlay.box_rect.is_equal_approx(fixed),[fixed,d.overlay.box_rect])
			if threshold==.6: await snap("problem-moving-"+target.replace(":","-")+suffix)
		if tasks.find(target)%2==0:
			if target==tasks[0]: await key(KEY_D)
			elif target==tasks[2]: await key(KEY_A)
			else: await button(d.next)
			check(target+"_busy_input_finishes_both",d.phase=="settled" and not d.problem_preparing and d.copy.visible_characters==d.copy.text.length() and d.state==d.after_states[d.current_beat])
		await idle()
		check(target+"_holds_result",d.phase=="settled" and d.overlay.problem_title.visible and d.state==d.after_states[d.current_beat])
		check(target+"_holds_card_position",d.overlay.box_rect.is_equal_approx(fixed),[fixed,d.overlay.box_rect])
		problem_layout(target+"_after")
		await snap("problem-result-"+target.replace(":","-")+suffix)
		await h.wait_frames(8)
		check(target+"_no_auto_next",d.beats[d.current_beat].id==target and d.phase=="settled")
		if target==tasks[1]:
			check("two_decorated_conditions",d.overlay.condition_layer.rows.size()==2,d.overlay.condition_layer.rows)
			for condition in d.overlay.conditions:
				var first: int = d.copy.text.find(condition)
				check("condition_on_own_line_"+condition,d.copy.get_character_line(first)==d.copy.get_character_line(first+condition.length()-1))
			var rows: Array = d.overlay.condition_layer.rows
			if rows.size()==2: check("condition_rows_separate",rows[0].end.y<rows[1].position.y)
			await select_copy(d.copy,"problem_card"+suffix)
			check("copy_preserves_step",d.beats[d.current_beat].id==target and d.phase=="settled")
		await key(KEY_D)
		check(target+"_ordinary_next",d.phase=="typing" and not d.overlay.problem_title.visible and d.overlay.callout_kind=="normal")
		await button(d.leave)
		check(target+"_clears_style",not d.active and not d.overlay.problem_title.visible and d.overlay.callout_kind=="normal")
		check(target+"_observation_preserved",r.observer.get_state()==camera and r.practice.snapshot()==draft)
	# Three constructive actions reveal only the newly requested projection.
	r.line_step_id="parallel:through"; d.enter(); await key(KEY_D)
	var views := [["front"],["top"],["left","space"]]
	for i in range(3):
		check("parallel_action_views_"+str(i),d.beats[d.current_beat].action.views==views[i])
		for v in Geometry.VIEWS:
			var completed: bool = v=="front" and i>0 or v=="top" and i>1
			check("parallel_before_"+str(i)+v,d.state.lines.AB[v]==(1.0 if completed else 0.0))
		await key(KEY_D)
		if i==1: await key(KEY_A)
		else: await idle()
		for v in Geometry.VIEWS:
			var completed: bool = v=="front" or v=="top" and i>=1 or v in ["left","space"] and i==2
			check("parallel_after_"+str(i)+v,d.state.lines.AB[v]==(1.0 if completed else 0.0) and d.state.points.B[v]==(1.0 if completed else 0.0))
		layout("parallel_split_"+str(i)); await snap("parallel-split-"+str(i)+suffix)
		if i<2: await key(KEY_D); await key(KEY_D)
	math_checks()
	await key(KEY_A); await key(KEY_D)
	check("parallel_back_keeps_front",d.beats[d.current_beat].id=="parallel:through-top" and d.state.lines.AB.front==1 and d.state.lines.AB.top==0 and d.state.lines.AB.left==0)
	d.exit()
	var aliases := {"point_on_line:V-guide-context":"point_on_line:height-guide-context","point_on_line:V-guide":"point_on_line:height-guide","point_on_line:V-point":"point_on_line:height-point","point_on_line:V-transfer":"point_on_line:height-transfer"}
	for old in aliases:
		r.line_step_id=old; d.enter()
		check("face_alias_"+old,d.beats[d.current_beat].id==aliases[old] and d.state==d.before_states[d.current_beat])
		d.exit()
	for target in ["division:parts-context","parallel:rule","intersection:apparent-context"]:
		r.line_step_id=target; d.enter(); await key(KEY_D)
		check(target+"_ordinary",not d.overlay.problem_title.visible and d.overlay.callout_kind=="normal")
		d.exit()
	for phase in ["typing","playing","settled"]:
		if phase=="playing": d.config.presentation.characters_per_second=128
		r.line_step_id=tasks[0]; d.enter(); await h.wait_frames(8)
		var count: int = d.scene.get_child_count()
		if phase=="playing":
			while d.phase=="typing": await h.wait_frames(1)
		if phase=="settled": await key(KEY_D)
		check("exit_phase_"+phase,d.phase==phase)
		if phase=="playing":
			check("text_finished_before_animation",d.problem_preparing and d.copy.visible_characters==d.copy.text.length())
		await button(d.leave); await h.wait_frames(20)
		check("exit_cancels_"+phase,not d.active and not d.problem_preparing and not d.overlay.problem_title.visible and d.scene.get_child_count()==count and not d.busy)
		d.config.presentation.characters_per_second=16
	r.line_step_id=tasks[1]; d.enter()
	while d.problem_preparing: await h.wait_frames(1)
	check("animation_finished_while_text_continues",d.phase=="typing" and d.copy.visible_characters<d.copy.text.length() and d.state==d.after_states[d.current_beat])
	await key(KEY_D)
	check("D_finishes_remaining_text",d.phase=="settled")
	d.exit()
	r.line_step_id=tasks[0]; d.enter(); await h.wait_frames(8)
	await button(d.progress.nodes[0]); await key(KEY_D); await h.wait_frames(120)
	check("jump_cancels_auto_preparation",d.current_beat==0 and d.phase=="ready" and not d.problem_preparing and d.state==d.before_states[0] and not d.overlay.problem_title.visible)
	d.exit()

func select_copy(node: RichTextLabel, name: String) -> void:
	await h.wait_frames(4)
	# Offscreen Viewport events cannot replace the native cursor sampled by
	# RichTextLabel's drag timer. Verify native selection through double-click,
	# whose hit test uses the injected event, without moving the system cursor.
	for x in range(6,int(minf(node.size.x-2,150)),12):
		var at := node.get_global_rect().position+Vector2(x,18)
		await h.click(at)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.double_click=pressed
			r.get_viewport().push_input(event,true)
			await h.wait_frames(2)
		if not node.get_selected_text().is_empty(): break
	check(name+"_native_mouse_selection",not node.get_selected_text().is_empty(),node.get_selected_text())
	var old_clipboard := DisplayServer.clipboard_get()
	var e := InputEventKey.new()
	e.keycode=KEY_C; e.physical_keycode=KEY_C; e.ctrl_pressed=true; e.pressed=true
	r.get_viewport().push_input(e,true)
	e=InputEventKey.new(); e.keycode=KEY_C; e.physical_keycode=KEY_C; e.ctrl_pressed=true; e.pressed=false
	r.get_viewport().push_input(e,true)
	await h.wait_frames(3)
	check(name+"_ctrl_c",DisplayServer.clipboard_get()==node.get_selected_text())
	DisplayServer.clipboard_set(old_clipboard)
	r.queue_redraw(); node.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/copy-"+name+".png")

func copy_checks() -> void:
	await h.choose(1)
	r.line_step_id="projection:connect"
	await button(r.line_tabs.find_child("LineMode_concept",true,false))
	await key(KEY_D)
	await select_copy(d.copy,"line_copy")
	check("copy_does_not_advance",d.phase=="ready")
	await key(KEY_D)
	check("selected_text_D_plays",d.phase=="playing")
	await button(d.leave)
	await h.choose(0)
	for mode in ["concept","solution"]:
		r.points_demo.enter(mode)
		await h.wait_frames(3)
		await key(KEY_D)
		await select_copy(r.points_demo.copy,"points_"+mode)
		if mode=="solution":
			await button(r.points_demo.question.button)
			await select_copy(r.points_demo.question.label,"question_copy")
		r.points_demo.exit()
		await h.wait_frames(3)
	await h.choose(6)
	r.course_workspace.start_concept()
	await h.wait_frames(8)
	await key(KEY_D)
	await select_copy(r.course_workspace.copy,"section_copy")
	r.course_workspace.exit_lesson()
	await h.wait_frames(3)

func rotate_model(demo) -> void:
	var start: Vector2 = demo.space.get_global_rect().position+demo.space.size*Vector2(.5,.25)
	# Selectable copy consumes mouse presses. Exercise model rotation at an
	# exposed part of the model pane, rather than accidentally selecting copy.
	for fraction in [Vector2(.5,.25),Vector2(.5,.45),Vector2(.55,.55),Vector2(.35,.6),Vector2(.7,.65)]:
		var candidate: Vector2 = demo.space.get_global_rect().position+demo.space.size*fraction
		if not demo.overlay.panel.get_global_rect().grow(40).has_point(candidate):
			start=candidate; break
	var motion := InputEventMouseMotion.new()
	motion.position=start
	r.get_viewport().push_input(motion,true)
	var down := InputEventMouseButton.new()
	down.position=start; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
	r.get_viewport().push_input(down,true)
	await h.wait_frames(2)
	motion=InputEventMouseMotion.new()
	motion.position=start+Vector2(35,20); motion.relative=Vector2(35,20); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	r.get_viewport().push_input(motion,true)
	await h.wait_frames(3)
	down=InputEventMouseButton.new()
	down.position=start+Vector2(35,20); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=false
	r.get_viewport().push_input(down,true)
	await h.wait_frames(4)

func refine_checks() -> void:
	await h.choose(1)
	r.line_step_id="parallel_plane:H"
	d.enter(); await h.wait_frames(6); await key(KEY_D)
	await key(KEY_D); await idle()
	check("definition_retains_transformed_AB",d.state.lines.AB.values().all(func(amount):return amount==1))
	check("definition_names_spatial_line",d.copy.text=="将 AB 转到平行 H 面的位置，此时称为水平线。")
	var free_camera: Dictionary = r.observer.get_state().duplicate(true)
	var before: float = d.space.yaw
	d.overlay.copy_hovered=false; d.overlay.selecting=false
	var space_copy_box: Rect2 = d.overlay.box_rect
	var old_cues: Array = d.overlay.cue_points.duplicate()
	await rotate_model(d)
	check("space_copy_fixed_during_rotation",d.overlay.box_rect==space_copy_box)
	check("space_cues_follow_rotation",d.overlay.cue_points!=old_cues)
	await rotate_model(d)
	check("space_copy_fixed_across_drags",d.overlay.box_rect==space_copy_box)
	await h.wait_frames(12)
	check("space_copy_fixed_after_release",d.overlay.box_rect==space_copy_box)
	check("line_drag_rotates",absf(d.space.yaw-before)>.05 and d.manual_camera)
	await key(KEY_D)
	check("line_next_resets_camera",is_equal_approx(d.space.yaw,-.55) and not d.manual_camera)
	await rotate_model(d); await key(KEY_A)
	check("line_previous_resets_camera",is_equal_approx(d.space.yaw,-.55) and not d.manual_camera)
	d.current_beat=d.beats.find_custom(func(beat):return beat.id=="parallel_plane:H-context"); d.prepare_beat(); await h.wait_frames(4)
	d.emphasis_clock=0; d.update_emphasis()
	var target = d.plane_labels.filter(func(node):return node.text.begins_with("H"))[0]
	var small: int = target.font_size
	d.emphasis_clock=.6; d.update_emphasis()
	check("line_label_pulses",target.font_size>small and target.font_size<=49)
	check("no_selected_text_drag_drop",not d.copy.drag_and_drop_selection_enabled)
	d.overlay.copy_hovered=true
	var box: Rect2 = d.overlay.box_rect
	d.space.yaw+=.15; d.space.update_camera(); d.overlay.geometry_key.clear(); d.overlay.refresh()
	check("copy_hit_area_stays_stable",d.overlay.box_rect==box)
	d.overlay.copy_hovered=false
	d.exit(); check("line_keeps_free_camera",r.observer.get_state()==free_camera)
	await h.choose(0)
	r.points_step_id="planes:H"
	r.points_demo.enter("concept"); await h.wait_frames(6)
	var point_demo = r.points_demo
	await key(KEY_D)
	before=point_demo.space.yaw
	await rotate_model(point_demo)
	check("point_drag_rotates",absf(point_demo.space.yaw-before)>.05)
	await key(KEY_D)
	check("point_next_resets_camera",is_equal_approx(point_demo.space.yaw,-.48) and not point_demo.manual_camera)
	point_demo.exit()
	r.change_points_mode("practice"); await h.wait_frames(6)
	var board = r.practice
	var saved: Dictionary = board.snapshot()
	board.document={"lines":[{"id":"qa","a":[-10,0],"b":[20,20]}],"points":{"id1":[0,0],"id2":[1,1]}}
	board.document.point_labels={"id1":"测试点 A′","id2":"B″"}
	board.canvas.queue_redraw(); await h.wait_frames(4)
	check("student_names_both_present",board.canvas.student_label_rects.size()==2)
	for rect in board.canvas.student_label_rects:
		check("student_name_avoids_line_"+str(checks.size()),not board.canvas.line_hits_rect(rect,board.canvas.at([-10,0]),board.canvas.at([20,20])))
	check("student_names_avoid_each_other",not board.canvas.student_label_rects[0].intersects(board.canvas.student_label_rects[1]))
	r.queue_redraw(); board.canvas.queue_redraw(); await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/lesson-refine-student-labels"+("-minimum" if "--qa-refine-minimum" in OS.get_cmdline_user_args() else "")+".png")
	board.restore_snapshot(saved)
	await copy_checks()

func label_line_checks(name: String) -> void:
	for label_name in d.paper.point_label_rects:
		var rect: Rect2 = d.paper.point_label_rects[label_name]
		check(name+"_paper_name_clear_"+label_name,d.paper.ink_segments.all(func(segment):return not d.paper.segment_hits_rect(rect,segment[0],segment[1])),rect)
	for label_id in d.spatial_label_rects:
		var rect: Rect2 = d.spatial_label_rects[label_id]
		check(name+"_space_name_clear_"+label_id,d.spatial_ink_segments.all(func(segment):return not d.paper.segment_hits_rect(rect,segment[0],segment[1])),rect)

func context_layout_checks() -> void:
	var suffix := "-minimum" if "--qa-context-minimum" in OS.get_cmdline_user_args() else "-normal"
	for target in ["projection:third-A-context","parallel_plane:H-context","normal_plane:H-context","point_on_line:height-guide-context","division:parts-context","parallel:through","parallel:complete-lines","intersection:both-space"]:
		r.line_step_id=target
		await button(r.line_tabs.find_child("LineMode_concept",true,false))
		var scene_before: String = d.state.scene
		await idle()
		layout("context"+target)
		check("read_before_change_"+target,d.state.scene==scene_before)
		await snap("teaching-before-"+target.replace(":","-")+suffix)
		if d.has_action(): await key(KEY_D); await idle()
		layout("result"+target)
		await snap("teaching-result-"+target.replace(":","-")+suffix)
		await button(d.leave)

func label_offsets() -> Dictionary:
	var offsets: Dictionary = {}
	var scale: Vector2 = d.space.size/Vector2(d.space.viewport.size)
	for views in d.point_nodes.values():
		for entry in views.values():
			if not entry.label.visible: continue
			var id := str(entry.label.get_instance_id())
			var p: Vector2 = d.space.camera.unproject_position(entry.ball.global_position)*scale
			var q: Vector2 = d.space.camera.unproject_position(entry.label.global_position)*scale
			offsets[id]=q-p
	return offsets

func label_motion_checks() -> void:
	Engine.time_scale=1
	for target in ["parallel:through","parallel_plane:H","intersection:both-space"]:
		r.line_step_id=target
		d.enter(); await idle()
		if d.has_action(): await key(KEY_D); await idle()
		var state_before: Dictionary = d.state.duplicate(true)
		var copy_box: Rect2 = d.overlay.box_rect
		var start: Vector2 = d.space.get_global_rect().position+d.space.size*Vector2(.4,.2)
		var motion := InputEventMouseMotion.new()
		motion.position=start; r.get_viewport().push_input(motion,true)
		var down := InputEventMouseButton.new()
		down.position=start; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
		r.get_viewport().push_input(down,true)
		await h.wait_frames(2)
		var previous: Dictionary = label_offsets()
		var moved := false
		var cursor: Vector2 = start
		for i in range(24):
			var travel := Vector2(9 if i<12 else -9,3 if i<12 else -3)
			cursor+=travel
			motion=InputEventMouseMotion.new()
			motion.position=cursor; motion.relative=travel; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			r.get_viewport().push_input(motion,true)
			await h.wait_frames(2)
			var current: Dictionary = label_offsets()
			for id in previous:
				if not current.has(id): continue
				var jump: float = current[id].distance_to(previous[id])
				check("bounded_label_motion_"+target+str(i)+id,jump<=16.05,jump)
				check("render_matches_cached_offset_"+target+str(i)+id,current[id].distance_to(d.spatial_label_layout[id].offset)<.01)
				if jump>.01: moved=true
			previous=current
		check("actual_reposition_exercised_"+target,moved)
		check("rotation_keeps_geometry_"+target,d.state==state_before)
		if d.beats[d.current_beat].anchor.any(func(ref):return str(ref).begins_with("space:")):
			check("rotation_keeps_copy_box_"+target,d.overlay.box_rect==copy_box)
		down=InputEventMouseButton.new()
		down.position=cursor; down.button_index=MOUSE_BUTTON_LEFT; down.pressed=false
		r.get_viewport().push_input(down,true)
		await h.wait_frames(90)
		var settled: Dictionary = label_offsets()
		await h.wait_frames(8)
		var after: Dictionary = label_offsets()
		check("stationary_pose_stays_still_"+target,settled.keys().all(func(id):return after[id].distance_to(settled[id])<.01))
		await snap("label-motion-"+target.replace(":","-")+("-minimum" if "--qa-label-minimum" in OS.get_cmdline_user_args() else "-normal"))
		await key(KEY_A); await h.wait_frames(4)
		check("step_restores_camera_"+target,not d.manual_camera and is_equal_approx(d.space.yaw,-.55))
		d.exit()
		check("exit_clears_label_cache_"+target,d.spatial_label_layout.is_empty())

func side_projection_checks() -> void:
	Engine.time_scale=1
	await connection_checks()
	r.line_step_id="projection:third-A-context"
	d.enter(); await idle()
	check("question_only",d.copy.text.ends_with("？") and not "先求" in d.copy.text and d.copy.text.length()<30,d.copy.text)
	check("question_sets_given_views",d.state.scene=="third" and d.state.lines.AB.left==0 and d.state.points.A.left==0 and d.state.points.B.left==0)
	for key_name in ["A","B"]:
		await key(KEY_D); await key(KEY_D)
		check("short_endpoint_step_"+key_name,d.copy.text.length()<25,d.copy.text)
		check("no_endpoint_preview_"+key_name,not d.point_nodes[key_name].left.ball.visible and d.state.side_guides[key_name]==0)
		var path: Array = d.geometry.side_projection_guides(d.state,key_name)
		var p: Vector3 = d.geometry.point(d.state,key_name)
		check("height_from_known_front_"+key_name,path[0][0]==Geometry.project(p,"front") and is_equal_approx(path[0][1].y,p.z))
		check("depth_to_45_line_"+key_name,path[1][0]==Geometry.project(p,"top") and is_zero_approx(path[1][1].x+path[1][1].y))
		check("45_to_side_endpoint_"+key_name,path[2][0]==path[1][1] and path[2][1]==Geometry.project(p,"left") and is_equal_approx(path[2][0].x,path[2][1].x))
		await key(KEY_D)
		for threshold in [.2,.5,.7,.86]:
			var deadline := Time.get_ticks_msec()+4000
			while d.phase=="playing" and float(d.state.side_guides[key_name])<threshold and Time.get_ticks_msec()<deadline: await h.wait_frames(1)
			await h.wait_frames(2)
			var drawn:Array=d.paper.side_guide_segments.get(key_name,[])
			check("guides_progress_"+key_name+str(threshold),drawn.size()==(2 if threshold<.32 else 3 if threshold<.76 else 2))
			check("endpoint_waits_for_guides_"+key_name+str(threshold),d.point_nodes[key_name].left.ball.visible==(threshold>=.64))
			if threshold==.5:
				check("parallel_branches_"+key_name,drawn.size()==3 and drawn[0][1].distance_to(drawn[0][0])>0 and drawn[2][1].distance_to(drawn[2][0])>0)
				await snap("side-building-"+key_name+("-minimum" if "--qa-side-minimum" in OS.get_cmdline_user_args() else "-normal"))
			if threshold==.7:check("rendered_transfer_ends_at_point_"+key_name,drawn.size()==3 and drawn[2][1].distance_to(d.paper.point_at(key_name,"left"))<.01)
		if key_name=="A": await key(KEY_D)
		await idle()
		check("endpoint_after_construction_"+key_name,d.state.side_guides[key_name]==1 and d.point_nodes[key_name].left.ball.visible and d.paper.side_guide_segments[key_name].is_empty())
		if key_name=="B": check("A_stays_completed",d.state.side_guides.A==1 and d.point_nodes.A.left.ball.visible)
		layout("side_result_"+key_name)
		await snap("side-result-"+key_name+("-minimum" if "--qa-side-minimum" in OS.get_cmdline_user_args() else "-normal"))
	await key(KEY_D); await key(KEY_D); await key(KEY_D); await idle()
	check("connect_only_after_endpoints",d.state.lines.AB.left==1 and d.current_beat==d.beats.find_custom(func(beat):return beat.id=="projection:third-line"))
	await key(KEY_D); await key(KEY_D)
	check("short_method_summary",d.beats[d.current_beat].id=="projection:method" and d.copy.text.length()<25 and not d.has_action())
	await snap("side-method"+("-minimum" if "--qa-side-minimum" in OS.get_cmdline_user_args() else "-normal"))
	await key(KEY_D)
	check("summary_no_empty_animation",d.beats[d.current_beat].id=="parallel_plane:H-context" and d.phase=="typing")
	d.exit()

func connection_checks() -> void:
	r.line_step_id="projection:connect"
	d.enter(); await idle()
	var views := ["space","front","top","left"]
	for i in range(views.size()):
		var view: String = views[i]
		check("connection_targets_"+view,d.beats[d.current_beat].action.views==[view] and not "同名投影" in d.copy.text,d.copy.text)
		check("connection_has_real_action_"+view,d.has_action())
		for j in range(views.size()):
			check("connection_before_"+view+views[j],d.state.lines.AB[views[j]]==(1.0 if j<i else 0.0))
		if i%2==0: await key(KEY_D)
		else: await button(d.next)
		check("connection_animates_"+view,d.phase=="playing")
		await idle()
		for j in range(views.size()):
			check("connection_result_"+view+views[j],d.state.lines.AB[views[j]]==(1.0 if j<=i else 0.0))
		layout("connection_"+view)
		await snap("connect-"+view+("-minimum" if "--qa-side-minimum" in OS.get_cmdline_user_args() else "-normal"))
		if i<views.size()-1:
			await key(KEY_D); await key(KEY_D)
	# Returning to a projection keeps earlier lines and removes this action's answer.
	await key(KEY_A); await key(KEY_D)
	check("connection_back_restores_prior_action",d.beats[d.current_beat].id=="projection:connect-top" and d.state.lines.AB.space==1 and d.state.lines.AB.front==1 and d.state.lines.AB.top==0 and d.state.lines.AB.left==0)
	d.exit()

func morph_checks() -> void:
	Engine.time_scale=1
	var suffix := "-minimum" if "--qa-morph-minimum" in OS.get_cmdline_user_args() else "-normal"
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var draft: Dictionary = r.practice.snapshot()
	var contexts: Array = []
	for group in d.config.concept:
		for beat in group.beats:
			if beat.action.type=="scene": contexts.append(beat.id)
	for target in contexts:
		r.line_step_id=target
		d.enter(); await h.wait_frames(5); await key(KEY_D)
		var original: Dictionary = d.before_states[d.current_beat]
		var goal: Dictionary = d.after_states[d.current_beat]
		var count: int = d.scene.get_child_count()
		var origin: Vector2 = d.paper.at(Vector2.ZERO)
		var zoom: float = d.paper.zoom
		var box: Rect2 = d.overlay.box_rect
		check("morph_starts_from_stable_"+target,d.phase=="ready" and d.state==original)
		if contexts.find(target)%2==0: await key(KEY_D)
		else: await button(d.next)
		check("morph_has_animation_"+target,d.phase=="playing" and d.hint_progress<.2)
		for threshold in [.2,.5,.8]:
			var deadline := Time.get_ticks_msec()+4000
			while d.phase=="playing" and d.hint_progress<threshold and Time.get_ticks_msec()<deadline: await h.wait_frames(1)
			check("morph_intermediate_"+target+str(threshold),d.phase=="playing" and d.state.has("positions") and d.state.morph_target==goal.scene)
			check("morph_axes_fixed_"+target+str(threshold),d.paper.at(Vector2.ZERO).distance_to(origin)<.01 and is_equal_approx(d.paper.zoom,zoom))
			check("morph_copy_fixed_"+target+str(threshold),d.overlay.box_rect==box)
			check("morph_copy_avoids_motion_"+target+str(threshold),d.overlay.protected.all(func(rect):return not rect.intersects(d.overlay.box_rect)))
			check("morph_node_pool_"+target+str(threshold),d.scene.get_child_count()==count and d.builds==1)
			for name in d.state.points:
				var p: Vector3 = d.geometry.point(d.state,name)
				for view in Geometry.VIEWS:
					var ball: MeshInstance3D = d.point_nodes[name][view].ball
					if not ball.visible: continue
					check("morph_space_point_"+target+name+view+str(threshold),ball.position.distance_to(Geometry.world(d.on_plane(p,view)))<.000001)
					if view!="space": check("morph_paper_point_"+target+name+view+str(threshold),d.paper.point_at(name,view).distance_to(d.paper.at(Geometry.project(p,view)))<.01)
			for name in d.state.lines:
				var ends: Array[Vector3] = d.geometry.ends(d.state,name)
				for view in Geometry.VIEWS:
					var node: MeshInstance3D = d.line_nodes[name][view]
					if not node.visible: continue
					var end: Vector3 = ends[0].lerp(ends[1],float(d.state.lines[name][view]))
					check("morph_line_end_"+target+name+view+str(threshold),node.to_global(Vector3(0,0,.001)).distance_to(Geometry.world(d.on_plane(end,view)))<.000001)
			if original.lines.has("AB") and goal.lines.has("AB") and original.lines.AB.space==1 and goal.lines.AB.space==1:
				var old: Array[Vector3] = d.geometry.ends(original,"AB")
				var new: Array[Vector3] = d.geometry.ends(goal,"AB")
				var now: Array[Vector3] = d.geometry.ends(d.state,"AB")
				check("morph_length_continuous_"+target+str(threshold),is_equal_approx(now[0].distance_to(now[1]),lerpf(old[0].distance_to(old[1]),new[0].distance_to(new[1]),d.hint_progress)))
				var centre_error: float = ((now[0]+now[1])*.5).distance_to(((old[0]+old[1])*.5).lerp((new[0]+new[1])*.5,d.hint_progress))
				check("morph_centre_continuous_"+target+str(threshold),centre_error<.0001,centre_error)
			if threshold==.5 and target in ["parallel_plane:H-context","parallel_plane:V-context","normal_plane:H-context","normal_plane:V-context"]:
				await snap("morph-"+target.replace(":","-")+suffix)
		if contexts.find(target)%3==0:
			await key(KEY_A)
			check("morph_A_finishes_current_"+target,d.state==goal and d.beats[d.current_beat].id==target)
		await idle()
		check("morph_stable_result_"+target,d.state==goal and not d.state.has("positions"))
		layout("morph_result_"+target)
		if target=="parallel_plane:V-context":
			check("frontal_projects_horizontal",is_equal_approx(d.geometry.point(d.state,"A").y,d.geometry.point(d.state,"B").y))
			await snap("morph-frontal-result"+suffix)
		await key(KEY_A); await key(KEY_D)
		check("morph_back_keeps_preceding_target_"+target,d.state==d.before_states[d.current_beat])
		d.exit()
	# Interrupt the transformation, then re-enter at its pre-action state.
	r.line_step_id="parallel_plane:V-context"
	d.enter(); await h.wait_frames(4); await key(KEY_D); await key(KEY_D)
	await h.wait_frames(12)
	check("morph_exit_during_animation",d.phase=="playing" and d.state.has("positions"))
	await button(d.leave); await h.wait_frames(120)
	check("morph_exit_cancels_late_callback",not d.active and d.phase=="idle" and r.observer.get_state()==camera and r.practice.snapshot()==draft)
	d.enter(); await h.wait_frames(4); await key(KEY_D)
	check("morph_resume_pre_action",d.beats[d.current_beat].id=="parallel_plane:V-context" and d.state==d.before_states[d.current_beat] and not d.state.has("positions"))
	await key(KEY_D); await h.wait_frames(8); await key(KEY_D)
	check("morph_D_finishes_current",d.state==d.after_states[d.current_beat] and d.phase=="settled")
	d.exit()


