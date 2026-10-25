extends RefCounted
var r
var h
var c
var checks: Array = []

func check(name: String, passed: bool, detail = null) -> void:
	checks.append({"check":name,"passed":passed,"detail":detail})

func move(area: Control, p: Vector2, held := false) -> void:
	var e := InputEventMouseMotion.new()
	e.position = area.get_global_transform_with_canvas() * p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	area.get_viewport().push_input(e, true)
	await h.wait_frames(2)

func screenshot(name: String) -> void:
	r.observer.request_render()
	r.queue_redraw()
	await h.wait_frames(3)
	await RenderingServer.frame_post_draw
	r.get_viewport().get_texture().get_image().save_png("res://qa/ui-refine-" + name + ".png")

func crosses_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if is_equal_approx(a.x,b.x):
		return a.x > rect.position.x and a.x < rect.end.x and maxf(a.y,b.y)>rect.position.y and minf(a.y,b.y)<rect.end.y
	if is_equal_approx(a.y,b.y):
		return a.y > rect.position.y and a.y < rect.end.y and maxf(a.x,b.x)>rect.position.x and minf(a.x,b.x)<rect.end.x
	return true

func check_routes() -> void:
	var graph: Dictionary = r.knowledge_map.graph
	var collisions: Array = []
	var semantic := true
	for edge in graph.edges:
		semantic = semantic and r.knowledge_map.nodes_by_id[edge.from].get("kind", "topic") != "group" and r.knowledge_map.nodes_by_id[edge.to].get("kind", "topic") != "group"
		var points: PackedVector2Array = r.knowledge_map.canvas.edge_points(edge)
		for id in r.knowledge_map.canvas.cards:
			if id in [edge.from,edge.to]: continue
			var rect: Rect2 = r.knowledge_map.canvas.cards[id].get_rect().grow(-1)
			for i in range(1, points.size()):
				if crosses_rect(points[i-1],points[i],rect): collisions.append([edge.from,edge.to,id])
	check("grouping_is_not_prerequisite", semantic)
	check("connections_do_not_cross_unrelated_labels", collisions.is_empty(),collisions)
	for group in graph.groups:
		var bounds := Rect2(group.rect[0],group.rect[1],group.rect[2],group.rect[3])
		check("group_contains_"+str(group.id),group.members.all(func(id):return bounds.encloses(r.knowledge_map.canvas.cards[id].get_rect())))

