extends RefCounted
var r
var h
var checks: Array = []
func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check":name,"passed":passed,"detail":detail})
func camera_close(a: Dictionary, b: Dictionary) -> bool:
	for key in ["yaw","pitch","zoom"]:
		if not is_equal_approx(float(a[key]),float(b[key])): return false
	for i in range(3):
		if not is_equal_approx(float(a.target[i]),float(b.target[i])): return false
	return true
func press(name: String) -> void:
	await h.click(r.find_child(name,true,false).get_global_rect().get_center())
func settled() -> void:
	await r.get_tree().create_timer(1.7).timeout
	await h.wait_frames(4)
func image_file(name: String) -> void:
	r.observer.request_render()
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/"+name+".png")
func visible_buttons(node: Node) -> Array:
	var found: Array = []
	if node is Window and not node.visible: return found
	if node is CanvasItem and not node.is_visible_in_tree(): return found
	if node is BaseButton: found.append(str(node.name))
	for child in node.get_children(): found.append_array(visible_buttons(child))
	return found
func run(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	await h.wait_frames(20)
	if not "--qa-guide-only" in OS.get_cmdline_user_args():
		checks.append_array(await h.run(r))
		checks.append_array(await load("res://section_check.gd").new().run(r))
		checks.append_array(await load("res://point_drag_check.gd").new().run(r))
	else: r.states = {}
	await h.choose(6)
	r.guide_step_id = ""
	await press("Camera_reset")
	r.select_feature("cut",[-37,0,25])
	var before: Dictionary = r.observer.get_state()
	var before_section: bool = r.section_enabled
	var size_before := DisplayServer.window_get_size()
	var position_before := DisplayServer.window_get_position()
	var mode_before := DisplayServer.window_get_mode()
	var source_position: Vector2 = r.find_child("SourceButton",true,false).get_global_rect().get_center()
	var left_position: Vector2 = r.find_child("Camera_left",true,false).get_global_rect().get_center()
	var parents := [r.observer.get_parent(),r.paper.get_parent()]
	check("free_entry_only",r.free_shell.visible and not r.guide_shell.visible and not r.guide_panel.visible)
	check("no_projection_switch",r.find_child("ProjectionToggle",true,false)==null and r.projections)
	await press("GuideEntry")
	await h.wait_frames(5)
	check("entry_real_input",r.guide.active and r.guide.current_step==0)
	check("fullscreen_requested",r.guide.fullscreen_requested)
	check("qa_keeps_window_offscreen",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_mode()==mode_before)
	check("independent_guide_shell",r.guide_shell.visible and not r.free_shell.visible)
	check("only_three_visible_buttons",visible_buttons(r)==["GuideExit","GuidePrevious","GuideNext"],visible_buttons(r))
	check("no_replay_restart",r.find_child("GuideReplay",true,false)==null and r.find_child("GuideRestart",true,false)==null)
	check("free_controls_disabled",r.find_child("MapEntry",true,false).disabled and r.find_child("SourceButton",true,false).disabled and r.find_child("Camera_left",true,false).disabled)
	check("guide_picking_disabled",not r.paper.picking_enabled and not r.observer.picking_enabled and not r.observer.interaction_enabled)
	check("entry_hides_point",r.paper.picked_world.is_empty() and r.observer.picked_world.is_empty())
	check("step1_only_model",not r.guide_paper.visible and not r.paper.is_visible_in_tree() and r.observer.size.x>r.guide_stage.size.x*0.95)
	check("step1_whole",r.guide.complete.visible and not r.guide.cut_plane.visible)
	check("first_boundary",r.guide_prev.disabled and not r.guide_next.disabled)
	await image_file("guide-theater-01-model")
	var guide_camera: Dictionary = r.observer.get_state()
	var center: Vector2 = r.observer.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position=center
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	r.get_viewport().push_input(down,true)
	var motion := InputEventMouseMotion.new()
	motion.position=center+Vector2(65,18)
	motion.relative=Vector2(65,18)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	r.get_viewport().push_input(motion,true)
	var up: InputEventMouseButton=down.duplicate()
	up.pressed=false
	up.position=motion.position
	r.get_viewport().push_input(up,true)
	var wheel := InputEventMouseButton.new()
	wheel.position=center
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	r.get_viewport().push_input(wheel,true)
	wheel=wheel.duplicate()
	wheel.pressed=false
	r.get_viewport().push_input(wheel,true)
	await h.wait_frames(4)
	check("guide_blocks_rotation_zoom",camera_close(r.observer.get_state(),guide_camera))
	await h.click(source_position)
	await h.click(left_position)
	check("hidden_button_positions_inert",not r.source_window.visible and camera_close(r.observer.get_state(),guide_camera))
	r.find_child("MapEntry",true,false).grab_focus()
	await h.key(KEY_SPACE)
	await h.key(KEY_ENTER)
	check("keyboard_cannot_activate_hidden_controls",not r.map_active and r.data.id=="section")
	r.show_source("question")
	r.load_example(0)
	r.set_section(not before_section)
	check("guide_guards_other_actions",not r.source_window.visible and r.data.id=="section" and r.section_enabled==before_section)
	await press("GuideNext")
	check("navigation_locked_during_animation",r.guide.busy and r.guide_prev.disabled and r.guide_next.disabled)
	await press("GuideNext")
	await press("GuidePrevious")
	r.guide.go_to(5)
	check("locked_navigation_cannot_skip",r.guide.current_step==1)
	check("exit_available_during_animation",not r.find_child("GuideExit",true,false).disabled)
	await settled()
	check("navigation_unlocked_after_animation",not r.guide.busy and not r.guide_prev.disabled and not r.guide_next.disabled)
	check("step2_plane_focus",r.guide.cut_plane.visible and r.guide.focus_materials[0].get_shader_parameter("focus_mode")==1)
	check("step2_projection_hidden",not r.guide_paper.visible)
	check("cut_plane_rule",r.guide.lesson_text().contains("全剖不要求总从中间对称线切开"))
	await image_file("guide-theater-02-plane")
	await press("GuideNext")
	await r.get_tree().create_timer(0.6).timeout
	check("split_is_continuous",float(r.guide.visual[0])>0.05 and float(r.guide.visual[0])<0.9 and r.guide.removed.visible)
	check("removed_moves_front",r.guide.removed.position.z>0)
	await image_file("guide-theater-03-moving")
	await press("GuideExit")
	await h.wait_frames(6)
	check("exit_interrupts_animation",not r.guide.active and not r.guide.busy and r.guide.animation==null)
	check("exit_restores_window",DisplayServer.window_get_size()==size_before and DisplayServer.window_get_position()==position_before and DisplayServer.window_get_mode()==mode_before)
	check("exit_restores_parents",r.observer.get_parent()==parents[0] and r.paper.get_parent()==parents[1])
	check("exit_restores_camera",camera_close(r.observer.get_state(),before))
	check("exit_restores_model",r.section_enabled==before_section and r.paper.data.section_active==before_section)
	check("exit_restores_point",r.selected=="cut" and r.paper.picked_world==[-37,0,25] and r.observer.picked_world==[-37,0,25])
	check("exit_restores_controls",r.free_shell.visible and not r.guide_shell.visible and not r.find_child("MapEntry",true,false).disabled and r.observer.interaction_enabled)
	check("exit_removes_focus",r.paper.guide_focus.is_empty() and r.guide.focus_materials.is_empty() and r.observer.world.find_child("SectionGuideScene",true,false)==null)
	await press("SourceButton")
	check("free_source_restored",r.source_window.visible)
	r.source_window.hide()
	await press("GuideEntry")
	await h.wait_frames(6)
	check("resume_stable_target",r.guide.current_step==2 and r.guide.visual==r.data.guide.steps[2].state and not r.guide.busy)
	await press("GuidePrevious")
	await settled()
	check("reverse_reassembles",r.guide.complete.visible and not r.guide.removed.visible)
	await press("GuideNext")
	await settled()
	check("step3_retained_only",not r.guide.complete.visible and not r.guide.removed.visible and r.observer.model.visible)
	await press("GuideNext")
	await settled()
	check("step4_material_focus",r.guide.material_notes.visible and r.guide.focus_materials[0].get_shader_parameter("focus_mode")==3)
	check("step4_projection_hidden",not r.guide_paper.visible and r.observer.size.x>r.guide_stage.size.x*0.95)
	await image_file("guide-theater-04-material")
	await press("GuideNext")
	await settled()
	check("step5_reveals_projection",r.guide_paper.visible and r.paper.is_visible_in_tree() and r.paper.data.section_active)
	check("step5_two_panels",r.observer.size.x<r.guide_stage.size.x*0.6 and r.paper.size.x>r.guide_stage.size.x*0.4)
	check("step5_front_focus",r.paper.guide_focus=="projection")
	check("other_views_remain_whole",r.paper.data.views.top==r.data.views.top and r.paper.data.views.left==r.data.views.left)
	check("full_formal_section_lines",r.paper.data.views.front.segments==r.data.section.views.front.segments)
	await image_file("guide-theater-05-projection")
	await press("GuideNext")
	await settled()
	check("step6_rib_focus",r.paper.guide_rib and r.paper.guide_focus=="rib" and r.guide.focus_materials[0].get_shader_parameter("focus_mode")==5)
	check("reason_exact",r.guide.lesson_text().contains("容易把肋板和底座、凸台看成一整块厚实材料"))
	check("rib_material_and_transverse",r.guide.lesson_text().contains("它有材料，也确实被切到了") and r.guide.lesson_text().contains("横向切断肋板时则要画剖面线"))
	check("last_boundary",r.guide_next.disabled and not r.guide_prev.disabled)
	check("guided_camera_is_authored",not camera_close(r.observer.get_state(),before))
	await image_file("guide-theater-06-rib")
	await h.click(r.paper.get_global_rect().get_center())
	check("dimmed_paper_inert",r.paper.picked_world.is_empty() and r.selected.is_empty())
	await press("GuidePrevious")
	await settled()
	await press("GuideNext")
	r.save_states()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(r.save_path))
	check("save_target_id",saved.states.section.guide_step_id=="rib_convention")
	check("save_free_camera",camera_close(saved.states.section.camera,before))
	check("save_free_model",saved.states.section.section==before_section)
	check("save_no_animation_transforms",not saved.states.section.has("visual") and not saved.states.section.has("window_snapshot"))
	await settled()
	DisplayServer.window_set_size(Vector2i(1060,720))
	await h.wait_frames(16)
	check("minimum_window_copy_fits",r.guide_copy.get_global_rect().end.y<r.get_viewport_rect().size.y)
	check("minimum_window_buttons_fit",r.find_child("GuideNext",true,false).get_global_rect().end.x<r.get_viewport_rect().size.x)
	await image_file("guide-theater-minimum")
	r.guide.go_to(4)
	await settled()
	r.guide.go_to(5)
	FileAccess.open("res://qa/guide-interaction-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failures := checks.filter(func(c):return not c.passed)
	print("GUIDE_CHECK ",JSON.stringify({"total":checks.size(),"failures":failures,"native_fullscreen_tested":false}))
	if not failures.is_empty(): push_error("Guide acceptance checks failed")
	r.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

