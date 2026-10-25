extends RefCounted
var r
var h
var d
var checks: Array = []

func check(name: String,value: bool,detail = null) -> void:
	checks.append({"check":name,"passed":value,"detail":detail})
	if not value: print("BEATS_FAILURE ",name," ",detail)

func button(node: Control) -> void:
	await h.click(node.get_global_rect().get_center())
	await h.wait_frames(2)

func wait_idle() -> void:
	var deadline := Time.get_ticks_msec()+9000
	while d.busy and Time.get_ticks_msec()<deadline: await h.wait_frames(1)
	check("idle_timeout_"+str(checks.size()),not d.busy,d.phase)
	await h.wait_frames(2)

func key_event(code: Key,pressed: bool,echo := false,ctrl := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	e.ctrl_pressed = ctrl
	r.get_viewport().push_input(e,true)

func snap(name: String) -> void:
	await h.wait_frames(2)
	r.queue_redraw()
	d.sheet.canvas.queue_redraw()
	d.space.request_render()
	d.overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	var image: Image = r.get_viewport().get_texture().get_image()
	image.save_png("res://qa/points-beats-"+name+".png")
	if name in ["typing","question-hover","minimum-solution","minimum-concept"]:
		var factor: Vector2 = Vector2(image.get_size())/r.size
		for i in range(d.progress.nodes.size()-1):
			var left: Vector2 = d.progress.nodes[i].get_global_rect().get_center()
			var right: Vector2 = d.progress.nodes[i+1].get_global_rect().get_center()
			var pixel := Vector2i((left+right)*0.5*factor)
			var expected := Color("8b9ca7") if i<d.progress.current else Color("3d505e")
			var found := false
			for x in range(-1,2):
				for y in range(-1,2):
					var color: Color = image.get_pixelv(pixel+Vector2i(x,y))
					if Vector3(color.r,color.g,color.b).distance_to(Vector3(expected.r,expected.g,expected.b))<.08: found=true
			check(name+"_continuous_track_"+str(i),found,pixel)

func inspect_layout(tag: String) -> void:
	var o = d.overlay
	check(tag+"_copy_in_stage",o.content_rect.encloses(o.box_rect),{"box":o.box_rect,"stage":o.content_rect})
	check(tag+"_copy_complete",d.copy.visible_characters == d.copy.text.length())
	check(tag+"_no_template",not "{" in d.copy.text and not "undefined" in d.copy.text,d.copy.text)
	var clear := true
	for rect in o.protected:
		if o.box_rect.intersects(rect): clear = false
	check(tag+"_protected_labels",clear,o.box_rect)
	for p in o.cue_points: check(tag+"_anchor_finite_"+str(checks.size()),p.is_finite())
	for node in d.progress.nodes:
		check(tag+"_chapter_in_footer_"+node.name,d.get_global_rect().encloses(node.get_global_rect()) and not node.get_global_rect().intersects(d.previous.get_global_rect()) and not node.get_global_rect().intersects(d.next.get_global_rect()))
	check(tag+"_current_chapter",d.progress.current==d.current_step)

func visible_guides() -> Array:
	return d.sheet.canvas.primitives.filter(func(item): return item.kind=="line" and float(item.order)<d.sheet.canvas.progress and d.sheet.canvas.erased_fraction(item)<1.0)

func visible_points() -> Array:
	return d.sheet.canvas.primitives.filter(func(item): return item.kind=="point" and float(item.order)<d.sheet.canvas.progress)

func guide_cross(first: String,second: String,point_ref: String) -> bool:
	var lines: Array = d.sheet.canvas.primitives.filter(func(item): return item.kind=="line" and item.get("id","") in [first,second])
	if lines.size()!=2: return false
	var points: Array = []
	for line in lines:
		points.append(Vector2(float(line.a[0]),float(line.a[1])))
		points.append(Vector2(float(line.b[0]),float(line.b[1])))
	var hit = Geometry2D.segment_intersects_segment(points[0],points[1],points[2],points[3])
	var wanted: Array = d.refs[point_ref]
	return hit != null and hit.is_equal_approx(Vector2(float(wanted[0]),float(wanted[1])))

func advance_to(id: String) -> void:
	var guard := 0
	while d.beats[d.current_beat].id != id and guard < 150:
		await wait_idle()
		await button(d.next)
		guard += 1
	await wait_idle()
	check("reach_"+id,d.beats[d.current_beat].id == id)

func walk(kind: String) -> void:
	var count: int = d.beats.size()
	var children: int = d.scene.get_child_count() if kind == "concept" else 0
	for i in range(count):
		await wait_idle()
		var action: bool = d.has_action()
		check(kind+"_ready_"+str(i),d.phase == ("complete" if i==count-1 and not action else "ready") and d.current_beat == i)
		inspect_layout(kind+"_"+str(i))
		var before: Array = d.state.duplicate()
		var beat_id: String = d.beats[i].id
		var text: String = d.copy.text
		if kind=="concept":
			check("knowledge_copy_no_exam_or_equation_"+str(i),not "第8套" in text and not "第1套" in text and not "=" in text and not "＝" in text and not "＋" in text and not "x_B" in text,text)
			var targets: Array = d.beats[i].get("label_focus",[])
			for item in d.concept.label_bases:
				check("semantic_label_style_"+str(i)+str(item.label.get_instance_id()),(item.label.font_size>=item.font_size and item.label.font_size<=roundi(item.font_size*1.35)) if item.key in targets else item.label.font_size==item.font_size)
			if not targets.is_empty():
				await snap("labels-"+beat_id.replace(":","-"))
		if kind=="solution" and d.beats[i].action.has("measure_from"):
			var a: Dictionary = d.beats[i].action
			var source: Array = d.refs[a.measure_from]
			var goal: Array = d.refs[a.measure_to]
			check("relative_measure_length_"+beat_id,is_equal_approx(Vector2(source[0],source[1]).distance_to(Vector2(goal[0],goal[1])),float(d.substitutions[{"b-distance:x":"dx","b-front:z":"dz","b-top:depth":"dy"}[beat_id]])))
			check("relative_copy_condition_only_"+beat_id,not "＝" in text and not "：" in text and text.length()<22,text)
		if not action:
			check(kind+"_text_has_no_fake_action_"+str(i),d.before_states[i]==d.after_states[i])
			if beat_id in ["alignment:depth","alignment:given","alignment:45-distance","relative8:given"]:
				await snap(kind+"-"+beat_id.replace(":","-"))
			if i==count-1:
				check(kind+"_final_next_disabled",d.next.disabled)
				break
			if i%2==0:
				key_event(KEY_D,true)
				key_event(KEY_D,true,true)
				key_event(KEY_D,true)
				check(kind+"_plain_D_new_copy_"+str(i),d.current_beat==i+1 and d.phase=="typing")
				key_event(KEY_D,false)
			else: await button(d.next)
			check(kind+"_plain_next_no_empty_wait_"+str(i),d.current_beat==i+1 and d.phase in ["typing","ready","complete"] and d.state==d.before_states[i+1])
			continue
		if i%2 == 0: await h.key(KEY_D)
		else: await button(d.next)
		check(kind+"_playing_"+str(i),d.phase == "playing" and not d.previous.disabled and not d.next.disabled and not d.leave.disabled)
		if kind=="solution" and d.beats[i].action.has("measure_from"):
			check("measure_precedes_extended_guide_"+beat_id,is_equal_approx(d.state[8],before[8]))
			await snap("relative-measure-"+beat_id.replace(":","-"))
		if kind=="solution" and d.beats[i].action.type=="erase":
			await h.wait_frames(6)
			check("eraser_moves_"+beat_id,d.sheet.canvas.eraser_position.is_finite() and not visible_guides().is_empty())
			await snap("erasing-"+beat_id.replace(":","-"))
		if kind=="concept" and beat_id in ["alignment:transfer","alignment:turn","relative:back","relative8:front"]:
			check("real_geometry_changes_"+beat_id,d.state!=before)
			await snap("moving-"+beat_id.replace(":","-"))
		var complete_key: Key = KEY_A if i%2==0 else KEY_D
		# Some actions run naturally; the others finish immediately with either direction key.
		if i%3!=0 and d.phase=="playing":
			key_event(complete_key,true)
			check(kind+"_key_completes_action_"+str(i),d.current_beat==i and not d.busy and d.state==d.after_states[i])
			key_event(complete_key,true,true)
			key_event(complete_key,true)
			check(kind+"_finish_hold_does_not_step_"+str(i),d.current_beat==i and not d.busy)
			key_event(complete_key,false)
		await wait_idle()
		check(kind+"_result_"+str(i),d.current_beat == i and d.copy.text == text and d.state == d.after_states[i])
		check(kind+"_waits_after_action_"+str(i),d.phase == ("complete" if i == count-1 else "settled"))
		if kind == "solution":
			for item in d.sheet.canvas.primitives:
				if item.kind == "point" and float(item.order) < d.sheet.canvas.progress:
					check("no_future_point_"+str(i)+item.name,item.step<=i)
		else: check("scene_reuse_"+str(i),d.scene.get_child_count()==children and d.builds==1)
		if beat_id in ["distances:H","unfold:H","unfold:W","alignment:vertical","alignment:height","alignment:transfer","alignment:turn","alignment:point","relative:back","relative8:left","relative8:up","relative8:front","a-front:x","a-front:z","a-front:point","a-top:depth","a-top:erase","a-side:turn","a-side:height","a-side:erase","b-top:depth"]:
			await snap(kind+"-"+beat_id.replace(":","-"))
		if kind == "solution":
			if beat_id=="a-front:z": check("first_condition_one_guide",visible_guides().size()==1 and visible_points().is_empty())
			if beat_id=="a-front:x": check("two_conditions_locate_front",visible_guides().size()==2 and guide_cross("A_height_guide","A_x_guide","A_front"))
			if beat_id=="a-top:depth": check("third_condition_locates_top",visible_guides().size()==3 and guide_cross("A_x_guide","A_depth_guide","A_top"))
			if beat_id=="a-top:erase": check("initial_A_guides_erased",visible_guides().is_empty() and visible_points().size()==2)
			if beat_id=="a-side:height": check("transfer_intersection_A",guide_cross("A_turn_line","A_level","A_left"))
			if beat_id=="a-side:erase": check("A_complete_before_B",visible_guides().is_empty() and visible_points().map(func(item):return item.name)==["a′","a","a″"])
			if beat_id=="b-front:z": check("B_front_intersection",guide_cross("B_height_guide","B_x_guide","B_front"))
			if beat_id=="b-top:depth": check("B_top_intersection",guide_cross("B_x_guide","B_depth_guide","B_top"))
			if beat_id=="b-side:height": check("transfer_intersection_B",guide_cross("B_turn_line","B_level","B_left"))
		if beat_id == "unfold:H":
			check("H_unfolds_alone",is_equal_approx(d.planes[1].rotation.x,PI/2) and is_zero_approx(d.planes[2].rotation.y))
			check("stationary_projection_rays_stay_complete",d.rays[0].scale==Vector3.ONE and d.rays[2].scale==Vector3.ONE and d.rays[0].visible and d.rays[2].visible and not d.rays[1].visible)
		if kind=="concept":
			if beat_id=="unfold:W": check("both_planes_unfolded",is_equal_approx(d.planes[1].rotation.x,PI/2) and is_equal_approx(d.planes[2].rotation.y,PI/2))
			if beat_id in ["unfold:distance","alignment:depth"]:
				var anchors:Array=d.beats[i].anchor
				var top:Vector2=Vector2(d.refs[anchors[1]][0],d.refs[anchors[1]][1])
				var top_foot:Vector2=Vector2(d.refs[anchors[0]][0],d.refs[anchors[0]][1])
				var side:Vector2=Vector2(d.refs[anchors[3]][0],d.refs[anchors[3]][1])
				var side_foot:Vector2=Vector2(d.refs[anchors[2]][0],d.refs[anchors[2]][1])
				var depth:float=absf(float(d.concept.position(d.state,"A")[1]))
				check(beat_id+" top brace perpendicular to X",is_zero_approx(top_foot.y) and is_equal_approx(top_foot.x,top.x))
				check(beat_id+" side brace perpendicular to Z",is_zero_approx(side_foot.x) and is_equal_approx(side_foot.y,side.y))
				check(beat_id+" both braces measure actual depth",is_equal_approx(top.distance_to(top_foot),depth) and is_equal_approx(side.distance_to(side_foot),depth))
				check(beat_id+" rendered caption measures depth",d.distance_caption(anchors.slice(0,2),true)=="%d mm"%roundi(depth))
				await snap("depth-braces-"+beat_id.replace(":","-"))
			if beat_id in ["alignment:transfer","alignment:turn"]:
				check("transfer_draws_real_line_"+beat_id,d.sheet.canvas.primitives.filter(func(p):return p.kind=="line" and p.step==i and float(p.order)<d.sheet.canvas.progress).size()==1)
				check("side_answer_still_hidden_"+beat_id,not visible_points().any(func(p):return p.name=="a″"))
			if beat_id=="alignment:point": check("third_side_true_intersection",guide_cross("alignment:turn","alignment:level","A_left"))
			if beat_id=="relative:back": check("relative_finishes_original_B",d.concept.position(d.state,"B")==r.data.parameters.points_mm.B)
			if beat_id=="relative8:front":
				var a: Array = r.data.parameters.points_mm.A
				var b: Array = r.data.parameters.points_mm.B
				check("front_only_depth_translation",d.concept.position(d.state,"B")==[float(b[0]),float(a[1])-18,float(b[2])])
				check("exam8_front_increases_depth",absf(d.refs.B_top[1])>absf(d.refs.A_top[1]) and d.refs.B_left[0]>d.refs.A_left[0])
				for item in visible_points():
					var p: Vector2 = d.sheet.canvas.get_global_transform_with_canvas()*load("res://practice_canvas.gd").at(item.p)
					check("exam8_point_visible_"+item.name,d.sheet.view.get_global_rect().grow(-8).has_point(p),p)
		if i==count-1:
			check(kind+"_final_next_disabled",d.next.disabled)
			break
		if i%2 == 0: await button(d.next)
		else: await h.key(KEY_D)
		check(kind+"_next_text_only_"+str(i),d.current_beat==i+1 and d.phase in ["typing","ready"] and d.state==d.before_states[i+1],{"phase":d.phase,"beat":d.current_beat})
		if d.phase=="typing":
			var text_key: Key = KEY_D if i%2==0 else KEY_A
			key_event(text_key,true)
			check(kind+"_key_completes_text_"+str(i),d.current_beat==i+1 and d.phase in ["ready","complete"] and d.copy.visible_characters==d.copy.text.length() and d.state==d.before_states[i+1])
			key_event(text_key,true,true)
			key_event(text_key,true)
			check(kind+"_text_finish_hold_does_not_play_"+str(i),d.phase in ["ready","complete"])
			key_event(text_key,false)

func move_pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	r.get_viewport().push_input(event,true)
	await h.wait_frames(4)

func inspect_question() -> void:
	var beat: int = d.current_beat
	var state: Array = d.state.duplicate()
	var control = d.question
	check("question_initially_collapsed",control.visible and not control.panel.visible and not control.pinned)
	await move_pointer(control.button.get_global_rect().get_center())
	check("question_hover_shows_full_statement",control.panel.visible and not control.pinned and control.label.text==r.points_config.statement)
	await move_pointer(control.panel.get_global_rect().get_center())
	check("question_hover_card_stays",control.panel.visible)
	await snap("question-hover")
	await move_pointer(d.leave.get_global_rect().get_center())
	check("question_leave_collapses",not control.panel.visible)
	await button(control.button)
	await move_pointer(d.leave.get_global_rect().get_center())
	check("question_click_pins",control.pinned and control.panel.visible)
	await button(control.button)
	check("question_second_click_collapses",not control.pinned and not control.panel.visible)
	await button(control.button)
	await h.click(d.sheet.view.get_global_rect().position+Vector2(16,16))
	check("question_outside_click_collapses",not control.pinned and not control.panel.visible)
	check("question_does_not_step_or_draw",d.current_beat==beat and d.state==state)

func inspect_chapters(mode: String) -> void:
	Engine.time_scale = 1.0
	var children: int = d.scene.get_child_count() if mode=="concept" else 0
	for i in range(d.steps.size()):
		# Begin each jump in a different phase, using only native controls and viewport keys.
		await button(d.progress.nodes[0])
		if i%3!=0:
			key_event(KEY_D,true)
			key_event(KEY_D,false)
		if i%3==2:
			if mode=="concept":
				await button(d.progress.nodes[1])
				await advance_to("distances:H")
			await button(d.next)
		var old_phase: String = d.phase
		check(mode+"_jump_source_phase_"+str(i),old_phase==["typing","ready","playing"][i%3],old_phase)
		await button(d.progress.nodes[i])
		var first: int = d.beats.find(d.beats.filter(func(b):return b.group==i)[0])
		check(mode+"_node_starts_chapter_"+str(i),d.current_beat==first and d.phase=="typing" and d.state==d.before_states[first] and d.progress.current==i)
		if mode=="concept": check("chapter_target_saved_"+str(i),r.points_step_id==d.beats[first].id and d.scene.get_child_count()==children)
		await wait_idle()
		inspect_layout(mode+"_chapter_"+str(i))
		check(mode+"_jump_no_late_action_"+str(i),d.phase==d.text_complete_phase() and d.state==d.before_states[first])
	# Repeated same-node clicks also restore the first beat, including after completion.
	await button(d.next)
	key_event(KEY_A,true)
	key_event(KEY_A,false)
	await button(d.progress.nodes[d.current_step])
	check(mode+"_same_node_restarts_text",d.phase=="typing" and d.state==d.before_states[d.current_beat])
	await wait_idle()
	Engine.time_scale = 4.0

func run(root,flag: String) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	d = r.points_demo
	await h.wait_frames(15)
	check("default_map",r.map_active)
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	check("isolated_save_paths",r.save_path=="user://qa-points-beats-observation.json" and r.practice.save_path=="user://qa-points-beats-practice.json",[r.save_path,r.practice.save_path])
	await h.choose(0)
	if flag == "--qa-points-beats-reopen":
		check("reopen_observe",r.free_shell.visible and not d.active)
		await button(r.free_shell.find_child("Mode_concept",true,false))
		await wait_idle()
		check("stable_beat_reopened",d.beats[d.current_beat].id=="unfold:W" and d.phase=="ready")
		check("reopen_before_action",is_equal_approx(d.planes[1].rotation.x,PI/2) and is_zero_approx(d.planes[2].rotation.y))
		await button(d.leave)
		finish("points-beats-reopen.json")
		return
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var selected: Array = r.data.parameters.points_mm.B.duplicate()
	r.select_feature("B",selected)
	await button(r.free_shell.find_child("Mode_lessons",true,false))
	var draft: Dictionary = r.practice.snapshot()
	await button(r.chapter_lessons.buttons[0])
	check("teaching_eight_chapters",d.progress.nodes.size()==8 and d.beats.size()==23)
	check("no_repeated_relation_check",d.beats.filter(func(b):return b.id.begins_with("check:")).size()==1)
	check("teaching_starts_first_condition",d.beats[d.current_beat].id=="a-front:z" and d.copy.text=="A 距 H 面 12 mm。")
	check("no_full_question_or_read_chapter",d.steps.all(func(g):return g.id!="read") and d.beats.all(func(b):return b.text!=r.points_config.statement and not "可能" in b.text))
	check("type_initial",d.phase=="typing" and d.copy.visible_characters<d.copy.text.length())
	check("type_controls_available",not d.next.disabled and not d.previous.disabled and not d.leave.disabled)
	var started := Time.get_ticks_msec()
	await h.wait_frames(12)
	check("real_type_speed",d.copy.visible_characters>0 and d.copy.visible_characters<d.copy.text.length(),{"elapsed":Time.get_ticks_msec()-started,"characters":d.copy.visible_characters})
	await snap("typing")
	await wait_idle()
	check("first_condition_before_action",d.sheet.canvas.progress==0 and d.previous.disabled)
	await inspect_question()
	await inspect_chapters("solution")
	await button(d.progress.nodes[0])
	await wait_idle()
	# Continue exhaustive real button/key input at accelerated engine time, not state overrides.
	Engine.time_scale = 4.0
	key_event(KEY_D,true,false,true)
	key_event(KEY_D,false,false,true)
	check("modified_key_ignored",d.phase=="ready")
	key_event(KEY_D,true)
	key_event(KEY_D,true,true)
	await wait_idle()
	var beat: int = d.current_beat
	key_event(KEY_D,true,false)
	await h.wait_frames(5)
	check("held_d_does_not_advance",d.current_beat==beat and d.phase=="settled")
	key_event(KEY_D,false)
	# Re-enter through the real control to start a complete mixed-input walkthrough.
	await button(d.leave)
	await button(r.chapter_lessons.buttons[0])
	await walk("solution")
	var expected := {"a′":[-10.0,12.0],"a":[-10.0,-15.0],"a″":[15.0,12.0],"b′":[-15.0,20.0],"b":[-15.0,-5.0],"b″":[5.0,20.0]}
	var actual: Dictionary = {}
	for item in d.sheet.canvas.primitives:
		if item.kind == "point": actual[item.name] = item.p
	check("six_exact_points",actual==expected,actual)
	check("six_points_and_clean_final",actual.size()==6 and visible_guides().is_empty())
	check("no_redundant_solution_arrows",d.beats.all(func(b): return not "arrow" in b.indicators))
	await h.key(KEY_A)
	await wait_idle()
	check("A_returns_previous_reading",d.current_beat==d.beats.size()-2 and d.phase=="ready" and d.state==d.before_states[d.current_beat])
	await button(d.leave)
	check("draft_unchanged",r.practice.snapshot()==draft)
	check("observation_unchanged",r.observer.get_state()==camera and r.observer.picked_world==selected)
	r.points_step_id = ""
	await button(r.chapter_lessons.find_child("Nav_concept",true,false))
	await walk("concept")
	check("knowledge_six_unique_chapters",d.progress.nodes.size()==6 and d.beats.size()==39 and not d.question.visible)
	check("purpose_before_projection_and_relative",d.steps[0].beats[0].id=="planes:purpose" and d.steps[-1].beats[0].id=="relative:purpose")
	var feet_group:Dictionary=d.steps.filter(func(g):return g.id=="feet")[0]
	check("projection_names_after_visible_feet",feet_group.beats[-1].id=="planes:names")
	check("relative_knowledge_not_repeated",d.steps.filter(func(g):return g.id=="relative").size()==1 and not d.steps.any(func(g):return g.id=="relative8") and not d.beats.any(func(b):return b.id in ["relative8:given","relative8:left","relative8:up"]))
	check("meaningful_actions_only",d.beats.filter(func(b):return b.action.type=="focus").all(func(b):return d.before_states[d.beats.find(b)]==d.after_states[d.beats.find(b)]))
	check("all_content_has_exam_sources",d.beats.all(func(b):return b.has("source_questions") and b.source_questions.all(func(id):return id in ["t01-q01","t08-q01"])))
	check("no_extraneous_knowledge_groups",d.steps.all(func(g):return not g.id in ["special","coordinates","coincident"]))
	check("question_scope_two_point_questions",r.points_config.knowledge_scope.direct_questions.map(func(q):return q.id)==["t01-q01","t08-q01"])
	await inspect_chapters("concept")
	await button(d.leave)
	check("exit_restores_label_size",d.concept.label_bases.all(func(item):return item.label.font_size==item.font_size and item.label.modulate==item.color))
	for legacy in ["planes","distances","feet","unfold","alignment","unknown-id"]:
		r.points_step_id = legacy
		await button(r.chapter_lessons.find_child("Nav_concept",true,false))
		await wait_idle()
		check("legacy_"+legacy,d.beats[d.current_beat].id==("planes:purpose" if legacy=="unknown-id" else legacy+":"+str(r.points_config.concept.filter(func(g):return g.id==legacy)[0].beats[0].id.split(":")[1])))
		await button(d.leave)
	for old_id in ["relative8","relative8:given","relative8:left","relative8:up","relative8:front"]:
		r.points_step_id = old_id
		await button(r.chapter_lessons.find_child("Nav_concept",true,false))
		await wait_idle()
		check("merged_progress_"+old_id,d.beats[d.current_beat].id==("relative8:front" if old_id=="relative8:front" else "relative:left") and d.current_step==5 and d.state==d.before_states[d.current_beat])
		await button(d.leave)
	# Actual minimum-window renders and anchors for both presentations.
	DisplayServer.window_set_size(Vector2i(1060,720))
	Engine.time_scale = 1.0
	await h.wait_frames(15)
	await button(r.chapter_lessons.buttons[0])
	await advance_to("a-side:turn")
	inspect_layout("minimum_solution")
	await snap("minimum-solution")
	await button(d.question.button)
	check("minimum_question_contained",d.get_global_rect().encloses(d.question.panel.get_global_rect()))
	await snap("minimum-question")
	await button(d.progress.nodes[0])
	check("chapter_jump_closes_question",not d.question.panel.visible)
	await button(d.previous)
	check("mouse_completes_first_text",d.phase=="ready" and d.current_beat==0)
	await button(d.next)
	await button(d.previous)
	check("mouse_completes_first_action",d.phase=="settled" and d.current_beat==0 and d.state==d.after_states[0])
	await snap("first-action")
	await button(d.leave)
	await button(r.chapter_lessons.buttons[0])
	await advance_to("a-side:transfer")
	await h.key(KEY_A)
	await wait_idle()
	check("back_restores_guides_before_erase",d.beats[d.current_beat].id=="a-top:erase" and visible_guides().size()==3 and visible_points().size()==2)
	await snap("minimum-before-erase")
	await h.key(KEY_D)
	await h.wait_frames(6)
	await button(d.leave)
	await h.wait_frames(20)
	check("exit_during_erasure_keeps_draft",not d.active and r.practice.snapshot()==draft)
	r.points_step_id = "unfold:H"
	await button(r.chapter_lessons.find_child("Nav_concept",true,false))
	await wait_idle()
	inspect_layout("minimum_concept")
	await snap("minimum-concept")
	await button(d.next)
	await button(d.leave)
	await h.wait_frames(20)
	check("mid_animation_exit",not d.active and r.chapter_lessons.visible and r.practice.snapshot()==draft)
	Engine.time_scale = 4.0
	await button(r.chapter_lessons.find_child("Nav_concept",true,false))
	await button(d.progress.nodes[0])
	await advance_to("planes:X")
	inspect_layout("minimum_axis_label")
	await snap("minimum-axis-label")
	for target in ["alignment:transfer","relative:back","relative8:front"]:
		var target_index: int = d.beats.find(d.beats.filter(func(b):return b.id==target)[0])
		await button(d.progress.nodes[d.beats[target_index].group])
		await advance_to(target)
		if d.has_action():
			await button(d.next)
			if d.phase=="playing":
				key_event(KEY_D,true)
				key_event(KEY_D,false)
			await wait_idle()
		inspect_layout("minimum_"+target)
		await snap("minimum-"+target.replace(":","-"))
	await button(d.leave)
	Engine.time_scale = 1.0
	r.points_step_id = "unfold:W"
	await button(r.chapter_lessons.find_child("Nav_concept",true,false))
	await button(d.leave)
	check("mid_type_exit",not d.active and not d.busy)
	check("question_cleared_on_exit",not d.question.panel.visible and not d.question.pinned)
	var overlay_source := FileAccess.get_file_as_string("res://points_callout.gd")
	check("no_moving_brace_dot",not "draw_circle" in overlay_source.split("func brace(")[1])
	check("no_moving_arrow_dot",not "draw_circle" in overlay_source.split("func arrow(")[1].split("func brace(")[0])
	check("no_ring_growth_animation",not "13+3*focus_strength" in overlay_source)
	DisplayServer.window_set_size(Vector2i(1440,900))
	await h.wait_frames(12)
	key_event(KEY_A,true)
	key_event(KEY_A,false)
	key_event(KEY_D,true)
	key_event(KEY_D,false)
	check("inactive_shortcuts_no_mode_change",r.chapter_lessons.visible)
	check("isolated_paths_after_presentations",r.save_path=="user://qa-points-beats-observation.json" and r.practice.save_path=="user://qa-points-beats-practice.json")
	for i in range(1,r.catalog.size()):
		await h.choose(i)
		check("other_chapter_"+str(i),(r.free_shell.visible or r.course_workspace.visible) and not d.active)
	await h.choose(0)
	r.points_step_id = "unfold:W"
	r.remember_current()
	r.save_states()
	Engine.time_scale = 1.0
	finish("points-beats-check.json")

func finish(name: String) -> void:
	FileAccess.open("res://qa/"+name,FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	print("POINTS_BEATS_QA ",name," ",checks.size()," checks")