func run(root) -> void:
	r = root
	h = load("res://interaction_check.gd").new()
	h.r = r
	c = load("res://canvas_check.gd").new()
	c.r = r
	c.h = h
	await h.wait_frames(12)
	check("isolated_save",r.save_path=="user://qa-ui-refine.json")
	check("offscreen_no_focus",DisplayServer.window_get_position().x<0 and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	r.show_knowledge_map()
	await h.wait_frames(4)
	check_routes()
	var view = r.knowledge_map.view
	view.center_on(r.knowledge_map.canvas.cards.points.get_rect().get_center())
	await h.wait_frames(3)
	var p: Vector2 = view.size*0.5
	await move(view,p)
	check("hover_visible",r.knowledge_map.buttons.points.get_meta("visual_state")=="hover" and view.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND)
	await screenshot("hover")
	c.mouse_button(view,p,MOUSE_BUTTON_LEFT,true)
	await h.wait_frames(2)
	check("pressed_visible",r.knowledge_map.buttons.points.get_meta("visual_state")=="pressed")
	await screenshot("pressed")
	await move(view,p+Vector2(40,20),true)
	check("drag_clears_pressed",r.map_active and r.knowledge_map.pressed_id.is_empty() and view.mouse_default_cursor_shape==Control.CURSOR_DRAG)
	var pivot := p+Vector2(40,20)
	var world: Vector2 = (pivot-view.pan)/view.zoom
	await c.wheel(view,pivot,true)
	var anchor_pan: Vector2 = view.pan
	check("held_zoom_anchor",((pivot-view.pan)/view.zoom).distance_to(world)<0.001)
	await move(view,pivot+Vector2(18,12),true)
	check("held_zoom_then_drag_continuous",view.pan.distance_to(anchor_pan+Vector2(18,12))<0.01)
	c.mouse_button(view,pivot+Vector2(18,12),MOUSE_BUTTON_LEFT,false)
	await h.wait_frames(3)
	check("held_wheel_never_clicks_node",r.map_active)
	await c.drag(view,p,p+Vector2(10000,-10000))
	check("map_not_lost_after_extreme_pan",Rect2(view.pan,view.content.size*view.zoom).intersection(Rect2(Vector2.ZERO,view.size)).get_area()>=96*96-1)
	var clamped: Vector2 = view.pan
	c.mouse_button(view,p,MOUSE_BUTTON_LEFT,true)
	await move(view,p+Vector2(10000,-10000),true)
	await move(view,p+Vector2(9980,-9980),true)
	check("clamped_drag_returns_immediately",view.pan.distance_to(clamped+Vector2(-20,20))<0.01)
	c.mouse_button(view,p+Vector2(9980,-9980),MOUSE_BUTTON_LEFT,false)
	view.fit_content()
	await h.wait_frames(3)
	await screenshot("map")
	await load("res://knowledge_map_check.gd").new().export_map_with_root(r)
	await h.choose(0)
	r.show_knowledge_map()
	check("current_label",r.knowledge_map.current_labels.points.text=="当前")
	await h.choose(0)
	r.observer.standard_view("reset")
	await screenshot("points")
	var quality = load("res://point_quality_check.gd").new()
	quality.r = r
	quality.h = h
	quality.stage = "after"
	var point_camera: Dictionary = r.observer.get_state().duplicate(true)
	for plane_label in quality.plane_labels(): await quality.overlap(plane_label)
	checks.append_array(quality.checks)
	r.observer.restore_state(point_camera)
	for i in [1,2]:
		await h.choose(i)
		r.observer.standard_view("reset")
		await screenshot(str(r.data.id))
	await h.choose(6)
	var camera: Dictionary = r.observer.get_state().duplicate(true)
	var remembered: Dictionary = {}
	for mode in ["question","answer"]:
		await h.click(r.find_child("SourceButton" if mode=="question" else "AnswerButton",true,false).get_global_rect().get_center())
		await h.wait_frames(8)
		var area = r.source_view
		var pivot_image: Vector2 = area.size*0.5
		await c.wheel(area,pivot_image,true,2)
		await c.drag(area,pivot_image,pivot_image+Vector2(-70,45))
		remembered[mode] = area.get_view_state()
		await c.close_source_x()
		await h.click(r.find_child("SourceButton" if mode=="question" else "AnswerButton",true,false).get_global_rect().get_center())
		await h.wait_frames(8)
		check(mode+"_reopen_preserves_view",is_equal_approx(area.zoom,remembered[mode].zoom) and area.get_view_state().center.distance_to(remembered[mode].center)<0.01)
		await screenshot("source-"+mode)
		await c.close_source_x()
	await h.choose(3)
	r.show_source("question")
	await h.wait_frames(6)
	r.hide_source()
	await h.choose(6)
	for mode in ["answer","question"]:
		r.show_source(mode)
		await h.wait_frames(6)
		check(mode+"_independent_of_other_source",is_equal_approx(r.source_view.zoom,remembered[mode].zoom) and r.source_view.get_view_state().center.distance_to(remembered[mode].center)<0.01)
		r.hide_source()
	check("source_preserves_model_camera",r.observer.get_state()==camera)
	var image_path: String = r.data.source.image
	r.data.source.image = "assets/source/not-present-qa.png"
	r.show_source("question")
	await h.wait_frames(4)
	check("failed_source_has_no_stale_image",r.source_window.visible and r.source_image.texture==null and r.source_note.text.contains("图片无法打开"))
	check("failed_source_preserves_camera",r.observer.get_state()==camera)
	r.hide_source()
	r.data.source.image = image_path
	r.show_source("question")
	await h.wait_frames(6)
	check("source_recovers_after_failure",r.source_image.texture!=null and is_equal_approx(r.source_view.zoom,remembered.question.zoom) and r.source_view.get_view_state().center.distance_to(remembered.question.center)<0.01)
	r.hide_source()
	r.guide_step_id = "rib_convention"
	await h.click(r.guide_button.get_global_rect().get_center())
	await h.wait_frames(8)
	check("rib_conclusion_separate",r.guide_copy.text=="肋板纵向剖切时，按规定不画剖面线。")
	check("reason_exact_visible",r.guide_reason.visible and r.guide_reason.text.contains("容易把肋板和底座、凸台看成一整块厚实材料"))
	check("material_and_transverse_visible",r.guide_detail.visible and r.guide_detail.text.contains("它有材料，也确实被切到了") and r.guide_detail.text.contains("横向切断肋板时则要画剖面线"))
	await screenshot("rib")
	DisplayServer.window_set_size(Vector2i(1060,720))
	await h.wait_frames(12)
	check("guide_minimum_content_fits",r.guide_detail.get_global_rect().end.y<r.guide_next.get_global_rect().position.y and r.guide_next.get_global_rect().end.y<r.get_viewport_rect().size.y)
	check("minimum_keeps_model_area",r.observer.size.y>r.get_viewport_rect().size.y*0.58)
	await screenshot("minimum-rib")
	await h.click(r.find_child("GuideExit",true,false).get_global_rect().get_center())
	await h.wait_frames(6)
	check("exit_restores_camera",r.observer.get_state()==camera and not r.guide_panel.visible)
	FileAccess.open("res://qa/ui-refine-check.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	print("UI_REFINE_CHECK ",JSON.stringify({"total":checks.size(),"failures":checks.filter(func(item):return not item.passed)}))
