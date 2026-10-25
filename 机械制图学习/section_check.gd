extends RefCounted
var r
var h
var drag
var checks: Array = []

func check(label: String, passed: bool) -> void:
	checks.append({"check":label,"passed":passed})

func toggle() -> void:
	r.section_toggle.grab_focus()
	await h.key(KEY_SPACE)
	await h.wait_frames(5)

func run(root) -> Array:
	r = root
	r.save_path = "user://qa-observation-v1.json"
	r.states.erase("section")
	h = load("res://interaction_check.gd").new()
	h.r = r
	drag = load("res://point_drag_check.gd").new()
	drag.r = r
	await h.choose(6)
	check("seventh_example_from_map",r.data.id=="section" and r.catalog.size()==7)
	check("source_pdf3_question5",r.data.source.pdf_page==3 and r.data.source.question_id=="t01-q05")
	check("section_default_on",r.section_enabled and r.section_toggle.visible and r.paper.data.section_active)
	check("section_hatches",r.paper.data.views.front.hatches.size()>0)
	check("section_front_has_no_hidden_lines",r.paper.data.views.front.segments.all(func(s): return not s.hidden))
	check("top_and_left_remain_whole",r.paper.data.views.top==r.data.views.top and r.paper.data.views.left==r.data.views.left)
	var camera: Dictionary = r.observer.get_state()
	await toggle()
	check("toggle_restores_whole_model",not r.section_enabled and not r.paper.data.section_active and not r.paper.data.views.front.has("hatches"))
	check("whole_has_hidden_hole_lines",r.paper.data.views.front.segments.any(func(s): return s.hidden))
	check("toggle_keeps_camera",r.observer.get_state()==camera)
	await toggle()
	check("toggle_back_to_section",r.section_enabled and r.paper.data.section_active)
	var world := Vector3(-37,0,25)
	await drag.mouse_button(drag.pos(world,"front"),true)
	check("cut_edge_correspondence",drag.close_world(world))
	world = Vector3(-37,0,40)
	await drag.move_to(drag.pos(world,"front"))
	check("cut_edge_drag_sync",drag.close_world(world))
	await drag.mouse_button(drag.pos(world,"front"),false)
	check("drag_release",not r.paper.dragging_point)
	await h.click(r.find_child("SourceButton",true,false).get_global_rect().get_center())
	check("question_popup",r.source_window.visible and r.source_image.texture.resource_path.ends_with("section.png"))
	r.source_window.hide()
	await h.wait_frames()
	await h.click(r.find_child("AnswerButton",true,false).get_global_rect().get_center())
	check("answer_popup",r.source_window.visible and r.source_image.texture.resource_path.ends_with("section-answer.png"))
	r.source_window.hide()
	await h.wait_frames()
	await toggle()
	await h.choose(0)
	check("other_examples_hide_section_control",not r.section_toggle.visible and r.data.id=="points")
	await h.choose(6)
	check("return_restores_section_option",not r.section_enabled and not r.paper.data.section_active)
	check("return_keeps_camera",r.observer.get_state()==camera)
	await toggle()
	r.save_states()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(r.save_path))
	check("section_option_saved",saved.states.section.section and saved.last_example=="section")
	r.observer.request_render()
	r.queue_redraw()
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/section-final.png")
	FileAccess.open("res://qa/section-interaction-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	return checks
